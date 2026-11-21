# 14.7 Подземелья: руины со стенами, ловушками для героя, стражей и сундуком; редкие чертежи открывают редкие здания.
# Всё правится: «Настройки → Подземелья», «Предметы» (чертежи), «Здания» (редкие: «Только по чертежу»).
import json, math
from art_kit import P, M

STONE, MOSS, DARK, GOLD = "#7d776c", "#5d6b45", "#2a2724", "#d9a82a"


def ruin_wall_model():
    p = [P("box", (2.0, 2.2, 1.6), (0, 1.1, 0), STONE, "stone")]
    for i, (x, y) in enumerate([(-0.6, 0.4), (0.5, 0.9), (-0.2, 1.6), (0.65, 1.95), (-0.7, 2.25)]):
        p.append(P("box", (0.62, 0.36, 1.64), (x, y, 0), "#6c675e" if i % 2 else "#8a8478", "stone"))
    p.append(P("box", (0.8, 0.12, 1.66), (0.3, 2.24, 0), MOSS, "leaf"))
    p.append(P("box", (0.5, 0.5, 0.5), (0.9, 0.25, 0.9), "#6c675e", "stone", rot=(0, 30, 12)))
    return M("Стена руин", p, "Подземелья")


def arch_model():
    p = []
    for s in (-1, 1):
        p.append(P("box", (0.5, 3.2, 1.6), (s * 0.78, 1.6, 0), STONE, "stone"))
        p.append(P("box", (0.6, 0.3, 1.7), (s * 0.78, 0.15, 0), "#5e594f", "stone"))
    p.append(P("box", (2.2, 0.6, 1.7), (0, 3.4, 0), "#8a8478", "stone"))
    p.append(P("box", (0.5, 0.5, 0.2), (0, 3.4, 0.86), "#3a3530", "dark"))
    p.append(P("sphere", (0.2, 0.2, 0.2), (0, 3.4, 0.98), "#ff5a2a", "glow"))
    for s in (-1, 1):
        p.append(P("cylinder", (0.12, 0.5, 0.12), (s * 0.78, 2.6, 0.86), DARK, "dark", rot=(90, 0, 0)))
        p.append(P("sphere", (0.18, 0.18, 0.18), (s * 0.78, 2.85, 1.1), "#ffb030", "glow"))
    return M("Вход в подземелье", p, "Подземелья")


def dspikes_model():
    p = [P("box", (1.96, 0.1, 1.96), (0, 0.05, 0), "#4a4540", "stone")]
    for x in range(4):
        for z in range(4):
            px, pz = -0.72 + x * 0.48, -0.72 + z * 0.48
            p.append(P("cone", (0.14, 0.38, 0.14), (px, 0.29, pz), "#9a9fa5", "metal", seg=5))
    p.append(P("box", (0.3, 0.06, 0.3), (0.6, 0.12, -0.6), "#7a1a14", "paint"))
    return M("Ловушка подземелья", p, "Подземелья")


def teleporter_model():
    p = [P("cylinder", (1.9, 0.25, 1.9), (0, 0.12, 0), "#3a3f48", "dark", seg=16),
         P("cylinder", (1.6, 0.06, 1.6), (0, 0.27, 0), "#5aa8ff", "glow", seg=16),
         P("torus", (1.85, 0.16, 1.85), (0, 0.3, 0), "#c9ced4", "metal")]
    for k in range(6):
        a = k * math.pi / 3
        p.append(P("box", (0.16, 1.4, 0.16), (math.cos(a) * 0.85, 0.95, math.sin(a) * 0.85), "#8c949e", "metal"))
        p.append(P("sphere", (0.2, 0.2, 0.2), (math.cos(a) * 0.85, 1.7, math.sin(a) * 0.85), "#7fd0ff", "glow"))
    p.append(P("torus", (1.4, 0.1, 1.4), (0, 1.5, 0), "#7fd0ff", "glow", anim="spin"))
    return M("Телепорт", p, "Редкое")


def antimatter_model():
    p = [P("box", (3.8, 0.4, 3.8), (0, 0.2, 0), "#3a3f48", "dark"),
         P("cylinder", (2.6, 1.2, 2.6), (0, 1.0, 0), "#8c949e", "metal", seg=16),
         P("sphere", (2.0, 2.0, 2.0), (0, 2.4, 0), "#b070ff", "glow"),
         P("torus", (3.0, 0.25, 3.0), (0, 2.4, 0), "#c9ced4", "metal", anim="spin"),
         P("torus", (2.6, 0.2, 2.6), (0, 2.4, 0), "#dfe3e8", "metal", anim="spin", rot=(90, 0, 0))]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        p.append(P("box", (0.3, 3.0, 0.3), (math.cos(a) * 1.6, 1.9, math.sin(a) * 1.6), "#5a6068", "metal"))
    return M("Генератор антиматерии", p, "Редкое")


