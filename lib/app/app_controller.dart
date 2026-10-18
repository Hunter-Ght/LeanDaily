import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../core/native.dart';
import '../l10n/app_messages.dart';
import '../config/app_info.dart';
import '../config/app_links.dart' as links;
import '../data/update_check.dart';
export '../data/update_check.dart' show UpdateStatus;
import '../core/haptics.dart';
import 'diagnostics.dart';
import '../data/body_log_store.dart';
import '../data/plan_store.dart';
import '../data/prefs.dart';
import '../data/profile_store.dart';
import '../data/reminders.dart';
import '../data/repository.dart';
import '../data/state_doc.dart' show newId;
import '../data/vision.dart';
import '../domain/body.dart' as body;
import '../domain/calendar.dart' as calendar;
import '../domain/foods.dart';
import '../domain/format.dart' show cloneJson;
import '../domain/plan_library.dart';
import '../domain/templates.dart' as templates;
import '../domain/plan.dart' as plan_lib;
import '../domain/progress.dart' as progress_lib;
import '../domain/progress_options.dart';
import '../domain/format.dart' show jsonMap;
import '../domain/records.dart' show DomainError;

/// 轻提示（顶部小胶囊）。
class ToastCenter extends ChangeNotifier {
  String? _text;
  String? actionLabel;
  VoidCallback? onAction;
  int _seq = 0;
  Timer? _timer;
  String? get text => _text;
  int get seq => _seq;

