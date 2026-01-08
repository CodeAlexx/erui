import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize local storage service
  await StorageService.init();

  runApp(
    const ProviderScope(
      child: EriUIApp(),
    ),
  );
}
