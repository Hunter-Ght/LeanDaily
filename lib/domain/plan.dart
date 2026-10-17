// Default tables transcribed from web/src/lib/plan.js; fresh JSON per call.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'dart:convert';
import 'dart:math' as math;

import 'format.dart';

const _defaultJson = r'''
{
  "version": 2,
  "startDate": "",
  "schedule": {
    "1": "w1",
    "3": "w2",
    "5": "w3"
  },
  "order": [
    "w1",
    "w2",
    "w3"
  ],
  "warmup": {
    "minutes": 5,
    "items": [
      "肩关节活动",
      "轻微肩胛运动",
      "原地走动",
      "徒手深蹲"
    ],
    "note": "第一个动作先做一组特别轻的练习"
  },
  "rules": [
    "每组留 2～3 次余力，不追求力竭",
    "组间休息 60～120 秒，俯卧撑或深蹲累得厉害就休息到 2 分钟",
    "尖锐疼痛、关节疼、明显头晕就停下；肌肉发酸和关节疼不是一回事"
  ],
  "ladders": {
    "pushup": {
      "stage": 0,
      "steps": [
        {
          "name": "高位俯卧撑",
          "min": 6,
          "max": 12,
          "hint": "双手撑稳固的厨房台面或高桌，连续两次做满 12 次、动作不变形就升级"
        },
        {
          "name": "低台面俯卧撑",
          "min": 6,
          "max": 12,
          "hint": "换成更低、仍然稳固的支撑物，连续两次做满 12 次就升级"
        },
        {
          "name": "跪姿俯卧撑",
          "min": 8,
          "max": 12,
          "hint": "肩—髋—膝成一条线，连续两次做满 12 次就试标准俯卧撑"
        },
        {
          "name": "标准俯卧撑",
          "min": 1,
          "max": 8,
          "hint": "每组 1～3 个标准动作起步，做不动就换回高位版补量"
        }
      ]
    }
  },
  "workouts": {
    "w1": {
      "name": "胸 + 肩 + 腹",
      "tag": "胸肌重点日",
      "note": "只有 30 分钟：做高位俯卧撑 + 弹力带胸推 + 腹肌。胸肌是主角，不用全做到很累。",
      "exercises": [
        {
          "id": "e1",
          "ladder": "pushup",
          "name": "高位俯卧撑",
          "part": "胸",
          "sets": 2,
          "min": 6,
          "max": 12,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "稳固、不滑动的台面",
          "tip": "身体保持一条直线；动作标准比多做几个更有用。台面不能晃、不能打滑，不要用带轮子的椅子。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e2",
          "name": "弹力带胸推",
          "part": "胸",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "黑色无手柄弹力带",
          "alt": "哑铃地板卧推",
          "alts": [
            {
              "name": "哑铃地板卧推",
              "weight": 5
            }
          ],
          "tip": "弹力带从背后肩胛附近绕过，两手握住两端向前推。先检查有没有老化破损，别让它朝脸回弹；阻力不合适就改哑铃地板卧推。",
          "machine": false,
          "rest": 0
        },
        {
          "id": "e3",
          "name": "哑铃肩推",
          "part": "肩",
          "sets": 2,
          "min": 6,
          "max": 10,
          "unit": "reps",
          "side": false,
          "weight": 5,
          "core": false,
          "optional": true,
          "gear": "5 kg 哑铃 × 2",
          "tip": "5 kg 太重、需要后仰借力，就改用水瓶，不硬上。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e4",
          "name": "轻重量侧平举",
          "part": "肩",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 1,
          "core": false,
          "optional": false,
          "gear": "500 mL～1.5 L 水瓶（重量按 1 kg 记）",
          "tip": "先别强行拿 5 kg，很多新手会耸肩和甩手。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e5",
          "name": "卷腹",
          "part": "核心",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "徒手",
          "alt": "死虫式",
          "alts": [
            {
              "name": "死虫式"
            }
          ],
          "tip": "缓慢控制，不要扯脖子或过度拱腰。卷腹和死虫式二选一。",
          "machine": false,
          "rest": 0
        }
      ],
      "gym": {
        "tag": "胸肌重点日",
        "note": "优先级：推胸机 → 上斜推胸 → 侧平举。时间不足时，腹肌少一组，别为了凑动作硬练。",
        "exercises": [
          {
            "id": "g1",
            "name": "坐姿推胸机",
            "part": "胸",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "坐姿推胸机",
            "tip": "调座椅，让握柄大致在胸部中段；肩胛稳定，向前推，不要耸肩。",
            "rest": 120,
            "alts": [
              {
                "name": "哑铃平板卧推",
                "weight": 5,
                "machine": false
              },
              {
                "name": "高位俯卧撑"
              }
            ]
          },
          {
            "id": "g2",
            "name": "上斜推胸机",
            "part": "胸",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "上斜推胸机",
            "tip": "兼顾上胸，让胸部更饱满；不要把座椅调得过高变成纯肩推。",
            "rest": 120,
            "alts": [
              {
                "name": "上斜哑铃卧推",
                "weight": 5,
                "machine": false
              },
              {
                "name": "坐姿推胸机",
                "machine": true
              }
            ]
          },
          {
            "id": "g3",
            "name": "坐姿肩推机",
            "part": "肩",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": false,
            "machine": true,
            "gear": "坐姿肩推机",
            "tip": "用可控范围推，避免后仰、腰部过度拱起。",
            "rest": 90,
            "alts": [
              {
                "name": "轻哑铃坐姿肩推",
                "weight": 5,
                "machine": false
              }
            ]
          },
          {
            "id": "g4",
            "name": "轻哑铃侧平举",
            "part": "肩",
            "sets": 2,
            "min": 12,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 2,
            "core": true,
            "optional": false,
            "machine": false,
            "gear": "轻哑铃",
            "tip": "重量轻一点，抬到肩高附近；别耸肩、甩腰。",
            "rest": 75,
            "alts": [
              {
                "name": "拉力器单臂侧平举",
                "machine": true
              }
            ]
          },
          {
            "id": "g5",
            "name": "卷腹机",
            "part": "核心",
            "sets": 2,
            "min": 10,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": false,
            "machine": true,
            "gear": "卷腹机 / 绳索",
            "tip": "卷动躯干，不要只用手臂拉绳子。",
            "rest": 75,
            "alts": [
              {
                "name": "绳索卷腹",
                "machine": true
              },
              {
                "name": "卷腹"
              },
              {
                "name": "死虫式"
              }
            ]
          }
        ]
      }
    },
    "w2": {
      "name": "背 + 腿 + 手臂",
      "tag": "让身体比例更好",
      "note": "没有引体向上也没关系，先用单臂哑铃划船练背。",
      "exercises": [
        {
          "id": "e6",
          "name": "单臂哑铃划船",
          "part": "背",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": true,
          "weight": 5,
          "core": true,
          "optional": false,
          "gear": "5 kg 哑铃 + 稳固桌面",
          "tip": "另一手扶稳桌面，背自然平直，把哑铃拉向髋部，顶端停 1 秒。每侧做完为一组。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e7",
          "name": "深蹲",
          "part": "腿",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "徒手或双手抱哑铃",
          "tip": "先把幅度和控制练标准，别为了负重弯腰塌背。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e8",
          "name": "分腿蹲",
          "part": "腿",
          "sets": 2,
          "min": 8,
          "max": 12,
          "unit": "reps",
          "side": true,
          "weight": 0,
          "core": false,
          "optional": false,
          "gear": "徒手优先",
          "tip": "增加腿部刺激，注意扶稳避免失去平衡。每侧做完为一组。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e9",
          "name": "哑铃弯举",
          "part": "手臂",
          "sets": 2,
          "min": 8,
          "max": 12,
          "unit": "reps",
          "side": false,
          "weight": 5,
          "core": false,
          "optional": false,
          "gear": "5 kg 哑铃",
          "tip": "5 kg 太重就交替单臂练，不能借甩腰完成。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e10",
          "name": "臀桥",
          "part": "腿",
          "sets": 2,
          "min": 12,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": false,
          "optional": false,
          "gear": "徒手",
          "tip": "顶端收紧臀部 1 秒，慢慢放下。",
          "alts": [],
          "machine": false,
          "rest": 0
        }
      ],
      "gym": {
        "tag": "比例和体态日",
        "note": "不方便做引体向上？健身房直接用高位下拉机，比勉强吊在杆上更容易调整难度。",
        "exercises": [
          {
            "id": "g6",
            "name": "高位下拉",
            "part": "背",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "高位下拉机",
            "tip": "把横杆拉向上胸，肩膀不要一直耸着；不要猛甩身体。",
            "rest": 120,
            "alts": [
              {
                "name": "辅助引体向上机",
                "machine": true
              }
            ]
          },
          {
            "id": "g7",
            "name": "坐姿划船机",
            "part": "背",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "坐姿划船机",
            "tip": "胸口自然挺起，把手柄拉向腹部，别靠后仰借力。",
            "rest": 120,
            "alts": [
              {
                "name": "单臂哑铃划船",
                "weight": 5,
                "side": true,
                "machine": false
              }
            ]
          },
          {
            "id": "g8",
            "name": "腿举机",
            "part": "腿",
            "sets": 2,
            "min": 10,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": false,
            "machine": true,
            "gear": "腿举机",
            "tip": "双脚踩稳，膝盖跟脚尖方向一致；下放别让腰背离开靠垫。",
            "rest": 120,
            "alts": [
              {
                "name": "徒手深蹲"
              },
              {
                "name": "高脚杯深蹲",
                "weight": 5
              }
            ]
          },
          {
            "id": "g9",
            "name": "坐姿腿弯举",
            "part": "腿",
            "sets": 2,
            "min": 10,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": false,
            "machine": true,
            "gear": "坐姿 / 俯卧腿弯举机",
            "tip": "补一下大腿后侧，缓慢做。",
            "rest": 90,
            "alts": [
              {
                "name": "轻哑铃罗马尼亚硬拉",
                "weight": 5,
                "machine": false
              }
            ]
          },
          {
            "id": "g10",
            "name": "哑铃弯举",
            "part": "手臂",
            "sets": 2,
            "min": 10,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 5,
            "core": false,
            "optional": false,
            "machine": false,
            "gear": "哑铃",
            "tip": "肘部别来回甩，动作完整。",
            "rest": 75,
            "alts": [
              {
                "name": "二头弯举机",
                "machine": true
              }
            ]
          }
        ]
      }
    },
    "w3": {
      "name": "胸 + 背 + 腹",
      "tag": "第二次刺激胸肌",
      "note": "目标是比周一更稳，而不是每次非要多做一个。",
      "exercises": [
        {
          "id": "e11",
          "ladder": "pushup",
          "name": "高位俯卧撑",
          "part": "胸",
          "sets": 2,
          "min": 6,
          "max": 12,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "稳固台面",
          "tip": "比周一更稳，而不是每次非要多做一个。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e12",
          "name": "哑铃地板卧推",
          "part": "胸",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 5,
          "core": true,
          "optional": false,
          "gear": "5 kg × 2 + 地上铺毛巾或垫子",
          "tip": "仰卧屈膝，手握哑铃从胸旁向上推，手肘别过度外张。本周胸肌还明显酸痛，可减 1 组。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e13",
          "name": "单臂哑铃划船",
          "part": "背",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": true,
          "weight": 5,
          "core": false,
          "optional": false,
          "gear": "5 kg 哑铃 + 稳固桌面",
          "tip": "背部一周再练一次，避免只练胸不练背。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e14",
          "name": "反向卷腹",
          "part": "核心",
          "sets": 2,
          "min": 10,
          "max": 15,
          "unit": "reps",
          "side": false,
          "weight": 0,
          "core": true,
          "optional": false,
          "gear": "徒手",
          "tip": "轻轻卷起骨盆，不要靠甩腿。",
          "alts": [],
          "machine": false,
          "rest": 0
        },
        {
          "id": "e15",
          "name": "平板支撑",
          "part": "核心",
          "sets": 2,
          "min": 20,
          "max": 40,
          "unit": "sec",
          "side": false,
          "weight": 0,
          "core": false,
          "optional": false,
          "gear": "徒手",
          "tip": "屁股不塌、腰不拱，保持呼吸。次数一栏记的是秒数。",
          "alts": [],
          "machine": false,
          "rest": 0
        }
      ],
      "gym": {
        "tag": "第二次刺激胸肌",
        "note": "拉力器夹胸只是补充，不是必须做：没人教或肩不舒服，就用蝴蝶机或跳过。不要为了「练下胸」强做双杠臂屈伸。",
        "exercises": [
          {
            "id": "g11",
            "name": "坐姿推胸机",
            "part": "胸",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "坐姿推胸机",
            "tip": "和周一用同一台，争取动作更稳、次数更足。",
            "rest": 120,
            "alts": [
              {
                "name": "哑铃平板卧推",
                "weight": 5,
                "machine": false
              },
              {
                "name": "高位俯卧撑"
              }
            ]
          },
          {
            "id": "g12",
            "name": "拉力器高位向下夹胸",
            "part": "胸",
            "sets": 2,
            "min": 10,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": true,
            "machine": true,
            "gear": "双侧拉力器",
            "tip": "两侧滑轮调高，双手从胸侧较高位置向身体前下方合拢；轻重量、控制轨迹。",
            "rest": 90,
            "alts": [
              {
                "name": "蝴蝶机夹胸",
                "machine": true
              }
            ]
          },
          {
            "id": "g13",
            "name": "坐姿划船机",
            "part": "背",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": true,
            "gear": "坐姿划船机",
            "tip": "练背部厚度和体态。",
            "rest": 120,
            "alts": [
              {
                "name": "单臂哑铃划船",
                "weight": 5,
                "side": true,
                "machine": false
              }
            ]
          },
          {
            "id": "g14",
            "name": "高位下拉",
            "part": "背",
            "sets": 2,
            "min": 8,
            "max": 12,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": false,
            "machine": true,
            "gear": "高位下拉机",
            "tip": "练背阔肌宽度。",
            "rest": 120,
            "alts": [
              {
                "name": "辅助引体向上机",
                "machine": true
              }
            ]
          },
          {
            "id": "g15",
            "name": "反向卷腹",
            "part": "核心",
            "sets": 2,
            "min": 10,
            "max": 15,
            "unit": "reps",
            "side": false,
            "weight": 0,
            "core": true,
            "optional": false,
            "machine": false,
            "gear": "垫子",
            "tip": "缓慢卷起骨盆，不靠甩腿。",
            "rest": 75,
            "alts": [
              {
                "name": "卷腹机",
                "machine": true
              }
            ]
          },
          {
            "id": "g16",
            "name": "平板支撑",
            "part": "核心",
            "sets": 2,
            "min": 20,
            "max": 40,
            "unit": "sec",
            "side": false,
            "weight": 0,
            "core": false,
            "optional": true,
            "machine": false,
            "gear": "垫子",
            "tip": "腰别塌，正常呼吸。",
            "rest": 60,
            "alts": [
              {
                "name": "死虫式"
              }
            ]
          }
        ]
      }
    }
  },
  "venues": {},
  "setups": {},
  "gymWarmup": {
    "minutes": 6,
    "items": [
      "走路或单车 3～5 分钟",
      "肩关节活动",
      "髋关节活动"
    ],
    "note": "每次第一个器械动作先用很轻重量试做 1～2 组（热身组不算正式组）"
  },
  "gymRules": [
    "重量选一个能规范做完目标次数、做完还能再做 2～3 次（RIR 2～3）的；机器上的数字没有统一标准，不用照抄别人",
    "组间休息：推胸、下拉、划船、腿举约 90～150 秒；侧平举、弯举、腹肌约 60～90 秒",
    "慢慢下降，稳定发力，不借力甩、不耸肩、不憋气；尖锐疼痛或关节疼就停",
    "器械不会调就问工作人员：座椅高度、握柄位置比盲目上重量重要",
    "加重规则：连续两次训练都做满上限（如 12/12/12）且动作没变形，就加机器允许的最小一档"
  ],
  "protein": {
    "goal": 110,
    "powder": {
      "name": "蛋白粉",
      "grams": 30,
      "protein": 22.6,
      "kcal": 124
    }
  },
  "reminder": {
    "enabled": true,
    "time": "19:00",
    "nudge": true,
    "restDay": true,
    "protein": true,
    "proteinTime": "16:00"
  }
}
''';

