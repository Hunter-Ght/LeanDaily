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
import '../data/backup.dart' as backup_io;
import '../data/backup_status.dart';
import '../data/body_log_store.dart';
import '../data/cardio_store.dart';
import '../domain/cardio.dart' as cardio;
import '../data/my_foods_store.dart';
import '../data/plan_store.dart';
import '../data/prefs.dart';
import '../data/profile_store.dart';
import '../data/reminders.dart';
import '../data/repository.dart';
import '../data/state_doc.dart' show newId;
import '../data/vision.dart';
import '../domain/backup_reminder.dart' as backup_rules;
import '../domain/body.dart' as body;
import '../domain/calendar.dart' as calendar;
import '../domain/foods.dart';
import '../domain/format.dart' show cloneJson;
import '../domain/plan_library.dart';
import '../domain/plan_recipe.dart' as recipes;
import '../domain/templates.dart' as templates;
import '../domain/plan.dart' as plan_lib;
import '../domain/progress.dart' as progress_lib;
import '../domain/progress_options.dart';
import '../domain/units.dart';
import '../domain/format.dart' show jsonMap;
import '../domain/records.dart' show DomainError, truthy;
import '../domain/movements.dart' show customMuscles;

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
    this.regionCode,
  }) : updateUrl = updateUrl ?? links.platformUpdateCheckUrl,
       clock = clock ?? DateTime.now,
       repo = Repository(native, clock: clock),
       settings = Settings(native, deviceTz: deviceTz ?? 'UTC'),
       goalsStore = GoalsStore(native),
       restPrefsStore = RestPrefsStore(native),
       customMusclesStore = CustomMusclesStore(native),
       myGymStore = MyGymStore(native),
       dayStatesStore = DayStatesStore(native),
       restTimerStore = RestTimerStore(native),
       planStore = PlanStore(native, clock: clock),
       profileStore = ProfileStore(native),
       bodyLog = BodyLogStore(native),
       cardioStore = CardioStore(
         native,
         now: clock == null ? null : () => clock().millisecondsSinceEpoch,
       ),
       backupStatusStore = BackupStatusStore(native),
       myFoodsStore = MyFoodsStore(native),
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

  /// 系统地区（如 `US`），只用来决定新安装的默认单位。
  final String? regionCode;

  /// 当前单位制。没选过时：全新安装按系统地区（美国英制），老用户保持公制。
  Units get units {
    final saved = settings.value['units'];
    if (saved == 'imperial' || saved == 'metric') return Units.byId(saved);
    return needsOnboarding ? Units.forRegion(regionCode) : Units.metric;
  }

  Future<void> setUnits(Units value) async {
    try {
      await settings.save({...settings.value, 'units': value.id});
      if (!_updateDisposed) notifyListeners();
    } on Object {
      toast.show('设置未保存，请稍后再试');
    }
  }

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

  Future<void> setHaptics(bool value) async {
    try {
      await settings.save({...settings.value, 'haptics': value});
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
  final CustomMusclesStore customMusclesStore;
  final MyGymStore myGymStore;

  /// 我的健身房里有的器械 id；空表示不限，推荐和替代动作只从这些器械里选。
  Set<String> myGym = {};
  final DayStatesStore dayStatesStore;
  final RestTimerStore restTimerStore;
  final PlanStore planStore;
  final ProfileStore profileStore;
  final BodyLogStore bodyLog;
  final MyFoodsStore myFoodsStore;

  /// 「我的食物」与「常吃整餐」（最近保存的在前）。
  MyFoods myFoods = const MyFoods();

  /// 体重/腰围记录，按日期升序；每天最多一条。
  List<Map<String, dynamic>> bodyEntries = [];

  /// 有氧记录（独立文档，不进力量统计），按日期升序。
  final CardioStore cardioStore;
  List<Map<String, dynamic>> cardioEntries = [];
  Map<String, List<Map<String, dynamic>>> _cardioByDate = {};

  Future<void> _loadCardio() async {
    try {
      cardioEntries = await cardioStore.load();
    } on Object {
      cardioEntries = []; // 有氧记录损坏不影响启动
    }
    _cardioByDate = {};
    for (final e in cardioEntries) {
      (_cardioByDate[e['date'] as String] ??= []).add(e);
    }
  }

  /// 某天的有氧记录。
  List<Map<String, dynamic>> cardioOn(String date) =>
      _cardioByDate[date] ?? const [];

  /// 有有氧记录的日期（活动日，见 domain/cardio.dart 的坚持规则）。
  Set<String> get cardioDates => _cardioByDate.keys.toSet();

  /// 记有氧的默认值：上次记的类型和时长；还没有记录就是走路 20 分钟。
  ({String type, int minutes}) get lastCardio {
    final last = cardioEntries.isEmpty
        ? null
        : (cardioEntries.toList()..sort(
                (a, b) =>
                    ((a['ts'] ?? 0) as num).compareTo((b['ts'] ?? 0) as num),
              ))
              .last;
    return (
      type: '${last?['type'] ?? 'walk'}',
      minutes: ((last?['minutes'] ?? cardio.cardioDefaultMinutes) as num)
          .toInt(),
    );
  }

  Future<void> saveCardio({
    required String date,
    required String type,
    required int minutes,
    num? distanceKm,
    String? effort,
    String? id,
  }) async {
    if (id == null) {
      await cardioStore.add(
        date: date,
        type: type,
        minutes: minutes,
        distanceKm: distanceKm,
        effort: effort,
      );
    } else {
      await cardioStore.update(
        id,
        type: type,
        minutes: minutes,
        distanceKm: distanceKm,
        effort: effort,
      );
    }
    await _loadCardio();
    notifyListeners();
  }

  Future<void> deleteCardio(String id) async {
    await cardioStore.remove(id);
    await _loadCardio();
    notifyListeners();
  }

  Future<void> restoreCardio(Map<String, dynamic> entry) async {
    await cardioStore.restore(entry);
    await _loadCardio();
    notifyListeners();
  }

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
    units: units,
    deloadActive:
        today.isNotEmpty &&
        jsonMap(progress['deload'])['week'] == calendar.mondayOf(today),
  );

  /// 当前使用的方案来自哪个模板；自己建的、导入的方案返回 null。
  String? get activeTemplateId {
    final id = library.activeId;
    if (id == null) return null;
    final item = library.items.where((i) => i['id'] == id).firstOrNull;
    if (item?['source'] != 'template') return null;
    return item?['templateId'] as String?;
  }

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

  /// 当前记录块；只在本次浏览期间保留，重新进入记录时回到饮食。
  String recordSection = '饮食';
  void showRecordSection(String section) {
    if (recordSection == section) return;
    recordSection = section;
    notifyListeners();
  }

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
      await _loadCustomMuscles();
      await _loadPlanLibrary();
      progress = await _loadProgress();
      dayStates = await dayStatesStore.load();
      await _loadProfile();
      await _loadReview();
      await _loadHints();
      await _loadBackupStatus();
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
      await _loadCardio();
      await _loadMyFoods();
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
    if (index == 1) recordSection = '饮食';
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
  Future<void> addProteinPowder(
    String date, {
    Map<String, dynamic>? entry,
  }) async {
    final p = (plan['protein'] as Map?)?['powder'] as Map?;
    if (date.isEmpty) return;
    final serving = entry ?? entryFor(proteinPowderFood(p), units: 1);
    final t = clock();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try {
      final id = await repo.saveMeal(
        date: date,
        meal: '加餐',
        time: time,
        source: '手动填写',
        items: [serving],
      );
      haptics.saved();
      toast.show(
        '+${_fmt(serving['protein'])} g 蛋白质（已记入饮食 · 加餐）',
        duration: const Duration(seconds: 6),
        actionLabel: '撤销',
        onAction: () async {
          toast.dismiss();
          try {
            await repo.deleteMeal(date, id);
            toast.show('已撤销');
          } on Object catch (e) {
            toast.show(message(e));
          }
        },
      );
    } on Object catch (e) {
      toast.show('保存失败：${_msg(e)}');
    }
  }

  Future<void> _loadMyFoods() async {
    try {
      myFoods = await myFoodsStore.load();
    } on Object {
      myFoods = const MyFoods(); // 文档损坏不影响启动，下次保存时会另存一份再重来
    }
  }

  /// 保存一个手动输入的食物到「我的食物」（同名则更新）。
  Future<void> saveMyFood({
    String? id,
    required String name,
    required num kcal,
    required num protein,
    num carbs = 0,
    num fat = 0,
  }) async {
    await myFoodsStore.saveFood(
      id: id,
      name: name,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    await _loadMyFoods();
    notifyListeners();
  }

  /// 把一餐里的多个食物存成一个常吃整餐。
  Future<void> saveMyMeal(List items, {String name = ''}) async {
    await myFoodsStore.saveMeal(name: name, items: items);
    await _loadMyFoods();
    notifyListeners();
  }

  Future<void> renameMyMeal(String id, String name) async {
    await myFoodsStore.renameMeal(id, name);
    await _loadMyFoods();
    notifyListeners();
  }

  Future<void> deleteMyFood(String id) async {
    await myFoodsStore.delete(id);
    await _loadMyFoods();
    notifyListeners();
  }

  /// 把一组食物明细记成 [date] 的 [meal]（再记一次、和昨天一样、常吃整餐都走这里），
  /// 提示里带「撤销」。返回新记录的 id，失败时返回 null 并提示原因。
  /// [time] 为空时用现在的时间。
  Future<String?> logItems({
    required String date,
    required String meal,
    required List items,
    String time = '',
  }) async {
    try {
      final t = clock();
      final id = await repo.saveMeal(
        date: date,
        meal: meal,
        time: time.isNotEmpty
            ? time
            : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        source: '手动填写',
        items: [for (final i in items) Map<String, dynamic>.from(i as Map)],
      );
      final saved = repo.state['meals'][id] as Map;
      haptics.saved();
      toast.show(
        '已记入 $meal：${_fmt(saved['kcal'])} 千卡 / 蛋白 ${_fmt(saved['protein'])} g',
        duration: const Duration(seconds: 6),
        actionLabel: '撤销',
        onAction: () async {
          toast.dismiss();
          try {
            await repo.deleteMeal(date, id);
            toast.show('已撤销');
          } on Object catch (e) {
            toast.show(message(e));
          }
        },
      );
      return id;
    } on Object catch (e) {
      toast.show(message(e));
      return null;
    }
  }

  /// 再记一次：把 [meal]（一条饮食记录）的食物明细复制到当前所选日期、同一餐次。
  /// 记到今天用现在的时间，记到别的日子沿用原来的时间，时间线上位置合理。
  Future<String?> repeatMeal(Map<String, dynamic> meal, {String? date}) {
    final target = date ?? _date;
    return logItems(
      date: target,
      meal: '${meal['meal']}',
      items: meal['items'] as List? ?? const [],
      time: target == today ? '' : '${meal['time'] ?? ''}',
    );
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
      foods = Foods.parse(
        await rootBundle.loadString('assets/foods.json'),
        usSource: await rootBundle.loadString('assets/foods_us.json'),
      );
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

  Future<void> _loadCustomMuscles() async {
    customMuscles
      ..clear()
      ..addAll(await customMusclesStore.load());
    myGym = await myGymStore.load();
  }

  Future<void> saveMyGym(Set<String> ids) async {
    myGym = Set.of(ids);
    await myGymStore.save(myGym);
    notifyListeners();
  }

  /// 给自定义动作指定主练肌肉，之后的恢复计算按这块肌肉算。
  Future<void> setCustomMuscle(String exercise, String muscleId) async {
    final name = exercise.trim();
    if (name.isEmpty) return;
    customMuscles[name] = muscleId;
    await customMusclesStore.save(Map.of(customMuscles));
    notifyListeners();
  }

  Future<void> saveRestPrefs(Map<String, dynamic> next) async {
    restPrefs = await restPrefsStore.save(next);
    notifyListeners();
  }

  // ---------------------------------------------------------------- 备份提醒 / 随系统备份

  final BackupStatusStore backupStatusStore;
  BackupStatus backupStatus = const BackupStatus();

  /// 本机是否支持「随设备备份」，以及是否已开启。Android 上不支持。
  SystemBackupState systemBackup = const SystemBackupState.unsupported();

  Future<void> _loadBackupStatus() async {
    backupStatus = await backupStatusStore.load();
    try {
      systemBackup = await native.systemBackupState();
    } on Object {
      systemBackup = const SystemBackupState.unsupported();
    }
  }

  int get _nowMs => clock().millisecondsSinceEpoch;

  /// 「我的」页备份行的状态文案。
  String get backupStatusLabel => backup_rules.backupStatusText(
    lastBackupMs: backupStatus.lastExportMs,
    nowMs: _nowMs,
  );

  backup_rules.BackupFacts? _backupFacts;
  int _backupFactsRevision = -1;
  String _backupFactsDay = '';
  backup_rules.BackupFacts get backupFacts {
    if (_backupFacts == null ||
        _backupFactsRevision != repo.revision ||
        _backupFactsDay != today) {
      final state = repo.state;
      Iterable<String> dates(String kind, bool Function(Map r) keep) => [
        for (final r in (state[kind] as Map).values)
          if (!truthy((r as Map)['deleted']) && keep(r)) r['date'] as String,
      ];
      _backupFacts = backup_rules.backupFacts(
        trainDates: dates('sets', (r) => r['type'] != '热身'),
        mealDates: dates('meals', (_) => true),
        today: today,
      );
      _backupFactsRevision = repo.revision;
      _backupFactsDay = today;
    }
    return _backupFacts!;
  }

  /// 「我的」页顶部是否显示备份提示卡。训练页是单独的全屏页面，不会出现这张卡。
  bool get shouldNudgeBackup =>
      booted &&
      today.isNotEmpty &&
      backup_rules.shouldNudgeBackup(
        facts: backupFacts,
        lastBackupMs: backupStatus.lastExportMs,
        snoozeUntilMs: backupStatus.snoozeUntilMs,
        nowMs: _nowMs,
        systemBackupOn: systemBackup.enabled,
      );

  Future<void> _saveBackupStatus(BackupStatus next) async {
    backupStatus = next;
    notifyListeners();
    try {
      await backupStatusStore.save(next);
    } on Object {
      // 只影响提醒的时间，不影响记录和备份文件。
    }
  }

  /// 点“以后再说”：14 天内不再提示。
  Future<void> snoozeBackupNudge() => _saveBackupStatus(
    backupStatus.copyWith(
      snoozeUntilMs: backup_rules.backupSnoozeUntil(_nowMs),
    ),
  );

  /// 导出备份文件（系统文件选择器让用户选存放位置）。成功后记下时间。
  /// 用户取消或失败会抛出异常，不更新时间。
  Future<void> exportBackup() async {
    await backup_io.exportBackup(native, repo, clock: clock);
    await _saveBackupStatus(BackupStatus(lastExportMs: _nowMs));
    toast.show('备份已保存到你选择的位置');
  }

  /// 打开或关闭「随设备备份」。失败时保持原状并提示。
  Future<void> setSystemBackup(bool on) async {
    try {
      await native.setSystemBackup(on);
      systemBackup = SystemBackupState(supported: true, enabled: on);
      notifyListeners();
    } on Object {
      toast.show('设置未保存，请稍后再试');
    }
  }

  /// 用已校验的备份替换本机记录，并回到可用状态。引导页和「备份与高级」共用。
  Future<void> restoreFromBackup(Map<String, dynamic> b) async {
    await backup_io.restoreBackup(native, repo, b);
    await reminders.scheduleRest(0);
    await reloadAfterRestore();
    // 现在手机上的记录就等于这份备份；从备份生成的时间开始算“上次备份”。
    final created = DateTime.tryParse('${b['created']}')
        ?.millisecondsSinceEpoch;
    await _saveBackupStatus(BackupStatus(lastExportMs: created));
    // 换新手机恢复的人不该再被引导页拦住。
    if (needsOnboarding) await skipOnboarding();
  }

  /// 备份恢复之后，把偏好重新读一遍。
  Future<void> reloadAfterRestore() async {
    await settings.load();
    await _refreshToday();
    _date = today;
    goals = await goalsStore.load();
    restPrefs = await restPrefsStore.load();
    await _loadCustomMuscles();
    await _loadPlanLibrary();
    progress = await _loadProgress();
    dayStates = await dayStatesStore.load();
    await _loadMyFoods();
    await _loadProfile();
    try {
      bodyEntries = await bodyLog.load();
    } on Object {
      bodyEntries = [];
    }
    await _loadCardio();
    await _loadReview();
    await _loadHints();
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

  /// 当前方案的配方；不是按配方生成的方案返回 null。
  Map<String, dynamic>? get activeRecipe {
    final r = plan['recipe'];
    return r is Map
        ? recipes.normalizeRecipe(Map<String, dynamic>.from(r))
        : null;
  }

  /// 按配方生成的方案：沿用资料里的蛋白目标。
  Map<String, dynamic> _buildRecipe(Map<String, dynamic> recipe) {
    final built = recipes.buildRecipePlan(recipe, startDate: today);
    if (profile != null) (built['protein'] as Map)['goal'] = proteinGoal;
    return built;
  }

  /// 按配方新建一份方案，默认直接使用。
  Future<String> addRecipePlan(
    Map<String, dynamic> recipe, {
    bool activate = true,
  }) async {
    final id = newId();
    library = await planStore.add(
      id: id,
      name: recipes.recipeName(recipe),
      plan: _buildRecipe(recipe),
      source: 'generated',
    );
    if (activate) {
      library = await planStore.setActive(id);
      await _afterPlanSwitch();
    } else {
      notifyListeners();
    }
    return id;
  }

  /// 调整方案：当前方案本来就是按配方生成的，就原地重新生成（保留开始日期、
  /// 提醒、蛋白设置、器械调节记录和课程进度）；否则另建一份并使用，原方案留在方案库里。
  Future<void> applyRecipe(Map<String, dynamic> recipe) async {
    final item = library.items
        .where((i) => i['id'] == library.activeId)
        .firstOrNull;
    if (item == null ||
        item['source'] != 'generated' ||
        plan['recipe'] is! Map) {
      await addRecipePlan(recipe);
      return;
    }
    final built = _buildRecipe(recipe);
    for (final key in [
      'startDate',
      'reminder',
      'protein',
      'setups',
      'course',
    ]) {
      if (plan.containsKey(key)) built[key] = plan[key];
    }
    final id = item['id'] as String;
    library = await planStore.update(id, built);
    library = await planStore.rename(id, recipes.recipeName(recipe));
    await _afterPlanSwitch();
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
    // 引导结束后「全新安装」的判断就不再成立，先把当时的默认单位存下来。
    if (settings.value['units'] == null) {
      final chosen = units;
      try {
        await settings.save({...settings.value, 'units': chosen.id});
      } on Object {
        // 存不上就保持公制，不挡住引导。
      }
    }
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

  /// 引导完成：保存资料；全新用户用配方（[recipe]）或选中的模板建计划并使用，
  /// 老用户保留现有计划（两者都为 null）。
  Future<void> completeOnboarding({
    required Map<String, dynamic> profile,
    String? templateId,
    Map<String, dynamic>? recipe,
    num? goalBodyFat,
  }) async {
    await setProfile(profile, goalBodyFat: goalBodyFat, resetBaseline: true);
    if (recipe != null) {
      // 全新用户直接使用；老用户只添加，不替换正在用的方案。
      final fresh = _planUnsaved || library.isEmpty;
      _planUnsaved = false;
      await addRecipePlan(recipe, activate: fresh);
    } else if (templateId != null) {
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
