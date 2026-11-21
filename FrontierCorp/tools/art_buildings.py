# Подробные модели основных зданий (12.2). Всё правится в редакторе моделей.
# Клетка 2×2 м: здание размера 1 помещается в квадрат от -1 до 1 по X и Z. Выход машин — по +X.
import math
from art_kit import *

CONC = "#9e9c91"
BRICK, BRICK_D = "#8a4a32", "#6b3826"
WOOD, WOOD_D = "#8a5a32", "#5c3d24"


def foundation_pad(a, w=1.9, d=1.9, h=0.18, col=CONC):
    a.append(P("box", (w, h, d), (0, h / 2, 0), col, "concrete"))
    a.append(P("box", (w + 0.04, 0.04, d + 0.04), (0, h, 0), shade(col, 0.8), "concrete"))
    for x in (-w / 2 + 0.1, w / 2 - 0.1):
        for z in (-d / 2 + 0.1, d / 2 - 0.1):
            a.append(P("cylinder", (0.07, 0.04, 0.07), (x, h + 0.02, z), CHR, "metal", seg=6))


def io_marks(a, y=0.3, out_col="#ffb040", in_col="#40c8ff"):
    """Стрелка выхода на +X и люки входа."""
    a.append(P("prism", (0.18, 0.04, 0.3), (0.86, y, 0), out_col, "glow", rot=(0, 0, -90), anim="pulse"))
    a.append(P("box", (0.06, 0.28, 0.6), (0.92, y + 0.1, 0), DARK, "dark"))
    a.append(P("box", (0.6, 0.28, 0.06), (0, y + 0.1, 0.92), DARK, "dark"))
    a.append(P("box", (0.6, 0.28, 0.06), (0, y + 0.1, -0.92), DARK, "dark"))
    a.append(P("box", (0.06, 0.28, 0.6), (-0.92, y + 0.1, 0), DARK, "dark"))


def chimney(a, x, z, y0, h, r, col=BRICK, cap=DARK, brick=True):
    a.append(P("cylinder" if not brick else "box", (r * 2, h, r * 2), (x, y0 + h / 2, z), col, "stone" if brick else "metal", seg=10))
    if brick:
        for i in range(int(h / 0.3)):
            a.append(P("box", (r * 2 + 0.02, 0.025, r * 2 + 0.02), (x, y0 + 0.15 + i * 0.3, z), shade(col, 0.8), "stone"))
    a.append(P("box" if brick else "cylinder", (r * 2.4, 0.1, r * 2.4), (x, y0 + h + 0.05, z), cap, "dark", seg=10))
    a.append(P("box" if brick else "cylinder", (r * 1.4, 0.04, r * 1.4), (x, y0 + h + 0.11, z), "#141414", "dark", seg=10))


def furnace():
    """Каменная печь: кладка из блоков, арка с огнём, решётка, поддувало, труба, мехи, ведро с углём."""
    a = []
    ST, SD = "#7d7466", "#5f574c"
    a.append(P("box", (1.86, 0.16, 1.86), (0, 0.08, 0), "#6b6357", "stone"))
    # кладка: ряды камней со смещением
    for row in range(5):
        y = 0.26 + row * 0.22
        off = 0.0 if row % 2 == 0 else 0.22
        for side in range(4):
            for k in range(4):
                t = -0.66 + off + k * 0.44
                if t > 0.78:
                    continue
                col = ST if (row + k + side) % 3 else SD
                if side == 0:
                    pos, sz = (t, y, 0.78), (0.42, 0.2, 0.2)
                elif side == 1:
                    pos, sz = (t, y, -0.78), (0.42, 0.2, 0.2)
                elif side == 2:
                    pos, sz = (-0.78, y, t), (0.2, 0.2, 0.42)
                else:
                    if abs(t) < 0.4 and row < 3:
                        continue   # топка
                    pos, sz = (0.78, y, t), (0.2, 0.2, 0.42)
                a.append(P("box", sz, pos, col, "stone"))
    a.append(P("box", (1.4, 1.1, 1.4), (0, 0.72, 0), SD, "stone"))
    # свод и купол
    a.append(P("box", (1.72, 0.14, 1.72), (0, 1.38, 0), "#6b6357", "stone"))
    a.append(P("sphere", (1.4, 0.8, 1.4), (0, 1.45, 0), ST, "stone", seg=10))
    # топка: арка, огонь, решётка
    a.append(P("box", (0.06, 0.62, 0.62), (0.82, 0.62, 0), "#1a1210", "dark"))
    a.append(P("torus", (0.62, 0.3, 0.62), (0.84, 0.82, 0), SD, "stone", rot=(0, 0, 90), seg=12))
    a.append(P("box", (0.05, 0.4, 0.5), (0.8, 0.52, 0), "#ff6a1a", "glow", anim="flicker"))
    a.append(P("sphere", (0.3, 0.25, 0.4), (0.7, 0.42, 0), "#ffb040", "glow", anim="flicker", seg=8))
    for k in range(5):
        a.append(P("box", (0.03, 0.5, 0.03), (0.86, 0.6, -0.2 + k * 0.1), DARK, "metal"))
    a.append(P("box", (0.06, 0.12, 0.5), (0.84, 0.24, 0), "#2a1d14", "dark"))
    # труба
    chimney(a, -0.45, -0.45, 1.5, 1.0, 0.2, col="#5a5249")
    # мехи сбоку
    a.append(P("wedge", (0.5, 0.3, 0.4), (-0.4, 0.4, 0.98), WOOD, "wood", rot=(0, 90, 0)))
    a.append(P("box", (0.5, 0.08, 0.36), (-0.4, 0.58, 0.98), "#4a2e1a", "cloth", anim="breathe"))
    a.append(P("cylinder", (0.05, 0.4, 0.05), (-0.1, 0.45, 0.98), DARK, "metal", rot=(0, 0, 90), seg=6))
    # ведро угля и кочерга
    a.append(P("cylinder", (0.3, 0.26, 0.3), (0.72, 0.29, 0.7), "#5a5f68", "metal", seg=10))
    a.append(P("sphere", (0.26, 0.12, 0.26), (0.72, 0.42, 0.7), "#1e1e22", "stone", seg=6))
    a.append(P("cylinder", (0.03, 0.9, 0.03), (0.82, 0.55, -0.68), DARK, "metal", rot=(0, 0, 20), seg=6))
    return a