Map<String, dynamic> defaultPlan([String startDate = '']) =>
    jsonMap(jsonDecode(_defaultJson))..['startDate'] = startDate;
Map<String, dynamic> defaultGym() => {
  for (final e in jsonMap(defaultPlan()['workouts']).entries)
    e.key: jsonMap(e.value)['gym'],
};
final Map<String, dynamic> GYM_WARMUP = jsonMap(defaultPlan()['gymWarmup']);
final List<dynamic> GYM_RULES = List<dynamic>.from(
  defaultPlan()['gymRules'] as List,
);
final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
int _clamp(Map<String, dynamic> m, String key, int lo, int hi, int fallback) {
  if (!m.containsKey(key)) return fallback;
  final n = jsNumber(m[key]);
  return n.isFinite ? (n + 0.5).floor().clamp(lo, hi) : fallback;
}

void _attachGym(Map<String, dynamic> plan) {
  final workouts = jsonMap(plan['workouts']);
  for (final e in defaultGym().entries) {
    if (workouts[e.key] is Map && !jsTruthy(workouts[e.key]['gym'])) {
      workouts[e.key]['gym'] = e.value;
    }
  }
}

/// 蛋白粉不再区分种类：旧版默认名“酵母蛋白粉”显示为“蛋白粉”。
/// 已保存的计划原样保留，只在显示和记录时换名。
String powderLabel(Object? name) {
  final text = jsString(name);
  return text == '酵母蛋白粉' ? '蛋白粉' : text;
}

