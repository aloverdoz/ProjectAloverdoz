# Каталог — ЗДАНИЯ, часть 1: производственные машины (20 видов × 5 уровней), энергетика, хранение, жидкости.
# Клетка 2×2 м: здание размера 1 стоит в квадрате -1..1 по X и Z, выход машин — по +X.
import math
from art_kit import *
from cat_detail import detail_machine, detail_base
from art_buildings import foundation_pad, io_marks, chimney, CONC, BRICK, WOOD, WOOD_D

buildings, models = {}, {}
BRASS = "#c9a227"
TIERS = [("Mk1", YEL, "#ffd27a"), ("Mk2", "#2e6bc7", "#40c8ff"), ("Mk3", "#2fa84f", "#7dff5a"), ("Mk4", "#c7302e", "#ff8c1a"), ("Mk5", "#7a2ec7", "#d9a6ff")]


def B(id, name, desc, cat, behavior, cost, parts, hp=300, size=1, params=None, blocks=None, emit=None, mcat="Здания", catalog=""):
    m = M(name, parts, "Каталог: " + (catalog or mcat))
    if emit:
        m["emitters"] = emit
    models["cb_" + id] = m
    d = {"name": name, "desc": desc, "category": cat, "behavior": behavior, "cost": cost, "model": "cb_" + id, "hp": hp, "size": size,
         "params": params or {}, "catalog": catalog or mcat}
    if blocks:
        d["blocks"] = blocks
    buildings[id] = d


def chassis(a, main, tier, acc):
    """Общая основа машины: плита, рама, щиток, пульт, отметки уровня и входы/выход."""
    foundation_pad(a)
    a.append(P("box", (1.7, 0.1, 1.7), (0, 0.23, 0), shade(main, 0.55), "dark"))
    for x in (-0.78, 0.78):
        for z in (-0.78, 0.78):
            a.append(P("box", (0.12, 0.12, 0.12), (x, 0.32, z), DARK, "dark"))
    panel(a, -0.8, 0.75, -0.5, main, face=-1, w=0.46, h=0.7, screen=acc)
    tier_pips(a, -0.97, 1.25, -0.5, tier, acc)
    io_marks(a, 0.22)
    if tier >= 3:
        beacon(a, -0.8, 1.15, 0.6, acc)
    if tier >= 4:
        energy_ring(a, 0, 0.32, 0, 0.92, acc, thick=0.12)
    if tier >= 2:
        for k in range(tier - 1):
            a.append(P("torus", (0.22, 0.22, 0.08), (-0.86, 0.5 + k * 0.08, 0.1 + k * 0.1), RUB, "cloth", rot=(0, 0, 90), seg=10))


# ------------------------------------------------------------------ виды машин (верхняя часть)
def k_crusher(a, M_, A, t):
    a.append(P("box", (1.1, 0.8, 1.0), (0.1, 0.75, 0), M_))
    a.append(P("cone", (1.1, 0.6, 1.0), (0.1, 1.45, 0), shade(M_, 0.8), seg=4, rot=(180, 45, 0)))
    for z in (-0.25, 0.25):
        a.append(P("cylinder", (0.4, 0.7, 0.4), (0.1, 1.05, z), CHR, "metal", rot=(90, 0, 0), seg=12, anim="spin_fast"))
        for k in range(3):
            a.append(P("box", (0.48, 0.72, 0.06), (0.1, 1.05, z), STEEL, "metal", rot=spun((90, 0, 0), k * 60), anim="spin_fast"))
    gearbox(a, 0.1, 0.75, 0.62, 0.7, 0.5, 0.2, DARK, A)
    chute(a, 0.72, 0.5, 0, M_)


def k_sawmill(a, M_, A, t):
    a.append(P("box", (1.6, 0.12, 0.7), (0, 0.85, 0), WOOD, "wood"))
    for x in (-0.65, 0.65):
        for z in (-0.28, 0.28):
            a.append(P("box", (0.1, 0.55, 0.1), (x, 0.55, z), M_))
    a.append(P("gear", (0.95, 0.03, 0.95), (0, 1.0, 0), CHR, "metal", rot=(90, 0, 0), seg=24, top=0.9, anim="spin_fast"))
    a.append(P("cylinder", (0.2, 0.06, 0.2), (0, 1.0, 0), DARK, "dark", rot=(90, 0, 0), seg=8, anim="spin_fast"))
    a.append(P("box", (0.6, 0.35, 0.3), (0, 1.3, 0), M_))
    a.append(P("cylinder", (0.3, 0.9, 0.3), (-0.4, 1.05, 0.0), WOOD_D, "wood", rot=(0, 0, 90), seg=10, anim="jitter"))
    motor(a, 0.5, 0.55, -0.55, 0.15, 0.3, A, axis="z")


def k_press(a, M_, A, t):
    for x in (-0.55, 0.55):
        a.append(P("box", (0.22, 1.9, 0.5), (x, 1.2, 0), M_))
    a.append(P("box", (1.4, 0.35, 0.6), (0, 2.2, 0), M_))
    a.append(P("box", (0.9, 0.2, 0.5), (0, 0.5, 0), DARK, "dark"))
    piston(a, 0, 1.6, 0, 0.9, 0.18, CHR, tilt=(180, 0, 0))
    a.append(P("box", (0.8, 0.12, 0.45), (0, 1.0, 0), STEEL, "metal", anim="piston"))
    a.append(P("box", (1.42, 0.06, 0.62), (0, 2.4, 0), A))
    for k in range(4):
        a.append(P("box", (0.12, 0.04, 0.62), (-0.45 + k * 0.3, 2.21, 0.01), DARK, "dark", rot=(0, 45, 0)))


def k_lathe(a, M_, A, t):
    a.append(P("box", (1.6, 0.55, 0.6), (0, 0.55, 0), M_))
    a.append(P("box", (1.5, 0.08, 0.3), (0, 0.86, 0), STEEL, "metal"))
    a.append(P("box", (0.45, 0.5, 0.55), (-0.55, 1.1, 0), shade(M_, 0.85)))
    a.append(P("cylinder", (0.32, 0.15, 0.32), (-0.27, 1.1, 0), CHR, "metal", rot=(0, 0, 90), seg=12, anim="spin_fast"))
    a.append(P("cylinder", (0.1, 0.7, 0.1), (0.15, 1.1, 0), A, "metal", rot=(0, 0, 90), seg=10, anim="spin_fast"))
    a.append(P("box", (0.25, 0.25, 0.35), (0.6, 1.05, 0), shade(M_, 0.85)))
    a.append(P("cylinder", (0.08, 0.3, 0.08), (0.42, 1.1, 0), CHR, "metal", rot=(0, 0, 90), seg=8))
    a.append(P("box", (0.2, 0.15, 0.25), (0.1, 0.95, 0.15), DARK, "dark", anim="jitter"))
    a.append(P("cylinder", (0.18, 0.04, 0.18), (0.1, 0.95, 0.42), CHR, "metal", rot=(90, 0, 0), seg=10))


def k_kiln(a, M_, A, t):
    a.append(P("cylinder", (1.3, 0.9, 1.3), (0, 0.75, 0), BRICK, "stone", seg=12))
    a.append(P("sphere", (1.3, 0.9, 1.3), (0, 1.2, 0), shade(BRICK, 0.9), "stone", seg=12))
    for k in range(4):
        a.append(P("torus", (1.33, 0.06, 1.33), (0, 0.4 + k * 0.2, 0), M_, "metal", seg=12))
    a.append(P("box", (0.45, 0.4, 0.1), (0.6, 0.65, 0), "#ff6a1a", "glow", anim="flicker"))
    a.append(P("box", (0.55, 0.5, 0.06), (0.62, 0.65, 0), DARK, "dark"))
    chimney(a, -0.35, -0.35, 1.3, 0.9, 0.12, M_, brick=False)