def smelter(tier=1):
    """Плавильня: кирпичная печь с тиглем, желобом жидкого металла, вытяжкой и трубой; Mk2 — стальная с синими панелями."""
    a = []
    MAIN = "#4d3329" if tier == 1 else "#5a5f69"
    ACC = YEL if tier == 1 else "#3a7bd5"
    foundation_pad(a)
    # корпус печи
    a.append(P("box", (1.3, 1.3, 1.3), (-0.15, 0.83, 0), MAIN, "stone" if tier == 1 else "metal"))
    for y in (0.4, 0.83, 1.26):
        a.append(P("box", (1.34, 0.06, 1.34), (-0.15, y, 0), shade(MAIN, 0.7), "dark"))
    for x in (-0.78, 0.48):
        for z in (-0.63, 0.63):
            a.append(P("box", (0.12, 1.36, 0.12), (x, 0.86, z), DARK, "dark"))
    # тигель сверху
    a.append(P("cylinder", (0.9, 0.5, 0.9), (-0.15, 1.73, 0), "#3a3f47", "metal", seg=14, top=1.15))
    a.append(P("cylinder", (0.8, 0.06, 0.8), (-0.15, 1.99, 0), "#ff7a1a", "glow", anim="flicker", seg=14))
    a.append(P("torus", (1.02, 0.12, 1.02), (-0.15, 1.98, 0), DARK, "dark", seg=16))
    # смотровое окно с огнём
    a.append(P("box", (0.06, 0.4, 0.6), (0.52, 0.85, 0), "#1a1210", "dark"))
    a.append(P("box", (0.05, 0.32, 0.5), (0.53, 0.85, 0), "#ff6a1a", "glow", anim="flicker"))
    for k in range(4):
        a.append(P("box", (0.03, 0.4, 0.03), (0.56, 0.85, -0.22 + k * 0.15), DARK, "metal"))
    # жёлоб жидкого металла к выходу
    a.append(P("box", (0.5, 0.08, 0.2), (0.75, 0.62, 0), "#3a3f47", "metal", rot=(0, 0, -12)))
    a.append(P("box", (0.46, 0.03, 0.12), (0.75, 0.67, 0), "#ffb040", "glow", rot=(0, 0, -12), anim="pulse"))
    a.append(P("box", (0.3, 0.3, 0.5), (0.82, 0.38, 0), DARK, "dark"))
    # изложница со слитками
    for k in range(3):
        a.append(P("box", (0.22, 0.06, 0.12), (0.82, 0.56, -0.15 + k * 0.15), "#c0c4cc", "metal"))
    # вытяжка и труба
    a.append(P("cone", (0.9, 0.4, 0.9), (-0.15, 2.25, 0), "#5a5f68", "metal", seg=8, rot=(0, 22.5, 0)))
    chimney(a, -0.55, -0.5, 1.5, 1.6, 0.16, col="#5a5249" if tier == 1 else "#7d8a99", brick=tier == 1)
    # трубы подачи газа и манометр
    pipe_run(a, [(-0.85, 0.3, 0.55), (-0.85, 1.1, 0.55), (-0.6, 1.1, 0.55)], 0.05, ACC)
    a.append(P("cylinder", (0.16, 0.04, 0.16), (-0.81, 0.8, 0.55), "#f2f2f2", rot=(0, 0, 90), seg=12))
    # табличка и полоса уровня
    a.append(P("box", (0.5, 0.16, 0.04), (-0.15, 1.15, 0.67), ACC))
    if tier >= 2:
        a.append(P("box", (0.2, 0.16, 0.05), (0.2, 1.15, 0.67), "#ffffff", "glow"))
        motor(a, -0.15, 0.55, -0.85, 0.16, 0.3, ACC, fins=4, fan=False, axis="z")
    io_marks(a, 0.18)
    return a


def assembler(tier=1):
    """Сборщик: рама с робо-рукой над столом, конвейер внутри, панели и кабели; Mk2 — фиолетовый с двумя руками."""
    a = []
    MAIN = "#2e6bc7" if tier == 1 else "#7a2ec7"
    ACC = YEL if tier == 1 else "#ffd11a"
    foundation_pad(a)
    # рама-каркас
    lattice(a, -0.8, 0.8, -0.8, 0.8, 0.18, 1.9, shade(MAIN, 0.7), levels=2, braces=False, thick=0.12)
    a.append(P("box", (1.7, 0.12, 1.7), (0, 1.95, 0), MAIN))
    a.append(P("box", (1.2, 0.08, 1.2), (0, 2.04, 0), DARK, "dark"))
    # низкие боковые щиты и кабель-каналы (верх открыт — видно руку)
    for z in (-0.8, 0.8):
        a.append(P("box", (1.5, 0.35, 0.04), (0, 0.38, z), shade(MAIN, 0.85)))
        a.append(P("box", (1.5, 0.06, 0.08), (0, 1.5, z), DARK, "dark"))
        for k in range(5):
            a.append(P("box", (0.03, 0.3, 0.05), (-0.6 + k * 0.3, 0.38, z * 1.01), ACC if k % 2 else DARK, "paint"))
    # стол и лента внутри
    a.append(P("box", (1.3, 0.5, 0.7), (0, 0.45, 0), "#3a3f47", "metal"))
    a.append(P("box", (1.3, 0.04, 0.5), (0, 0.72, 0), "#2a2d33", "belt"))
    for k in range(3):
        a.append(P("box", (0.18, 0.12, 0.18), (-0.4 + k * 0.4, 0.8, 0), "#c0c4cc", "metal", anim="jitter"))
    # робо-рука(и)
    arms = [(-0.25, 0.0)] if tier == 1 else [(-0.4, -0.2), (0.4, 0.2)]
    for (x, z) in arms:
        a.append(P("cylinder", (0.3, 0.14, 0.3), (x, 1.82, z), DARK, "dark", seg=12))
        a.append(P("cylinder", (0.16, 0.5, 0.16), (x, 1.55, z), ACC, anim="swing", seg=10))
        a.append(P("sphere", (0.2, 0.2, 0.2), (x, 1.3, z), DARK, "dark", seg=10))
        a.append(P("box", (0.12, 0.45, 0.12), (x + 0.12, 1.1, z), ACC, rot=(0, 0, 25), anim="swing"))
        a.append(P("box", (0.06, 0.16, 0.04), (x + 0.22, 0.92, z + 0.05), CHR, "metal", anim="piston"))
        a.append(P("box", (0.06, 0.16, 0.04), (x + 0.22, 0.92, z - 0.05), CHR, "metal", anim="piston"))
        a.append(P("sphere", (0.06, 0.06, 0.06), (x + 0.22, 0.86, z), "#40c8ff", "glow", anim="blink"))
    # пульт и кабели
    panel(a, -0.86, 0.6, 0.45, MAIN, face=-1, w=0.5, h=0.7, screen="#40ffb0")
    for k in range(3):
        a.append(P("torus", (0.3, 0.3, 0.12), (-0.86, 1.4 + k * 0.08, -0.4 + k * 0.1), "#1d1e21", "cloth", rot=(0, 0, 90), seg=10))
    beacon(a, 0.6, 2.1, 0.6, "#40c8ff" if tier == 1 else "#ffd11a")
    a.append(P("box", (0.5, 0.18, 0.04), (0, 1.75, 0.82), ACC))
    io_marks(a, 0.18)
    return a


