# Подробная природа (12.2): деревья, кусты, камни и руда. Деталей умеренно — их на карте тысячи.
import math
from art_kit import P, M, shade


def roots(a, r, col, n=5, h=0.25):
    for i in range(n):
        ang = 2 * math.pi * i / n + 0.3
        a.append(P("cone", (r * 0.6, h * 2.2, r * 0.6), (math.cos(ang) * r * 0.55, h * 0.4, math.sin(ang) * r * 0.55), col, "wood",
                   rot=(math.sin(ang) * 55, 0, -math.cos(ang) * 55), seg=5))


def pine(trunk, crown, h=1.0, layers=4, snow=None, tip=None):
    a = []
    a.append(P("cylinder", (0.42, 2.4 * h, 0.42), (0, 1.2 * h, 0), trunk, "wood", top=0.45, seg=7))
    roots(a, 0.5, trunk)
    for i in range(layers):
        t = i / max(1, layers - 1)
        w = (3.0 - t * 1.9) * (1 if h < 1.2 else 1.05)
        y = (1.5 + t * 2.6) * h
        col = shade(crown, 1.0 + (i % 2) * 0.12)
        a.append(P("cone", (w, 1.5 * h, w), (0.05 * (i % 2), y, -0.04 * (i % 2)), col, "leaf", anim="sway", seg=8, rot=(0, i * 22, 0)))
        if snow:
            a.append(P("cone", (w * 0.7, 0.5 * h, w * 0.7), (0.05 * (i % 2), y + 0.55 * h, -0.04 * (i % 2)), snow, "leaf", anim="sway", seg=8, rot=(0, i * 22, 0)))
    a.append(P("cone", (0.5, 0.9 * h, 0.5), (0, (4.4 + 0.3) * h, 0), tip or shade(crown, 1.15), "leaf", anim="sway", seg=6))
    # шишки
    for k in range(3):
        ang = k * 2.1
        a.append(P("capsule", (0.1, 0.18, 0.1), (math.cos(ang) * 0.6, 1.9 * h + k * 0.5, math.sin(ang) * 0.6), "#6b4a2a", "wood", anim="sway"))
    return a


def oak(trunk="#5c3d24", leaf="#3d6b29", h=1.0, autumn=None):
    a = []
    a.append(P("cylinder", (0.7, 2.2 * h, 0.7), (0, 1.1 * h, 0), trunk, "wood", top=0.65, seg=8))
    roots(a, 0.75, trunk, n=6, h=0.3)
    # ветви
    for k, (ang, tilt, ln) in enumerate(((0.3, 45, 1.4), (2.4, 50, 1.3), (4.3, 40, 1.5), (1.4, 30, 1.0))):
        x, z = math.cos(ang), math.sin(ang)
        a.append(P("cylinder", (0.22, ln * h, 0.22), (x * 0.4, 2.2 * h + 0.3, z * 0.4), trunk, "wood",
                   rot=(z * tilt, 0, -x * tilt), top=0.5, seg=6))
    # кроны-облака
    cols = [leaf, shade(leaf, 1.15), shade(leaf, 0.85), autumn or shade(leaf, 1.05)]
    for k, (x, y, z, s) in enumerate(((0, 3.4, 0, 2.6), (1.0, 3.1, 0.5, 1.8), (-0.9, 3.2, -0.4, 1.9), (0.3, 3.0, -1.0, 1.7),
                                       (-0.4, 3.0, 1.0, 1.7), (0.2, 4.1, 0.1, 1.8))):
        a.append(P("sphere", (s, s * 0.8, s), (x, y * h, z), cols[k % 4], "leaf", anim="sway", seg=8))
    # жёлуди / птичье гнездо
    a.append(P("torus", (0.4, 0.4, 0.4), (0.7, 2.75 * h, 0.3), "#7a5a3a", "wood", seg=8))
    for k in range(2):
        a.append(P("sphere", (0.08, 0.06, 0.08), (0.65 + k * 0.1, 2.8 * h, 0.3), "#cfe6ff", "paint"))
    return a