def k_chem(a, M_, A, t):
    tank_v(a, -0.35, 0.3, -0.3, 0.3, 1.1, M_)
    tank_v(a, 0.35, 0.3, 0.3, 0.25, 0.8, shade(M_, 1.2))
    a.append(P("sphere", (0.55, 0.55, 0.55), (0.35, 0.65, -0.4), "#9fe8ff", "glass", seg=12))
    a.append(P("sphere", (0.4, 0.4, 0.4), (0.35, 0.65, -0.4), A, "glow", anim="pulse", seg=10))
    pipe_run(a, [(-0.35, 1.6, -0.3), (-0.35, 1.75, 0.3), (0.35, 1.75, 0.3), (0.35, 1.2, 0.3)], 0.06, STEEL)
    pipe_run(a, [(0.35, 0.95, -0.4), (0.35, 1.4, -0.4), (-0.1, 1.4, -0.4)], 0.05, A)


def k_electro(a, M_, A, t):
    a.append(P("box", (1.4, 0.6, 1.0), (0.1, 0.6, 0), "#9fe8ff", "glass"))
    a.append(P("box", (1.44, 0.08, 1.04), (0.1, 0.92, 0), M_))
    for k in range(4):
        x = -0.4 + k * 0.33
        a.append(P("box", (0.06, 0.65, 0.8), (x, 0.65, 0), DARK if k % 2 else CHR, "metal"))
        a.append(P("cylinder", (0.08, 0.25, 0.08), (x, 1.05, 0.3), "#c87533" if k % 2 else "#c03020", "metal", seg=8))
    for k in range(5):
        a.append(P("sphere", (0.05, 0.05, 0.05), (-0.3 + k * 0.2, 0.5 + (k % 2) * 0.2, -0.1 + (k % 3) * 0.1), "#ffffff", "glow", anim="bob"))
    coil(a, 0.65, 0.95, 0.0, 0.14, 0.5, "#c87533")


def k_loom(a, M_, A, t):
    for x in (-0.6, 0.6):
        a.append(P("box", (0.1, 1.6, 0.1), (x, 1.05, -0.35), WOOD, "wood"))
        a.append(P("box", (0.1, 1.6, 0.1), (x, 1.05, 0.35), WOOD, "wood"))
    a.append(P("box", (1.3, 0.1, 0.8), (0, 1.85, 0), WOOD, "wood"))
    a.append(P("box", (1.2, 0.04, 0.7), (0, 0.85, 0), "#e6dcc8", "cloth"))
    for k in range(10):
        a.append(P("box", (0.015, 1.0, 0.015), (-0.5 + k * 0.11, 1.35, 0), A, "cloth"))
    a.append(P("box", (1.25, 0.08, 0.08), (0, 1.3, 0), M_, anim="piston_small"))
    a.append(P("cylinder", (0.2, 1.2, 0.2), (0, 0.55, 0.35), "#e6dcc8", "cloth", rot=(0, 0, 90), seg=12, anim="spin_slow"))


def k_centrifuge(a, M_, A, t):
    a.append(P("cylinder", (1.3, 0.7, 1.3), (0, 0.65, 0), M_, seg=20))
    a.append(P("cylinder", (1.1, 0.1, 1.1), (0, 1.05, 0), "#9fe8ff", "glass", seg=20))
    a.append(P("cylinder", (0.9, 0.3, 0.9), (0, 1.0, 0), CHR, "metal", seg=8, anim="spin_fast"))
    for k in range(4):
        ang = k * math.pi / 2
        a.append(P("capsule", (0.18, 0.4, 0.18), (math.cos(ang) * 0.32, 1.0, math.sin(ang) * 0.32), A, "glow", rot=(90, 0, 0), anim="pulse"))
    for k in range(3):
        a.append(P("torus", (1.34, 0.08, 1.34), (0, 0.4 + k * 0.25, 0), DARK, "dark", seg=20))


def k_welder(a, M_, A, t):
    a.append(P("box", (1.3, 0.4, 1.0), (0, 0.5, 0), STEEL, "metal"))
    a.append(P("box", (0.5, 0.2, 0.4), (0.1, 0.8, 0), "#5c6370", "metal", anim="jitter"))
    a.append(P("cylinder", (0.3, 0.2, 0.3), (-0.5, 0.8, 0.3), DARK, "dark", seg=10))
    a.append(P("cylinder", (0.12, 0.7, 0.12), (-0.5, 1.2, 0.3), M_, rot=(0, 0, -30), anim="swing", seg=8))
    a.append(P("box", (0.1, 0.6, 0.1), (-0.15, 1.4, 0.3), M_, rot=(0, 0, 60), anim="swing"))
    a.append(P("cone", (0.08, 0.2, 0.08), (0.08, 1.15, 0.3), CHR, "metal", rot=(0, 0, 150), anim="swing"))
    a.append(P("sphere", (0.1, 0.1, 0.1), (0.12, 0.92, 0.1), "#bfe8ff", "glow", anim="flicker"))
    tank_v(a, 0.6, 0.3, -0.55, 0.12, 0.7, "#c03020")
    tank_v(a, 0.85, 0.3, -0.55, 0.12, 0.7, "#2e6bc7")


def k_fab(a, M_, A, t):
    a.append(P("box", (1.5, 1.1, 1.3), (0, 0.85, 0), "#e6eaee", "paint"))
    window_strip(a, 0.76, 0.95, 0, 1.0, 0.6, "z", M_)
    a.append(P("box", (1.54, 0.12, 1.34), (0, 1.45, 0), M_))
    for k in range(3):
        a.append(P("cylinder", (0.22, 0.12, 0.22), (-0.45 + k * 0.45, 1.56, 0.3), DARK, "dark", seg=12))
        a.append(P("cylinder", (0.18, 0.02, 0.18), (-0.45 + k * 0.45, 1.62, 0.3), STEEL, "metal", seg=8, anim="spin_fan"))
    a.append(P("box", (0.8, 0.04, 0.6), (0.3, 0.75, 0), "#1f6b3d", "paint"))
    for k in range(4):
        a.append(P("box", (0.12, 0.03, 0.12), (0.05 + k * 0.17, 0.79, 0.05 * (k % 2)), "#2a2d33", "dark"))
    a.append(P("box", (0.03, 0.4, 0.03), (0.3, 1.0, 0.0), A, "glow", anim="pulse"))


def k_foundry(a, M_, A, t):
    a.append(P("cylinder", (0.9, 0.8, 0.9), (-0.2, 0.75, 0), BRICK, "stone", seg=10))
    a.append(P("cylinder", (0.7, 0.06, 0.7), (-0.2, 1.17, 0), "#ff6a1a", "glow", seg=10, anim="flicker"))
    a.append(P("cylinder", (0.4, 0.4, 0.4), (0.5, 1.2, 0), DARK, "dark", seg=10, top=0.8, rot=(0, 0, -25), anim="sway"))
    a.append(P("box", (0.1, 1.4, 0.1), (0.5, 1.0, -0.35), M_))
    a.append(P("box", (0.1, 1.4, 0.1), (0.5, 1.0, 0.35), M_))
    a.append(P("box", (0.1, 0.1, 0.8), (0.5, 1.7, 0), M_))
    a.append(P("box", (0.6, 0.06, 0.3), (0.55, 0.45, 0), "#ff8c1a", "glow", anim="pulse"))
    chimney(a, -0.5, -0.5, 1.15, 1.0, 0.14, BRICK)


def k_mixer(a, M_, A, t):
    a.append(P("cylinder", (1.2, 0.9, 1.2), (0, 0.8, 0), CHR, "metal", seg=18, top=0.85))
    a.append(P("cylinder", (1.05, 0.04, 1.05), (0, 1.22, 0), A, "paint", seg=18))
    a.append(P("box", (1.3, 0.12, 0.2), (0, 1.5, 0), M_))
    a.append(P("cylinder", (0.06, 0.6, 0.06), (0, 1.2, 0), STEEL, "metal", seg=6, anim="spin"))
    for k in range(3):
        a.append(P("box", (0.6, 0.05, 0.08), (0, 1.05 - k * 0.12, 0), STEEL, "metal", rot=(0, k * 60, 0), anim="spin"))
    motor(a, 0, 1.75, 0, 0.16, 0.3, M_)
    for x in (-0.6, 0.6):
        a.append(P("box", (0.08, 1.2, 0.08), (x, 0.9, 0), M_))


