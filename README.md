# gate_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Usage analytics (event tracker)

`lib/core/telemetry/telemetry.dart`, using the in-house `vistar_event_tracker`
SDK (vendored in `packages/`, see its `VENDORED.md`). Read in the Platform
Console under Analytics > Event tracker.

**Off unless the build gets both `ET_APP_ID` and `ET_WRITE_KEY`**; without them
nothing is initialised and the app behaves exactly as before. To switch it on:

- Web (Cloudflare Workers Builds, build command set in the Cloudflare
  dashboard): add the build variables `ET_APP_ID=gate_app` and `ET_WRITE_KEY`,
  and append
  ` --dart-define=ET_APP_ID=$ET_APP_ID --dart-define=ET_WRITE_KEY=$ET_WRITE_KEY`
  to the `flutter build web` command.
- APK: `flutter build apk --release --dart-define=ET_APP_ID=gate_app --dart-define=ET_WRITE_KEY=wk_...`

Register the app and get its write key in the Platform Console, Settings >
Event tracker. Events go to the host of `Env.baseUrl` (a UAT build reports to
UAT); `ET_BASE_URL` overrides it.

Sent: screen views by route pattern (ids, plates and reference numbers
replaced), sign-in / sign-out (the user as `gate:<id>` with role and
organisation code), named actions from successful writes (`gate_entry_created`,
`challan_scanned`, `gate_out_recorded`, `gate_entry_approved`, ... see
`_actions`), failed API calls (5xx / no connection) and client errors by type.
Never sent: request or response bodies, names, phone numbers, vehicle plates,
driver or vendor names, challan / invoice numbers, photos or recognised (OCR)
text. Nothing is awaited by a screen, a gate entry, a sign-in or a sign-out;
start-up waits at most 2 s; the event queue is capped at 200.
