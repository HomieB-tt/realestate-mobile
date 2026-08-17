# Real Estate MVP — Mobile (Flutter, Riverpod, Feature-First)

## Structure

```
mobile/
├── lib/
│   ├── core/
│   │   ├── network/
│   │   │   ├── supabase_client.dart   # Auth ONLY — see note below
│   │   │   └── api_client.dart        # Talks to the custom backend, attaches JWT
│   │   ├── theme/app_theme.dart
│   │   ├── constants/env.dart          # --dart-define config
│   │   └── error/                      # Shared AppFailure + Dio error mapping
│   ├── features/
│   │   ├── auth/          # domain / data / presentation
│   │   ├── property/      # domain / data / presentation
│   │   └── viewing/       # domain / data / presentation
│   ├── app.dart            # Root widget, auth-gated routing
│   └── main.dart
├── analysis_options.yaml
└── pubspec.yaml
```

## Important architectural note: two different backends, on purpose

The mobile app talks to **two different servers**, matching the spec:

- **Supabase directly** — for Auth only (`core/network/supabase_client.dart`). Sign-up/sign-in/session management goes straight to Supabase, same as the architecture doc specifies ("Client apps authenticate via Supabase Auth").
- **The custom backend** (`core/network/api_client.dart`) — for every property/viewing operation. Every outgoing request auto-attaches `Authorization: Bearer <supabase-jwt>`, which the backend's middleware independently re-verifies against Supabase's JWKS. The mobile app never talks to Supabase's own REST API for property/viewing data — it always goes through the custom backend, so business rules (ownership checks, publish rules, ACID booking) are enforced in one place.

## Running it

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

`API_BASE_URL` defaults to `10.0.2.2` (Android emulator's alias for the host machine's `localhost`). For iOS simulator, use `http://localhost:8080/api/v1` instead. For a physical device, use your machine's LAN IP.

## ⚠️ Not yet compiler-verified

Unlike the backend (which was `tsc --noEmit`'d) and the SQL migration (which was run against a real local Postgres+PostGIS instance), **this Flutter code has not been run through `flutter analyze` or `flutter pub get`** — there's no Flutter/Dart SDK available in the environment this was generated in, and it isn't on the small allow-list of package registries reachable here (npm/pip/cargo only).

The code was written carefully against Dart 3 syntax (sealed classes, pattern-matching `switch` expressions) and each file was manually reviewed for consistency, but it hasn't been compiled. Please run:

```bash
flutter pub get
flutter analyze
```

as your first step, and paste back any errors — same troubleshooting loop we used for the backend.

## Required native permissions (Android)

Two new packages were added this round — `geolocator` and `image_picker` —
and both need entries in `android/app/src/main/AndroidManifest.xml`, which
`flutter create` generated on your machine and isn't something I can edit
directly. Add these `<uses-permission>` entries as siblings of
`<application>`, inside the outer `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

`image_picker` on Android 13+ uses the system Photo Picker, which needs no
extra runtime permission for gallery access. If you also want camera
capture (not just gallery), add:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Waydroid/emulators without a real GPS may report `LocationServiceDisabled`
or an inaccurate/zeroed position — the search screen falls back to the
demo coordinate automatically in that case (see `PropertyListScreen`), so
this isn't a blocker for testing, just something to expect until you're
on a device with real GPS.

## New in this round

- **Navigation shell** (`features/shell/root_shell.dart`) — bottom tabs: Search, Bookings, Listings (agent-only), Account. Previously there was no way to sign out from the app at all; that's now on the Account tab.
- **Create listing** (`features/property/presentation/screens/create_property_screen.dart`) — full form + multi-image picker, with a "publish immediately" toggle.
- **Image upload** — goes directly to Supabase (Storage + the `property_images` table), NOT through the custom backend, since the backend never got a `property_images` endpoint. Authorization is enforced entirely by the RLS policies already in `001_init_schema.sql` — worth being aware that this is the one write path in the app where there's no server-side check backing up the database, only RLS itself.
- **My Listings** / **My Bookings** screens — now have actual UI (the providers existed before, nothing consumed them).
- **Real geolocation** — `core/location/location_service.dart`, with graceful fallback to the demo coordinate if permissions/services aren't available.
- **Publish from the detail screen** — agents can now publish a draft without going back to a list view, if they're viewing their own draft.



## Auth flow

**Password sign-in** is what's currently wired into `LoginScreen`. OTP
(`AuthRepository.sendOtp()`/`verifyOtp()`) is still implemented on the
repository and matches the architecture spec's preferred flow, but isn't
in the UI right now — Supabase restricted email template customization
(needed to show the raw OTP code rather than just a magic link) behind
custom SMTP as of a June 2026 anti-abuse policy change. Revisit OTP once
custom SMTP is set up; swapping the UI back is a small, contained change
since the repository layer already supports both.

## What's implemented vs. stubbed

**Implemented:** auth (password), property search (radius-based, real geolocation with fallback), property detail with photo strip, create-listing form with multi-image upload, owner-publish from the detail screen, book-a-viewing flow with 409 slot-conflict surfaced distinctly, My Listings (agent), My Bookings (client, with cancel), sign-out.

**Not yet built:** edit-listing screen (create-only, no update form yet), image reordering/cover selection after upload, agent-side viewing confirmation UI (the `confirm()` repository method exists, no screen calls it), OTP re-enabled once custom SMTP is set up, and this UI hasn't had a visual design pass — it's functional Material 3 defaults.

