# Набор деталей для подробных моделей: рамы, вышки, редукторы, моторы, пульты, лестницы, перила...
# Каждая функция дописывает детали в список a (list) и ничего не возвращает.
# Используется gen_core.py (уровни буров, лент, труб) и gen_library.py (каталог готовых объектов).
import math

DARK, STEEL, CHR, RUB = "#292b30", "#8c949e", "#d5dbe2", "#1d1e21"
YEL = "#f2a81f"


def P(shape, size, pos, color, mat="paint", rot=(0, 0, 0), anim="", role="", tint=True, top=None, seg=None):
    d = {"shape": shape, "size": [round(float(v), 3) for v in size], "pos": [round(float(v), 3) for v in pos],
         "rot": [round(float(v), 2) for v in rot], "color": color, "mat": mat}
    if anim: d["anim"] = anim
    if role: d["role"] = role
    if not tint: d["tint"] = False
    if top is not None: d["top"] = top
    if seg is not None: d["seg"] = seg
    return d


def M(name, parts, cat="Разное"):
    return {"name": name, "category": cat, "parts": parts}


def shade(col, k):
    """Темнее (k<1) или светлее (k>1) цвет."""
    c = col.lstrip("#")
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    if k >= 1:
        r, g, b = [int(v + (255 - v) * (k - 1)) for v in (r, g, b)]
    else:
        r, g, b = [int(v * k) for v in (r, g, b)]
    return "#%02x%02x%02x" % (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))


# ------------------------------------------------------------------ основания
def skids(a, w=1.96, d=1.56, col=DARK):
    """Салазки с загнутыми концами и поперечинами."""
    for z in (-d / 2, d / 2):
        a.append(P("box", (w, 0.1, 0.22), (0, 0.05, z), col, "dark"))
        a.append(P("box", (w, 0.16, 0.05), (0, 0.18, z), col, "dark"))
        a.append(P("box", (0.22, 0.1, 0.24), (w / 2, 0.08, z), col, "dark", rot=(0, 0, 35)))
        a.append(P("box", (0.22, 0.1, 0.24), (-w / 2, 0.08, z), col, "dark", rot=(0, 0, -35)))
    for x in (-w * 0.38, 0.0, w * 0.38):
        a.append(P("box", (0.12, 0.12, d), (x, 0.17, 0), col, "dark"))


def deck(a, y, w, d, col, edge=YEL, bolts=True, stripes=True):
    """Плита-палуба: окантовка, полосы опасности, болты."""
    a.append(P("box", (w, 0.12, d), (0, y, 0), col))
    a.append(P("box", (w + 0.02, 0.04, 0.1), (0, y + 0.08, d / 2 - 0.04), edge))
    a.append(P("box", (w + 0.02, 0.04, 0.1), (0, y + 0.08, -d / 2 + 0.04), edge))
    if stripes:
        n = int(w / 0.26)
        for i in range(n):
            x = -w / 2 + 0.13 + i * (w - 0.26) / max(1, n - 1)
            a.append(P("box", (0.12, 0.045, 0.1), (x, y + 0.09, d / 2 - 0.04), DARK, "dark", rot=(0, 45, 0)))
            a.append(P("box", (0.12, 0.045, 0.1), (x, y + 0.09, -d / 2 + 0.04), DARK, "dark", rot=(0, 45, 0)))
    if bolts:
        for x in (-w * 0.45, -w * 0.15, w * 0.15, w * 0.45):
            for z in (-d * 0.45, d * 0.45):
                a.append(P("cylinder", (0.06, 0.05, 0.06), (x, y + 0.08, z), CHR, "metal", seg=6))


def outriggers(a, x, z, y, col, rubber=RUB):
    """Гидроопора: подушка, шток, корпус цилиндра, шланг."""
    a.append(P("box", (0.22, 0.08, 0.22), (x, 0.04, z), rubber, "dark"))
    a.append(P("cylinder", (0.13, y - 0.1, 0.13), (x, (y - 0.1) / 2 + 0.06, z), CHR, "metal", seg=10))
    a.append(P("cylinder", (0.2, 0.24, 0.2), (x, y, z), col, seg=10))
    a.append(P("cylinder", (0.22, 0.04, 0.22), (x, y + 0.13, z), DARK, "dark", seg=10))


