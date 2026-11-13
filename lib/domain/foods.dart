import 'dart:convert';

/// Offline estimates per 100 g (drinks treat 1 ml as 1 g). All quantities and
/// portions are approximate; packaged foods should use their nutrition label.
/// Loading the asset is the caller's responsibility; this library is pure Dart.
const typicalMealCategory = '常见一餐';

/// 美式食物包里每个条目的 `region` 值。
const usRegion = 'us';
const mealNames = ['早餐', '午餐', '晚餐', '加餐'];

class Foods {
  Foods._(this.items);

  /// Read-only JSON-shaped entries, including read-only alias lists.
  final List<Map<String, dynamic>> items;

  /// [usSource] 是美式食物包（`assets/foods_us.json`），条目带 `region: us`，
  /// 与主食物库共用同一套字段，名称不得与主库重复。
  factory Foods.parse(String source, {String? usSource}) {
    final names = <String>{};
    final items = <Map<String, dynamic>>[];
    _parseInto(source, names, items, region: null);
    if (usSource != null) _parseInto(usSource, names, items, region: usRegion);
    return Foods._(List<Map<String, dynamic>>.unmodifiable(items));
  }

  static void _parseInto(
    String source,
    Set<String> names,
    List<Map<String, dynamic>> items, {
    required String? region,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! List) throw const FormatException('食物库应为数组');
    for (final raw in decoded) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('食物条目应为对象');
      }
      String text(String key) {
        final value = raw[key];
        if (value is! String || value.trim().isEmpty || value != value.trim()) {
          throw FormatException('食物字段无效：$key');
        }
        return value;
      }

