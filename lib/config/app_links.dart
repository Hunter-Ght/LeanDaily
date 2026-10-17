import 'package:flutter/foundation.dart';

/// GitHub Releases latest 接口；发布正式 Release 后可检查更新。
const String updateCheckUrl =
    'https://api.github.com/repos/Hunter-Ght/LeanDaily/releases/latest';

/// 在线隐私政策，随 main 分支中的 PRIVACY.md 更新。
const String privacyPolicyUrl =
    'https://github.com/Hunter-Ght/LeanDaily/blob/main/PRIVACY.md';

/// 项目主页。
const String repoUrl = 'https://github.com/Hunter-Ght/LeanDaily';

/// iOS has an independent release cadence. Do not read Android GitHub releases.
/// Configure only after an iOS manifest and its App Store/TestFlight URL exist.
const String iosUpdateCheckUrl = String.fromEnvironment(
  'LEANDAILY_IOS_UPDATE_URL',
);
String get platformUpdateCheckUrl => defaultTargetPlatform == TargetPlatform.iOS
    ? iosUpdateCheckUrl
    : updateCheckUrl;