def hex_base(a, r, y, h, col, trim):
    """Шестигранная плита с подсветкой по граням."""
    a.append(P("cylinder", (r * 2, h, r * 2), (0, y, 0), col, "dark", seg=6))
    a.append(P("cylinder", (r * 2.04, 0.04, r * 2.04), (0, y + h / 2, 0), trim, "glow", seg=6, anim="pulse"))
    a.append(P("cylinder", (r * 1.7, 0.06, r * 1.7), (0, y + h / 2 + 0.03, 0), shade(col, 1.25), "metal", seg=6))


# ------------------------------------------------------------------ вышки и фермы
def lattice(a, x0, x1, z0, z1, y0, y1, col, levels=3, braces=True, thick=0.1):
    """Решётчатая вышка: 4 стойки, пояса, раскосы на двух гранях."""
    h = y1 - y0
    for x in (x0, x1):
        for z in (z0, z1):
            a.append(P("box", (thick, h, thick), (x, y0 + h / 2, z), col))
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    wx, wz = abs(x1 - x0), abs(z1 - z0)
    for i in range(levels):
        y = y0 + h * (i + 1) / levels
        for z in (z0, z1):
            a.append(P("box", (wx, 0.06, 0.06), (cx, y, z), col))
        for x in (x0, x1):
            a.append(P("box", (0.06, 0.06, wz), (x, y, cz), col))
    if braces:
        seg = h / levels
        for i in range(levels):
            y = y0 + seg * (i + 0.5)
            ang = math.degrees(math.atan2(seg, wx))
            ln = math.hypot(seg, wx)
            for z in (z0, z1):
                a.append(P("box", (ln, 0.045, 0.045), (cx, y, z), col, rot=(0, 0, ang if i % 2 == 0 else -ang)))
            angz = math.degrees(math.atan2(seg, wz))
            lnz = math.hypot(seg, wz)
            for x in (x0, x1):
                a.append(P("box", (0.045, 0.045, lnz), (x, y, cz), col, rot=(angz if i % 2 == 0 else -angz, 0, 0)))


def railing(a, x0, x1, z0, z1, y, col, h=0.42, posts=3):
    """Перила по периметру площадки."""
    for i in range(posts):
        t = i / max(1, posts - 1)
        x = x0 + (x1 - x0) * t
        z = z0 + (z1 - z0) * t
        for zz in (z0, z1):
            a.append(P("box", (0.04, h, 0.04), (x, y + h / 2, zz), col))
        for xx in (x0, x1):
            a.append(P("box", (0.04, h, 0.04), (xx, y + h / 2, z), col))
    for zz in (z0, z1):
        a.append(P("box", (abs(x1 - x0), 0.04, 0.04), ((x0 + x1) / 2, y + h, zz), col))
        a.append(P("box", (abs(x1 - x0), 0.03, 0.03), ((x0 + x1) / 2, y + h * 0.5, zz), col))
    for xx in (x0, x1):
        a.append(P("box", (0.04, 0.04, abs(z1 - z0)), (xx, y + h, (z0 + z1) / 2), col))
        a.append(P("box", (0.03, 0.03, abs(z1 - z0)), (xx, y + h * 0.5, (z0 + z1) / 2), col))


def ladder(a, x, z, y0, y1, col, rung=STEEL, along="z", w=0.3):
    """Лестница: две тетивы и перекладины; along — вдоль какой оси стоят тетивы."""
    h = y1 - y0
    for s in (-w / 2, w / 2):
        p = (x, y0 + h / 2, z + s) if along == "z" else (x + s, y0 + h / 2, z)
        a.append(P("box", (0.05, h, 0.05), p, col))
    n = max(2, int(h / 0.27))
    for i in range(n):
        y = y0 + 0.2 + i * (h - 0.3) / max(1, n - 1)
        if along == "z":
            a.append(P("cylinder", (0.03, w, 0.03), (x, y, z), rung, "metal", rot=(90, 0, 0), seg=6))
        else:
            a.append(P("cylinder", (0.03, w, 0.03), (x, y, z), rung, "metal", rot=(0, 0, 90), seg=6))
    # дуги ограждения
    for i in range(int(h / 0.6)):
        y = y0 + 0.9 + i * 0.6
        if y < y1 - 0.1:
            a.append(P("torus", (w + 0.12, 0.3, w + 0.12), (x - (0.12 if along == "z" else 0), y, z), col, "dark",
                       rot=(0, 0, 90) if along == "z" else (90, 0, 0), seg=10))


