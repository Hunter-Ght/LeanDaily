#!/usr/bin/env python3
"""App Store 产品页的“标题图”（Header）和“搜索结果图”（Search Results），以及 1206×2622 的截图版本。

Header：3840×1646（21:9）；Search：3840×2560（3:2）。苹果模板的安全区（其余部分在不同设备上会被裁掉）：
  Header  x 1097–2743，y 493–1154
  Search  x  836–3004，y  765–1795
文字和界面都放在安全区里。图里不放价格、网址、Logo、其他平台字样。
用法：NODE_PATH=…/node_modules python3 tool/appstore_shots/compose_assets.py
输出：out/appstore/zh-Hans/header.png、search.png，以及 out/appstore/zh-Hans-1206x2622/1.png …
"""
import subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'out/appstore/raw'
OUT = ROOT / 'out/appstore/zh-Hans'
HTML = ROOT / 'out/appstore/html'
FONT = "-apple-system,'SF Pro Display','PingFang SC','Hiragino Sans GB',sans-serif"


def bar_svg(c, s):
    sig = ''.join(f'<rect x="{i * 4.4}" y="{9 - h}" width="3" height="{h}" rx="1" fill="{c}"/>' for i, h in enumerate([3, 5, 7, 9]))
    return (f'<svg width="{18 * s:.1f}" height="{10 * s:.1f}" viewBox="0 0 18 10">{sig}</svg>'
            f'<svg width="{27 * s:.1f}" height="{12 * s:.1f}" viewBox="0 0 27 12"><rect x=".5" y=".5" width="22" height="11" rx="3.2" fill="none" stroke="{c}" opacity=".45"/>'
            f'<rect x="2" y="2" width="19" height="8" rx="2" fill="{c}"/><rect x="24" y="4" width="2" height="4" rx="1" fill="{c}" opacity=".5"/></svg>')


def phone(img, left, top, screen_w, shadow=True, sb_bg='transparent'):
    """画一台 iPhone（CSS 外框 + 真实截图）。screen_w 是屏幕宽度（px）。"""
    k = screen_w / 1206
    pt = 3 * k
    bez = max(8, round(screen_w * .02))
    sh = 2622 * k
    r = 55 * pt
    return f'''<div style="position:absolute;left:{left}px;top:{top}px;width:{screen_w + 2 * bez}px;height:{sh + 2 * bez:.0f}px;border-radius:{r + bez}px;padding:{bez}px;
 background:linear-gradient(145deg,#4a4a4f,#1c1c1f 40%,#2d2d31);
 box-shadow:{'0 ' + str(round(screen_w * .07)) + 'px ' + str(round(screen_w * .12)) + 'px rgba(0,0,0,.45),' if shadow else ''}inset 0 0 0 {max(2, bez * .15):.1f}px #5b5b60,inset 0 0 0 {max(3, bez * .35):.1f}px #0b0b0c">
 <div style="position:relative;width:{screen_w}px;height:{sh:.0f}px;border-radius:{r}px;overflow:hidden;background:#000">
 <img src="file://{img}" style="display:block;width:100%;height:100%">
 <div style="position:absolute;left:0;right:0;top:0;height:{62 * pt:.0f}px;background:{sb_bg};display:flex;justify-content:space-between;align-items:center;padding:{14 * pt:.0f}px {38 * pt:.0f}px 0 {50 * pt:.0f}px;color:#000;font:600 {17 * pt:.0f}px {FONT}"><span>9:41</span><span style="display:flex;align-items:center;gap:{6 * pt:.0f}px">{bar_svg('#000', pt * .9)}</span></div>
 <div style="position:absolute;left:50%;transform:translateX(-50%);top:{11 * pt:.0f}px;width:{126 * pt:.0f}px;height:{37 * pt:.0f}px;border-radius:999px;background:#000"></div></div></div>'''


