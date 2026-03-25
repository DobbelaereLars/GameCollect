import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep running even if .env is missing; the Discover page shows a clear message.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  runApp(const GameCollectApp());
}
