import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/native_channel.dart';

Future<void> main() async {
  // ChannelNative 构造时就注册 MethodChannel 回调，必须先准备好 messenger。
  WidgetsFlutterBinding.ensureInitialized();
  // 随 App 分发的第三方数据的许可，显示在“查看开源许可证”里。
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'MuscleMap',
    ], await rootBundle.loadString('assets/legal/MuscleMap-LICENSE.txt'));
  });
  await runLeanDaily(ChannelNative());
}