def workbench():
    """Верстак: столешница на козлах, тиски, инструменты на щите, ящик с гвоздями."""
    a = []
    for x in (-0.7, 0.7):
        for z in (-0.4, 0.4):
            a.append(P("box", (0.1, 0.8, 0.1), (x, 0.4, z), WOOD_D, "wood"))
        a.append(P("box", (0.08, 0.08, 0.9), (x, 0.22, 0), WOOD_D, "wood"))
    a.append(P("box", (1.6, 0.06, 0.08), (0, 0.22, 0.4), WOOD_D, "wood"))
    a.append(P("box", (1.7, 0.1, 1.0), (0, 0.85, 0), WOOD, "wood"))
    for k in range(4):
        a.append(P("box", (1.7, 0.012, 0.02), (0, 0.905, -0.375 + k * 0.25), WOOD_D, "wood"))
    a.append(P("box", (1.5, 0.05, 0.8), (0, 0.35, 0), WOOD_D, "wood"))
    # тиски
    a.append(P("box", (0.2, 0.16, 0.24), (0.62, 0.98, 0.32), "#3a5f8a", "metal"))
    a.append(P("box", (0.06, 0.16, 0.24), (0.74, 0.98, 0.32), "#3a5f8a", "metal"))
    a.append(P("cylinder", (0.03, 0.3, 0.03), (0.8, 0.96, 0.32), CHR, "metal", rot=(0, 0, 90), seg=6))
    # щит с инструментами
    a.append(P("box", (1.5, 0.8, 0.05), (0, 1.35, -0.48), WOOD, "wood"))
    a.append(P("box", (0.06, 1.1, 0.06), (-0.72, 1.2, -0.48), WOOD_D, "wood"))
    a.append(P("box", (0.06, 1.1, 0.06), (0.72, 1.2, -0.48), WOOD_D, "wood"))
    a.append(P("box", (0.05, 0.38, 0.04), (-0.5, 1.35, -0.44), WOOD_D, "wood"))
    a.append(P("box", (0.18, 0.08, 0.04), (-0.5, 1.52, -0.44), "#9aa3ad", "metal"))
    a.append(P("box", (0.05, 0.42, 0.04), (-0.25, 1.33, -0.44), "#c03020", "paint"))
    a.append(P("box", (0.2, 0.05, 0.04), (-0.25, 1.52, -0.44), "#9aa3ad", "metal"))
    a.append(P("torus", (0.2, 0.25, 0.2), (0.05, 1.45, -0.44), "#9aa3ad", "metal", rot=(90, 0, 0), seg=10))
    a.append(P("box", (0.32, 0.04, 0.04), (0.35, 1.5, -0.44), "#9aa3ad", "metal", rot=(0, 0, 20)))
    a.append(P("box", (0.04, 0.36, 0.04), (0.55, 1.35, -0.44), "#d9a400", "metal"))
    # предметы на столе: доска, молоток, гвозди, чертёж
    a.append(P("box", (0.6, 0.04, 0.16), (-0.35, 0.92, 0.2), "#c49a6c", "wood", rot=(0, 15, 0)))
    a.append(P("box", (0.04, 0.04, 0.3), (0.1, 0.93, 0.15), WOOD_D, "wood", rot=(0, 30, 0)))
    a.append(P("box", (0.14, 0.07, 0.06), (0.17, 0.93, 0.03), "#5a5f68", "metal", rot=(0, 30, 0)))
    a.append(P("box", (0.5, 0.005, 0.36), (0.25, 0.905, -0.18), "#d8e6f2", "paint", rot=(0, -8, 0)))
    a.append(P("box", (0.3, 0.006, 0.02), (0.25, 0.91, -0.18), "#2f6fc4", "paint", rot=(0, -8, 0)))
    a.append(P("box", (0.3, 0.2, 0.2), (-0.6, 0.48, 0.25), WOOD_D, "wood"))
    for k in range(4):
        a.append(P("cylinder", (0.012, 0.06, 0.012), (-0.66 + k * 0.04, 0.6, 0.25), CHR, "metal", seg=4))
    a.append(P("cylinder", (0.18, 0.06, 0.18), (0.5, 0.1, 0.55), "#c49a6c", "wood", seg=8))
    return a


def workshop():
    """Мастерская: станок с наковальней, точило, верстак с тисками, полки с деталями, лампа."""
    a = []
    foundation_pad(a, h=0.12)
    # наковальня
    a.append(P("box", (0.3, 0.35, 0.3), (0.45, 0.3, 0.4), "#3a3f47", "metal"))
    a.append(P("box", (0.55, 0.14, 0.22), (0.45, 0.54, 0.4), "#2a2d33", "metal"))
    a.append(P("prism", (0.2, 0.14, 0.22), (0.8, 0.54, 0.4), "#2a2d33", "metal", rot=(0, 0, -90)))
    # точило с крутящимся кругом
    a.append(P("box", (0.3, 0.6, 0.3), (-0.5, 0.42, 0.45), "#3a5f8a", "metal"))
    a.append(P("cylinder", (0.36, 0.06, 0.36), (-0.5, 0.9, 0.45), "#c8c0b0", "stone", rot=(90, 0, 0), anim="spin_fast", seg=16))
    a.append(P("cylinder", (0.05, 0.3, 0.05), (-0.5, 0.9, 0.45), CHR, "metal", rot=(90, 0, 0), seg=6))
    # верстак сзади
    a.append(P("box", (1.6, 0.08, 0.6), (0, 0.85, -0.5), WOOD, "wood"))
    for x in (-0.72, 0.72):
        a.append(P("box", (0.08, 0.75, 0.5), (x, 0.47, -0.5), WOOD_D, "wood"))
    a.append(P("box", (0.18, 0.14, 0.2), (0.5, 0.96, -0.5), "#c03020", "metal"))
    # полки с деталями
    for y in (1.2, 1.55):
        a.append(P("box", (1.5, 0.05, 0.3), (0, y, -0.78), WOOD, "wood"))
        for k in range(5):
            col = ("#c0c4cc", "#d9822b", "#9aa3ad", YEL, "#3a7bd5")[k]
            a.append(P("gear" if k % 2 == 0 else "box", (0.16, 0.06 if k % 2 == 0 else 0.14, 0.16), (-0.6 + k * 0.3, y + 0.08, -0.78), col, "metal",
                       rot=(90, 0, 0) if k % 2 == 0 else (0, 0, 0), seg=8, top=0.75 if k % 2 == 0 else None))
    for x in (-0.76, 0.76):
        a.append(P("box", (0.05, 1.2, 0.3), (x, 1.15, -0.78), WOOD_D, "wood"))
    lamp_post(a, 0.85, 0.85, 1.6)
    a.append(P("box", (0.4, 0.3, 0.3), (0.0, 0.27, 0.6), "#5a5f68", "metal"))
    a.append(P("box", (0.36, 0.03, 0.26), (0.0, 0.43, 0.6), "#d9822b", "metal"))
    return a


def chest():
    """Ящик: окованный деревянный сундук с замком и ручками."""
    a = []
    a.append(P("box", (1.3, 0.7, 0.9), (0, 0.38, 0), WOOD, "wood"))
    for k in range(4):
        a.append(P("box", (1.32, 0.012, 0.92), (0, 0.12 + k * 0.17, 0), WOOD_D, "wood"))
    a.append(P("box", (1.34, 0.28, 0.94), (0, 0.86, 0), "#9a6a3a", "wood"))
    a.append(P("cylinder", (0.94, 1.34, 0.4), (0, 1.0, 0), "#9a6a3a", "wood", rot=(0, 0, 90), seg=12))
    for x in (-0.55, 0.0, 0.55):
        a.append(P("box", (0.08, 0.74, 0.96), (x, 0.38, 0), "#5a5f68", "metal"))
        a.append(P("box", (0.08, 0.3, 0.96), (x, 0.86, 0), "#5a5f68", "metal"))
    for x in (-0.66, 0.66):
        a.append(P("box", (0.04, 0.72, 0.04), (x, 0.38, 0.46), "#5a5f68", "metal"))
        a.append(P("box", (0.04, 0.72, 0.04), (x, 0.38, -0.46), "#5a5f68", "metal"))
    a.append(P("box", (0.2, 0.24, 0.05), (0, 0.72, 0.48), "#c9a227", "metal"))
    a.append(P("cylinder", (0.04, 0.03, 0.04), (0, 0.68, 0.51), "#1a1a1a", "dark", rot=(90, 0, 0), seg=6))
    for x in (-0.68, 0.68):
        a.append(P("torus", (0.2, 0.2, 0.2), (x, 0.55, 0), "#5a5f68", "metal", rot=(0, 0, 90), seg=10))
    return a


