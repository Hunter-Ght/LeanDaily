import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../core/native.dart';
import '../../data/ai_consent.dart';
import 'ai_consent_sheet.dart';
import '../../domain/records.dart' as records;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart' show mealIcon;
import '../kit/menu.dart';
import '../kit/number_field.dart';
import '../kit/photo_image.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';

class MealSheet extends StatefulWidget {
  const MealSheet({super.key, this.preset});
  final Map<String, dynamic>? preset;
  @override
  State<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<MealSheet> {
  late AppController _app;
  late String _date, _draftKey;
  String? _editId;
  String _meal = '',
      _time = '',
      _note = '',
      _source = '',
      _summary = '',
      _error = '';
  String _base = '', _analysisSig = '', _job = '', _phase = '', _think = '';
  List<Map<String, dynamic>> _items = [];
  List<String> _photos = [];

  /// 与 [_photos] 一一对应：before = 吃之前，after = 吃完后。
  List<String> _phases = [];
  bool _afterSkipped = false;
  String _basis = '', _warning = '';

  /// 只有吃之前的照片时，识别出的是“整份”；按用户选的吃了几成再折算。
  List<Map<String, dynamic>> _plate = [];
  String _ratio = '全部', _scaledSig = '';
  static const _ratios = {'¼': .25, '½': .5, '¾': .75, '全部': 1.0};
  static const _perPhase = 2;
  final Map<String, Uint8List> _photoBytes = {};
  bool _initialized = false,
      _loading = true,
      _saving = false,
      _finished = false;
  bool _consenting = false;
  bool _analyzing = false,
      _hasAnalysis = false,
      _pickingPhotos = false,
      _enabled = false;
  int _seq = 0, _waited = 0, _generation = 0;
  Timer? _draftTimer, _pollTimer;
  Future<void> _draftLane = Future.value();
  static const _fields = ['name', 'portion', 'kcal', 'protein', 'carbs', 'fat'];
  Map<String, dynamic> _item([Map? raw]) => {
    'id': _seq++,
    for (final k in _fields) k: raw?[k] ?? '',
  };
  List<Map<String, dynamic>> get _plain => [
    for (final it in _items) {for (final k in _fields) k: it[k]},
  ];
  String _sig(List<Map<String, dynamic>> list) => jsonEncode(list);
  String get _contentSig =>
      '${_sig(_plain)}|$_meal|$_time|$_note|${_phases.join(',')}|$_afterSkipped';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _app = context.app;
    _date = _app.date;
    final p = widget.preset ?? {};
    _editId = (p['editId'] ?? p['record_id']) as String?;
    _draftKey = 'android-meal-draft:${_editId ?? _date}';
    _restore();
  }

  String _defaultMeal(String time) {
    final parts = time.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    final mins = parts.first * 60 + (parts.length > 1 ? parts[1] : 0);
    if (mins < 630) return '早餐';
    if (mins < 870) return '午餐';
    if (mins >= 1020 && mins < 1260) return '晚餐';
    return '加餐';
  }

