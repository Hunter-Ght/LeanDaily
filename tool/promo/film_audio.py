#!/usr/bin/env python3
"""电影感版宣传片的声音（原创合成，无版权问题）。按 film_cuts.js 的剪辑表把每个场景的音效对齐到画面。
python3 tool/promo/film_audio.py full|short
输出 out/promo/film_<cut>_music.wav（配乐 + 音效 + 访谈原声）和 film_<cut>_sfx.wav（只有音效和访谈原声，方便在抖音里配热门音乐）。"""
import json, sys, wave
import numpy as np
from scipy import signal
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'out/promo'
CUT = sys.argv[1] if len(sys.argv) > 1 else 'full'
CUTS = json.loads((ROOT / 'tool/promo/film_cuts.js').read_text().split('=', 1)[1].strip().rstrip(';'))
SR = 48000
rng = np.random.default_rng(11)

# 场景在成片里的起点：scene -> (成片起点, 场景内起点, 场景内终点)
PLACE, acc = {}, 0.0
for name, a, b in CUTS[CUT]:
    PLACE[name] = (acc, a, b); acc += b - a
TOTAL = acc; N = int(TOTAL * SR) + 1

def tt(d): return np.arange(int(d * SR)) / SR
def lp(x, f): b, a = signal.butter(2, f / (SR / 2), 'low'); return signal.lfilter(b, a, x)
def hp(x, f): b, a = signal.butter(2, f / (SR / 2), 'high'); return signal.lfilter(b, a, x)
def bp(x, f0, f1): b, a = signal.butter(2, [f0 / (SR / 2), min(f1, SR / 2 - 100) / (SR / 2)], 'band'); return signal.lfilter(b, a, x)
def sweep(d, f0, f1, shape):
    n = rng.standard_normal(int(d * SR)); u = tt(d) / d; out = np.zeros_like(n); K = 24
    for k in range(K):
        s = slice(int(k / K * len(n)), int((k + 1) / K * len(n))); f = f0 * (f1 / f0) ** (k / K)
        out[s] = bp(n, f, f * 1.8)[s]
    return out * shape(u)
def whoosh(d=.7, up=True): return sweep(d, 250, 5000, lambda u: np.sin(np.pi * u) ** 1.5) if up else sweep(d, 5000, 250, lambda u: np.sin(np.pi * u) ** 1.2)
def swish(d=.18): return sweep(d, 1500, 12000, lambda u: np.sin(np.pi * u) ** .8) * 1.3
def riser(d): return sweep(d, 200, 9000, lambda u: u ** 2.2) * .9
def sub(d=1.6, f=42): t = tt(d); return np.sin(2 * np.pi * f * t * (1 + .8 * np.exp(-t * 7))) * np.exp(-t * 2.4)
def impact(d=2.2, f=36):
    t = tt(d)
    return sub(d, f) + hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 35) * .5 + lp(rng.standard_normal(len(t)), 900) * np.exp(-t * 4) * .35
def bell(f, d=1.6):
    t = tt(d); return (np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 6) + .2 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 10)) * np.exp(-t * 3) * .3
def tick():
    t = tt(.06); return hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 110) * .5 + np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 80) * .25
def kick(d=.45):
    t = tt(d); f = 45 + 110 * np.exp(-t * 28); return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) + .25 * hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 180)
def clap():
    d = .22; n = bp(rng.standard_normal(int(d * SR)), 900, 3500); x = np.zeros_like(n)
    for o in (0, .012, .024): i = int(o * SR); x[i:] += n[:len(x) - i] * np.exp(-tt(d)[:len(x) - i] * 60)
    return x * .6 * np.exp(-tt(d) * 12)
def hat(): d = .05; return hp(rng.standard_normal(int(d * SR)), 7000) * np.exp(-tt(d) * 80) * .3
def saw(f, d, de=0.0): t = tt(d); return 2 * ((t * f * (1 + de)) % 1) - 1
def pad(freqs, d, bright=1400):
    x = sum(saw(f, d, de) for f in freqs for de in (-.006, 0, .006)); x = lp(x, bright); t = tt(d)
    return x * np.minimum(1, t / .4) * np.minimum(1, (d - t) / .5) * .05