def container():
    """Большой контейнер: гофрированный морской контейнер с дверями, запорными штангами и маркировкой."""
    a = []
    C, CD = "#c0552a", "#8a3a1c"
    a.append(P("box", (1.9, 1.45, 1.5), (0, 0.85, 0), C, "metal"))
    for k in range(13):
        x = -0.9 + k * 0.15
        a.append(P("box", (0.05, 1.3, 1.53), (x, 0.85, 0), CD, "metal"))
    for y in (0.12, 1.58):
        a.append(P("box", (1.94, 0.1, 1.54), (0, y, 0), shade(C, 0.6), "dark"))
    for x in (-0.95, 0.95):
        for z in (-0.73, 0.73):
            for y in (0.12, 1.58):
                a.append(P("box", (0.12, 0.12, 0.12), (x, y, z), DARK, "dark"))
    # двери с торца +X
    a.append(P("box", (0.04, 1.36, 1.44), (0.96, 0.85, 0), CD, "metal"))
    a.append(P("box", (0.05, 1.36, 0.02), (0.97, 0.85, 0), DARK, "dark"))
    for z in (-0.5, -0.2, 0.2, 0.5):
        a.append(P("cylinder", (0.03, 1.4, 0.03), (0.99, 0.85, z), CHR, "metal", seg=6))
        a.append(P("box", (0.06, 0.16, 0.08), (1.0, 0.7, z), DARK, "dark"))
    a.append(P("box", (0.02, 0.18, 0.7), (0.98, 1.3, 0.35), "#f2f2f2"))
    a.append(P("box", (0.02, 0.06, 0.5), (0.99, 1.3, 0.35), "#1d1e21"))
    a.append(P("box", (0.6, 0.2, 0.02), (0, 1.2, 0.77), "#f2f2f2"))
    return a


def generator():
    """Генератор на дровах/угле: топка, котёл, маховик с ремнём, динамо, выхлоп, провода."""
    a = []
    foundation_pad(a)
    a.append(P("box", (0.8, 0.8, 0.9), (-0.45, 0.6, 0), "#4d4d52", "metal"))
    a.append(P("box", (0.05, 0.36, 0.4), (-0.03, 0.5, 0), "#ff6a1a", "glow", anim="flicker"))
    a.append(P("box", (0.04, 0.44, 0.48), (-0.04, 0.5, 0), DARK, "dark"))
    tank_v(a, -0.45, 1.0, 0, 0.35, 0.6, "#8a4a32", band=DARK, gauge=True)
    chimney(a, -0.62, -0.42, 1.4, 1.1, 0.1, col=DARK, brick=False)
    # маховик и ремень
    a.append(P("cylinder", (0.9, 0.12, 0.9), (0.35, 0.75, 0.6), "#2a2d33", "metal", rot=(90, 0, 0), anim="spin_fast", seg=16))
    for k in range(4):
        a.append(P("box", (0.08, 0.04, 0.8), (0.35, 0.75, 0.62), "#5a5f68", "metal", rot=(90, k * 45, 0), anim="spin_fast"))
    a.append(P("cylinder", (0.12, 0.3, 0.12), (0.35, 0.75, 0.45), CHR, "metal", rot=(90, 0, 0), seg=8))
    # динамо
    motor(a, 0.45, 0.65, -0.1, 0.25, 0.7, "#2f6fc4", fins=5, fan=False, axis="z")
    a.append(P("box", (0.5, 0.06, 0.06), (0.4, 1.1, 0.25), "#1d1e21", "cloth", rot=(0, 0, 70)))
    # провода и изоляторы
    for k in range(3):
        a.append(P("cylinder", (0.06, 0.16, 0.06), (0.7, 1.05, -0.3 + k * 0.15), "#e6e3d8", "paint", seg=6))
        a.append(P("sphere", (0.06, 0.06, 0.06), (0.7, 1.15, -0.3 + k * 0.15), "#66d9ff", "glow", anim="pulse"))
    a.append(P("box", (0.32, 0.24, 0.06), (0.4, 0.6, -0.72), "#1b2d3a", "glass"))
    a.append(P("box", (0.26, 0.04, 0.07), (0.4, 0.62, -0.72), "#40ff6a", "glow", anim="pulse"))
    return a


