#!/usr/bin/env python3
"""合成宣传片的配乐和音效（原创，无版权问题）：120 BPM，A 小调；访谈原声在前几秒保留。
输出 out/promo/audio_music.wav（带配乐）和 audio_clean.wav（只有访谈原声和音效，方便在抖音里换平台热门音乐）。"""
import json, wave
import numpy as np
from scipy import signal
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'out/promo'
SR = 48000
T = json.loads((OUT / 'timeline.js').read_text().split('=', 1)[1].rstrip(';'))
TOTAL = T['total']; S = T['scenes']
N = int(TOTAL * SR)
rng = np.random.default_rng(7)
BEAT = .5

def zeros(): return np.zeros((N, 2))
def put(buf, x, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N: return
    x = np.asarray(x); L = min(len(x), N - i)
    l = gain * (1 - max(0, pan)); r = gain * (1 + min(0, pan))
    buf[i:i + L, 0] += x[:L] * l; buf[i:i + L, 1] += x[:L] * r
def tt(d): return np.arange(int(d * SR)) / SR
def env_exp(d, k): t = tt(d); return np.exp(-t * k)
def lp(x, f, order=2): b, a = signal.butter(order, f / (SR / 2), 'low'); return signal.lfilter(b, a, x)
def hp(x, f, order=2): b, a = signal.butter(order, f / (SR / 2), 'high'); return signal.lfilter(b, a, x)
def bp(x, f0, f1): b, a = signal.butter(2, [f0 / (SR / 2), f1 / (SR / 2)], 'band'); return signal.lfilter(b, a, x)
def saw(f, d, det=0.0):
    t = tt(d); return 2 * ((t * f * (1 + det)) % 1) - 1
def kick(d=.45):
    t = tt(d); f = 45 + 110 * np.exp(-t * 28); ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * np.exp(-t * 9) + .25 * hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 180)) * 1.0
def clap():
    d = .22; x = np.zeros(int(d * SR)); n = bp(rng.standard_normal(len(x)), 900, 3500)
    for o in (0, .012, .024): i = int(o * SR); x[i:] += n[:len(x) - i] * np.exp(-tt(d)[:len(x) - i] * 60)
    return x * .6 * np.exp(-tt(d) * 12)
def hat(d=.06, op=False):
    d = .22 if op else d; return hp(rng.standard_normal(int(d * SR)), 7000) * np.exp(-tt(d) * (22 if op else 70)) * .35
def boom(d=1.6):
    t = tt(d); return (np.sin(2 * np.pi * 38 * t * (1 + .6 * np.exp(-t * 6))) * np.exp(-t * 2.4) + .5 * lp(rng.standard_normal(len(t)), 600) * np.exp(-t * 5))
def whoosh(d=.7, up=True):
    n = rng.standard_normal(int(d * SR)); t = tt(d); out = np.zeros_like(n)
    for k in range(8):
        a, b = k / 8, (k + 1) / 8; seg = slice(int(a * len(t)), int(b * len(t)))
        f = 300 * (2 ** (5 * (a if up else 1 - a)))
        out[seg] = bp(n, f, min(f * 1.9, 20000))[seg]
    e = np.sin(np.pi * np.clip(t / d, 0, 1)) ** (1.6 if up else 1.2)
    return out * e * 1.6
def riser(d):
    n = rng.standard_normal(int(d * SR)); t = tt(d); out = np.zeros_like(n)
    for k in range(16):
        a, b = k / 16, (k + 1) / 16; seg = slice(int(a * len(t)), int(b * len(t)))
        f = 250 * (2 ** (5.5 * a)); out[seg] = bp(n, f, min(f * 2.2, 20000))[seg]
    return out * (t / d) ** 2 * .7
def pluck(f, d=.22, bright=3500):
    x = saw(f, d) * .6 + saw(f, d, .004) * .4; x = lp(x, bright); return x * env_exp(d, 14) * .5
def bassnote(f, d=.24):
    x = np.sin(2 * np.pi * f * tt(d)) * .8 + lp(saw(f, d), 500) * .5; return x * np.minimum(1, tt(d) * 400) * env_exp(d, 7)