Map<String, dynamic> normalizePlan(Object? raw, [String startDate = '']) {
  final base = defaultPlan(startDate);
  final r = jsonMap(raw);
  if (![1, 2].contains(r['version']) ||
      r['workouts'] is! Map && r['workouts'] is! List) {
    return base;
  }
  // Match Web: normalize nested workouts in place; top-level fields are merged.
  final source = r;
  final p = <String, dynamic>{...base, ...source}
    ..remove('rampWeeks')
    ..remove('rampSets');
  p['version'] = 2;
  p['startDate'] =
      r['startDate'] is String &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(r['startDate'] as String)
      ? r['startDate']
      : startDate;
  final workouts = source['workouts'] is Map<String, dynamic>
      ? source['workouts'] as Map<String, dynamic>
      : jsonMap(source['workouts']);
  p['workouts'] = source['workouts'] is List ? source['workouts'] : workouts;
  p['order'] =
      (r['order'] is List ? r['order'] as List : workouts.keys.toList())
          .where((id) => jsTruthy(workouts[id]))
          .toList();
  p['schedule'] = <String, dynamic>{};
  p['venues'] = <String, dynamic>{};
  for (var d = 0; d < 7; d++) {
    final id = jsonMap(r['schedule'])['$d'];
    if (jsTruthy(id) && jsTruthy(workouts[id])) p['schedule']['$d'] = id;
    if (jsonMap(r['venues'])['$d'] == 'gym') p['venues']['$d'] = 'gym';
  }
  p['setups'] = source['setups'] is Map || source['setups'] is List
      ? source['setups']
      : <String, dynamic>{};
  p['gymWarmup'] = jsTruthy(jsonMap(source['gymWarmup'])['items'])
      ? source['gymWarmup']
      : base['gymWarmup'];
  p['gymRules'] = source['gymRules'] is List
      ? source['gymRules']
      : base['gymRules'];
  _attachGym(p);
  final baseAlts = <dynamic, dynamic>{};
  for (final w in jsonRows(jsonMap(base['workouts']).values.toList())) {
    for (final e in [
      ...jsonRows(w['exercises']),
      ...jsonRows(jsonMap(w['gym'])['exercises']),
    ]) {
      baseAlts[e['id']] = e['alts'];
    }
  }
  p['ladders'] = source['ladders'] is Map || source['ladders'] is List
      ? source['ladders']
      : base['ladders'];
  List<Map<String, dynamic>> fixList(Object? list) => jsonRows(list)
      .map(
        (e) => <String, dynamic>{
          ...e,
          'alts': e['alts'] is List
              ? (e['alts'] as List)
                    .where((a) => jsTruthy(jsonMap(a)['name']))
                    .toList()
              : baseAlts[e['id']] ?? [],
          'machine': jsTruthy(e['machine']),
          'rest': _clamp(e, 'rest', 0, 300, 0),
          'sets': _clamp(e, 'sets', 1, 10, 2),
          'min': _clamp(e, 'min', 1, 500, 8),
          'max': math.max(
            _clamp(e, 'min', 1, 500, 8),
            _clamp(e, 'max', 1, 500, 12),
          ),
          'img': e['img'] is String ? e['img'] : '',
          'weight':
              e.containsKey('weight') &&
                  jsNumber(e['weight']).isFinite &&
                  jsNumber(e['weight']) >= 0
              ? jsNumber(e['weight'])
              : 0,
          'unit': e['unit'] == 'sec' ? 'sec' : 'reps',
        },
      )
      .toList();
  for (final w in workouts.values) {
    w['exercises'] = fixList(w['exercises']);
    if (jsTruthy(w['gym'])) {
      w['gym'] = <String, dynamic>{
        ...jsonMap(w['gym']),
        'exercises': fixList(w['gym']['exercises']),
      };
    }
  }
  if (r['version'] == 1) {
    const old = {'e1', 'e6', 'e7', 'e11', 'g1', 'g6', 'g8', 'g13'};
    for (final w in workouts.values) {
      for (final e in [
        ...(w['exercises'] as List),
        ...(jsonMap(w['gym'])['exercises'] as List? ?? []),
      ]) {
        if (old.contains(e['id']) && e['sets'] == 3) e['sets'] = 2;
      }
    }
    for (final e in jsonMap(p['ladders']).entries) {
      final b = jsonMap(base['ladders'])[e.key];
      if (b != null &&
          (b['steps'] as List).length == (e.value['steps'] as List).length) {
        p['ladders'][e.key] = <String, dynamic>{
          ...jsonMap(b),
          'stage': math.min(
            jsTruthy(e.value['stage']) ? jsNumber(e.value['stage']) : 0,
            (b['steps'] as List).length - 1,
          ),
        };
      }
    }
  }
  p['reminder'] = <String, dynamic>{
    ...jsonMap(base['reminder']),
    ...jsonMap(source['reminder']),
  };
  for (final key in ['time', 'proteinTime']) {
    if (!_time.hasMatch(jsString(p['reminder'][key]))) {
      p['reminder'][key] = base['reminder'][key];
    }
  }
  p['protein'] = <String, dynamic>{
    ...jsonMap(base['protein']),
    ...jsonMap(source['protein']),
    'powder': <String, dynamic>{
      ...jsonMap(base['protein']['powder']),
      ...jsonMap(jsonMap(source['protein'])['powder']),
    },
  };
  p['protein']['goal'] = _clamp(
    jsonMap(p['protein']),
    'goal',
    20,
    400,
    base['protein']['goal'] as int,
  );
  return p;
}

