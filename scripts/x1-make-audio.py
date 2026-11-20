#!/usr/bin/env python3
"""Generate every X1 sound effect and music loop (standard library only, fixed seeds).

    python3 -B scripts/x1-make-audio.py          # writes game/assets/audio/x1/**.wav and prints a report

Sound names and variant counts come from game/data/x1/feel.json ("sounds"); each recipe below
layers a transient, a body and a tail. Music: per region four 8-bar loops at the same tempo
(ambient, drums, lead, boss) that the game crossfades by intensity, plus short stingers.
"""

import array
import json
import math
import random
import wave
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / 'game/assets/audio/x1'
RATE = 22050
TAU = math.tau


# ---- primitives ---------------------------------------------------------------------------

def buf(seconds):
    return [0.0] * max(1, int(seconds * RATE))


def add(dst, src, at=0.0, gain=1.0, wrap=False):
    start = int(at * RATE)
    n = len(dst)
    for i, v in enumerate(src):
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        dst[j] += v * gain
    return dst


def env_exp(n, attack, decay):
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(math.exp(-(i - a) / (decay * RATE)))
    return out


def tone(seconds, f0, f1=None, wave_type='sine', attack=0.002, decay=0.08, gain=1.0, vibrato=0.0, fm=0.0, fm_ratio=2.0):
    f1 = f0 if f1 is None else f1
    n = int(seconds * RATE)
    env = env_exp(n, attack, decay)
    out = []
    phase = 0.0
    mod_phase = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        freq = f0 * (f1 / f0) ** t if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
        if vibrato:
            freq *= 1.0 + vibrato * math.sin(TAU * 5.5 * i / RATE)
        mod = 0.0
        if fm:
            mod_phase += TAU * freq * fm_ratio / RATE
            mod = fm * math.sin(mod_phase) * env[i]
        phase += TAU * freq / RATE
        p = phase + mod
        if wave_type == 'sine':
            v = math.sin(p)
        elif wave_type == 'tri':
            v = 2.0 / math.pi * math.asin(math.sin(p))
        elif wave_type == 'square':
            v = 0.6 if math.sin(p) >= 0 else -0.6
        elif wave_type == 'saw':
            v = ((p / TAU) % 1.0) * 2.0 - 1.0
            v *= 0.6
        else:
            v = math.sin(p)
        out.append(v * env[i] * gain)
    return out


def noise(seconds, rng, attack=0.001, decay=0.05, gain=1.0, lp=None, hp=None, lp_end=None):
    n = int(seconds * RATE)
    env = env_exp(n, attack, decay)
    out = []
    low = 0.0
    prev_in = 0.0
    prev_hp = 0.0
    for i in range(n):
        x = rng.uniform(-1.0, 1.0)
        if lp is not None:
            cutoff = lp if lp_end is None else lp + (lp_end - lp) * i / max(1, n - 1)
            k = 1.0 - math.exp(-TAU * cutoff / RATE)
            low += k * (x - low)
            x = low
        if hp is not None:
            k = math.exp(-TAU * hp / RATE)
            y = k * (prev_hp + x - prev_in)
            prev_in = x
            prev_hp = y
            x = y
        out.append(x * env[i] * gain)
    return out


def normalize(samples, peak=0.89):
    top = max(1e-9, max(abs(v) for v in samples))
    return [v * peak / top for v in samples]


def soft_clip(samples):
    return [math.tanh(v * 1.2) / math.tanh(1.2) for v in samples]


def write(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = array.array('h', (int(max(-1.0, min(1.0, v)) * 32767) for v in samples))
    with wave.open(str(path), 'wb') as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    peak = max(abs(v) for v in samples)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples))
    return peak, rms


def note(semitones_from_a4):
    return 440.0 * 2 ** (semitones_from_a4 / 12.0)


# ---- sound effects -----------------------------------------------------------------------