  void show(
    String text, {
    Duration duration = const Duration(milliseconds: 2200),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    this.actionLabel = actionLabel;
    this.onAction = onAction;
    _text = text;
    _seq++;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(duration, () {
      _text = null;
      this.actionLabel = null;
      this.onAction = null;
      notifyListeners();
    });
  }

  void dismiss() {
    _timer?.cancel();
    _text = null;
    actionLabel = null;
    onAction = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 组间休息倒计时。到点自动清除并提醒。
class RestTimer extends ChangeNotifier {
  RestTimer(this._onChanged, this._onDone);
  final void Function(int untilMs, int total) _onChanged;
  final VoidCallback _onDone;

  int _until = 0;
  int total = 90;
  Timer? _timer;

  int get untilMs => _until;
  bool get active => _until > DateTime.now().millisecondsSinceEpoch;

  /// 恢复上次的状态（App 重新打开时）。
  void restore(int until, int total) {
    this.total = total <= 0 ? 90 : total;
    _until = until > DateTime.now().millisecondsSinceEpoch ? until : 0;
    _arm();
    notifyListeners();
  }

  void start(int seconds) {
    total = seconds.clamp(30, 300);
    _until = DateTime.now().millisecondsSinceEpoch + total * 1000;
    _commit();
  }

  void add(int seconds) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _until = (_until > now ? _until : now) + seconds * 1000;
    _commit();
  }

  void clear() {
    _until = 0;
    _commit();
  }

  void _commit() {
    _arm();
    _onChanged(_until, total);
    notifyListeners();
  }

  void _arm() {
    _timer?.cancel();
    if (_until <= 0) return;
    final wait = _until - DateTime.now().millisecondsSinceEpoch;
    _timer = Timer(Duration(milliseconds: wait.clamp(0, 1 << 31)), () {
      if (_until <= 0) return;
      _until = 0;
      _onChanged(0, total);
      notifyListeners();
      _onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 整个 App 的“大脑”：时间、选中日期、计划/进度/目标等偏好、休息计时、提醒。
/// 记录本身在 [Repository]；页面按需订阅各自的 Listenable，拖动手势期间不要触发整页重建。
class AppController extends ChangeNotifier {
  AppController({
    required this.native,
    String? deviceTz,
    Clock? clock,
    this.localeOverride,
    String? updateUrl,
  }) : updateUrl = updateUrl ?? links.platformUpdateCheckUrl,
       clock = clock ?? DateTime.now,
       repo = Repository(native, clock: clock),
       settings = Settings(native, deviceTz: deviceTz ?? 'UTC'),
       goalsStore = GoalsStore(native),
       restPrefsStore = RestPrefsStore(native),
       dayStatesStore = DayStatesStore(native),
       restTimerStore = RestTimerStore(native),
       planStore = PlanStore(native, clock: clock),
       profileStore = ProfileStore(native),
       bodyLog = BodyLogStore(native),
       reminders = Reminders(native, clock: clock),
       vision = Vision(native) {
    rest = RestTimer(_persistRest, () {
      toast.show('休息好了');
      haptics.restEnded();
    });
    reminders.translate = (text) => messages.text(text);
    vision.outputLanguage = () => messages.code;
    repo.addListener(_onRecords);
    _notificationSubscription = native.notificationTaps.listen(
      _onNotificationTap,
    );
  }

  final Locale? localeOverride;
  String languagePreference = 'system';
  Locale get resolvedLocale =>
      localeOverride ??
      AppMessages.resolve(
        languagePreference,
        WidgetsBinding.instance.platformDispatcher.locales,
      );
  AppMessages get messages => AppMessages(resolvedLocale);
  Future<void> setLanguage(String value) async {
    if (!const ['system', 'en', 'zh_Hans', 'zh_Hant'].contains(value)) return;
    await native.put('leandaily-language-v1', value);
    languagePreference = value;
    notifyListeners();
    await refreshLocalizedReminders();
  }

  Future<void> refreshLocalizedReminders() async {
    await _refreshReminders();
    try {
      await reminders.scheduleRest(rest.untilMs);
    } on Object {
      // A denied notification permission must not undo a saved language choice.
    }
  }

  final String updateUrl;
  UpdateStatus updateStatus = UpdateStatus.idle;
  UpdateInfo? updateInfo;
  bool _updateDisposed = false;
  bool get hasUnseenUpdate =>
      updateStatus == UpdateStatus.available &&
      updateInfo != null &&
      _hints['updateSeen'] != updateInfo!.identity;

  Future<void> setAutoUpdateCheck(bool value) async {
    try {
      await settings.save({...settings.value, 'autoUpdateCheck': value});
      if (!_updateDisposed) notifyListeners();
    } on Object {
      toast.show('设置未保存，请稍后再试');
    }
  }

  Future<void> markUpdateSeen() async {
    if (updateInfo == null) return;
    _hints['updateSeen'] = updateInfo!.identity;
    if (!_updateDisposed) notifyListeners();
    try {
      await _saveHints();
    } on Object {
      /* 不打断阅读 */
    }
  }

  Future<void> checkUpdate({bool manual = false}) async {
    if (_updateDisposed || updateStatus == UpdateStatus.checking) return;
    if (updateUrl.isEmpty) {
      updateStatus = UpdateStatus.unconfigured;
      notifyListeners();
      return;
    }
    if (!manual) {
      if (settings.value['autoUpdateCheck'] == false) return;
      final checked = _hints['updateCheckedAt'];
      if (checked is num &&
          clock().millisecondsSinceEpoch - checked <
              const Duration(hours: 24).inMilliseconds) {
        return;
      }
    }
    updateStatus = UpdateStatus.checking;
    notifyListeners();
    _hints['updateCheckedAt'] = clock().millisecondsSinceEpoch;
    try {
      await _saveHints();
    } on Object {
      /* 检查失败不会影响启动 */
    }
    final info = await fetchUpdate(native, updateUrl);
    if (_updateDisposed) return;
    if (info == null) {
      updateStatus = UpdateStatus.failed;
      if (manual) toast.show('暂时无法检查，请稍后再试');
    } else {
      updateInfo = info;
      _hints['updateInfo'] = {
        'version': info.version,
        'build': info.build,
        'url': info.url,
        'notes': info.notes,
      };
      try {
        await _saveHints();
      } on Object {
        /* 网络结果仍可查看 */
      }
      if (_updateDisposed) return;
      updateStatus =
          isNewer(
            info.version,
            appVersion,
            remoteBuild: info.build,
            localBuild: appBuild,
          )
          ? UpdateStatus.available
          : UpdateStatus.upToDate;
      if (manual && updateStatus == UpdateStatus.upToDate) toast.show('已是最新版本');
    }
    notifyListeners();
  }

  final Native native;
  final Clock clock;
  final Repository repo;
  final Settings settings;
  final GoalsStore goalsStore;
  final RestPrefsStore restPrefsStore;
  final DayStatesStore dayStatesStore;
  final RestTimerStore restTimerStore;
  final PlanStore planStore;
  final ProfileStore profileStore;
  final BodyLogStore bodyLog;

  /// 体重/腰围记录，按日期升序；每天最多一条。
  List<Map<String, dynamic>> bodyEntries = [];
  final Reminders reminders;
  final Vision vision;
  late final RestTimer rest;
  final ToastCenter toast = ToastCenter();
  late final AppHaptics haptics = AppHaptics(
    isEnabled: () => settings.value['haptics'] != false,
  );

  // ---- 启动状态 ----
  bool booted = false;
  String bootError = '';
  bool _secretsPruned = false;

  // ---- 时间 ----
  String today = '';
  String _date = '';

  /// 记录页正在看的日期。
  String get date => _date;

  // ---- 计划库 / 资料 ----
  PlanLibrary library = PlanLibrary.empty();
  Map<String, dynamic>? profile;
  Map<String, dynamic>? targets;
  Map<String, dynamic> targetPrefs = {};
  Foods? foods;
  bool onboarded = false;
  bool hasLegacySnapshot = false;
  bool _planUnsaved = false;

  /// 全新用户（没有任何计划、没走过引导）：外壳显示引导。
  bool get needsOnboarding => booted && library.isEmpty && !onboarded;

  /// 老用户升级后第一次：今日页顶部出一张可跳过的提示。
  bool get showUpgradePrompt =>
      booted && !library.isEmpty && !onboarded && profile == null;

  List<Map<String, dynamic>> get plans => library.items;
  String? get activePlanId => library.activeId;

  /// 每日目标：手动覆盖 > 按资料计算 > 旧的设置值。
  int get kcalGoal =>
      ((targetPrefs['kcalOverride'] as num?) ??
              (targets?['kcal'] as num?) ??
              goals['kcal'] ??
              1800)
          .round();
  int get proteinGoal =>
      ((targetPrefs['proteinOverride'] as num?) ??
              (targets?['proteinG'] as num?) ??
              ((plan['protein'] as Map?)?['goal'] as num?) ??
              130)
          .round();

  // ---- 偏好 ----
  Map<String, dynamic> plan = {};
  ProgressOptions get progressOptions => ProgressOptions(
    experience: profile?['experience'] as String? ?? 'some',
    stage: targets?['stage'] as String?,
    age: (profile?['age'] as num?)?.toInt(),
    venue: profile?['venue'] as String?,
    deloadActive:
        today.isNotEmpty &&
        jsonMap(progress['deload'])['week'] == calendar.mondayOf(today),
  );

  /// Uses the existing progress document, so backup and restore include deloads.
  Map<String, dynamic> get deloadState => jsonMap(progress['deload']);

  Future<void> acceptDeload() => acceptSuggestion({
    'accept': {'type': 'deload', 'week': calendar.mondayOf(today)},
  });

  Future<void> declineDeload() => declineSuggestion({'key': 'deload'});

  Map<String, dynamic> progress = progress_lib.emptyProgress();
  Map<String, dynamic> dayStates = {};
  Map<String, int> goals = {...goalDefaults};
  Map<String, dynamic> restPrefs = {'enabled': true, 'sec': 90};

  /// 0 今日，1 记录，2 进度，3 我的。
  int tab = 0;

  StreamSubscription<NotificationTap>? _notificationSubscription;
  NotificationTap? _pendingNotificationTap;

  void _onNotificationTap(NotificationTap tap) {
    if (_updateDisposed) return;
    if (!booted) {
      _pendingNotificationTap = tap;
      return;
    }
    // Both reminder kinds lead back to today's training entry without opening
    // a second training sheet on top of one that may already be open.
    tab = 0;
    _date = today;
    notifyListeners();
  }

  Timer? _reminderTimer;
  Timer? _clockTimer;

  // ---------------------------------------------------------------- 启动

  Future<void> boot() async {
    bootError = '';
    if (!_secretsPruned) {
      _secretsPruned = true;
      try {
        await native.pruneSecrets();
      } on Object {
        // 旧密钥清理失败不阻塞启动。
      }
    }
    try {
      await AppMessages.initialize();
      final storedLanguage = (await native.all())['leandaily-language-v1'];
      if (const [
        'system',
        'en',
        'zh_Hans',
        'zh_Hant',
      ].contains(storedLanguage)) {
        languagePreference = storedLanguage!;
      }
      Diagnostics.at('读取记录');
      await repo.load();
      Diagnostics.at('读取设置');
      await settings.load();
      Diagnostics.at('确定今天日期');
      await _refreshToday();
      _date = today;
      Diagnostics.at('读取计划和进度');
      goals = await goalsStore.load();
      restPrefs = await restPrefsStore.load();
      await _loadPlanLibrary();
      progress = await _loadProgress();
      dayStates = await dayStatesStore.load();
      await _loadProfile();
      await _loadReview();
      await _loadHints();
      final cachedUpdate = _hints['updateInfo'];
      if (updateUrl.isNotEmpty && cachedUpdate is Map) {
        updateInfo = parseUpdate(jsonEncode(cachedUpdate));
        final info = updateInfo;
        if (info != null) {
          updateStatus =
              isNewer(
                info.version,
                appVersion,
                remoteBuild: info.build,
                localBuild: appBuild,
              )
              ? UpdateStatus.available
              : UpdateStatus.upToDate;
        }
      }
      try {
        bodyEntries = await bodyLog.load();
      } on Object {
        bodyEntries = []; // 体重记录损坏不影响启动
      }
      final r = await restTimerStore.load();
      rest.restore(
        ((r['until'] ?? 0) as num).toInt(),
        ((r['total'] ?? 90) as num).toInt(),
      );
      booted = true;
      Diagnostics.at('进入主界面');
    } on Object catch (e, st) {
      bootError = '$e';
      Diagnostics.error(e, st);
    }
    notifyListeners();
    if (booted) {
      try {
        final launch = await native.takeLaunchPayload();
        final tap = _pendingNotificationTap ?? launch;
        _pendingNotificationTap = null;
        if (tap != null) _onNotificationTap(tap);
      } on Object {
        /* Notification routing must not prevent startup. */
      }
      if (_updateDisposed) return;
      _refreshReminders();
      unawaited(checkUpdate());
    }
  }

  Future<void> _refreshToday() async {
    final tz = '${settings.value['tz']}';
    String next;
    try {
      next = (await native.clock(tz)).today;
    } on Object {
      final n = clock();
      next =
          '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    }
    today = next;
  }

  /// App 回到前台：换日、重排提醒。
  Future<void> resume() async {
    if (!booted) return;
    final before = today;
    final zoneChanged = await settings.syncDeviceTz();
    await _refreshToday();
    if (today != before || zoneChanged) {
      final following = _date == before;
      if (following) _date = today;
      notifyListeners();
      _refreshReminders();
    }
  }

  // ---------------------------------------------------------------- 日期 / 标签

  void setDate(String iso) {
    if (today.isEmpty) return;
    final next = iso.isEmpty || iso.compareTo(today) > 0 ? today : iso;
    if (next == _date) return;
    _date = next;
    notifyListeners();
  }

  void setTab(int index) {
    if (tab == index) return;
    tab = index;
    if (index == 0 && today.isNotEmpty && _date != today) _date = today;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 记录

  Map<String, dynamic> get day => repo.day(_date);
  Map<String, dynamic> get meals => repo.meals(_date);

  void _onRecords() {
    _scheduleReminders();
    notifyListeners();
  }

  /// 一键记一份蛋白粉：写成“加餐”，蛋白质按计划里设置的每份含量。
  Future<void> addProteinPowder(String date) async {
    final p = (plan['protein'] as Map?)?['powder'] as Map?;
    if (p == null || date.isEmpty) return;
    final serving = entryFor(proteinPowderFood(p), units: 1);
    final t = clock();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try {
      await repo.saveMeal(
        date: date,
        meal: '加餐',
        time: time,
        source: '手动填写',
        items: [serving],
      );
      haptics.saved();
      toast.show('+${_fmt(serving['protein'])} g 蛋白质（已记入饮食 · 加餐）');
    } on Object catch (e) {
      toast.show('保存失败：${_msg(e)}');
    }
  }

  // ---------------------------------------------------------------- 计划 / 进度

  static const _progressKey = 'fw-progress-v1';

  static const _targetsKey = 'fw-targets-v1';

  Future<void> _loadPlanLibrary() async {
    library = await planStore.load(today);
    if (library.isEmpty) {
      // 全新用户：先放一份默认模板在内存里，页面能正常画；走完引导才真正保存。
      plan = templates.buildPlan(templates.defaultTemplateId, startDate: today);
      _planUnsaved = true;
    } else {
      plan = Map<String, dynamic>.from(library.activePlan!);
      _planUnsaved = false;
    }
    hasLegacySnapshot = (await native.all()).containsKey('fw-plan-legacy-v1');
  }

  Future<void> _loadProfile() async {
    profile = await profileStore.load();
    onboarded = profileStore.onboarded;
    final raw = (await native.all())[_targetsKey];
    try {
      targetPrefs = raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      targetPrefs = {};
    }
    _recomputeTargets();
    if (profile == null) {
      final f = foods;
      if (f == null) _loadFoods();
    } else {
      _loadFoods();
    }
  }

  void _recomputeTargets() {
    final p = profile;
    targets = p == null
        ? null
        : body.buildTargets(
            p,
            goalOverride: targetPrefs['goalBodyFat'] as num?,
          );
  }

  Future<void> _loadFoods() async {
    if (foods != null) return;
    try {
      foods = Foods.parse(await rootBundle.loadString('assets/foods.json'));
      notifyListeners();
    } on Object catch (e, st) {
      Diagnostics.error('食物库加载失败：$e', st);
    }
  }

  Future<Map<String, dynamic>> _loadProgress() async {
    final raw = (await native.all())[_progressKey];
    try {
      final j = raw == null ? null : jsonDecode(raw);
      if (j is Map && j['v'] == 1) {
        return {
          ...progress_lib.emptyProgress(),
          ...Map<String, dynamic>.from(j),
          'anchors': j['anchors'] ?? {},
          'steps': j['steps'] ?? {},
          'declined': j['declined'] ?? {},
          'setUps': j['setUps'] ?? {},
        };
      }
    } on FormatException {
      // 损坏的进度文件当作没有。
    }
    return progress_lib.emptyProgress();
  }

  Future<void> updatePlan(Map<String, dynamic> next) async {
    plan = next;
    notifyListeners();
    _scheduleReminders();
    await _persistPlan();
  }

  /// 把当前 [plan] 写回计划库的“使用中”条目（没有条目时先建一个）。
  Future<void> _persistPlan() async {
    if (_planUnsaved || library.isEmpty) {
      library = await planStore.add(
        id: newId(),
        name: '我的计划',
        plan: plan,
        source: 'template',
        templateId: templates.defaultTemplateId,
        templateVersion: 1,
      );
      _planUnsaved = false;
    } else {
      library = await planStore.update(library.activeId!, plan);
    }
  }

  /// 接受进度建议：按建议里的动作改计划 / 重设起点。
  Future<void> acceptSuggestion(Map<String, dynamic> s) async {
    final acc = s['accept'];
    if (acc == null || plan.isEmpty) return;
    final r = progress_lib.applyAccept(
      cloneJson(plan),
      cloneJson(progress),
      acc as Map<String, dynamic>,
      today,
    );
    plan = r['plan'] as Map<String, dynamic>;
    progress = r['progress'] as Map<String, dynamic>;
    notifyListeners();
    await _persistPlan();
    await native.put(_progressKey, jsonEncode(progress));
  }

  Future<void> declineSuggestion(Map<String, dynamic> s) async {
    final key = s['key'];
    if (key == null) return;
    progress = progress_lib.decline(cloneJson(progress), '$key', today);
    notifyListeners();
    await native.put(_progressKey, jsonEncode(progress));
  }

  Future<void> setStep(String name, num? kg) async {
    final p = cloneJson(progress);
    p['steps'] = {...(p['steps'] as Map), name: kg};
    progress = p;
    notifyListeners();
    await native.put(_progressKey, jsonEncode(p));
  }

  Future<void> patchDayState(String iso, Map<String, dynamic> patch) async {
    final next = {
      ...dayStates,
      iso: {
        ...Map<String, dynamic>.from((dayStates[iso] as Map?) ?? {}),
        ...patch,
      },
    };
    dayStates = await dayStatesStore.save(next, today.isEmpty ? iso : today);
    notifyListeners();
    _scheduleReminders();
  }

  Future<void> saveGoals(Map<String, dynamic> next) async {
    goals = await goalsStore.save(next);
    notifyListeners();
  }

  Future<void> saveRestPrefs(Map<String, dynamic> next) async {
    restPrefs = await restPrefsStore.save(next);
    notifyListeners();
  }

  /// 备份恢复之后，把偏好重新读一遍。
  Future<void> reloadAfterRestore() async {
    await settings.load();
    await _refreshToday();
    _date = today;
    goals = await goalsStore.load();
    restPrefs = await restPrefsStore.load();
    await _loadPlanLibrary();
    progress = await _loadProgress();
    dayStates = await dayStatesStore.load();
    await _loadProfile();
    rest.clear();
    notifyListeners();
    _scheduleReminders();
  }

  // ---------------------------------------------------------------- 计划库 / 资料 / 引导

  Future<void> _afterPlanSwitch() async {
    plan = Map<String, dynamic>.from(library.activePlan!);
    notifyListeners();
    _scheduleReminders();
  }

  Future<void> usePlan(String id) async {
    library = await planStore.setActive(id);
    await _afterPlanSwitch();
  }

  /// 从模板新建一份计划。默认只添加，不替换当前方案。
  Future<String> addTemplatePlan(
    String templateId, {
    bool activate = false,
    String? name,
  }) async {
    final tpl = templates.templates.firstWhere((t) => t['id'] == templateId);
    final base = name ?? '${tpl['name']}';
    var title = base;
    var n = 2;
    while (plans.any((e) => e['name'] == title)) {
      title = '$base（$n）';
      n++;
    }
    final built = templates.buildPlan(
      templateId,
      profile: profile,
      startDate: today,
    );
    final goal = profile == null ? null : proteinGoal;
    if (goal != null) (built['protein'] as Map)['goal'] = goal;
    final id = newId();
    library = await planStore.add(
      id: id,
      name: title,
      plan: built,
      source: 'template',
      templateId: templateId,
      templateVersion: (tpl['version'] as num?)?.toInt() ?? 1,
    );
    if (activate) {
      library = await planStore.setActive(id);
      await _afterPlanSwitch();
    } else {
      notifyListeners();
    }
    return id;
  }

  Future<void> renamePlan(String id, String name) async {
    library = await planStore.rename(id, name);
    notifyListeners();
  }

  Future<void> duplicatePlan(String id) async {
    final src = plans.firstWhere((e) => e['id'] == id);
    library = await planStore.duplicate(
      id,
      id: newId(),
      name: '${src['name']}（副本）',
    );
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    library = await planStore.remove(id);
    notifyListeners();
  }

  /// 恢复到升级前的方案（含进度和每日状态快照）。
  Future<void> restoreLegacy() async {
    library = await planStore.restoreLegacySnapshot();
    progress = await _loadProgress();
    dayStates = await dayStatesStore.load();
    await _afterPlanSwitch();
  }

  Future<void> skipOnboarding() async {
    await profileStore.markOnboarded();
    onboarded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 场地（居家 / 健身房）

  static const _hintsKey = 'fw-hints-v1';

  /// 用户拒绝过“以后每周X都默认健身房/居家”的星期几（0=周日…6=周六）。
  Set<int> venueHintDeclined = {};

  Map<String, dynamic> _hints = {};

  Future<void> _loadHints() async {
    try {
      final raw = (await native.all())[_hintsKey];
      _hints = raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = _hints['venueDeclined'] as List? ?? const [];
      venueHintDeclined = {
        for (final v in list)
          if (v is num) v.toInt(),
      };
    } on Object {
      _hints = {};
      venueHintDeclined = {};
    }
  }

  Future<void> _saveHints() => native.put(
    _hintsKey,
    jsonEncode({
      ..._hints,
      'v': 1,
      'venueDeclined': venueHintDeclined.toList()..sort(),
    }),
  );

  Future<void> declineVenueHint(int dow) async {
    venueHintDeclined = {...venueHintDeclined, dow};
    await _saveHints();
  }

  /// “记一次体重”的提醒：在此日期（含）之前不再显示。
  String get weightNudgeUntil => '${_hints['weightNudgeUntil'] ?? ''}';

  /// 把体重提醒推迟 [days] 天（点“记一次”或“先不”都会调用）。
  Future<void> snoozeWeightNudge(int days) async {
    _hints['weightNudgeUntil'] = calendar.shiftDate(today, days);
    await _saveHints();
    notifyListeners();
  }

  /// 今日页是否该提醒记体重：已填资料；最近一次记录超过 7 天（或从没记过）；且没被推迟。
  bool get shouldNudgeWeight {
    if (profile == null || today.isEmpty) return false;
    if (weightNudgeUntil.isNotEmpty && today.compareTo(weightNudgeUntil) <= 0) {
      return false;
    }
    if (bodyEntries.isEmpty) return true;
    final last = '${bodyEntries.last['date']}';
    return today.compareTo(calendar.shiftDate(last, 7)) > 0;
  }

  /// 今日页是否显示“居家/健身房”小标签：只给“两边都去”的人，以及还没填资料的老用户（旧计划带健身房版）。
  bool get showVenueSwitch => profile == null || profile!['venue'] == 'both';

  /// [iso] 这天刚手动切到 [venue] 后，是否该问“以后每周X都这样”：
  /// 上周同一个星期几也手动选了同一个场地、计划的默认场地不同、且没拒绝过。
  bool shouldAskVenueDefault(String iso, String venue) {
    final dow = plan_lib.dow(iso);
    if (venueHintDeclined.contains(dow)) return false;
    final planDefault = (plan['venues'] as Map?)?['$dow'] == 'gym'
        ? 'gym'
        : 'home';
    if (planDefault == venue) return false;
    final last = dayStates[calendar.shiftDate(iso, -7)];
    return last is Map && last['venue'] == venue;
  }

  /// 把计划里“每周 [dow] 的默认场地”设为 [venue]（居家 = 不写，沿用默认居家）。
  Future<void> setWeekdayVenue(int dow, String venue) async {
    final next = cloneJson(plan);
    final venues = Map<String, dynamic>.from(
      (next['venues'] as Map?) ?? const {},
    );
    if (venue == 'gym') {
      venues['$dow'] = 'gym';
    } else {
      venues.remove('$dow');
    }
    next['venues'] = venues;
    await updatePlan(next);
  }

  // ---------------------------------------------------------------- 每周回顾

  static const _reviewKey = 'fw-review-v1';

  /// 已处理（点了“知道了”或应用了调整）的回顾周，用该周周一的日期表示。
  String reviewDone = '';

  Future<void> _loadReview() async {
    try {
      final raw = (await native.all())[_reviewKey];
      reviewDone = raw == null
          ? ''
          : '${(jsonDecode(raw) as Map)['done'] ?? ''}';
    } on Object {
      reviewDone = '';
    }
  }

  Future<void> finishWeeklyReview(String week) async {
    reviewDone = week;
    await native.put(_reviewKey, jsonEncode({'v': 1, 'done': week}));
    notifyListeners();
  }

  /// 每日热量目标整体加减 [delta]（不低于安全下限），以“自定义热量”保存；资料和蛋白不变。
  Future<void> adjustKcal(int delta) async {
    final p = profile;
    if (p == null) return;
    final next = math.max(body.kcalFloor(p), kcalGoal + delta);
    await setProfile(
      p,
      goalBodyFat: targetPrefs['goalBodyFat'] as num?,
      kcalOverride: next,
      proteinOverride: targetPrefs['proteinOverride'] as num?,
    );
  }

  /// 评估起点（体重、体脂、日期）。趋势与进度以它为准，不随“同步体重到资料”变化。
  Map<String, dynamic>? get baseline {
    final b = targetPrefs['baseline'];
    return b is Map ? Map<String, dynamic>.from(b) : null;
  }

  Map<String, dynamic>? _baselineNow([String? date]) {
    final p = profile, t = targets;
    final fat = (t?['bodyFat'] as Map?)?['value'];
    if (p == null || fat is! num) return null;
    return {
      'date': date ?? today,
      'weightKg': p['weightKg'],
      'bodyFatPct': fat,
    };
  }

  /// 保存资料并重算目标。[kcalOverride]/[proteinOverride] 为 null 表示跟随计算。
  /// [resetBaseline] 为真（重新评估）时把当前资料记为新的起点；否则沿用已有起点，没有则以此刻为起点。
  Future<void> setProfile(
    Map<String, dynamic> next, {
    num? goalBodyFat,
    num? kcalOverride,
    num? proteinOverride,
    bool resetBaseline = false,
  }) async {
    final kept = resetBaseline ? null : targetPrefs['baseline'];
    profile = await profileStore.save(next);
    targetPrefs = {
      'goalBodyFat': ?goalBodyFat,
      'kcalOverride': ?kcalOverride,
      'proteinOverride': ?proteinOverride,
      'baseline': ?kept,
    };
    _recomputeTargets();
    if (kept == null) {
      final b = _baselineNow();
      if (b != null) targetPrefs['baseline'] = b;
    }
    await native.put(_targetsKey, jsonEncode(targetPrefs));
    // 热量目标同步给旧的“每日目标”，摘要页等沿用它。
    await saveGoals({...goals, 'kcal': kcalGoal});
    notifyListeners();
  }

  /// 记一次体重（可带腰围），同一天覆盖；[updateProfile] 为真时同步更新资料里的体重/腰围并重算目标。
  Future<void> recordBody({
    required num weightKg,
    num? waistCm,
    String? date,
    bool updateProfile = false,
  }) async {
    await bodyLog.record(
      date: date ?? today,
      weightKg: weightKg,
      waistCm: waistCm,
    );
    final hadEntries = bodyEntries.isNotEmpty;
    bodyEntries = await bodyLog.load();
    if (updateProfile && profile != null) {
      // 同步体重之前，先把当前资料钉成起点（老用户第一次记体重时尤其重要）。
      if (baseline == null) {
        final b = _baselineNow(
          hadEntries ? '${bodyEntries.first['date']}' : null,
        );
        if (b != null) {
          targetPrefs = {...targetPrefs, 'baseline': b};
          await native.put(_targetsKey, jsonEncode(targetPrefs));
        }
      }
      await setProfile(
        {...profile!, 'weightKg': weightKg, 'waistCm': ?waistCm},
        goalBodyFat: targetPrefs['goalBodyFat'] as num?,
        kcalOverride: targetPrefs['kcalOverride'] as num?,
        proteinOverride: targetPrefs['proteinOverride'] as num?,
      );
      return;
    }
    notifyListeners();
  }

  /// 引导完成：保存资料；全新用户用选中的模板建计划并使用，老用户保留现有计划（[templateId] 为 null）。
  Future<void> completeOnboarding({
    required Map<String, dynamic> profile,
    String? templateId,
    num? goalBodyFat,
  }) async {
    await setProfile(profile, goalBodyFat: goalBodyFat, resetBaseline: true);
    if (templateId != null) {
      if (_planUnsaved || library.isEmpty) {
        final built = templates.buildPlan(
          templateId,
          profile: this.profile,
          startDate: today,
        );
        (built['protein'] as Map)['goal'] = proteinGoal;
        final tpl = templates.templates.firstWhere(
          (t) => t['id'] == templateId,
        );
        library = await planStore.add(
          id: newId(),
          name: '${tpl['name']}',
          plan: built,
          source: 'template',
          templateId: templateId,
          templateVersion: (tpl['version'] as num?)?.toInt() ?? 1,
        );
        _planUnsaved = false;
        await _afterPlanSwitch();
      } else {
        await addTemplatePlan(templateId, activate: false);
      }
    }
    await skipOnboarding();
    _refreshReminders();
  }

  // ---------------------------------------------------------------- 休息计时

  int get restSeconds => restPrefs['sec'] == 120 ? 120 : 90;
  bool get restEnabled => restPrefs['enabled'] != false;

  /// 记完一组后调用：按偏好开始倒计时。
  void startRest([int? seconds]) {
    if (!restEnabled) {
      rest.clear();
      return;
    }
    rest.start(seconds ?? restSeconds);
  }

  void _persistRest(int until, int total) {
    restTimerStore.save(until: until, total: total);
    reminders.scheduleRest(until).catchError((Object e) => toast.show(_msg(e)));
  }

  // ---------------------------------------------------------------- 提醒

  void _scheduleReminders() {
    if (!booted) return;
    _reminderTimer?.cancel();
    _reminderTimer = Timer(
      const Duration(milliseconds: 600),
      _refreshReminders,
    );
  }

  Future<void> _refreshReminders() async {
    if (plan.isEmpty || today.isEmpty) return;
    final todayDone = (repo.day(today)['sets'] as List).any(
      (s) => (s as Map)['type'] != '热身',
    );
    final powderName =
        '${(((plan['protein'] as Map?)?['powder']) as Map?)?['name'] ?? ''}';
    final powderToday =
        powderName.isNotEmpty &&
        (repo.meals(today)['meals'] as List).any(
          (m) => ((m as Map)['items'] as List).any(
            (i) =>
                isProteinPowder((i as Map)['name']) ||
                '${i['name']}'.contains(powderName),
          ),
        );
    try {
      final list = plan_lib.buildReminders(
        plan: plan,
        now: clock(),
        today: today,
        dayStates: dayStates,
        todayDone: todayDone,
        powderToday: powderToday,
      );
      await reminders.applyPlan([
        for (final n in list)
          PlanNote(
            id: n['id'] as int,
            title: messages.text('${n['title']}'),
            body: messages.text('${n['body']}'),
            at: n['at'] as DateTime,
          ),
      ]);
    } on Object {
      // 通知权限没开时静默；设置页会提示。
    }
  }

  /// 外部（设置页开关提醒）要求立即重排。
  void refreshRemindersNow() => _refreshReminders();

  static String _msg(Object e) => e is DomainError
      ? e.message
      : e is NativeError
      ? e.message
      : '$e';
  static String _fmt(Object? n) {
    final v = n is num ? n : num.tryParse('$n') ?? 0;
    return v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  }

  /// 供页面把任意错误转成用户能看懂的一句话。
  static String message(Object e) => _msg(e);

  @override
  void dispose() {
    _updateDisposed = true;
    unawaited(_notificationSubscription?.cancel());
    _reminderTimer?.cancel();
    _clockTimer?.cancel();
    repo.removeListener(_onRecords);
    rest.dispose();
    haptics.dispose();
    toast.dispose();
    repo.dispose();
    super.dispose();
  }
}

/// 把 [AppController] 放进 Widget 树。
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// 只取控制器，不订阅整体变化（页面自己订阅更细的 Listenable）。
  static AppController read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget
              as AppScope)
          .notifier!;
}

extension AppContext on BuildContext {
  AppController get app => AppScope.read(this);
}
