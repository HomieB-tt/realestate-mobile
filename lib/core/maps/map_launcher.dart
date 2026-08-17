import 'package:url_launcher/url_launcher.dart';

/// Opens the given coordinates in Google Maps.
///
/// Uses Google's "universal" maps URL rather than a platform-specific
/// scheme (e.g. `geo:` or `comgooglemaps://`) so the same call works on
/// both Android and iOS without branching: the OS resolves it to the
/// Google Maps app if installed, or the browser otherwise — no need to
/// detect which is available ourselves.
///
/// Returns false if nothing on the device could handle the URL at all
/// (extremely unlikely, since a plain https:// URL always resolves to
/// some browser) — callers should surface that as a user-facing message
/// rather than fail silently.
Future<bool> openInMaps({
  required double lat,
  required double lng,
  String? label,
}) async {
  final query = label != null && label.trim().isNotEmpty
      ? Uri.encodeComponent('$lat,$lng ($label)')
      : '$lat,$lng';

  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

  // externalApplication hands off to the Maps app/browser directly,
  // rather than opening inside an in-app webview.
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