def platform(a, x0, x1, z0, z1, y, col, rail=YEL, grate=True):
    """Площадка с решётчатым настилом и перилами."""
    w, d = abs(x1 - x0), abs(z1 - z0)
    a.append(P("box", (w, 0.06, d), ((x0 + x1) / 2, y, (z0 + z1) / 2), col, "dark"))
    if grate:
        n = max(2, int(w / 0.18))
        for i in range(n):
            x = x0 + 0.09 + i * (w - 0.18) / max(1, n - 1)
            a.append(P("box", (0.025, 0.02, d - 0.04), (x, y + 0.04, (z0 + z1) / 2), shade(col, 1.4), "metal"))
    railing(a, x0, x1, z0, z1, y + 0.03, rail)


# ------------------------------------------------------------------ механика
def gearbox(a, x, y, z, w, h, d, col, gear_col=YEL, side=1):
    """Редуктор: корпус с крышкой и рёбрами, пара шестерён на боку (вращаются при работе)."""
    a.append(P("box", (w, h, d), (x, y, z), col))
    a.append(P("box", (w + 0.04, 0.06, d + 0.04), (x, y + h / 2 + 0.03, z), DARK, "dark"))
    a.append(P("box", (w + 0.04, 0.05, d + 0.04), (x, y - h / 2 + 0.025, z), DARK, "dark"))
    for i in range(3):
        a.append(P("box", (0.03, h * 0.7, d + 0.02), (x - w * 0.35 + i * w * 0.12, y, z), shade(col, 0.75)))
    zf = z + side * (d / 2 + 0.02)
    a.append(P("box", (w * 0.96, h * 0.92, 0.02), (x, y, zf), DARK, "dark"))
    r1, r2 = min(h, w) * 0.85, min(h, w) * 0.48
    rx = 90 if side > 0 else -90
    a.append(P("gear", (r1, 0.07, r1), (x - w * 0.15, y, zf + side * 0.05), gear_col, "metal", rot=(rx, 0, 0), anim="gear_slow", seg=20, top=0.82))
    a.append(P("gear", (r2, 0.07, r2), (x + w * 0.3, y + h * 0.08, zf + side * 0.05), STEEL, "metal", rot=(-rx, 0, 0), anim="gear_fast", seg=11, top=0.75))
    a.append(P("cylinder", (0.08, 0.14, 0.08), (x - w * 0.15, y, zf + side * 0.09), CHR, "metal", rot=(rx, 0, 0), seg=8))
    a.append(P("cylinder", (0.06, 0.14, 0.06), (x + w * 0.3, y + h * 0.08, zf + side * 0.09), CHR, "metal", rot=(rx, 0, 0), seg=8))
    # смотровое окошко и маслёнка
    a.append(P("cylinder", (0.12, 0.03, 0.12), (x + w * 0.38, y - h * 0.3, zf + side * 0.02), "#d9a400", "glass", rot=(rx, 0, 0), seg=10))
    a.append(P("cylinder", (0.05, 0.12, 0.05), (x - w * 0.4, y + h / 2 + 0.1, z), "#c03020", seg=8))


