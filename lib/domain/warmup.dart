/// 热身项的辅助数据：一行大白话做法、有没有动作库示范、跟做模式每项的默认时长。
library;

import 'guide.dart';

/// 跟做模式每一项的默认秒数。
const warmupSeconds = 60;

/// 默认计划里的热身项；自定义的热身项没有这里的说明，界面就只显示名字。
const _howTo = <String, String>{
  '肩关节活动': '手臂放松，前后各画大圈 10 次',
  '轻微肩胛运动': '肩胛骨向后夹紧再放松，做 10 次',
  '原地走动': '原地踏步，自然摆臂，身体微热即可',
  '徒手深蹲': '坐下去再站起来，慢慢做 10 次',
  '走路或单车 3～5 分钟': '轻松的速度，微微出汗就行',
  '髋关节活动': '扶稳，一条腿前后、左右各摆 10 次',
};

/// 一行做法；没有收录时返回 null。
String? warmupHowTo(String name) => _howTo[name];

/// 动作库里有对应示范（如「徒手深蹲」→ 深蹲）。
bool warmupHasDemo(String name) => guideFor({'name': name}) != null;
