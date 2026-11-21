# Подробные модели предметов на земле и в руках (12.2). Белые детали (#ffffff) красятся в цвет предмета.
import math
from art_kit import P, M, shade

W = "#ffffff"
WOOD_H, WOOD_D = "#7a5230", "#4a2e1a"
STEEL, DARK, BRASS, LEATHER = "#b8bec7", "#2a2d33", "#c9a227", "#5a3a22"


def axe():
    return [
        P("cylinder", (0.07, 0.9, 0.07), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7),
        P("torus", (0.1, 0.25, 0.1), (0, -0.3, 0), LEATHER, "cloth", tint=False, seg=8),
        P("torus", (0.1, 0.25, 0.1), (0, -0.25, 0), LEATHER, "cloth", tint=False, seg=8),
        P("sphere", (0.1, 0.06, 0.1), (0, -0.46, 0), WOOD_D, "wood", tint=False, seg=6),
        P("box", (0.26, 0.24, 0.06), (0.12, 0.3, 0), W, "metal"),
        P("prism", (0.14, 0.34, 0.06), (0.3, 0.3, 0), W, "metal", rot=(0, 0, -90)),
        P("box", (0.03, 0.34, 0.065), (0.36, 0.3, 0), "#e8eef4", "metal", tint=False),
        P("box", (0.12, 0.12, 0.08), (-0.06, 0.32, 0), DARK, "dark", tint=False),
        P("cylinder", (0.03, 0.09, 0.03), (0.02, 0.32, 0), BRASS, "metal", tint=False, rot=(90, 0, 0), seg=6),
    ]


def pickaxe():
    return [
        P("cylinder", (0.07, 0.9, 0.07), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7),
        P("torus", (0.1, 0.25, 0.1), (0, -0.28, 0), LEATHER, "cloth", tint=False, seg=8),
        P("box", (0.12, 0.14, 0.1), (0, 0.38, 0), DARK, "dark", tint=False),
        P("cylinder", (0.07, 0.42, 0.07), (0.22, 0.4, 0), W, "metal", rot=(0, 0, -80), top=0.15, seg=6),
        P("cylinder", (0.07, 0.42, 0.07), (-0.22, 0.4, 0), W, "metal", rot=(0, 0, 80), top=0.15, seg=6),
        P("cylinder", (0.03, 0.12, 0.03), (0, 0.38, 0), BRASS, "metal", tint=False, rot=(90, 0, 0), seg=6),
    ]


def sword():
    return [
        P("box", (0.1, 0.68, 0.025), (0, 0.2, 0), W, "metal"),
        P("box", (0.02, 0.6, 0.03), (0, 0.18, 0), "#e8eef4", "metal", tint=False),
        P("prism", (0.1, 0.14, 0.025), (0, 0.61, 0), W, "metal"),
        P("box", (0.34, 0.05, 0.08), (0, -0.16, 0), BRASS, "metal", tint=False),
        P("sphere", (0.07, 0.07, 0.07), (0.17, -0.16, 0), BRASS, "metal", tint=False, seg=6),
        P("sphere", (0.07, 0.07, 0.07), (-0.17, -0.16, 0), BRASS, "metal", tint=False, seg=6),
        P("cylinder", (0.06, 0.2, 0.06), (0, -0.29, 0), LEATHER, "cloth", tint=False, seg=6),
        P("torus", (0.07, 0.3, 0.07), (0, -0.25, 0), BRASS, "metal", tint=False, seg=6),
        P("sphere", (0.09, 0.09, 0.09), (0, -0.41, 0), BRASS, "metal", tint=False, seg=8),
        P("sphere", (0.04, 0.04, 0.03), (0, -0.16, 0.04), "#e0263d", "glow", tint=False),
    ]


def knife():
    return [
        P("prism", (0.09, 0.38, 0.025), (0, 0.12, 0), W, "metal"),
        P("box", (0.015, 0.3, 0.03), (-0.025, 0.1, 0), "#e8eef4", "metal", tint=False),
        P("box", (0.16, 0.04, 0.06), (0, -0.08, 0), DARK, "dark", tint=False),
        P("cylinder", (0.065, 0.22, 0.065), (0, -0.2, 0), WOOD_D, "wood", tint=False, seg=6),
        P("torus", (0.07, 0.3, 0.07), (0, -0.14, 0), DARK, "dark", tint=False, seg=6),
        P("torus", (0.07, 0.3, 0.07), (0, -0.24, 0), DARK, "dark", tint=False, seg=6),
    ]