def coal_generator():
    """Угольный генератор: большая топка с бункером угля, два котла, турбина, градирня-труба."""
    a = []
    foundation_pad(a)
    a.append(P("box", (0.9, 1.1, 1.6), (-0.4, 0.73, 0), "#4a4d55", "metal"))
    for z in (-0.55, 0, 0.55):
        a.append(P("box", (0.05, 0.3, 0.3), (0.06, 0.55, z), "#ff6a1a", "glow", anim="flicker"))
        a.append(P("box", (0.04, 0.38, 0.38), (0.05, 0.55, z), DARK, "dark"))
    # бункер угля сверху
    a.append(P("cone", (0.8, 0.6, 0.8), (-0.4, 1.6, 0.3), "#3a3f47", "metal", rot=(180, 0, 0), seg=4))
    a.append(P("box", (0.6, 0.06, 0.6), (-0.4, 1.9, 0.3), "#1e1e22", "stone"))
    for k in range(5):
        a.append(P("sphere", (0.14, 0.1, 0.14), (-0.55 + (k % 3) * 0.15, 1.94, 0.15 + (k // 3) * 0.2), "#1e1e22", "stone", seg=5))
    # котлы
    for z in (-0.5, 0.5):
        a.append(P("cylinder", (0.5, 1.0, 0.5), (0.4, 0.8, z), "#8a4a32", "metal", rot=(0, 0, 90), seg=14))
        a.append(P("torus", (0.52, 0.1, 0.52), (0.2, 0.8, z), DARK, "dark", rot=(0, 0, 90), seg=14))
        a.append(P("torus", (0.52, 0.1, 0.52), (0.65, 0.8, z), DARK, "dark", rot=(0, 0, 90), seg=14))
    # турбина
    a.append(P("cylinder", (0.6, 0.5, 0.6), (0.6, 1.4, 0), "#5a5f68", "metal", rot=(90, 0, 0), seg=16))
    a.append(P("cylinder", (0.5, 0.04, 0.5), (0.6, 1.4, 0.27), DARK, "dark", rot=(90, 0, 0), seg=16))
    for k in range(6):
        a.append(P("box", (0.04, 0.02, 0.22), (0.6, 1.4, 0.3), STEEL, "metal", rot=(90, k * 30, 0), anim="spin_fan"))
    chimney(a, -0.55, -0.45, 1.28, 1.8, 0.15, col="#6b6357")
    pipe_run(a, [(0.4, 1.05, 0.5), (0.4, 1.4, 0.3)], 0.05, CHR)
    pipe_run(a, [(0.4, 1.05, -0.5), (0.4, 1.4, -0.3)], 0.05, CHR)
    beacon(a, 0.85, 1.75, -0.7, "#ff8c1a")
    return a


def solar():
    """Солнечная панель: стойка, наклонная рама 3×4 ячеек, инвертор с индикатором."""
    a = []
    a.append(P("box", (0.6, 0.12, 0.6), (0, 0.06, 0), CONC, "concrete"))
    a.append(P("cylinder", (0.16, 1.0, 0.16), (0, 0.6, 0), STEEL, "metal", seg=8))
    a.append(P("box", (0.3, 0.12, 0.2), (0, 1.1, 0), DARK, "dark"))
    a.append(P("box", (1.9, 0.06, 1.5), (0, 1.25, 0), "#c0c4cc", "metal", rot=(0, 0, 18)))
    for i in range(4):
        for j in range(3):
            x = -0.68 + i * 0.45
            z = -0.47 + j * 0.47
            a.append(P("box", (0.42, 0.03, 0.44), (x * math.cos(math.radians(18)), 1.29 + x * math.sin(math.radians(18)), z), "#1d3a6b", "glass", rot=(0, 0, 18)))
    a.append(P("box", (0.4, 0.4, 0.2), (0.3, 0.5, 0.3), "#e6e3d8", "paint"))
    a.append(P("box", (0.05, 0.05, 0.02), (0.4, 0.6, 0.41), "#40ff6a", "glow", anim="pulse"))
    a.append(P("cylinder", (0.04, 0.5, 0.04), (0.15, 0.35, 0.3), "#1d1e21", "cloth", seg=6, rot=(0, 0, 60)))
    return a


def pole():
    """Опора ЛЭП: столб с подкосом, траверса, изоляторы-«тарелки», заземление."""
    a = []
    a.append(P("cylinder", (0.4, 0.2, 0.4), (0, 0.1, 0), CONC, "concrete", seg=8))
    a.append(P("cylinder", (0.2, 3.6, 0.2), (0, 1.8, 0), "#7a5230", "wood", seg=8, top=0.8))
    for k in range(6):
        a.append(P("torus", (0.22, 0.08, 0.22), (0, 0.6 + k * 0.45, 0), "#5c3d24", "wood", seg=8))
    a.append(P("box", (1.3, 0.12, 0.14), (0, 3.38, 0), "#7a5230", "wood"))
    a.append(P("box", (0.06, 0.6, 0.06), (0.25, 3.1, 0), "#5c3d24", "wood", rot=(0, 0, 40)))
    a.append(P("box", (0.06, 0.6, 0.06), (-0.25, 3.1, 0), "#5c3d24", "wood", rot=(0, 0, -40)))
    for x in (-0.5, 0.5):
        for k in range(3):
            a.append(P("cylinder", (0.16 - k * 0.02, 0.04, 0.16 - k * 0.02), (x, 3.47 + k * 0.05, 0), "#9fd8ff", "glass", seg=10))
        a.append(P("sphere", (0.12, 0.12, 0.12), (x, 3.62, 0), "#66d9ff", "glow", anim="pulse", seg=8))
    a.append(P("cylinder", (0.04, 3.4, 0.04), (0.1, 1.7, 0.1), "#5a5f68", "metal", seg=4))
    a.append(P("box", (0.3, 0.2, 0.02), (0, 1.6, 0.11), YEL, "paint"))
    a.append(P("prism", (0.12, 0.12, 0.02), (0, 1.6, 0.12), "#1d1e21", "paint"))
    return a


def wind_turbine():
    """Ветряк: бетонный фундамент, конусная башня с люком и лестницей, гондола, ступица и три лопасти."""
    a = []
    a.append(P("cylinder", (1.6, 0.3, 1.6), (0, 0.15, 0), CONC, "concrete", seg=12))
    a.append(P("cylinder", (0.5, 6.6, 0.5), (0, 3.6, 0), "#e8ecef", "paint", top=0.6, seg=14))
    for y in (1.5, 3.0, 4.5, 6.0):
        a.append(P("torus", (0.5 - y * 0.02, 0.06, 0.5 - y * 0.02), (0, y, 0), "#c8ced6", "metal", seg=14))
    a.append(P("box", (0.04, 0.6, 0.26), (0.24, 0.65, 0), "#5a5f68", "metal"))
    a.append(P("box", (0.56, 0.5, 1.3), (0, 7.0, -0.1), "#e8ecef", "paint"))
    a.append(P("box", (0.58, 0.06, 1.32), (0, 7.26, -0.1), "#e04b2a", "paint"))
    for k in range(4):
        a.append(P("box", (0.02, 0.3, 0.04), (0.29, 7.0, -0.6 + k * 0.12), "#8c949e", "metal"))
    a.append(P("cone", (0.4, 0.5, 0.4), (0, 7.0, 0.8), "#c8ced6", "metal", rot=(90, 0, 0), seg=12))
    # три лопасти вокруг оси Z (вращение по локальной оси Y детали, повёрнутой на 90° по X)
    for k in range(3):
        # лопасть — от ступицы наружу по локальной оси X; длинная, с красным кончиком
        a.append(P("box", (2.6, 0.06, 0.3), (0, 7.0, 0.68), "#f4f6f8", "paint", rot=spun((90, 0, 0), k * 120), anim="spin_wind"))
        a.append(P("box", (0.5, 0.07, 0.16), (0, 7.0, 0.68), "#e04b2a", "paint", rot=spun((90, 0, 0), k * 120), anim="spin_wind"))
    a.append(P("sphere", (0.12, 0.12, 0.12), (0, 7.34, -0.55), "#ff3a2a", "glow", anim="blink"))
    a.append(P("box", (0.04, 0.3, 0.04), (0, 7.4, -0.65), DARK, "dark"))
    return a


def battery():
    """Аккумулятор: стойка из четырёх банок, шкала заряда, радиатор, клеммы."""
    a = []
    foundation_pad(a, w=1.6, d=1.6, h=0.14)
    for x in (-0.35, 0.35):
        for z in (-0.35, 0.35):
            a.append(P("box", (0.6, 1.2, 0.6), (x, 0.76, z), "#2f3a4a", "metal"))
            a.append(P("box", (0.62, 0.08, 0.62), (x, 1.4, z), "#40c8ff", "glow", anim="pulse"))
            a.append(P("cylinder", (0.1, 0.12, 0.1), (x + 0.15, 1.5, z), "#c03020", seg=8))
            a.append(P("cylinder", (0.1, 0.12, 0.1), (x - 0.15, 1.5, z), "#1d1e21", seg=8))
    for k in range(5):
        a.append(P("box", (0.08, 0.12, 0.02), (-0.24 + k * 0.12, 0.6 + k * 0.12, 0.66), "#40ff6a" if k < 4 else "#3a3f47", "glow" if k < 4 else "dark", anim="pulse"))
    for k in range(6):
        a.append(P("box", (0.02, 1.0, 0.5), (-0.67, 0.74, -0.25 + k * 0.1), STEEL, "metal"))
    a.append(P("box", (1.3, 0.04, 0.04), (0, 1.58, 0), "#1d1e21", "cloth"))
    return a


def turret(laser=False):
    """Турель: бронированное основание, поворотная башня (роль head) со стволами, прицел, ящик боеприпасов."""
    a = []
    BODY = "#d94020" if not laser else "#e6e3d8"
    ACC = "#ffcc4d" if not laser else "#ff3a5a"
    a.append(P("cylinder", (1.8, 0.3, 1.8), (0, 0.15, 0), "#383b40", "dark", seg=8))
    for i in range(8):
        ang = 2 * math.pi * i / 8 + math.pi / 8
        a.append(P("wedge", (0.4, 0.25, 0.35), (math.cos(ang) * 0.75, 0.42, math.sin(ang) * 0.75), "#4a4d55", "metal", rot=(0, -math.degrees(ang) + 180, 0)))
    a.append(P("cylinder", (1.0, 0.6, 1.0), (0, 0.6, 0), STEEL, "metal", top=0.8, seg=12))
    a.append(P("torus", (1.0, 0.12, 1.0), (0, 0.92, 0), DARK, "dark", seg=16))
    # башня
    a.append(P("cylinder", (0.95, 0.2, 0.95), (0, 1.05, 0), "#2a2d33", "dark", role="head", seg=12))
    a.append(P("box", (1.0, 0.55, 0.9), (0, 1.4, 0), BODY, role="head"))
    a.append(P("wedge", (0.4, 0.55, 0.9), (0.68, 1.4, 0), BODY, rot=(0, 180, 0), role="head"))
    a.append(P("box", (0.6, 0.1, 0.92), (-0.1, 1.72, 0), shade(BODY, 0.75), role="head"))
    if not laser:
        for z in (0.2, -0.2):
            a.append(P("cylinder", (0.14, 1.1, 0.14), (1.0, 1.42, z), "#4d4d52", "metal", rot=(0, 0, 90), role="head", seg=8))
            a.append(P("cylinder", (0.2, 0.18, 0.2), (1.5, 1.42, z), DARK, "dark", rot=(0, 0, 90), role="head", seg=8))
            for k in range(3):
                a.append(P("torus", (0.18, 0.15, 0.18), (0.7 + k * 0.2, 1.42, z), DARK, "dark", rot=(0, 0, 90), role="head", seg=8))
        a.append(P("box", (0.35, 0.3, 0.3), (-0.3, 1.25, 0.55), "#5a6a3a", "metal", role="head"))
        a.append(P("box", (0.2, 0.06, 0.32), (-0.3, 1.42, 0.55), "#c9a227", "metal", role="head"))
    else:
        a.append(P("cylinder", (0.22, 1.2, 0.22), (1.0, 1.42, 0), "#c8ced6", "metal", rot=(0, 0, 90), role="head", seg=12))
        for k in range(4):
            a.append(P("torus", (0.34, 0.2, 0.34), (0.6 + k * 0.22, 1.42, 0), ACC, "glow", rot=(0, 0, 90), role="head", anim="pulse", seg=12))
        a.append(P("sphere", (0.18, 0.18, 0.18), (1.62, 1.42, 0), ACC, "glow", role="head", anim="pulse", seg=10))
        coil(a, -0.3, 1.6, 0.0, 0.12, 0.4, col="#c87533")
        for p in a[-8:]:
            p["role"] = "head"
    a.append(P("box", (0.08, 0.12, 0.6), (0.53, 1.58, 0), ACC, "glow", role="head"))
    a.append(P("box", (0.16, 0.14, 0.14), (0.2, 1.78, -0.3), DARK, "dark", role="head"))
    a.append(P("cylinder", (0.08, 0.04, 0.08), (0.29, 1.78, -0.3), "#ff3a2a", "glow", rot=(0, 0, 90), role="head", seg=8, anim="blink"))
    return a


def wall_wood():
    """Деревянная стена-частокол: брёвна с заострёнными концами, две перекладины, скобы."""
    a = []
    for k in range(7):
        z = -0.84 + k * 0.28
        h = 1.9 + (k % 3) * 0.12
        a.append(P("cylinder", (0.28, h, 0.28), (0, h / 2, z), WOOD if k % 2 else "#7a4f2c", "wood", seg=7))
        a.append(P("cone", (0.28, 0.3, 0.28), (0, h + 0.15, z), "#a87850", "wood", seg=7))
    for y in (0.6, 1.5):
        a.append(P("box", (0.16, 0.14, 1.98), (0.18, y, 0), WOOD_D, "wood"))
        for k in range(4):
            a.append(P("cylinder", (0.04, 0.06, 0.04), (0.27, y, -0.7 + k * 0.47), "#5a5f68", "metal", rot=(0, 0, 90), seg=6))
    a.append(P("box", (0.2, 1.4, 0.12), (0.18, 1.05, 0), WOOD_D, "wood", rot=(35, 0, 0)))
    return a


def wall():
    """Бетонная стена: блоки с швами, стальной кант, колючая проволока сверху."""
    a = []
    a.append(P("box", (0.7, 0.2, 2.0), (0, 0.1, 0), shade(CONC, 0.85), "concrete"))
    for row in range(4):
        for k in range(3 if row % 2 == 0 else 4):
            off = 0 if row % 2 == 0 else -0.33
            w = 0.64 if row % 2 == 0 else (0.31 if k in (0, 3) else 0.64)
            z = -0.66 + k * 0.66 + off if row % 2 == 0 else [-0.84, -0.33, 0.33, 0.84][k]
            a.append(P("box", (0.56, 0.48, w), (0, 0.45 + row * 0.5, z), CONC if (row + k) % 2 else shade(CONC, 0.92), "concrete"))
    a.append(P("box", (0.62, 0.08, 2.0), (0, 2.2, 0), "#5a5f68", "metal"))
    for k in range(5):
        a.append(P("box", (0.04, 0.4, 0.04), (0, 2.42, -0.8 + k * 0.4), DARK, "dark"))
    for y in (2.45, 2.6):
        a.append(P("box", (0.02, 0.02, 2.0), (0, y, 0), "#9aa3ad", "metal"))
    for k in range(10):
        a.append(P("torus", (0.12, 0.2, 0.12), (0, 2.52, -0.9 + k * 0.2), "#9aa3ad", "metal", rot=(0, 0, 90), seg=6))
    a.append(P("box", (0.02, 0.18, 0.5), (0.29, 1.4, 0), YEL))
    for k in range(3):
        a.append(P("box", (0.025, 0.18, 0.06), (0.3, 1.4, -0.15 + k * 0.15), DARK, "dark", rot=(45, 0, 0)))
    return a


def gate():
    """Ворота: бетонные столбы, стальные створки с решёткой, мигалки, привод."""
    a = []
    for z in (-0.85, 0.85):
        a.append(P("box", (0.5, 2.4, 0.3), (0, 1.2, z), CONC, "concrete"))
        a.append(P("box", (0.56, 0.12, 0.36), (0, 2.45, z), "#5a5f68", "metal"))
        beacon(a, 0, 2.52, z, "#ffb040")
    a.append(P("box", (0.12, 1.9, 1.4), (0, 1.05, 0), "#5a6a3a", "metal"))
    for k in range(7):
        a.append(P("box", (0.14, 1.85, 0.05), (0, 1.05, -0.6 + k * 0.2), "#3e4a28", "metal"))
    for y in (0.4, 1.05, 1.7):
        a.append(P("box", (0.15, 0.08, 1.4), (0, y, 0), "#3e4a28", "metal"))
    a.append(P("box", (0.13, 1.6, 0.06), (0, 1.05, 0), "#3e4a28", "metal", rot=(42, 0, 0)))
    a.append(P("box", (0.3, 0.3, 0.3), (0.3, 2.2, 0.85), "#3a3f47", "metal"))
    a.append(P("cylinder", (0.06, 1.6, 0.06), (0.1, 2.3, 0), CHR, "metal", rot=(90, 0, 0), seg=6))
    for k in range(6):
        a.append(P("box", (0.02, 0.12, 0.2), (0.07, 0.25, -0.5 + k * 0.2), YEL if k % 2 else DARK, "paint"))
    return a


def lamp():
    """Фонарь: столб, кронштейн, плафон со светом, мотыльки кружат."""
    a = []
    a.append(P("cylinder", (0.4, 0.15, 0.4), (0, 0.075, 0), CONC, "concrete", seg=8))
    a.append(P("cylinder", (0.12, 2.6, 0.12), (0, 1.4, 0), "#2a2d33", "metal", seg=8, top=0.7))
    for y in (0.4, 1.2):
        a.append(P("torus", (0.18, 0.15, 0.18), (0, y, 0), "#2a2d33", "metal", seg=8))
    a.append(P("box", (0.6, 0.06, 0.06), (0.25, 2.65, 0), "#2a2d33", "metal"))
    a.append(P("box", (0.04, 0.3, 0.04), (0.1, 2.5, 0), "#2a2d33", "metal", rot=(0, 0, 45)))
    a.append(P("cone", (0.4, 0.2, 0.4), (0.5, 2.6, 0), "#2a2d33", "metal", seg=10))
    a.append(P("sphere", (0.26, 0.2, 0.26), (0.5, 2.45, 0), "#fff1c4", "glow", anim="flicker_soft", seg=10))
    for k in range(3):
        a.append(P("sphere", (0.03, 0.02, 0.03), (0.5 + math.cos(k * 2.1) * 0.3, 2.35 + k * 0.05, math.sin(k * 2.1) * 0.3), "#e6dcc8", "paint", anim="jitter"))
    return a


def fence():
    """Забор: столбики, три жерди, сетка рабица."""
    a = []
    for z in (-0.9, 0.0, 0.9):
        a.append(P("box", (0.12, 1.2, 0.12), (0, 0.6, z), WOOD_D, "wood"))
        a.append(P("prism", (0.12, 0.12, 0.12), (0, 1.26, z), WOOD_D, "wood"))
    for y in (0.3, 0.7, 1.05):
        a.append(P("box", (0.06, 0.08, 1.9), (0.08, y, 0), WOOD, "wood"))
    for k in range(9):
        a.append(P("box", (0.01, 0.95, 0.01), (0.04, 0.65, -0.8 + k * 0.2), "#9aa3ad", "metal", rot=(45, 0, 0)))
        a.append(P("box", (0.01, 0.95, 0.01), (0.04, 0.65, -0.8 + k * 0.2), "#9aa3ad", "metal", rot=(-45, 0, 0)))
    return a


def flag():
    """Флаг: мачта с растяжками, полотнище с эмблемой, бетонная тумба."""
    a = []
    a.append(P("box", (0.5, 0.2, 0.5), (0, 0.1, 0), CONC, "concrete"))
    a.append(P("cylinder", (0.08, 3.4, 0.08), (0, 1.8, 0), "#d9d9d9", "metal", seg=8))
    a.append(P("sphere", (0.14, 0.14, 0.14), (0, 3.55, 0), "#c9a227", "metal", seg=8))
    a.append(P("box", (1.2, 0.7, 0.02), (0.62, 3.0, 0), "#d94020", "cloth", anim="wave"))
    a.append(P("box", (0.4, 0.36, 0.025), (0.45, 3.0, 0), "#ffffff", "cloth", anim="wave"))
    a.append(P("box", (0.16, 0.16, 0.03), (0.45, 3.0, 0), "#f2a81f", "cloth", anim="wave"))
    for z in (-0.6, 0.6):
        a.append(P("box", (0.01, 3.0, 0.01), (0, 1.75, z * 0.5), "#9aa3ad", "metal", rot=(math.degrees(math.atan2(z, 3.0)) * -1, 0, 0)))
    return a


def hq():
    """Штаб: бетонная платформа, корпус с панелями и окнами, купол-сфера связи, антенна, посадочная площадка, ящики."""
    a = []
    BL, GL = "#3a5f8a", "#40e0ff"
    a.append(P("box", (5.8, 0.3, 5.8), (0, 0.15, 0), CONC, "concrete"))
    a.append(P("box", (5.9, 0.06, 5.9), (0, 0.3, 0), shade(CONC, 0.8), "concrete"))
    for x in (-2.7, 2.7):
        for z in (-2.7, 2.7):
            a.append(P("cylinder", (0.6, 2.4, 0.6), (x, 1.5, z), "#5a6c86", "metal", seg=12))
            a.append(P("cylinder", (0.7, 0.12, 0.7), (x, 2.75, z), DARK, "dark", seg=12))
            a.append(P("sphere", (0.2, 0.2, 0.2), (x, 2.9, z), "#ffb040", "glow", anim="blink", seg=8))
    a.append(P("box", (4.2, 2.2, 4.2), (0, 1.4, 0), "#c8d2de", "metal"))
    for y in (0.6, 1.4, 2.2):
        a.append(P("box", (4.26, 0.08, 4.26), (0, y, 0), "#8a96a8", "metal"))
    for s in (-1, 1):
        a.append(P("box", (0.06, 0.5, 3.0), (s * 2.11, 1.6, 0), GL, "glow", anim="pulse"))
        a.append(P("box", (3.0, 0.5, 0.06), (0, 1.6, s * 2.11), GL, "glow", anim="pulse"))
        for k in range(4):
            a.append(P("box", (0.07, 0.6, 0.06), (s * 2.12, 1.6, -1.2 + k * 0.8), DARK, "dark"))
    a.append(P("box", (4.4, 0.2, 4.4), (0, 2.6, 0), BL, "metal"))
    a.append(P("box", (0.5, 0.3, 4.3), (0, 1.0, 0), "#c08830", "metal"))
    # двери
    a.append(P("box", (0.08, 1.2, 1.0), (2.12, 0.9, 0), DARK, "dark"))
    a.append(P("box", (0.09, 1.1, 0.04), (2.13, 0.9, 0), "#40e0ff", "glow"))
    a.append(P("wedge", (0.8, 0.3, 1.2), (2.5, 0.45, 0), shade(CONC, 0.9), "concrete"))
    # верхний блок с куполом
    a.append(P("box", (2.2, 1.2, 2.2), (0, 3.3, 0), "#2a3a55", "metal"))
    a.append(P("sphere", (2.0, 2.0, 2.0), (0, 4.0, 0), "#7fe8ff", "glass", seg=20))
    a.append(P("torus", (2.1, 0.12, 2.1), (0, 3.95, 0), DARK, "dark", seg=24))
    energy_ring(a, 0, 4.3, 0, 0.7, "#40e0ff", anim="spin_slow", thick=0.15)
    a.append(P("cylinder", (0.06, 2.6, 0.06), (0.2, 5.6, 0), "#d9d9d9", "metal", seg=6))
    a.append(P("sphere", (0.18, 0.18, 0.18), (0.2, 6.95, 0), "#ff3a2a", "glow", anim="blink"))
    for k in range(3):
        a.append(P("box", (0.6 - k * 0.15, 0.03, 0.03), (0.2, 6.2 + k * 0.25, 0), "#d9d9d9", "metal"))
    # тарелка связи
    a.append(P("cylinder", (0.12, 0.6, 0.12), (-1.6, 2.95, -1.6), DARK, "dark", seg=8))
    a.append(P("sphere", (1.0, 0.35, 1.0), (-1.6, 3.35, -1.6), "#e6e3d8", "metal", rot=(35, 45, 0), seg=14))
    a.append(P("cylinder", (0.04, 0.5, 0.04), (-1.45, 3.6, -1.45), DARK, "dark", rot=(35, 45, 0), seg=6))
    # ящики и бочки у входа
    for k in range(3):
        a.append(P("box", (0.5, 0.5, 0.5), (1.7 + (k % 2) * 0.55, 0.55 + (k // 2) * 0.5, 2.4), "#8a5a32", "wood"))
    barrel(a, 2.55, -2.2, "#2f6fc4", y=0.3, h=0.6)
    barrel(a, 2.2, -2.5, "#c03020", y=0.3, h=0.6)
    lamp_post(a, 2.6, 1.3, 2.0)
    return a


def splitter(kind="split", smart=False):
    """Разделитель/соединитель: корпус с поворотной заслонкой, стрелки направлений, лампы."""
    a = []
    COL = "#d68a1a" if kind == "split" else "#2f8fd6"
    GL = "#ffd040" if kind == "split" else "#40c8ff"
    a.append(P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"))
    for x in (-0.85, 0.85):
        for z in (-0.85, 0.85):
            a.append(P("box", (0.12, 0.34, 0.12), (x, 0.17, z), DARK, "dark"))
    a.append(P("box", (1.2, 0.65, 1.2), (0, 0.62, 0), COL))
    a.append(P("box", (1.24, 0.06, 1.24), (0, 0.96, 0), DARK, "dark"))
    for d in range(4):
        ang = d * 90
        x, z = math.cos(math.radians(ang)) * 0.61, math.sin(math.radians(ang)) * 0.61
        a.append(P("box", (0.04 if d % 2 == 0 else 0.5, 0.36, 0.5 if d % 2 == 0 else 0.04), (x, 0.55, z), "#1a1c20", "dark"))
    a.append(P("cylinder", (0.5, 0.12, 0.5), (0, 1.04, 0), "#2a2d33", "dark", seg=12))
    a.append(P("box", (0.5, 0.06, 0.08), (0, 1.12, 0), CHR, "metal", anim="spin"))
    if kind == "split":
        dirs = [(-90, -90, 0.45, 0), (-90, 0, 0, 0.45), (90, 0, 0, -0.45)]
    else:
        dirs = [(-90, -90, 0.45, 0), (-90, 180, -0.1, 0.4), (90, 180, -0.1, -0.4)]
    for (rx, rz, x, z) in dirs:
        a.append(P("prism", (0.4, 0.3, 0.16), (x, 1.2, z), GL, "glow", rot=(rx, 0, rz)))
    if smart:
        a.append(P("box", (0.5, 0.3, 0.04), (0, 0.72, 0.62), "#7dff5a", "glow", anim="flicker_soft"))
        a.append(P("sphere", (0.14, 0.14, 0.14), (0, 1.32, 0), "#7dff5a", "glow", anim="blink"))
        for k in range(3):
            a.append(P("box", (0.08, 0.06, 0.04), (-0.15 + k * 0.15, 0.5, 0.62), ("#ff3b2f", "#ffd040", "#40ff6a")[k], "glow", anim="pulse"))
    beacon(a, -0.7, 0.3, -0.7, GL)
    return a


def tech_terminal():
    """Терминал открытий: пьедестал, наклонный экран с голограммой дерева, антенны, приёмный лоток."""
    a = []
    a.append(P("cylinder", (1.6, 0.2, 1.6), (0, 0.1, 0), "#3a3f47", "dark", seg=8))
    a.append(P("cylinder", (1.3, 0.06, 1.3), (0, 0.23, 0), "#40c8ff", "glow", anim="pulse", seg=8))
    a.append(P("box", (0.7, 1.1, 0.6), (-0.2, 0.75, 0), "#e6e3d8", "metal"))
    a.append(P("box", (0.72, 0.1, 0.62), (-0.2, 1.33, 0), "#2f6fc4"))
    a.append(P("box", (0.08, 0.8, 1.1), (0.15, 1.65, 0), DARK, "dark", rot=(0, 0, -20)))
    a.append(P("box", (0.03, 0.7, 1.0), (0.2, 1.67, 0), "#40c8ff", "glow", anim="flicker_soft", rot=(0, 0, -20)))
    # голограмма дерева открытий
    for k in range(3):
        a.append(P("sphere", (0.12, 0.12, 0.12), (-0.2, 2.3 + k * 0.3, -0.25 + (k % 2) * 0.5), "#7dff5a", "glow", anim="hover"))
        a.append(P("box", (0.02, 0.3, 0.02), (-0.2, 2.15 + k * 0.3, -0.12 + (k % 2) * 0.25), "#7dff5a", "glow", anim="hover", rot=(45 if k % 2 else -45, 0, 0)))
    a.append(P("cylinder", (0.4, 0.04, 0.4), (-0.2, 1.4, 0), "#7dff5a", "glow", anim="pulse", seg=12))
    for z in (-0.5, 0.5):
        a.append(P("cylinder", (0.04, 1.2, 0.04), (-0.55, 1.9, z), CHR, "metal", seg=6))
        a.append(P("sphere", (0.08, 0.08, 0.08), (-0.55, 2.52, z), "#ffb040", "glow", anim="blink"))
    a.append(P("box", (0.4, 0.15, 0.6), (0.6, 0.4, 0), "#5a5f68", "metal"))
    a.append(P("box", (0.36, 0.03, 0.56), (0.6, 0.48, 0), "#1a1c20", "dark"))
    return a


BUILD = {
    "furnace": ("Каменная печь", furnace, "Производство", [{"kind": "puff", "pos": [-0.45, 2.7, -0.45], "when": "active", "rate": 0.35, "size": 0.9}]),
    "smelter": ("Плавильня", lambda: smelter(1), "Производство", [{"kind": "puff", "pos": [-0.55, 3.25, -0.5], "when": "active", "rate": 0.3, "size": 1.0}]),
    "smelter_mk2": ("Плавильня Mk2", lambda: smelter(2), "Производство", [{"kind": "puff", "pos": [-0.55, 3.25, -0.5], "when": "active", "rate": 0.5, "size": 1.0}]),
    "assembler": ("Сборщик", lambda: assembler(1), "Производство", [{"kind": "spark", "pos": [0.0, 0.9, 0.0], "when": "active", "rate": 1.5, "size": 0.5}]),
    "assembler_mk2": ("Сборщик Mk2", lambda: assembler(2), "Производство", [{"kind": "spark", "pos": [0.0, 0.9, 0.0], "when": "active", "rate": 2.5, "size": 0.5}]),
    "workbench": ("Верстак", workbench, "Станции", None),
    "workshop": ("Мастерская", workshop, "Станции", None),
    "chest": ("Ящик", chest, "Хранение", None),
    "container": ("Контейнер", container, "Хранение", None),
    "generator": ("Генератор", generator, "Энергетика", [{"kind": "puff", "pos": [-0.62, 2.6, -0.42], "when": "active", "rate": 0.25, "size": 1.1}]),
    "coal_generator": ("Угольный генератор", coal_generator, "Энергетика", [{"kind": "puff", "pos": [-0.55, 3.2, -0.45], "when": "active", "rate": 0.4, "size": 1.3}]),
    "solar": ("Солнечная панель", solar, "Энергетика", None),
    "pole": ("Опора ЛЭП", pole, "Энергетика", None),
    "wind_turbine": ("Ветряк", wind_turbine, "Энергетика", None),
    "battery": ("Аккумулятор", battery, "Энергетика", None),
    "turret": ("Турель", turret, "Оборона", None),
    "laser_turret": ("Лазерная турель", lambda: turret(True), "Оборона", None),
    "wall_wood": ("Деревянная стена", wall_wood, "Оборона", None),
    "wall": ("Бетонная стена", wall, "Оборона", None),
    "gate": ("Ворота", gate, "Оборона", None),
    "lamp": ("Фонарь", lamp, "Декор", None),
    "fence": ("Забор", fence, "Декор", None),
    "flag": ("Флаг", flag, "Декор", None),
    "hq": ("Штаб", hq, "Здания", None),
    "splitter": ("Разделитель", lambda: splitter("split"), "Логистика", None),
    "merger": ("Соединитель", lambda: splitter("merge"), "Логистика", None),
    "smart_splitter": ("Умный разделитель", lambda: splitter("split", True), "Логистика", None),
    "smart_merger": ("Умный соединитель", lambda: splitter("merge", True), "Логистика", None),
    "tech_terminal": ("Терминал открытий", tech_terminal, "Станции", None),
}


def all_models(old):
    out = {}
    for k, (name, fn, cat, emit) in BUILD.items():
        m = M(name, fn(), cat)
        if emit:
            m["emitters"] = emit
        elif old.get(k, {}).get("emitters"):
            m["emitters"] = old[k]["emitters"]
        out[k] = m
    return out
