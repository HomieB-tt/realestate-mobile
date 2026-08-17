import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/location/location_service.dart';
import '../../domain/entities/property.dart';
import '../../domain/repositories/property_repository.dart';
import '../../domain/repositories/property_image_repository.dart';
import '../providers/property_providers.dart';

class CreatePropertyScreen extends ConsumerStatefulWidget {
  const CreatePropertyScreen({super.key});

  @override
  ConsumerState<CreatePropertyScreen> createState() => _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends ConsumerState<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _bedroomsController = TextEditingController(text: '1');
  final _bathroomsController = TextEditingController(text: '1');
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _lngController = TextEditingController();
  final _latController = TextEditingController();

  ListingType _listingType = ListingType.sale;
  String _currency = 'USD';
  bool _publishImmediately = true;

  final List<XFile> _selectedImages = [];
  bool _submitting = false;
  String? _errorMessage;

  static const _locationService = LocationService();
  bool _resolvingLocation = false;
  String? _locationStatusMessage;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _resolvingLocation = true;
      _locationStatusMessage = null;
    });

    final result = await _locationService.getCurrentLocation();

    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final lng, :final lat):
        setState(() {
          _lngController.text = lng.toStringAsFixed(6);
          _latController.text = lat.toStringAsFixed(6);
          _resolvingLocation = false;
          _locationStatusMessage = 'Location captured — adjust manually if needed.';
        });
      case LocationServiceDisabled():
        setState(() {
          _resolvingLocation = false;
          _locationStatusMessage = 'Location services are off. Enable them or enter coordinates manually.';
        });
      case LocationPermissionDenied(:final permanently):
        setState(() {
          _resolvingLocation = false;
          _locationStatusMessage = permanently
              ? 'Location permission denied. Enable it in system settings, or enter coordinates manually.'
              : 'Location permission denied. Enter coordinates manually.';
        });
      case LocationUnknownError():
        setState(() {
          _resolvingLocation = false;
          _locationStatusMessage = 'Could not get your location. Enter coordinates manually.';
        });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _descriptionController,
      _priceController,
      _bedroomsController,
      _bathroomsController,
      _areaController,
      _addressController,
      _cityController,
      _countryController,
      _lngController,
      _latController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    // Constrain dimensions, not just JPEG quality — an unconstrained pick
    // can return a full-resolution camera image (e.g. 4000x3000+), which
    // is expensive to decode for the inline preview and can OOM-crash on
    // resource-limited emulators (observed on Waydroid). 1600px is more
    // than enough for a property photo.
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (images.isEmpty) return;
    setState(() => _selectedImages.addAll(images));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final propertyRepo = ref.read(propertyRepositoryProvider);
    final imageRepo = ref.read(propertyImageRepositoryProvider);

    final input = NewPropertyInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      listingType: _listingType,
      price: num.parse(_priceController.text.trim()),
      currency: _currency,
      bedrooms: int.parse(_bedroomsController.text.trim()),
      bathrooms: int.parse(_bathroomsController.text.trim()),
      areaSqm: _areaController.text.trim().isEmpty ? null : num.parse(_areaController.text.trim()),
      addressLine: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      lng: double.parse(_lngController.text.trim()),
      lat: double.parse(_latController.text.trim()),
    );

    final createResult = await propertyRepo.createDraft(input);

    if (createResult is Failure<Property>) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = createResult.failure.message;
      });
      return;
    }

    final property = (createResult as Success<Property>).value;

    // Upload images sequentially after the property exists — each upload
    // needs the property's id, and RLS on `property_images` checks the
    // parent property's agent_id, so the property row must already exist
    // and be committed before any image insert can pass.
    for (var i = 0; i < _selectedImages.length; i++) {
      final file = _selectedImages[i];
      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last;

      final uploadResult = await imageRepo.upload(
        propertyId: property.id,
        bytes: bytes,
        fileExtension: extension,
        position: i,
        isCover: i == 0,
      );

      if (uploadResult is ImageFailure<PropertyImage> && mounted) {
        // Property was created successfully even if an image upload
        // fails partway through — surface this distinctly rather than
        // implying the whole operation failed, since the draft exists
        // and is editable.
        setState(() {
          _errorMessage =
              'Listing created, but image ${i + 1} failed to upload: ${uploadResult.failure.message}';
        });
      }
    }

    if (_publishImmediately) {
      final publishResult = await propertyRepo.publish(property.id);
      if (publishResult is Failure<Property> && mounted) {
        setState(() {
          _errorMessage = 'Listing created but could not be published: ${publishResult.failure.message}';
        });
      }
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    // Only auto-close on a fully clean run; if something partially
    // failed, leave the screen up with the error visible so the agent
    // can see exactly what happened rather than losing that context.
    if (_errorMessage == null) {
      ref.invalidate(myPropertiesProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ListingType>(
                    initialValue: _listingType,
                    decoration: const InputDecoration(labelText: 'Listing type'),
                    items: ListingType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _listingType = value ?? _listingType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    onChanged: (v) => _currency = v.trim().toUpperCase(),
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bedroomsController,
                    decoration: const InputDecoration(labelText: 'Bedrooms'),
                    keyboardType: TextInputType.number,
                    validator: _numberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bathroomsController,
                    decoration: const InputDecoration(labelText: 'Bathrooms'),
                    keyboardType: TextInputType.number,
                    validator: _numberValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(labelText: 'Area (m²) — optional'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(labelText: 'Country'),
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resolvingLocation ? null : _useCurrentLocation,
              icon: _resolvingLocation
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: const Text('Use current location'),
            ),
            if (_locationStatusMessage != null) ...[
              const SizedBox(height: 6),
              Text(_locationStatusMessage!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: _numberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: _numberValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedImages[index].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImages.removeAt(index)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish immediately'),
              subtitle: const Text('Otherwise it is saved as a draft, visible only to you'),
              value: _publishImmediately,
              onChanged: (v) => setState(() => _publishImmediately = v),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create listing'),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (num.tryParse(value.trim()) == null) return 'Must be a number';
    return null;
  }
}
