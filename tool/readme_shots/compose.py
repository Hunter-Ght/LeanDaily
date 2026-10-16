#!/usr/bin/env python3
"""把 out/shots 里的真实界面截图排版成 README 展示图，并用 ffmpeg 合成动图。

截图要带上真机的安全区（顶部状态栏、底部手势条），否则界面内容会贴着屏幕边缘、被圆角裁掉：
    LEANDAILY_SAFE_AREA=1 LEANDAILY_TEST_FONT=out/fonts/PingFangSC-Regular.ttf TZ=Asia/Shanghai flutter test
    for s in light dark; do README_SCHEME=$s LEANDAILY_SAFE_AREA=1 LEANDAILY_TEST_FONT=... TZ=Asia/Shanghai \\
        flutter test tool/readme_shots/readme_shots_test.dart; done
    python3 tool/readme_shots/compose.py
（中文字体见 extract_pingfang_sc.py。）需要：Node + playwright-core 与 Google Chrome（render.cjs）、ffmpeg。
结果写入 docs/images/。
"""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / 'out/shots'
OUT = ROOT / 'docs/images'
HTML = ROOT / 'out/readme-html'
OUT.mkdir(parents=True, exist_ok=True)
HTML.mkdir(parents=True, exist_ok=True)

CSS = '''
*{box-sizing:border-box;margin:0}
body{font-family:-apple-system,"PingFang SC","Hiragino Sans GB",sans-serif;-webkit-font-smoothing:antialiased}
.stage{display:flex;align-items:flex-start;justify-content:center;gap:40px}
.item{display:flex;flex-direction:column;align-items:center;gap:20px}
.phone{background:#0e0e10;border-radius:calc(var(--k)*56px);padding:calc(var(--k)*7px);
  box-shadow:0 28px 56px rgba(120,50,0,.26),0 4px 10px rgba(0,0,0,.16),inset 0 0 0 1.5px #3a3a3e}
.scr{position:relative;overflow:hidden;border-radius:calc(var(--k)*50px);background:#000}
.scr img{display:block;width:100%;height:100%}
.sb{position:absolute;left:0;right:0;top:0;display:flex;justify-content:space-between;align-items:center;
  font:600 calc(var(--k)*16px) -apple-system,"SF Pro Text","PingFang SC",sans-serif;letter-spacing:.2px}
.sb .r{display:flex;align-items:center;gap:calc(var(--k)*6px)}
.home{position:absolute;left:50%;transform:translateX(-50%);height:calc(var(--k)*5px);width:calc(var(--k)*134px);border-radius:9px}
.cap{text-align:center}
.cap b{display:block;font-size:26px;font-weight:700;color:#1d1d1f;letter-spacing:-.3px}
.cap span{display:block;margin-top:6px;font-size:18px;color:#6e6e73;line-height:1.4}
.dark .cap b{color:#fff}.dark .cap span{color:#a1a1a6}
'''


def bar_svg(color):
    signal = ''.join(f'<rect x="{i * 4.4}" y="{9 - h}" width="3" height="{h}" rx="1" fill="{color}"/>' for i, h in enumerate([3, 5, 7, 9]))
    return (f'<svg width="18" height="10" viewBox="0 0 18 10">{signal}</svg>'
            f'<svg width="16" height="11" viewBox="0 0 16 11"><path d="M8 10.2 5.9 8a3 3 0 0 1 4.2 0L8 10.2Z" fill="{color}"/>'
            f'<path d="M3.4 5.6a6.4 6.4 0 0 1 9.2 0l-1.3 1.3a4.6 4.6 0 0 0-6.6 0L3.4 5.6Z" fill="{color}"/>'
            f'<path d="M.8 3a10 10 0 0 1 14.4 0l-1.3 1.3a8.2 8.2 0 0 0-11.8 0L.8 3Z" fill="{color}"/></svg>'
            f'<svg width="27" height="12" viewBox="0 0 27 12"><rect x=".5" y=".5" width="22" height="11" rx="3.2" fill="none" stroke="{color}" opacity=".45"/>'
            f'<rect x="2" y="2" width="19" height="8" rx="2" fill="{color}"/><rect x="24" y="4" width="2" height="4" rx="1" fill="{color}" opacity=".5"/></svg>')


