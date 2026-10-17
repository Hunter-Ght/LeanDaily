#!/usr/bin/env python3
"""把 out/appstore/raw 里的真实界面截图排成 App Store 商店图（1320×2868，6.9" iPhone）。

手机外框是用 CSS 画的 iPhone 18 Pro 风格（灵动岛、细边框、圆角），界面是 402×874 pt 的真实截图。
用法（先出 raw 截图，见 appstore_shots_test.dart）：
    NODE_PATH=/path/to/node_modules python3 tool/appstore_shots/compose.py [zh-Hans|en-US]
输出：out/appstore/<语言>/1.png … 5.png
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'out/appstore/raw'
W, H = 1320, 2868
SCREEN_W = 1040                       # 手机屏幕在画布上的宽度（px）
K = SCREEN_W / 1206                   # 原图 1206 px → 画布
SCREEN_H = 2622 * K
BEZEL = 20
TOP = 700                             # 手机顶部位置，文字在上方；底部会出血被裁掉

# 每张：原图、背景、文字色、副标题色、状态栏色
THEMES = {
    'cream': dict(bg='linear-gradient(170deg,#fff7ef 0%,#ffe6d2 60%,#ffd2b0 100%)', h='#1d1d1f', s='#6e5a4c', bar='#000'),
    'orange': dict(bg='linear-gradient(170deg,#ff7a26 0%,#ff6a13 55%,#e8560a 100%)', h='#ffffff', s='rgba(255,255,255,.86)', bar='#000'),
    'dark': dict(bg='linear-gradient(170deg,#2a2622 0%,#1b1917 60%,#101010 100%)', h='#ffffff', s='rgba(255,255,255,.7)', bar='#000'),
}
SCENES = [
    ('1-today', 'cream', False),
    ('2-plan', 'orange', False),
    ('3-muscle', 'cream', False),
    ('4-train', 'dark', False),
    ('5-progress', 'cream', False),
    ('6-meals', 'orange', True),     # 半屏弹层：顶部是压暗的背景，状态栏用白字
]
TEXT = {
    'zh-Hans': [
        ('看清今天的<br>训练与饮食', '一个大按钮，打开就知道今天练什么'),
        ('先问几句，<br>再推荐', '每周几天、在哪练、练过没有，给你一张推荐卡'),
        ('看得见的<br>肌肉恢复', '练完的肌肉会染色，越狠颜色越深'),
        ('记录每一组<br>与余力', '示范图自己会动，一次只看一个动作'),
        ('回看每周<br>进度', '体重趋势和每周总览，一眼看清'),
        ('常见的饭，<br>一点就记', '一顿多少热量、蛋白直接写好，也能拍照让 AI 算'),
    ],
}


def bar_svg(color, k):
    s = k
    signal = ''.join(f'<rect x="{i * 4.4}" y="{9 - h}" width="3" height="{h}" rx="1" fill="{color}"/>' for i, h in enumerate([3, 5, 7, 9]))
    return (f'<svg width="{18 * s:.1f}" height="{10 * s:.1f}" viewBox="0 0 18 10">{signal}</svg>'
            f'<svg width="{16 * s:.1f}" height="{11 * s:.1f}" viewBox="0 0 16 11"><path d="M8 10.2 5.9 8a3 3 0 0 1 4.2 0L8 10.2Z" fill="{color}"/>'
            f'<path d="M3.4 5.6a6.4 6.4 0 0 1 9.2 0l-1.3 1.3a4.6 4.6 0 0 0-6.6 0L3.4 5.6Z" fill="{color}"/>'
            f'<path d="M.8 3a10 10 0 0 1 14.4 0l-1.3 1.3a8.2 8.2 0 0 0-11.8 0L.8 3Z" fill="{color}"/></svg>'
            f'<svg width="{27 * s:.1f}" height="{12 * s:.1f}" viewBox="0 0 27 12"><rect x=".5" y=".5" width="22" height="11" rx="3.2" fill="none" stroke="{color}" opacity=".45"/>'
            f'<rect x="2" y="2" width="19" height="8" rx="2" fill="{color}"/><rect x="24" y="4" width="2" height="4" rx="1" fill="{color}" opacity=".5"/></svg>')


def page(img, theme, white_bar, title, sub):
    t = THEMES[theme]
    pt = 3 * K                         # 1 pt 对应多少画布像素
    bar = '#fff' if white_bar else t['bar']
    sb_h = 62 * pt
    phone_w = SCREEN_W + 2 * BEZEL
    radius = 55 * pt                   # 屏幕圆角
    return f'''<!doctype html><meta charset="utf-8"><style>
*{{box-sizing:border-box;margin:0}}
body{{width:{W}px;height:{H}px;overflow:hidden;position:relative;background:{t['bg']};
  font-family:-apple-system,"SF Pro Display","PingFang SC","Hiragino Sans GB",sans-serif;-webkit-font-smoothing:antialiased}}
.glow{{position:absolute;left:-200px;top:-260px;width:1100px;height:1100px;border-radius:50%;
  background:radial-gradient(circle,rgba(255,255,255,{.35 if theme != 'dark' else .06}),rgba(255,255,255,0) 65%)}}
h1{{position:absolute;left:96px;right:96px;top:150px;font-size:136px;line-height:1.14;font-weight:800;
  letter-spacing:-2px;color:{t['h']}}}
p{{position:absolute;left:100px;right:96px;top:{150 + 136 * 2.28 + 34:.0f}px;font-size:50px;line-height:1.35;font-weight:500;color:{t['s']}}}
.phone{{position:absolute;left:{(W - phone_w) / 2}px;top:{TOP}px;width:{phone_w}px;height:{SCREEN_H + 2 * BEZEL:.0f}px;
  background:linear-gradient(145deg,#4a4a4f,#1c1c1f 40%,#2d2d31);border-radius:{radius + BEZEL}px;padding:{BEZEL}px;
  box-shadow:0 70px 120px rgba(0,0,0,.38),0 14px 30px rgba(0,0,0,.28),inset 0 0 0 3px #5b5b60,inset 0 0 0 7px #0b0b0c}}
.scr{{position:relative;width:{SCREEN_W}px;height:{SCREEN_H:.0f}px;border-radius:{radius}px;overflow:hidden;background:#000}}
.scr img{{display:block;width:100%;height:100%}}
.sb{{position:absolute;left:0;right:0;top:0;height:{sb_h:.0f}px;background:{'#f2f2f7' if img.name == '3-muscle.png' else 'transparent'};display:flex;justify-content:space-between;align-items:center;
  padding:{14 * pt:.0f}px {38 * pt:.0f}px 0 {50 * pt:.0f}px;color:{bar};font:600 {17 * pt:.0f}px -apple-system,"SF Pro Text","PingFang SC",sans-serif}}
.sb .r{{display:flex;align-items:center;gap:{6 * pt:.0f}px}}
.di{{position:absolute;left:50%;transform:translateX(-50%);top:{11 * pt:.0f}px;width:{126 * pt:.0f}px;height:{37 * pt:.0f}px;border-radius:999px;background:#000}}
.btn{{position:absolute;width:8px;background:linear-gradient(90deg,#2a2a2e,#505055);border-radius:4px}}
</style><body><div class="glow"></div>
<h1>{title}</h1><p>{sub}</p>
<div class="btn" style="left:{(W - phone_w) / 2 - 7}px;top:{TOP + 330}px;height:90px"></div>
<div class="btn" style="left:{(W - phone_w) / 2 - 7}px;top:{TOP + 490}px;height:170px"></div>
<div class="btn" style="left:{(W - phone_w) / 2 - 7}px;top:{TOP + 690}px;height:170px"></div>
<div class="btn" style="left:{(W + phone_w) / 2 - 1}px;top:{TOP + 560}px;height:240px"></div>
<div class="phone"><div class="scr"><img src="file://{img}">
<div class="sb"><span>9:41</span><span class="r">{bar_svg(bar, pt * 0.9)}</span></div><div class="di"></div></div></div></body>'''


def main():
    lang = sys.argv[1] if len(sys.argv) > 1 else 'zh-Hans'
    out = ROOT / f'out/appstore/{lang}'
    html_dir = ROOT / 'out/appstore/html'
    out.mkdir(parents=True, exist_ok=True)
    html_dir.mkdir(parents=True, exist_ok=True)
    raw = RAW if lang == 'zh-Hans' else ROOT / f'out/appstore/raw-{lang}'
    for i, ((name, theme, white), (title, sub)) in enumerate(zip(SCENES, TEXT[lang]), 1):
        h = html_dir / f'{lang}-{i}.html'
        h.write_text(page(raw / f'{name}.png', theme, white, title, sub))
        png = out / f'{i}.png'
        subprocess.run(['node', str(ROOT / 'tool/appstore_shots/render.cjs'), str(h), str(png), str(W), str(H)], check=True)
        print('wrote', png.relative_to(ROOT))


if __name__ == '__main__':
    main()