def motor(a, x, y, z, r, h, col, fins=6, fan=True, axis="y"):
    """Электромотор: корпус, рёбра охлаждения, крышка, вентилятор, клеммная коробка."""
    rot = (0, 0, 0) if axis == "y" else ((0, 0, 90) if axis == "x" else (90, 0, 0))
    a.append(P("cylinder", (r * 2, h, r * 2), (x, y, z), col, rot=rot, seg=20))
    for i in range(fins):
        o = -h * 0.4 + i * h * 0.8 / max(1, fins - 1)
        p = (x, y + o, z) if axis == "y" else ((x + o, y, z) if axis == "x" else (x, y, z + o))
        a.append(P("cylinder", (r * 2.25, 0.035, r * 2.25), p, DARK, "dark", rot=rot, seg=20))
    o = h / 2 + 0.03
    p = (x, y + o, z) if axis == "y" else ((x + o, y, z) if axis == "x" else (x, y, z + o))
    a.append(P("cylinder", (r * 2.1, 0.06, r * 2.1), p, CHR, "metal", rot=rot, seg=20))
    if fan and axis == "y":
        a.append(P("cylinder", (r * 1.9, 0.04, r * 1.9), (x, y + o + 0.05, z), DARK, "dark", seg=24))
        for i in range(6):
            a.append(P("box", (r * 0.85, 0.02, 0.08), (x, y + o + 0.08, z), STEEL, "metal", rot=(14, i * 30, 0), anim="spin_fan"))
        a.append(P("sphere", (0.1, 0.06, 0.1), (x, y + o + 0.1, z), CHR, "metal"))
    a.append(P("box", (r * 0.7, h * 0.4, r * 0.6), (x + r * 0.95, y, z + r * 0.4), DARK, "dark"))
    a.append(P("box", (0.02, h * 0.15, r * 0.4), (x + r * 1.31, y + h * 0.05, z + r * 0.4), "#40c8ff", "glow", anim="pulse"))


def piston(a, x, y, z, length, r, col, tilt=(0, 0, 0)):
    """Гидроцилиндр: корпус и шток, который ходит при работе."""
    a.append(P("cylinder", (r * 2, length * 0.55, r * 2), (x, y, z), col, rot=tilt, seg=12))
    a.append(P("cylinder", (r, length * 0.5, r), (x, y + length * 0.45, z), CHR, "metal", rot=tilt, anim="piston_small", seg=10))
    a.append(P("cylinder", (r * 2.3, 0.05, r * 2.3), (x, y + length * 0.28, z), DARK, "dark", rot=tilt, seg=12))
    a.append(P("torus", (r * 2.2, 0.2, r * 2.2), (x, y - length * 0.3, z), RUB, "dark", rot=(90, 0, 0), seg=10))


def hose(a, x, y, z, r, col="#e0761c", rot=(90, 0, 0), thick=0.12):
    a.append(P("torus", (r, r, thick), (x, y, z), col, "cloth", rot=rot, seg=14))


def auger(a, x, y, z, d, h, col=CHR, anim="spin_fast"):
    """Шнек с обсадным кольцом."""
    a.append(P("torus", (d * 1.45, 0.3, d * 1.45), (x, y - h / 2 + 0.06, z), DARK, "dark", seg=20))
    a.append(P("cylinder", (d * 1.2, 0.18, d * 1.2), (x, y - h / 2, z), RUB, "dark", seg=20))
    a.append(P("screw", (d, h, d), (x, y, z), col, "metal", anim=anim, seg=4, top=0.3))


def cutter_head(a, x, y, z, r, col, tooth=CHR, n=10):
    """Буровая коронка: диск с резцами по кругу, крутится."""
    a.append(P("cylinder", (r * 2, 0.2, r * 2), (x, y, z), col, "metal", anim="spin_fast", seg=n * 2))
    a.append(P("cone", (r * 1.6, 0.4, r * 1.6), (x, y - 0.28, z), shade(col, 0.7), "metal", anim="spin_fast", seg=n, rot=(180, 0, 0)))
    for i in range(n):
        ang = 2 * math.pi * i / n
        a.append(P("cone", (0.09, 0.2, 0.09), (x + math.cos(ang) * r * 0.9, y - 0.16, z + math.sin(ang) * r * 0.9), tooth, "metal",
                   rot=(180, 0, 0), anim="spin_fast"))


