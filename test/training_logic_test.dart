import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/training/training_logic.dart';
import 'package:leandaily/ui/today/today_model.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('保存沿用旧字段，反馈更新原组且保留标识', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    final model = TodayModel(h.controller);
    final e = Map<String, dynamic>.from(model.items.first['ex']);
    final id = await saveTrainingSet(h.controller, model, e, 9, 0);
    Map row() => jsonDecode(h.native.docs['android-state']!)['sets'][id] as Map;
    expect(row(), containsPair('reps', 9));
    expect(row(), containsPair('w', 0));
    expect(row(), containsPair('type', '正式'));
    expect(row()['rpe'], isNull);
    expect(row().containsKey('flag'), isFalse);
    final ts = row()['ts'];
    await trainingFeedback(h.controller, id, remaining: 2, flag: 'pain');
    expect(row()['rpe'], 8);
    expect(row()['flag'], 'pain');
    expect(row()['ts'], ts);
    expect(row()['notes'], e['side'] == true ? '单边' : '');
    h.controller.rest.clear();
    await tester.pump(const Duration(seconds: 4));
  });
  test('上一组优先，自重不显示负重', () {
    final e = <String, dynamic>{'min': 8, 'weight': 0};
    expect(
      trainingReps(
        e,
        {'reps': 10},
        [
          {'reps': 11},
        ],
      ),
      11,
    );
    expect(
      trainingWeight(
        e,
        {'weight': 5},
        [
          {'w': 6},
        ],
      ),
      6,
    );
    expect(trainingHasLoad(e, []), false);
    expect(trainingHasLoad({'name': '俯卧撑', 'weight': 5}, []), false);
    expect(
      trainingHasLoad({'name': '高位下拉', 'machine': true, 'weight': 0}, []),
      true,
    );
  });
}