def gun():
    return [
        P("box", (0.5, 0.15, 0.12), (0.05, 0.1, 0), W, "metal"),
        P("box", (0.3, 0.06, 0.13), (0.1, 0.2, 0), DARK, "dark", tint=False),
        P("cylinder", (0.08, 0.34, 0.08), (0.42, 0.11, 0), DARK, "dark", rot=(0, 0, 90), tint=False, seg=10),
        P("torus", (0.11, 0.3, 0.11), (0.35, 0.11, 0), "#40c8ff", "glow", rot=(0, 0, 90), tint=False, seg=10),
        P("torus", (0.11, 0.3, 0.11), (0.45, 0.11, 0), "#40c8ff", "glow", rot=(0, 0, 90), tint=False, seg=10),
        P("box", (0.12, 0.28, 0.1), (-0.13, -0.08, 0), DARK, "dark", rot=(0, 0, -15), tint=False),
        P("box", (0.03, 0.1, 0.02), (-0.03, -0.02, 0), DARK, "dark", tint=False),
        P("torus", (0.12, 0.2, 0.06), (-0.02, -0.03, 0), DARK, "dark", rot=(90, 0, 0), tint=False, seg=8),
        P("box", (0.16, 0.04, 0.13), (0.08, 0.2, 0), "#40c8ff", "glow", tint=False, anim="pulse"),
        P("cylinder", (0.06, 0.16, 0.06), (0.05, 0.27, 0), DARK, "dark", rot=(0, 0, 90), tint=False, seg=8),
        P("cylinder", (0.05, 0.02, 0.05), (0.14, 0.27, 0), "#ff3b2f", "glow", rot=(0, 0, 90), tint=False, seg=8),
        P("box", (0.08, 0.12, 0.14), (-0.2, 0.1, 0), "#3a3f47", "metal", tint=False),
    ]


def medkit():
    return [
        P("box", (0.5, 0.34, 0.2), (0, 0, 0), "#f2f2f2", "paint", tint=False),
        P("box", (0.52, 0.04, 0.21), (0, 0.06, 0), "#d0d0d0", "paint", tint=False),
        P("box", (0.24, 0.08, 0.21), (0, -0.04, 0), "#e0263d", "paint", tint=False),
        P("box", (0.08, 0.24, 0.21), (0, -0.04, 0), "#e0263d", "paint", tint=False),
        P("torus", (0.18, 0.3, 0.06), (0, 0.21, 0), DARK, "dark", rot=(90, 0, 0), tint=False, seg=8),
        P("box", (0.04, 0.06, 0.04), (0.2, 0.16, 0.09), "#9aa3ad", "metal", tint=False),
        P("box", (0.04, 0.06, 0.04), (-0.2, 0.16, 0.09), "#9aa3ad", "metal", tint=False),
    ]


def grenade():
    a = [P("sphere", (0.34, 0.42, 0.34), (0, 0, 0), W, "metal", seg=10)]
    for k in range(4):
        a.append(P("torus", (0.35, 0.08, 0.35), (0, -0.14 + k * 0.09, 0), shade("#5a6a3a", 0.8), "dark", tint=False, seg=10))
    a += [
        P("cylinder", (0.14, 0.12, 0.14), (0, 0.24, 0), "#8c949e", "metal", tint=False, seg=8),
        P("box", (0.06, 0.22, 0.05), (0.08, 0.2, 0), "#8c949e", "metal", tint=False, rot=(0, 0, -15)),
        P("torus", (0.14, 0.12, 0.14), (-0.1, 0.32, 0), BRASS, "metal", rot=(90, 0, 0), tint=False, seg=10),
    ]
    return a