  Future<void> _restore() async {
    try {
      final docs = await _app.native.all();
      final now = await _app.native.clock('${_app.settings.value['tz']}');
      final secrets = await _app.native.secretsGet();
      final opened = <String, dynamic>{...?_editRecord(), ...?widget.preset};
      final rawDraft = docs[_draftKey];
      if (rawDraft != null && rawDraft != 'null') {
        final draft = jsonDecode(rawDraft);
        if (draft is Map) opened.addAll(Map<String, dynamic>.from(draft));
      }
      if (!mounted) return;
      setState(() {
        _time = '${opened['time'] ?? now.now}';
        _meal = '${opened['meal'] ?? ''}';
        if (_meal.isEmpty) _meal = _defaultMeal(_time);
        _note = '${opened['note'] ?? ''}';
        _source = '${opened['source'] ?? ''}';
        _items = (opened['items'] as List? ?? [])
            .map((it) => _item(it as Map))
            .toList();
        _photos = List<String>.from(opened['photo_ids'] as List? ?? []);
        _phases = records.cleanPhases(opened['photo_phases'], _photos.length);
        _afterSkipped = opened['after_skipped'] == true;
        _basis = '${opened['basis'] ?? ''}';
        _summary =
            '${opened['summary'] ?? (_photos.isNotEmpty ? '可以用已保存的照片重新识别' : (records.number(opened['photos']) > 0 ? '原记录已有 ${opened['photos']} 张照片' : ''))}';
        _enabled =
            secrets.modelKey.isNotEmpty &&
            '${_app.settings.value['model']}'.isNotEmpty &&
            '${_app.settings.value['baseUrl']}'.isNotEmpty;
        _base = _contentSig;
        _loading = false;
      });
      for (final path in _photos.toList()) {
        try {
          final photo = await _app.native.photoRead(path);
          if (mounted) setState(() => _photoBytes[path] = photo.bytes);
        } catch (_) {
          /* PhotoImage has an on-disk fallback. */
        }
      }
      _scheduleDraft();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppController.message(e);
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic>? _editRecord() {
    if (_editId == null) return null;
    final list = _app.repo.meals(_date)['meals'] as List;
    for (final raw in list) {
      if (raw['record_id'] == _editId) {
        return Map<String, dynamic>.from(raw as Map);
      }
    }
    return null;
  }

  String get _draft => jsonEncode({
    'meal': _meal,
    'time': _time,
    'note': _note,
    'items': _plain,
    'photo_ids': _photos,
    'photo_phases': _phases,
    'after_skipped': _afterSkipped,
    'basis': _basis,
  });
  Future<void> _writeDraft(String value) {
    _draftLane = _draftLane
        .then((_) => _app.native.put(_draftKey, value))
        .catchError((Object e) {
          if (mounted) _app.toast.show(AppController.message(e));
        });
    return _draftLane;
  }

  void _scheduleDraft() {
    if (_loading || _finished) return;
    _draftTimer?.cancel();
    final value = _draft;
    _draftTimer = Timer(
      const Duration(milliseconds: 300),
      () => _writeDraft(value),
    );
  }

  void _change(VoidCallback change) {
    setState(change);
    _scheduleDraft();
  }

  bool get _dirty {
    if (_photos.isNotEmpty) return true;
    if (_editId != null) return _contentSig != _base;
    return _note.trim().isNotEmpty ||
        _items.any(
          (it) => [
            'name',
            'kcal',
            'portion',
          ].any((k) => '${it[k]}'.trim().isNotEmpty),
        );
  }

  Future<bool> _confirmClose() async {
    if (_saving || _pickingPhotos) return false;
    if (_dirty &&
        !await showConfirm(
          context,
          title: '放弃这餐？',
          message: '已填的内容不会保存。',
          confirm: '放弃',
          danger: true,
        )) {
      return false;
    }
    _finished = true;
    _draftTimer?.cancel();
    await _writeDraft('null');
    return true;
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _pollTimer?.cancel();
    _generation++;
    if (!_finished && !_loading) unawaited(_writeDraft(_draft));
    if (_job.isNotEmpty) unawaited(_app.vision.cancelAnalysis(_job));
    super.dispose();
  }

  int _count(String phase) => _phases.where((e) => e == phase).length;

  void _removePhoto(String path) => _change(() {
    final i = _photos.indexOf(path);
    if (i < 0) return;
    _photos.removeAt(i);
    _phases.removeAt(i);
  });

  Future<void> _pickPhotos(PickSource source, String phase) async {
    if (_pickingPhotos) return;
    final room = math.min(_perPhase - _count(phase), 8 - _photos.length);
    if (room <= 0) {
      _app.toast.show('这一栏最多 $_perPhase 张');
      return;
    }
    setState(() => _pickingPhotos = true);
    try {
      final picked = await _app.native.pickImages(source: source, limit: room);
      if (picked.length > room) _app.toast.show('这一栏最多 $_perPhase 张');
      for (final bytes in picked.take(room)) {
        try {
          final path = await _app.native.photoWrite(bytes);
          if (!mounted) return;
          _change(() {
            _photos.add(path);
            _phases.add(phase);
            _photoBytes[path] = bytes;
            // 补了吃完后的照片，就不再是“吃光了”的口头说明。
            if (phase == records.photoPhaseAfter) _afterSkipped = false;
          });
        } catch (e) {
          if (!mounted) return;
          _app.toast.show('照片上传失败：${AppController.message(e)}');
        }
      }
    } catch (e) {
      final message = AppController.message(e);
      if (!message.toLowerCase().contains('cancel')) {
        _app.toast.show('照片选择未完成：$message');
      }
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  Future<void> _analyze() async {
    if (_analyzing || _consenting) return;
    if (_pickingPhotos) {
      _app.toast.show('照片还在上传');
      return;
    }
    if (_photos.isEmpty) {
      _app.toast.show('先拍一张，或从相册选');
      return;
    }
    if (_count(records.photoPhaseBefore) == 0) {
      _app.toast.show('先拍一张吃之前的，才能算吃了多少');
      return;
    }
    _consenting = true;
    final consent = AiConsent(_app.native);
    final consentSettings = Map<String, dynamic>.from(_app.settings.value);
    try {
      if (!await consent.granted(consentSettings)) {
        if (!mounted) return;
        final accepted = await showAppSheet<bool>(
          context,
          (_) => AiConsentSheet(settings: consentSettings),
        );
        if (accepted != true || !mounted) {
          _consenting = false;
          return;
        }
        // Bind the permission to the settings shown in the dialog. If settings
        // change meanwhile, Vision rejects the new destination independently.
        await consent.grant(consentSettings);
      }
    } catch (e) {
      if (mounted) _app.toast.show(AppController.message(e));
      _consenting = false;
      return;
    }
    _consenting = false;
    if (!mounted || _analyzing) return;
    final generation = ++_generation;
    setState(() {
      _analyzing = true;
      _error = '';
      _phase = '正在看照片';
      _think = '';
      _waited = 0;
    });
    _job = _app.vision.startAnalysis(
      _photos.toList(),
      _note,
      _meal,
      _phases.toList(),
    )['job']!;
    final started = DateTime.now();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || generation != _generation) return;
      try {
        final status = _app.vision.analysisStatus(_job);
        if ('${status['error'] ?? ''}'.isNotEmpty) {
          throw records.DomainError('${status['error']}');
        }
        if (status['done'] == true && status['analysis'] is Map) {
          final a = status['analysis'] as Map;
          _pollTimer?.cancel();
          _change(() {
            _items = (a['items'] as List? ?? [])
                .map((it) => _item(it as Map))
                .toList();
            _hasAnalysis = true;
            _analysisSig = _sig(_plain);
            _basis = '${a['basis'] ?? ''}';
            _warning = '${a['warning'] ?? ''}';
            _plate = _plain;
            _ratio = '全部';
            _scaledSig = _analysisSig;
            _summary = [
              if ('${a['summary'] ?? ''}'.isNotEmpty) '${a['summary']}',
              if ('${a['confidence'] ?? ''}'.isNotEmpty)
                '可信度 ${a['confidence']}',
            ].join(' · ');
            _analyzing = false;
            _job = '';
            _phase = '';
            _think = '';
          });
          return;
        }
        if (status['finished'] == true) {
          throw const records.DomainError('识别没有返回结果');
        }
        final seconds = DateTime.now().difference(started).inSeconds;
        if (seconds >= 160) {
          unawaited(_app.vision.cancelAnalysis(_job));
          throw const records.DomainError('请求超时');
        }
        setState(() {
          _phase = '${status['phase'] ?? _phase}';
          _think = '${status['think'] ?? ''}';
          _waited = seconds;
        });
      } catch (e) {
        _pollTimer?.cancel();
        final msg = AppController.message(e);
        _change(() {
          _analyzing = false;
          _job = '';
          _phase = '';
          _think = '';
          _error = msg.startsWith('识别失败') ? msg : '识别失败：$msg';
          if (_items.isEmpty) _items.add(_item());
        });
      }
    });
  }

  /// 只有吃之前的照片、结果还没被手动改过，才显示“吃了多少”。
  bool get _canScale =>
      _hasAnalysis &&
      !_afterSkipped &&
      _basis == records.basisBeforeOnly &&
      _plate.isNotEmpty &&
      _sig(_plain) == _scaledSig;

  void _setRatio(String label) {
    if (label == _ratio) return;
    _app.haptics.selection();
    final r = _ratios[label] ?? 1.0;
    _change(() {
      _ratio = label;
      _items = [
        for (final it in _plate)
          _item({
            ...it,
            if (r < 1) 'portion': '${it['portion']}（吃了约$label）',
            for (final k in ['kcal', 'protein', 'carbs', 'fat'])
              k: _scale(it[k], r, whole: k == 'kcal'),
          }),
      ];
      _scaledSig = _analysisSig = _sig(_plain);
    });
  }

  static Object _scale(Object? v, double r, {bool whole = false}) {
    final n = records.number(v);
    if (!n.isFinite) return '';
    final x = n * r;
    return whole ? x.round() : (x * 10).round() / 10;
  }

  Future<void> _cancelAnalysis() async {
    final job = _job;
    _generation++;
    _pollTimer?.cancel();
    setState(() {
      _analyzing = false;
      _job = '';
      _phase = '';
      _think = '';
    });
    if (job.isNotEmpty) {
      try {
        await _app.vision.cancelAnalysis(job);
      } catch (e) {
        _app.toast.show(AppController.message(e));
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (_pickingPhotos) {
      _app.toast.show('照片还在上传');
      return;
    }
    final clean = _plain
        .where((it) => '${it['name']}'.trim().isNotEmpty)
        .toList();
    setState(() => _error = '');
    if (_editId == null &&
        _photos.isEmpty &&
        clean.isEmpty &&
        _note.trim().isEmpty) {
      setState(() => _error = '至少拍一张、写一个食物，或写一句备注');
      return;
    }
    var source = '待分析';
    if (_hasAnalysis) {
      source = _sig(clean) == _analysisSig ? 'AI识别' : 'AI识别+手动修正';
    } else if (clean.isNotEmpty) {
      source = _source.startsWith('AI') ? 'AI识别+手动修正' : '手动填写';
    }
    setState(() => _saving = true);
    try {
      if (_editId != null) {
        await _app.repo.updateMeal(
          id: _editId!,
          date: _date,
          meal: _meal,
          time: _time,
          note: _note.trim(),
          source: source,
          items: clean,
          photoIds: _photos.toList(),
          photoPhases: _phases.toList(),
          afterSkipped: _afterSkipped,
          basis: _basis,
          photosChanged: true,
        );
      } else {
        await _app.repo.saveMeal(
          date: _date,
          meal: _meal,
          time: _time,
          note: _note.trim(),
          source: source,
          items: clean,
          photoIds: _photos.toList(),
          photoPhases: _phases.toList(),
          afterSkipped: _afterSkipped,
          basis: _basis,
        );
      }
      _finished = true;
      _draftTimer?.cancel();
      await _writeDraft('null');
      _app.toast.show('已记下');
      _app.haptics.saved();
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
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final compareReady =
        _count(records.photoPhaseAfter) > 0 &&
        _count(records.photoPhaseBefore) > 0;
    final analyzeLabel = !_enabled
        ? '识别营养（未配置）'
        : compareReady
        ? (_basis == records.basisCompare ? '重新识别' : '按吃前吃后对比识别')
        : (_items.isNotEmpty || _photos.isNotEmpty && _editId != null
              ? '重新识别'
              : '识别营养');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppSheet(
        title: _editId == null ? '记一餐' : '编辑饮食',
        onSave: _save,
        saveEnabled: !_saving && !_loading,
        confirmClose: _confirmClose,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: FadeSwitcher(
          child: KeyedSubtree(
            key: ValueKey(_loading),
            child: _loading
                ? const SizedBox(height: 104)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        visible: _error.isNotEmpty,
                        child: _error.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: p.err.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: LText(
                                  _error,
                                  style: TextStyle(color: p.err, fontSize: 15),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SheetSegments(
                        labels: records.meals,
                        value: _meal,
                        onChanged: (s) => _change(() => _meal = s),
                        height: 48,
                        iconFor: mealIcon,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: LText('时间', style: AppText.body(p)),
                            ),
                            SizedBox(
                              width: 100,
                              child: SheetInput(
                                value: _time,
                                onChanged: (s) => _change(() => _time = s),
                                label: '时间',
                                color: p.secondary,
                                align: TextAlign.end,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _phaseBlock(records.photoPhaseBefore, '开吃前', '先拍这一张'),
                      const SizedBox(height: 12),
                      _phaseBlock(
                        records.photoPhaseAfter,
                        '吃完后',
                        _count(records.photoPhaseBefore) == 0
                            ? '吃完再来补拍'
                            : '拍一张，算得更准；不拍也行',
                        skip: true,
                      ),
                      if (!_enabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                          child: LText(
                            '还没配置识别。可以自己填营养，或只保存照片，记成待分析。',
                            style: AppText.hint(p),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SheetButton(
                        _analyzing ? '识别中' : analyzeLabel,
                        _analyzing ? null : _analyze,
                        primary: true,
                      ),
                      Reveal(
                        visible: _analyzing,
                        child: _analyzing
                            ? Column(
                                children: [
                                  const SizedBox(height: 12),
                                  SheetButton('取消识别', _cancelAnalysis),
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.card,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: LText(
                                                _phase,
                                                style: AppText.body(p),
                                              ),
                                            ),
                                            LText(
                                              '已等 $_waited 秒',
                                              style: AppText.hint(p),
                                            ),
                                          ],
                                        ),
                                        LText(
                                          _think.isEmpty
                                              ? '识别过程会显示在这里'
                                              : '思考过程',
                                          style: AppText.hint(p),
                                        ),
                                        if (_think.isNotEmpty)
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 144,
                                            ),
                                            child: SingleChildScrollView(
                                              reverse: true,
                                              child: LText(
                                                _think,
                                                localize: false,
                                                style: AppText.hint(p),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      Reveal(
                        visible: _summary.isNotEmpty,
                        child: _summary.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: p.fill2,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: LText(
                                  [
                                    _summary,
                                    if (_warning.isNotEmpty) '提示：$_warning',
                                  ].join('\n'),
                                  localize: false,
                                  style: TextStyle(color: p.text, fontSize: 15),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Reveal(
                        visible: _canScale,
                        child: _canScale
                            ? _ratioRow()
                            : const SizedBox.shrink(),
                      ),
                      if (_items.isNotEmpty) _totals(),
                      MotionList(
                        children: [
                          for (final it in _items)
                            KeyedSubtree(key: ObjectKey(it), child: _food(it)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SheetButton(
                        '添加食物',
                        () => _change(() => _items.add(_item())),
                        icon: 'plus',
                      ),
                      _label('补充，可选'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SheetInput(
                          value: _note,
                          onChanged: (s) => _change(() => _note = s),
                          label: '补充',
                          placeholder: '例如米饭只吃了一半',
                          lines: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// “开吃前 / 吃完后”各一栏：缩略图 + 拍照 + 相册；吃完后那栏另有“我吃光了”。
  Widget _phaseBlock(
    String phase,
    String title,
    String hint, {
    bool skip = false,
  }) {
    final p = context.pal;
    final full = _count(phase) >= _perPhase || _photos.length >= 8;
    final skipped = skip && _afterSkipped;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LText(
                title,
                style: AppText.body(p).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LText(
                  skipped ? '已标记吃光了，不用补拍' : hint,
                  style: AppText.hint(p),
                ),
              ),
              if (skip && _count(phase) == 0)
                Semantics(
                  button: true,
                  label: AppMessages.of(context).text('我吃光了'),
                  selected: _afterSkipped,
                  child: Pressable(
                    haptic: true,
                    onTap: () => _change(() => _afterSkipped = !_afterSkipped),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _afterSkipped ? p.tint : p.fill2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: LText(
                        '我吃光了',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _afterSkipped ? p.onTint : p.text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, path) in _photos.indexed)
                  if (_phases[i] == phase)
                    Padding(
                      key: ValueKey(path),
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          children: [
                            PhotoImage(
                              path: path,
                              bytes: _photoBytes[path],
                              width: 88,
                              height: 88,
                              radius: 16,
                            ),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Semantics(
                                button: true,
                                label: AppMessages.of(context).text('移除照片'),
                                child: Pressable(
                                  onTap: () => _removePhoto(path),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: p.scrim,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: LText(
                                          '×',
                                          style: TextStyle(
                                            color: p.onTint,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                _photoButton('拍照', 'camera', PickSource.camera, phase, full),
                const SizedBox(width: 8),
                _photoButton('相册', 'photo', PickSource.gallery, phase, full),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoButton(
    String label,
    String icon,
    PickSource source,
    String phase,
    bool full,
  ) {
    final p = context.pal;
    final where = phase == records.photoPhaseBefore ? '开吃前' : '吃完后';
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('$label（$where）'),
      child: Pressable(
        onTap: _pickingPhotos || full ? null : () => _pickPhotos(source, phase),
        child: Opacity(
          opacity: full ? .4 : 1,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: p.fill2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 22, color: p.secondary),
                const SizedBox(height: 6),
                LText(
                  label,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 只有吃之前的照片时：识别出整份，由用户说吃了几成。
  Widget _ratioRow() {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            '这一餐你吃了多少？',
            style: AppText.body(p).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          LText('按全部吃完估算，没吃完在这里改', style: AppText.hint(p)),
          const SizedBox(height: 10),
          SheetSegments(
            labels: _ratios.keys.toList(),
            value: _ratio,
            onChanged: _setRatio,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _totals() {
    final p = context.pal;
    final keys = ['kcal', 'protein', 'carbs', 'fat'],
        labels = ['热量', '蛋白', '碳水', '脂肪'];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++)
            Expanded(
              child: Column(
                children: [
                  LText(
                    _total(keys[i], i == 0),
                    style: TextStyle(
                      color: p.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 24,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? p.kcal
                          : i == 1
                          ? p.protein
                          : p.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LText(labels[i], style: AppText.hint(p)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _total(String key, bool integer) {
    final sum = _items.fold<double>(0, (s, it) {
      final n = records.number(it[key]);
      return s + (n.isFinite ? n : 0);
    });
    return integer
        ? sum.round().toString()
        : (sum * 10).round().toDouble().__format();
  }

  Widget _food(Map<String, dynamic> it) {
    final p = context.pal;
    Widget field(
      String key,
      String label, {
      String placeholder = '',
      bool numeric = false,
    }) => Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.sep, width: 0.5)),
      ),
      child: Row(
        children: [
          LText(label, style: TextStyle(color: p.secondary, fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: SheetInput(
              value: '${it[key]}',
              onChanged: (s) => _change(() => it[key] = s),
              label: label,
              placeholder: placeholder,
              numeric: numeric,
              align: TextAlign.end,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Container(
      key: ValueKey(it['id']),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: SheetInput(
                    value: '${it['name']}',
                    onChanged: (s) => _change(() => it['name'] = s),
                    label: '食物',
                    placeholder: '食物',
                    weight: FontWeight.w600,
                  ),
                ),
                Semantics(
                  button: true,
                  label: AppMessages.of(context).text('删除这个食物'),
                  child: Pressable(
                    onTap: () => _change(() => _items.remove(it)),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AppIcon('trash', size: 18, color: p.secondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          field('portion', '份量', placeholder: '如 200g'),
          Row(
            children: [
              Expanded(child: field('kcal', '热量', numeric: true)),
              Expanded(child: field('protein', '蛋白', numeric: true)),
            ],
          ),
          Row(
            children: [
              Expanded(child: field('carbs', '碳水', numeric: true)),
              Expanded(child: field('fat', '脂肪', numeric: true)),
            ],
          ),
        ],
      ),
    );
  }
}

extension on double {
  String __format() => (this / 10).toString().replaceFirst(RegExp(r'\.0$'), '');
}
