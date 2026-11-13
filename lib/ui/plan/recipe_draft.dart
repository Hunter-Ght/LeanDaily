import '../../domain/plan_recipe.dart';

/// 引导和重新选方案时的配方草稿：用户资料给出默认配方，用户在「你的方案」里
/// 改过的字段（天数、训练日、时长、重点、排法）单独记下来。资料里的条件（场地、
/// 经验、不方便的部位）变了，默认配方跟着变，用户已经选的几项保持不动。
class RecipeDraft {
  static const _keys = ['days', 'weekdays', 'minutes', 'focus', 'split'];
  final Map<String, dynamic> _edits = {};

  /// 在 [base]（按当前资料算出的默认配方）上叠加用户的选择。
  Map<String, dynamic> resolve(Map<String, dynamic> base) =>
      normalizeRecipe({...base, ..._edits});

  /// 记下用户在界面里改成的新配方；和默认值相同的字段不记，继续跟着资料走。
  void update(Map<String, dynamic> base, Map<String, dynamic> next) {
    final b = normalizeRecipe(base), n = normalizeRecipe(next);
    for (final k in _keys) {
      if ('${b[k]}' == '${n[k]}') {
        _edits.remove(k);
      } else {
        _edits[k] = n[k];
      }
    }
  }

  void clear() => _edits.clear();
}