def kelly(a, x, z, y0, y1, r=0.1):
    """Ведущая штанга (вращается) с муфтой."""
    a.append(P("cylinder", (r * 2, y1 - y0, r * 2), (x, (y0 + y1) / 2, z), CHR, "metal", anim="spin_fast", seg=6))
    a.append(P("cylinder", (r * 3.4, 0.12, r * 3.4), (x, y0 + 0.35, z), DARK, "dark", anim="spin_fast", seg=6))


# ------------------------------------------------------------------ пульты, свет, мелочи
def panel(a, x, y, z, col, face=-1, w=0.62, h=0.9, screen="#40ffb0"):
    """Шкаф управления: экран, кнопки, рычаги. face = -1 смотрит в -x, +1 в +x."""
    a.append(P("box", (0.32, h, w), (x, y, z), col))
    fx = x + face * 0.17
    a.append(P("box", (0.02, h * 0.31, w * 0.65), (fx, y + h * 0.22, z), "#1b2d3a", "glass"))
    a.append(P("box", (0.02, h * 0.22, w * 0.52), (fx + face * 0.01, y + h * 0.22, z), screen, "glow", anim="flicker_soft"))
    for k, c in enumerate(("#ff3b2f", "#ffd040", "#40ff6a")):
        a.append(P("sphere", (0.06, 0.06, 0.06), (fx, y - h * 0.11, z - w * 0.29 + k * w * 0.16), c, "glow", anim="blink" if k == 0 else "pulse"))
    for k in range(2):
        a.append(P("cylinder", (0.03, 0.22, 0.03), (fx + face * 0.01, y - h * 0.19, z + w * 0.24 + k * 0.08), CHR, "metal", rot=(0, 0, 20 + k * 15), seg=6))
        a.append(P("sphere", (0.06, 0.06, 0.06), (fx + face * 0.05, y - h * 0.07, z + w * 0.24 + k * 0.08), "#ff3b2f"))
    a.append(P("box", (0.3, 0.06, w + 0.04), (x, y + h / 2 + 0.03, z), DARK, "dark"))
    a.append(P("box", (0.34, 0.08, w + 0.06), (x, y - h / 2 + 0.04, z), DARK, "dark"))


def beacon(a, x, y, z, col="#ff8c1a"):
    a.append(P("cylinder", (0.12, 0.08, 0.12), (x, y, z), DARK, "dark", seg=10))
    a.append(P("sphere", (0.14, 0.16, 0.14), (x, y + 0.1, z), col, "glow", anim="blink"))
    a.append(P("cylinder", (0.17, 0.18, 0.17), (x, y + 0.1, z), DARK, "dark", seg=6, top=1.0))


def lamp_post(a, x, z, h, col=DARK, light="#fff1c4"):
    a.append(P("cylinder", (0.06, h, 0.06), (x, h / 2, z), col, "dark", seg=6))
    a.append(P("box", (0.28, 0.05, 0.06), (x + 0.12, h, z), col, "dark"))
    a.append(P("box", (0.16, 0.06, 0.12), (x + 0.24, h - 0.04, z), col, "dark"))
    a.append(P("box", (0.12, 0.02, 0.09), (x + 0.24, h - 0.08, z), light, "glow", anim="flicker_soft"))


def exhaust(a, x, y, z, h=0.9, r=0.06):
    a.append(P("cylinder", (r * 2, h, r * 2), (x, y, z), DARK, "dark", seg=10))
    a.append(P("cylinder", (r * 3.4, 0.05, r * 3.4), (x, y + h / 2 + 0.03, z), DARK, "dark", rot=(0, 0, 20), seg=10))
    a.append(P("torus", (r * 2.6, 0.2, r * 2.6), (x, y - h * 0.2, z), STEEL, "metal", seg=10))


def barrel(a, x, z, col="#c03020", y=0.0, h=0.42):
    a.append(P("cylinder", (0.3, h, 0.3), (x, y + h / 2, z), col, seg=12))
    for k in (0.25, 0.75):
        a.append(P("torus", (0.31, 0.12, 0.31), (x, y + h * k, z), shade(col, 0.6), "metal", seg=12))
    a.append(P("cylinder", (0.05, 0.03, 0.05), (x + 0.07, y + h + 0.01, z), CHR, "metal", seg=6))


