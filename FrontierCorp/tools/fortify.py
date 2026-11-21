# 14.7 Ловушки и укрепления: шипы, катушка Теслы (турель на проводах с цепью молний), стальная стена.
# Монстры у базы обходят стены по лабиринту (scripts/maze.gd). Всё правится: «Здания» (Ловушка: урон, Цепь молний), «Настройки» (радиус лабиринта).
import math
from art_kit import P, M

STEEL, DARK, CONC, YEL = "#8c949e", "#292b30", "#9e9c91", "#f2a81f"


def spikes_model():
    p = [P("box", (1.96, 0.12, 1.96), (0, 0.06, 0), "#5a5048", "dark")]
    for x in range(5):
        for z in range(5):
            px, pz = -0.78 + x * 0.39, -0.78 + z * 0.39
            p.append(P("cylinder", (0.16, 0.06, 0.16), (px, 0.15, pz), DARK, "dark", seg=6))
            p.append(P("cone", (0.12, 0.42, 0.12), (px, 0.38, pz), "#c9ced4", "metal", seg=6))
            p.append(P("cone", (0.05, 0.1, 0.05), (px, 0.62, pz), "#8a2a20", "paint", seg=5))
    for s in (-1, 1):
        p.append(P("box", (1.96, 0.08, 0.1), (0, 0.13, s * 0.95), YEL, "paint"))
        p.append(P("box", (0.1, 0.08, 1.96), (s * 0.95, 0.13, 0), YEL, "paint"))
    return M("Шипы", p, "Защита")


def tesla_model():
    p = [P("cylinder", (1.6, 0.3, 1.6), (0, 0.15, 0), CONC, "concrete", seg=10),
         P("cylinder", (1.1, 0.5, 1.1), (0, 0.55, 0), DARK, "dark", seg=10),
         P("cylinder", (0.5, 2.4, 0.5), (0, 2.0, 0), "#b87333", "metal", seg=12)]
    for i in range(9):
        p.append(P("torus", (0.75 - i * 0.02, 0.08, 0.75 - i * 0.02), (0, 1.0 + i * 0.27, 0), "#d08a40", "metal"))
    p.append(P("torus", (1.5, 0.3, 1.5), (0, 3.35, 0), "#c9ced4", "metal"))
    p.append(P("sphere", (0.7, 0.7, 0.7), (0, 3.5, 0), "#9fdcff", "glow"))
    for k in range(4):
        a = k * math.pi / 2
        p.append(P("box", (0.12, 1.2, 0.12), (math.cos(a) * 0.62, 0.9, math.sin(a) * 0.62), STEEL, "metal", rot=(0, 0, 0)))
        p.append(P("sphere", (0.18, 0.18, 0.18), (math.cos(a) * 0.62, 1.55, math.sin(a) * 0.62), "#7fd0ff", "glow"))
    return M("Катушка Теслы", p, "Защита")


def steel_wall_model():
    p = [P("box", (2.0, 2.6, 0.9), (0, 1.3, 0), "#6c737c", "metal"),
         P("box", (2.04, 0.2, 0.96), (0, 0.1, 0), DARK, "dark"),
         P("box", (2.04, 0.16, 0.96), (0, 2.62, 0), DARK, "dark")]
    for x in (-0.66, 0, 0.66):
        p.append(P("box", (0.08, 2.3, 0.94), (x, 1.3, 0), "#555b63", "metal"))
        for y in (0.45, 1.3, 2.15):
            for s in (-1, 1):
                p.append(P("cylinder", (0.07, 0.03, 0.07), (x + 0.2, y, s * 0.46), "#a8aeb6", "metal", rot=(90, 0, 0), seg=6))
    for s in (-1, 1):
        p.append(P("box", (2.0, 0.12, 0.04), (0, 1.9, s * 0.46), YEL, "paint"))
    return M("Стальная стена", p, "Защита")


def apply(models, buildings, settings):
    models["spike_trap"] = spikes_model()
    models["tesla_coil"] = tesla_model()
    models["steel_wall"] = steel_wall_model()
    buildings["spike_trap"] = {
        "name": "Шипы", "desc": "Ловушка: монстры, которые идут по шипам, получают урон. Шипы изнашиваются. Ставьте в проходах лабиринта.",
        "category": "defense", "behavior": "floor", "cost": {"iron_plate": 4, "stone": 4}, "model": "spike_trap", "hp": 300, "size": 1,
        "params": {"trap_dps": 30.0, "trap_wear": 1.5}}
    buildings["tesla_coil"] = {
        "name": "Катушка Теслы", "desc": "Турель на проводах: без патронов, нужна энергия. Молния перескакивает на 4 соседних монстров.",
        "category": "defense", "behavior": "turret", "cost": {"steel": 8, "wire": 16, "circuit": 4}, "model": "tesla_coil", "hp": 1100, "size": 1,
        "params": {"range": 20, "damage": 28, "rate": 1.1, "ammo": "", "power": 25, "chain": 4, "chain_range": 7.0}}
    buildings["steel_wall"] = {
        "name": "Стальная стена", "desc": "Крепче бетонной. Из стен можно строить лабиринт: монстры обходят стены и ломают их, только если пути нет.",
        "category": "defense", "behavior": "wall", "cost": {"steel": 3, "concrete": 2}, "model": "steel_wall", "hp": 4500, "size": 1}
    settings["maze_radius"] = 70
