# Уровни (тиры) буров, лент и труб: подробные модели Mk1–Mk5.
# Все модели потом свободно правятся в редакторе моделей.
import math
from art_kit import *

TIER_COL = {1: "#f2a81f", 2: "#2f6fc4", 3: "#3aa35a", 4: "#c8372d", 5: "#8a4dff"}
TIER_GLOW = {1: "#ffb040", 2: "#40c8ff", 3: "#7dff5a", 4: "#ff5a3a", 5: "#d9a6ff"}


# ================================================================== буры
def miner_mk1():
    """Бур Mk1: жёлтая буровая установка на салазках — вышка, шнек, редуктор, мотор, пульт, лестница."""
    BL, BLD = "#f2a81f", "#c9861a"
    a = []
    skids(a)
    deck(a, 0.31, 1.84, 1.84, BL, edge="#292b30")
    for x in (-0.92, 0.92):
        for z in (-0.92, 0.92):
            outriggers(a, x, z, 0.42, BL)
    auger(a, -0.1, 0.65, 0, 0.56, 1.5)
    lattice(a, -0.62, 0.42, -0.52, 0.52, 0.37, 2.87, BLD, levels=3)
    a.append(P("box", (1.3, 0.08, 1.3), (-0.1, 2.9, 0), DARK, "dark"))
    kelly(a, -0.1, 0, 0.6, 2.7)
    gearbox(a, -0.1, 2.15, 0.0, 0.9, 0.62, 0.5, BL, gear_col=DARK, side=1)
    a.append(P("gear", (0.5, 0.07, 0.5), (-0.1, 2.15, -0.31), DARK, "metal", rot=(-90, 0, 0), anim="gear_slow", seg=16, top=0.8))
    motor(a, -0.1, 3.3, 0, 0.35, 0.7, BL)
    a.append(P("cylinder", (0.12, 0.45, 0.12), (-0.1, 2.72, 0), CHR, "metal", anim="spin_fast", seg=8))
    for z in (-0.68, 0.68):
        piston(a, 0.62, 1.0, z, 1.4, 0.08, BL, tilt=(0, 0, 8))
    hose(a, 0.5, 1.45, 0.62, 0.5)
    hose(a, 0.5, 1.35, -0.62, 0.4)
    chute(a, 0.62, 0.62, 0, BLD)
    a.append(P("box", (0.4, 0.3, 0.6), (0.82, 0.55, 0), "#3f4247", "dark"))
    a.append(P("box", (0.12, 0.25, 1.0), (0.6, 1.2, 0), "#ffb040", "glow", anim="pulse"))
    panel(a, -0.82, 0.85, -0.4, BL)
    ladder(a, -0.86, 0.47, 0.37, 2.87, BLD)
    railing(a, -0.72, 0.52, -0.62, 0.62, 2.94, DARK)
    exhaust(a, -0.6, 3.25, -0.45)
    beacon(a, 0.4, 2.98, -0.5)
    cable_reel(a, 0.75, 0.62, -0.7)
    barrel(a, -0.72, 0.62, "#c03020", y=0.37, h=0.36)
    sign_plate(a, 0.43, 2.15, 0.0, "#292b30", n=1)
    tier_pips(a, 0.82, 0.62, 0.32, 1, TIER_GLOW[1])
    return a