def cable_reel(a, x, y, z, col=YEL, cable="#1d1e21"):
    a.append(P("cylinder", (0.4, 0.04, 0.4), (x, y, z - 0.1), col, rot=(90, 0, 0), seg=14))
    a.append(P("cylinder", (0.4, 0.04, 0.4), (x, y, z + 0.1), col, rot=(90, 0, 0), seg=14))
    a.append(P("cylinder", (0.3, 0.18, 0.3), (x, y, z), cable, "cloth", rot=(90, 0, 0), seg=14))
    a.append(P("box", (0.06, y, 0.06), (x, y / 2, z - 0.14), DARK, "dark"))
    a.append(P("box", (0.06, y, 0.06), (x, y / 2, z + 0.14), DARK, "dark"))


def sign_plate(a, x, y, z, text_col, bg="#ffffff", face="x", n=2):
    """Табличка с «буквами» (полоски) — номер уровня."""
    if face == "x":
        a.append(P("box", (0.02, 0.16, 0.34), (x, y, z), bg))
        for i in range(n):
            a.append(P("box", (0.02, 0.07, 0.04), (x + 0.01, y, z - 0.1 + i * 0.2 / max(1, n - 1)), text_col))
    else:
        a.append(P("box", (0.34, 0.16, 0.02), (x, y, z), bg))
        for i in range(n):
            a.append(P("box", (0.04, 0.07, 0.02), (x - 0.1 + i * 0.2 / max(1, n - 1), y, z + 0.01), text_col))


def tier_pips(a, x, y, z, n, col, face="x"):
    """Метки уровня: n светящихся рисок."""
    for i in range(n):
        o = -0.12 * (n - 1) / 2 + i * 0.12
        p = (x, y, z + o) if face == "x" else (x + o, y, z)
        a.append(P("box", (0.03, 0.12, 0.06) if face == "x" else (0.06, 0.12, 0.03), p, col, "glow", anim="pulse"))


def chute(a, x, y, z, col, side=STEEL, rollers=4):
    """Жёлоб выгрузки с роликами к выходу (+x)."""
    a.append(P("box", (0.75, 0.06, 0.5), (x, y, z), side, "metal", rot=(0, 0, -16)))
    a.append(P("box", (0.75, 0.18, 0.04), (x, y + 0.08, z + 0.26), col, rot=(0, 0, -16)))
    a.append(P("box", (0.75, 0.18, 0.04), (x, y + 0.08, z - 0.26), col, rot=(0, 0, -16)))
    for i in range(rollers):
        a.append(P("cylinder", (0.07, 0.46, 0.07), (x - 0.26 + i * 0.17, y + 0.1 - i * 0.05, z), RUB, "dark", rot=(90, 0, 0), anim="spin_fast", seg=8))


def tank_v(a, x, y, z, r, h, col, band=DARK, cap=CHR, gauge=True):
    """Вертикальный бак: обечайка, пояса, купол, манометр."""
    a.append(P("cylinder", (r * 2, h, r * 2), (x, y + h / 2, z), col, "metal", seg=16))
    for k in (0.15, 0.5, 0.85):
        a.append(P("torus", (r * 2.05, 0.08, r * 2.05), (x, y + h * k, z), band, "dark", seg=16))
    a.append(P("sphere", (r * 2, r * 0.9, r * 2), (x, y + h, z), col, "metal", seg=16))
    a.append(P("cylinder", (r * 0.4, 0.08, r * 0.4), (x, y + h + r * 0.42, z), cap, "metal", seg=8))
    if gauge:
        a.append(P("cylinder", (0.12, 0.03, 0.12), (x + r + 0.01, y + h * 0.6, z), "#f2f2f2", rot=(0, 0, 90), seg=12))
        a.append(P("box", (0.01, 0.05, 0.01), (x + r + 0.03, y + h * 0.6 + 0.02, z), "#c03020", rot=(30, 0, 0)))


