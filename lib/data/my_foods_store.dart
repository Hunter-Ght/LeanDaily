import 'dart:convert';

import '../core/native.dart';
import '../domain/records.dart' as records;
import 'state_doc.dart' show newId;

/// 「我的食物」与「常吃整餐」：一份本地文档，随备份导出导入。
///
/// 单个食物按“1 份”的营养保存（手动输入时填的就是一份的量）；整餐保存当时的
/// 食物明细，下次一下记完。写入前重新读取并串行排队，连续两次保存不会互相覆盖。
class MyFoodsStore {
  MyFoodsStore(this.native);
  final Native native;
  static const key = 'fw-my-foods-v1';
  static const maxFoods = 200, maxMeals = 50;
  Future<void> _lane = Future<void>.value();

  Future<MyFoods> load() async {
    final raw = (await native.all())[key];
    if (raw == null) return const MyFoods();
    final doc = jsonDecode(raw);
    // 备份恢复会把“没有这份数据”写成 JSON null。
    if (doc == null) return const MyFoods();
    if (doc is! Map || doc['v'] != 1) {
      throw const FormatException('我的食物格式无效');
    }
    List<Map<String, dynamic>> rows(Object? value) => [
      for (final e in value is List ? value : const [])
        if (e is Map && '${e['id'] ?? ''}'.isNotEmpty && e['name'] is String)
          Map<String, dynamic>.from(e),
    ];
    return MyFoods(foods: rows(doc['foods']), meals: rows(doc['meals']));
  }

  Future<MyFoods> _loadForWrite() async {
    try {
      return await load();
    } on Object {
      final raw = (await native.all())[key];
      if (raw != null) await native.put('$key-corrupt', raw);
      return const MyFoods();
    }
  }

  Future<T> _write<T>(
    T Function(
      List<Map<String, dynamic>> foods,
      List<Map<String, dynamic>> meals,
    )
    change,
  ) {
    final result = _lane.then((_) async {
      final doc = await _loadForWrite();
      final foods = [...doc.foods], meals = [...doc.meals];
      final out = change(foods, meals);
      await native.put(
        key,
        jsonEncode({'v': 1, 'foods': foods, 'meals': meals}),
      );
      return out;
    });
    _lane = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String _cleanName(String name) {
    final n = name.trim();
    if (n.isEmpty || n.length > 60) {
      throw const records.DomainError('名称不能为空，最多 60 个字');
    }
    return n;
  }

  /// 保存一个食物；已有同名（不分大小写）的就更新营养。返回它的 id。
  /// [id] 给出时改的是那一条（可改名）。
  Future<String> saveFood({
    String? id,
    required String name,
    required num kcal,
    required num protein,
    num carbs = 0,
    num fat = 0,
  }) {
    final clean = _cleanName(name);
    final nutrition = records.cleanItems([
      {
        'name': clean,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      },
    ]).single;
    return _write((foods, meals) {
      final same = foods.indexWhere(
        (f) =>
            f['id'] == id ||
            (id == null && '${f['name']}'.toLowerCase() == clean.toLowerCase()),
      );
      final row = <String, dynamic>{
        'id': same >= 0 ? foods[same]['id'] : newId(),
        'name': clean,
        for (final k in ['kcal', 'protein', 'carbs', 'fat']) k: nutrition[k],
      };
      if (same >= 0) {
        foods[same] = row;
      } else {
        if (foods.length >= maxFoods) {
          throw const records.DomainError('我的食物最多 $maxFoods 个');
        }
        foods.insert(0, row);
      }
      return '${row['id']}';
    });
  }

  /// 把整餐存成一个条目；[name] 为空时用食物名拼一个。
  Future<String> saveMeal({String name = '', required List items}) {
    final cleaned = records.cleanItems(items);
    if (cleaned.length < 2) {
      throw const records.DomainError('整餐至少要有两种食物');
    }
    final label = name.trim().isEmpty
        ? records.cut(cleaned.map((e) => e['name']).join('、'), 40)
        : _cleanName(name);
    return _write((foods, meals) {
      if (meals.length >= maxMeals) {
        throw const records.DomainError('常吃整餐最多 $maxMeals 个');
      }
      final id = newId();
      meals.insert(0, {'id': id, 'name': label, 'items': cleaned});
      return id;
    });
  }

  Future<void> renameMeal(String id, String name) {
    final clean = _cleanName(name);
    return _write((foods, meals) {
      final i = meals.indexWhere((m) => m['id'] == id);
      if (i >= 0) meals[i] = {...meals[i], 'name': clean};
    });
  }

  Future<void> delete(String id) => _write((foods, meals) {
    foods.removeWhere((f) => f['id'] == id);
    meals.removeWhere((m) => m['id'] == id);
  });
}

class MyFoods {
  const MyFoods({this.foods = const [], this.meals = const []});
  final List<Map<String, dynamic>> foods, meals;
  bool get isEmpty => foods.isEmpty && meals.isEmpty;
}
