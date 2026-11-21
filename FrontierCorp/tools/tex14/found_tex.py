"""1.4: фундаменты были белыми плитами. Перекрашиваем их текстуры (models20/found_*/tex0.png) в рисованный бетон:
тёплый серый, пятна и потёки, светлые сколы по швам, тёмная грязь снизу. Линии, болты и жёлтые полосы остаются.
Исходники сохраняются в tools/tex14/found_src/ (повторный запуск берёт их, а не уже перекрашенные).

    python3 tools/tex14/found_tex.py"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ground_tex import pnoise, blur, hexc  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "found_src")
IDS = ["found_1x1", "found_2x2", "found_tall", "found_wall", "found_ramp", "found_ramp2"]


def concrete(n, seed):
    b = pnoise(n, 6, seed, 3)
    c = hexc("#7d7a73") * (1 - b[..., None]) + hexc("#9a958b") * b[..., None]
    # пятна и потёки
    stain = np.clip((pnoise(n, 14, seed + 1, 2) - 0.55) * 4, 0, 1)
    c = c * (1 - 0.18 * stain[..., None]) + hexc("#6b5d4a") * 0.18 * stain[..., None]
    streak = pnoise(n, 3, seed + 2, 1)
    ys = np.linspace(0, 1, n)[:, None]
    drip = np.clip((np.sin((np.arange(n)[None, :] / n) * 90 + streak * 20) - 0.6) * 2, 0, 1) * 0.08
    c = c * (1 - drip[..., None])
    # мелкие поры и сколы
    pores = (pnoise(n, 160, seed + 3) < 0.22) * 0.12
    c = c * (1 - pores[..., None])
    chips = np.clip((pnoise(n, 40, seed + 4) - 0.75) * 6, 0, 1)
    c = c + chips[..., None] * 0.08
    return np.clip(c, 0, 1)


def main():
    os.makedirs(SRC, exist_ok=True)
    for i, mid in enumerate(IDS):
        dst = os.path.join(ROOT, "models20", mid, "tex0.png")
        if not os.path.exists(dst):
            continue
        src = os.path.join(SRC, mid + ".png")
        if not os.path.exists(src):
            shutil.copy(dst, src)
        a = np.asarray(Image.open(src).convert("RGB")) / 255.0
        n = a.shape[0]
        lum = a @ np.array([0.3, 0.59, 0.11])
        sat = a.max(-1) - a.min(-1)
        neutral = np.clip((0.16 - sat) / 0.08, 0, 1)
        bright = np.clip((lum - 0.4) / 0.25, 0, 1)
        k = neutral * bright
        con = concrete(n, 70 + i)
        # светлое — бетон (оттенок сохраняет рисунок исходника: швы, тени, болты)
        shade = np.clip(lum / 0.82, 0.55, 1.15)
        newc = con * shade[..., None]
        # у тёмных линий и швов — светлый скол краёв
        edge = np.clip(blur((lum < 0.3).astype(float), 1.5) * 3 - (lum < 0.3), 0, 1) * k
        newc = newc + edge[..., None] * 0.1
        out = a * (1 - k[..., None]) + newc * k[..., None]
        # цветные полосы — чуть потёртые
        wear = np.clip((pnoise(n, 30, 90 + i) - 0.6) * 4, 0, 1) * (sat > 0.25)
        out = out * (1 - 0.25 * wear[..., None]) + con * 0.25 * wear[..., None]
        Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(dst)
        print("painted", mid)


if __name__ == "__main__":
    main()