def phone(img, width, bar, mask=None):
    """bar: 'dark' 深色字（亮色界面）/ 'light' 白字（暗色界面或带压暗背景的半屏弹层）"""
    k = width / 393
    h = width * 852 / 393
    color = '#000' if bar == 'dark' else '#fff'
    return (f'<div class="phone" style="--k:{k:.4f};width:{width + 14 * k:.1f}px"><div class="scr" style="width:{width}px;height:{h:.1f}px">'
            f'<img src="file://{SHOTS / img}">'
            f'<div class="sb" style="{f"background:{mask};" if mask else ""}height:{47 * k:.1f}px;padding:{6 * k:.1f}px {26 * k:.1f}px 0 {38 * k:.1f}px;color:{color}"><span>9:41</span>'
            f'<span class="r">{bar_svg(color)}</span></div>'
            f'<div class="home" style="bottom:{8 * k:.1f}px;background:{color};opacity:.85"></div></div></div>')


def item(img, title, sub, width=300, bar='dark', mask=None):
    return (f'<div class="item">{phone(img, width, bar, mask)}'
            f'<div class="cap"><b>{title}</b><span>{sub}</span></div></div>')



def fold(img, width, caption, sub):
    """折叠屏内屏：825×887dp，细边框、小圆角。"""
    s = width / 825
    h = width * 887 / 825
    sb = (f'<div class="sb" style="height:{56 * s:.1f}px;padding:{12 * s:.1f}px {40 * s:.1f}px 0 {44 * s:.1f}px;'
          f'font-size:{17 * s:.1f}px;color:#000"><span>9:41</span><span class="r">{bar_svg("#000")}</span></div>')
    frame = (f'<div class="phone" style="--k:{s:.4f};border-radius:{30 * s:.1f}px;padding:{8 * s:.1f}px;width:{width + 16 * s:.1f}px">'
             f'<div class="scr" style="width:{width}px;height:{h:.1f}px;border-radius:{22 * s:.1f}px">'
             f'<img src="file://{SHOTS / img}">{sb}</div></div>')
    return f'<div class="item">{frame}<div class="cap"><b>{caption}</b><span>{sub}</span></div></div>'


def render(name, body, w, h, bg, dark=False, transparent=False):
    pad = '8px 20px' if transparent else '56px 40px'
    html = (f'<!doctype html><meta charset="utf-8"><style>{CSS}body{{width:{w}px;height:{h}px;background:{bg};padding:{pad}}}</style>'
            f'<body class="{"dark" if dark else ""}"><div class="stage">{body}</div></body>')
    path = HTML / (Path(name).stem + '.html')
    path.write_text(html)
    out = OUT / name
    subprocess.run(['node', str(ROOT / 'tool/readme_shots/render.cjs'), str(path), str(out), str(w), str(h)]
                   + (['transparent'] if transparent else []), check=True)
    print('wrote', out.relative_to(ROOT))


LIGHT_BG = 'linear-gradient(160deg,#fff8f2 0%,#ffe9d9 55%,#ffd8bf 100%)'
DARK_BG = 'linear-gradient(160deg,#1a1a1c 0%,#26211d 55%,#3a2415 100%)'

# 1 主图：推荐方案 → 今日计划 → 肌肉恢复（三张等大，说明文字对齐）
render('hero.png',
       item('r-plan-onb-light.png', '先问几句，再推荐', '每周几天、在哪练、练过没有，给你一张推荐卡', 310)
       + item('readme-today-light.png', '打开就是今天的计划', '一个大按钮，动作带会动的示范图', 310)
       + item('readme-muscle-light.png', '看得见的肌肉恢复', '练完的肌肉会染色，越狠颜色越深', 310, mask='#f2f2f7'),
       1500, 940, LIGHT_BG)

# 2 新手选方案（半屏弹层顶部是压暗的背景页，状态栏用白字）
render('feature-plan.png',
       item('r-plan-onb-light.png', '先问几句，再推荐', '每周几天、在哪练、练过没有', 300)
       + item('r-plan-browser-light.png', '一周条一眼看懂节奏', '圆点里的字就是这天练什么', 300, bar='light')
       + item('r-plan-preview-light.png', '人体图看练哪里', '点进去看每天的动作和示范', 300, bar='light'),
       1500, 920, LIGHT_BG)

