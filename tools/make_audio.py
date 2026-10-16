"""ZERO PRESSURE audio: synthesis (numpy/scipy) layered with a few Sonniss
library recordings for metal, electricity and air. Fixed seeds.
Usage: G:/audio_library/venv/Scripts/python.exe tools/make_audio.py [only_prefix]
"""
import json
import os
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

import numpy as np
import soundfile as sf
from pedalboard import Pedalboard, Reverb, Compressor, Limiter
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
WORK = Path('G:/audio_library/work/zeropower')
OUT.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
POOL = 'G:/audio_library/sonniss'
SR = 44100
ONLY = sys.argv[1] if len(sys.argv) > 1 else ''
rng = np.random.default_rng(11)
SLICES = json.load(open(os.path.join(POOL, 'slices.json'), encoding='utf-8'))


def tv(d):
    return np.arange(int(SR * d)) / SR


def noise(n):
    return rng.standard_normal(n)


def env(t, a, d):
    return np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0.0, t - a) / d)


def filt(x, kind, f, order=2):
    if kind == 'band':
        sos = butter(order, [max(20, f[0]), min(SR / 2 - 100, f[1])], btype='band', fs=SR, output='sos')
    else:
        sos = butter(order, min(SR / 2 - 100, max(20, f)), btype=kind, fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)


def lp(x, f):
    return filt(x, 'low', f)


def hp(x, f):
    return filt(x, 'high', f)


def bp(x, lo, hi):
    return filt(x, 'band', (lo, hi))


def sweep(f0, f1, d, curve=1.0):
    t = tv(d)
    f = f0 + (f1 - f0) * (t / d) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def tone(f, d, a=0.004, dec=0.2, harm=(1.0,)):
    t = tv(d)
    x = sum(h * np.sin(2 * np.pi * f * (i + 1) * t) for i, h in enumerate(harm))
    return x * env(t, a, dec)


def pad(x, d):
    n = int(SR * d)
    if len(x) >= n:
        return x[:n]
    shape = (n - len(x),) + x.shape[1:]
    return np.concatenate([x, np.zeros(shape)])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def sample(key, index=0, start=0.0, dur=None, pitch=1.0):
    hits = [s for s in SLICES if key.lower() in s['file'].lower()]
    if not hits:
        print('  (no sample for', key, ')')
        return np.zeros(int(SR * (dur or 0.2)))
    s = hits[min(index, len(hits) - 1)]
    path = os.path.join(POOL, 'files', s['file'])
    if not os.path.exists(path):
        print('  (missing file', s['file'], ')')
        return np.zeros(int(SR * (dur or 0.2)))
    sr = s['sr']
    a = int((s['start'] + start) * sr)
    b = int((s['start'] + start + dur) * sr) if dur else int(s['end'] * sr)
    data, sr2 = sf.read(path, start=a, stop=b, always_2d=True, dtype='float32')
    x = data.mean(axis=1).astype(np.float64)
    target = SR / pitch
    ratio = Fraction(int(round(target)), int(sr2)).limit_denominator(400)
    if ratio != 1:
        x = resample_poly(x, ratio.numerator, ratio.denominator)
    m = np.max(np.abs(x))
    return x / m if m > 0 else x


def verb(x, room=0.35, wet=0.18):
    board = Pedalboard([Reverb(room_size=room, wet_level=wet, dry_level=1.0, width=0.9)])
    y = board(np.stack([x, x]).astype(np.float32), SR)
    return y.T.astype(np.float64)


def stereo(x, width=0.25):
    if x.ndim == 2:
        return x
    d = int(SR * 0.006)
    r = np.concatenate([np.zeros(d), x[:len(x) - d]])
    return np.stack([x * (1 - width * 0.5) + r * width * 0.5, r * (1 - width * 0.5) + x * width * 0.5], axis=1)


def fade(x, a=0.002, r=0.03):
    n = len(x)
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return x * (e[:, None] if x.ndim == 2 else e)