def header_html():
    rings = ''
    for cx in (360, 3480):                     # 左右两侧的“环”（App 里的进度环意象），在安全区之外
        for i, (r, a) in enumerate(((620, .20), (470, .28), (320, .38))):
            rings += (f'<div style="position:absolute;left:{cx - r}px;top:{823 - r}px;width:{2 * r}px;height:{2 * r}px;border-radius:50%;'
                      f'border:34px solid rgba(255,255,255,{a})"></div>')
    return f'''<!doctype html><meta charset="utf-8"><body style="margin:0;width:3840px;height:1646px;overflow:hidden;position:relative;
 background:linear-gradient(135deg,#ff8a3d 0%,#ff6a13 52%,#e8560a 100%);font-family:{FONT};-webkit-font-smoothing:antialiased">
 <div style="position:absolute;left:1220px;top:-500px;width:1400px;height:1400px;border-radius:50%;background:radial-gradient(circle,rgba(255,255,255,.34),rgba(255,255,255,0) 65%)"></div>
 {rings}
 <div style="position:absolute;left:1097px;top:493px;width:1646px;height:661px;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center">
  <div style="font-size:282px;line-height:1.1;font-weight:800;letter-spacing:-8px;color:#fff;text-shadow:0 8px 40px rgba(120,40,0,.25)">打开就知道</div>
  <div style="font-size:282px;line-height:1.1;font-weight:800;letter-spacing:-8px;color:#2a160a">今天练什么</div>
 </div></body>'''


def search_html():
    # 安全区 x 836–3004，y 765–1795：左边文字，右边两台手机
    ph = 1000                                   # 手机整体高度（含边框）
    sw = round((ph - 2 * 20) / 2622 * 1206)     # 屏幕宽度
    bez = max(8, round(sw * .02))
    pw = sw + 2 * bez
    top = 780
    p1 = phone(RAW / '1-today.png', 2020, top + 30, sw)
    p2 = phone(RAW / '3-muscle.png', 2020 + pw - 50, top, sw, sb_bg='#f2f2f7')
    return f'''<!doctype html><meta charset="utf-8"><body style="margin:0;width:3840px;height:2560px;overflow:hidden;position:relative;
 background:linear-gradient(160deg,#2a2622 0%,#1b1917 60%,#100f0e 100%);font-family:{FONT};-webkit-font-smoothing:antialiased">
 <div style="position:absolute;left:300px;top:200px;width:2600px;height:2600px;border-radius:50%;background:radial-gradient(circle,rgba(255,106,19,.34),rgba(255,106,19,0) 62%)"></div>
 <div style="position:absolute;left:836px;top:765px;width:1180px;height:1030px;display:flex;flex-direction:column;justify-content:center">
  <div style="font-size:262px;line-height:1.12;font-weight:800;letter-spacing:-6px;color:#fff">看得见的</div>
  <div style="font-size:262px;line-height:1.12;font-weight:800;letter-spacing:-6px;color:#ff6a13">肌肉恢复</div>
  <div style="font-size:84px;line-height:1.3;font-weight:500;color:rgba(255,255,255,.72);margin-top:40px;letter-spacing:1px">今天练什么，一眼就懂</div>
 </div>
 {p1}{p2}</body>'''


def render(html, png, w, h):
    HTML.mkdir(parents=True, exist_ok=True)
    f = HTML / (png.stem + '.html')
    f.write_text(html)
    subprocess.run(['node', str(ROOT / 'tool/appstore_shots/render.cjs'), str(f), str(png), str(w), str(h)], check=True)
    Image.open(png).convert('RGB').save(png)    # 去掉 alpha 通道，苹果不接受透明
    print('wrote', png.relative_to(ROOT), Image.open(png).size, Image.open(png).mode)


def export_1206():
    out = ROOT / 'out/appstore/zh-Hans-1206x2622'
    out.mkdir(exist_ok=True)
    for i in range(1, 7):
        im = Image.open(OUT / f'{i}.png').convert('RGB').resize((1206, 2622), Image.LANCZOS)
        im.save(out / f'{i}.png')
        print('wrote', (out / f'{i}.png').relative_to(ROOT), im.size, im.mode)


if __name__ == '__main__':
    render(header_html(), OUT / 'header.png', 3840, 1646)
    render(search_html(), OUT / 'search.png', 3840, 2560)
    export_1206()