def stereo(x, pan=0.0): x = np.asarray(x); return np.stack([x * (1 - max(0, pan)), x * (1 + min(0, pan))], 1) if x.ndim == 1 else x
def reverb(x, d=1.8, wet=.35):
    t = tt(d); ir = rng.standard_normal((len(t), 2)) * np.exp(-t * 3.2)[:, None] * .06
    return x + np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1) * wet
mid = lambda m: 440 * 2 ** ((m - 69) / 12)

sfx = np.zeros((N, 2)); voice = np.zeros((N, 2)); music = np.zeros((N, 2))
def at(scene, lt):
    """场景内时间 → 成片时间；场景不在剪辑里或这一刻被剪掉则返回 None。"""
    if scene not in PLACE: return None
    s, a, b = PLACE[scene]
    return s + lt - a if a - .3 <= lt <= b + .3 else None
def put(buf, x, t, g=1.0, pan=0.0):
    if t is None: return
    x = stereo(x, pan); i = int(t * SR)
    if i < 0: x = x[-i:]; i = 0
    L = min(len(x), N - i)
    if L > 0: buf[i:i + L] += x[:L] * g
def S(scene, lt, x, g=1.0, pan=0.0): put(sfx, x, at(scene, lt), g, pan)
def wav(name):
    with wave.open(str(OUT / name)) as w:
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768
        return a.reshape(-1, w.getnchannels())[:, :2] if w.getnchannels() > 1 else np.stack([a, a], 1)

# ---- 访谈原声（剪辑里有哪段就放哪段）
for sc, f, dur in (('A', 'clipA.wav', 2.0), ('C', 'clipC.wav', 3.9), ('P', 'clipP.wav', .9)):
    if sc in PLACE:
        v = wav(f)[:int(dur * SR)]; v *= np.minimum(1, (len(v) - np.arange(len(v)))[:, None] / (.04 * SR))
        v *= .16 / np.sqrt((v ** 2).mean())   # 三段人声统一响度
        put(voice, v, at(sc, 0), 1.0)
# ---- 音效：与 film.html 的动作一一对应
S('A', 1.75, whoosh(.3), .25)
S('B', .08, sub(1.2, 46), .55); S('B', .38, whoosh(.25), .35); S('B', .55, impact(), .9)
S('B', 1.1, sweep(.8, 2000, 10000, lambda u: np.sin(np.pi * u)), .1)
S('C', 2.45, bell(mid(81), 1.8), .35)
S('P', .9, sub(1.0, 50), .5); S('P', 1.02, sub(1.0, 44), .45)
S('P', 1.42, swish(), .7); S('P', 1.5, impact(1.6, 40), .6)
for i, m in enumerate((69, 76, 81)): S('P', 1.72 + i * .03, bell(mid(m), 1.8), .35, -.4 + .4 * i)
S('P', 2.0, sweep(.6, 2000, 10000, lambda u: np.sin(np.pi * u)), .1)
S('P', 2.2, riser(.8), .55); S('P', 2.65, whoosh(.4), .6)
# 亮点一
S('H1', 0, impact(2.0, 38), .7); S('H1', .02, whoosh(1.0), .45)
S('H1', .55, whoosh(.5), .2, -.3); S('H1', 1.375, tick(), .8); S('H1', 1.9375, tick(), .7)
S('H1', 1.9, riser(.75), .35); S('H1', 2.3, whoosh(.6), .4); S('H1', 2.72, sub(1.2, 44), .45)
S('H1', 4.375, tick(), .8); S('H1', 4.45, bell(mid(84), 1.2), .35)
S('H1', 5.95, whoosh(.45), .6, .3)
# 亮点二
S('H2', -.1, whoosh(.45), .5, -.3)
for f in (27, 60, 93, 126): S('H2', .25 + f / 66, tick(), .7)
S('H2', 2.5, riser(.75), .35); S('H2', 2.95, whoosh(.5), .4); S('H2', 3.3, sub(1.2, 44), .45)
S('H2', 4.0, whoosh(.6), .25, .4); S('H2', 5.85, whoosh(.45), .6, .3)
# 亮点三
S('H3', -.1, whoosh(.45), .5, -.3); S('H3', .45, whoosh(.7), .25, -.3)
S('H3', 1.15, riser(.6), .5); S('H3', 1.55, whoosh(.4), .55); S('H3', 1.78, impact(), .9)
S('H3', 2.05, sweep(.75, 1500, 9000, lambda u: np.sin(np.pi * u)), .18)
for i, m in enumerate((69, 72, 76, 79, 81, 84, 88)): S('H3', 2.07 + i * .1, bell(mid(m)), .45, -.5 + i / 6)
for f in (60, 105, 150): S('H3', 2.75 + (f - 40) / 72, tick(), .8)
S('H3', 4.85, whoosh(.9, False), .5); S('H3', 5.6, sub(1.6, 41), .55); S('H3', 5.6, bell(mid(81), 2.0), .4)
# 结尾
S('D', 0, whoosh(.9, False), .4); S('D', .7, impact(2.6, 34), .95)
for i, m in enumerate((57, 64, 69, 72, 76)): S('D', .72 + i * .02, bell(mid(m + 12), 2.4), .3, -.4 + .2 * i)
S('D', 1.0, sweep(.6, 2000, 10000, lambda u: np.sin(np.pi * u)), .1)
for i in range(3):
    S('D', 2.0 + i * .4, kick(), .75); S('D', 2.0 + i * .4, clap(), .5); S('D', 2.0 + i * .4, bell(mid(76 + 3 * i), 1.0), .25)
