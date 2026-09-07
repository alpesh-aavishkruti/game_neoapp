import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/util/app_time.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the device's timezone once, before anything can render a date. Every
  // request then declares it, so a book read in Dubai shows Dubai times even
  // though the server's own default is India.
  await AppTime.init();

  runApp(const ProviderScope(child: NeonApp()));
}
