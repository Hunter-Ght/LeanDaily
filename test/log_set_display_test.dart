import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/log/set_display.dart';

void main() {
  test('自重、附加负重和普通负重显示统一', () {
    expect(setDisplay({'ex': '俯卧撑', 'w': 0, 'reps': 9}), '自重 × 9 次');
    expect(setDisplay({'ex': '高位俯卧撑', 'w': 5, 'reps': 9}), '+5 kg × 9 次');
    expect(setDisplay({'ex': '哑铃地板卧推', 'w': 5, 'reps': 9}), '5 kg × 9 次');
    expect(setEffortLabel(8), '还能做 2 次');
    expect(setEffortLabel(''), '');
    expect(setEffortLabel(null), '');
    expect(setEffortLabel(7), '还能做 3+ 次');
    expect(setDisplay({'w': 0, 'reps': 9, 'flag': 'pain'}), '自重 × 9 次 · 有点痛');
  });
}
