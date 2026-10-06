import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/telemetry/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Usage analytics: off unless the build carries ET_APP_ID + ET_WRITE_KEY
  // (lib/core/telemetry/telemetry.dart). Waits at most 2 s, never throws.
  await Telemetry.init();

  runApp(const ProviderScope(child: App()));
}