def pad(freqs, d):
    x = sum(saw(f, d, de) for f in freqs for de in (-.006, 0, .006)); x = lp(x, 1400); t = tt(d)
    e = np.minimum(1, t / .5) * np.minimum(1, (d - t) / .6); return x * e * .05
def chime(f, d=1.4): t = tt(d); return (np.sin(2 * np.pi * f * t) + .4 * np.sin(2 * np.pi * 2 * f * t) + .15 * np.sin(2 * np.pi * 3 * f * t)) * np.exp(-t * 3.2) * .35
def tick(): return hp(rng.standard_normal(int(.05 * SR)), 2500) * env_exp(.05, 90) * .6 + np.sin(2 * np.pi * 1800 * tt(.05)) * env_exp(.05, 70) * .25
def reverb(x, d=1.1, wet=.3):
    t = tt(d); ir = rng.standard_normal((len(t), 2)) * np.exp(-t * 4.5)[:, None] * .08
    w = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1); return x * (1 - wet * .4) + w * wet

# ---- 乐理：Am F C G，每和弦一小节（2s）
mid = lambda m: 440 * 2 ** ((m - 69) / 12)
CH = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]   # 根音, 和弦音
def bar_chord(t): return CH[int((t - S['H1'][0]) // 2) % 4]

music = zeros(); sfx = zeros(); verb = zeros()
# ---- 开场 / B：冲击
B0 = S['B'][0]
put(sfx, whoosh(.35, True), B0 - .25, .7); put(sfx, boom(), B0 + .08, 1.0)          # “赚钱之外”砸下
for i, f in enumerate((mid(84), mid(88), mid(91), mid(96))): put(sfx, chime(f, .9), B0 + .1 + i * .05, .55)   # 金币炸开
put(sfx, riser(.45), B0 + .25, .6)
put(sfx, whoosh(.3, True), B0 + .5, .7); put(sfx, boom(1.8), B0 + .72, 1.15)         # “投资身体”更重的一击
put(sfx, clap(), B0 + .72, .9); put(music, kick(), B0 + .72, .9)
for t in (B0 + .08, B0 + .72): put(music, kick(), t, .8)
for t in np.arange(B0 + .72, S['C'][0], .25): put(music, bassnote(mid(33), .2), t, .4)
put(sfx, tick(), 0.62, .0)   # 预留
# ---- C：低调垫底（访谈在说话）
put(verb, pad([mid(57), mid(60), mid(64)], 4.2), S['C'][0] - .1, .8)
for t in np.arange(S['C'][0], S['C'][1] - .5, BEAT): put(music, kick(.3), t, .22)
put(sfx, riser(1.6), S['P'][0] - 1.6, .55)
# ---- P：搏击 → 薄肌
put(sfx, boom(1.3), S['P'][0], .8); put(sfx, whoosh(.45, True), S['P'][0] - .3, .5)
put(verb, pad([mid(45), mid(52), mid(57)], 3.2), S['P'][0], .9)
for k, t in enumerate(np.arange(S['P'][0] + .4, S['P'][0] + 1.1, BEAT)): put(music, kick(.3), t, .3)
sw = S['P'][0] + 1.15
put(sfx, whoosh(.4, False), sw - .1, .8); put(sfx, boom(1.0), sw + .25, .85); put(sfx, whoosh(.3, True), sw + .1, .5)
for i in range(3): put(sfx, tick(), S['P'][0] + 1.75 + i * .16, .9)
put(sfx, riser(.8), S['H1'][0] - .8, .7)
# ---- 主体：H1~H3 + CTA 前半（鼓 + 贝斯 + 琶音 + 和弦垫）
d0, d1 = S['H1'][0], S['D'][0] + 3.9
put(sfx, boom(1.4), d0, 1.0); put(sfx, whoosh(.6, False), d0 - .05, .6)
t = d0
while t < d1 - 1e-6:
    bar = int((t - d0) // 2); root, tones = bar_chord(t); bt = round(((t - d0) % 2) / BEAT)
    # 鼓
    put(music, kick(), t, .8)
    if bt in (1, 3): put(music, clap(), t, .55)
    for h in (0, .25): put(music, hat(), t + h, .5 if h == 0 else .35)
    if bt in (0, 2): put(music, hat(op=True), t + .25, .4)
    # 贝斯（8 分音符）
    for h in (0, .25): put(music, bassnote(mid(root), .22), t + h, .55)
    # 琶音（16 分音符，亮度随段落提升）
    sec = 0 if t < S['H2'][0] else 1 if t < S['H3'][0] else 2
    for j, h in enumerate((0, .125, .25, .375)):
        m = tones[(j + bt) % 3] + (12 if (j + bt) % 2 else 24)
        put(music, pluck(mid(m), .2, 2500 + 1200 * sec), t + h, .26 if sec else .2, pan=(-.4 if j % 2 else .4))
    t += BEAT
for t in np.arange(d0, S['D'][0] + 3.9, 2.0):
    root, tones = bar_chord(t); put(verb, pad([mid(m) for m in tones] + [mid(tones[0] + 12)], 2.1), t, 1.0)
# 场景切换
for k in ('H2', 'H3'):
    a = S[k][0]; put(sfx, whoosh(.55, False), a - .1, .7); put(sfx, boom(1.0), a, .65)
    put(sfx, clap(), a - .25, .9); put(sfx, clap(), a - .125, .7)
# 点按音效（取时间线里的触点）
def timeOf(k, scene, frame):
    acc = 0
    for s in T['segs'][k]:
        dur = (s['f1'] - s['f0']) / 30 / s['speed']
        if s['scene'] == scene and s['f0'] <= frame < s['f1']: return acc + (frame - s['f0']) / 30 / s['speed']
        acc += dur
for k, evs in T['events'].items():
    for e in evs:
        o = timeOf(k, e['scene'], e['frame'])
        if o is not None: put(sfx, tick(), S[k][0] + .4025 + o, .8)
# 每个亮点：标题弹出的“嗒”
for k in ('H1', 'H2', 'H3'): put(sfx, tick(), S[k][0] + .12 + .1, 1.0)
# ---- CTA
D = S['D'][0]
put(sfx, boom(1.5), D, 1.0); put(sfx, whoosh(.6, False), D - .1, .6)
for i, f in enumerate((mid(81), mid(84), mid(88))): put(sfx, chime(f), D + 1.0 + i * .42, .9)
put(sfx, chime(mid(93), 2.0), D + 2.5, .7)
put(verb, pad([mid(57), mid(60), mid(64), mid(69)], 2.9), D + 3.6, 1.1)
put(music, kick(), D + 3.5, .0)

# ---- 访谈原声
def load(p):
    w = wave.open(str(p)); a = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768; return a.reshape(-1, w.getnchannels())
voice = zeros()
for name, t0 in (('clipA', S['A'][0]), ('clipC', S['C'][0])):
    a = load(OUT / f'{name}.wav'); f = int(.015 * SR); a[:f] *= np.linspace(0, 1, f)[:, None]; a[-f * 3:] *= np.linspace(1, 0, f * 3)[:, None]
    i = int(t0 * SR); voice[i:i + len(a)] += a[:N - i] * 1.6    # 原声偏小，抬一下

# ---- 混音
def duck(x):
    g = np.ones(N)
    for a, b in ((S['A'][0], S['A'][1]), (S['C'][0], S['C'][0] + 4.0)):
        i, j = int(a * SR), int(b * SR); g[i:j] = .32
    g = lp(g, 8, 1); return x * g[:, None]
verb = reverb(verb, 1.4, .55)
mus = duck(music * .9 + verb * .8)
sfx_d = sfx * .8
clean = voice + sfx_d
full = voice + sfx_d + mus
def finish(x, name):
    f = int(.5 * SR); x = x.copy(); x[-f:] *= np.linspace(1, 0, f)[:, None]
    pk = np.abs(x).max(); x = x / pk * .89
    # 简单限幅/软削波
    x = np.tanh(x * 1.15) / np.tanh(1.15)
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(str(OUT / name), 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    print('wrote', name, round(len(x) / SR, 2), 's')
finish(full, 'audio_music.wav'); finish(clean, 'audio_clean.wav')
