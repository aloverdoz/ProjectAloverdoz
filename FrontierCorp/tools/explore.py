# 14.7 Исследование и туман войны: радарная вышка и дрон-разведчик. Карта открывается по мере прохода.
# Всё правится в редакторе: «Настройки» (радиусы, модуль «Туман войны»), «Здания» (Радар: радиус), «Предметы» (разведчик).
import math
from art_kit import P, M

STEEL, DARK, YEL, CONC = "#8c949e", "#292b30", "#f2a81f", "#9e9c91"


def radar_model():
    p = [P("box", (2.0, 0.3, 2.0), (0, 0.15, 0), CONC, "concrete")]
    # решётчатая вышка: четыре стойки и раскосы по ярусам
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.append(P("box", (0.12, 4.2, 0.12), (sx * 0.6, 2.4, sz * 0.6), STEEL, "metal", rot=(sz * 4, 0, -sx * 4)))
            p.append(P("box", (0.3, 0.12, 0.3), (sx * 0.72, 0.36, sz * 0.72), DARK, "dark"))
    for lv in range(6):
        y = 0.7 + lv * 0.7
        w = 1.25 - lv * 0.06
        for side in range(4):
            a = side * math.pi / 2
            x, z = math.cos(a) * w * 0.5, math.sin(a) * w * 0.5
            p.append(P("box", (0.06, 0.06, w), (x, y, z), STEEL, "metal", rot=(0, math.degrees(a), 0)))
            p.append(P("box", (0.05, 0.05, w * 1.15), (x, y + 0.35, z), "#6c737c", "metal", rot=(32 if side % 2 else -32, math.degrees(a), 0)))
    # площадка, кабина и вращающаяся антенна
    p.append(P("box", (1.5, 0.12, 1.5), (0, 4.6, 0), DARK, "dark"))
    p.append(P("box", (0.9, 0.6, 0.9), (0, 4.95, 0), "#d8dde3", "paint"))
    p.append(P("box", (0.92, 0.18, 0.5), (0, 5.05, 0.21), "#3a6d8c", "glass"))
    p.append(P("cylinder", (0.18, 0.5, 0.18), (0, 5.5, 0), STEEL, "metal", anim="spin"))
    p.append(P("box", (2.4, 0.9, 0.08), (0, 6.0, 0.25), "#e8ecef", "paint", anim="spin", rot=(-15, 0, 0)))
    p.append(P("box", (2.5, 0.08, 0.14), (0, 6.45, 0.18), YEL, "paint", anim="spin"))
    p.append(P("cylinder", (0.12, 0.6, 0.12), (0, 6.0, -0.2), DARK, "dark", anim="spin", rot=(90, 0, 0)))
    p.append(P("sphere", (0.16, 0.16, 0.16), (0, 6.75, 0), "#ff3a30", "glow"))
    # перила
    for side in range(4):
        a = side * math.pi / 2
        p.append(P("box", (0.04, 0.04, 1.5), (math.cos(a) * 0.73, 4.95, math.sin(a) * 0.73), YEL, "paint", rot=(0, math.degrees(a), 0)))
    return M("Радарная вышка", p, "Защита")


def apply(models, buildings, items, recipes, settings, tech):
    models["radar_tower"] = radar_model()
    buildings["radar_tower"] = {
        "name": "Радарная вышка", "desc": "Открывает карту вокруг (туман войны) и показывает гнёзда и монстров в округе. Нужна энергия.",
        "category": "defense", "behavior": "decor", "cost": {"steel": 10, "circuit": 6, "wire": 8}, "model": "radar_tower", "hp": 900, "size": 2,
        "params": {"power": 15, "radar_radius": 70.0}}
    items["scout_drone"] = {
        "name": "Дрон-разведчик", "desc": "Использовать (ПКМ): дрон летит туда, куда смотрит камера, и открывает полосу карты (туман войны).",
        "color": "#7fd0ff", "category": "Инструменты", "stack": 10, "price": 30, "model": "drop_motor",
        "on_use": [{"do": "scout", "dist": "320"}]}
    recipes["scout_drone"] = {"name": "Дрон-разведчик", "in": {"iron_plate": 4, "circuit": 2, "motor": 1}, "out": {"scout_drone": 1},
                              "time": 4.0, "stations": ["workbench"]}
    settings["modules"]["fog"] = True
    settings["fog_reveal_radius"] = 45.0
    settings["fog_start_radius"] = 70.0
    settings["scout_dist"] = 320.0
    settings["scout_radius"] = 40.0
    settings["scout_speed"] = 30.0
    # вышка открывается вместе с электричеством
    for tid, t in tech.items():
        if "generator" in t.get("unlocks", {}).get("buildings", []):
            t["unlocks"]["buildings"].append("radar_tower")
            break