      num number(String key, {bool positive = false}) {
        final value = raw[key];
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            (positive && value == 0)) {
          throw FormatException('食物数值无效：$key');
        }
        return value;
      }

      final name = text('name');
      if (name.length > 60 || !names.add(name)) {
        throw FormatException('食物名称过长或重复：$name');
      }
      final aliases = raw['aliases'];
      if (aliases is! List ||
          aliases.any(
            (a) => a is! String || a.trim().isEmpty || a != a.trim(),
          )) {
        throw FormatException('食物别名无效：$name');
      }
      // 整顿饭（category 为“常见一餐”）可以标注适合哪几餐，用来按餐次推荐。
      final meals = raw['meals'];
      if (meals != null &&
          (meals is! List ||
              meals.any((m) => m is! String || !mealNames.contains(m)))) {
        throw FormatException('食物餐次无效：$name');
      }
      items.add(
        Map<String, dynamic>.unmodifiable({
          'name': name,
          'aliases': List<String>.unmodifiable(aliases.cast<String>()),
          if (meals != null)
            'meals': List<String>.unmodifiable(meals.cast<String>()),
          'region': ?region,
          'category': text('category'),
          'unit': text('unit'),
          'gramsPerUnit': number('gramsPerUnit', positive: true),
          for (final key in ['kcal100', 'protein100', 'carbs100', 'fat100'])
            key: number(key),
        }),
      );
    }
  }

  /// 是否来自美式食物包。
  static bool isUs(Map<String, dynamic> food) => food['region'] == usRegion;

  /// “常见一餐”：一顿饭整体的热量和蛋白，按餐次排序（适合 [meal] 的在前，保持资源顺序）。
  /// [onlyThisMeal] 为 true 时只返回适合该餐的。[us] 为 true 时给美式整餐，
  /// 否则保持原有的中式列表，两套互不混入。
  List<Map<String, dynamic>> typicalMeals(
    String meal, {
    bool onlyThisMeal = true,
    bool us = false,
  }) {
    final all = items.where(
      (f) => f['category'] == typicalMealCategory && isUs(f) == us,
    );
    bool fits(Map<String, dynamic> f) =>
        (f['meals'] as List?)?.contains(meal) ?? false;
    return [
      ...all.where(fits),
      if (!onlyThisMeal) ...all.where((f) => !fits(f)),
    ];
  }

  /// 分类浏览用的分类名（不含“常见一餐”），按资源里出现的先后。
  /// [us] 为 true 时是美式分类，否则是原有分类。
  List<String> categories({bool us = false}) => {
    for (final f in items)
      if (isUs(f) == us && f['category'] != typicalMealCategory)
        f['category'] as String,
  }.toList();

  /// 某个分类下的全部食物，保持资源顺序。
  List<Map<String, dynamic>> inCategory(String category) => [
    for (final f in items)
      if (f['category'] == category) f,
  ];

  /// Exact name > name prefix > name substring > alias exact > alias prefix >
  /// alias substring > pinyin initials > every word found somewhere. Matching
  /// is case-insensitive and tolerates English plurals (egg/eggs).
  /// [localName] adds the displayed (translated) name as another name, so a
  /// food is findable by what the user sees. With [usFirst], American foods
  /// win ties. Ties otherwise retain asset order. Empty queries mix familiar
  /// staples and protein recommendations. [limit] <= 0 returns an empty list.
  List<Map<String, dynamic>> search(
    String query, {
    int limit = 30,
    bool usFirst = false,
    String Function(String name)? localName,
  }) {
    if (limit <= 0) return [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      final recommended = <Map<String, dynamic>>[];
      for (final name in [if (usFirst) ..._commonUsNames, ..._commonNames]) {
        recommended.addAll(items.where((food) => food['name'] == name));
      }
      final seen = recommended.map((food) => food['name']).toSet();
      for (final food in proteinRanking()) {
        if (seen.add(food['name'])) recommended.add(food);
      }
      for (final food in items) {
        if (seen.add(food['name'])) recommended.add(food);
      }
      return recommended.take(limit).toList();
    }
    final variants = _queryVariants(q);
    final tokens = q.split(RegExp(r'\s+'));
    final latin = RegExp(r'^[a-z]+$').hasMatch(q);
    final matches = <({int rank, int us, int index})>[];
    for (var index = 0; index < items.length; index++) {
      final food = items[index];
      final name = (food['name'] as String).toLowerCase();
      final shown = localName?.call(food['name'] as String).toLowerCase();
      final names = [name, if (shown != null && shown != name) shown];
      final aliases = [
        for (final a in food['aliases'] as List<String>) a.toLowerCase(),
      ];
      int rank = -1;
      for (final v in variants) {
        final r = names.any((n) => n == v)
            ? 0
            : names.any((n) => n.startsWith(v))
            ? 1
            : names.any((n) => n.contains(v))
            ? 2
            : aliases.any((a) => a == v)
            ? 3
            : aliases.any((a) => a.startsWith(v))
            ? 4
            : aliases.any((a) => a.contains(v))
            ? 5
            : latin && [name, ...aliases].any((t) => _initials(t).contains(v))
            ? 6
            : -1;
        if (r >= 0 && (rank < 0 || r < rank)) rank = r;
      }
      if (rank < 0 && tokens.length > 1) {
        final texts = [...names, ...aliases];
        if (tokens.every((t) => texts.any((x) => x.contains(t)))) rank = 7;
      }
      if (rank >= 0) {
        matches.add((
          rank: rank,
          us: isUs(food) == usFirst ? 0 : 1,
          index: index,
        ));
      }
    }
    matches.sort((a, b) {
      // 中文界面：中式条目整体在前，保持原来的顺序，美式食物排在后面仍可搜到。
      // 英文界面：先按匹配程度，同等匹配时美式食物在前。
      if (!usFirst) {
        final us = a.us.compareTo(b.us);
        if (us != 0) return us;
      }
      final rank = a.rank.compareTo(b.rank);
      if (rank != 0) return rank;
      final us = a.us.compareTo(b.us);
      return us != 0 ? us : a.index.compareTo(b.index);
    });
    return matches.take(limit).map((m) => items[m.index]).toList();
  }

  /// The query itself plus its English singular forms (eggs -> egg,
  /// berries -> berry, tomatoes -> tomato).
  static List<String> _queryVariants(String q) {
    final out = [q];
    if (q.length >= 4 && RegExp(r'^[a-z ]+$').hasMatch(q)) {
      if (q.endsWith('ies')) out.add('${q.substring(0, q.length - 3)}y');
      if (q.endsWith('es')) out.add(q.substring(0, q.length - 2));
      if (q.endsWith('s') && !q.endsWith('ss')) {
        out.add(q.substring(0, q.length - 1));
      }
    }
    return out;
  }

  /// Descending protein grams per 100 kcal, excluding zero-energy entries.
  /// Equal ratios retain asset order. This measures density, not a meal plan.
  List<Map<String, dynamic>> proteinRanking() {
    final indices = [
      for (var i = 0; i < items.length; i++)
        if ((items[i]['kcal100'] as num) > 0 &&
            (items[i]['protein100'] as num) > 0)
          i,
    ];
    num density(int i) =>
        (items[i]['protein100'] as num) / (items[i]['kcal100'] as num);
    indices.sort((a, b) {
      final ratio = density(b).compareTo(density(a));
      return ratio != 0 ? ratio : a.compareTo(b);
    });
    return indices.map((i) => items[i]).toList();
  }

  /// Defaults to one household unit. Supply either [grams] or [units].
  Map<String, dynamic> entryFor(
    Map<String, dynamic> food, {
    num? grams,
    num? units,
  }) => _entryFor(food, grams: grams, units: units);
}

/// Also available without retaining the parsed catalogue.
Map<String, dynamic> entryFor(
  Map<String, dynamic> food, {
  num? grams,
  num? units,
}) => _entryFor(food, grams: grams, units: units);