int dow(String iso) => isoDate(iso).weekday % 7;
int daysBetween(String a, String b) => isoDate(b).difference(isoDate(a)).inDays;
int weekNumber(Map<String, dynamic> plan, String iso) =>
    !jsTruthy(plan['startDate'])
    ? 1
    : math.max(
        1,
        (daysBetween(plan['startDate'] as String, iso) / 7).floor() + 1,
      );
Map<String, dynamic> resolveEx(
  Map<String, dynamic> plan,
  Map<String, dynamic> ex,
) {
  final ladder = jsonMap(jsonMap(plan['ladders'])[ex['ladder']]);
  final steps = ladder['steps'];
  final stage = ladder['stage'];
  // JS array property lookup also accepts canonical string indices.
  final index = stage is num
      ? stage
      : stage is String && RegExp(r'^(0|[1-9]\d*)$').hasMatch(stage)
      ? int.tryParse(stage)
      : null;
  if (steps is! List ||
      index == null ||
      index != index.toInt() ||
      index < 0 ||
      index >= steps.length) {
    return ex;
  }
  final step = jsonMap(steps[index.toInt()]);
  return {
    ...ex,
    'name': step['name'],
    'min': step['min'],
    'max': step['max'],
    'step': step,
    'stage': stage,
    'stages': steps.length,
  };
}

