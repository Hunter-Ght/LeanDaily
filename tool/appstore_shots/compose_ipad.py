#!/usr/bin/env python3
"""iPad 13 英寸 App Store 商店图（2064×2752，竖屏）。

界面是真实的 iPad 布局截图（1032×1376 pt @2x），先出 raw：
    LEANDAILY_SHOT_SIZE=1032x1376 LEANDAILY_SAFE_AREA=1 LEANDAILY_SAFE_TOP=24 LEANDAILY_SAFE_BOTTOM=20 \
    LEANDAILY_SHOT_SCALE=2 LEANDAILY_SHOT_DIR=out/appstore/raw-ipad LEANDAILY_TEST_FONT=out/fonts/PingFangSC-Regular.ttf \
    TZ=Asia/Shanghai flutter test tool/appstore_shots/appstore_shots_test.dart
再： NODE_PATH=…/node_modules python3 tool/appstore_shots/compose_ipad.py
输出 out/appstore/zh-Hans-ipad/1.png … 5.png（RGB，无透明通道）。
"""
import subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'out/appstore/raw-ipad'
OUT = ROOT / 'out/appstore/zh-Hans-ipad'
HTML = ROOT / 'out/appstore/html'
W, H = 2064, 2752
FONT = "-apple-system,'SF Pro Display','PingFang SC','Hiragino Sans GB',sans-serif"
SCREEN_W = 1760
K = SCREEN_W / 2064                    # raw 2064 px → 画布
SCREEN_H = 2752 * K
BEZEL = 40
TOP = 700
PT = 2 * K                             # 1 pt（raw 是 @2x）对应的画布像素

THEMES = {
    'cream': dict(bg='linear-gradient(170deg,#fff7ef 0%,#ffe6d2 60%,#ffd2b0 100%)', h='#1d1d1f', s='#6e5a4c'),
    'orange': dict(bg='linear-gradient(170deg,#ff7a26 0%,#ff6a13 55%,#e8560a 100%)', h='#ffffff', s='rgba(255,255,255,.86)'),
    'dark': dict(bg='linear-gradient(170deg,#2a2622 0%,#1b1917 60%,#101010 100%)', h='#ffffff', s='rgba(255,255,255,.7)'),
}
# 文件、背景、状态栏文字色、状态栏底色（内容会滚到状态栏下面的页面要垫一层）
SCENES = [
    ('1-today', 'cream', '#000', 'transparent', '今天练什么，<br>怎么练', '左边是今日训练，右边是动作要点'),
    ('2-plan', 'orange', '#000', 'transparent', '先问几句，<br>再推荐', '每周几天、在哪练、练过没有，给你一张推荐卡'),
    ('3-muscle', 'dark', '#000', '#f2f2f7', '看得见的<br>肌肉恢复', '练完的肌肉会染色，越狠颜色越深'),
    ('6-meals', 'cream', '#fff', 'transparent', '常见的饭，<br>一点就记', '一顿多少热量、蛋白直接写好，也能拍照让 AI 算'),
    ('5-progress', 'orange', '#000', 'transparent', '回看每周<br>进度', '体重趋势和每周总览，一眼看清'),
]


def bar_svg(c, s):
    sig = ''.join(f'<rect x="{i * 4.4}" y="{9 - h}" width="3" height="{h}" rx="1" fill="{c}"/>' for i, h in enumerate([3, 5, 7, 9]))
    return (f'<svg width="{18 * s:.1f}" height="{10 * s:.1f}" viewBox="0 0 18 10">{sig}</svg>'
            f'<svg width="{27 * s:.1f}" height="{12 * s:.1f}" viewBox="0 0 27 12"><rect x=".5" y=".5" width="22" height="11" rx="3.2" fill="none" stroke="{c}" opacity=".45"/>'
            f'<rect x="2" y="2" width="19" height="8" rx="2" fill="{c}"/><rect x="24" y="4" width="2" height="4" rx="1" fill="{c}" opacity=".5"/></svg>')


def page(i, name, theme, bar, sb_bg, title, sub):
    t = THEMES[theme]
    left = (W - SCREEN_W - 2 * BEZEL) / 2
    radius = 46
    sb_h = 24 * PT
    return f'''<!doctype html><meta charset="utf-8"><style>
*{{box-sizing:border-box;margin:0}}
body{{width:{W}px;height:{H}px;overflow:hidden;position:relative;background:{t['bg']};font-family:{FONT};-webkit-font-smoothing:antialiased}}
.glow{{position:absolute;left:-300px;top:-420px;width:1700px;height:1700px;border-radius:50%;
  background:radial-gradient(circle,rgba(255,255,255,{.35 if theme != 'dark' else .06}),rgba(255,255,255,0) 65%)}}
h1{{position:absolute;left:150px;right:150px;top:140px;font-size:172px;line-height:1.14;font-weight:800;letter-spacing:-3px;color:{t['h']}}}
p{{position:absolute;left:156px;right:150px;top:{140 + 172 * 2.28 + 22:.0f}px;font-size:58px;line-height:1.35;font-weight:500;color:{t['s']}}}
.pad{{position:absolute;left:{left}px;top:{TOP}px;width:{SCREEN_W + 2 * BEZEL}px;height:{SCREEN_H + 2 * BEZEL:.0f}px;padding:{BEZEL}px;border-radius:{radius + BEZEL}px;
  background:linear-gradient(145deg,#3d3d42,#18181a 40%,#26262a);
  box-shadow:0 90px 160px rgba(0,0,0,.38),0 18px 40px rgba(0,0,0,.28),inset 0 0 0 4px #55555a,inset 0 0 0 9px #0b0b0c}}
.scr{{position:relative;width:{SCREEN_W}px;height:{SCREEN_H:.0f}px;border-radius:{radius}px;overflow:hidden;background:#000}}
.scr img{{display:block;width:100%;height:100%}}
.sb{{position:absolute;left:0;right:0;top:0;height:{sb_h:.0f}px;background:{sb_bg};display:flex;justify-content:space-between;align-items:center;
  padding:0 {30 * PT:.0f}px;color:{bar};font:600 {12 * PT:.0f}px {FONT}}}
.sb .r{{display:flex;align-items:center;gap:{6 * PT:.0f}px}}
.cam{{position:absolute;left:50%;top:{BEZEL / 2 - 7}px;width:14px;height:14px;margin-left:-7px;border-radius:50%;background:#050506;box-shadow:inset 0 0 0 3px #1c1c20}}
</style><body><div class="glow"></div><h1>{title}</h1><p>{sub}</p>
<div class="pad"><div class="cam"></div><div class="scr"><img src="file://{RAW / (name + '.png')}">
<div class="sb"><span>9:41 &nbsp; 10月16日 周五</span><span class="r">{bar_svg(bar, PT * .8)}</span></div></div></div></body>'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    HTML.mkdir(parents=True, exist_ok=True)
    for i, (name, theme, bar, sb_bg, title, sub) in enumerate(SCENES, 1):
        h = HTML / f'ipad-{i}.html'
        h.write_text(page(i, name, theme, bar, sb_bg, title, sub))
        png = OUT / f'{i}.png'
        subprocess.run(['node', str(ROOT / 'tool/appstore_shots/render.cjs'), str(h), str(png), str(W), str(H)], check=True)
        Image.open(png).convert('RGB').save(png)            # 去掉 alpha，苹果不接受透明
        print('wrote', png.relative_to(ROOT), Image.open(png).size, Image.open(png).mode)


if __name__ == '__main__':
    main()
