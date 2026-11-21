"""1.4: рисованные текстуры земли (свои, без чужих картинок). Стиль — как у печки и у рисованной брусчатки:
крупные формы, мягкий свет сверху-слева, тёмные швы, светлые края, трещинки. Все текстуры бесшовные.
В альфа-канале — высота (по ней земля смешивает слои: трава прорастает между камнями, а не размазывается).

    python3 tools/tex14/ground_tex.py [OUT_DIR] [SIZE]

Пишет grass.png, meadow.png, dirt.png, rock.png, sand.png, gravel.png (RGBA)."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "textures", "ground")
N = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
LIGHT = np.array([-0.55, -0.6, 0.58])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# ------------------------------------------------------------------ бесшовный шум
def pnoise(n, freq, seed, octaves=1):
    """Бесшовный шум 0..1: белый шум, сглаженный в частотах (период = размер текстуры)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        w = rng.standard_normal((n, n))
        k = np.fft.fftfreq(n) * n
        kx, ky = np.meshgrid(k, k)
        f = np.exp(-(kx ** 2 + ky ** 2) / (freq * (2 ** o)) ** 2)
        v = np.real(np.fft.ifft2(np.fft.fft2(w) * f))
        v = (v - v.mean()) / (v.std() + 1e-9)
        out += v * amp
        tot += amp
        amp *= 0.5
    out /= tot
    return np.clip(out * 0.18 + 0.5, 0, 1)


def grad(h):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    return gx, gy


def shade(h, strength):
    """Свет от рельефа h (сверху-слева), 0..1."""
    gx, gy = grad(h)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.clip((nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / ln, 0, 1)


def paint(v, steps=4, k=0.45):
    """Рисованный свет: плавное значение чуть «ступенчатое», как мазки кистью."""
    q = np.floor(v * steps + 0.5) / steps
    return v * (1 - k) + q * k


def blur(a, r):
    """Бесшовное размытие (в частотах)."""
    n = a.shape[0]
    k = np.fft.fftfreq(n) * n
    kx, ky = np.meshgrid(k, k)
    f = np.exp(-(kx ** 2 + ky ** 2) * (r / n * math.pi) ** 2 * 2)
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * f))
    return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * f)) for c in range(a.shape[2])], -1)


# ------------------------------------------------------------------ камни (ячейки Вороного)
def cells(n, count, seed, warp=0.0, warp_freq=6):
    """Бесшовные ячейки: расстояние до ближайшей точки, до второй, номер ближайшей."""
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0, n, (count, 2))
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    if warp > 0:
        xs = xs + (pnoise(n, warp_freq, seed + 1) - 0.5) * warp
        ys = ys + (pnoise(n, warp_freq, seed + 2) - 0.5) * warp
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    idx = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xs - px) % n
        dx = np.minimum(dx, n - dx)
        dy = np.abs(ys - py) % n
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


def stones(n, count, seed, palette, gap_col, bevel=0.35, gap=0.06, warp=0.12, crack=0.35, bulge=0.5, rim=0.25,
           dark=0.55, under=None, relief=0.9):
    """Рисованные камни: округлые, с фаской, тёмным швом, бликом по верхнему краю и трещинками."""
    rng = np.random.default_rng(seed + 100)
    cell = n / math.sqrt(count)
    d1, d2, idx = cells(n, count, seed, warp * cell, warp_freq=max(3, int(n / cell * 0.8)))
    e = (d2 - d1) * 0.5 / cell                    # расстояние до шва в долях ячейки
    inside = np.clip((e - gap) / max(1e-3, bevel - gap), 0, 1)
    h = 1 - (1 - inside) ** 2                    # фаска
    h = h * (1 - bulge * np.clip(d1 / cell, 0, 1) ** 2)   # купол
    h = blur(h, max(1.0, cell * 0.14))           # мягкая «подушка» без рёбер от середины к краям
    h = h + (pnoise(n, n / cell * 2, seed + 3, 2) - 0.5) * 0.12 * inside   # бугристость
    sh = paint(shade(h * cell * relief, 1.0))
    # цвет камня: свой оттенок из палитры и лёгкая разница яркости
    pal = np.array([hexc(c) for c in palette])
    pick = rng.integers(0, len(pal), count)
    var = rng.uniform(0.88, 1.1, count)
    base = pal[pick[idx]] * var[idx][..., None]
    base = base * (0.92 + 0.16 * pnoise(n, n / cell * 2, seed + 4)[..., None])
    col = base * (dark + (1.25 - dark) * sh[..., None])
    # светлый край сверху-слева
    edge = np.clip(1 - np.abs(inside - 0.35) / 0.35, 0, 1) * (sh > 0.62)
    col = col + rim * edge[..., None] * np.array([1.0, 0.95, 0.85])
    # трещинки у части камней
    cn = pnoise(n, n / cell * 2.2, seed + 5, 2)
    has = (rng.uniform(0, 1, count) < crack)[idx]
    line = np.clip(1 - np.abs(cn - 0.5) / 0.012, 0, 1) * has * (inside > 0.6)
    col = col * (1 - 0.55 * line[..., None])
    # шов
    g = hexc(gap_col) * (0.8 + 0.4 * pnoise(n, n / cell * 4, seed + 6))[..., None]
    if under is not None:
        g = under
    seam = 1 - inside
    col = col * (1 - seam[..., None]) + g * seam[..., None]
    col = col * (1 - 0.35 * np.clip(1 - e / gap, 0, 1)[..., None] * (e < gap)[..., None])
    return np.clip(col, 0, 1), np.clip(h, 0, 1)


