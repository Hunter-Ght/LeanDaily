import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/native_channel.dart';

Future<void> main() async {
  // ChannelNative 构造时就注册 MethodChannel 回调，必须先准备好 messenger。
  WidgetsFlutterBinding.ensureInitialized();
  await runLeanDaily(ChannelNative());
}
