# Детализация каталога: общие «обвесы» для машин и зданий — стойки, обшивка с решётками, кабели, трубы, лестницы.
# Всё ставится по краям клетки, чтобы не задевать саму машину (она стоит в середине).
import math
from art_kit import *

HAZ = "#f2b21f"


def hazard_strip(a, x0, x1, z, y, n=6, along="x"):
    """Жёлто-чёрная полоса по краю плиты."""
    L = (x1 - x0) / n
    for i in range(n):
        c = HAZ if i % 2 == 0 else "#1d1e21"
        x = x0 + L * (i + 0.5)
        if along == "x":
            a.append(P("box", (L * 0.98, 0.025, 0.07), (x, y, z), c, "paint", tint=False))
        else:
            a.append(P("box", (0.07, 0.025, L * 0.98), (z, y, x), c, "paint", tint=False))


def vent_panel(a, x, y, z, w, h, col, face_z=1, slats=4):
    """Лист обшивки на стенке (по оси x) с решёткой и болтами."""
    fz = z + face_z * 0.025
    a.append(P("box", (w, h, 0.04), (x, y, z), shade(col, 0.9)))
    for i in range(slats):
        a.append(P("box", (w * 0.7, 0.03, 0.02), (x, y - h * 0.3 + i * h * 0.6 / max(1, slats - 1), fz), "#16171a", "dark", tint=False))
    for dx in (-1, 1):
        for dy in (-1, 1):
            a.append(P("cylinder", (0.035, 0.02, 0.035), (x + dx * (w / 2 - 0.04), y + dy * (h / 2 - 0.04), fz), CHR, "metal", rot=(90, 0, 0), seg=6, tint=False))


def corner_posts(a, h, col, acc, t, r=0.86):
    for x in (-r, r):
        for z in (-r, r):
            a.append(P("box", (0.09, h, 0.09), (x, 0.28 + h / 2, z), shade(col, 0.6), "metal"))
            a.append(P("box", (0.13, 0.05, 0.13), (x, 0.28 + h, z), DARK, "dark"))
            a.append(P("box", (0.13, 0.06, 0.13), (x, 0.31, z), DARK, "dark"))
            if t >= 2:
                a.append(P("box", (0.02, h * 0.7, 0.03), (x + (0.05 if x > 0 else -0.05), 0.28 + h * 0.5, z), acc, "glow", anim="pulse", tint=False))


def cable_tray(a, x0, x1, z, y, col=DARK):
    a.append(P("box", (x1 - x0, 0.04, 0.14), ((x0 + x1) / 2, y, z), col, "dark"))
    for k, c in enumerate(("#1d1e21", "#c03020", "#2f5fa8")):
        a.append(P("cylinder", (0.035, x1 - x0, 0.035), ((x0 + x1) / 2, y + 0.04, z - 0.04 + k * 0.04), c, "cloth", rot=(0, 0, 90), seg=6, tint=False))
    for x in (x0 + 0.05, x1 - 0.05):
        a.append(P("box", (0.04, y - 0.28, 0.04), (x, (y + 0.28) / 2, z), col, "dark"))


def side_pipe(a, x0, x1, z, y, col=CHR, valve=YEL):
    a.append(P("cylinder", (0.08, x1 - x0, 0.08), ((x0 + x1) / 2, y, z), col, "metal", rot=(0, 0, 90), seg=10))
    for x in (x0 + 0.06, x1 - 0.06, (x0 + x1) / 2):
        a.append(P("cylinder", (0.12, 0.03, 0.12), (x, y, z), DARK, "dark", rot=(0, 0, 90), seg=10))
    a.append(P("cylinder", (0.04, 0.12, 0.04), ((x0 + x1) / 2, y + 0.1, z), col, "metal", seg=6))
    a.append(P("torus", (0.14, 0.2, 0.14), ((x0 + x1) / 2, y + 0.17, z), valve, "paint", seg=10, tint=False))
    for x in (x0 + 0.06, x1 - 0.06):
        a.append(P("box", (0.03, y - 0.28, 0.03), (x, (y + 0.28) / 2, z), DARK, "dark"))


def capacitor_bank(a, x, z, col, acc, n=2):
    for i in range(n):
        zz = z + (i - (n - 1) / 2) * 0.16
        a.append(P("cylinder", (0.13, 0.36, 0.13), (x, 0.47, zz), col, "metal", seg=10))
        a.append(P("cylinder", (0.09, 0.03, 0.09), (x, 0.66, zz), acc, "glow", seg=10, anim="pulse", tint=False))


