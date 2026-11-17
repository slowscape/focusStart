"""Generate particle shapes and the app icon as PNGs (stdlib only: zlib, struct).

    python tools/generate_images.py
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "app" / "assets" / "images"


def png(path: Path, w: int, h: int, pixel) -> None:
    """pixel(x, y) -> (r, g, b, a) floats 0..1; 4x4 supersampled for anti-aliasing."""
    rows = []
    ss = 4
    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(ss):
                for sx in range(ss):
                    r, g, b, a = pixel(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss)
                    acc[0] += r * a; acc[1] += g * a; acc[2] += b * a; acc[3] += a
            n = ss * ss
            a = acc[3] / n
            if a > 0:
                rgb = [acc[i] / acc[3] for i in range(3)]
            else:
                rgb = [0, 0, 0]
            row += bytes(int(max(0, min(1, c)) * 255 + 0.5) for c in (*rgb, a))
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", raw) + chunk(b"IEND", b""))


WHITE = (1, 1, 1)


def shape(fn):
    return lambda x, y: (*WHITE, 1.0 if fn(x, y) else 0.0)


def star(x, y, cx=16, cy=16, R=15, r=6.5):
    ang = math.atan2(y - cy, x - cx)
    d = math.hypot(x - cx, y - cy)
    k = (ang + math.pi / 2) % (2 * math.pi / 5) / (2 * math.pi / 5)
    lim = r + (R - r) * abs(1 - 2 * k)
    return d <= lim


def point_in_tri(px, py, a, b, c):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = s((px, py), a, b), s((px, py), b, c), s((px, py), c, a)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def icon(x, y, S=256):
    """The My Day progress ring: 3 segments (tasks), 2 done in green, on a dark disc."""
    cx = cy = S / 2
    d = math.hypot(x - cx, y - cy)
    if d > S * 0.48:
        return (0, 0, 0, 0)
    bg = (0.17, 0.17, 0.17, 1)
    r, w = S * 0.30, S * 0.05           # ring radius and half-thickness
    if abs(d - r) > w:
        return bg
    # Angle measured clockwise from 12 o'clock, like StepRing.qml.
    ang = (math.atan2(y - cy, x - cx) + math.pi / 2) % (2 * math.pi)
    seg = 2 * math.pi / 3
    gap = 0.30
    i, off = int(ang // seg), ang % seg
    if off < gap / 2 or off > seg - gap / 2:
        return bg
    return (0.42, 0.80, 0.37, 1) if i < 2 else (0.45, 0.45, 0.45, 1)


if __name__ == "__main__":
    png(OUT / "p_rect.png", 32, 32, shape(lambda x, y: 6 <= x <= 26 and 11 <= y <= 21))
    png(OUT / "p_strip.png", 32, 32, shape(lambda x, y: 2 <= x <= 30 and 13 <= y <= 19))
    png(OUT / "p_circle.png", 32, 32, shape(lambda x, y: math.hypot(x - 16, y - 16) <= 13))
    png(OUT / "p_tri.png", 32, 32, shape(lambda x, y: point_in_tri(x, y, (16, 3), (29, 28), (3, 28))))
    png(OUT / "p_star.png", 32, 32, shape(star))
    png(OUT / "p_dot.png", 16, 16, lambda x, y: (*WHITE, max(0.0, 1 - math.hypot(x - 8, y - 8) / 8) ** 1.5))
    png(OUT / "icon.png", 256, 256, icon)
    print("wrote", sorted(p.name for p in OUT.glob("*.png")))
