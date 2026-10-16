#!/usr/bin/env python3
"""把 out/shots 里的真实界面截图排版成 README 展示图（手机边框 + 说明文字），并用 ffmpeg 合成动图。

先运行 tool/readme_shots/readme_shots_test.dart 和全量测试生成截图，再运行本脚本：
    python3 tool/readme_shots/compose.py
需要：Node + playwright-core 与 Google Chrome（排版截图，见 render.cjs）、ffmpeg（动图）。结果写入 docs/images/。
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / 'out/shots'
OUT = ROOT / 'docs/images'
OUT.mkdir(parents=True, exist_ok=True)

CSS = '''
*{box-sizing:border-box;margin:0}
body{font-family:-apple-system,"PingFang SC","Hiragino Sans GB",sans-serif;-webkit-font-smoothing:antialiased}
.stage{display:flex;align-items:flex-start;justify-content:center;gap:34px}
.item{display:flex;flex-direction:column;align-items:center;gap:18px}
.phone{background:#1c1c1e;border-radius:46px;padding:9px;box-shadow:0 30px 60px rgba(120,50,0,.28),0 4px 10px rgba(0,0,0,.18)}
.phone .scr{border-radius:38px;overflow:hidden;background:#f2f2f7}
.phone img{display:block;width:100%}
.cap{text-align:center}
.cap b{display:block;font-size:26px;font-weight:700;color:#1d1d1f;letter-spacing:-.3px}
.cap span{display:block;margin-top:6px;font-size:18px;color:#6e6e73;line-height:1.4}
.dark .cap b{color:#fff}.dark .cap span{color:#a1a1a6}
'''


def phone(img, width, crop=None, scale=1.0):
    """crop=(宽高比) 时按手机屏幕比例裁掉多余的下半部分。"""
    ratio = crop or (1704 / 786)
    h = int(width * ratio)
    return (f'<div class="phone" style="width:{width + 18}px"><div class="scr" style="height:{h}px">'
            f'<img src="file://{SHOTS / img}" style="width:{width}px"></div></div>')


def item(img, title, sub, width=300, crop=None, offset=0):
    return (f'<div class="item" style="margin-top:{offset}px">{phone(img, width, crop)}'
            f'<div class="cap"><b>{title}</b><span>{sub}</span></div></div>')


def render(name, body, w, h, bg, dark=False, transparent=False):
    pad = '8px 20px' if transparent else '56px 40px'
    html = f'<!doctype html><meta charset="utf-8"><style>{CSS}body{{width:{w}px;height:{h}px;background:{bg};padding:{pad}}}</style><body class="{"dark" if dark else ""}"><div class="stage">{body}</div></body>'
    html_dir = ROOT / 'out/readme-html'
    html_dir.mkdir(parents=True, exist_ok=True)
    path = html_dir / (Path(name).stem + '.html')
    path.write_text(html)
    out = OUT / name
    subprocess.run(['node', str(ROOT / 'tool/readme_shots/render.cjs'), str(path), str(out), str(w), str(h)] + (['transparent'] if transparent else []), check=True)
    print('wrote', out.relative_to(ROOT))


LIGHT_BG = 'linear-gradient(160deg,#fff8f2 0%,#ffe9d9 55%,#ffd8bf 100%)'
DARK_BG = 'linear-gradient(160deg,#1a1a1c 0%,#26211d 55%,#3a2415 100%)'

# 1 主图：今日 / 训练 / 进度
render('hero.png',
       item('r-train-set-light.png', '一组一次点击', '数字沿用上一组，自动休息', 290, offset=70)
       + item('readme-today-light.png', '打开就是今天的计划', '一个大按钮，动作带示范图', 330)
       + item('muscle-fatigue-light.png', '看得见的肌肉恢复', '练完的肌肉会染色，练得越狠颜色越深', 290, crop=1.95, offset=70),
       1500, 940, LIGHT_BG)

# 2 新手选方案
render('feature-plan.png',
       item('r-plan-onb-light.png', '先问几句，再推荐', '每周几天、在哪练、练过没有', 300)
       + item('r-plan-browser-light.png', '一周条一眼看懂节奏', '圆点里的字就是这天练什么', 300)
       + item('r-plan-preview-light.png', '人体图看练哪里', '点进去看每天的动作和示范', 300),
       1500, 880, LIGHT_BG)

# 3 进度
render('feature-progress.png',
       item('r-progress-light.png', '体重趋势，不看单日波动', '7 日均线 + 每周回顾与建议', 300)
       + item('muscle-fatigue-light.png', '肌肉状态', '恢复 / 训练量 / 久未练 三种视角', 300, crop=1.95)
       + item('r-train-summary-light.png', '练完有小结', '组数、训练量、用时和新纪录', 300),
       1500, 880, LIGHT_BG)

# 4 训练模式
render('feature-training.png',
       item('r-train-set-light.png', '示范图自己会动', '一次一个动作，左右滑动切换', 300)
       + item('r-train-feedback-bar-light.png', '感受随时可补', '组后收成一行小条，不打断下一组', 300)
       + item('r-train-summary-light.png', '训练小结', '本次组数 / 训练量 / 用时', 300),
       1500, 880, LIGHT_BG)

# 5 暗色
render('feature-dark.png',
       item('readme-today-dark.png', '今日', '深色模式同样精致', 300)
       + item('r-plan-preview-dark.png', '方案', '一周条与人体图', 300)
       + item('r-progress-dark.png', '进度', '体重趋势与回顾', 300),
       1500, 880, DARK_BG, dark=True)


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
        off = round(i * hold, 2)
        parts.append(f'[{last}][v{i}]xfade=transition=fade:duration={fade}:offset={off}[x{i}]')
        last = f'x{i}'
    parts.append(f'[{last}]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4[g]')
    cmd += ['-filter_complex', ';'.join(parts), '-map', '[g]', '-r', '15', str(out)]
    run(*cmd)
    print('wrote', Path(out).relative_to(ROOT))


gif_from_images([SHOTS / n for n in ['readme-today-light.png', 'r-train-set-light.png', 'r-train-feedback-bar-light.png', 'r-train-summary-light.png']],
                OUT / 'flow.gif', 300)

# 动作示范动图：两帧交替
for key, name in [('floor-press', 'demo-floor-press.gif')]:
    frames = [ROOT / f'assets/exercises/{key}/{i}.jpg' for i in (0, 1)]
    cmd = ['ffmpeg', '-y']
    for f in frames * 4:
        cmd += ['-loop', '1', '-t', '0.9', '-i', str(f)]
    # 简单交替：每帧 0.9 秒，共 8 段
    inputs = ''.join(f'[{i}:v]scale=360:360:force_original_aspect_ratio=increase,crop=360:360,setsar=1[s{i}];' for i in range(8))
    concat = ''.join(f'[s{i}]' for i in range(8)) + 'concat=n=8:v=1:a=0[c];[c]split[a][b];[a]palettegen[p];[b][p]paletteuse[g]'
    cmd += ['-filter_complex', inputs + concat, '-map', '[g]', '-r', '10', str(OUT / name)]
    run(*cmd)
    print('wrote', (OUT / name).relative_to(ROOT))


# 7 字标（透明底；README 顶部用 <picture> 区分亮/暗主题）
FONT_FACE = f'@font-face{{font-family:Wordmark;src:url(file://{ROOT}/assets/fonts/SmileySans-Wordmark.ttf)}}'
CSS = CSS + FONT_FACE
for fname, ink in [('wordmark.png', '#1d1d1f'), ('wordmark-dark.png', '#ffffff')]:
    html = (f'<div style="font-family:Wordmark;font-size:140px;letter-spacing:6px;color:{ink};text-align:center;line-height:1.25">'
            '薄肌<span style="color:#ff6a13">日课</span></div>')
    render(fname, html, 760, 260, 'transparent', transparent=True)