def sfx(name, rng, k):
    """k: variant index (0..n-1); variations come from rng and small pitch offsets."""
    p = 1.0 + (k - 1) * 0.06 + rng.uniform(-0.02, 0.02)
    out = buf(0.05)
    if name == 'swipe':
        out = noise(0.11, rng, 0.004, 0.035, 0.9, lp=6000 * p, hp=900, lp_end=2200)
    elif name == 'claw_hit':
        out = buf(0.07)
        add(out, noise(0.012, rng, 0.0005, 0.004, 1.0, hp=1500))
        add(out, tone(0.07, 950 * p, 520 * p, 'tri', 0.001, 0.02, 0.8))
    elif name == 'pop':
        out = buf(0.09)
        add(out, tone(0.09, 760 * p, 300 * p, 'sine', 0.001, 0.025, 1.0, fm=1.6, fm_ratio=1.5))
        add(out, noise(0.01, rng, 0.0005, 0.003, 0.5, hp=2000))
    elif name == 'pop_big':
        out = buf(0.22)
        add(out, tone(0.22, 420 * p, 150 * p, 'sine', 0.001, 0.06, 1.0, fm=2.0, fm_ratio=1.4))
        add(out, tone(0.2, 70, 45, 'sine', 0.002, 0.07, 0.9))
        add(out, noise(0.08, rng, 0.0005, 0.02, 0.5, lp=3000))
    elif name in ('prey', 'elite_down', 'boss_down', 'level', 'net', 'ready', 'heal', 'evolve', 'combo'):
        recipes = {
            'prey': ([0, 4, 7, 12], 0.06, 0.45, 0.5),
            'elite_down': ([0, 3, 7, 10, 12, 15], 0.05, 0.75, 0.9),
            'boss_down': ([0, 7, 12, 16, 19, 24], 0.08, 1.4, 1.0),
            'level': ([0, 4, 7, 12, 16], 0.05, 0.5, 0.0),
            'net': ([0, 5, 7, 12, 17, 19, 24], 0.045, 0.6, 0.3),
            'ready': ([7, 12, 19], 0.06, 0.4, 0.0),
            'heal': ([0, 7], 0.07, 0.3, 0.0),
            'evolve': ([0, 4, 7, 11, 14, 19, 23, 26], 0.07, 1.2, 0.4),
            'combo': ([0, 7, 12], 0.04, 0.3, 0.0),
        }
        steps, spacing, length, thump = recipes[name]
        base = {'prey': 3, 'elite_down': -2, 'boss_down': -9, 'level': 3, 'net': 0, 'ready': 10, 'heal': 7, 'evolve': -2, 'combo': 8}[name]
        out = buf(length + spacing * len(steps) + 0.1)
        for i, s in enumerate(steps):
            f = note(base + s)
            add(out, tone(length, f, f, 'tri', 0.003, length * 0.35, 0.55), i * spacing)
            add(out, tone(length * 0.6, f * 2, f * 2, 'sine', 0.002, length * 0.2, 0.2), i * spacing)
        if thump:
            add(out, tone(0.35, 90, 40, 'sine', 0.002, 0.12, thump))
            add(out, noise(0.25, rng, 0.001, 0.08, thump * 0.4, lp=2500))
        add(out, noise(length, rng, 0.01, length * 0.3, 0.06, hp=6000), spacing)
    elif name == 'whoosh':
        out = noise(0.2, rng, 0.03, 0.06, 1.0, lp=900 * p, lp_end=5200 * p, hp=300)
    elif name == 'slash':
        out = buf(0.09)
        add(out, noise(0.03, rng, 0.0005, 0.01, 0.8, hp=3000))
        add(out, tone(0.09, 2100 * p, 1900 * p, 'sine', 0.001, 0.02, 0.35))
        add(out, tone(0.09, 2780 * p, 2650 * p, 'sine', 0.001, 0.018, 0.25))
    elif name == 'pierce':
        out = buf(0.25)
        for i, f in enumerate((1568, 2093, 2637)):
            add(out, tone(0.18, f, f, 'sine', 0.001, 0.05, 0.4), i * 0.03)
        add(out, noise(0.12, rng, 0.001, 0.03, 0.4, hp=4000))
    elif name == 'land':
        out = buf(0.2)
        add(out, tone(0.18, 120 * p, 48, 'sine', 0.001, 0.05, 1.0))
        add(out, noise(0.15, rng, 0.002, 0.04, 0.5, lp=900))
    elif name == 'escape':
        out = buf(0.3)
        add(out, noise(0.25, rng, 0.02, 0.07, 0.8, lp=1500, lp_end=7000, hp=400))
        add(out, tone(0.2, 900, 1800, 'sine', 0.002, 0.06, 0.25), 0.05)
    elif name == 'bite':
        out = buf(0.16)
        for i in range(3):
            add(out, noise(0.03, rng, 0.0005, 0.008, 0.8, lp=2600 * p), i * 0.018)
        add(out, tone(0.14, 140 * p, 70, 'sine', 0.001, 0.045, 0.9))
    elif name == 'bite_prey':
        out = sfx('bite', rng, k)
        out = out + [0.0] * int(0.2 * RATE)
        add(out, tone(0.3, 1250, 1240, 'sine', 0.001, 0.09, 0.35, fm=3.0, fm_ratio=2.76), 0.01)
    elif name == 'mark':
        out = tone(0.4, 880, 880, 'sine', 0.001, 0.12, 0.8, fm=2.5, fm_ratio=3.5)
    elif name == 'cash':
        out = buf(0.5)
        add(out, tone(0.45, 660, 660, 'sine', 0.001, 0.14, 0.6, fm=3.0, fm_ratio=2.76))
        add(out, tone(0.25, 110, 50, 'sine', 0.001, 0.08, 1.0))
        add(out, noise(0.4, rng, 0.01, 0.12, 0.15, hp=5000), 0.02)
    elif name == 'execute':
        out = buf(0.4)
        add(out, noise(0.2, rng, 0.08, 0.02, 0.6, lp=600, lp_end=6000))
        add(out, tone(0.25, 100, 40, 'sine', 0.001, 0.08, 1.0), 0.16)
        add(out, noise(0.15, rng, 0.0005, 0.04, 0.7, lp=3000), 0.16)
    elif name == 'hurt':
        out = buf(0.25)
        add(out, tone(0.22, 240 * p, 110 * p, 'square', 0.001, 0.07, 0.7))
        add(out, noise(0.12, rng, 0.0005, 0.03, 0.6, lp=2000))
    elif name == 'ult':
        out = buf(0.9)
        add(out, tone(0.8, 55, 38, 'sine', 0.002, 0.3, 1.0))
        add(out, tone(0.6, 180, 720, 'saw', 0.05, 0.25, 0.35))
        add(out, noise(0.7, rng, 0.02, 0.25, 0.5, lp=500, lp_end=6000))
    elif name == 'ult_end':
        out = tone(0.35, 600, 300, 'tri', 0.01, 0.12, 0.6)
    elif name == 'wave':
        out = buf(0.25)
        add(out, tone(0.2, 160 * p, 60, 'sine', 0.001, 0.06, 0.8))
        add(out, noise(0.2, rng, 0.005, 0.06, 0.5, lp=3000, hp=200))
    elif name == 'shadow':
        out = noise(0.12, rng, 0.006, 0.04, 0.8, lp=9000 * p, hp=2500)
    elif name == 'burst':
        out = buf(0.15)
        for i in range(4):
            add(out, noise(0.02, rng, 0.0005, 0.006, 0.6, hp=1800), i * 0.025)
    elif name in ('refund', 'charge'):
        f = 1046 if name == 'refund' else 784
        out = tone(0.12, f, f * 1.5, 'sine', 0.002, 0.04, 0.7)
    elif name == 'pickup':
        out = tone(0.05, 1320, 1500, 'sine', 0.001, 0.015, 0.8)
    elif name == 'warn_small':
        out = tone(0.05, 620, 620, 'square', 0.002, 0.015, 0.4)
    elif name == 'warn':
        out = buf(0.18)
        add(out, tone(0.07, 700, 700, 'square', 0.002, 0.03, 0.5))
        add(out, tone(0.07, 930, 930, 'square', 0.002, 0.03, 0.5), 0.08)
    elif name == 'warn_big':
        out = buf(0.45)
        add(out, tone(0.4, 147, 140, 'saw', 0.02, 0.18, 0.7, vibrato=0.01))
        add(out, tone(0.4, 220, 210, 'square', 0.02, 0.18, 0.3))
    elif name == 'strike':
        out = noise(0.08, rng, 0.0005, 0.025, 0.9, lp=1800 * p)
    elif name == 'spawn':
        n = noise(0.25, rng, 0.2, 0.02, 0.6, lp=600, lp_end=3000)
        out = n
    elif name == 'boss_phase':
        out = buf(0.9)
        add(out, noise(0.8, rng, 0.05, 0.3, 0.8, lp=400, lp_end=1500))
        add(out, tone(0.8, 110, 70, 'saw', 0.03, 0.3, 0.6, vibrato=0.03))
        add(out, tone(0.6, 50, 35, 'sine', 0.01, 0.25, 1.0))
    elif name == 'combo_break':
        out = buf(0.3)
        add(out, noise(0.05, rng, 0.0005, 0.02, 0.8, hp=5000))
        add(out, tone(0.25, 1800, 700, 'tri', 0.001, 0.08, 0.4), 0.01)
    elif name == 'click':
        out = buf(0.04)
        add(out, noise(0.006, rng, 0.0003, 0.002, 0.7, hp=3000))
        add(out, tone(0.03, 1400, 1100, 'sine', 0.001, 0.008, 0.5))
    elif name == 'card':
        out = noise(0.07, rng, 0.004, 0.02, 0.8, lp=5000, hp=800)
    elif name == 'chest':
        out = buf(0.7)
        add(out, tone(0.2, 130, 70, 'sine', 0.001, 0.06, 1.0))
        add(out, noise(0.08, rng, 0.0005, 0.02, 0.6, lp=1500))
        for i, s in enumerate((12, 16, 19, 24)):
            f = note(s)
            add(out, tone(0.35, f, f, 'sine', 0.002, 0.1, 0.35), 0.12 + i * 0.05)
    elif name == 'tick':
        out = tone(0.02, 1800, 1800, 'sine', 0.0005, 0.005, 0.6)
    elif name == 'step':
        out = buf(0.08)
        add(out, tone(0.07, 200 * p, 120, 'sine', 0.001, 0.02, 0.6))
        add(out, noise(0.03, rng, 0.0005, 0.01, 0.3, lp=1200))
    elif name == 'wipe':
        out = noise(0.3, rng, 0.05, 0.08, 0.9, lp=1200, lp_end=8000, hp=300)
    elif name == 'heartbeat':
        out = buf(0.5)
        add(out, tone(0.12, 70, 45, 'sine', 0.002, 0.04, 1.0))
        add(out, tone(0.1, 60, 40, 'sine', 0.002, 0.035, 0.7), 0.2)
    return normalize(soft_clip(out))


