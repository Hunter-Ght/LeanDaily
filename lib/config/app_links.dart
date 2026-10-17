import 'package:flutter/foundation.dart';

/// GitHub Releases latest 接口；发布正式 Release 后可检查更新。
const String updateCheckUrl =
    'https://api.github.com/repos/Hunter-Ght/LeanDaily/releases/latest';

/// Public, login-free legal/support pages.
const String privacyPolicyUrl =
    'https://hunter-ght.github.io/LeanDaily/privacy/';

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

const String supportUrl = 'https://hunter-ght.github.io/LeanDaily/support/';

String localizedPage(String base, String language) =>
    language == 'en' ? base : '$base$language/';