def birch(h=1.0):
    a = []
    a.append(P("cylinder", (0.34, 3.4 * h, 0.34), (0, 1.7 * h, 0), "#e6e3d8", "wood", top=0.55, seg=7))
    for k in range(7):
        a.append(P("box", (0.36 - k * 0.02, 0.05, 0.12), (0.03 * (k % 2), 0.5 + k * 0.42 * h, 0.12 * ((k % 3) - 1)), "#2e2b26", "wood", rot=(0, k * 47, 0)))
    for k, ang in enumerate((0.5, 2.6, 4.4)):
        x, z = math.cos(ang), math.sin(ang)
        a.append(P("cylinder", (0.08, 1.1, 0.08), (x * 0.3, 2.6 * h + k * 0.3, z * 0.3), "#d9d6cb", "wood", rot=(z * 40, 0, -x * 40), seg=5))
    for k, (x, y, z, s) in enumerate(((0, 3.9, 0, 1.9), (0.5, 3.4, 0.4, 1.3), (-0.5, 3.5, -0.3, 1.4), (0.1, 4.5, -0.1, 1.2))):
        a.append(P("sphere", (s, s * 1.15, s), (x, y * h, z), ("#7aa63a", "#8cb84a", "#6a9630", "#9ccb5a")[k], "leaf", anim="sway", seg=7))
    return a


def dead_tree():
    a = []
    C = "#4a3f36"
    a.append(P("cylinder", (0.5, 2.8, 0.5), (0, 1.4, 0), C, "wood", top=0.35, seg=7))
    roots(a, 0.55, C)
    for k, (ang, y, tilt, ln) in enumerate(((0.2, 2.2, 45, 1.4), (2.3, 1.9, 50, 1.2), (4.1, 2.5, 35, 1.0), (1.2, 2.7, 60, 0.8), (5.2, 1.5, 70, 0.9))):
        x, z = math.cos(ang), math.sin(ang)
        a.append(P("cylinder", (0.14, ln, 0.14), (x * ln * 0.35, y + 0.3, z * ln * 0.35), C, "wood", rot=(z * tilt, 0, -x * tilt), top=0.3, seg=5))
    a.append(P("box", (0.3, 0.2, 0.05), (0.2, 1.4, 0.24), "#2e2620", "wood"))
    a.append(P("sphere", (0.2, 0.08, 0.2), (0.27, 0.8, 0), "#c9a227", "paint", seg=6))
    a.append(P("sphere", (0.14, 0.06, 0.14), (0.25, 0.65, 0.1), "#e6d43a", "paint", seg=6))
    return a


def stump():
    a = []
    a.append(P("cylinder", (0.62, 0.45, 0.62), (0, 0.22, 0), "#5c3d24", "wood", seg=9))
    a.append(P("cylinder", (0.56, 0.02, 0.56), (0, 0.455, 0), "#c49a6c", "wood", seg=9))
    for r in (0.38, 0.24, 0.1):
        a.append(P("torus", (r, 0.08, r), (0, 0.465, 0), "#a07a50", "wood", seg=12))
    roots(a, 0.6, "#5c3d24", n=5, h=0.2)
    a.append(P("sphere", (0.14, 0.06, 0.14), (0.3, 0.3, 0.12), "#c2331f", "paint", seg=6))
    a.append(P("cylinder", (0.04, 0.1, 0.04), (0.3, 0.25, 0.12), "#e6dccb", "paint", seg=5))
    return a


def bush_berry():
    a = []
    for k, (x, z, s) in enumerate(((0, 0, 1.3), (0.4, 0.3, 0.9), (-0.4, 0.25, 0.85), (0.1, -0.4, 0.9))):
        a.append(P("sphere", (s, s * 0.75, s), (x, s * 0.35 + 0.05, z), ("#2f5c26", "#3a6b2e", "#28521f", "#356428")[k], "leaf", anim="sway", seg=8))
    for k in range(12):
        ang = k * 2.4
        r = 0.45 + (k % 3) * 0.12
        a.append(P("sphere", (0.12, 0.12, 0.12), (math.cos(ang) * r, 0.45 + (k % 4) * 0.1, math.sin(ang) * r), "#e0263d" if k % 3 else "#9a1a8a", "paint", seg=6))
    return a


