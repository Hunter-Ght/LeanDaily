#!/usr/bin/env python3
"""生成宣传片的时间线和页面：out/promo/index.html + timeline.js。先跑 promo_frames_test.dart 出 App 画面，再用 render.cjs 逐帧渲染。"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'out/promo'

def ev(name):
    d = json.load(open(OUT / f'frames/{name}/events.json'))
    return d['frames'], [dict(e, scene=name) for e in d['events']]

nt, et = ev('today'); nr, er = ev('train'); npl, ep = ev('plan'); nm, em = ev('muscle')
taps = [e for e in er if e['type'] == 'tap']
warm, done = taps[1]['frame'], taps[2]['frame']        # “热身完成”“完成第 1 组”
T = {
    'total': 39.0,
    'scenes': {'A': [0, 2.0], 'B': [2.0, 4.0], 'C': [4.0, 8.0], 'P': [8.0, 11.0], 'H1': [11.0, 17.0],
               'H2': [17.0, 25.0], 'H3': [25.0, 33.0], 'D': [33.0, 39.0]},
    'segs': {
        # 训练段跳过点“完成第 1 组”后示范图重新淡入的那几帧灰图
        'H1': [{'scene': 'today', 'f0': 0, 'f1': 80, 'speed': 1.7},
               {'scene': 'train', 'f0': max(0, warm - 3), 'f1': done + 2, 'speed': 1.5},
               {'scene': 'train', 'f0': done + 14, 'f1': nr, 'speed': 1.0}],
        'H2': [{'scene': 'plan', 'f0': 0, 'f1': 150, 'speed': 1.7}, {'scene': 'plan', 'f0': 150, 'f1': npl, 'speed': 1.0}],
        'H3': [{'scene': 'muscle', 'f0': 0, 'f1': nm, 'speed': 1.0}],
    },
    'events': {'H1': et + er, 'H2': ep, 'H3': em},
    'captions': {
        'H1': {'pill': '亮点 ①', 'head': '打开就知道<br>今天练什么', 'sub': '每个动作都有动图，怎么练一看就懂'},
        'H2': {'pill': '亮点 ②', 'head': '专为薄肌用户<br>设计的训练方案', 'sub': '先问几句再推荐 · 居家、健身房都有'},
        'H3': {'pill': '亮点 ③', 'head': '看得见的<br>肌肉恢复', 'sub': '练完的肌肉会染色，越狠颜色越深'},
    },
}
(OUT / 'timeline.js').write_text('const T=' + json.dumps(T, ensure_ascii=False) + ';')
html = (ROOT / 'tool/promo/index.html').read_text().replace('__ROOT__', 'file://' + str(ROOT))
(OUT / 'index.html').write_text(html)
print('timeline ok')