def ammo():
    a = [
        P("box", (0.5, 0.22, 0.32), (0, -0.05, 0), "#5a6a3a", "metal", tint=False),
        P("box", (0.52, 0.04, 0.34), (0, 0.04, 0), "#3e4a28", "metal", tint=False),
        P("box", (0.2, 0.08, 0.02), (0, -0.05, 0.165), "#f2d24a", "paint", tint=False),
        P("box", (0.14, 0.04, 0.06), (0, 0.09, 0), DARK, "dark", tint=False),
    ]
    for i in range(5):
        a.append(P("cylinder", (0.06, 0.16, 0.06), (-0.17 + i * 0.085, 0.13, 0.06), BRASS, "metal", tint=False, seg=6))
        a.append(P("cone", (0.06, 0.06, 0.06), (-0.17 + i * 0.085, 0.24, 0.06), "#b87333", "metal", tint=False, seg=6))
    return a


def battery():
    return [
        P("cylinder", (0.26, 0.48, 0.26), (0, 0, 0), W, "metal", seg=12),
        P("cylinder", (0.27, 0.12, 0.27), (0, -0.18, 0), DARK, "dark", tint=False, seg=12),
        P("cylinder", (0.1, 0.06, 0.1), (0, 0.27, 0), "#b8bec7", "metal", tint=False, seg=8),
        P("box", (0.06, 0.18, 0.02), (0, 0.03, 0.13), "#40ff6a", "glow", tint=False, anim="pulse"),
        P("torus", (0.27, 0.1, 0.27), (0, 0.18, 0), DARK, "dark", tint=False, seg=12),
    ]


def gear():
    return [
        P("gear", (0.5, 0.12, 0.5), (0, 0, 0), W, "metal", rot=(90, 0, 0), seg=12, top=0.78),
        P("cylinder", (0.18, 0.14, 0.18), (0, 0, 0), shade("#8c949e", 0.8), "metal", rot=(90, 0, 0), tint=False, seg=10),
        P("cylinder", (0.08, 0.16, 0.08), (0, 0, 0), DARK, "dark", rot=(90, 0, 0), tint=False, seg=6),
    ]


def ingot():
    return [
        P("box", (0.5, 0.14, 0.26), (0, 0, 0), W, "metal"),
        P("box", (0.42, 0.06, 0.18), (0, 0.09, 0), W, "metal"),
        P("box", (0.12, 0.01, 0.06), (0, 0.125, 0), shade("#8c949e", 0.6), "metal", tint=False),
    ]


def log():
    return [
        P("cylinder", (0.32, 0.9, 0.32), (0, 0, 0), "#7a5230", "wood", rot=(0, 0, 90), seg=8),
        P("cylinder", (0.29, 0.02, 0.29), (0.455, 0, 0), "#c49a6c", "wood", rot=(0, 0, 90), seg=8),
        P("cylinder", (0.29, 0.02, 0.29), (-0.455, 0, 0), "#c49a6c", "wood", rot=(0, 0, 90), seg=8),
        P("torus", (0.18, 0.06, 0.18), (0.465, 0, 0), "#a07a50", "wood", rot=(0, 0, 90), seg=10),
        P("cylinder", (0.06, 0.18, 0.06), (0.1, 0.17, 0.05), "#7a5230", "wood", rot=(20, 0, 10), seg=5),
        P("sphere", (0.1, 0.04, 0.14), (-0.2, 0.15, 0), "#4f8a3a", "leaf"),
    ]


def plank():
    return [
        P("box", (0.7, 0.07, 0.2), (0, 0, 0), "#c49a6c", "wood", rot=(0, 10, 0)),
        P("box", (0.7, 0.07, 0.2), (0.03, 0.08, 0.05), "#b48a5c", "wood", rot=(0, -6, 0)),
        P("box", (0.7, 0.07, 0.2), (-0.02, 0.16, -0.02), "#c49a6c", "wood", rot=(0, 18, 0)),
    ]


def ore():
    return [
        P("sphere", (0.42, 0.34, 0.38), (0, 0, 0), W, "stone", seg=5),
        P("sphere", (0.24, 0.2, 0.22), (0.15, 0.08, 0.1), W, "stone", seg=4),
        P("prism", (0.08, 0.14, 0.08), (-0.06, 0.15, -0.05), "#ffffff", "glow", rot=(0, 0, 20)),
        P("prism", (0.06, 0.1, 0.06), (0.1, 0.14, -0.08), "#ffffff", "glow", rot=(10, 0, -15)),
    ]