def k_distill(a, M_, A, t):
    a.append(P("cylinder", (0.5, 2.2, 0.5), (-0.3, 1.4, 0), "#c87533", "metal", seg=14))
    for k in range(5):
        a.append(P("torus", (0.54, 0.08, 0.54), (-0.3, 0.6 + k * 0.4, 0), DARK, "dark", seg=14))
    a.append(P("sphere", (0.8, 0.6, 0.8), (0.35, 0.65, 0), "#c87533", "metal", seg=14))
    pipe_run(a, [(-0.3, 2.5, 0), (0.4, 2.5, 0), (0.4, 1.5, 0)], 0.05, "#c87533")
    coil(a, 0.45, 0.95, 0.4, 0.1, 0.5, "#c87533")
    ladder(a, -0.6, 0.0, 0.3, 2.3, M_, along="z")


def k_compactor(a, M_, A, t):
    a.append(P("box", (1.4, 1.0, 1.2), (0, 0.8, 0), M_))
    a.append(P("box", (1.0, 0.2, 0.8), (0, 1.4, 0), DARK, "dark"))
    for z in (-0.3, 0.3):
        piston(a, 0, 1.5, z, 0.6, 0.1, CHR)
    for k in range(5):
        a.append(P("box", (0.05, 0.8, 1.22), (-0.6 + k * 0.3, 0.8, 0), shade(M_, 0.75)))
    a.append(P("box", (0.4, 0.3, 0.4), (0.75, 0.45, 0), "#7a5230", "wood"))


def k_sorter(a, M_, A, t):
    a.append(P("box", (1.5, 0.08, 0.5), (0, 0.85, 0), "#2a2d33", "belt"))
    a.append(P("box", (1.5, 0.3, 0.06), (0, 0.95, 0.27), M_))
    a.append(P("box", (1.5, 0.3, 0.06), (0, 0.95, -0.27), M_))
    a.append(P("box", (0.5, 0.5, 0.6), (0, 1.35, 0), M_))
    a.append(P("cylinder", (0.25, 0.02, 0.25), (0.26, 1.35, 0), "#40ff6a", "glow", rot=(0, 0, 90), anim="blink", seg=12))
    for k in range(3):
        a.append(P("box", (0.1, 0.4, 0.04), (-0.4 + k * 0.4, 1.0, 0.0), A, rot=(0, 30 * (k - 1), 0), anim="swing"))
        a.append(P("box", (0.25, 0.15, 0.25), (-0.5 + k * 0.5, 0.95, 0), ["#e0263d", "#2f6fc4", "#2fb85a"][k], "paint", anim="jitter"))


def k_printer(a, M_, A, t):
    for x in (-0.65, 0.65):
        for z in (-0.6, 0.6):
            a.append(P("box", (0.08, 1.6, 0.08), (x, 1.05, z), M_))
    a.append(P("box", (1.38, 0.08, 1.28), (0, 1.85, 0), M_))
    a.append(P("box", (1.3, 0.06, 0.08), (0, 1.5, 0), STEEL, "metal", anim="sway"))
    a.append(P("box", (0.2, 0.2, 0.2), (0, 1.4, 0), DARK, "dark", anim="sway"))
    a.append(P("cone", (0.08, 0.12, 0.08), (0, 1.25, 0), A, "glow", rot=(180, 0, 0), anim="sway"))
    a.append(P("box", (1.0, 0.06, 1.0), (0, 0.5, 0), DARK, "dark"))
    a.append(P("cylinder", (0.4, 0.4, 0.4), (0, 0.75, 0), A, "paint", seg=6))
    a.append(P("cylinder", (0.35, 0.1, 0.35), (-0.55, 1.95, 0.4), "#e6e3d8", "paint", rot=(0, 0, 90), seg=12, anim="spin_slow"))


def k_bio(a, M_, A, t):
    a.append(P("cylinder", (1.1, 1.3, 1.1), (0, 1.0, 0), "#9fe8ff", "glass", seg=16))
    a.append(P("cylinder", (0.95, 1.0, 0.95), (0, 0.9, 0), "#5aff8a", "glow", seg=16, anim="breathe"))
    for k in range(6):
        a.append(P("sphere", (0.1, 0.1, 0.1), (math.cos(k) * 0.3, 0.6 + k * 0.15, math.sin(k) * 0.3), "#e6ffe6", "glow", anim="bob"))
    a.append(P("cylinder", (1.2, 0.15, 1.2), (0, 0.38, 0), M_, seg=16))
    a.append(P("cylinder", (1.2, 0.15, 1.2), (0, 1.7, 0), M_, seg=16))
    pipe_run(a, [(0.55, 1.6, 0), (0.85, 1.6, 0), (0.85, 0.4, 0)], 0.06, M_)


def k_crystal(a, M_, A, t):
    hex_base(a, 0.7, 0.45, 0.25, DARK, A)
    crystal_cluster(a, 0, 0.6, 0, A, 1.4)
    for k in range(3):
        ang = k * 2 * math.pi / 3
        x, z = math.cos(ang) * 0.7, math.sin(ang) * 0.7
        a.append(P("box", (0.12, 1.6, 0.12), (x, 1.2, z), M_))
        a.append(P("sphere", (0.18, 0.18, 0.18), (x, 2.05, z), A, "glow", anim="pulse"))
    energy_ring(a, 0, 1.6, 0, 0.6, A)


def k_packer(a, M_, A, t):
    a.append(P("box", (1.3, 0.9, 1.1), (-0.1, 0.75, 0), M_))
    a.append(P("box", (0.6, 0.06, 0.5), (0.55, 0.85, 0), "#2a2d33", "belt"))
    for k in range(3):
        a.append(P("box", (0.25, 0.22, 0.25), (0.4 + k * 0.12, 1.0 + k * 0.23, -0.1), "#c49a6c", "cloth", anim="jitter" if k == 0 else ""))
    a.append(P("box", (0.5, 0.1, 0.5), (-0.1, 1.25, 0), DARK, "dark"))
    piston(a, -0.1, 1.45, 0, 0.5, 0.1, CHR)
    a.append(P("cylinder", (0.35, 0.6, 0.35), (-0.4, 1.25, -0.4), "#e6e3d8", "paint", seg=12, anim="spin_slow"))


def k_kitchen(a, M_, A, t):
    a.append(P("box", (1.5, 0.8, 0.8), (0, 0.65, -0.3), "#d5dbe2", "metal"))
    for x in (-0.45, 0.0, 0.45):
        a.append(P("cylinder", (0.32, 0.03, 0.32), (x, 1.07, -0.3), DARK, "dark", seg=14))
        a.append(P("torus", (0.28, 0.1, 0.28), (x, 1.08, -0.3), "#ff6a1a", "glow", anim="flicker", seg=14))
    a.append(P("cylinder", (0.32, 0.25, 0.32), (-0.45, 1.2, -0.3), STEEL, "metal", seg=14))
    a.append(P("cylinder", (0.38, 0.06, 0.38), (0.45, 1.12, -0.3), "#2a2d33", "dark", seg=14))
    a.append(P("box", (0.6, 0.35, 0.03), (0, 0.6, 0.11), "#1b2d3a", "glass"))
    a.append(P("box", (0.5, 0.25, 0.02), (0, 0.6, 0.12), "#ff8c1a", "glow", anim="pulse"))
    a.append(P("box", (1.5, 0.6, 0.15), (0, 1.6, -0.62), "#d5dbe2", "metal"))
    exhaust(a, 0.5, 1.9, -0.62)