# ---- music ---------------------------------------------------------------------------------

REGIONS = {
    'courtyard': {'root': -12, 'scale': [0, 3, 5, 7, 10], 'chords': [0, 8, 3, 10], 'seed': 11, 'lead': 'tri'},
    'greenhouse': {'root': -7, 'scale': [0, 2, 3, 7, 9], 'chords': [0, 5, 10, 3], 'seed': 23, 'lead': 'sine'},
    'belltower': {'root': -5, 'scale': [0, 3, 5, 7, 10], 'chords': [0, 3, 8, 7], 'seed': 37, 'lead': 'square'},
}
BPM = 100
BEAT = 60.0 / BPM
BARS = 8
LOOP = BARS * 4 * BEAT


def chord_tones(root, quality_minor=True):
    third = 3 if quality_minor else 4
    return [root, root + third, root + 7]


def music_layer(region, layer):
    cfg = REGIONS[region]
    rng = random.Random(cfg['seed'] * 10 + len(layer))
    out = buf(LOOP)
    root = cfg['root']
    if layer == 'ambient':
        for bar in range(BARS):
            c = cfg['chords'][(bar // 2) % 4]
            minor = c in (0, 5, 7)
            for s in chord_tones(root + c, minor):
                f = note(s - 12)
                add(out, tone(BEAT * 4.2, f, f, 'tri', 0.6, 2.5, 0.22, vibrato=0.004), bar * 4 * BEAT, wrap=True)
                add(out, tone(BEAT * 4.2, f * 2.003, f * 2.003, 'sine', 0.8, 2.0, 0.07), bar * 4 * BEAT, wrap=True)
        add(out, noise(LOOP, rng, 2.0, LOOP, 0.035, lp=700, hp=150), 0.0, wrap=True)
        for i in range(int(LOOP * 2)):
            if rng.random() < 0.35:
                f = rng.choice([4200, 4600, 5100])
                add(out, tone(0.05, f, f, 'sine', 0.002, 0.012, 0.05), i * 0.5 + rng.uniform(0, 0.4), wrap=True)
    elif layer == 'drums':
        for b in range(BARS * 4):
            t = b * BEAT
            if b % 2 == 0:
                add(out, tone(0.3, 110, 42, 'sine', 0.002, 0.08, 1.0), t, wrap=True)
            if b % 4 == 2:
                add(out, tone(0.25, 110, 42, 'sine', 0.002, 0.07, 0.6), t + BEAT * 0.5, wrap=True)
            if b % 2 == 1:
                add(out, noise(0.18, rng, 0.001, 0.05, 0.45, lp=4500, hp=500), t, wrap=True)
                add(out, tone(0.12, 220, 180, 'tri', 0.001, 0.04, 0.25), t, wrap=True)
            for h in range(2):
                gain = 0.18 if h == 0 else 0.11
                add(out, noise(0.04, rng, 0.0005, 0.01, gain, hp=7000), t + h * BEAT * 0.5, wrap=True)
            if rng.random() < 0.25:
                add(out, noise(0.03, rng, 0.0005, 0.008, 0.08, hp=7000), t + BEAT * 0.75, wrap=True)
    elif layer == 'lead':
        scale = cfg['scale']
        motif = [rng.choice(range(len(scale))) for _ in range(8)]
        for bar in range(BARS):
            c = cfg['chords'][(bar // 2) % 4]
            for step in range(8):
                if (bar + step) % 3 == 2 and rng.random() < 0.5:
                    continue
                degree = (motif[step] + (bar % 2) * 2) % len(scale)
                s = root + 12 + c % 12 * 0 + scale[degree] + (12 if step % 4 == 3 else 0)
                f = note(s)
                add(out, tone(BEAT * 0.9, f, f, cfg['lead'], 0.004, BEAT * 0.35, 0.3, vibrato=0.003), (bar * 8 + step) * BEAT * 0.5, wrap=True)
                add(out, tone(BEAT * 0.9, f * 0.5, f * 0.5, 'sine', 0.004, BEAT * 0.3, 0.08), (bar * 8 + step) * BEAT * 0.5 + 0.02, wrap=True)
    elif layer == 'boss':
        for bar in range(BARS):
            c = cfg['chords'][(bar // 2) % 4]
            for step in range(8):
                f = note(root + c - 24 + (7 if step in (3, 7) else 0))
                add(out, tone(BEAT * 0.45, f, f, 'saw', 0.003, BEAT * 0.18, 0.5), (bar * 8 + step) * BEAT * 0.5, wrap=True)
            for step in range(16):
                if step % 4 in (0, 3) or rng.random() < 0.3:
                    add(out, tone(0.2, 160, 75, 'sine', 0.001, 0.06, 0.55 if step % 4 == 0 else 0.3), (bar * 16 + step) * BEAT * 0.25, wrap=True)
    return out


def stinger(name, rng):
    if name == 'net':
        steps, spacing, length = [0, 4, 7, 12, 16, 19], 0.07, 1.2
    elif name == 'level':
        steps, spacing, length = [0, 7, 12, 16], 0.06, 0.8
    elif name == 'win':
        steps, spacing, length = [0, 4, 7, 12, 7, 12, 16, 19, 24], 0.14, 2.6
    else:
        steps, spacing, length = [12, 10, 7, 3, 0], 0.22, 2.2
    out = buf(length + spacing * len(steps))
    for i, s in enumerate(steps):
        f = note(s - 9)
        add(out, tone(length * 0.7, f, f, 'tri', 0.004, length * 0.25, 0.5), i * spacing)
        add(out, tone(length * 0.6, f * 1.5, f * 1.5, 'sine', 0.01, length * 0.2, 0.12), i * spacing)
    if name == 'win':
        add(out, tone(1.5, 55, 50, 'sine', 0.01, 0.6, 0.7))
    return out


LAYER_RMS = {'ambient': 0.07, 'drums': 0.09, 'lead': 0.07, 'boss': 0.09}


def level_to(samples, target_rms):
    rms = math.sqrt(sum(v * v for v in samples) / len(samples)) or 1e-9
    gain = target_rms / rms
    out = [v * gain for v in samples]
    peak = max(abs(v) for v in out)
    if peak > 0.95:
        out = [v * 0.95 / peak for v in out]
    return out


def main():
    feel = json.loads((PROJECT / 'game/data/x1/feel.json').read_text(encoding='utf-8'))
    report = []
    for name, spec in feel['sounds'].items():
        for k in range(int(spec.get('variants', 1))):
            rng = random.Random(sum(map(ord, name)) * 31 + k)
            samples = sfx(name, rng, k)
            peak, rms = write(OUT / 'sfx' / ('%s_%d.wav' % (name, k + 1)), samples)
            report.append(('sfx/%s_%d' % (name, k + 1), len(samples) / RATE, peak, rms))
    for region in REGIONS:
        for layer in ('ambient', 'drums', 'lead', 'boss'):
            samples = level_to(music_layer(region, layer), LAYER_RMS[layer])
            peak, rms = write(OUT / 'music' / ('%s_%s.wav' % (region, layer)), samples)
            report.append(('music/%s_%s' % (region, layer), len(samples) / RATE, peak, rms))
    for name in feel.get('stingers', []):
        samples = normalize(stinger(name, random.Random(sum(map(ord, name)))), 0.85)
        peak, rms = write(OUT / 'music' / ('stinger_%s.wav' % name), samples)
        report.append(('music/stinger_%s' % name, len(samples) / RATE, peak, rms))
    for path, seconds, peak, rms in report:
        db = 20 * math.log10(max(rms, 1e-9))
        print('%-34s %5.2fs  peak %.2f  rms %6.1f dBFS%s' % (path, seconds, peak, db, '  CLIP' if peak > 0.99 else ''))
    print('files:', len(report), ' loop length: %.3fs' % LOOP)


if __name__ == '__main__':
    main()
