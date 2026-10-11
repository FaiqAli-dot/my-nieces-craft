#!/usr/bin/env python3
"""Generate CozyBlocks block textures that match the soft flat style of the
existing set (64x64, gentle value noise, no harsh outlines).

Usage: python3 tools/gen_block_textures.py
Writes into assets/textures/blocks/. Deterministic (fixed seeds).
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "blocks")
S = 64


def clamp(v):
    return max(0, min(255, int(v)))


def shade(c, k):
    return tuple(clamp(x * k) for x in c)


def noise_fill(img, base, amount, seed, cell=4):
    rnd = random.Random(seed)
    px = img.load()
    for y in range(0, S, cell):
        for x in range(0, S, cell):
            k = 1.0 + rnd.uniform(-amount, amount)
            col = shade(base, k)
            for yy in range(cell):
                for xx in range(cell):
                    px[x + xx, y + yy] = col + (255,)


def log_side(base, stripe, seed):
    img = Image.new("RGBA", (S, S))
    noise_fill(img, base, 0.05, seed)
    rnd = random.Random(seed + 1)
    d = ImageDraw.Draw(img)
    x = 2
    while x < S:
        w = rnd.choice([2, 2, 3])
        y0 = rnd.randint(-8, 10)
        while y0 < S:
            seg = rnd.randint(10, 22)
            d.rectangle([x, y0, x + w - 1, y0 + seg], fill=stripe + (255,))
            y0 += seg + rnd.randint(4, 10)
        x += w + rnd.randint(4, 7)
    return img


def birch_side(seed):
    img = Image.new("RGBA", (S, S))
    noise_fill(img, (238, 233, 220), 0.03, seed)
    rnd = random.Random(seed + 1)
    d = ImageDraw.Draw(img)
    for _ in range(9):
        y = rnd.randint(0, S - 4)
        x = rnd.randint(-6, S - 10)
        w = rnd.randint(8, 18)
        d.rectangle([x, y, x + w, y + 2], fill=(74, 66, 60, 255))
    for _ in range(6):
        y = rnd.randint(0, S - 3)
        x = rnd.randint(0, S - 6)
        d.rectangle([x, y, x + 4, y + 1], fill=(150, 142, 130, 255))
    return img


def log_top(bark, inner, ring):
    img = Image.new("RGBA", (S, S), bark + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle([5, 5, S - 6, S - 6], fill=inner + (255,))
    c = S / 2 - 0.5
    px = img.load()
    for y in range(6, S - 6):
        for x in range(6, S - 6):
            r = math.hypot(x - c, y - c)
            if int(r) % 7 in (0, 1):
                px[x, y] = ring + (255,)
    return img


def leaf_block(base, dark, light, seed):
    img = Image.new("RGBA", (S, S))
    noise_fill(img, base, 0.06, seed)
    rnd = random.Random(seed + 7)
    d = ImageDraw.Draw(img)
    for _ in range(46):
        x, y = rnd.randint(0, S - 5), rnd.randint(0, S - 5)
        d.rectangle([x, y, x + 3, y + 3], fill=dark + (255,))
    for _ in range(26):
        x, y = rnd.randint(0, S - 4), rnd.randint(0, S - 4)
        d.rectangle([x, y, x + 2, y + 2], fill=light + (255,))
    return img


def plaster(seed):
    img = Image.new("RGBA", (S, S))
    noise_fill(img, (246, 232, 204), 0.025, seed, cell=8)
    d = ImageDraw.Draw(img)
    d.rectangle([0, S - 2, S - 1, S - 1], fill=(226, 208, 176, 255))
    d.rectangle([S - 2, 0, S - 1, S - 1], fill=(232, 216, 186, 255))
    return img


def roof_tile(seed):
    img = Image.new("RGBA", (S, S))
    noise_fill(img, (214, 98, 76), 0.04, seed)
    d = ImageDraw.Draw(img)
    for row in range(4):
        y = row * 16
        d.rectangle([0, y + 13, S - 1, y + 15], fill=(166, 70, 56, 255))
        off = 0 if row % 2 == 0 else 8
        for x in range(off, S + 16, 16):
            d.rectangle([x - 1, y, x, y + 13], fill=(184, 80, 62, 255))
        d.rectangle([0, y, S - 1, y + 1], fill=(232, 128, 104, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    out = {
        "log_side.png": log_side((150, 98, 58), (118, 74, 42), 11),
        "log_top.png": log_top((128, 82, 48), (226, 184, 124), (196, 150, 96)),
        "birch_side.png": birch_side(21),
        "birch_top.png": log_top((228, 222, 208), (232, 204, 150), (206, 176, 124)),
        "pine_leaves.png": leaf_block((46, 124, 86), (32, 96, 66), (78, 156, 108), 31),
        "birch_leaves.png": leaf_block((132, 196, 84), (100, 164, 62), (172, 222, 110), 41),
        "plaster.png": plaster(51),
        "roof_tile.png": roof_tile(61),
    }
    for name, img in out.items():
        img.convert("RGB").save(os.path.join(OUT, name))
        print("wrote", name)


if __name__ == "__main__":
    main()