def coil(a, x, y, z, r, h, col="#c87533", turns=6, core=DARK):
    """Катушка: сердечник и витки."""
    a.append(P("cylinder", (r * 1.2, h, r * 1.2), (x, y + h / 2, z), core, "dark", seg=12))
    for i in range(turns):
        a.append(P("torus", (r * 2, 0.35, r * 2), (x, y + 0.08 + i * (h - 0.16) / max(1, turns - 1), z), col, "metal", seg=14))


def energy_ring(a, x, y, z, r, col, anim="spin_slow", thick=0.25):
    a.append(P("torus", (r * 2, thick, r * 2), (x, y, z), col, "glow", anim=anim, seg=24))


def crystal_cluster(a, x, y, z, col, s=1.0, anim="pulse"):
    for (dx, dz, h, rz, rx) in ((0, 0, 0.7, 0, 0), (0.14, 0.06, 0.45, -24, 8), (-0.12, -0.08, 0.5, 22, -10), (0.04, -0.15, 0.35, 8, 26)):
        a.append(P("prism", (0.16 * s, h * s, 0.16 * s), (x + dx * s, y + h * s / 2, z + dz * s), col, "glow", rot=(rx, 0, rz), anim=anim))


def window_strip(a, x, y, z, w, h, along="z", frame=DARK, glass="#7fc8ff"):
    if along == "z":
        a.append(P("box", (0.04, h + 0.06, w + 0.06), (x, y, z), frame, "dark"))
        a.append(P("box", (0.05, h, w), (x, y, z), glass, "glass"))
        a.append(P("box", (0.06, h, 0.03), (x, y, z), frame, "dark"))
    else:
        a.append(P("box", (w + 0.06, h + 0.06, 0.04), (x, y, z), frame, "dark"))
        a.append(P("box", (w, h, 0.05), (x, y, z), glass, "glass"))
        a.append(P("box", (0.03, h, 0.06), (x, y, z), frame, "dark"))


def pipe_run(a, pts, r, col, mat="metal", flange=DARK):
    """Труба по ломаной (точки в плоскостях осей) с фланцами на стыках."""
    for i in range(len(pts) - 1):
        p0, p1 = pts[i], pts[i + 1]
        d = [p1[k] - p0[k] for k in range(3)]
        ln = math.sqrt(sum(v * v for v in d))
        if ln < 1e-4:
            continue
        mid = [(p0[k] + p1[k]) / 2 for k in range(3)]
        if abs(d[1]) >= max(abs(d[0]), abs(d[2])):
            rot = (0, 0, 0)
        elif abs(d[0]) >= abs(d[2]):
            rot = (0, 0, 90)
        else:
            rot = (90, 0, 0)
        a.append(P("cylinder", (r * 2, ln, r * 2), mid, col, mat, rot=rot, seg=10))
        a.append(P("sphere", (r * 2.3, r * 2.3, r * 2.3), p1, flange, "dark", seg=8))


# ------------------------------------------------------------------ повороты (как в Godot: порядок YXZ)
def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def _ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def rot_matrix(rot):
    x, y, z = [math.radians(v) for v in rot]
    return _mul(_mul(_ry(y), _rx(x)), _rz(z))


def euler_yxz(m):
    m12 = m[1][2]
    if m12 < 1 - 1e-6:
        if m12 > -(1 - 1e-6):
            x = math.asin(-m12)
            y = math.atan2(m[0][2], m[2][2])
            z = math.atan2(m[1][0], m[1][1])
        else:
            x = math.pi / 2
            y = math.atan2(m[0][1], m[0][0])
            z = 0.0
    else:
        x = -math.pi / 2
        y = -math.atan2(m[0][1], m[0][0])
        z = 0.0
    return (round(math.degrees(x), 2), round(math.degrees(y), 2), round(math.degrees(z), 2))


def spun(rot, phi):
    """Поворот детали rot, предварительно повёрнутой на phi градусов вокруг своей оси Y (оси анимации вращения)."""
    return euler_yxz(_mul(rot_matrix(rot), _ry(math.radians(phi))))
