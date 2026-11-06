import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/body_figure.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppMessages.initialize();
  BodyFigure.animateBreath = false;
  await testMain();
}
