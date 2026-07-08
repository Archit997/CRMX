import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/config/supabase_config.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await EnvConfig.load();

  // Validate required environment variables
  EnvConfig.validate();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  runApp(
    // Wrap app with ProviderScope for Riverpod
    const ProviderScope(
      child: CRMXMobileApp(),
    ),
  );
}
