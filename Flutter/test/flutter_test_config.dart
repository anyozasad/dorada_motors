import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Los tests corren en Linux; las apps Android tienen su plugin sqflite nativo.
/// Inicializar SQLite FFI para probar la misma persistencia en CI.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