dynamic setupOf(Map<String, dynamic> plan, Map<String, dynamic> ex) {
  final value = jsonMap(plan['setups'])[ex['name']];
  return jsTruthy(value) ? value : '';
}

dynamic setsFor(
  Map<String, dynamic> plan,
  Map<String, dynamic> ex, [
  String? iso,
]) => ex['sets'];
dynamic venueOf(
  Map<String, dynamic> plan,
  String iso, [
  Map<String, dynamic>? dayState,
]) => jsTruthy(dayState?['venue'])
    ? dayState!['venue']
    : jsTruthy(jsonMap(plan['venues'])['${dow(iso)}'])
    ? jsonMap(plan['venues'])['${dow(iso)}']
    : 'home';
Map<String, dynamic> swapEx(Map<String, dynamic> e, String altName) {
  final alts = jsonRows(e['alts']).where((a) => a['name'] == altName);
  if (alts.isEmpty) return e;
  final a = alts.first;
  return <String, dynamic>{
    ...e,
    'name': a['name'],
    'origName': e['name'],
    'swapped': true,
    'machine': jsTruthy(a['machine']),
    'weight': a['weight'] ?? 0,
    'side': a['side'] ?? e['side'],
    'img': '',
    'setup': '',
    'gear': jsTruthy(a['gear']) ? a['gear'] : '',
    'tip': '原动作：${e['name']}。${e['tip'] ?? ''}',
  }..remove('ladder');
}

