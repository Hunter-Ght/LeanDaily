import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/equipment.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/domain/records.dart';

void main() {
  tearDown(customMuscles.clear);

  test('every equipment exercise maps to real muscles except cardio', () {
    for (final e in equipmentList) {
      expect(equipmentKinds, contains(e.kind), reason: e.id);
      expect(e.exercises, isNotEmpty, reason: e.id);
      expect(e.setup, isNotEmpty, reason: e.id);
      for (final name in e.exercises) {
        final mv = musclesOf(name);
        if (e.kind == '有氧') {
          expect(mv, isNull, reason: name);
        } else {
          expect(mv?['matched'], 'exact', reason: '$name 不在肌肉表里');
        }
      }
    }
  });

  test('ids are unique and demo keys have frames', () {
    expect(equipmentById.length, equipmentList.length);
    for (final e in equipmentList.where((e) => e.demo != null)) {
      expect(LIB.containsKey(e.demo), isTrue, reason: e.id);
    }
  });

  test('aliases point to known exercises', () {
    for (final target in exerciseAliases.values) {
      expect(musclesOf(target)?['matched'], 'exact', reason: target);
    }
  });

  test('common gym names now have demonstrations', () {
    for (final name in ['坐姿划船', '腿举', '龙门架夹胸', '腿屈伸', '哑铃卧推']) {
      expect(guideFor({'name': name}), isNotNull, reason: name);
    }
  });

  test('search finds exercises across parts, by equipment and slang', () {
    List<String> names(String q) =>
        searchExercises(q).map((h) => h.name).toList();
    expect(names('倒蹬'), contains('腿举'));
    expect(names('大飞鸟'), contains('龙门架夹胸'));
    final cable = searchExercises('龙门架');
    expect(cable.map((h) => h.name), containsAll(['绳索下压', '绳索面拉']));
    expect(cable.firstWhere((h) => h.name == '绳索下压').part, '手臂');
    expect(cable.firstWhere((h) => h.name == '绳索下压').via, '龙门架 / 拉力器');
    expect(names('Leg Press'), contains('腿举'));
    expect(names('划船').toSet(), containsAll({'坐姿划船', '杠铃划船'}));
    expect(searchExercises('  '), isEmpty);
  });

  test('search uses translated names and custom exercises', () {
    expect(
      searchExercises('row', translate: (s) => s == '坐姿划船' ? 'Seated row' : s)
          .map((h) => h.name),
      contains('坐姿划船'),
    );
    expect(
      searchExercises('我的动作', extra: ['我的动作']).single.name,
      '我的动作',
    );
  });

  test('part is inferred for exercises outside the default list', () {
    expect(partOfExercise('卧推'), '胸');
    expect(partOfExercise('髋外展机'), '腿');
    expect(partOfExercise('坐姿臂屈伸机'), '手臂');
    expect(partOfExercise('绳索面拉'), '肩');
    expect(partOfExercise('跑步机'), '有氧');
    for (final e in equipmentList) {
      for (final name in e.exercises) {
        expect(defaultEx.keys, contains(partOfExercise(name)), reason: name);
      }
    }
  });

  test('equipmentFor resolves aliases', () {
    expect(equipmentFor('倒蹬').single.id, 'leg-press');
    expect(equipmentFor('哑铃卧推').map((e) => e.id), containsAll(['dumbbell', 'bench']));
    expect(equipmentFor('不存在'), isEmpty);
  });

  test('custom muscle overrides part guess but not the movement table', () {
    expect(musclesOf('我的后束动作', '背')?['primary'], 'lats');
    customMuscles['我的后束动作'] = 'delt_rear';
    final mv = musclesOf('我的后束动作', '背')!;
    expect(mv['primary'], 'delt_rear');
    expect(mv['matched'], 'custom');
    customMuscles['卧推'] = 'calves';
    expect(musclesOf('卧推')?['primary'], 'chest');
    customMuscles['坏数据'] = 'nope';
    expect(musclesOf('坏数据', '腿')?['matched'], 'part');
  });

  test('equipment search', () {
    expect(searchEquipment('').length, equipmentList.length);
    expect(searchEquipment('夹腿').single.id, 'hip-machine');
    expect(searchEquipment('pec deck').single.id, 'pec-deck');
    expect(searchEquipment('绳索下压').single.id, 'cable');
  });
}