# 3 进度
render('feature-progress.png',
       item('r-progress-light.png', '体重趋势，不看单日波动', '7 日均线 + 每周回顾与建议', 300, mask='#f2f2f7')
       + item('readme-muscle-light.png', '肌肉状态', '恢复 / 训练量 / 久未练 三种视角', 300, mask='#f2f2f7')
       + item('r-train-summary-light.png', '练完有小结', '组数、训练量、用时和新纪录', 300),
       1500, 920, LIGHT_BG)

# 4 训练模式
render('feature-training.png',
       item('r-train-set-light.png', '示范图自己会动', '一次一个动作，左右滑动切换', 300)
       + item('r-train-feedback-bar-light.png', '感受随时可补', '组后收成一行小条，不打断下一组', 300)
       + item('r-train-summary-light.png', '训练小结', '本次组数 / 训练量 / 用时', 300),
       1500, 920, LIGHT_BG)

# 4.5 折叠屏内屏（侧边导航 + 双栏）
render('feature-fold.png',
       fold('readme-fold-today-light.png', 640, '展开就是双栏', '左边今天练什么，右边这个动作怎么做')
       + fold('readme-fold-log-light.png', 640, '记录页：日历 + 当天', '侧边导航，一屏看完一整天'),
       1500, 940, LIGHT_BG)

# 5 暗色
render('feature-dark.png',
       item('readme-today-dark.png', '今日', '深色模式同样精致', 300, bar='light')
       + item('r-plan-preview-dark.png', '方案', '一周条与人体图', 300, bar='light')
       + item('readme-muscle-dark.png', '肌肉状态', '恢复程度一目了然', 300, bar='light', mask='#000'),
       1500, 920, DARK_BG, dark=True)


# 6 动图
def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def gif_from_images(images, out, width, hold=1.8, fade=0.4):
    n = len(images)
    cmd = ['ffmpeg', '-y']
    for img in images:
        cmd += ['-loop', '1', '-t', str(hold + fade), '-i', str(img)]
    parts = [f'[{i}:v]scale={width}:-2:flags=lanczos,format=yuv420p,setsar=1[v{i}]' for i in range(n)]
    last = 'v0'
    for i in range(1, n):
        parts.append(f'[{last}][v{i}]xfade=transition=fade:duration={fade}:offset={round(i * hold, 2)}[x{i}]')
        last = f'x{i}'
    parts.append(f'[{last}]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4[g]')
    run(*cmd, '-filter_complex', ';'.join(parts), '-map', '[g]', '-r', '15', str(out))
    print('wrote', Path(out).relative_to(ROOT))


# 流程动图：每一帧都是带状态栏的完整手机画面（不含说明文字）
flow = []
for i, img in enumerate(['readme-today-light.png', 'r-train-set-light.png', 'r-train-feedback-bar-light.png', 'r-train-summary-light.png']):
    render(f'_flow{i}.png', phone(img, 320, 'dark'), 360, 720, '#ffffff')
    flow.append(OUT / f'_flow{i}.png')
gif_from_images(flow, OUT / 'flow.gif', 300)
for f in flow:
    f.unlink()

# 动作示范动图：两帧交替
frames = [ROOT / f'assets/exercises/floor-press/{i}.jpg' for i in (0, 1)]
cmd = ['ffmpeg', '-y']
for f in frames * 4:
    cmd += ['-loop', '1', '-t', '0.9', '-i', str(f)]
inputs = ''.join(f'[{i}:v]scale=360:360:force_original_aspect_ratio=increase,crop=360:360,setsar=1[s{i}];' for i in range(8))
concat = ''.join(f'[s{i}]' for i in range(8)) + 'concat=n=8:v=1:a=0[c];[c]split[a][b];[a]palettegen[p];[b][p]paletteuse[g]'
run(*cmd, '-filter_complex', inputs + concat, '-map', '[g]', '-r', '10', str(OUT / 'demo-floor-press.gif'))
print('wrote docs/images/demo-floor-press.gif')

# 字标（透明底；README 顶部用 <picture> 区分亮/暗主题）
CSS += f'@font-face{{font-family:Wordmark;src:url(file://{ROOT}/assets/fonts/SmileySans-Wordmark.ttf)}}'
for fname, ink in [('wordmark.png', '#1d1d1f'), ('wordmark-dark.png', '#ffffff')]:
    html = (f'<div style="font-family:Wordmark;font-size:140px;letter-spacing:6px;color:{ink};text-align:center;line-height:1.25">'
            '薄肌<span style="color:#ff6a13">日课</span></div>')
    render(fname, html, 760, 260, 'transparent', transparent=True)