Map<String, dynamic> _entryFor(
  Map<String, dynamic> food, {
  num? grams,
  num? units,
}) {
  if (grams != null && units != null) {
    throw ArgumentError('克数与份数只能填写一种');
  }
  final quantity = grams ?? units ?? 1;
  if (!quantity.isFinite || quantity < 0) {
    throw ArgumentError('食物份量应为非负有限数值');
  }
  final weight = grams ?? quantity * (food['gramsPerUnit'] as num);
  if (!weight.isFinite) throw ArgumentError('食物份量过大');
  String display(num n) => n == n.truncateToDouble()
      ? n.toInt().toString()
      : n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  final portion = grams != null || food['unit'] == '100g'
      ? '约${display(weight)}g'
      : '约${display(quantity)}${food['unit']}（${display(weight)}g）';
  final entry = <String, dynamic>{'name': food['name'], 'portion': portion};
  for (final key in ['kcal', 'protein', 'carbs', 'fat']) {
    final value = (food['${key}100'] as num) * weight / 100;
    if (!value.isFinite || value < 0 || value >= 100000) {
      throw ArgumentError('食物营养数值超出记录范围');
    }
    final rounded = key == 'kcal' ? value.round() : (value * 10).round() / 10;
    if (rounded >= 100000) throw ArgumentError('食物营养数值超出记录范围');
    entry[key] = rounded;
  }
  if (portion.length > 40) throw ArgumentError('食物份量文字过长');
  return entry;
}

const _commonUsNames = [
  '烤鸡胸肉',
  '水煮蛋',
  '炒蛋',
  '燕麦粥（水煮）',
  '希腊酸奶（原味，脱脂）',
  '牛油果吐司',
  '花生酱（经典，含糖）',
  '蛋白棒',
  '2%低脂牛奶',
];

const _commonNames = [
  '米饭',
  '鸡蛋（全蛋）',
  '鸡胸肉（水煮，去皮）',
  '纯牛奶（全脂）',
  '豆腐（北豆腐）',
  '燕麦片（干）',
  '馒头',
  '香蕉',
];

// Small, dependency-free character table for common food names and aliases.
// Unknown characters remain in the key, so initials cannot bridge a missing
// character and accidentally match unrelated foods. This is not full pinyin.
const _initialGroups = <String, String>{
  'a': '鹌',
  'b': '不保八冰包北卜堡宝巴扁拌棒爆白百碧苞菠贝部饼鲅鲍',
  'c': '常彩橙炒糙纯翅肠茶草菜葱蚕车鹑',
  'd': '丁低冬冻动地大带度打旦炖蛋豆达',
  'e': '耳鳄鹅',
  'f': '凤分发啡法番粉腐蜂覆非饭',
  'g': '估宫干果根桂棍橄瓜糕罐肝菇蛤谷锅骨高鲑',
  'h': '化后含哈回核汉河海火猴红胡花荷葫蒿蚝馄黄黑',
  'j': '加即卷基季家桔椒橘浆浸焦脊腱芥苣蕉角酱金韭饺鲫鸡',
  'k': '克口可咖开烤矿空苦葵',
  'l': '乐兰凉利力卤厘拉料李梨榄榴沥淋离笼粮绿罗老腊芦荔莲萝蓝藜蛎蜊辣酪里铃零鲈鲤龙',
  'm': '卖墨密木檬毛牡猕米美芒茅莓蔓蘑蜜面馒马麦麻',
  'n': '内南女奶嫩年拿柠牛糯腩',
  'o': '藕',
  'p': '婆平披拍排普泡片皮盆苹葡螃',
  'q': '全切千去奇巧曲枪汽泉淇清秋芹茄荞裙青鲭',
  'r': '乳仁肉',
  's': '三丝参司四圣士山式扇松柿树桑水沙烧熟生瘦石笋算素舒苏萨葚薯酥酸食',
  't': '兔吐土头提条桃汤甜糖脱腿茼萄蹄通铁饨',
  'w': '丸乌五味围威屋文无窝莴豌',
  'x': '咸夏小希心杏稀线胸苋虾蟹血西雪香鲜鳕',
  'y': '原叶圆夷异柚椰樱油洋燕玉用眼约羊腰芋药薏贻越运银饮鱼鱿鸭鹰',
  'z': '肫嘴子张杂枝枣楂榛汁灼炸煮爪猪章竹籽粥紫胗脂芝蒸贼酯针',
};
final _initialByChar = <String, String>{
  for (final group in _initialGroups.entries)
    for (final character in group.value.split('')) character: group.key,
};
String _initials(String text) => text
    .toLowerCase()
    .split('')
    .where((char) => !RegExp(r'[\s（），、()·%\d]').hasMatch(char))
    .map((char) => _initialByChar[char] ?? char)
    .join();

/// A single generic quick-entry powder. Keep original plans/records intact;
/// scale their known nutrition to a 30 g scoop instead of inventing a new label.
bool isProteinPowder(Object? name) => '$name'.contains('蛋白粉');

Map<String, dynamic> proteinPowderFood([Map? configured]) {
  num positive(String key, num fallback) {
    final n = configured?[key];
    return n is num && n.isFinite && n > 0 ? n : fallback;
  }

  final grams = positive('grams', 30);
  return {
    'name': '蛋白粉',
    'unit': '勺',
    'gramsPerUnit': 30,
    'aliases': [
      '蛋白粉',
      '酵母蛋白粉',
      '乳清蛋白粉',
      'protein powder',
      'whey',
      'yeast',
      'dbf',
    ],
    'kcal100': positive('kcal', 124) * 100 / grams,
    'protein100': positive('protein', 22.6) * 100 / grams,
    'carbs100': 0,
    'fat100': 0,
  };
}
