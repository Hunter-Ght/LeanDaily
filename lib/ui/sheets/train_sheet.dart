import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/records.dart' as records;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart';
import '../kit/menu.dart';
import '../kit/number_field.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';
import 'train/effort_editor.dart';

class TrainSheet extends StatefulWidget {
  const TrainSheet({super.key, this.preset});
  final Map<String, dynamic>? preset;
  @override
  State<TrainSheet> createState() => _TrainSheetState();
}

class _TrainSheetState extends State<TrainSheet> {
  static String _lastPart = '胸';
  late String _part, _exercise, _date;
  String _query = '', _note = '', _error = '';
  late bool _unilateral, _picking;
  bool _initialized = false, _saving = false;
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
    _exercise = p['exercise'] as String? ?? '';
    _picking = _exercise.isEmpty;
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
  String _lastLine(String name) {
    final last = _last(name);
    if (last == null) return '';
    final sets = _lastSets(name);
    final desc = sets
        .map(
          (s) =>
              '${_fmt(s['weight'])}×${s['reps']}${s['type'] != null && s['type'] != '正式' ? ' ${s['type']}' : ''}',
        )
        .join('  ');
    final side = sets.any((s) => '${s['notes']}'.contains('单边')) ? ' · 单边' : '';
    return '上次 ${'${last['date']}'.substring(5).replaceAll('-', '/')} · $desc$side';
  }

  Future<void> _pick(String name) async {
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
    setState(() {
      _exercise = name;
      _picking = false;
      if (_last(name) != null) {
        _unilateral = last.any((s) => '${s['notes']}'.contains('单边'));
      } else if (name.contains('哑铃')) {
        _unilateral = true;
      }
      if (!_filled) _rows = [_row()];
    });
    _scroll.jumpTo(0);
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
      setState(() {
        _error = '先选择动作';
        _picking = true;
      });
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
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
    child: LText(text, style: AppText.hint(context.pal)),
  );
  Widget _card(Widget child, {double padding = 16}) => Container(
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
        title: '记一组',
        onSave: _save,
        saveEnabled: !_saving,
        confirmClose: _confirmClose,
        scrollController: _scroll,
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
              direction: _picking ? -1 : 1,
              child: Column(
                key: ValueKey(_picking),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _picking ? _picker() : _logger(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _picker() {
    final p = context.pal;
    final recentAll =
        ((context.app.repo.recentByExercise()['byPart'] as Map)[_part]
                    as List? ??
                [])
            .cast<String>();
    bool match(String s) => s.contains(_query.trim());
    final recent = recentAll.where(match).toList();
    final common = records.defaultEx[_part]!
        .where((s) => !recentAll.contains(s) && match(s))
        .toList();
    final custom =
        _query.trim().isNotEmpty &&
        ![...recentAll, ...records.defaultEx[_part]!].contains(_query.trim());
    return [
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                      width: 80,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _part == part ? p.tint : p.card,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_part == part)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: p.onTint.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AppIcon(
                                  partIcon(part),
                                  size: 16,
                                  color: p.onTint,
                                ),
                              ),
                            )
                          else
                            ToneBadge.part(part, size: 36, iconSize: 16),
                          const SizedBox(height: 8),
                          LText(
                            part,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _part == part ? p.onTint : p.text,
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
                      _pick(custom ? s.trim() : (recent + common).first);
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                children: [
                  for (final name in common)
                    Semantics(
                      button: true,
                      label: AppMessages.of(context).text(name),
                      child: Pressable(
                        onTap: () => _pick(name),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
                    ),
                ],
              ),
            ],
            if (custom)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SheetButton(
                  '使用「${_query.trim()}」',
                  () => _pick(_query.trim()),
                  icon: 'plus',
                ),
              ),
            if (custom) LText('不在列表里，就用这个名字', style: AppText.hint(p)),
          ],
        ),
      ),
    ];
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
              Builder(
                builder: (context) {
                  final tone = ToneBadge.tone(
                    p,
                    partIcon(_part),
                    p.bg.computeLuminance() < 0.1,
                  );
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tone.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcon('spark', size: 18, color: tone.fg),
                  );
                },
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
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              Row(
                children: [
                  ToneBadge.part(_part, size: 32, iconSize: 20),
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
                        if (_lastLine(_exercise).isNotEmpty)
                          LText(
                            _lastLine(_exercise),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.hint(p),
                          ),
                      ],
                    ),
                  ),
                  SheetButton(
                    '更换',
                    () => setState(() => _picking = true),
                    icon: 'repeat',
                    pill: true,
                  ),
                ],
              ),
              padding: 14,
            ),
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

  Widget _setCard(Map<String, dynamic> row, int i) {
    final p = context.pal;
    void change(String k, String v) => setState(() => row[k] = v);
    return _card(
      Column(
        children: [
          Row(
            children: [
              Expanded(child: LText('第 ${i + 1} 组', style: AppText.h2(p))),
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
          NumberField(
            value: row['weight'] as String,
            onChanged: (s) => change('weight', s),
            label: '重量',
            focusNode: _focus(row),
            unit: 'kg',
            step: 2.5,
          ),
          const SizedBox(height: 10),
          NumberField(
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