def nameplate(a, x, y, z, acc, face="z"):
    if face == "z":
        a.append(P("box", (0.34, 0.12, 0.02), (x, y, z), "#e8e8e2", "paint", tint=False))
        a.append(P("box", (0.26, 0.04, 0.025), (x, y, z), acc, "glow", tint=False))
    else:
        a.append(P("box", (0.02, 0.12, 0.34), (x, y, z), "#e8e8e2", "paint", tint=False))
        a.append(P("box", (0.025, 0.04, 0.26), (x, y, z), acc, "glow", tint=False))


def detail_machine(a, main, acc, t):
    """Обвес производственной машины уровня t (1..5): чем выше уровень, тем богаче."""
    h = 0.6 + 0.12 * t
    corner_posts(a, h, main, acc, t)
    hazard_strip(a, -0.7, 0.7, 0.8, 0.3, n=8)
    hazard_strip(a, -0.7, 0.7, -0.8, 0.3, n=8)
    # обшивка с решётками на боковых стенках у выхода
    for zs in (-1, 1):
        vent_panel(a, 0.58, 0.55, zs * 0.9, 0.42, 0.42, main, face_z=zs, slats=4 if t < 3 else 6)
    cable_tray(a, -0.82, -0.36, 0.9, 0.78)
    nameplate(a, 0.58, 0.88, 0.93, acc)
    if t >= 2:
        side_pipe(a, -0.82, -0.36, -0.9, 0.62)
        for k in range(t):
            a.append(P("box", (0.03, 0.22, 0.4), (-0.95, 0.55 + k * 0.05, 0.05), shade(main, 0.7), "metal"))
    if t >= 3:
        ladder(a, 0.95, 0.6, 0.3, 0.3 + h, DARK, along="z", w=0.26)
        a.append(P("box", (0.5, 0.04, 0.5), (0.6, 0.3 + h, 0.6), DARK, "dark"))
        for x, z in ((0.85, 0.85), (0.35, 0.85), (0.85, 0.35)):
            a.append(P("cylinder", (0.03, 0.4, 0.03), (x, 0.5 + h, z), YEL, "paint", seg=6, tint=False))
        a.append(P("box", (0.5, 0.03, 0.03), (0.6, 0.7 + h, 0.85), YEL, "paint", tint=False))
        a.append(P("box", (0.03, 0.03, 0.5), (0.85, 0.7 + h, 0.6), YEL, "paint", tint=False))
    if t >= 4:
        capacitor_bank(a, -0.6, -0.72, shade(main, 0.8), acc, n=2)
        for x in (-0.86, 0.86):
            for z in (-0.86, 0.86):
                a.append(P("sphere", (0.09, 0.09, 0.09), (x, 0.36 + h, z), acc, "glow", anim="blink", tint=False))
    if t >= 5:
        a.append(P("cylinder", (0.12, 1.0, 0.12), (0.7, 0.8, -0.7), DARK, "dark", seg=10))
        for k in range(4):
            a.append(P("torus", (0.26, 0.3, 0.26), (0.7, 0.45 + k * 0.2, -0.7), "#c87533", "metal", seg=12, tint=False))
        a.append(P("sphere", (0.2, 0.2, 0.2), (0.7, 1.35, -0.7), acc, "glow", anim="pulse", tint=False))
        exhaust(a, -0.6, 1.1 + h * 0.3, 0.72, h=0.6, r=0.05)


def detail_base(a, col, acc, w=0.9):
    """Лёгкий обвес для энергетики, складов и жидкостей: полосы по краю, болты, табличка."""
    hazard_strip(a, -w + 0.15, w - 0.15, w - 0.08, 0.2, n=8)
    hazard_strip(a, -w + 0.15, w - 0.15, -w + 0.08, 0.2, n=8)
    for x in (-w + 0.06, w - 0.06):
        for z in (-w * 0.5, 0.0, w * 0.5):
            a.append(P("cylinder", (0.05, 0.03, 0.05), (x, 0.2, z), CHR, "metal", seg=6, tint=False))
    a.append(P("box", (0.06, 0.08, 0.06), (w - 0.04, 0.24, w - 0.04), acc, "glow", anim="blink", tint=False))
