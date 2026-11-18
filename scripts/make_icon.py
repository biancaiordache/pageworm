#!/usr/bin/env python3
"""Draw a simple Inky app icon as a 1024 PNG. No third-party libraries."""

import struct
import zlib
from pathlib import Path


def pixel(x, y):
    # Cream paper.
    r, g, b = 250, 242, 230
    cx, cy = 512, 560

    def circle(px, py, radius, color):
        return (x - px) ** 2 + (y - py) ** 2 <= radius ** 2, color

    blobs = [
        (390, 690, 150, (84, 122, 97)),
        (530, 640, 165, (84, 122, 97)),
        (680, 560, 190, (140, 168, 128)),
    ]
    for px, py, radius, color in blobs:
        if (x - px) ** 2 + (y - py) ** 2 <= radius ** 2:
            r, g, b = color
    # Belly on the head.
    if (x - 680) ** 2 / (120 ** 2) + (y - 590) ** 2 / (80 ** 2) <= 1:
        r, g, b = 219, 232, 199
    # Cheeks.
    for px in (610, 750):
        if (x - px) ** 2 / (36 ** 2) + (y - 600) ** 2 / (22 ** 2) <= 1:
            r, g, b = 230, 153, 138
    # Eyes.
    for px in (640, 730):
        if (x - px) ** 2 + (y - 540) ** 2 <= 22 ** 2:
            r, g, b = 56, 41, 33
        if (x - (px - 6)) ** 2 + (y - 532) ** 2 <= 6 ** 2:
            r, g, b = 255, 255, 255
    # Smile.
    if 640 <= x <= 730 and 575 <= y <= 590:
        curve = 582 + int(((x - 685) ** 2) / 900)
        if abs(y - curve) <= 4:
            r, g, b = 56, 41, 33
    # Sprout.
    if 668 <= x <= 692 and 330 <= y <= 400:
        r, g, b = 84, 122, 97
    if (x - 720) ** 2 / (50 ** 2) + (y - 350) ** 2 / (28 ** 2) <= 1:
        r, g, b = 140, 168, 128
    # Soft corner vignette so the icon reads on a home screen.
    edge = min(x, y, 1023 - x, 1023 - y)
    if edge < 36:
        fade = edge / 36
        r = int(r * fade + 245 * (1 - fade))
        g = int(g * fade + 236 * (1 - fade))
        b = int(b * fade + 224 * (1 - fade))
    return bytes((r, g, b, 255))


def write_png(path, size=1024):
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            raw.extend(pixel(x, y))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    write_png(destination)
    print(destination, destination.stat().st_size)