def plate():
    return [
        P("box", (0.46, 0.04, 0.46), (0, 0, 0), W, "metal"),
        P("box", (0.46, 0.04, 0.46), (0.02, 0.05, 0.02), W, "metal", rot=(0, 8, 0)),
    ] + [P("cylinder", (0.04, 0.02, 0.04), (x, 0.08, z), "#8c949e", "metal", tint=False, seg=6) for x in (-0.18, 0.18) for z in (-0.18, 0.18)]


def circuit():
    a = [P("box", (0.48, 0.03, 0.34), (0, 0, 0), "#1f6b3d", "paint", tint=False)]
    for k in range(3):
        a.append(P("box", (0.1, 0.04, 0.1), (-0.14 + k * 0.14, 0.03, -0.06), DARK, "dark", tint=False))
    for k in range(5):
        a.append(P("box", (0.3, 0.005, 0.01), (0.02, 0.017, -0.12 + k * 0.06), BRASS, "metal", tint=False))
    a.append(P("cylinder", (0.06, 0.08, 0.06), (0.16, 0.05, 0.1), "#2f6fc4", "paint", tint=False, seg=8))
    a.append(P("sphere", (0.04, 0.04, 0.04), (-0.18, 0.04, 0.12), "#ff3b2f", "glow", tint=False, anim="blink"))
    return a


def wire():
    return [
        P("cylinder", (0.4, 0.06, 0.4), (0, 0.12, 0), "#7a5230", "wood", tint=False, rot=(90, 0, 0), seg=12),
        P("cylinder", (0.4, 0.06, 0.4), (0, 0.12, 0.2), "#7a5230", "wood", tint=False, rot=(90, 0, 0), seg=12),
        P("cylinder", (0.3, 0.18, 0.3), (0, 0.12, 0.1), "#d9822b", "metal", tint=False, rot=(90, 0, 0), seg=12),
        P("torus", (0.31, 0.1, 0.31), (0, 0.12, 0.05), "#b86b20", "metal", tint=False, rot=(90, 0, 0), seg=12),
        P("torus", (0.31, 0.1, 0.31), (0, 0.12, 0.15), "#b86b20", "metal", tint=False, rot=(90, 0, 0), seg=12),
    ]


def motor():
    a = [P("cylinder", (0.3, 0.38, 0.3), (0, 0, 0), W, "metal", rot=(0, 0, 90), seg=12)]
    for k in range(4):
        a.append(P("torus", (0.32, 0.08, 0.32), (-0.13 + k * 0.09, 0, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=12))
    a += [
        P("cylinder", (0.06, 0.14, 0.06), (0.25, 0, 0), "#b8bec7", "metal", tint=False, rot=(0, 0, 90), seg=8),
        P("box", (0.14, 0.1, 0.12), (0, 0.18, 0), DARK, "dark", tint=False),
        P("box", (0.4, 0.04, 0.3), (0, -0.17, 0), DARK, "dark", tint=False),
    ]
    return a


def all_models():
    return {
        "drop_axe": M("Топор", axe(), "Предметы"),
        "drop_pickaxe": M("Кирка", pickaxe(), "Предметы"),
        "drop_sword": M("Меч", sword(), "Предметы"),
        "drop_knife": M("Нож", knife(), "Предметы"),
        "drop_gun": M("Бластер", gun(), "Предметы"),
        "drop_medkit": M("Аптечка", medkit(), "Предметы"),
        "drop_grenade": M("Граната", grenade(), "Предметы"),
        "drop_ammo": M("Патроны", ammo(), "Предметы"),
        "drop_battery": M("Батарея", battery(), "Предметы"),
        "drop_gear": M("Шестерня", gear(), "Предметы"),
        "drop_ingot": M("Слиток", ingot(), "Предметы"),
        "drop_log": M("Бревно", log(), "Предметы"),
        "drop_plank": M("Доски", plank(), "Предметы"),
        "drop_ore": M("Кусок руды", ore(), "Предметы"),
        "drop_plate": M("Пластина", plate(), "Предметы"),
        "drop_circuit": M("Микросхема", circuit(), "Предметы"),
        "drop_wire": M("Провод", wire(), "Предметы"),
        "drop_motor": M("Мотор", motor(), "Предметы"),
    }