KINDS = [  # id, имя, описание, станция, цвет корпуса (None = цвет уровня), построитель
    ("crusher", "Дробилка", "Мелет руду и камень в порошок и щебень.", "workshop", k_crusher),
    ("sawmill", "Лесопилка", "Пилит брёвна на доски и балки.", "workbench", k_sawmill),
    ("press", "Пресс", "Штампует пластины и детали из слитков.", "workshop", k_press),
    ("lathe", "Токарный станок", "Точит валы, болты и шестерни.", "workshop", k_lathe),
    ("kiln", "Обжиговая печь", "Обжигает глину, кирпич и керамику.", "furnace", k_kiln),
    ("chem_plant", "Химический завод", "Смешивает кислоты, газы и растворы.", "refinery", k_chem),
    ("electrolyzer", "Электролизёр", "Разделяет растворы током: литий, алюминий, водород.", "refinery", k_electro),
    ("loom", "Ткацкий станок", "Ткёт ткань, брезент и кевлар.", "workshop", k_loom),
    ("centrifuge", "Центрифуга", "Обогащает руду и разделяет смеси.", "refinery", k_centrifuge),
    ("welder", "Сварочный цех", "Сваривает каркасы, балки и корпуса.", "assembler", k_welder),
    ("chip_fab", "Фабрика микросхем", "Чистая комната для плат и процессоров.", "assembler", k_fab),
    ("foundry", "Литейная", "Льёт сплавы и тяжёлые слитки.", "smelter", k_foundry),
    ("mixer", "Смеситель", "Замешивает бетон, удобрения и краски.", "workshop", k_mixer),
    ("distillery", "Перегонная колонна", "Перегоняет спирт, растворители и топливо.", "refinery", k_distill),
    ("compactor", "Уплотнитель", "Прессует мусор и биомассу в блоки.", "workshop", k_compactor),
    ("sorter", "Сортировщик", "Разбирает смешанные грузы и собирает наборы.", "assembler", k_sorter),
    ("printer3d", "3D-принтер", "Печатает пластиковые и металлические детали.", "assembler", k_printer),
    ("bioreactor", "Биореактор", "Выращивает биомассу, лекарства и удобрения.", "refinery", k_bio),
    ("crystal_grower", "Кристаллизатор", "Выращивает кристаллы и линзы.", "assembler", k_crystal),
    ("packer", "Упаковочная линия", "Упаковывает еду, патроны и наборы.", "packager", k_packer),
    ("kitchen", "Кухня", "Готовит еду на всю колонию.", "furnace", k_kitchen),
]
TIER_COST = [{"iron_plate": 8, "gear": 4, "wire": 4}, {"steel_plate": 8, "steel_gear": 4, "copper_wire": 8, "circuit": 2},
             {"aluminum_plate": 10, "motor": 2, "circuit_mk2": 2, "steel_beam": 2}, {"titanium_plate": 10, "servo_motor": 2, "circuit_mk3": 2, "superconductor": 1},
             {"tungsten_plate": 10, "quantum_chip": 1, "ai_core": 1, "plasma_core": 1}]


def build_machines():
    for kid, nm, desc, st, fn in KINDS:
        for t in range(1, 6):
            tn, MAIN, ACC = TIERS[t - 1]
            a = []
            chassis(a, MAIN, t, ACC)
            fn(a, MAIN, ACC, t)
            detail_machine(a, MAIN, ACC, t)
            iid = kid if t == 1 else "%s_mk%d" % (kid, t)
            speed = [1.0, 1.6, 2.4, 3.5, 5.0][t - 1]
            power = [4, 10, 20, 35, 60][t - 1]
            fuel = st in ("furnace",) and t == 1
            emit = None
            if kid in ("kiln", "foundry", "kitchen"):
                emit = [{"kind": "smoke", "pos": [-0.4, 2.4, -0.4], "when": "active", "rate": 0.3 + 0.1 * t, "size": 1.0}]
            elif kid in ("welder",):
                emit = [{"kind": "spark", "pos": [0.1, 0.95, 0.1], "when": "active", "rate": 2.0 + t, "size": 0.5}]
            elif kid in ("chem_plant", "distillery", "bioreactor"):
                emit = [{"kind": "steam", "pos": [0.0, 2.0, 0.0], "when": "active", "rate": 0.4 + 0.1 * t, "size": 0.8}]
            elif kid in ("crusher", "compactor"):
                emit = [{"kind": "dust", "pos": [0.6, 0.6, 0.0], "when": "active", "rate": 1.0 + 0.3 * t, "size": 0.6}]
            B(iid, "%s %s" % (nm, tn) if t > 1 else nm, "%s Скорость ×%g. Энергия: %d." % (desc, speed, 0 if fuel else power) + (" Работает на топливе." if fuel else ""),
              "production", "crafter", dict(TIER_COST[t - 1]), a, hp=300 + t * 120,
              params={"station": st, "speed": speed, "power": 0 if fuel else power, "tier": t, **({"fuel": True} if fuel else {})},
              emit=emit, catalog="Машины: " + nm)


# ------------------------------------------------------------------ энергетика
def g_burner(col, fuel_glow="#ff6a1a", big=False):
    a = []
    foundation_pad(a)
    a.append(P("box", (1.2, 0.9, 1.0), (-0.2, 0.65, 0), col))
    a.append(P("box", (0.5, 0.35, 0.05), (0.42, 0.55, 0), DARK, "dark"))
    a.append(P("box", (0.4, 0.25, 0.04), (0.44, 0.55, 0), fuel_glow, "glow", anim="flicker"))
    for k in range(4):
        a.append(P("box", (0.04, 0.8, 1.02), (-0.7 + k * 0.33, 0.65, 0), shade(col, 0.75)))
    chimney(a, -0.55, -0.4, 1.1, 1.3 if big else 0.9, 0.14, col, brick=False)
    motor(a, 0.5, 0.55, -0.55, 0.18, 0.35, YEL, axis="z")
    coil(a, 0.55, 0.3, 0.55, 0.12, 0.6)
    panel(a, -0.85, 0.75, 0.55, col, w=0.4, h=0.6, screen="#ffd040")
    return a


def g_turbine(col, acc):
    a = []
    foundation_pad(a)
    a.append(P("cylinder", (0.9, 1.6, 0.9), (0, 0.8, 0), col, rot=(0, 0, 90), seg=16, top=0.6))
    for k in range(5):
        a.append(P("torus", (0.85 - k * 0.06, 0.1, 0.85 - k * 0.06), (-0.6 + k * 0.3, 0.8, 0), DARK, "dark", rot=(0, 0, 90), seg=16))
    a.append(P("cylinder", (0.6, 0.05, 0.6), (-0.82, 0.8, 0), DARK, "dark", rot=(0, 0, 90), seg=16))
    for k in range(8):
        a.append(P("box", (0.56, 0.03, 0.08), (-0.84, 0.8, 0), STEEL, "metal", rot=spun((0, 0, 90), k * 22.5), anim="spin_fast"))
    exhaust(a, 0.4, 1.2, 0.3, 1.1, 0.12)
    exhaust(a, 0.4, 1.2, -0.3, 1.1, 0.12)
    pipe_run(a, [(-0.4, 0.3, 0.8), (-0.4, 0.8, 0.8), (-0.4, 0.8, 0.45)], 0.08, acc)
    panel(a, 0.8, 0.6, 0.55, col, face=1, w=0.4, h=0.6, screen=acc)
    return a


def g_geo(col, acc):
    a = []
    foundation_pad(a)
    hex_base(a, 0.75, 0.35, 0.3, DARK, "#ff6a1a")
    a.append(P("cylinder", (0.7, 1.3, 0.7), (0, 1.1, 0), col, seg=12))
    a.append(P("cone", (0.9, 0.5, 0.9), (0, 2.0, 0), shade(col, 0.8), seg=12))
    for k in range(4):
        ang = k * math.pi / 2 + 0.78
        pipe_run(a, [(math.cos(ang) * 0.35, 0.6, math.sin(ang) * 0.35), (math.cos(ang) * 0.8, 0.6, math.sin(ang) * 0.8), (math.cos(ang) * 0.8, 1.5, math.sin(ang) * 0.8)], 0.06, acc)
    a.append(P("cylinder", (0.5, 0.06, 0.5), (0, 0.52, 0), "#ff6a1a", "glow", anim="pulse", seg=12))
    return a