# ------------------------------------------------------------------ трава мазками
def strokes(n, seed, base_cols, blade_cols, tufts, blades=(8, 16), length=(0.035, 0.07), width=(0.006, 0.011),
            ground=None, ground_h=None, spread=0.5):
    """Рисованная трава: пучки изогнутых листьев от центра, тёмные снизу и светлые к кончику (бесшовно)."""
    rng = np.random.default_rng(seed)
    S = n * 2
    img = Image.new("RGB", (S, S))
    hgt = Image.new("L", (S, S))
    if ground is None:
        b = pnoise(n, 10, seed + 1, 2)
        c0, c1 = hexc(base_cols[0]), hexc(base_cols[1])
        ground = c0 * (1 - b[..., None]) + c1 * b[..., None]
    img.paste(Image.fromarray((np.clip(ground, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR))
    if ground_h is not None:
        hgt.paste(Image.fromarray((ground_h * 120).astype(np.uint8)).resize((S, S), Image.BILINEAR))
    dr = ImageDraw.Draw(img)
    dh = ImageDraw.Draw(hgt)
    cols = [hexc(c) for c in blade_cols]
    dens = pnoise(n, 5, seed + 2)
    placed = 0
    tries = 0
    while placed < tufts and tries < tufts * 20:
        tries += 1
        cx, cy = rng.uniform(0, S), rng.uniform(0, S)
        if rng.uniform() > 0.25 + dens[int(cy / 2) % n, int(cx / 2) % n] * 1.2:
            continue
        placed += 1
        nb = rng.integers(blades[0], blades[1])
        size = rng.uniform(0.75, 1.3)
        for bi in range(nb):
            a = rng.uniform(0, math.tau)
            ln = rng.uniform(*length) * S * size
            w = rng.uniform(*width) * S * size
            bend = rng.uniform(-0.6, 0.6)
            lay = bi / max(1, nb - 1)
            # слои: сначала тёмные длинные, сверху светлые
            ci = min(len(cols) - 2, int(lay * (len(cols) - 1)))
            segs = 5
            pts_l, pts_r, shades = [], [], []
            for s in range(segs + 1):
                t = s / segs
                ang = a + bend * t * t
                r0 = ln * spread * 0.15
                px = cx + math.cos(a) * r0 + math.cos(ang) * ln * t
                py = cy + math.sin(a) * r0 + math.sin(ang) * ln * t
                ww = w * (1 - t) ** 0.8 * (0.6 + 0.4 * math.sin(math.pi * min(1, t * 1.6)))
                nx, ny = -math.sin(ang), math.cos(ang)
                pts_l.append((px + nx * ww, py + ny * ww))
                pts_r.append((px - nx * ww, py - ny * ww))
            for s in range(segs):
                t = (s + 0.5) / segs
                c = cols[ci] * (1 - t) + cols[ci + 1] * t
                c = c * rng.uniform(0.92, 1.08)
                # блик на стороне к свету
                lit = 0.5 + 0.5 * (math.cos(a) * -LIGHT[0] + math.sin(a) * -LIGHT[1]) * -1
                c = c * (0.85 + 0.3 * lit)
                poly = [pts_l[s], pts_l[s + 1], pts_r[s + 1], pts_r[s]]
                for ox in (-S, 0, S):
                    for oy in (-S, 0, S):
                        pp = [(x + ox, y + oy) for x, y in poly]
                        if max(x for x, _ in pp) < 0 or min(x for x, _ in pp) > S or max(y for _, y in pp) < 0 or min(y for _, y in pp) > S:
                            continue
                        dr.polygon(pp, fill=tuple(int(v * 255) for v in np.clip(c, 0, 1)))
                        dh.polygon(pp, fill=int(130 + 120 * t * (0.5 + lay * 0.5)))
    img = img.resize((n, n), Image.LANCZOS)
    hgt = hgt.resize((n, n), Image.LANCZOS)
    return np.asarray(img) / 255.0, np.asarray(hgt) / 255.0


def save(name, col, h):
    os.makedirs(OUT, exist_ok=True)
    rgba = np.dstack([np.clip(col, 0, 1), np.clip(h, 0, 1)])
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def soil(n, seed, c0, c1, c2):
    """Земля под травой: тёплая, комками, со светлыми камешками."""
    b = pnoise(n, 14, seed, 3)
    col = hexc(c0) * (1 - b[..., None]) + hexc(c1) * b[..., None]
    lumps = pnoise(n, 40, seed + 1, 2)
    col = col * (0.85 + 0.3 * paint(shade(lumps * 60, 1.0))[..., None])
    peb = (pnoise(n, 90, seed + 2) > 0.79).astype(float)
    peb = np.clip(blur(peb, 1.2) * 1.4, 0, 1)
    col = col * (1 - peb[..., None] * 0.6) + hexc(c2) * peb[..., None] * 0.6
    return col, lumps * 0.5


def main():
    n = N
    print("size", n)
    # каменистая земля (скалы, склоны): тёплые серые камни, как рисованная брусчатка, но природные
    col, h = stones(n, 70, 11, ["#9a9183", "#8b8378", "#a59b8b", "#7f7a73", "#8e8a86"], "#4a3b2c", bevel=0.45, gap=0.05,
                    warp=0.22, crack=0.45, bulge=0.45, relief=0.7)
    save("rock", col, h)
    # земля: крупные плотные комья, тёплая коричневая, с камешками в швах
    sc, sh = soil(n, 20, "#5e4029", "#7a5636", "#9a8f7e")
    col, h = stones(n, 90, 21, ["#7a5434", "#82603e", "#6e4b30", "#8a6644"], "#4a3322", bevel=0.55, gap=0.05,
                    warp=0.45, crack=0.55, bulge=0.15, rim=0.06, dark=0.72, relief=0.45)
    k = np.clip((h - 0.02) / 0.22, 0, 1)[..., None]
    col = sc * (1 - k) + (col * 0.8 + sc * 0.2) * k
    save("dirt", col, h * 0.7 + sh * 0.3)
    # гравий: много мелких камешков на тёмной земле
    under = hexc("#5a4632") * (0.8 + 0.4 * pnoise(n, 30, 31))[..., None]
    col, h = stones(n, 1400, 32, ["#9b958c", "#a8a194", "#86827b", "#b4ab9a", "#8c8a88"], "#4c3b2a", bevel=0.4,
                    gap=0.16, warp=0.25, crack=0.1, bulge=0.6, rim=0.2, under=under)
    save("gravel", col, h)
    # песок: тёплый, с рябью от ветра и редкими камешками
    b = pnoise(n, 8, 41, 3)
    col = hexc("#cfb685") * (1 - b[..., None]) + hexc("#e2cc9a") * b[..., None]
    wx = (pnoise(n, 4, 42) - 0.5) * 60
    ys, xs = np.mgrid[0:n, 0:n]
    rip = np.sin((xs * 0.35 + ys * 1.0 + wx * 3.0) * (2 * math.pi * 12 / n))
    hr = rip * 0.5 + 0.5
    col = col * (0.9 + 0.18 * paint(shade(hr * 8, 1.0), 3)[..., None])
    grains = (pnoise(n, 200, 43) > 0.8) * 0.12
    col = col * (1 - grains[..., None])
    peb, ph = stones(n, 500, 44, ["#a59a88", "#8f8578", "#b9ae98"], "#000000", bevel=0.4, gap=0.1, bulge=0.6, crack=0,
                     under=col)
    m = ((pnoise(n, 50, 45) > 0.75) * (ph > 0.2)).astype(float)
    col = col * (1 - m[..., None]) + peb * m[..., None]
    save("sand", col, np.maximum(hr * 0.3, m * ph))
    # трава: сочные пучки на тёмной земле
    sc, sh = soil(n, 51, "#3d3220", "#4e3f26", "#7a7060")
    gcol = sc * 0.55 + hexc("#2f4519") * 0.45
    col, h = strokes(n, 52, None, ["#2c4317", "#3f5c22", "#5b7f2c", "#7fa23c", "#a3c055"], tufts=700, ground=gcol, ground_h=sh,
                     blades=(9, 18), length=(0.03, 0.06), width=(0.005, 0.009))
    save("grass", col, h)
    # луг: суше и светлее, между пучками видна земля
    sc, sh = soil(n, 61, "#5c4628", "#73592f", "#9c917e")
    col, h = strokes(n, 62, None, ["#4f5124", "#6f6d2e", "#97903f", "#c0b25c", "#dccd7c"], tufts=420, ground=sc, ground_h=sh,
                     blades=(7, 14), length=(0.028, 0.055), width=(0.005, 0.009))
    save("meadow", col, h)


if __name__ == "__main__":
    main()