S('D', 3.2, sweep(.7, 2000, 10000, lambda u: np.sin(np.pi * u)), .1); S('D', 3.5, bell(mid(88), 2.0), .25)

# ---- 配乐：开场只有低频铺底；亮点段进入 120 BPM 的脉冲（Am F C G），结尾回到 Am 长音
def scene_start(sc): return at(sc, PLACE[sc][1]) if sc in PLACE else None
CH = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]
put(music, pad([mid(45), mid(52), mid(57)], TOTAL, 500), 0, 1.2)            # 全片低频铺底
h0 = next((scene_start(s) for s in ('H1', 'H2', 'H3') if s in PLACE), None)
d0 = scene_start('D') if 'D' in PLACE else TOTAL
if h0 is not None:
    t = h0; i = 0
    while t < d0 - .01:
        root, notes = CH[(i // 8) % 4]; beat = i % 8
        put(music, lp(saw(mid(root - 12), .24), 380) * np.exp(-tt(.24) * 6) * .45, t, 1)   # 八分音符低音
        if beat % 2 == 0: put(music, kick(), t, .55)
        if beat % 4 == 2: put(music, clap(), t, .25)
        put(music, hat(), t + .125, .5 if t > h0 + 6 else .25)
        if beat == 0: put(music, pad([mid(n) for n in notes], 2.0, 1800), t, 1.0)
        t += .25; i += 1
put(music, pad([mid(n) for n in (57, 60, 64, 69)], TOTAL - d0, 2200), d0 + .7, 1.6)  # 结尾和弦

def norm(x): return x / max(1e-9, np.abs(x).max())
voice = voice * 1.0
env = np.abs(voice).max(1); env = np.convolve(env, np.ones(2400) / 2400, 'same'); duck = 1 - np.clip(env * 5, 0, .7)
sfx_r = reverb(sfx)
fade = np.minimum(1, (TOTAL - np.arange(N) / SR) / .5)[:, None]
for kind, mix in (('music', voice + sfx_r * .55 * duck[:, None] + reverb(music, wet=.2) * .5 * duck[:, None]),
                  ('sfx', voice + sfx_r * .55 * duck[:, None])):
    y = mix * fade; y = y / max(1e-9, np.abs(y).max()) * .89
    with wave.open(str(OUT / f'film_{CUT}_{kind}.wav'), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((y * 32767).astype('<i2').tobytes())
print('ok', CUT, round(TOTAL, 2))