def g_nuclear(col, acc, fusion=False):
    a = []
    foundation_pad(a, 3.8, 3.8, 0.25)
    a.append(P("cylinder", (2.2, 2.6, 2.2), (-0.5, 1.5, -0.5), "#d5dbe2", "concrete", seg=24, top=0.75))
    a.append(P("torus", (2.2, 0.15, 2.2), (-0.5, 2.6, -0.5), col, seg=24))
    if fusion:
        energy_ring(a, 0.9, 1.4, 0.9, 0.8, acc, thick=0.35)
        energy_ring(a, 0.9, 1.4, 0.9, 0.6, acc, anim="spin", thick=0.2)
        a.append(P("sphere", (0.6, 0.6, 0.6), (0.9, 1.4, 0.9), "#ffffff", "glow", anim="pulse", seg=16))
        for k in range(6):
            ang = k * math.pi / 3
            coil(a, 0.9 + math.cos(ang) * 1.0, 0.3, 0.9 + math.sin(ang) * 1.0, 0.15, 1.6, acc)
    else:
        a.append(P("box", (1.3, 1.4, 1.3), (1.0, 0.95, 1.0), col))
        a.append(P("cylinder", (0.6, 0.05, 0.6), (1.0, 1.68, 1.0), acc, "glow", anim="pulse", seg=16))
        for k in range(3):
            exhaust(a, 0.6 + k * 0.4, 1.7, 1.5, 1.0, 0.1)
        a.append(P("box", (0.06, 0.4, 0.4), (1.67, 1.0, 1.0), "#f2d24a", "paint"))
        a.append(P("cylinder", (0.25, 0.02, 0.25), (1.71, 1.0, 1.0), "#1d1e21", "dark", rot=(0, 0, 90), seg=3))
    pipe_run(a, [(-0.5, 0.5, 0.6), (-0.5, 0.5, 1.6), (1.0, 0.5, 1.6)], 0.12, STEEL)
    ladder(a, 0.6, -0.5, 0.25, 2.6, YEL, along="z")
    panel(a, -1.7, 0.75, 1.2, col, w=0.6, h=0.8, screen=acc)
    beacon(a, -0.5, 2.85, -0.5, "#ff3b2f")
    return a


def g_solar(col, big=False, track=False):
    a = []
    a.append(P("box", (0.5, 0.15, 0.5), (0, 0.08, 0), CONC, "concrete"))
    a.append(P("cylinder", (0.12, 1.0 if not big else 1.6, 0.12), (0, 0.6 if not big else 0.9, 0), STEEL, "metal", seg=8))
    h = 1.15 if not big else 1.75
    rot = (25, 0, 0)
    w = 1.9 if not big else 3.8
    a.append(P("box", (w, 0.06, 1.4 if not big else 2.6), (0, h, 0), DARK, "dark", rot=rot, anim="sway" if track else ""))
    n = 4 if not big else 8
    for i in range(n):
        for j in range(3 if not big else 5):
            x = -w / 2 + (i + 0.5) * w / n
            dz = (-0.45 + j * 0.45) if not big else (-1.0 + j * 0.5)
            a.append(P("box", (w / n - 0.05, 0.02, 0.4), (x, h + 0.04 + dz * 0.42, dz * 0.9), col, "glass", rot=rot, anim="sway" if track else ""))
    a.append(P("box", (0.2, 0.25, 0.15), (0.2, 0.4, 0.2), DARK, "dark"))
    a.append(P("sphere", (0.05, 0.05, 0.05), (0.31, 0.45, 0.2), "#40ff6a", "glow", anim="blink"))
    return a


def g_wind(col, h=4.5, blades=3):
    a = []
    a.append(P("cylinder", (0.9, 0.2, 0.9), (0, 0.1, 0), CONC, "concrete", seg=12))
    a.append(P("cylinder", (0.3, h, 0.3), (0, h / 2, 0), "#e6eaee", "paint", seg=12, top=0.6))
    a.append(P("capsule", (0.35, 0.8, 0.35), (0.1, h + 0.1, 0), "#e6eaee", "paint", rot=(0, 0, 90), seg=12))
    a.append(P("sphere", (0.3, 0.3, 0.3), (0.55, h + 0.1, 0), col, seg=12, anim="spin_wind"))
    for k in range(blades):
        a.append(P("box", (0.22, 0.06, 2.0 + h * 0.15), (0.62, h + 0.1, 0), "#f2f2f2", "paint", rot=spun((0, 0, 90), k * 180 / blades), anim="spin_wind"))
    a.append(P("box", (0.04, 0.2, 0.36), (-0.32, h + 0.1, 0), col))
    ladder(a, 0.0, -0.2, 0.2, h - 0.2, STEEL, along="x", w=0.2)
    beacon(a, -0.1, h + 0.32, 0, "#ff3b2f")
    return a


def g_watermill(col):
    a = []
    foundation_pad(a)
    a.append(P("box", (0.9, 1.3, 1.2), (-0.45, 0.85, 0), WOOD, "wood"))
    a.append(P("prism", (1.0, 0.5, 1.3), (-0.45, 1.75, 0), "#8a2a2a", "paint", rot=(0, 90, 0)))
    a.append(P("cylinder", (1.5, 0.3, 1.5), (0.45, 0.9, 0), WOOD_D, "wood", rot=(90, 0, 0), seg=16, anim="spin_slow"))
    for k in range(8):
        a.append(P("box", (1.6, 0.32, 0.06), (0.45, 0.9, 0), WOOD, "wood", rot=spun((90, 0, 0), k * 22.5), anim="spin_slow"))
    a.append(P("cylinder", (0.12, 0.5, 0.12), (0.45, 0.9, 0), DARK, "dark", rot=(90, 0, 0), seg=8))
    window_strip(a, -0.9, 1.0, 0, 0.4, 0.3, "z", WOOD_D, "#ffd27a")
    return a


def g_battery(col, acc, n):
    a = []
    foundation_pad(a)
    for i in range(n):
        x = -0.6 + i * 1.2 / max(1, n - 1) if n > 1 else 0
        a.append(P("box", (1.2 / n * 0.85 if n > 1 else 0.9, 1.1, 1.2), (x, 0.8, 0), col))
        a.append(P("box", (0.08, 0.7, 0.02), (x, 0.8, 0.61), DARK, "dark"))
        a.append(P("box", (0.06, 0.6, 0.02), (x, 0.75, 0.62), acc, "glow", anim="pulse"))
        a.append(P("cylinder", (0.1, 0.1, 0.1), (x - 0.06, 1.4, 0), "#c03020", "metal", seg=8))
        a.append(P("cylinder", (0.1, 0.1, 0.1), (x + 0.06, 1.4, 0), DARK, "dark", seg=8))
    a.append(P("box", (1.6, 0.08, 1.3), (0, 1.38, 0), DARK, "dark"))
    return a


def g_pole(col, h, kind="wood"):
    a = []
    if kind == "wood":
        a.append(P("cylinder", (0.22, h, 0.22), (0, h / 2, 0), WOOD_D, "wood", seg=8))
        a.append(P("box", (1.1, 0.12, 0.12), (0, h - 0.3, 0), WOOD_D, "wood"))
    elif kind == "steel":
        lattice(a, -0.25, 0.25, -0.25, 0.25, 0, h, col, levels=int(h / 1.2), thick=0.06)
        a.append(P("box", (1.3, 0.1, 0.1), (0, h - 0.3, 0), col))
    else:
        lattice(a, -0.5, 0.5, -0.5, 0.5, 0, h, col, levels=int(h / 1.2), thick=0.08)
        a.append(P("box", (2.2, 0.14, 0.14), (0, h - 0.5, 0), col))
        a.append(P("box", (1.6, 0.14, 0.14), (0, h - 1.2, 0), col))
    for x in (-0.45, 0.0, 0.45) if kind != "big" else (-1.0, -0.5, 0.5, 1.0):
        a.append(P("cylinder", (0.1, 0.2, 0.1), (x, h - 0.15 if kind != "big" else h - 0.35, 0), "#f2f2e6", "paint", seg=8))
        a.append(P("torus", (0.13, 0.15, 0.13), (x, h - 0.13 if kind != "big" else h - 0.33, 0), "#f2f2e6", "paint", seg=8))
    beacon(a, 0, h + 0.05, 0, "#ff3b2f") if kind == "big" else None
    return a