def apply(models, buildings, items, settings):
    models["ruin_wall"] = ruin_wall_model()
    models["ruin_arch"] = arch_model()
    models["dungeon_spikes"] = dspikes_model()
    models["teleporter"] = teleporter_model()
    models["antimatter_gen"] = antimatter_model()
    wild = {"wild": True}
    buildings["ruin_wall"] = {"name": "Стена руин", "desc": "Часть подземелья.", "category": "", "behavior": "wall", "cost": {},
                              "model": "ruin_wall", "hp": 2500, "size": 1, "params": dict(wild)}
    buildings["ruin_arch"] = {"name": "Вход в подземелье", "desc": "Внутри стража, ловушки и сундук с редким чертежом.", "category": "",
                              "behavior": "decor", "cost": {}, "model": "ruin_arch", "hp": 4000, "size": 1, "walkable": True, "params": dict(wild)}
    buildings["dungeon_spikes"] = {"name": "Ловушка подземелья", "desc": "Шипы ранят героя. Перепрыгните (пробел)!", "category": "",
                                   "behavior": "floor", "cost": {}, "model": "dungeon_spikes", "hp": 800, "size": 1,
                                   "params": {"wild": True, "trap_dps_player": 22.0}}
    ch = json.loads(json.dumps(buildings["chest"]))
    ch.update({"name": "Сундук подземелья", "desc": "Добыча подземелья. Заберите всё — подземелье будет пройдено.", "category": "", "cost": {}, "hp": 3000})
    ch["params"] = {"slots": 12, "wild": True}
    buildings["dungeon_chest"] = ch
    # редкие здания: только по чертежу из подземелья
    pt = json.loads(json.dumps(buildings["laser_turret"]))
    pt.update({"name": "Плазменная турель", "desc": "Редкое: исследование в дереве открытий (или чертёж из подземелья, если они включены). Очень сильная турель на энергии, молния бьёт ещё двоих.", "rare": True,
               "cost": {"steel": 20, "circuit": 12, "crystal": 6}, "hp": 2500})
    pt["params"] = dict(pt.get("params", {}), damage=95, range=42, rate=0.7, power=40, chain=2, chain_range=8.0)
    buildings["plasma_turret"] = pt
    buildings["teleporter"] = {"name": "Телепорт", "desc": "Редкое: исследование в дереве открытий (или чертёж из подземелья, если они включены). Поставьте два и больше: в окне телепорта — «Перенестись» к другому.",
                               "category": "special", "behavior": "decor", "cost": {"steel": 12, "circuit": 8, "crystal": 4}, "model": "teleporter",
                               "hp": 1200, "size": 2, "walkable": True, "rare": True, "params": {"teleport": True}}
    buildings["antimatter_gen"] = {"name": "Генератор антиматерии", "desc": "Редкое: исследование в дереве открытий (или чертёж из подземелья, если они включены). 400 энергии без топлива.",
                                   "category": "energy", "behavior": "decor", "cost": {"steel": 40, "circuit": 20, "crystal": 12}, "model": "antimatter_gen",
                                   "hp": 3000, "size": 4, "rare": True,
                                   "blocks": [{"type": "power_gen", "power": 400.0, "radius": 10.0, "fuel": False, "solar": False}]}
    for bid, name in (("plasma_turret", "Плазменная турель"), ("teleporter", "Телепорт"), ("antimatter_gen", "Генератор антиматерии")):
        items["bp_" + bid] = {"name": "Чертёж: " + name, "desc": "Редкий чертёж из подземелья. Использовать (ПКМ) — здание можно строить.",
                              "color": "#ffd36b", "category": "Чертежи", "stack": 5, "price": 300, "rarity": "epic", "model": "drop_gift",
                              "on_use": [{"do": "unlock_rare", "key": bid}]}
    # 11.10: подземелья выключены по просьбе (включить — «Настройки → Подземелья»); редкие здания — в дереве открытий
    settings["dungeons"] = {
        "enabled": False, "count": 4, "min_dist": 70, "max_dist": 220, "wake_dist": 70,
        "guards": [{"enemy": "zombie_soldier", "n": 3, "from_day": 0}, {"enemy": "troll_cave", "n": 1, "from_day": 0},
                   {"enemy": "ghost_knight", "n": 2, "from_day": 4}],
        "boss": "giant_chief",
        "loot": [{"item": "crystal", "chance": 1.0, "min": 4, "max": 8}, {"item": "circuit", "chance": 1.0, "min": 5, "max": 10},
                 {"item": "steel", "chance": 0.8, "min": 10, "max": 20}, {"item": "medkit", "chance": 0.6, "min": 1, "max": 3}],
        "blueprints": ["bp_plasma_turret", "bp_teleporter", "bp_antimatter_gen"]}
