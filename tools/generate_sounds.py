"""Generate the app's WAV sounds using only the standard library.

    python tools/generate_sounds.py

Writes into app/assets/sounds/. Output is deterministic; the WAVs are committed.
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "app" / "assets" / "sounds"

# C major pentatonic, C5 upward: the step "pop" climbs this scale within a task.
PENTA = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51]


def env(t: float, dur: float, attack: float, decay: float) -> float:
    """Attack ramp then exponential decay, with a short fade at the very end."""
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = math.exp(-t / decay)
    tail = min(1.0, (dur - t) / 0.01) if dur - t < 0.01 else 1.0
    return a * d * max(0.0, tail)


def osc(kind: str, phase: float) -> float:
    if kind == "sine":
        return math.sin(phase)
    if kind == "tri":
        x = (phase / (2 * math.pi)) % 1.0
        return 4 * abs(x - 0.5) - 1
    raise ValueError(kind)


def tone(freq: float, dur: float, kind="sine", attack=0.004, decay=0.08,
         glide=0.0, harmonics=((1, 1.0),), start=0.0, total=None) -> list[float]:
    total = total or (start + dur)
    out = [0.0] * int(total * RATE)
    phase = [0.0] * len(harmonics)
    for i in range(int(dur * RATE)):
        t = i / RATE
        f = freq * (1 + glide * math.exp(-t / 0.02))  # quick pitch drop = "pop"
        e = env(t, dur, attack, decay)
        s = 0.0
        for h, (mult, amp) in enumerate(harmonics):
            phase[h] += 2 * math.pi * f * mult / RATE
            s += amp * osc(kind, phase[h])
        j = int(start * RATE) + i
        if j < len(out):
            out[j] += e * s
    return out


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, v in enumerate(tr):
            out[i] += v
    return out


def write(name: str, samples: list[float], peak: float = 0.7) -> None:
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767))
                               for s in samples))


def step_pops() -> None:
    variants = {
        0: dict(kind="sine", decay=0.05, glide=0.35, harmonics=((1, 1.0), (2, 0.15))),
        1: dict(kind="tri", decay=0.06, glide=0.2, harmonics=((1, 1.0),)),
        2: dict(kind="sine", decay=0.09, glide=0.0, harmonics=((1, 1.0), (2.76, 0.25), (5.4, 0.08))),
        3: dict(kind="sine", decay=0.045, glide=0.5, harmonics=((1, 1.0), (1.5, 0.2))),
    }
    for v, params in variants.items():
        for deg, f in enumerate(PENTA):
            write(f"pop_{v}_{deg}", tone(f, 0.22, **params), peak=0.55)


def arp(freqs, gap, dur, **kw):
    return mix(*(tone(f, dur, start=i * gap, total=gap * len(freqs) + dur, **kw)
                 for i, f in enumerate(freqs)))


def chords() -> None:
    bell = ((1, 1.0), (2, 0.3), (3, 0.12))
    write("chord_0", arp([523.25, 659.25, 783.99, 1046.50], 0.05, 0.7,
                         decay=0.28, harmonics=bell))
    write("chord_1", arp([587.33, 739.99, 880.00, 1174.66], 0.045, 0.7,
                         kind="tri", decay=0.25))
    write("chord_2", arp([392.00, 523.25, 659.25, 783.99, 1046.50], 0.04, 0.75,
                         decay=0.3, harmonics=((1, 1.0), (2.0, 0.2), (4.0, 0.06))))
    # First task of the day: a fuller chord plus a sparkle on top.
    write("chord_big", mix(
        arp([523.25, 659.25, 783.99, 1046.50, 1318.51], 0.06, 0.9, decay=0.35, harmonics=bell),
        tone(2093.0, 0.5, start=0.35, total=1.25, decay=0.12, harmonics=((1, 0.35),)),
        tone(2637.0, 0.5, start=0.42, total=1.25, decay=0.12, harmonics=((1, 0.25),)),
    ))


def chime() -> None:
    bell = ((1, 1.0), (2.0, 0.25), (3.01, 0.08))
    write("chime", mix(tone(783.99, 1.2, decay=0.45, harmonics=bell, total=1.6),
                       tone(1046.50, 1.2, start=0.18, decay=0.5, harmonics=bell, total=1.6)),
          peak=0.45)


def day_complete() -> None:
    """~1.9 s rising arpeggio that resolves: deliberately unlike the task chord."""
    rise = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50]
    parts = [tone(f, 0.35, start=i * 0.09, total=2.0, decay=0.16, kind="tri")
             for i, f in enumerate(rise)]
    chord_start = len(rise) * 0.09 + 0.05
    for f, a in ((523.25, 1.0), (659.25, 0.8), (783.99, 0.8), (1046.50, 0.7), (261.63, 0.6)):
        parts.append([a * x for x in tone(f, 2.0 - chord_start, start=chord_start, total=2.0,
                                          attack=0.01, decay=0.55,
                                          harmonics=((1, 1.0), (2, 0.25), (3, 0.1)))])
    for i, f in enumerate((2093.0, 2349.3, 2637.0, 3136.0)):
        parts.append(tone(f, 0.3, start=chord_start + 0.1 + i * 0.07, total=2.0, decay=0.08,
                          harmonics=((1, 0.25),)))
    write("day_complete", mix(*parts), peak=0.7)


if __name__ == "__main__":
    step_pops()
    chords()
    chime()
    day_complete()
    print(f"wrote {len(list(OUT.glob('*.wav')))} files to {OUT}")