def build_power():
    E = "Энергетика"
    B("biomass_stove", "Печь-генератор", "Жжёт ветки, листья и брёвна: 15 энергии.", "energy", "generator", {"stone": 10, "log": 4}, g_burner("#8a5a32"), 200,
      params={"power": 15, "radius": 8, "fuels": ["leaves", "fiber", "branch", "log", "plank", "biomass"], "burn_mult": 2.0},
      emit=[{"kind": "smoke", "pos": [-0.55, 2.1, -0.4], "when": "active", "rate": 0.3, "size": 1.0}], catalog=E)
    B("coal_plant", "Угольная станция", "Жжёт уголь и древесный уголь: 110 энергии.", "energy", "generator", {"steel_plate": 10, "brick": 20, "motor": 2}, g_burner("#5c6370", big=True), 600,
      params={"power": 110, "radius": 12, "fuels": ["coal", "charcoal", "coal_hq"], "burn_mult": 1.3, "fuel_slots": 2},
      emit=[{"kind": "smoke", "pos": [-0.55, 2.5, -0.4], "when": "active", "rate": 0.5, "size": 1.4}], catalog=E)
    B("gas_turbine", "Газовая турбина", "Жжёт топливо из труб: 220 энергии.", "energy", "generator", {"aluminum_plate": 10, "motor": 3, "steel_pipe_part": 4}, g_turbine("#c0c4cc", "#ff8c1a"), 700,
      params={"power": 220, "radius": 12, "fuels": ["fuel", "canister_fuel"], "burn_mult": 0.8, "fuel_slots": 2, "pipes": True},
      emit=[{"kind": "steam", "pos": [0.4, 2.4, 0.3], "when": "active", "rate": 0.5, "size": 1.0}], catalog=E)
    B("hydrogen_cell_plant", "Водородная станция", "Чистая энергия из водородных баллонов: 300.", "energy", "generator", {"titanium_plate": 8, "circuit_mk2": 2, "electromagnet": 2}, g_turbine("#ff8ad8", "#40c8ff"), 700,
      params={"power": 300, "radius": 12, "fuels": ["hydrogen_tank", "fuel_cell"], "burn_mult": 1.0, "fuel_slots": 2}, catalog=E)
    B("geothermal", "Геотермальная станция", "Даёт 180 энергии из жара недр. Топливо не нужно.", "energy", "generator", {"steel_beam": 4, "steel_pipe_part": 6, "ceramic": 10}, g_geo("#8a4a32", "#ff8c1a"), 900,
      params={"power": 180, "radius": 10}, emit=[{"kind": "steam", "pos": [0, 2.4, 0], "when": "always", "rate": 0.6, "size": 1.2}], catalog=E)
    B("nuclear_plant", "Атомная станция", "Жжёт урановые слитки: 1200 энергии.", "energy", "generator", {"concrete": 60, "steel_beam": 20, "circuit_mk3": 6, "lead_plate": 20}, g_nuclear("#2fa84f", "#7dff5a"), 3000,
      size=2, params={"power": 1200, "radius": 20, "fuels": ["uranium_ingot", "power_cell"], "burn_mult": 10.0, "fuel_slots": 2},
      emit=[{"kind": "steam", "pos": [-0.5, 3.0, -0.5], "when": "active", "rate": 1.0, "size": 2.0}], catalog=E)
    B("fusion_reactor", "Термоядерный реактор", "Звезда в бутылке: 4000 энергии на водороде.", "energy", "generator", {"superconductor": 20, "plasma_core": 4, "ai_core": 1, "tungsten_beam": 10}, g_nuclear("#7a2ec7", "#d9a6ff", True), 5000,
      size=2, params={"power": 4000, "radius": 24, "fuels": ["hydrogen_tank", "plasma_core"], "burn_mult": 20.0, "fuel_slots": 2}, catalog=E)
    for i, (sid, nm, pw, big, track, col, cost) in enumerate((
            ("solar_small", "Солнечная панель малая", 8, False, False, "#1d3a6b", {"solar_cell": 2, "iron_rod": 2}),
            ("solar_mk2", "Солнечная панель Mk2", 18, False, False, "#1f2f8a", {"solar_cell": 4, "aluminum_rod": 2}),
            ("solar_tracker", "Поворотная солнечная панель", 26, False, True, "#1d3a6b", {"solar_cell": 4, "servo_motor": 1, "steel_rod": 2}),
            ("solar_farm", "Солнечная ферма", 70, True, False, "#1d3a6b", {"solar_cell": 12, "steel_beam": 2}),
            ("solar_farm_mk2", "Солнечная ферма Mk2", 140, True, True, "#3a1f6b", {"solar_cell": 20, "servo_motor": 2, "titanium_beam": 2}))):
        B(sid, nm, "Даёт %d энергии днём." % pw, "energy", "generator", cost, g_solar(col, big, track), 150 + pw * 2, size=2 if big else 1,
          params={"power": pw, "solar": True, "radius": 6 if not big else 10}, catalog=E)
    for sid, nm, pw, h, bl, col, cost in (("wind_small", "Малый ветряк", 12, 3.0, 4, YEL, {"plank": 6, "iron_gear": 2, "copper_wire": 4}),
                                          ("wind_large", "Большой ветряк", 60, 7.0, 3, "#2e6bc7", {"steel_beam": 4, "motor": 2}),
                                          ("wind_giant", "Гигантский ветряк", 160, 10.0, 3, "#2fa84f", {"titanium_beam": 6, "servo_motor": 2, "carbon_fiber": 4})):
        B(sid, nm, "Даёт до %d энергии от ветра." % pw, "energy", "generator", cost, g_wind(col, h, bl), 200 + pw * 2,
          params={"power": pw, "wind": True, "radius": 6, "wire_height": h + 0.3}, catalog=E)
    B("water_wheel", "Водяная мельница", "Даёт 30 энергии без топлива и днём, и ночью.", "energy", "generator", {"plank": 20, "iron_gear": 4}, g_watermill(WOOD), 300,
      params={"power": 30, "radius": 8}, catalog=E)
    for t in range(1, 6):
        tn, MAIN, ACC = TIERS[t - 1]
        cap = [1000, 3000, 8000, 20000, 60000][t - 1]
        B("battery_mk%d" % t, "Аккумулятор %s" % tn, "Запасает %d энергии на ночь." % cap, "energy", "battery",
          [{"battery": 4, "iron_plate": 4}, {"battery_cell": 6, "steel_plate": 4}, {"battery_pack": 4, "aluminum_plate": 6},
           {"battery_pack": 8, "superconductor": 2}, {"power_cell": 6, "graphene": 4}][t - 1], g_battery(MAIN, ACC, min(t + 1, 4)), 200 + t * 80,
          params={"capacity": cap, "radius": 4 + t}, catalog=E)
    for sid, nm, h, kind, col, r, cost in (("pole_wood", "Деревянный столб", 4.0, "wood", WOOD_D, 8, {"log": 1, "copper_wire": 2}),
                                           ("pole_steel", "Стальная опора", 5.5, "steel", STEEL, 14, {"steel_rod": 4, "copper_wire": 4}),
                                           ("pole_tower", "Высоковольтная вышка", 9.0, "big", "#8c949e", 30, {"steel_beam": 6, "aluminum_wire": 6, "porcelain": 4})):
        B(sid, nm, "Передаёт энергию на %d клеток. Провода тянутся клавишей V." % r, "energy", "pole", cost, g_pole(col, h, kind), 150 + r * 10,
          params={"radius": r, "any_ground": True, "wire_height": h - 0.2}, catalog=E)
    a = []
    foundation_pad(a)
    for x in (-0.4, 0.4):
        coil(a, x, 0.2, 0, 0.3, 1.0, "#c87533")
    a.append(P("box", (1.4, 0.2, 0.8), (0, 1.3, 0), STEEL, "metal"))
    for x in (-0.5, 0, 0.5):
        a.append(P("cylinder", (0.12, 0.4, 0.12), (x, 1.6, 0), "#f2f2e6", "paint", seg=8))
    a.append(P("box", (0.06, 0.3, 0.3), (0.72, 0.8, 0), "#f2d24a", "paint"))
    B("transformer", "Трансформатор", "Передаёт энергию далеко: радиус 20 клеток.", "energy", "pole", {"transformer_core": 2, "steel_plate": 4}, a, 400,
      params={"radius": 20, "any_ground": True}, catalog=E)


