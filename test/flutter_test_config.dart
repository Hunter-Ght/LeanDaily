import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/l10n/app_messages.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppMessages.initialize();
  await testMain();
}