Map<String, dynamic> workoutFor(
  Map<String, dynamic> plan,
  String iso, [
  Map<String, dynamic>? dayState,
]) {
  final o = dayState?['override'];
  dynamic id;
  var overridden = false;
  Map<String, dynamic> rest(bool v) => {
    'kind': 'rest',
    'id': null,
    'workout': null,
    'overridden': v,
  };
  if (o == 'rest') return rest(true);
  final workouts = jsonMap(plan['workouts']);
  if (jsTruthy(o) && jsTruthy(workouts[o])) {
    id = o;
    overridden = true;
  } else {
    final s = jsonMap(plan['schedule'])['${dow(iso)}'];
    if (jsTruthy(s) && jsTruthy(workouts[s])) id = s;
  }
  if (id == null) return rest(false);
  final base = jsonMap(workouts[id]);
  final gym = venueOf(plan, iso, dayState) == 'gym' && jsTruthy(base['gym']);
  final v = gym ? jsonMap(base['gym']) : base;
  final swaps = jsonMap(dayState?['swaps']);
  final w = <String, dynamic>{
    if (base.containsKey('name')) 'name': base['name'],
    if (v.containsKey('tag') || base.containsKey('tag'))
      'tag': v['tag'] ?? base['tag'],
    if (v.containsKey('note') || base.containsKey('note'))
      'note': v['note'] ?? base['note'],
    'venue': gym ? 'gym' : 'home',
    'hasGym': jsTruthy(base['gym']),
    if (plan.containsKey(gym ? 'gymWarmup' : 'warmup'))
      'warmup': plan[gym ? 'gymWarmup' : 'warmup'],
    if (plan.containsKey(gym ? 'gymRules' : 'rules'))
      'rules': plan[gym ? 'gymRules' : 'rules'],
    'exercises': jsonRows(v['exercises'])
        .map(
          (e) => jsTruthy(swaps[e['id']])
              ? swapEx(e, swaps[e['id']].toString())
              : e,
        )
        .toList(),
  };
  return {'kind': 'train', 'id': id, 'workout': w, 'overridden': overridden};
}

Map<String, dynamic>? nextTraining(
  Map<String, dynamic> plan,
  String iso, [
  Map<String, dynamic> dayStates = const {},
]) {
  for (var i = 1; i <= 7; i++) {
    final d = shiftDate(iso, i),
        w = workoutFor(
          plan,
          shiftDate(iso, i),
          jsonMap(dayStates[shiftDate(iso, i)]),
        );
    if (w['kind'] == 'train') {
      return {'iso': d, 'id': w['id'], 'workout': w['workout'], 'inDays': i};
    }
  }
  return null;
}

