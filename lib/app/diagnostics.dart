import 'package:flutter/foundation.dart';

/// 启动过程和未捕获错误的记录，只用于在界面上显示“卡在哪一步”。
class Diagnostics {
  Diagnostics._();

  /// 当前步骤的文字。
  static final ValueNotifier<String> step = ValueNotifier('启动');
  static final ValueNotifier<List<String>> errors = ValueNotifier(const []);

  static void at(String s) => step.value = s;

  static void error(Object e, [StackTrace? st]) {
    final line = '$e${st == null ? '' : '\n${st.toString().split('\n').take(6).join('\n')}'}';
    errors.value = [...errors.value.take(4), line];
  }
}