def loopify(x, xf=0.4):
    # crossfade the tail into the head so the loop has no seam
    n = int(SR * xf)
    head = x[:n].copy()
    tail = x[-n:].copy()
    k = np.linspace(0, 1, n)
    if x.ndim == 2:
        k = k[:, None]
    body = x[n:-n] if len(x) > 2 * n else x
    seam = tail * (1 - k) + head * k
    return np.concatenate([body, seam])


def write(name, x, peak=0.85, rv=None, loop=False):
    if ONLY and not name.startswith(ONLY):
        return
    if rv:
        x = verb(x if x.ndim == 1 else x.mean(axis=1), *rv)
    x = stereo(x)
    if loop:
        x = loopify(x)
    else:
        x = fade(x)
    x = x - x.mean(axis=0)
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    # lift quiet transients toward a common loudness, soft-limited
    rms = np.sqrt((x ** 2).mean()) + 1e-9
    want = 10 ** ((-24.0 if loop else -18.0) / 20)
    if rms < want:
        g = min(4.0, want / rms)
        x = np.tanh(x * g * 1.2) / np.tanh(1.2) * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    f = WORK / (name + '.wav')
    sf.write(str(f), pcm, SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.2fs' % (len(x) / SR))


# ---------------------------------------------------------------- building blocks

def metal_hit(pitch=1.0, d=0.8, bright=1.0):
    t = tv(d)
    modes = [(420, 1.0, 0.25), (1130, 0.6, 0.18), (1870, 0.45, 0.12), (2950, 0.3, 0.08), (4300, 0.2, 0.05)]
    x = np.zeros(len(t))
    for f, a, dec in modes:
        x += a * np.sin(2 * np.pi * f * pitch * t + rng.random() * 6) * np.exp(-t / (dec * (1.4 - 0.4 * bright)))
    click = hp(noise(len(t)), 2500) * np.exp(-t / 0.006) * 0.8 * bright
    thump = lp(noise(len(t)), 300) * np.exp(-t / 0.05) * 1.2
    return x * 0.5 + click + thump


def hiss(d, lo=1500, hi=9000, a=0.02, r=0.2):
    t = tv(d)
    x = bp(noise(len(t)), lo, hi)
    return x * np.minimum(1, t / a) * np.minimum(1, np.maximum(0, d - t) / r)


def click(d=0.03, f=3000):
    t = tv(d)
    return hp(noise(len(t)), f) * np.exp(-t / 0.004)


def servo(d, f0=180, f1=260):
    t = tv(d)
    w = sweep(f0, f1, d)
    buzz = np.sign(w) * 0.3 + w
    return lp(buzz, 2200) * np.minimum(1, t / 0.03) * np.minimum(1, (d - t) / 0.05) * (1 + 0.15 * np.sin(2 * np.pi * 31 * t))


def rumble(d, f=60, a=0.3, r=0.5):
    t = tv(d)
    x = lp(noise(len(t)), f * 2) * 3 + np.sin(2 * np.pi * f * t) * 0.3
    return x * np.minimum(1, t / a) * np.minimum(1, np.maximum(0, d - t) / r)


# ---------------------------------------------------------------- ui

def ui():
    write('tool', mix(click(0.02, 4000) * 0.5, tone(1760, 0.08, 0.002, 0.03) * 0.25, at(tone(2640, 0.06, 0.002, 0.025) * 0.18, 0.025)))
    write('menu', mix(hiss(0.25, 800, 4000, 0.08, 0.15) * 0.4, tone(660, 0.3, 0.01, 0.12) * 0.2))
    write('ok', mix(click(0.02, 3000) * 0.4, tone(1320, 0.12, 0.002, 0.05) * 0.3, at(tone(1980, 0.12, 0.002, 0.06) * 0.25, 0.04)))
    write('deny', mix(tone(180, 0.12, 0.003, 0.05, (1, 0.6, 0.4)) * 0.6, at(tone(150, 0.14, 0.003, 0.06, (1, 0.6, 0.4)) * 0.6, 0.11)))
    write('warn', mix(tone(988, 0.1, 0.003, 0.05) * 0.4, at(tone(740, 0.12, 0.003, 0.06) * 0.4, 0.11)))
    write('blueprint_on', mix(sweep(400, 1600, 0.35) * env(tv(0.35), 0.05, 0.15) * 0.15, hiss(0.35, 3000, 9000, 0.1, 0.2) * 0.12, *[at(tone(1200 + i * 300, 0.1, 0.002, 0.04) * 0.08, i * 0.05) for i in range(5)]))
    write('blueprint_off', mix(sweep(1400, 400, 0.25) * env(tv(0.25), 0.01, 0.1) * 0.15, hiss(0.25, 2000, 7000, 0.02, 0.2) * 0.08))


# ---------------------------------------------------------------- tools

def tools():
    write('probe', mix(servo(0.32, 300, 520) * 0.35, at(click(0.03) * 0.4, 0.3)))
    write('measure', mix(tone(1560, 0.09, 0.002, 0.04) * 0.3, at(tone(2080, 0.16, 0.002, 0.08) * 0.3, 0.07), click(0.02) * 0.2), rv=(0.2, 0.08))
    rat = mix(*[at(click(0.02, 2200) * (0.5 + 0.3 * (i % 2)), i * 0.055) for i in range(8)])
    write('wrench', mix(rat, servo(0.45, 200, 240) * 0.08))
    write('unbolt', mix(metal_hit(2.2, 0.35, 1.0) * 0.4, click(0.03) * 0.5, at(metal_hit(3.1, 0.25, 0.6) * 0.25, 0.08)), rv=(0.3, 0.12))
    write('unplug', mix(lp(noise(int(SR * 0.08)), 900) * env(tv(0.08), 0.002, 0.02) * 0.9, click(0.03, 1800) * 0.5, at(hiss(0.08, 3000, 8000, 0.002, 0.06) * 0.15, 0.02)))
    t = tv(0.5)
    squeak = np.sin(2 * np.pi * np.cumsum(900 + 250 * np.sin(2 * np.pi * 7 * t)) / SR) * env(t, 0.05, 0.2) * 0.12
    write('valve', mix(squeak, at(metal_hit(1.5, 0.4, 0.5) * 0.4, 0.38)), rv=(0.3, 0.1))
    write('switch', mix(click(0.04, 1200) * 0.8, lp(noise(int(SR * 0.06)), 600) * env(tv(0.06), 0.001, 0.015) * 0.6))
    write('plug', mix(click(0.04, 1500) * 0.6, metal_hit(2.5, 0.25, 0.7) * 0.25, at(tone(220, 0.25, 0.01, 0.1, (1, 0.5)) * 0.2, 0.05)))
    write('hose_on', mix(metal_hit(1.2, 0.4, 0.4) * 0.4, at(hiss(0.6, 600, 5000, 0.05, 0.3) * 0.3, 0.05)), rv=(0.3, 0.1))
    write('grab', mix(sweep(60, 140, 0.3) * env(tv(0.3), 0.01, 0.2) * 0.5, click(0.03, 2500) * 0.4, hp(noise(int(SR * 0.25)), 5000) * env(tv(0.25), 0.002, 0.05) * 0.1))
    write('release', mix(sweep(140, 50, 0.25) * env(tv(0.25), 0.005, 0.12) * 0.4, click(0.02, 3000) * 0.2))
    write('throw', mix(hiss(0.35, 300, 3000, 0.03, 0.25) * 0.5, sweep(160, 50, 0.3) * env(tv(0.3), 0.005, 0.15) * 0.4))
    write('unjam', mix(metal_hit(0.7, 0.9, 0.8) * 0.6, at(hiss(0.2, 2000, 6000, 0.01, 0.15) * 0.2, 0.05), at(metal_hit(1.3, 0.5, 1.0) * 0.4, 0.22)), rv=(0.5, 0.2))
    write('hatch', mix(servo(1.2, 90, 120) * 0.35, rumble(1.2, 50, 0.1, 0.3) * 0.3, at(metal_hit(0.6, 0.9, 0.6) * 0.5, 1.1)), rv=(0.5, 0.2))
    write('door', mix(servo(0.55, 160, 210) * 0.35, at(metal_hit(1.0, 0.4, 0.5) * 0.35, 0.5)))
    write('gen_down', mix(sweep(220, 40, 1.4, 0.6) * env(tv(1.4), 0.01, 0.8) * 0.4, sweep(440, 80, 1.4, 0.6) * env(tv(1.4), 0.01, 0.6) * 0.15, rumble(1.4, 45, 0.02, 0.8) * 0.3), rv=(0.5, 0.15))
    clamp_x = sample('Bay Door_Lock Down', 0, 0.0, 1.6)
    write('clamp', mix(clamp_x * 0.7, metal_hit(0.5, 0.8, 0.7) * 0.5), rv=(0.6, 0.2))
    write('clamp_off', mix(hiss(0.5, 500, 6000, 0.01, 0.4) * 0.5, metal_hit(0.6, 0.8, 0.6) * 0.6, at(rumble(0.6, 55, 0.05, 0.4) * 0.3, 0.05)), rv=(0.6, 0.2))
    write('launch', mix(hiss(0.7, 200, 4000, 0.01, 0.5) * 0.6, metal_hit(0.8, 0.5, 0.5) * 0.4, sweep(80, 300, 0.6) * env(tv(0.6), 0.02, 0.25) * 0.3), rv=(0.6, 0.2))


# ---------------------------------------------------------------- events

def events():
    write('crack', mix(metal_hit(0.9, 0.8, 1.0) * 0.6, hp(noise(int(SR * 0.2)), 1500) * env(tv(0.2), 0.001, 0.05) * 0.5, at(metal_hit(1.6, 0.4, 0.7) * 0.3, 0.06)), rv=(0.5, 0.18))
    groan = np.sin(2 * np.pi * np.cumsum(70 + 20 * np.sin(2 * np.pi * 1.3 * tv(1.2))) / SR) * env(tv(1.2), 0.15, 0.5)
    write('free', mix(lp(groan + 0.3 * np.sign(groan), 900) * 0.4, metal_hit(0.45, 1.2, 0.5) * 0.5, sample('dry hard metal impact', 0, 0.0, 1.2, 0.8) * 0.3), rv=(0.6, 0.25))
    write('clank', mix(sample('Hit Impact Hard Metal Scrap', 0, 0.0, 0.45) * 0.7, metal_hit(1.1, 0.5, 0.8) * 0.4), rv=(0.4, 0.15))
    write('debris', mix(sample('Bouncing Metal Rattle', 1, 0.0, 0.8, 1.3) * 0.5, hiss(0.4, 2000, 7000, 0.01, 0.3) * 0.15))
    write('net', mix(hiss(0.3, 1500, 6000, 0.02, 0.25) * 0.3, click(0.03) * 0.2, at(tone(880, 0.15, 0.002, 0.05) * 0.1, 0.05)))
    write('reject', mix(tone(130, 0.35, 0.005, 0.2, (1, 0.7, 0.5, 0.3)) * 0.5, metal_hit(0.8, 0.6, 0.8) * 0.5, at(hiss(0.3, 600, 4000, 0.01, 0.25) * 0.4, 0.03)), rv=(0.5, 0.2))
    write('swallow_equip', mix(servo(0.6, 300, 600) * 0.3, *[at(tone(1000 + 200 * i, 0.08, 0.002, 0.03) * 0.12, 0.08 * i) for i in range(6)]))
    t = tv(0.6)
    write('swallow_metal', mix(rumble(0.6, 70, 0.3, 0.05) * 0.6, hiss(0.6, 300, 3000, 0.3, 0.05) * 0.4))
    write('swallow_hazard', mix(hiss(0.6, 800, 6000, 0.2, 0.1) * 0.4, servo(0.6, 120, 150) * 0.25))
    write('eat_equip', mix(metal_hit(0.7, 0.8, 0.5) * 0.5, at(tone(660, 0.6, 0.004, 0.3, (1, 0.4)) * 0.25, 0.03), at(tone(990, 0.6, 0.004, 0.3) * 0.2, 0.12)), rv=(0.5, 0.2))
    crush = sample('Crush Rattle Metal Scrap', 0, 0.0, 1.4)
    write('eat_metal', mix(crush * 0.6, rumble(1.6, 50, 0.05, 1.0) * 0.8, at(hiss(1.0, 1500, 7000, 0.05, 0.8) * 0.25, 0.15), metal_hit(0.4, 1.0, 0.8) * 0.4), rv=(0.6, 0.2))
    write('eat_hazard', mix(metal_hit(0.55, 0.8, 0.4) * 0.6, at(hiss(0.8, 1200, 7000, 0.01, 0.6) * 0.4, 0.05)), rv=(0.5, 0.2))
    boom = sample('combat_drone_weapon_explosion', 0, 0.0, 2.5)
    write('boom', mix(boom * 0.8, rumble(2.0, 40, 0.01, 1.2) * 1.0, metal_hit(0.35, 1.5, 1.0) * 0.4), rv=(0.7, 0.25))
    arcx = sample('surge_discharge_electrical_arc', 0, 0.0, 1.4)
    t = tv(1.0)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * hp(noise(len(t)), 800) * env(t, 0.002, 0.25)
    write('arc', mix(arcx * 0.8, buzz * 0.4, click(0.05, 1000) * 0.9), rv=(0.4, 0.15))
    write('zap_small', mix(sample('sizzling_crackling', 0, 0.3, 0.35) * 0.6, click(0.03, 2000) * 0.5))
    write('burst', mix(lp(noise(int(SR * 0.3)), 1200) * env(tv(0.3), 0.001, 0.05) * 1.2, metal_hit(0.6, 1.0, 1.0) * 0.6, at(hiss(1.4, 800, 9000, 0.01, 1.0) * 0.6, 0.02)), rv=(0.6, 0.25))
    write('leak', mix(hiss(1.2, 600, 5000, 0.05, 0.6) * 0.4, *[at(tone(1800 + 400 * i, 0.05, 0.001, 0.02) * 0.1, 0.2 + i * 0.27) for i in range(3)]))
    write('hiss', hiss(0.5, 1500, 9000, 0.005, 0.4) * 0.6)
    write('ignite', mix(lp(noise(int(SR * 1.6)), 700) * env(tv(1.6), 0.03, 0.5) * 1.2, hiss(1.6, 300, 4000, 0.02, 1.0) * 0.5, rumble(1.5, 45, 0.02, 1.0) * 0.8), rv=(0.7, 0.25))
    t = tv(2.2)
    rush = bp(noise(len(t)), 200, 6000) * env(t, 0.01, 0.9)
    write('blowout', mix(rush * 0.9, lp(noise(len(t)), 120) * env(t, 0.005, 0.6) * 1.2, metal_hit(0.3, 1.8, 0.8) * 0.5, at(sample('dry rusty metal impact with collapse', 0, 0.0, 1.5, 0.7) * 0.4, 0.15)), rv=(0.7, 0.3))
    write('hurt', mix(metal_hit(1.4, 0.4, 1.0) * 0.6, at(tone(880, 0.08, 0.002, 0.03) * 0.25, 0.08), at(tone(660, 0.1, 0.002, 0.04) * 0.25, 0.17)))
    write('reveal', mix(hiss(0.9, 400, 3000, 0.25, 0.5) * 0.35, sweep(120, 260, 0.9) * env(tv(0.9), 0.2, 0.4) * 0.2), rv=(0.6, 0.25))
    t = tv(0.6)
    twang = np.sin(2 * np.pi * np.cumsum(900 * np.exp(-t * 3)) / SR) * env(t, 0.001, 0.15)
    write('snap', mix(twang * 0.5, click(0.04, 1500) * 0.8, metal_hit(1.8, 0.4, 0.8) * 0.3), rv=(0.4, 0.15))
    t = tv(3.0)
    chord = sum(np.sin(2 * np.pi * f * t) * (0.35 / (i + 1)) for i, f in enumerate([65.4, 98.0, 130.8, 196.0, 261.6]))
    write('end', mix(chord * env(t, 0.6, 1.4), hiss(3.0, 2000, 8000, 1.0, 1.5) * 0.05), rv=(0.8, 0.3))


# ---------------------------------------------------------------- loops

def loops():
    d = 3.0
    t = tv(d)
    core = bp(noise(len(t)), 2500, 9000) * 0.5
    whine = np.sin(2 * np.pi * 3100 * t + 2 * np.sin(2 * np.pi * 7 * t)) * 0.06
    crackle = np.zeros(len(t))
    for i in range(160):
        p = int(rng.random() * (len(t) - 400))
        crackle[p:p + 300] += hp(noise(300), 3000) * np.exp(-np.arange(300) / 40) * rng.random()
    burn = lp(noise(len(t)), 500) * 0.4
    write('cut_loop', core + whine + crackle * 0.5 + burn, peak=0.7, loop=True)
    write('jet_loop', bp(noise(int(SR * 3.0)), 150, 7000) * (1 + 0.1 * np.sin(2 * np.pi * 0.7 * tv(3.0))), peak=0.7, loop=True)
    th = bp(noise(int(SR * 3.0)), 80, 2500)
    write('thrust_loop', th + lp(noise(int(SR * 3.0)), 120) * 2.0, peak=0.6, loop=True)
    t = tv(3.2)
    chug = (0.5 + 0.5 * np.sin(2 * np.pi * 2.5 * t)) ** 4
    write('pump_loop', lp(noise(len(t)), 400) * chug * 1.5 + np.sin(2 * np.pi * 95 * t) * 0.15 + hiss(3.2, 1000, 4000, 0.01, 0.01) * 0.05, peak=0.5, loop=True)
    t = tv(3.0)
    hum = sum(np.sin(2 * np.pi * 50 * k * t) / k for k in (1, 2, 3, 5, 7)) * (1 + 0.05 * np.sin(2 * np.pi * 0.5 * t))
    write('hum_loop', hum * 0.5 + lp(noise(len(t)), 300) * 0.2, peak=0.5, loop=True)
    mag = np.sin(2 * np.pi * 110 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t)) + np.sin(2 * np.pi * 220.5 * t) * 0.3
    write('tether_loop', mag + hp(noise(len(t)), 4000) * 0.05, peak=0.5, loop=True)
    # the dock: low pad, slow swells, distant metal now and then
    d = 24.0
    t = tv(d)
    pad_x = np.zeros(len(t))
    for f, a in [(41.2, 0.5), (55.0, 0.35), (82.4, 0.2), (110.0, 0.1), (164.8, 0.05)]:
        pad_x += a * np.sin(2 * np.pi * f * t + 2 * np.sin(2 * np.pi * 0.05 * t))
    pad_x *= 0.7 + 0.3 * np.sin(2 * np.pi * t / d * 2)
    air = lp(noise(len(t)), 400) * 0.3
    events_x = np.zeros(len(t))
    for k in range(6):
        p = int((1.5 + k * 3.9 + rng.random()) * SR)
        h = metal_hit(0.25 + rng.random() * 0.3, 2.5, 0.3) * 0.15
        events_x[p:p + len(h)] += h[:len(t) - p]
    write('ambience', pad_x + air + events_x, peak=0.6, rv=(0.9, 0.35), loop=True)


if __name__ == '__main__':
    ui()
    tools()
    events()
    loops()
