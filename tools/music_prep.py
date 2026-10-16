"""Prepare the user's Suno tracks for the game.

  G:/audio_library/venv/Scripts/python.exe tools/music_prep.py <main.wav> <ending.wav>

main   -> assets/music/main.ogg : seamless loop. Takes [START, END) and bakes a
          crossfade with the audio that follows END into the head, so the jump
          END -> START continues naturally. -18 LUFS, a small 2-5 kHz dip to leave
          room for the cutting and metal sounds.
ending -> assets/music/ending.ogg : played once under the settlement, -16 LUFS.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from pedalboard import Pedalboard, PeakFilter, HighpassFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'music'
OUT.mkdir(parents=True, exist_ok=True)
START = 4.0
END = 272.0
XF = 6.0


def master(x, sr, lufs):
    board = Pedalboard([HighpassFilter(30.0), PeakFilter(3200.0, -2.5, 0.8)])
    x = board(x.T.astype(np.float32), sr).T
    gain = lufs - pyln.Meter(sr).integrated_loudness(x)
    x = x * (10 ** (gain / 20))
    peak = np.max(np.abs(x))
    if peak > 0.95:
        x = np.tanh(x / peak * 1.4) / np.tanh(1.4) * 0.95
    return x


def ogg(x, sr, name):
    wav = Path('G:/audio_library/work/zeropower/music') / (name + '_out.wav')
    sf.write(str(wav), x, sr, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.1fs' % (len(x) / sr))


def main():
    x, sr = sf.read(sys.argv[1], always_2d=True, dtype='float32')
    a, e, n = int(START * sr), int(END * sr), int(XF * sr)
    loop = x[a:e].copy()
    k = np.sin(np.linspace(0, np.pi / 2, n))[:, None]
    loop[:n] = loop[:n] * k + x[e:e + n] * np.cos(np.linspace(0, np.pi / 2, n))[:, None]
    ogg(master(loop, sr, -18.0), sr, 'main')
    y, sr2 = sf.read(sys.argv[2], always_2d=True, dtype='float32')
    ogg(master(y, sr2, -16.0), sr2, 'ending')


if __name__ == '__main__':
    main()