# ------------------------------------------------------------------ хранение
def s_chest(col, band, w=1.3, h=0.8, d=0.9, lid=True, glow=None):
    a = [P("box", (w, h, d), (0, h / 2 + 0.05, 0), col, "wood" if col in (WOOD, WOOD_D, "#a0703a") else "metal")]
    for x in (-w / 2 + 0.05, w / 2 - 0.05):
        a.append(P("box", (0.08, h + 0.02, d + 0.02), (x, h / 2 + 0.05, 0), band, "metal"))
    a.append(P("box", (w + 0.02, 0.08, d + 0.02), (0, h * 0.7, 0), band, "metal"))
    if lid:
        a.append(P("cylinder", (d, w, d * 0.5), (0, h + 0.05, 0), col, "wood" if col in (WOOD, WOOD_D, "#a0703a") else "metal", rot=(0, 0, 90), seg=12, top=1.0))
    a.append(P("box", (0.16, 0.2, 0.06), (0, h * 0.7, d / 2 + 0.02), BRASS if glow is None else DARK, "metal"))
    if glow:
        a.append(P("box", (0.08, 0.08, 0.02), (0, h * 0.7, d / 2 + 0.05), glow, "glow", anim="pulse"))
        a.append(P("box", (w * 0.9, 0.03, 0.02), (0, h * 0.3, d / 2 + 0.01), glow, "glow", anim="pulse"))
    return a


def s_silo(col, h, n=1):
    a = []
    foundation_pad(a, 3.8 if n > 1 else 1.9, 3.8 if n > 1 else 1.9)
    pos = [(0, 0)] if n == 1 else [(-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)]
    for x, z in pos:
        tank_v(a, x, 0.6, z, 0.8 if n == 1 else 0.85, h, col)
        a.append(P("cone", (0.5, 0.6, 0.5), (x, 0.45, z), shade(col, 0.8), "metal", rot=(180, 0, 0), seg=12))
        for k in range(4):
            ang = k * math.pi / 2 + 0.78
            a.append(P("box", (0.08, 0.6, 0.08), (x + math.cos(ang) * 0.6, 0.3, z + math.sin(ang) * 0.6), DARK, "dark"))
    ladder(a, pos[0][0] + 0.82, pos[0][1], 0.6, 0.6 + h, YEL, along="z")
    return a


def s_rack(col, levels=4):
    a = []
    foundation_pad(a)
    for x in (-0.85, 0.85):
        for z in (-0.4, 0.4):
            a.append(P("box", (0.08, 2.2, 0.08), (x, 1.25, z), col))
    for k in range(levels):
        y = 0.4 + k * 0.55
        a.append(P("box", (1.8, 0.05, 0.9), (0, y, 0), DARK, "dark"))
        a.append(P("box", (1.8, 0.06, 0.04), (0, y + 0.02, 0.44), col))
        for j in range(3):
            if (k + j) % 4 != 3:
                a.append(P("box", (0.45, 0.35, 0.6), (-0.55 + j * 0.55, y + 0.2, 0), ["#c49a6c", "#5a8a5a", "#4a6fa8", "#a8784a"][(k + j) % 4], "cloth"))
    return a


def s_vault(col, acc):
    a = []
    foundation_pad(a)
    a.append(P("box", (1.6, 1.6, 1.4), (0, 1.0, 0), col))
    a.append(P("cylinder", (1.0, 0.12, 1.0), (0.81, 1.0, 0), CHR, "metal", rot=(0, 0, 90), seg=20))
    for k in range(6):
        a.append(P("box", (0.06, 0.06, 0.4), (0.88, 1.0, 0), DARK, "dark", rot=(k * 30, 0, 0)))
    a.append(P("cylinder", (0.2, 0.08, 0.2), (0.9, 1.0, 0), acc, "glow", rot=(0, 0, 90), seg=12, anim="pulse"))
    for y in (0.3, 1.75):
        a.append(P("box", (1.64, 0.1, 1.44), (0, y, 0), DARK, "dark"))
    return a


def s_quantum(col, acc):
    a = []
    hex_base(a, 0.85, 0.2, 0.3, DARK, acc)
    a.append(P("box", (1.0, 1.0, 1.0), (0, 1.2, 0), col, "glass", rot=(45, 0, 35), anim="spin_slow"))
    a.append(P("box", (0.6, 0.6, 0.6), (0, 1.2, 0), acc, "glow", rot=(45, 0, 35), anim="spin"))
    energy_ring(a, 0, 1.2, 0, 0.8, acc)
    for k in range(3):
        ang = k * 2 * math.pi / 3
        a.append(P("box", (0.1, 1.4, 0.1), (math.cos(ang) * 0.8, 0.9, math.sin(ang) * 0.8), DARK, "dark"))
    return a


