import 'dart:async';

// Cold-start ordering must run without the normal test catalog/binding preload.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
