import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../onboarding/onboarding_flow.dart';
import '../../app/routes.dart';
import '../kit/grouped.dart';
import '../../domain/body.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/menu.dart';
import '../kit/sheet.dart';
import 'settings/profile_controls.dart';
import 'settings/profile_plan_selection.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, this.onChoosePlan});

  /// The shell can supply the training arrangement entry without replacing a plan.
  final VoidCallback? onChoosePlan;
  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  Profile? _profile;
  bool _initialized = false,
      _busy = false,
      _customKcal = false,
      _customProtein = false;
  String? _editing;
  String _kcal = '', _protein = '', _error = '', _original = '';
  final _goal = ValueNotifier<double>(11);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialize();
  }

  void _initialize() {
    if (_initialized) return;
    _initialized = true;
    final app = context.app;
    _profile = app.profile == null
        ? null
        : {
            ...app.profile!,
            'limits': List<String>.from(app.profile!['limits'] as List),
          };
    if (_profile != null) {
      _goal.value =
          (app.targetPrefs['goalBodyFat'] as num? ??
                  _profile!['goalBodyFatPct'] as num? ??
                  (_profile!['sex'] == 'male' ? 11 : 20))
              .toDouble();
      _customKcal = app.targetPrefs['kcalOverride'] != null;
      _customProtein = app.targetPrefs['proteinOverride'] != null;
      _kcal = '${app.kcalGoal}';
      _protein = '${app.proteinGoal}';
    }
    _original = _snapshot();
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  String _snapshot() => jsonEncode([
    _profile,
    _goal.value,
    _customKcal,
    _customProtein,
    _kcal,
    _protein,
  ]);
  Targets get _targets => buildTargets(_profile!, goalOverride: _goal.value);
  double get _floor => math
      .max(bmr(_profile!), _profile!['sex'] == 'male' ? 1500 : 1200)
      .ceilToDouble();
  num _effective(String text, num fallback, num min, num max) =>
      (num.tryParse(text) ?? fallback).isFinite
      ? (num.tryParse(text) ?? fallback).clamp(min, max).round()
      : fallback;
  num get _effectiveKcal => _customKcal
      ? _effective(_kcal, _targets['kcal'] as num, _floor, double.infinity)
      : _targets['kcal'] as num;
  num get _effectiveProtein => _customProtein
      ? _effective(_protein, _targets['proteinG'] as num, 1, 220)
      : _targets['proteinG'] as num;
  Future<bool> _canClose() async =>
      !_busy &&
      (_snapshot() == _original ||
          await showConfirm(
            context,
            title: '已填的内容不会保存。',
            confirm: '放弃',
            danger: true,
          ));
  Future<bool> _save({bool close = true}) async {
    if (_busy || _profile == null) return false;
    final normalized = normalizeProfile(_profile!);
    if ((normalized['errors'] as List).isNotEmpty) {
      setState(() => _error = '请输入有效的个人资料');
      return false;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final target = _targets;
      final goal = target['goalBodyFat'] as num;
      await context.app.setProfile(
        {..._profile!, 'goalBodyFatPct': goal},
        goalBodyFat: goal,
        kcalOverride: _customKcal ? _effectiveKcal : null,
        proteinOverride: _customProtein ? _effectiveProtein : null,
      );
      _original = _snapshot();
      if (mounted && close) SheetController.of(context).close();
      return true;
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _set(String key, Object? value) => setState(() {
    _profile![key] = value;
  });
  Widget _number(String key, String label, {String suffix = ''}) => Row(
    children: [
      Expanded(
        child: FormInput(
          key: ValueKey(key),
          label: label,
          value: _profile![key] == null
              ? ''
              : numberText(_profile![key] as num),
          numeric: true,
          boxed: true,
          onChanged: (s) {
            final n = num.tryParse(s);
            if (s.isEmpty || n != null && n.isFinite) _set(key, n);
          },
        ),
      ),
      if (suffix.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(suffix, style: TextStyle(color: context.pal.secondary)),
        ),
    ],
  );
  Widget _options(String key, Map<String, String> options) => FormSegments(
    labels: options.values.toList(),
    selected: options.keys.toList().indexOf('${_profile![key]}'),
    onChanged: (i) => _set(key, options.keys.elementAt(i)),
  );
  Widget _row(
    String key,
    String label,
    String value,
    Widget editor, {
    Widget? trailing,
    String? sub,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupRow(
        label: label,
        sub: sub,
        value: value,
        trailing: trailing,
        semanticLabel: '编辑$label',
        onTap: () => setState(() => _editing = _editing == key ? null : key),
      ),
      Reveal(
        visible: _editing == key,
        child: _editing == key
            ? Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(
                  children: [
                    editor,
                    FormButton(
                      '完成',
                      plain: true,
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _editing = null);
                      },
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) {
      return AppSheet(
        title: '我的资料与目标',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormHint('还没有个人资料，先评估你的训练与饮食目标。'),
            FormButton(
              '开始评估',
              onTap: () async {
                await Navigator.of(context, rootNavigator: true).push<void>(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, _, _) =>
                        const OnboardingFlow(upgrade: true),
                    transitionDuration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 280,
                    ),
                    reverseTransitionDuration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 220,
                    ),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _initialized = false;
                    _initialize();
                  });
                }
              },
            ),
          ],
        ),
      );
    }
    const sexes = {'male': '男', 'female': '女'};
    const activities = {'sedentary': '久坐', 'light': '轻度活动', 'active': '经常活动'};
    const venues = {
      'bodyweight': '在家 · 无哑铃',
      'dumbbell': '在家 · 有哑铃',
      'gym': '健身房',
      'both': '两边都会去',
    };
    const experience = {'new': '新手', 'some': '有些经验', 'trained': '规律训练'};
    const methods = {
      'manual': '手动输入',
      'navy': '围度估算',
      'picker': '参考图估算',
      'bmi': 'BMI 估算',
    };
    final fat = estimateBodyFat(p);
    return AppSheet(
      title: '我的资料与目标',
      onSave: _save,
      saveEnabled: !_busy,
      confirmClose: _canClose,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: GroupScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: _error.isNotEmpty,
              child: _error.isNotEmpty
                  ? FormHint(_error, error: true)
                  : const SizedBox.shrink(),
            ),
            ValueListenableBuilder(
              valueListenable: _goal,
              builder: (_, _, _) => ProfileDiagnosis(
                targets: _targets,
                kcal: _effectiveKcal,
                protein: _effectiveProtein,
              ),
            ),
            const GroupHeader('身体'),
            GroupCard(
              children: [
                _row('sex', '性别', sexes[p['sex']]!, _options('sex', sexes)),
                _row(
                  'age',
                  '年龄',
                  '${p['age']} 岁',
                  _number('age', '年龄', suffix: '岁'),
                ),
                _row(
                  'heightCm',
                  '身高',
                  '${p['heightCm']} 厘米',
                  _number('heightCm', '身高', suffix: '厘米'),
                ),
                _row(
                  'weightKg',
                  '体重',
                  '${p['weightKg']} 公斤',
                  _number('weightKg', '体重', suffix: '公斤'),
                  trailing: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FormButton(
                      '记一次',
                      plain: true,
                      onTap: _busy
                          ? null
                          : () async {
                              final app = context.app;
                              final before = app.profile;
                              await openBodyLog(context);
                              if (!mounted || app.profile == null) return;
                              setState(() {
                                for (final field in ['weightKg', 'waistCm']) {
                                  if (app.profile![field] != before?[field]) {
                                    _profile![field] = app.profile![field];
                                  }
                                }
                              });
                            },
                    ),
                  ),
                ),
                _row(
                  'bodyFatPct',
                  '体脂',
                  '${fat['value']}%',
                  Column(
                    children: [
                      _options('bodyFatMethod', methods),
                      if (p['bodyFatMethod'] == 'manual' ||
                          p['bodyFatMethod'] == 'picker')
                        _number('bodyFatPct', '体脂百分比', suffix: '%'),
                      if (p['bodyFatMethod'] == 'picker')
                        const FormHint('参考档位估算，误差约 ±4%。'),
                      if (p['bodyFatMethod'] == 'navy') ...[
                        _number('neckCm', '颈围', suffix: '厘米'),
                        if (p['sex'] == 'female')
                          _number('hipCm', '臀围', suffix: '厘米'),
                        const FormHint('填写腰围和颈围；女性还需填写臀围。围度不完整时使用 BMI 估算。'),
                      ],
                    ],
                  ),
                  sub: methods[fat['method']],
                ),
                _row(
                  'waistCm',
                  '腰围',
                  p['waistCm'] == null ? '未填写' : '${p['waistCm']} 厘米',
                  _number('waistCm', '腰围', suffix: '厘米'),
                ),
              ],
            ),
            const GroupHeader('训练'),
            GroupCard(
              children: [
                _row(
                  'activity',
                  '活动量',
                  activities[p['activity']]!,
                  _options('activity', activities),
                ),
                _row(
                  'venue',
                  '场地',
                  venues[p['venue']]!,
                  _options('venue', venues),
                ),
                _row(
                  'daysPerWeek',
                  '每周天数',
                  '${p['daysPerWeek']} 天',
                  FormSegments(
                    labels: const ['2', '3', '4', '5', '6'],
                    selected: (p['daysPerWeek'] as num).toInt() - 2,
                    onChanged: (i) => _set('daysPerWeek', i + 2),
                  ),
                ),
                _row(
                  'experience',
                  '经验',
                  experience[p['experience']]!,
                  _options('experience', experience),
                ),
                _row(
                  'limits',
                  '不方便的部位',
                  (p['limits'] as List).isEmpty
                      ? '无'
                      : (p['limits'] as List).join('、'),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final name in ['肩', '腰', '膝', '腕', '肘', '髋'])
                        FormCheck(
                          label: name,
                          value: (p['limits'] as List).contains(name),
                          onChanged: (on) {
                            final limits = List<String>.from(
                              p['limits'] as List,
                            );
                            on ? limits.add(name) : limits.remove(name);
                            _set('limits', limits);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const GroupHeader('目标'),
            GroupCard(
              children: [
                ValueListenableBuilder(
                  valueListenable: _goal,
                  builder: (_, _, _) => _row(
                    'goal',
                    '目标体脂',
                    '${numberText(_targets['goalBodyFat'] as num)}%',
                    Column(
                      children: [
                        FormInput(
                          label: '目标体脂',
                          value: numberText(_goal.value),
                          numeric: true,
                          onChanged: (s) {
                            final n = double.tryParse(s);
                            if (n != null && n.isFinite) _goal.value = n;
                          },
                        ),
                        ProfileGoalSlider(
                          value: (_targets['goalBodyFat'] as num).toDouble(),
                          min: p['sex'] == 'male' ? 8 : 16,
                          max: p['sex'] == 'male' ? 25 : 35,
                          onChanged: (v) => _goal.value = v,
                        ),
                      ],
                    ),
                  ),
                ),
                GroupRow(
                  label: '自定义每日热量',
                  trailing: FormSwitch(
                    label: '自定义每日热量',
                    value: _customKcal,
                    onChanged: (v) => setState(() => _customKcal = v),
                  ),
                ),
                Reveal(
                  visible: _customKcal,
                  child: _customKcal
                      ? GroupRow(
                          label: '每日热量',
                          chevron: false,
                          trailing: FormInput(
                            label: '每日热量',
                            value: _kcal,
                            width: 94,
                            numeric: true,
                            onChanged: (s) => setState(() => _kcal = s),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Reveal(
                  visible: _customKcal && num.tryParse(_kcal) != _effectiveKcal,
                  child: _customKcal && num.tryParse(_kcal) != _effectiveKcal
                      ? FormHint('每日热量不低于安全下限：${numberText(_floor)} 千卡')
                      : const SizedBox.shrink(),
                ),
                GroupRow(
                  label: '自定义每日蛋白',
                  trailing: FormSwitch(
                    label: '自定义每日蛋白',
                    value: _customProtein,
                    onChanged: (v) => setState(() => _customProtein = v),
                  ),
                ),
                Reveal(
                  visible: _customProtein,
                  child: _customProtein
                      ? GroupRow(
                          label: '每日蛋白',
                          chevron: false,
                          trailing: FormInput(
                            label: '每日蛋白',
                            value: _protein,
                            width: 94,
                            numeric: true,
                            onChanged: (s) => setState(() => _protein = s),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_customProtein &&
                    num.tryParse(_protein) != _effectiveProtein)
                  const FormHint('每日蛋白已限制在 1–220 克'),
              ],
            ),
            Reveal(
              visible: !_customKcal || !_customProtein,
              child: !_customKcal || !_customProtein
                  ? const GroupFooter('关闭自定义时，目标跟随个人资料自动计算。')
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 18),
            FormButton(
              _busy ? '正在保存…' : '保存',
              onTap: _busy ? null : _save,
              filled: true,
            ),
            const SizedBox(height: 12),
            FormButton(
              '用新资料重新选计划',
              plain: true,
              onTap: _busy
                  ? null
                  : () async {
                      final saved = await _save(close: false);
                      if (!mounted || !context.mounted || !saved) return;
                      {
                        if (widget.onChoosePlan != null) {
                          widget.onChoosePlan!();
                        } else {
                          await Navigator.of(
                            context,
                            rootNavigator: true,
                          ).push<void>(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, _, _) =>
                                  const ProfilePlanSelection(),
                              transitionDuration: Duration(
                                milliseconds:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : 280,
                              ),
                              reverseTransitionDuration: Duration(
                                milliseconds:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : 220,
                              ),
                              transitionsBuilder: (_, animation, _, child) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