def build_storage():
    S = "Хранение"
    for sid, nm, col, band, slots, cost, glow in (
            ("crate_small", "Маленький ящик", WOOD, WOOD_D, 8, {"plank": 3}, None),
            ("chest_oak", "Дубовый сундук", "#a0703a", BRASS, 20, {"oak_plank": 6, "iron_bolt": 2}, None),
            ("chest_iron", "Железный сундук", "#8c949e", DARK, 24, {"iron_plate": 6}, None),
            ("chest_steel", "Стальной сундук", "#5c6370", YEL, 32, {"steel_plate": 6}, None),
            ("chest_titanium", "Титановый сундук", "#a8b4c4", "#2e6bc7", 48, {"titanium_plate": 6}, "#40c8ff"),
            ("chest_tungsten", "Вольфрамовый сейф", "#3a3f47", "#c7302e", 64, {"tungsten_plate": 6, "microchip": 1}, "#ff8c1a"),
            ("fridge", "Холодильник", "#e6eaee", "#9aa3ad", 20, {"steel_plate": 4, "coolant": 1, "motor": 1}, "#40c8ff"),
            ("weapon_rack", "Оружейный шкаф", "#3a4a2a", DARK, 12, {"steel_plate": 4, "plank": 2}, None),
            ("medicine_cabinet", "Аптечный шкаф", "#f2f2f2", "#e0263d", 12, {"iron_plate": 3, "glass": 1}, None),
            ("tool_chest", "Ящик для инструментов", "#e0263d", DARK, 16, {"iron_plate": 4}, None)):
        tall = sid in ("fridge", "weapon_rack", "medicine_cabinet")
        a = s_chest(col, band, 1.0 if tall else 1.3, 1.8 if tall else 0.8, 0.8, not tall, glow)
        B(sid, nm, "Хранит %d стаков. Принимает предметы с лент." % slots, "storage", "storage", cost, a, 150 + slots * 6, params={"slots": slots}, catalog=S)
    B("shelf_rack", "Стеллаж склада", "Хранит 60 стаков.", "storage", "storage", {"steel_rod": 8, "plank": 6}, s_rack("#2e6bc7"), 400, params={"slots": 60}, catalog=S)
    B("shelf_rack_big", "Высокий стеллаж", "Хранит 90 стаков.", "storage", "storage", {"steel_beam": 4, "plank": 10}, s_rack(YEL, 5), 500, params={"slots": 90}, catalog=S)
    B("vault", "Хранилище-сейф", "Хранит 120 стаков. Очень прочное.", "storage", "storage", {"steel_plate": 20, "tungsten_plate": 4, "microchip": 2}, s_vault("#5c6370", "#40ff6a"), 2500,
      params={"slots": 120}, catalog=S)
    B("quantum_storage", "Квантовое хранилище", "Хранит 300 стаков в кармане пространства.", "storage", "storage", {"quantum_chip": 2, "void_essence": 1, "titanium_plate": 10},
      s_quantum("#9fe8ff", "#d9a6ff"), 1500, params={"slots": 300}, catalog=S)
    for sid, nm, col, h, n, slots, cost in (("silo_small", "Малый силос", "#c0c4cc", 2.0, 1, 50, {"iron_plate": 12}),
                                            ("silo", "Силос", "#e6eaee", 3.2, 1, 80, {"steel_plate": 14, "steel_beam": 2}),
                                            ("silo_block", "Блок силосов", "#d5dbe2", 3.4, 4, 300, {"steel_plate": 40, "steel_beam": 8})):
        B(sid, nm, "Хранит %d стаков сыпучих грузов." % slots, "storage", "storage", cost, s_silo(col, h, n), 400 + slots * 4, size=2 if n > 1 else 1,
          params={"slots": slots}, catalog=S)
    for t in range(1, 6):
        tn, MAIN, ACC = TIERS[t - 1]
        a = []
        foundation_pad(a)
        a.append(P("box", (1.8, 1.3, 1.5), (0, 0.85, 0), MAIN, "metal"))
        for k in range(9):
            a.append(P("box", (0.04, 1.22, 1.52), (-0.8 + k * 0.2, 0.85, 0), shade(MAIN, 0.75), "metal"))
        a.append(P("box", (0.04, 1.1, 0.6), (0.91, 0.85, 0.3), shade(MAIN, 0.85), "metal"))
        a.append(P("box", (0.04, 1.1, 0.6), (0.91, 0.85, -0.3), shade(MAIN, 0.85), "metal"))
        for z in (-0.1, 0.1):
            a.append(P("box", (0.05, 1.0, 0.04), (0.94, 0.85, z), CHR, "metal"))
        tier_pips(a, 0.95, 1.4, 0, t, ACC)
        sign_plate(a, 0, 1.2, 0.77, DARK, "#f2f2f2", "z", t)
        B("cargo_mk%d" % t, "Грузовой контейнер %s" % tn, "Хранит %d стаков." % (40 + t * 20), "storage", "storage",
          [{"iron_plate": 10, "steel": 2}, {"steel_plate": 10}, {"aluminum_plate": 10}, {"titanium_plate": 10}, {"tungsten_plate": 10}][t - 1], a, 400 + t * 150,
          params={"slots": 40 + t * 20}, catalog=S)


# ------------------------------------------------------------------ жидкости
def f_tank(col, r, h, sphere=False):
    a = []
    foundation_pad(a, 1.9 if r < 0.8 else 3.8, 1.9 if r < 0.8 else 3.8)
    if sphere:
        a.append(P("sphere", (r * 2, r * 2, r * 2), (0, r + 0.8, 0), col, "metal", seg=20))
        for k in range(6):
            ang = k * math.pi / 3
            a.append(P("box", (0.1, r + 0.8, 0.1), (math.cos(ang) * r * 0.85, (r + 0.8) / 2, math.sin(ang) * r * 0.85), DARK, "dark"))
        a.append(P("torus", (r * 2.02, 0.06, r * 2.02), (0, r + 0.8, 0), DARK, "dark", seg=20))
    else:
        tank_v(a, 0, 0.2, 0, r, h, col)
    pipe_run(a, [(r + 0.05, 0.4, 0), (0.95 if r < 0.8 else 1.9, 0.4, 0)], 0.08, STEEL)
    pipe_run(a, [(-r - 0.05, 0.4, 0), (-0.95 if r < 0.8 else -1.9, 0.4, 0)], 0.08, STEEL)
    return a


def build_fluids():
    F = "Жидкости"
    for sid, nm, col, r, h, cap, size, sphere, cost in (
            ("barrel_tank", "Бочка-бак", "#c03020", 0.4, 0.9, 100, 1, False, {"iron_plate": 4}),
            ("tank_small", "Малый бак", "#c0c4cc", 0.7, 1.4, 250, 1, False, {"iron_plate": 8}),
            ("tank_tall", "Высокий бак", "#e6eaee", 0.7, 3.0, 600, 1, False, {"steel_plate": 10}),
            ("tank_large", "Большой бак", "#d5dbe2", 1.6, 2.4, 2000, 2, False, {"steel_plate": 30, "steel_beam": 4}),
            ("tank_sphere", "Сферический резервуар", "#f2f2f2", 1.5, 0, 4000, 2, True, {"aluminum_plate": 30, "steel_beam": 6}),
            ("water_tower", "Водонапорная башня", "#5ab4ff", 0.8, 1.2, 800, 1, False, {"steel_beam": 6, "steel_plate": 6})):
        a = f_tank(col, r, h, sphere)
        if sid == "water_tower":
            a = []
            lattice(a, -0.6, 0.6, -0.6, 0.6, 0, 3.0, STEEL, levels=3)
            tank_v(a, 0, 3.0, 0, 0.85, 1.3, col)
            ladder(a, 0.62, 0, 0, 4.3, YEL, along="z")
        B(sid, nm, "Запасает до %d единиц жидкости из труб." % cap, "fluids", "tank", cost, a, 300 + cap // 10, size=size,
          params={"pipe_capacity": cap}, catalog=F)
    a = []
    foundation_pad(a)
    tank_v(a, -0.3, 0.2, 0, 0.4, 1.2, "#5ab4ff")
    motor(a, 0.45, 0.6, 0, 0.2, 0.4, YEL, axis="x")
    pipe_run(a, [(0.0, 0.5, 0.5), (0.0, 0.5, 0.95)], 0.07, STEEL)
    a.append(P("cylinder", (0.5, 0.3, 0.5), (-0.3, 1.6, 0), "#9fe8ff", "glass", seg=12))
    B("water_purifier", "Очистка воды", "Делает из речной воды питьевую.", "fluids", "crafter", {"steel_plate": 6, "ceramic": 4, "motor": 1}, a, 350,
      params={"station": "refinery", "speed": 1.0, "power": 8, "pipes": True}, catalog=F)
    a = []
    foundation_pad(a)
    a.append(P("cylinder", (0.7, 0.4, 0.7), (0, 0.4, 0), STEEL, "metal", seg=12))
    a.append(P("cylinder", (0.25, 1.4, 0.25), (0, 1.2, 0), DARK, "dark", seg=10, anim="piston_small"))
    a.append(P("box", (1.2, 0.2, 0.3), (0, 2.0, 0), "#c7302e", rot=(0, 0, 10), anim="pump_nod"))
    pipe_run(a, [(0.35, 0.4, 0), (0.95, 0.4, 0)], 0.08, STEEL)
    B("well_pump", "Скважина", "Качает 30 единиц воды в минуту из-под земли где угодно.", "fluids", "miner", {"steel_pipe_part": 4, "motor": 1, "iron_plate": 4}, a, 300,
      params={"period": 2.0, "power": 6, "any_ground": True, "water_item": "water", "extracts": "fluid", "pipes": True}, catalog=F)
    a = []
    foundation_pad(a)
    for k in range(4):
        x = -0.6 + k * 0.4
        a.append(P("cylinder", (0.12, 1.8, 0.12), (x, 1.1, 0), STEEL, "metal", seg=8))
        a.append(P("torus", (0.3, 0.1, 0.3), (x, 1.8, 0), "#c03020", "metal", seg=10, rot=(90, 0, 0)))
    pipe_run(a, [(-0.6, 0.4, 0.5), (0.6, 0.4, 0.5), (0.95, 0.4, 0.5)], 0.09, YEL)
    B("valve_station", "Узел задвижек", "Декоративный узел труб с задвижками.", "fluids", "decor", {"steel_pipe_part": 6}, a, 300, params={}, catalog=F)


def build_all():
    build_machines(); build_power(); build_storage(); build_fluids()