List<Map<String, dynamic>> exercisesFor(
  Map<String, dynamic> plan,
  Map<String, dynamic>? workout,
  String iso, [
  bool lite = false,
  num Function(Map<String, dynamic>)? setsOf,
]) => jsonRows(workout?['exercises'])
    .map((e) => resolveEx(plan, e))
    .where((e) => !lite || jsTruthy(e['core']) && !jsTruthy(e['optional']))
    .map(
      (e) => <String, dynamic>{
        ...e,
        'target': setsOf != null ? setsOf(e) : setsFor(plan, e, iso),
      },
    )
    .toList();
String rangeText(Map<String, dynamic> e) =>
    '${e['min'] == e['max'] ? jsString(e['min']) : '${jsString(e['min'])}～${jsString(e['max'])}'}${e['unit'] == 'sec'
        ? ' 秒'
        : jsTruthy(e['side'])
        ? ' 次/侧'
        : ' 次'}';
String prescription(Map<String, dynamic> e) =>
    '${jsString(e['target'] ?? e['sets'])} 组 × ${rangeText(e)}';
int estimateMinutes(
  Map<String, dynamic> plan,
  List<Map<String, dynamic>> list, [
  num? warmMin,
]) {
  final sec = list
      .where((e) => !jsTruthy(e['optional']))
      .fold<num>(
        0,
        (n, e) =>
            n +
            jsNumber(e['target']) *
                ((jsTruthy(e['rest']) ? jsNumber(e['rest']) : 90) + 50),
      );
  return (((warmMin ?? jsNumber(jsonMap(plan['warmup'])['minutes'])) +
                      sec / 60) /
                  5 +
              0.5)
          .floor() *
      5;
}

List<Map<String, dynamic>> formalSets(Map<String, dynamic>? day, String name) {
  final indexed = jsonRows(day?['sets'])
      .where(
        (s) => s['ex'] == name && s['type'] != '热身' && !jsTruthy(s['deleted']),
      )
      .indexed
      .toList();
  indexed.sort((a, b) {
    final n =
        (jsTruthy(a.$2['no']) ? jsNumber(a.$2['no']) : 0) -
        (jsTruthy(b.$2['no']) ? jsNumber(b.$2['no']) : 0);
    return n.isNaN || n == 0 ? a.$1.compareTo(b.$1) : n.sign.toInt();
  });
  return indexed.map((e) => e.$2).toList();
}

Map<String, dynamic> dayProgress(
  Map<String, dynamic> plan,
  Map<String, dynamic>? workout,
  String iso,
  Map<String, dynamic>? day, [
  bool lite = false,
  num Function(Map<String, dynamic>)? setsOf,
]) {
  final items = exercisesFor(plan, workout, iso, lite, setsOf).map((e) {
    final s = formalSets(day, e['name'] as String);
    return <String, dynamic>{
      'ex': e,
      'sets': s,
      'done': s.length,
      'complete': s.length >= jsNumber(e['target']),
    };
  }).toList();
  final need = items.where((i) => !jsTruthy(i['ex']['optional'])).toList();
  return {
    'items': items,
    'totalSets': need.fold<num>(0, (n, i) => n + jsNumber(i['ex']['target'])),
    'doneSets': need.fold<num>(
      0,
      (n, i) => n + math.min(i['done'] as int, jsNumber(i['ex']['target'])),
    ),
    'complete': need.isNotEmpty && need.every((i) => i['complete'] == true),
  };
}

Map<String, dynamic>? lastSession(
  Map<String, dynamic>? days,
  String name,
  String beforeIso,
) {
  final dates =
      (days ?? {}).keys.where((d) => d.compareTo(beforeIso) < 0).toList()
        ..sort((a, b) => b.compareTo(a));
  for (final d in dates) {
    final sets = formalSets(jsonMap(days![d]), name);
    if (sets.isNotEmpty) return {'date': d, 'sets': sets};
  }
  return null;
}

Map<String, dynamic> upgradeLadder(
  Map<String, dynamic> plan,
  String ladderId, [
  num? stage,
]) {
  final next = cloneJson(plan), ladder = jsonMap(plan['ladders'])[ladderId];
  next['ladders'][ladderId]['stage'] = math.max(
    0,
    math.min(
      (ladder['steps'] as List).length - 1,
      stage ?? jsNumber(ladder['stage']) + 1,
    ),
  );
  return next;
}

