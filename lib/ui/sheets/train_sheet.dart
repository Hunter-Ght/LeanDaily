import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/equipment.dart';
import '../../domain/guide.dart';
import '../../domain/movements.dart';
import '../../domain/records.dart' as records;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart';
import '../kit/exercise_thumb.dart';
import '../kit/menu.dart';
import '../kit/number_field.dart' show SheetInput;
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';
import 'train/effort_editor.dart';
import 'train/exercise_info.dart';
import 'train/stepper_field.dart';
import 'equipment_sheet.dart' show EquipmentDetail, EquipmentGrid;
import '../../domain/free_training.dart';
import '../../app/routes.dart' show openAlternatives, openGuide, openMyGym;

// 上次选动作的方式：推荐 / 按部位 / 按器械；首次默认推荐。
String _lastMode = '推荐';

// 记一组弹层里的三级页：选动作 → 器械详情（可选）→ 记组。
enum _Page { pick, equipment, log }

class TrainSheet extends StatefulWidget {
  const TrainSheet({super.key, this.preset});

  @visibleForTesting
  static void resetPickerMode() => _lastMode = '推荐';

  final Map<String, dynamic>? preset;
  @override
  State<TrainSheet> createState() => _TrainSheetState();
}

class _TrainSheetState extends State<TrainSheet> {
  static String _lastPart = '胸';
  late String _part, _exercise, _date;
  String _query = '', _note = '', _error = '';
  late bool _unilateral;
  // 当前页；记组页是从哪一页进来的（null = 外部直接带着动作打开，没有上一层）
  late _Page _page;
  _Page? _backTo;
  int _dir = 1;
  Equipment? _equipment;
  String _equipSel = '';
  double _pickerOffset = 0;
  bool _initialized = false, _saving = false;
  // 选动作的方式；恢复状态缓存（换动作或选了肌肉后重算）；展开全部肌肉
  late String _mode;
  bool _allMuscles = false;
  // 记组页“换一个”按钮：当前动作有没有替代动作（按动作缓存）
  String? _altKey;
  bool _altHas = false;
  Map<String, dynamic>? _status;
  int _seq = 0;
  late List<Map<String, dynamic>> _rows;
  final _scroll = ScrollController();
  final _weightFocus = <int, FocusNode>{};
  FocusNode _focus(Map row) =>
      _weightFocus.putIfAbsent(row['id'] as int, FocusNode.new);
  void _focusWeight(Map row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = _focus(row);
      focus.requestFocus();
      if (focus.context != null) {
        Scrollable.ensureVisible(focus.context!, alignment: 0.4);
      }
    });
  }

  Map<String, dynamic> _row([Map? src]) => {
    'id': _seq++,
    'weight': '${src?['weight'] ?? ''}',
    'reps': '${src?['reps'] ?? ''}',
    'rpe': '${src?['rpe'] ?? ''}',
    'type': src?['type'] ?? '正式',
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final p = widget.preset ?? {};
    _date = context.app.date;
    _part = records.defaultEx.containsKey(p['part'] ?? _lastPart)
        ? (p['part'] ?? _lastPart) as String
        : '胸';
    _mode = p['mode'] == 'recommend' ? '推荐' : _lastMode;
    _exercise = p['exercise'] as String? ?? '';
    _page = _exercise.isEmpty ? _Page.pick : _Page.log;
    _unilateral = p['uni'] == true;
    _rows = (p['rows'] as List? ?? []).map((r) => _row(r as Map)).toList();
    if (_rows.isEmpty) _rows.add(_row());
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final focus in _weightFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  bool get _filled => _rows.any(
    (r) =>
        '${r['weight']}'.trim().isNotEmpty || '${r['reps']}'.trim().isNotEmpty,
  );
  Map? _last(String name) =>
      (context.app.repo.recentByExercise()['last'] as Map)[name] as Map?;
  List<Map> _lastSets(String name) =>
      ((_last(name)?['sets'] as List?) ?? []).cast<Map>();
  String _fmt(Object? v) => '$v'.replaceFirst(RegExp(r'\.0$'), '');
  String _lastLine(String name) => lastLineOf(_last(name));

  Future<void> _pick(String name, {String? part}) async {
    if (_filled && _exercise.isNotEmpty && _exercise != name) {
      if (!await showConfirm(
        context,
        title: '换动作会清掉已填的组',
        confirm: '更换',
        danger: true,
      )) {
        return;
      }
      if (!mounted) return;
      _rows = [_row()];
    }
    final last = _lastSets(name);
    _status = null;
    // 按名字关键字猜到了肌肉，部位跟着猜测走，别沿用上一个动作的部位。
    part ??= musclesOf(name, _part)?['matched'] == 'keyword'
        ? partOfExercise(name)
        : null;
    final from = _page == _Page.log ? _backTo : _page;
    _show(_Page.log, () {
      _backTo = from;
      if (part != null) _part = part;
      _exercise = name;
      if (_last(name) != null) {
        _unilateral = last.any((s) => '${s['notes']}'.contains('单边'));
      } else if (name.contains('哑铃')) {
        _unilateral = true;
      }
      if (!_filled) _rows = [_row()];
    });
  }

  // 换页：前进向左推、返回向右推；选动作页的滚动位置回来时恢复。
  void _show(_Page next, [VoidCallback? change]) {
    if (_page == _Page.pick && _scroll.hasClients) {
      _pickerOffset = _scroll.offset;
    }
    final moved = next != _page;
    setState(() {
      change?.call();
      if (moved) _dir = next.index > _page.index ? 1 : -1;
      _page = next;
    });
    if (!_scroll.hasClients) return;
    final target = moved && next == _Page.pick ? _pickerOffset : 0.0;
    void apply() {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(target.clamp(0.0, max));
    }

    apply();
    if (target > 0) {
      // 内容高度在转场动画里才长到位，位置再校一次。
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      Future.delayed(const Duration(milliseconds: 320), apply);
    }
  }

  bool get _hasBack =>
      _page == _Page.equipment || (_page == _Page.log && _backTo != null);

  // 左上角“返回”、系统返回手势都走这里：回上一层，不关弹层。
  Future<void> _back() async {
    if (_page == _Page.equipment) {
      _show(_Page.pick);
      return;
    }
    if (_filled &&
        !await showConfirm(
          context,
          title: '返回会清掉已填的组',
          confirm: '返回',
          danger: true,
        )) {
      return;
    }
    if (!mounted) return;
    _show(_backTo!, () {
      _rows = [_row()];
      _exercise = '';
      _unilateral = false;
      _status = null;
      _error = '';
    });
  }

  Future<bool> _closeOrBack() async {
    if (_hasBack) {
      await _back();
      return false;
    }
    return _confirmClose();
  }

  Future<void> _applyLast() async {
    if (_filled &&
        !await showConfirm(
          context,
          title: '用上次的组替换现在填的？',
          confirm: '替换',
          danger: true,
        )) {
      return;
    }
    if (!mounted) return;
    final last = _lastSets(_exercise);
    setState(() {
      _rows = last.map(_row).toList();
      _unilateral = last.any((s) => '${s['notes']}'.contains('单边'));
    });
  }

  Future<bool> _confirmClose() async =>
      !_saving &&
      (!_filled && _note.trim().isEmpty ||
          await showConfirm(
            context,
            title: '放弃这次记录？',
            message: '已填的内容不会保存。',
            confirm: '放弃',
            danger: true,
          ));
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = '');
    if (_exercise.isEmpty) {
      _show(_Page.pick, () => _error = '先选择动作');
      return;
    }
    final sets = _rows
        .where(
          (r) =>
              '${r['weight']}'.trim().isNotEmpty ||
              '${r['reps']}'.trim().isNotEmpty,
        )
        .map(
          (r) => <String, dynamic>{
            'weight': records.number(r['weight']),
            'reps': records.number(r['reps']),
            'rpe': '${r['rpe']}'.trim().isEmpty
                ? null
                : records.number(r['rpe']),
            'type': r['type'],
          },
        )
        .toList();
    if (sets.isEmpty) {
      setState(() => _error = '至少填一组');
      return;
    }
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      final w = s['weight'] as double, reps = s['reps'] as double;
      if (!(w >= 0) || !(reps >= 1) || reps != reps.truncateToDouble()) {
        setState(() => _error = '第 ${i + 1} 组的重量或次数不对');
        return;
      }
    }
    for (var i = 0; i < sets.length; i++) {
      final rpe = sets[i]['rpe'] as double?;
      if (rpe != null && !(rpe >= 1 && rpe <= 10)) {
        setState(() => _error = '第 ${i + 1} 组吃力程度要在 1 到 10');
        return;
      }
    }
    final app = context.app;
    setState(() => _saving = true);
    try {
      await app.repo.addSets(
        date: _date,
        part: _part,
        exercise: _exercise,
        unilateral: _unilateral,
        dayNote: _note.trim(),
        rows: sets,
      );
      app.startRest();
      app.toast.show('已记下');
      app.showRecordSection('训练');
      app.haptics.saved();
      if (mounted) SheetController.of(context).close();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppController.message(e);
        });
      }
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: LText(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.pal.text,
      ),
    ),
  );
  Widget _card(Widget child, {double padding = 16}) => Container(
    clipBehavior: Clip.antiAlias,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppSheet(
        title: _page == _Page.equipment ? _equipment!.name : '记一组',
        cancelLabel: _hasBack ? '返回' : '取消',
        // 记组页的保存在底部橙色「记录这一组」（拇指区、训练动作的唯一主按钮），顶栏不再重复一个。
        confirmClose: _closeOrBack,
        scrollController: _scroll,
        footer: _page == _Page.pick
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _page == _Page.equipment
                          ? SheetButton(
                              '记录这个动作',
                              () => _pick(
                                _equipSel,
                                part: partOfExercise(_equipSel),
                              ),
                              primary: true,
                            )
                          : SheetButton(
                              '记录这一组',
                              _saving ? null : _save,
                              primary: true,
                            ),
                    ),
                  ],
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: _error.isNotEmpty,
              child: _error.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: LText(_error, style: TextStyle(color: p.err)),
                    )
                  : const SizedBox.shrink(),
            ),
            PushSwitcher(
              direction: _dir,
              child: Column(
                key: ValueKey(_page),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (_page) {
                  _Page.pick => _picker(),
                  _Page.equipment => [
                    EquipmentDetail(
                      equipment: _equipment!,
                      selected: _equipSel,
                      onSelect: (name) => setState(() => _equipSel = name),
                    ),
                  ],
                  _Page.log => _logger(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _picker() {
    final p = context.pal;
    final messages = AppMessages.of(context);
    final byPart = context.app.repo.recentByExercise()['byPart'] as Map;
    final recentAll = (byPart[_part] as List? ?? []).cast<String>();
    final q = _query.trim();
    // 搜索时不分部位：把所有部位练过的动作也放进检索范围
    final hits = q.isEmpty
        ? const <ExerciseHit>[]
        : searchExercises(
            q,
            extra: [
              for (final l in byPart.values) ...(l as List).cast<String>(),
            ],
            translate: messages.text,
          );
    final recent = recentAll;
    final common = (records.defaultEx[_part] ?? <String>[])
        .where((s) => !recentAll.contains(s))
        .toList();
    final custom = q.isNotEmpty && !hits.any((h) => h.name == q);
    return [
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SheetSegments(
          labels: const ['推荐', '按部位', '按器械'],
          value: _mode,
          onChanged: (s) => setState(() {
            _mode = s;
            _lastMode = s;
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.only(left: 10),
          height: 44,
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              AppIcon('search', size: 18, color: p.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: SheetInput(
                  value: _query,
                  onChanged: (s) => setState(() => _query = s),
                  label: '搜索或输入动作',
                  placeholder: '搜索或输入动作',
                  onSubmitted: (s) {
                    if (s.trim().isNotEmpty) {
                      _submit(hits, s.trim());
                    }
                  },
                ),
              ),
              if (_query.isNotEmpty)
                SheetButton(
                  '清除搜索',
                  () => setState(() => _query = ''),
                  icon: 'close',
                  iconOnly: true,
                ),
            ],
          ),
        ),
      ),
      if (q.isEmpty && _mode == '按部位') ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              for (final part in records.defaultEx.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    label: AppMessages.of(context).text(part),
                    selected: part == _part,
                    child: Pressable(
                      onTap: () => setState(() {
                        _part = part;
                        _lastPart = part;
                      }),
                      child: Container(
                        width: 76,
                        height: 84,
                        decoration: BoxDecoration(
                          color: _part == part ? p.primary : p.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _part == part
                                    ? p.onPrimary.withValues(alpha: 0.16)
                                    : p.fill2,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AppIcon(
                                  partIcon(part),
                                  size: 17,
                                  color: _part == part ? p.onPrimary : p.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LText(
                              part,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _part == part ? p.onPrimary : p.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (q.isNotEmpty && hits.isNotEmpty)
              _card(
                Column(children: [for (final h in hits) _hitRow(h)]),
                padding: 0,
              ),
            if (q.isEmpty && _mode == '推荐') ..._recommendation(),
            if (q.isEmpty && _mode == '按器械') ...[
              _gymLine(),
              EquipmentGrid(onOpen: _openEquipment, owned: context.app.myGym),
            ],
            if (q.isEmpty && _mode == '按部位') ...[
              if (recent.isNotEmpty) ...[
                _label('最近练过'),
                _card(
                  Column(
                    children: [for (final name in recent) _recentCard(name)],
                  ),
                  padding: 0,
                ),
              ],
              if (common.isNotEmpty) ...[
                _label('常用'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final name in common) _commonChip(name)],
                ),
              ],
            ],
            if (custom)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SheetButton('使用「$q」', () => _pick(q), icon: 'plus'),
              ),
            if (custom) LText('不在列表里，就用这个名字', style: AppText.hint(p)),
          ],
        ),
      ),
    ];
  }

  // 回车：有结果选第一个（同名优先），没有就当自定义动作。
  void _submit(List<ExerciseHit> hits, String q) {
    if (hits.isEmpty) {
      _pick(q);
      return;
    }
    final hit = hits.firstWhere((h) => h.name == q, orElse: () => hits.first);
    _pick(hit.name, part: hit.part);
  }

  // 器械被占：打开替代弹层，选中后按普通换动作流程处理。
  Future<void> _swap(String exercise) async {
    final name = await openAlternatives(context, exercise);
    if (name == null || !mounted) return;
    await _pick(name, part: partOfExercise(name));
  }

  Future<void> _editGym() async {
    await openMyGym(context);
    if (mounted) setState(() {});
  }

  // 我的健身房入口：一行清晰的可点行，正文色加粗 + 小箭头。
  Widget _gymEntry(String text, Key key) {
    final p = context.pal;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: _editGym,
        child: Container(
          key: key,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AppIcon('weight', size: 18, color: p.text),
              const SizedBox(width: 10),
              Expanded(
                child: LText(
                  text,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppIcon('right', size: 14, color: p.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  // 按器械页顶部：我的健身房当前状态和编辑入口。
  Widget _gymLine() {
    final n = context.app.myGym.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _gymEntry(
        n == 0 ? '我的健身房：不限 · 编辑' : '我的健身房：已选 $n 台 · 编辑',
        const ValueKey('gym-line'),
      ),
    );
  }

  // 推荐页：按肌肉恢复推荐现在能练的动作，再列出还在恢复的肌群。
  List<Widget> _recommendation() {
    final p = context.pal;
    final app = context.app;
    final owned = app.myGym;
    _status ??= recoveryStatus(app);
    final done = ((app.repo.recentByExercise()['last'] as Map).keys)
        .cast<String>()
        .toSet();
    final groups = recommendNow(_status!, owned: owned, done: done);
    final recovering = recoveringGroups(_status!, owned: owned);
    return [
      _gymEntry(
        owned.isEmpty ? '设置我的健身房' : '只看我的健身房（${owned.length} 台器械）',
        const ValueKey('gym-entry'),
      ),
      if (groups.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            key: const ValueKey('reco-empty'),
            children: [
              LText(
                '现在没有适合练的动作',
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              LText(
                '肌肉都还在恢复，或“我的健身房”里的器械太少。也可以切到「按部位」自己选。',
                textAlign: TextAlign.center,
                style: AppText.hint(p),
              ),
            ],
          ),
        ),
      for (final g in groups) ...[
        Padding(
          key: ValueKey('reco-group-${g.group}'),
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          // 肌群名和状态分别翻译，状态用恢复青小标签。
          child: Row(
            children: [
              Text(
                AppMessages.of(context).text(g.name),
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              RecoveryTag(
                ExerciseInfo(
                  ready: true,
                  recovery: g.daysSince == null
                      ? '还没练过'
                      : g.daysSince! < 1
                      ? '今天练过'
                      : '${g.daysSince!.floor()} 天前练过',
                ),
              ),
            ],
          ),
        ),
        _card(
          Column(children: [for (final e in g.exercises) _recoRow(e)]),
          padding: 0,
        ),
      ],
      if (recovering.isNotEmpty) ...[
        _label('还在恢复'),
        // 只展示：这些肌群现在不适合练，不提供入口。
        _card(
          Column(
            children: [
              for (final r in recovering)
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: p.sep, width: 0.5),
                    ),
                  ),
                  child: LText(
                    '${r.name} · ${daysLeftText(r.daysLeft)}',
                    style: TextStyle(color: p.secondary, fontSize: 15),
                  ),
                ),
            ],
          ),
          padding: 0,
        ),
      ],
    ];
  }

  // 推荐行只留一项信息：名字里已含器械名就写练的位置，否则写器械。
  String _rowInfo(String? equipment, String name, String part) {
    final messages = AppMessages.of(context);
    final plain = plainMusclesOf(messages, name, part);
    final base = messages.text(equipment ?? '徒手');
    if (equipment == null || name.contains(equipment)) {
      return plain.isEmpty ? base : plain;
    }
    return base;
  }

  Widget _recoRow(FreeExercise e) {
    final p = context.pal;
    return Container(
      key: ValueKey('reco-${e.name}'),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sep, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: AppMessages.of(context).text(e.name),
              child: Pressable(
                onTap: () => _pick(e.name, part: e.part),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      ExerciseThumb(
                        ex: {'name': e.name, 'part': e.part},
                        size: 44,
                        radius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                LText(
                                  e.name,
                                  style: TextStyle(
                                    color: p.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (e.done)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.fill,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: LText(
                                      '练过',
                                      style: TextStyle(
                                        color: p.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            LText(
                              _rowInfo(e.equipment, e.name, e.part),
                              style: AppText.hint(p),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SheetButton(
            '换一个',
            () => _swap(e.name),
            key: ValueKey('swap-${e.name}'),
            icon: 'repeat',
            iconOnly: true,
          ),
        ],
      ),
    );
  }

  void _openEquipment(Equipment e) {
    _equipment = e;
    _equipSel = e.exercises.first;
    _show(_Page.equipment);
  }

  Widget _commonChip(String name) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(name),
      child: Pressable(
        onTap: () => _pick(name),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(999),
          ),
          child: LText(
            name,
            style: TextStyle(
              color: p.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // 搜索结果行：缩略图、动作名、部位，以及是通过哪台器械/俗称找到的。
  Widget _hitRow(ExerciseHit hit) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(hit.name),
      child: Pressable(
        onTap: () => _pick(hit.name, part: hit.part),
        child: Container(
          key: ValueKey('hit-${hit.name}'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.sep, width: 0.5)),
          ),
          child: Row(
            children: [
              ExerciseThumb(
                ex: {'name': hit.name, 'part': hit.part},
                size: 44,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LText(
                          hit.name,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: p.fill,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: LText(
                            hit.part,
                            style: TextStyle(
                              color: p.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hit.via.isNotEmpty)
                      LText('来自：${hit.via}', style: AppText.hint(p)),
                  ],
                ),
              ),
              AppIcon('right', size: 16, color: p.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentCard(String name) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(name),
      child: Pressable(
        onTap: () => _pick(name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.sep, width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.fill2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIcon(partIcon(_part), size: 17, color: p.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      name,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final s in _lastSets(name).take(4))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.fill,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: LText(
                              '${_fmt(s['weight'])}×${s['reps']}',
                              style: TextStyle(
                                color: s['type'] == '热身' ? p.secondary : p.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppIcon('right', size: 16, color: p.tertiary),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _logger() {
    final p = context.pal;
    _status ??= recoveryStatus(context.app);
    final info = exerciseInfo(
      AppMessages.of(context),
      _status!,
      _exercise,
      _part,
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerCard(info),
            // 不是动作表里的规范名（按部位或关键字猜的、或已自定义）都让用户确认。
            if (musclesOf(_exercise, _part)?['matched']
                case 'part' || 'keyword' || 'custom')
              _musclePicker(),
            if (_lastSets(_exercise).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SheetButton(
                  '套用上次',
                  _applyLast,
                  icon: 'spark',
                  soft: true,
                ),
              ),
            Semantics(
              button: true,
              toggled: _unilateral,
              label: AppMessages.of(context).text('单边，只记一只的重量'),
              child: Pressable(
                onTap: () => setState(() => _unilateral = !_unilateral),
                child: Container(
                  height: 51,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: LText('单边，只记一只的重量', style: AppText.body(p)),
                      ),
                      Container(
                        width: 51,
                        height: 31,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _unilateral ? p.ok : p.fill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AnimatedAlign(
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 180,
                          ),
                          alignment: _unilateral
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: p.onTint,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            MotionList(
              children: [
                for (var i = 0; i < _rows.length; i++)
                  Padding(
                    key: ValueKey(_rows[i]['id']),
                    padding: const EdgeInsets.only(top: 12),
                    child: _setCard(_rows[i], i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SheetButton('复制上一组', () {
                    final last = _rows.last;
                    if ('${last['weight']}'.trim().isEmpty &&
                        '${last['reps']}'.trim().isEmpty) {
                      context.app.toast.show('先填这一组');
                      return;
                    }
                    setState(() => _rows.add(_row(last)));
                  }, icon: 'copy'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SheetButton('加一组', () {
                    final last = _rows.last;
                    if ('${last['weight']}'.trim().isNotEmpty ||
                        '${last['reps']}'.trim().isNotEmpty) {
                      setState(() => _rows.add(_row({'type': last['type']})));
                    }
                    _focusWeight(_rows.last);
                  }, icon: 'plus'),
                ),
              ],
            ),
            _label('当天备注，可选'),
            _card(
              SheetInput(
                value: _note,
                onChanged: (s) => setState(() => _note = s),
                label: '当天备注',
                placeholder: '状态、睡眠、感受',
                lines: 2,
              ),
              padding: 12,
            ),
          ],
        ),
      ),
    ];
  }

  bool _hasAlternatives() {
    if (_altKey != _exercise) {
      _altKey = _exercise;
      _altHas = alternativesFor(
        _status ??= recoveryStatus(context.app),
        _exercise,
        owned: context.app.myGym,
        limit: 1,
      ).isNotEmpty;
    }
    return _altHas;
  }

  // 动作头部：缩略图、名称、主练肌肉、恢复状态、示范入口。
  Widget _headerCard(ExerciseInfo info) {
    final p = context.pal;
    final line = _lastLine(_exercise);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseThumb(ex: {'name': _exercise, 'part': _part}, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(_part, style: AppText.hint(p)),
                    LText(
                      _exercise,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.44,
                      ),
                    ),
                    if (info.plainPro.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: LText(
                          AppMessages.of(context).text('练：') + info.plainPro,
                          style: AppText.hint(p),
                        ),
                      ),
                    if (info.ready != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: RecoveryTag(info),
                      ),
                    if (line.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LText(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.hint(p),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SheetButton(
                '更换',
                () => _show(_Page.pick),
                icon: 'repeat',
                pill: true,
              ),
            ],
          ),
          if (guideFor({'name': _exercise}) != null || _hasAlternatives())
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (guideFor({'name': _exercise}) != null)
                      SheetButton(
                        '看示范',
                        () => openGuide(context, _exercise),
                        soft: true,
                      ),
                    if (_hasAlternatives())
                      SheetButton(
                        '器械被占？换一个',
                        () => _swap(_exercise),
                        key: const ValueKey('busy-swap'),
                        icon: 'repeat',
                        soft: true,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      padding: 14,
    );
  }

  // 不认识的动作名：让用户选主练肌肉，恢复按这块肌肉算。不强制。
  Widget _musclePicker() {
    final p = context.pal;
    const groups = {
      '胸': {'chest'},
      '背': {'back'},
      '肩': {'shoulders'},
      '手臂': {'arms'},
      '核心': {'abs'},
      '腿': {'quads', 'hamstrings', 'glutes', 'calves'},
    };
    final related = groups[_part];
    final shown = [
      for (final m in MUSCLES)
        if (_allMuscles || related == null || related.contains(m['group'])) m,
    ];
    final chosen = customMuscles[_exercise.trim()];
    Widget chip(String label, bool on, VoidCallback tap) => Semantics(
      button: true,
      selected: on,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on ? p.primary : p.fill2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: LText(
            label,
            style: TextStyle(
              color: on ? p.onPrimary : p.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText('主要练哪块肌肉？', style: AppText.h2(p)),
            const SizedBox(height: 2),
            LText('选了之后，恢复按这块肌肉算；不选也能保存。', style: AppText.hint(p)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in shown)
                  chip('${m['name']}', chosen == m['id'], () async {
                    final app = context.app;
                    await app.setCustomMuscle(_exercise, '${m['id']}');
                    if (!mounted) return;
                    setState(() {
                      _status = null;
                      // 记录的部位与选的肌肉保持一致，统计才不会错位。
                      _part = partOfExercise(_exercise);
                    });
                  }),
                if (!_allMuscles && related != null)
                  chip('其他', false, () => setState(() => _allMuscles = true)),
              ],
            ),
          ],
        ),
        padding: 14,
      ),
    );
  }

  Widget _setCard(Map<String, dynamic> row, int i) {
    final p = context.pal;
    void change(String k, String v) => setState(() => row[k] = v);
    return _card(
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LText(
                  '第 ${i + 1} 组',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SheetButton(
                '删除这组',
                () => setState(() {
                  if (_rows.length == 1) {
                    _rows = [_row()];
                  } else {
                    _rows.remove(row);
                  }
                }),
                icon: 'trash',
                iconOnly: true,
              ),
            ],
          ),
          StepperField(
            value: row['weight'] as String,
            onChanged: (s) => change('weight', s),
            label: '重量',
            focusNode: _focus(row),
            unit: 'kg',
            step: 2.5,
          ),
          const SizedBox(height: 10),
          StepperField(
            value: row['reps'] as String,
            onChanged: (s) => change('reps', s),
            label: '次数',
            unit: '次',
            step: 1,
          ),
          const SizedBox(height: 14),
          EffortEditor(
            value: row['rpe'] as String,
            onChanged: (v) => row['rpe'] = v,
          ),
          const SizedBox(height: 14),
          SheetSegments(
            labels: records.types,
            value: row['type'] as String,
            onChanged: (s) => change('type', s),
          ),
        ],
      ),
    );
  }
}
