/// Versioned template metadata. `venues` describes profile equipment; plans use
/// home exercises plus an optional gym variant, as in plan.dart.
const defaultTemplateId = 'bochi-ppl-3';
const List<Map<String, dynamic>> templates = [
  {
    'id': 'bochi-ppl-3',
    'tagline': '推、拉、腿轮着练，最经典的增肌节奏',
    'feature': null,
    'version': 1,
    'name': '薄肌三练 · 推拉腿',
    'summary': '周一推、周三拉、周五腿加补强，兼顾肩、上胸、背阔和腹。核心动作 4～6 次，辅助动作 8～12 次。',
    'days': 3,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['推拉腿', '肩背', '上胸'],
    'for': '每周 3 天；居家哑铃或健身房；各经验阶段；男女均可',
  },
  {
    'id': 'full-2',
    'tagline': '每周只练两天，先把习惯养成',
    'feature': null,
    'version': 1,
    'name': '全身两练 · 入门',
    'summary': '每次覆盖推、拉、腿和核心，两天也能稳步起步。适合时间有限或先建立训练习惯的人。',
    'days': 2,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['全身', '入门', '增肌'],
    'for': '每周 2 天；居家哑铃或健身房；新手优先；男女均可',
  },
  {
    'id': 'ul-4',
    'tagline': '上下肢各练两次，练得更勤更细',
    'feature': null,
    'version': 1,
    'name': '上下肢四练',
    'summary': '上下肢各练两次，把每周训练量分散到四天。适合已有习惯、想继续增肌的人。',
    'days': 4,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['some', 'trained'],
    'tags': ['上下肢', '增肌'],
    'for': '每周 4 天；居家哑铃或健身房；有基础；男女均可',
  },
  {
    'id': 'ppl-5',
    'tagline': '推拉腿之后再各补一次上肢和下肢',
    'feature': null,
    'version': 1,
    'name': '推拉腿 + 上下肢 五练',
    'summary': '推、拉、腿之后各补一次上肢和下肢，周中和周末安排休息。适合能稳定每周五练的人。',
    'days': 5,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['trained'],
    'tags': ['推拉腿', '上下肢', '进阶'],
    'for': '每周 5 天；居家哑铃或健身房；熟练训练者；男女均可',
  },
  {
    'id': 'bodyweight-3',
    'tagline': '不用器械，在家建立训练习惯',
    'feature': null,
    'version': 1,
    'name': '居家自重三练（无器械）',
    'summary':
        '以俯卧撑、桌下反向划船、深蹲和核心建立基础。先增加标准次数，再用背包装书逐步加重；划船需要稳固承重桌，无法保证安全时改超人式。',
    'days': 3,
    'venues': ['bodyweight', 'dumbbell', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['自重', '居家', '入门'],
    'for': '每周 3 天；居家无训练器械；各经验阶段；男女均可',
  },
  {
    'id': 'dumbbell-3',
    'tagline': '一对哑铃，在家练全身',
    'feature': null,
    'version': 1,
    'name': '居家哑铃三练',
    'summary': '一对哑铃覆盖全身，穿插肩背和核心补强。不需要健身房器械。',
    'days': 3,
    'venues': ['dumbbell', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['哑铃', '居家', '全身'],
    'for': '每周 3 天；居家哑铃；各经验阶段；男女均可',
  },
  {
    'id': 'lean-female-3',
    'tagline': '多练臀腿、背和肩，练出线条',
    'feature': '女性向',
    'version': 1,
    'name': '线条三练 · 肩背臀腿',
    'summary': '提高臀腿、背部、肩和核心的比例，保留少量推胸。用逐步进步的力量训练塑造线条。',
    'days': 3,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['女性向', '臀腿', '肩背'],
    'for': '每周 3 天；居家哑铃或健身房；各经验阶段；女性优先、男性也可',
  },
  {
    'id': 'refine-3',
    'tagline': '肩、背、腹多练一些，补强线条',
    'feature': '精修',
    'version': 1,
    'name': '精修三练 · 肩背腹',
    'summary': '肩背和腹部多分配一些训练，仍保留胸腿基础。适合想维持体脂、补强肩背腹的人。',
    'days': 3,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['some', 'trained'],
    'tags': ['精修', '肩背腹'],
    'for': '每周 3 天；居家哑铃或健身房；有基础且体脂较低；男女均可',
  },
  {
    'id': 'legacy-home-gym-3',
    'tagline': '原始方案：居家和健身房两套',
    'feature': null,
    'version': 1,
    'name': '居家 + 健身房三练（原始方案）',
    'summary': '沿用原始方案的动作、俯卧撑阶梯和两种场地。新建模板使用通用蛋白粉默认值，不修改已有方案。',
    'days': 3,
    'venues': ['dumbbell', 'gym', 'both'],
    'level': ['new', 'some', 'trained'],
    'tags': ['原始方案', '居家', '健身房'],
    'for': '每周 3 天；居家哑铃和弹力带或健身房；各经验阶段；男女均可',
  },
];

// First coreCount exercises are core; remaining exercises are accessories.
typedef TemplateDay = ({
  String name,
  String short,
  int coreCount,
  List<String> home,
  List<String> gym,
});
const TemplateDay push = (
  name: '推 · 上胸与肩',
  short: '推',
  coreCount: 3,
  home: ['高位俯卧撑', '哑铃地板卧推', '哑铃肩推', '轻重量侧平举', '站姿哑铃臂屈伸'],
  gym: ['上斜哑铃卧推', '哑铃平板卧推', '坐姿肩推机', '轻哑铃侧平举', '绳索下压'],
);
const TemplateDay pull = (
  name: '拉 · 背阔与体态',
  short: '拉',
  coreCount: 3,
  home: ['轻哑铃罗马尼亚硬拉', '单臂哑铃划船', '弯腰双臂哑铃划船', '俯身哑铃反向飞鸟', '哑铃弯举'],
  gym: ['硬拉', '引体向上', '坐姿划船机', '绳索面拉', '哑铃弯举'],
);
const TemplateDay legs = (
  name: '腿 + 补强',
  short: '腿',
  coreCount: 2,
  home: ['深蹲', '哑铃肩推', '俯身哑铃反向飞鸟', '轻重量侧平举', '反向卷腹', '臀桥'],
  gym: ['深蹲', '坐姿肩推机', '绳索面拉', '轻哑铃侧平举', '绳索卷腹', '臀桥'],
);
const TemplateDay fullA = (
  name: '全身 A',
  short: '全',
  coreCount: 3,
  home: ['高脚杯深蹲', '高位俯卧撑', '单臂哑铃划船', '轻重量侧平举', '死虫式'],
  gym: ['腿举机', '上斜哑铃卧推', '高位下拉', '轻哑铃侧平举', '死虫式'],
);
const TemplateDay fullB = (
  name: '全身 B',
  short: '全',
  coreCount: 3,
  home: ['轻哑铃罗马尼亚硬拉', '哑铃地板卧推', '弯腰双臂哑铃划船', '臀桥', '反向卷腹'],
  gym: ['轻哑铃罗马尼亚硬拉', '哑铃平板卧推', '坐姿划船机', '臀桥', '反向卷腹'],
);
const TemplateDay upper = (
  name: '上肢',
  short: '上',
  coreCount: 3,
  home: ['哑铃地板卧推', '单臂哑铃划船', '哑铃肩推', '俯身哑铃反向飞鸟', '轻重量侧平举'],
  gym: ['上斜哑铃卧推', '高位下拉', '坐姿肩推机', '绳索面拉', '轻哑铃侧平举'],
);
const TemplateDay lower = (
  name: '下肢与核心',
  short: '下',
  coreCount: 2,
  home: ['高脚杯深蹲', '轻哑铃罗马尼亚硬拉', '分腿蹲', '臀桥', '死虫式'],
  gym: ['腿举机', '轻哑铃罗马尼亚硬拉', '坐姿腿弯举', '臀桥', '绳索卷腹'],
);
const TemplateDay glutes = (
  name: '臀腿与背',
  short: '臀',
  coreCount: 3,
  home: ['臀桥', '深蹲', '单臂哑铃划船', '俯身哑铃反向飞鸟', '死虫式'],
  gym: ['臀桥', '腿举机', '高位下拉', '绳索面拉', '死虫式'],
);
const TemplateDay femaleUpper = (
  name: '肩背与核心',
  short: '肩',
  coreCount: 2,
  home: ['单臂哑铃划船', '哑铃肩推', '高位俯卧撑', '轻重量侧平举', '反向卷腹'],
  gym: ['坐姿划船机', '坐姿肩推机', '上斜哑铃卧推', '轻哑铃侧平举', '绳索卷腹'],
);
const TemplateDay refine = (
  name: '肩背腹补强',
  short: '肩',
  coreCount: 2,
  home: ['单臂哑铃划船', '哑铃肩推', '轻重量侧平举', '俯身哑铃反向飞鸟', '卷腹', '侧平板支撑'],
  gym: ['高位下拉', '坐姿肩推机', '轻哑铃侧平举', '绳索面拉', '绳索卷腹', '侧平板支撑'],
);
const TemplateDay bwA = (
  name: '自重 A',
  short: '全',
  coreCount: 3,
  home: ['高位俯卧撑', '反向划船', '深蹲', '臀桥', '死虫式'],
  gym: ['哑铃平板卧推', '高位下拉', '腿举机', '臀桥', '死虫式'],
);
const TemplateDay bwB = (
  name: '自重 B',
  short: '全',
  coreCount: 3,
  home: ['高位俯卧撑', '反向划船', '分腿蹲', '单腿臀桥', '反向卷腹'],
  gym: ['上斜哑铃卧推', '坐姿划船机', '分腿蹲', '单腿臀桥', '反向卷腹'],
);
const TemplateDay bwC = (
  name: '自重 C',
  short: '全',
  coreCount: 3,
  home: ['高位俯卧撑', '反向划船', '深蹲', '站姿提踵', '平板支撑'],
  gym: ['哑铃平板卧推', '高位下拉', '深蹲', '站姿提踵', '平板支撑'],
);
const Map<String, List<TemplateDay>> templateDays = {
  'bochi-ppl-3': [push, pull, legs],
  'full-2': [fullA, fullB],
  'ul-4': [upper, lower, upper, lower],
  'ppl-5': [push, pull, legs, upper, lower],
  'bodyweight-3': [bwA, bwB, bwC],
  'dumbbell-3': [fullA, fullB, upper],
  'lean-female-3': [glutes, femaleUpper, lower],
  'refine-3': [upper, lower, refine],
};