def rock_shape(col, s=1.0, moss=None, veins=None, crystal=None):
    a = []
    pieces = ((0, 0.35, 0, 1.6, 1.0, 1.4), (0.5, 0.3, 0.45, 0.9, 0.7, 0.9), (-0.45, 0.22, -0.35, 0.8, 0.5, 0.7), (0.15, 0.62, -0.1, 0.8, 0.5, 0.8))
    for k, (x, y, z, sx, sy, sz) in enumerate(pieces):
        a.append(P("sphere", (sx * s, sy * s, sz * s), (x * s, y * s, z * s), shade(col, 1.0 - k * 0.06), "stone", seg=5, rot=(k * 17, k * 40, k * 11)))
    for k in range(3):
        ang = k * 2.2
        a.append(P("sphere", (0.25 * s, 0.18 * s, 0.22 * s), (math.cos(ang) * 0.85 * s, 0.08, math.sin(ang) * 0.85 * s), shade(col, 0.9), "stone", seg=4))
    if moss:
        a.append(P("sphere", (1.1 * s, 0.3 * s, 0.9 * s), (-0.1 * s, 0.78 * s, 0.05 * s), moss, "leaf", seg=6))
    if veins:
        for k in range(5):
            ang = k * 1.3
            a.append(P("box", (0.5 * s, 0.07 * s, 0.1 * s), (math.cos(ang) * 0.55 * s, (0.35 + (k % 3) * 0.18) * s, math.sin(ang) * 0.5 * s), veins, "metal",
                       rot=(k * 30, -math.degrees(ang), 20 + k * 9)))
    if crystal:
        for (x, y, z, h, rx, rz) in ((-0.2, 0.75, 0.1, 0.7, 0, 15), (0.35, 0.6, -0.25, 0.5, 10, -20), (0.05, 0.7, 0.4, 0.45, -18, 8), (-0.5, 0.45, -0.3, 0.4, 12, 30)):
            a.append(P("prism", (0.26 * s, h * s, 0.26 * s), (x * s, y * s, z * s), crystal, "glow", rot=(rx, 0, rz), anim="pulse"))
    return a


def crystal_node():
    a = []
    a.append(P("sphere", (1.4, 0.5, 1.2), (0, 0.15, 0), "#3a3348", "stone", seg=5))
    for k, (x, z, h, rx, rz, col) in enumerate(((0, 0, 1.8, 0, 0, "#b34dff"), (0.4, 0.2, 1.1, 10, -25, "#cc66ff"), (-0.35, -0.15, 0.95, 15, 30, "#9933ff"),
                                                 (0.15, -0.45, 0.8, -25, -10, "#d9a6ff"), (-0.3, 0.4, 0.7, 20, 20, "#b34dff"), (0.55, -0.3, 0.6, -15, -35, "#9933ff"))):
        a.append(P("prism", (0.45 - k * 0.04, h, 0.45 - k * 0.04), (x, h / 2 + 0.1, z), col, "glow", rot=(rx, k * 30, rz), anim="pulse"))
    for k in range(6):
        ang = k * 1.05
        a.append(P("prism", (0.1, 0.25, 0.1), (math.cos(ang) * 0.75, 0.15, math.sin(ang) * 0.65), "#e6ccff", "glow", rot=(0, 0, 40 * math.cos(ang)), anim="pulse"))
    return a


def all_models():
    return {
        "tree_pine": M("Ель", pine("#543823", "#1f4d24"), "Флора"),
        "tree_fir": M("Пихта", pine("#4a301d", "#2b5c2e", 1.25, layers=5), "Флора"),
        "tree_oak": M("Дуб", oak(), "Флора"),
        "tree_birch": M("Берёза", birch(), "Флора"),
        "tree_dead": M("Сухое дерево", dead_tree(), "Флора"),
        "stump": M("Пень", stump(), "Флора"),
        "bush_berry": M("Ягодный куст", bush_berry(), "Флора"),
        "rock_big": M("Валун", rock_shape("#7d7b76", moss="#4f7a3a"), "Камни и руда"),
        "rock_small": M("Камень", rock_shape("#8c8a85", s=0.55), "Камни и руда"),
        "ore_iron": M("Железная руда", rock_shape("#8a5547", veins="#c08070", crystal="#b37a66"), "Камни и руда"),
        "ore_copper": M("Медная руда", rock_shape("#8c6640", veins="#e08a3a", crystal="#ff8c33"), "Камни и руда"),
        "ore_coal": M("Уголь", rock_shape("#2e2e33", veins="#141418"), "Камни и руда"),
        "ore_quartz": M("Кварц", rock_shape("#9aa3ad", crystal="#e6f2ff"), "Камни и руда"),
        "ore_sulfur": M("Сера", rock_shape("#8c8a52", veins="#d9d040", crystal="#f2e633"), "Камни и руда"),
        "crystal": M("Кристалл", crystal_node(), "Камни и руда"),
    }