Map<String, dynamic>? missedWorkout(
  Map<String, dynamic> plan,
  String iso,
  Map<String, dynamic>? dayStates,
  Map<String, dynamic>? days,
) {
  if (workoutFor(plan, iso, jsonMap(dayStates?[iso]))['kind'] == 'train') {
    return null;
  }
  final y = shiftDate(iso, -1);
  if (jsTruthy(plan['startDate']) &&
      y.compareTo(plan['startDate'] as String) < 0) {
    return null;
  }
  final prev = workoutFor(plan, y, jsonMap(dayStates?[y]));
  if (prev['kind'] != 'train' || prev['overridden'] == true) return null;
  return jsonRows(jsonMap(days?[y])['sets']).any((s) => s['type'] != '热身')
      ? null
      : {'iso': y, 'id': prev['id'], 'workout': prev['workout']};
}

List<Map<String, dynamic>> weekPlan(
  Map<String, dynamic> plan,
  String iso,
  Map<String, dynamic>? dayStates,
  Map<String, dynamic>? days,
) {
  final start = shiftDate(iso, dow(iso) == 0 ? -6 : 1 - dow(iso));
  return List.generate(7, (i) {
    final d = shiftDate(start, i),
        w = workoutFor(
          plan,
          shiftDate(start, i),
          jsonMap(dayStates?[shiftDate(start, i)]),
        );
    final workout = jsonMap(w['workout']);
    return {
      'iso': d,
      'label': weekday(d).substring(1),
      'today': d == iso,
      'kind': w['kind'],
      'name': jsTruthy(workout['name']) ? workout['name'] : '休息',
      'venue': workout['venue'] ?? '',
      'done': jsonRows(jsonMap(days?[d])['sets']).any((s) => s['type'] != '热身'),
      'past': d.compareTo(iso) < 0,
    };
  });
}

DateTime _atTime(String iso, String hhmm, [int addMin = 0]) {
  final date = isoDate(iso, utc: false),
      hm = hhmm.split(':').map(int.parse).toList();
  return DateTime(date.year, date.month, date.day, hm[0], hm[1] + addMin);
}

List<Map<String, dynamic>> buildReminders({
  required Map<String, dynamic> plan,
  required DateTime now,
  required String today,
  Map<String, dynamic> dayStates = const {},
  bool todayDone = false,
  bool powderToday = false,
  int days = 14,
}) {
  final r = jsonMap(plan['reminder']);
  if (!jsTruthy(r['enabled'])) return [];
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < days; i++) {
    final iso = shiftDate(today, i),
        w = workoutFor(
          plan,
          shiftDate(today, i),
          jsonMap(dayStates[shiftDate(today, i)]),
        );
    void add(int kind, DateTime at, String title, String body) {
      if (at.isAfter(now)) {
        out.add({
          'id': 1000 + i * 10 + kind,
          'at': at,
          'title': title,
          'body': body,
        });
      }
    }

    if (w['kind'] == 'train') {
      final workout = jsonMap(w['workout']),
          list = exercisesFor(plan, jsonMap(w['workout']), iso);
      if (!(i == 0 && todayDone)) {
        final body = list
            .map(
              (e) =>
                  '${e['name']} ${jsString(e['target'])}×${e['min'] == e['max'] ? jsString(e['min']) : '${jsString(e['min'])}-${jsString(e['max'])}'}${e['unit'] == 'sec' ? '秒' : ''}${jsTruthy(e['optional']) ? '(可选)' : ''}',
            )
            .join('，');
        add(
          0,
          _atTime(iso, r['time'] as String),
          '今天练：${workout['name']}${workout['venue'] == 'gym' ? '（健身房）' : ''}',
          '$body · 约 ${estimateMinutes(plan, list, jsonMap(workout['warmup'])['minutes'] as num?)} 分钟',
        );
        if (jsTruthy(r['nudge'])) {
          final at = _atTime(iso, r['time'] as String, 120);
          if (at.hour < 23 || at.hour == 23 && at.minute <= 30) {
            final lite = exercisesFor(
              plan,
              workout,
              iso,
              true,
            ).map((e) => e['name']).join('、');
            add(1, at, '${workout['name']} 还没练', '来不及的话做 30 分钟精简版：$lite');
          }
        }
      }
    } else if (jsTruthy(r['restDay'])) {
      final nx = nextTraining(plan, iso, dayStates);
      add(
        0,
        _atTime(iso, r['time'] as String),
        '今天休息日',
        '${nx != null ? '下次 ${weekday(nx['iso'] as String)}：${nx['workout']['name']}。' : ''}散步、睡够 7～9 小时，蛋白质照样吃够',
      );
    }
    if (jsTruthy(r['protein']) && !(i == 0 && powderToday)) {
      final p = jsonMap(plan['protein']['powder']);
      add(
        2,
        _atTime(iso, r['proteinTime'] as String),
        '蛋白粉时间',
        '${jsString(p['grams'])} g ${powderLabel(p['name'])} ≈ ${jsString(p['protein'])} g 蛋白质，今天目标 ${jsString(plan['protein']['goal'])} g',
      );
    }
  }
  return out
    ..sort((a, b) => (a['at'] as DateTime).compareTo(b['at'] as DateTime));
}
