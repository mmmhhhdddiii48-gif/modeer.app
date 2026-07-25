import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/database/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database;
  runApp(const NukhbaGeneratorsApp());
}
