import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/photo_storage.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();
  await PhotoStorage.instance.init();
  // Best-effort early init so the timezone DB is loaded before any provider
  // touches it. Permission prompts are deferred until the user enables a
  // reminder for the first time.
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: VibesightApp()));
}
