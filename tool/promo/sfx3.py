#!/usr/bin/env python3
"""亮点三样片（cine3.html）的声音：低频铺底 + 与镜头动作逐一对齐的音效。输出 out/promo/sfx3.wav。"""
import wave
import numpy as np
from scipy import signal
from pathlib import Path
OUT = Path(__file__).resolve().parents[2] / 'out/promo'
SR = 48000; TOTAL = 8.9; N = int(TOTAL * SR)
rng = np.random.default_rng(11)
buf = np.zeros((N, 2))

def tt(d): return np.arange(int(d * SR)) / SR
def put(x, t, g=1.0, pan=0.0):
    i = int(t * SR); x = np.asarray(x); L = min(len(x), N - i)
    if L <= 0: return
    if x.ndim == 1: x = np.stack([x * (1 - max(0, pan)), x * (1 + min(0, pan))], 1)
    buf[i:i + L] += x[:L] * g
def lp(x, f): b, a = signal.butter(2, f / (SR / 2), 'low'); return signal.lfilter(b, a, x)
def hp(x, f): b, a = signal.butter(2, f / (SR / 2), 'high'); return signal.lfilter(b, a, x)
def bp(x, f0, f1): b, a = signal.butter(2, [f0 / (SR / 2), f1 / (SR / 2)], 'band'); return signal.lfilter(b, a, x)
def sweep(d, f0, f1, shape):
    """带通噪声从 f0 扫到 f1，包络 shape(u)。"""
    n = rng.standard_normal(int(d * SR)); u = tt(d) / d; out = np.zeros_like(n); K = 24
    for k in range(K):
        s = slice(int(k / K * len(n)), int((k + 1) / K * len(n))); f = f0 * (f1 / f0) ** (k / K)
        out[s] = bp(n, f, min(f * 1.8, 20000))[s]
    return out * shape(u)
def whoosh(d, up=True): return sweep(d, 250, 5000, lambda u: np.sin(np.pi * u) ** 1.5) if up else sweep(d, 5000, 250, lambda u: np.sin(np.pi * u) ** 1.2)
def riser(d): return sweep(d, 200, 9000, lambda u: u ** 2.2) * .9
def sub(d=1.8, f=40):
    t = tt(d); return np.sin(2 * np.pi * f * t * (1 + .8 * np.exp(-t * 7))) * np.exp(-t * 2.2)
def impact(d=2.2):
    t = tt(d); body = sub(d, 36)
    crack = hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 35) * .5
    tail = lp(rng.standard_normal(len(t)), 900) * np.exp(-t * 4) * .35
    return body + crack + tail
def bell(f, d=1.6):
    t = tt(d); return (np.sin(2 * np.pi * f * t) + .35 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 6) + .2 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 10)) * np.exp(-t * 3) * .3
def tick():
    t = tt(.06); return hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 110) * .5 + np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 80) * .25
def drone(d):
    t = tt(d); x = 0
    for f, a in ((55, 1), (110, .5), (164.8, .25), (220, .18), (261.6, .12)):
        for de in (-.004, .004): x = x + a * (2 * ((t * f * (1 + de)) % 1) - 1)
    # 低通随时间打开，推镜时最亮，结尾收回
    cut = 300 + 1600 * np.clip((t - 1) / 2.4, 0, 1) - 900 * np.clip((t - 6.9) / 1.5, 0, 1)
    y = np.zeros_like(x); z = 0.0
    alpha = 1 - np.exp(-2 * np.pi * cut / SR)
    for i in range(len(x)): z += alpha[i] * (x[i] - z); y[i] = z
    e = np.minimum(1, t / 1.2) * np.minimum(1, (d - t) / .6)
    return y * e * .08
def reverb(x, d=1.8, wet=.35):
    t = tt(d); ir = rng.standard_normal((len(t), 2)) * np.exp(-t * 3.2)[:, None] * .06
    w = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1); return x + w * wet

mid = lambda m: 440 * 2 ** ((m - 69) / 12)
put(drone(TOTAL), 0, 1.0)
put(whoosh(1.1), .05, .55)                              # 手机升起
put(sub(1.2, 44), .3, .5); put(sub(1.2, 49), .55, .45)  # 两行标题落位
put(whoosh(.8), 1.85, .25, -.3)                         # 卡片抬起
put(riser(.8), 2.58, .5)                                # 推镜前蓄力
put(whoosh(.5), 3.0, .6)
put(impact(), 3.38, .95)                                # 推到位
put(sweep(.85, 1500, 9000, lambda u: np.sin(np.pi * u)), 3.75, .18)   # 染色扫光
for i, m in enumerate((69, 72, 76, 79, 81, 84, 88)):    # 染色时的上行音
    put(bell(mid(m)), 3.78 + i * .11, .5, -.5 + i / 6)
FPS, F0, SPEED, TP = 30, 40, 2.2, 4.6
for f in (60, 105, 150): put(tick(), TP + (f - F0) / FPS / SPEED, .8)
put(whoosh(.9, False), 6.85, .5)                        # 拉回
put(sub(1.6, 41), 7.72, .6); put(bell(mid(81), 2.2), 7.72, .45); put(bell(mid(76), 2.2), 7.75, .3)
buf = reverb(buf)
buf *= np.minimum(1, (TOTAL - tt(TOTAL)) / .45)[:, None]
buf /= max(1e-9, np.abs(buf).max()) / .89
with wave.open(str(OUT / 'sfx3.wav'), 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((buf * 32767).astype('<i2').tobytes())
print('ok', OUT / 'sfx3.wav')