def miner_mk2():
    """Бур Mk2: синяя установка с двумя встречными шнеками, кабиной оператора, цепным приводом и радиатором."""
    BL, BLD, GL = "#2f6fc4", "#24569a", "#9fd8ff"
    a = []
    skids(a)
    deck(a, 0.31, 1.88, 1.88, BL)
    for x in (-0.94, 0.94):
        for z in (-0.94, 0.94):
            outriggers(a, x, z, 0.42, BL)
    # два шнека и общая рама
    for z in (-0.3, 0.3):
        auger(a, -0.15, 0.6, z, 0.42, 1.4, anim="spin_fast")
        kelly(a, -0.15, z, 0.6, 2.6, r=0.08)
    lattice(a, -0.65, 0.35, -0.62, 0.62, 0.37, 2.75, BLD, levels=3)
    # цепной привод между шнеками
    a.append(P("box", (0.16, 0.5, 0.86), (-0.15, 2.45, 0), DARK, "dark"))
    for i in range(10):
        a.append(P("box", (0.06, 0.04, 0.08), (-0.06, 2.24 + (i % 5) * 0.1, -0.3 + (i // 5) * 0.6), CHR, "metal", anim="jitter"))
    for z in (-0.3, 0.3):
        a.append(P("gear", (0.34, 0.06, 0.34), (-0.05, 2.45, z), YEL, "metal", rot=(0, 0, 90), anim="gear_fast", seg=12, top=0.78))
    gearbox(a, -0.15, 2.95, 0.0, 0.95, 0.42, 1.0, BL, side=1)
    # большой мотор лёжа и радиатор
    motor(a, -0.15, 3.45, 0, 0.32, 0.9, BL, fins=7, fan=False, axis="x")
    a.append(P("box", (0.12, 0.62, 0.9), (0.42, 3.45, 0), DARK, "dark"))
    for i in range(9):
        a.append(P("box", (0.14, 0.56, 0.02), (0.43, 3.45, -0.4 + i * 0.1), STEEL, "metal"))
    a.append(P("cylinder", (0.5, 0.04, 0.5), (0.5, 3.45, 0), DARK, "dark", rot=(0, 0, 90), seg=20))
    for i in range(5):
        a.append(P("box", (0.02, 0.22, 0.07), (0.53, 3.45, 0), STEEL, "metal", rot=(i * 36, 0, 0), anim="spin_fan"))
    # кабина оператора сзади
    a.append(P("box", (0.55, 0.85, 0.7), (-0.6, 0.82, -0.5), BL))
    window_strip(a, -0.88, 0.95, -0.5, 0.5, 0.35, glass=GL)
    window_strip(a, -0.6, 0.95, -0.86, 0.36, 0.35, along="x", glass=GL)
    a.append(P("box", (0.6, 0.06, 0.76), (-0.6, 1.28, -0.5), DARK, "dark"))
    beacon(a, -0.45, 1.32, -0.62, "#40c8ff")
    a.append(P("box", (0.02, 0.5, 0.28), (-0.88, 0.62, -0.18), DARK, "dark"))
    a.append(P("sphere", (0.04, 0.04, 0.04), (-0.9, 0.62, -0.08), CHR, "metal"))
    panel(a, -0.82, 0.85, 0.48, BL, screen="#40c8ff")
    for z in (-0.78, 0.78):
        piston(a, 0.55, 1.05, z, 1.5, 0.085, BL, tilt=(0, 0, 9))
    hose(a, 0.45, 1.5, 0.72, 0.45)
    hose(a, 0.45, 1.5, -0.72, 0.45)
    chute(a, 0.62, 0.6, 0, BLD, rollers=5)
    a.append(P("box", (0.4, 0.34, 0.66), (0.82, 0.55, 0), "#3f4247", "dark"))
    a.append(P("box", (0.12, 0.25, 1.0), (0.45, 1.25, 0), "#40c8ff", "glow", anim="pulse"))
    ladder(a, -0.9, 0.0, 1.3, 2.75, BLD)
    platform(a, -0.75, 0.45, -0.7, 0.7, 2.8, DARK, rail=YEL)
    exhaust(a, 0.2, 3.85, -0.35, h=0.7)
    exhaust(a, 0.2, 3.85, 0.35, h=0.7)
    tank_v(a, 0.7, 0.37, -0.68, 0.14, 0.55, "#d9822b", gauge=False)
    beacon(a, 0.3, 4.0, 0.0, "#40c8ff")
    sign_plate(a, 0.39, 2.95, 0.0, "#2f6fc4", n=2)
    tier_pips(a, 0.82, 0.62, 0.36, 2, TIER_GLOW[2])
    return a


def miner_mk3():
    """Бур Mk3: зелёная тяжёлая установка — закрытая башня, вращающаяся коронка с резцами, турбина охлаждения, баки и галерея."""
    G, GD, WH = "#3aa35a", "#2a7a43", "#e9efe9"
    a = []
    skids(a, w=1.98, d=1.7)
    deck(a, 0.31, 1.94, 1.94, GD, edge=YEL)
    for x in (-0.96, 0.96):
        for z in (-0.96, 0.96):
            outriggers(a, x, z, 0.44, G)
    # коронка в шахте и прозрачный кожух
    a.append(P("cylinder", (1.1, 0.12, 1.1), (-0.1, 0.36, 0), DARK, "dark", seg=24))
    cutter_head(a, -0.1, 0.62, 0, 0.42, STEEL, n=12)
    a.append(P("cylinder", (1.0, 0.7, 1.0), (-0.1, 0.78, 0), "#9fd8ff", "glass", seg=20))
    for i in range(4):
        ang = i * 90 + 45
        a.append(P("box", (0.05, 0.75, 0.05), (-0.1 + math.cos(math.radians(ang)) * 0.5, 0.8, math.sin(math.radians(ang)) * 0.5), DARK, "dark"))
    # закрытая башня с панелями и окнами
    a.append(P("box", (1.0, 1.8, 1.0), (-0.1, 2.05, 0), G))
    for y in (1.3, 2.05, 2.8):
        a.append(P("box", (1.04, 0.06, 1.04), (-0.1, y, 0), GD))
    for z in (-0.51, 0.51):
        for y in (1.65, 2.45):
            window_strip(a, -0.1, y, z, 0.6, 0.22, along="x", glass="#7dff5a")
    for x in (-0.61, 0.41):
        a.append(P("box", (0.03, 1.7, 0.06), (x, 2.05, 0.3), DARK, "dark"))
        a.append(P("box", (0.03, 1.7, 0.06), (x, 2.05, -0.3), DARK, "dark"))
    kelly(a, -0.1, 0, 0.9, 1.15, r=0.14)
    # турбина охлаждения сверху
    a.append(P("cylinder", (1.2, 0.5, 1.2), (-0.1, 3.2, 0), WH, "metal", seg=24))
    a.append(P("torus", (1.24, 0.15, 1.24), (-0.1, 3.45, 0), G, seg=24))
    a.append(P("cylinder", (1.06, 0.04, 1.06), (-0.1, 3.47, 0), DARK, "dark", seg=24))
    for i in range(8):
        a.append(P("box", (0.5, 0.02, 0.12), (-0.1, 3.5, 0), STEEL, "metal", rot=(18, i * 22.5, 0), anim="spin_fan"))
    a.append(P("sphere", (0.18, 0.12, 0.18), (-0.1, 3.53, 0), G, "metal"))
    for i in range(12):
        ang = 2 * math.pi * i / 12
        a.append(P("box", (0.04, 0.42, 0.1), (-0.1 + math.cos(ang) * 0.6, 3.2, math.sin(ang) * 0.6), DARK, "dark", rot=(0, -math.degrees(ang), 0)))
    # баки охлаждения по бокам
    for z in (-0.75, 0.75):
        tank_v(a, 0.62, 0.37, z, 0.2, 1.1, WH, band=G)
        pipe_run(a, [(0.62, 1.7, z), (0.62, 1.9, z), (0.42, 1.9, z * 0.5)], 0.05, G)
    # гидравлика коронки
    for z in (-0.42, 0.42):
        piston(a, -0.62, 0.8, z, 1.1, 0.07, G)
    # галерея вокруг башни
    platform(a, -0.85, 0.65, -0.85, 0.85, 2.85, DARK, rail=YEL)
    ladder(a, -0.94, 0.62, 0.37, 2.85, GD)
    panel(a, -0.84, 0.82, -0.52, G, screen="#7dff5a")
    chute(a, 0.7, 0.58, 0, GD, rollers=5)
    a.append(P("box", (0.36, 0.34, 0.6), (0.85, 0.52, 0), "#3f4247", "dark"))
    a.append(P("box", (0.06, 0.4, 0.6), (0.41, 2.05, 0), "#7dff5a", "glow", anim="pulse"))
    lamp_post(a, 0.85, -0.25, 1.4)
    beacon(a, -0.55, 3.45, -0.55, "#7dff5a")
    beacon(a, 0.35, 3.45, 0.55, "#ff8c1a")
    cable_reel(a, -0.7, 0.62, 0.2, col=G)
    sign_plate(a, 0.41, 2.62, 0.0, G, n=3)
    tier_pips(a, 0.85, 0.62, 0.38, 3, TIER_GLOW[3])
    return a


def miner_mk4():
    """Бур Mk4: красно-чёрный плазменный бур — шестигранная плита, кольца-излучатели вокруг луча, конденсаторы, катушки."""
    R, RD, BK = "#c8372d", "#8c2018", "#1e1f23"
    a = []
    hex_base(a, 1.0, 0.18, 0.36, BK, "#ff5a3a")
    for i in range(6):
        ang = 2 * math.pi * i / 6 + math.pi / 6
        x, z = math.cos(ang) * 0.85, math.sin(ang) * 0.85
        a.append(P("box", (0.22, 0.42, 0.22), (x, 0.21, z), R, rot=(0, -math.degrees(ang), 0)))
        a.append(P("cylinder", (0.14, 0.06, 0.14), (x, 0.44, z), CHR, "metal", seg=8))
    # шахта и луч
    a.append(P("cylinder", (0.9, 0.2, 0.9), (0, 0.42, 0), DARK, "dark", seg=24))
    a.append(P("cylinder", (0.2, 2.6, 0.2), (0, 1.6, 0), "#ff6a3a", "glow", anim="pulse", seg=12))
    a.append(P("cylinder", (0.36, 2.6, 0.36), (0, 1.6, 0), "#ffb08a", "glass", seg=12))
    for k, y in enumerate((0.75, 1.3, 1.85, 2.4)):
        energy_ring(a, 0, y, 0, 0.42 - k * 0.03, "#ff5a3a", anim="spin" if k % 2 == 0 else "spin_fast", thick=0.22)
    # четыре колонны-излучателя
    for i in range(4):
        ang = 2 * math.pi * i / 4 + math.pi / 4
        x, z = math.cos(ang) * 0.62, math.sin(ang) * 0.62
        a.append(P("box", (0.18, 2.6, 0.18), (x, 1.6, z), BK, "dark", rot=(0, -math.degrees(ang), 0)))
        a.append(P("box", (0.05, 2.3, 0.06), (x - math.cos(ang) * 0.1, 1.6, z - math.sin(ang) * 0.1), "#ff5a3a", "glow", anim="pulse", rot=(0, -math.degrees(ang), 0)))
        for y in (0.9, 1.6, 2.3):
            a.append(P("box", (0.26, 0.1, 0.26), (x, y, z), R, rot=(0, -math.degrees(ang), 0)))
    # верхняя корона-эмиттер
    a.append(P("cylinder", (1.5, 0.24, 1.5), (0, 3.0, 0), R, "metal", seg=6))
    a.append(P("cylinder", (1.2, 0.3, 1.2), (0, 3.25, 0), BK, "dark", seg=6))
    a.append(P("cone", (0.9, 0.6, 0.9), (0, 3.7, 0), R, "metal", seg=6))
    a.append(P("sphere", (0.36, 0.36, 0.36), (0, 4.05, 0), "#ff6a3a", "glow", anim="pulse", seg=14))
    energy_ring(a, 0, 4.05, 0, 0.32, "#ffb08a", anim="spin_fast", thick=0.15)
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.append(P("box", (0.08, 0.5, 0.08), (math.cos(ang) * 0.55, 3.55, math.sin(ang) * 0.55), CHR, "metal", rot=(math.sin(ang) * 25, 0, -math.cos(ang) * 25)))
    # батарея конденсаторов и катушки
    for k in range(3):
        a.append(P("cylinder", (0.2, 0.62, 0.2), (-0.72, 0.75, -0.3 + k * 0.3), "#3a3f47", "metal", seg=12))
        a.append(P("cylinder", (0.12, 0.06, 0.12), (-0.72, 1.1, -0.3 + k * 0.3), "#ff5a3a", "glow", anim="blink", seg=10))
    coil(a, 0.7, 0.4, -0.62, 0.15, 0.8, turns=7)
    coil(a, 0.7, 0.4, 0.62, 0.15, 0.8, turns=7)
    pipe_run(a, [(0.7, 1.22, -0.62), (0.7, 1.5, -0.62), (0.2, 1.5, -0.3)], 0.04, "#c87533")
    pipe_run(a, [(0.7, 1.22, 0.62), (0.7, 1.5, 0.62), (0.2, 1.5, 0.3)], 0.04, "#c87533")
    # радиаторы-рёбра на колоннах и кабель-каналы
    for i in range(4):
        ang = 2 * math.pi * i / 4 + math.pi / 4
        x, z = math.cos(ang) * 0.62, math.sin(ang) * 0.62
        for k in range(8):
            a.append(P("box", (0.32, 0.03, 0.32), (x, 1.05 + k * 0.17, z), "#3a3f47", "metal", rot=(0, -math.degrees(ang), 0)))
        a.append(P("box", (0.06, 0.06, 0.6), (x * 0.5, 0.5, z * 0.5), DARK, "dark", rot=(0, -math.degrees(ang) + 90, 0)))
    # внешняя вращающаяся клетка
    for i in range(8):
        ang = 2 * math.pi * i / 8
        a.append(P("box", (0.04, 1.9, 0.04), (math.cos(ang) * 0.95, 1.55, math.sin(ang) * 0.95), CHR, "metal", anim="spin_slow"))
    for y in (0.6, 2.5):
        a.append(P("torus", (1.95, 0.06, 1.95), (0, y, 0), R, "metal", anim="spin_slow", seg=32))
    # кольцевая галерея
    a.append(P("torus", (1.6, 0.18, 1.6), (0, 2.75, 0), BK, "dark", seg=24))
    for i in range(12):
        ang = 2 * math.pi * i / 12
        a.append(P("box", (0.03, 0.35, 0.03), (math.cos(ang) * 0.88, 2.93, math.sin(ang) * 0.88), YEL))
    a.append(P("torus", (1.8, 0.05, 1.8), (0, 3.1, 0), YEL, seg=32))
    # плазменные трубки от конденсаторов к лучу
    for k in range(3):
        pipe_run(a, [(-0.72, 1.12, -0.3 + k * 0.3), (-0.72, 1.35 + k * 0.08, -0.3 + k * 0.3), (-0.2, 1.35 + k * 0.08, -0.3 + k * 0.3)], 0.025, "#ff6a3a", mat="glow")
    # вентиляционные решётки в плите
    for i in range(6):
        ang = 2 * math.pi * i / 6
        for k in range(3):
            a.append(P("box", (0.2, 0.02, 0.03), (math.cos(ang) * 0.55 + math.sin(ang) * (k - 1) * 0.05, 0.37, math.sin(ang) * 0.55 - math.cos(ang) * (k - 1) * 0.05), "#ff5a3a", "glow", rot=(0, -math.degrees(ang) + 90, 0), anim="pulse"))
    # прожекторы и предупреждающие огни
    for i in range(4):
        ang = 2 * math.pi * i / 4
        a.append(P("box", (0.14, 0.1, 0.1), (math.cos(ang) * 0.68, 3.4, math.sin(ang) * 0.68), BK, "dark", rot=(0, -math.degrees(ang), 0)))
        a.append(P("box", (0.02, 0.07, 0.07), (math.cos(ang) * 0.76, 3.4, math.sin(ang) * 0.76), "#fff1c4", "glow", rot=(0, -math.degrees(ang), 0)))
    exhaust(a, -0.55, 0.9, -0.62, h=0.8, r=0.05)
    exhaust(a, -0.55, 0.9, 0.62, h=0.8, r=0.05)
    # выход и пульт
    chute(a, 0.72, 0.62, 0, RD, side="#3f4247", rollers=5)
    a.append(P("box", (0.36, 0.36, 0.62), (0.86, 0.55, 0), BK, "dark"))
    panel(a, -0.86, 0.85, 0.5, R, screen="#ff8a5a")
    beacon(a, -0.5, 3.15, 0.5, "#ff5a3a")
    sign_plate(a, 0.75, 3.0, 0.0, R, n=4)
    tier_pips(a, 0.88, 0.62, 0.4, 4, TIER_GLOW[4])
    return a


def miner_mk5():
    """Бур Mk5: фиолетово-белый квантовый экстрактор — парящие кольца, кристаллическое ядро, пилоны с дугами, антигравитационная плита."""
    PU, PUD, WH = "#8a4dff", "#5a2bb3", "#eef0ff"
    a = []
    hex_base(a, 1.0, 0.16, 0.32, "#20182e", "#d9a6ff")
    a.append(P("cylinder", (1.6, 0.1, 1.6), (0, 0.38, 0), WH, "metal", seg=6))
    for i in range(6):
        ang = 2 * math.pi * i / 6
        x, z = math.cos(ang) * 0.8, math.sin(ang) * 0.8
        a.append(P("wedge", (0.3, 0.2, 0.3), (x, 0.48, z), PU, rot=(0, -math.degrees(ang), 0)))
    # пилоны с дугами
    for i in range(3):
        ang = 2 * math.pi * i / 3 + math.pi / 2
        x, z = math.cos(ang) * 0.78, math.sin(ang) * 0.78
        a.append(P("cylinder", (0.16, 2.6, 0.16), (x, 1.75, z), WH, "metal", seg=8, top=0.6))
        a.append(P("cone", (0.24, 0.4, 0.24), (x, 3.25, z), PU, "metal", seg=8))
        a.append(P("sphere", (0.18, 0.18, 0.18), (x, 3.5, z), "#d9a6ff", "glow", anim="blink", seg=10))
        for y in (1.0, 1.8, 2.6):
            a.append(P("torus", (0.28, 0.25, 0.28), (x, y, z), PU, "glow", anim="pulse", seg=12))
        a.append(P("box", (0.03, 0.03, 0.8), (x * 0.55, 3.0, z * 0.55), "#e6ccff", "glow", anim="flicker", rot=(0, -math.degrees(ang) + 90, 0)))
    # ядро: кристалл в оболочке, кольца-гироскоп
    a.append(P("sphere", (0.9, 0.9, 0.9), (0, 1.9, 0), "#d9c2ff", "glass", seg=20))
    crystal_cluster(a, 0, 1.5, 0, "#c47dff", s=1.2)
    a.append(P("prism", (0.3, 0.9, 0.3), (0, 2.6, 0), "#e6ccff", "glow", anim="pulse", rot=(180, 0, 0)))
    energy_ring(a, 0, 1.9, 0, 0.62, PU, anim="spin", thick=0.12)
    a.append(P("torus", (1.1, 0.1, 1.1), (0, 1.9, 0), "#d9a6ff", "glow", rot=(90, 0, 0), anim="spin_slow", seg=24))
    a.append(P("torus", (1.0, 0.1, 1.0), (0, 1.9, 0), WH, "metal", rot=(0, 0, 90), anim="spin_slow", seg=24))
    # парящие кольца над и под ядром
    for k, y in enumerate((0.75, 3.05, 3.55)):
        energy_ring(a, 0, y, 0, 0.55 - k * 0.12, "#b07dff", anim="hover", thick=0.18)
    # луч в землю
    a.append(P("cone", (0.4, 1.0, 0.4), (0, 0.95, 0), "#c47dff", "glow", anim="pulse", rot=(180, 0, 0), seg=12))
    # спутники-дроны
    for i in range(3):
        ang = 2 * math.pi * i / 3
        x, z = math.cos(ang) * 0.42, math.sin(ang) * 0.42
        a.append(P("sphere", (0.12, 0.08, 0.12), (x, 3.3, z), WH, "metal", anim="hover", seg=10))
        a.append(P("box", (0.03, 0.02, 0.16), (x, 3.3, z), "#d9a6ff", "glow", anim="hover"))
    # светящиеся руны-дорожки в плите
    for i in range(6):
        ang = 2 * math.pi * i / 6 + math.pi / 6
        for k in range(4):
            r0 = 0.25 + k * 0.15
            a.append(P("box", (0.1, 0.02, 0.03), (math.cos(ang) * r0, 0.44, math.sin(ang) * r0), "#d9a6ff", "glow", rot=(0, -math.degrees(ang), 0), anim="pulse"))
    # парящие осколки по орбите
    for i in range(10):
        ang = 2 * math.pi * i / 10
        r0 = 0.95 if i % 2 == 0 else 1.0
        a.append(P("prism", (0.08, 0.22, 0.08), (math.cos(ang) * r0 * 0.55, 1.2 + (i % 3) * 0.55, math.sin(ang) * r0 * 0.55), "#c47dff", "glow", rot=(i * 17, i * 36, i * 11), anim="hover"))
    # оболочки пилонов: сегменты и катушки
    for i in range(3):
        ang = 2 * math.pi * i / 3 + math.pi / 2
        x, z = math.cos(ang) * 0.78, math.sin(ang) * 0.78
        for k in range(6):
            a.append(P("cylinder", (0.22, 0.06, 0.22), (x, 0.7 + k * 0.4, z), PUD, "metal", seg=8))
        a.append(P("box", (0.08, 0.3, 0.08), (x * 1.12, 0.6, z * 1.12), WH, "metal", rot=(0, -math.degrees(ang), 0)))
        a.append(P("wedge", (0.22, 0.18, 0.2), (x * 1.15, 0.44, z * 1.15), PU, rot=(0, -math.degrees(ang), 0)))
        # дуга между пилонами
        ang2 = ang + math.pi / 3
        a.append(P("torus", (0.9, 0.04, 0.9), (math.cos(ang2) * 0.45, 3.25, math.sin(ang2) * 0.45), "#e6ccff", "glow", rot=(90, -math.degrees(ang2), 0), anim="flicker", seg=16))
    # внешнее кольцо-ограждение на ножках
    a.append(P("torus", (2.0, 0.05, 2.0), (0, 0.62, 0), WH, "metal", seg=36))
    for i in range(12):
        ang = 2 * math.pi * i / 12
        a.append(P("cylinder", (0.04, 0.24, 0.04), (math.cos(ang) * 0.98, 0.5, math.sin(ang) * 0.98), WH, "metal", seg=6))
        a.append(P("sphere", (0.05, 0.05, 0.05), (math.cos(ang) * 0.98, 0.64, math.sin(ang) * 0.98), "#d9a6ff", "glow", anim="blink" if i % 3 == 0 else "pulse", seg=6))
    # верхняя корона
    a.append(P("cylinder", (0.6, 0.08, 0.6), (0, 3.8, 0), WH, "metal", anim="hover", seg=6))
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.append(P("prism", (0.08, 0.3, 0.08), (math.cos(ang) * 0.26, 3.98, math.sin(ang) * 0.26), "#e6ccff", "glow", anim="hover", rot=(math.sin(ang) * 15, 0, -math.cos(ang) * 15)))
    a.append(P("sphere", (0.2, 0.2, 0.2), (0, 4.05, 0), "#ffffff", "glow", anim="pulse", seg=12))
    # выход и пульт-голограмма
    chute(a, 0.72, 0.62, 0, PUD, side=WH, rollers=5)
    a.append(P("box", (0.36, 0.34, 0.62), (0.86, 0.55, 0), "#20182e", "dark"))
    a.append(P("cylinder", (0.32, 0.5, 0.32), (-0.82, 0.65, 0.0), WH, "metal", seg=10))
    a.append(P("box", (0.02, 0.32, 0.42), (-0.82, 1.18, 0), "#d9a6ff", "glow", anim="flicker_soft", rot=(0, 90, 0)))
    a.append(P("cylinder", (0.36, 0.04, 0.36), (-0.82, 0.92, 0), "#d9a6ff", "glow", anim="pulse", seg=10))
    sign_plate(a, 0.0, 0.5, 0.82, PU, face="z", n=5)
    tier_pips(a, 0.88, 0.62, 0.4, 5, TIER_GLOW[5])
    return a


MINERS = [
    ("miner", "Бур", miner_mk1),
    ("miner_mk2", "Бур Mk2", miner_mk2),
    ("miner_mk3", "Бур Mk3", miner_mk3),
    ("miner_mk4", "Бур Mk4", miner_mk4),
    ("miner_mk5", "Бур Mk5", miner_mk5),
]
MINER_EMIT = {
    "miner": [{"kind": "dust", "pos": [-0.1, 0.45, 0.0], "when": "active", "rate": 1.0, "size": 0.7},
              {"kind": "puff", "pos": [-0.6, 3.75, -0.45], "when": "active", "rate": 0.5, "size": 0.6}],
    "miner_mk2": [{"kind": "dust", "pos": [-0.15, 0.4, 0.0], "when": "active", "rate": 1.4, "size": 0.8},
                  {"kind": "puff", "pos": [0.2, 4.25, -0.35], "when": "active", "rate": 0.6, "size": 0.7},
                  {"kind": "puff", "pos": [0.2, 4.25, 0.35], "when": "active", "rate": 0.6, "size": 0.7}],
    "miner_mk3": [{"kind": "dust", "pos": [-0.1, 0.4, 0.0], "when": "active", "rate": 1.6, "size": 0.8}],
    "miner_mk4": [{"kind": "spark", "pos": [0.0, 0.5, 0.0], "when": "active", "rate": 2.0, "size": 0.5}],
    "miner_mk5": [{"kind": "spark", "pos": [0.0, 1.9, 0.0], "when": "active", "rate": 1.4, "size": 0.4}],
}


# ================================================================== ленты
# Прямой кусок ленты: 2 x 2 клетки по X (длина 2.0), ширина 1.3. Первая деталь с материалом belt — полотно.
BELT_COL = {1: "#6b7079", 2: "#4f6f9c", 3: "#5f8f4f", 4: "#9c4f4a", 5: "#7a5aa6"}


def belt_model(t):
    col = BELT_COL[t]
    rail = shade(col, 0.6)
    a = [P("box", (2.0, 0.26, 1.3), (0, 0.13, 0), col, "belt")]
    # борта с рёбрами
    for z in (-0.68, 0.68):
        a.append(P("box", (2.0, 0.14 + 0.02 * t, 0.08), (0, 0.22 + 0.01 * t, z), rail, "dark"))
        a.append(P("box", (2.0, 0.03, 0.1), (0, 0.3 + 0.02 * t, z), TIER_COL[t] if t > 1 else STEEL, "metal" if t < 3 else "paint"))
        for i in range(4):
            a.append(P("box", (0.04, 0.12, 0.1), (-0.75 + i * 0.5, 0.2, z), DARK, "dark"))
    # ролики под полотном по краям
    for x in (-0.94, 0.94):
        a.append(P("cylinder", (0.12, 1.3, 0.12), (x, 0.13, 0), STEEL, "metal", rot=(90, 0, 0), anim="spin_fast", seg=8))
    # ножки
    for x in (-0.6, 0.6):
        for z in (-0.6, 0.6):
            a.append(P("box", (0.07, 0.1, 0.07), (x, 0.05, z), DARK, "dark"))
    # метки уровня на борту
    if t >= 2:
        for i in range(t):
            a.append(P("box", (0.06, 0.04, 0.02), (-0.15 * (t - 1) / 2 + i * 0.15, 0.26, 0.73), TIER_GLOW[t], "glow"))
            a.append(P("box", (0.06, 0.04, 0.02), (-0.15 * (t - 1) / 2 + i * 0.15, 0.26, -0.73), TIER_GLOW[t], "glow"))
    if t >= 4:
        for z in (-0.72, 0.72):
            a.append(P("box", (1.9, 0.02, 0.02), (0, 0.33 + 0.02 * t, z), TIER_GLOW[t], "glow", anim="pulse"))
    return a


BELTS = [  # id, имя, предметов в минуту
    ("belt", "Конвейер", 60), ("belt_mk2", "Конвейер Mk2", 120), ("belt_mk3", "Конвейер Mk3", 270),
    ("belt_mk4", "Конвейер Mk4", 480), ("belt_mk5", "Конвейер Mk5", 780),
]


# ================================================================== трубы
PIPE_COL = {1: "#7d8a99", 2: "#d9822b", 3: "#3aa35a", 4: "#c8372d", 5: "#8a4dff"}
PIPE_R = {1: 0.32, 2: 0.4, 3: 0.46, 4: 0.52, 5: 0.58}
PIPE_Y = 0.45
FLANGE = "#4a525c"


def pipe_hub(t):
    col, r = PIPE_COL[t], PIPE_R[t]
    a = [
        P("box", (0.5 + 0.04 * t, 0.05, 0.5 + 0.04 * t), (0, 0.025, 0), DARK, "dark"),
        P("cylinder", (0.12, PIPE_Y, 0.12), (0, PIPE_Y * 0.5, 0), FLANGE, "metal", seg=6),
        P("sphere", (r * 1.35, r * 1.35, r * 1.35), (0, PIPE_Y, 0), col, "metal", seg=14),
        P("cylinder", (r * 1.5, 0.07, r * 1.5), (0, PIPE_Y + r * 0.62, 0), FLANGE, "metal", seg=12),
        P("cylinder", (r * 0.8, 0.06, r * 0.8), (0, PIPE_Y + r * 0.7, 0), "#ffffff", "glow", role="fluid_color", tint=False, seg=12),
    ]
    # болты фланца
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.append(P("cylinder", (0.04, 0.05, 0.04), (math.cos(ang) * r * 0.62, PIPE_Y + r * 0.66, math.sin(ang) * r * 0.62), CHR, "metal", seg=6))
    # подпорка-хомут
    a.append(P("box", (0.06, PIPE_Y - r * 0.5, 0.3), (0.12, (PIPE_Y - r * 0.5) / 2, 0), DARK, "dark"))
    a.append(P("box", (0.06, PIPE_Y - r * 0.5, 0.3), (-0.12, (PIPE_Y - r * 0.5) / 2, 0), DARK, "dark"))
    if t >= 2:
        # вентиль-штурвал
        a.append(P("cylinder", (0.05, 0.16, 0.05), (0, PIPE_Y + r * 0.7 + 0.08, -r * 0.4), CHR, "metal", seg=6))
        a.append(P("torus", (0.22, 0.2, 0.22), (0, PIPE_Y + r * 0.7 + 0.17, -r * 0.4), "#c03020", seg=12))
    if t >= 3:
        a.append(P("cylinder", (0.12, 0.03, 0.12), (r * 0.69, PIPE_Y, 0), "#f2f2f2", rot=(0, 0, 90), seg=12))
    for i in range(t):
        a.append(P("box", (0.04, 0.03, 0.08), (-0.06 * (t - 1) + i * 0.12, PIPE_Y - r * 0.68, 0), TIER_GLOW[t], "glow"))
    return a


def pipe_arm(t):
    col, r = PIPE_COL[t], PIPE_R[t]
    a = [
        P("cylinder", (r, 1.0, r), (0.5, PIPE_Y, 0), col, "metal", rot=(0, 0, 90), role="stretch", seg=12),
        P("cylinder", (r * 1.25, 0.06, r * 1.25), (0.5, PIPE_Y, 0), FLANGE, "metal", rot=(0, 0, 90), role="stretch", seg=12),
    ]
    if t >= 3:
        a.append(P("cylinder", (r * 1.08, 0.5, r * 1.08), (0.5, PIPE_Y, 0), shade(col, 0.7), "metal", rot=(0, 0, 90), role="stretch", seg=12))
    if t >= 4:
        a.append(P("cylinder", (r * 0.4, 1.0, r * 0.4), (0.5, PIPE_Y + r * 0.5, 0), TIER_GLOW[t], "glow", rot=(0, 0, 90), role="stretch", anim="pulse", seg=8))
    return a


PIPES = [  # id, имя, в минуту, ёмкость
    ("pipe", "Труба", 300, 5), ("pipe_mk2", "Труба Mk2", 600, 10), ("pipe_mk3", "Труба Mk3", 900, 15),
    ("pipe_mk4", "Труба Mk4", 1200, 20), ("pipe_mk5", "Труба Mk5", 1800, 30),
]


def all_models():
    out = {}
    for i, (mid, name, fn) in enumerate(MINERS):
        out[mid] = M(name, fn(), "Добыча")
        out[mid]["emitters"] = MINER_EMIT[mid]
    for i, (bid, name, _) in enumerate(BELTS):
        out[bid] = M(name, belt_model(i + 1), "Логистика")
    for i, (pid, name, _, _) in enumerate(PIPES):
        t = i + 1
        out[pid] = M(name + " (узел)", pipe_hub(t), "Жидкости")
        out["pipe_arm" + ("" if t == 1 else "_mk%d" % t)] = M(name + " (отрезок)", pipe_arm(t), "Жидкости")
    return out
