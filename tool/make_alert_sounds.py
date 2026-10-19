#!/usr/bin/env python3
"""Makes the short alert sounds in android/app/src/main/res/raw.

Everything is built from sine waves with plain Python, so there is nothing to
download and the sounds belong to the app. Run it again after changing a
sound:  python3 tool/make_alert_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src',
                   'main', 'res', 'raw')


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*parts):
    """Lays sounds on top of each other, each as (start_seconds, samples)."""
    length = max(int(RATE * start) + len(s) for start, s in parts)
    out = [0.0] * length
    for start, samples in parts:
        offset = int(RATE * start)
        for i, value in enumerate(samples):
            out[offset + i] += value
    return out


def voice(freq, seconds, harmonics, attack=0.01, decay=6.0, vibrato=0.0,
          vibrato_hz=6.0, glide=0.0):
    """A note: [(harmonic_number, strength)], a quick attack, then a fade.
    `glide` multiplies the pitch by (1 + glide) by the end of the note."""
    n = int(RATE * seconds)
    phase = [0.0] * len(harmonics)
    out = []
    for i in range(n):
        t = i / RATE
        f = freq * (1 + glide * i / n)
        f *= 1 + vibrato * math.sin(2 * math.pi * vibrato_hz * t)
        amp = min(1.0, t / attack) * math.exp(-decay * t)
        sample = 0.0
        for k, (number, strength) in enumerate(harmonics):
            phase[k] += 2 * math.pi * f * number / RATE
            sample += strength * math.sin(phase[k])
        out.append(sample * amp)
    return out


def bell(freq, seconds, decay=5.0):
    """A struck metal sound: partials that are not whole multiples."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        sample = 0.0
        for ratio, strength, fade in (
            (1.0, 1.0, 1.0), (2.76, 0.6, 1.6), (5.4, 0.35, 2.4),
            (8.93, 0.18, 3.2),
        ):
            sample += strength * math.sin(2 * math.pi * freq * ratio * t) \
                * math.exp(-decay * fade * t)
        out.append(sample * min(1.0, t / 0.002))
    return out


def save(name, samples, peak=0.85):
    top = max(abs(s) for s in samples) or 1.0
    scale = peak / top
    fade = int(RATE * 0.02)
    data = []
    for i, s in enumerate(samples):
        gain = scale
        if i > len(samples) - fade:
            gain *= (len(samples) - i) / fade
        data.append(int(max(-1, min(1, s * gain)) * 32767))
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack('<%dh' % len(data), *data))
    print('%-14s %.2fs %d bytes' % (name, len(samples) / RATE,
                                    os.path.getsize(path)))


REED = [(n, 1 / n ** 0.8) for n in range(1, 9)]
BRASS = [(n, 1 / n ** 1.2) for n in range(1, 10)]

# A rickshaw's rubber horn: "pyan, pyan".
honk1 = voice(392, 0.22, REED, attack=0.012, decay=5, glide=-0.12)
honk2 = voice(349, 0.30, REED, attack=0.012, decay=4, glide=-0.15)
save('alert_horn', mix((0.0, honk1), (0.27, honk2)))

# "Boing": a spring that bounces away.
boing = voice(210, 0.9, [(1, 1.0), (2, 0.35), (3, 0.15)], attack=0.004,
              decay=3.2, vibrato=0.14, vibrato_hz=17, glide=0.9)
save('alert_boing', boing)

# "Ka-ching": the till opens, then the coin drops.
rng = random.Random(7)
click = [rng.uniform(-1, 1) * math.exp(-60 * i / RATE) * 0.5
         for i in range(int(RATE * 0.04))]
save('alert_coin', mix((0.0, click), (0.0, bell(1318, 0.5, 6)),
                       (0.13, bell(1975, 0.7, 5))))

# "Uh-oh": two notes falling.
save('alert_uhoh', mix(
    (0.0, voice(494, 0.22, [(1, 1), (2, .3)], decay=4, glide=-0.04)),
    (0.26, voice(370, 0.4, [(1, 1), (2, .3)], decay=4, glide=-0.06)),
))

# The sad trombone: wah, wah, wah, waaah.
notes = [(233, 0.0, 0.3, -0.02), (220, 0.34, 0.3, -0.02),
         (208, 0.68, 0.3, -0.02), (196, 1.02, 0.9, -0.28)]
save('alert_wah', mix(*[
    (start, voice(f, length, BRASS, attack=0.05, decay=1.6,
                  vibrato=0.025 if length > 0.5 else 0, glide=g))
    for f, start, length, g in notes
]))

# "Ta-da!": three quick notes, then the chord.
chord = [voice(f, 0.7, [(1, 1), (2, .5), (3, .25)], decay=3)
         for f in (523, 659, 784, 1047)]
save('alert_tada', mix(
    (0.0, voice(523, 0.12, [(1, 1), (2, .4)], decay=2)),
    (0.1, voice(659, 0.12, [(1, 1), (2, .4)], decay=2)),
    (0.2, voice(784, 0.12, [(1, 1), (2, .4)], decay=2)),
    *[(0.32, c) for c in chord],
))

# A soft, calm bell for zakat day: no jokes there.
save('alert_chime', mix((0.0, bell(523, 1.3, 2.2)), (0.45, bell(659, 1.1, 2.2))),
     peak=0.6)
