# 14.3 Живой мир, который мешает играть: солнечный выброс, «Рёв матери», «Дрожь земли», землетрясение.
# Укрытия (бункер) и щиты-купола. Всё правится в редакторе: «События», «Здания», «Монстры и НПС».
import math
from art_kit import P, M, shade

CONC, STEEL, DARK = "#9e9c91", "#8c949e", "#292b30"


def bunker_model():
    """Бункер 3×3: полузакопанный бетонный купол, стальная дверь, вентиляция, мешки с песком."""
    p = []
    p.append(P("box", (6.0, 0.3, 6.0), (0, 0.15, 0), shade(CONC, 0.8), "concrete"))
    p.append(P("cylinder", (5.4, 1.2, 5.4), (0, 0.9, 0), CONC, "concrete", seg=24))
    p.append(P("sphere", (5.2, 3.4, 5.2), (0, 1.5, 0), shade(CONC, 1.08), "concrete", seg=24))
    # рёбра жёсткости купола
    for k in range(12):
        a = k / 12 * 360
        r = math.radians(a)
        p.append(P("box", (0.18, 1.4, 0.3), (math.cos(r) * 2.62, 1.0, math.sin(r) * 2.62), shade(CONC, 0.7), "concrete", rot=(0, -a, 0)))
    # вход: тамбур с дверью
    p.append(P("box", (1.6, 2.0, 1.8), (2.6, 1.0, 0), shade(CONC, 0.95), "concrete"))
    p.append(P("box", (0.08, 1.6, 1.1), (3.42, 0.95, 0), "#4a5058", "metal"))
    p.append(P("cylinder", (0.5, 0.06, 0.5), (3.47, 1.0, 0), "#c9a227", "metal", rot=(0, 0, 90), seg=12))
    for z in (-0.45, 0.45):
        p.append(P("box", (0.1, 1.7, 0.08), (3.44, 0.95, z), "#2e3238", "metal"))
    p.append(P("box", (0.1, 0.25, 1.3), (3.44, 1.9, 0), "#f2a81f", "paint"))
    p.append(P("sphere", (0.18, 0.18, 0.18), (3.5, 2.1, 0), "#ff3b1f", "glow", anim="blink", seg=8))
    # вентиляция и антенна
    for x, z in ((-1.2, 1.0), (-1.0, -1.3), (0.6, -1.5)):
        p.append(P("cylinder", (0.36, 0.9, 0.36), (x, 3.0, z), STEEL, "metal", seg=12))
        p.append(P("cylinder", (0.52, 0.12, 0.52), (x, 3.5, z), DARK, "metal", seg=12))
    p.append(P("cylinder", (0.06, 2.0, 0.06), (0.2, 4.1, 0.6), STEEL, "metal", seg=6))
    p.append(P("sphere", (0.14, 0.14, 0.14), (0.2, 5.1, 0.6), "#ff3b1f", "glow", anim="blink", seg=8))
    # мешки с песком по кругу
    for k in range(22):
        a = k / 22 * 360
        if -35 < ((a + 180) % 360) - 180 < 35:
            continue   # проход к двери
        r = math.radians(a)
        for row in range(3):
            p.append(P("capsule", (0.34, 0.7, 0.34), (math.cos(r) * 2.95, 0.42 + row * 0.3, math.sin(r) * 2.95), "#b8a476" if row else "#a8946a", "cloth", rot=(90, -a, 0), seg=8))
    # заклёпки по нижнему кольцу и швы плит купола
    for k in range(36):
        r = math.radians(k * 10)
        p.append(P("sphere", (0.09, 0.09, 0.09), (math.cos(r) * 2.71, 1.35, math.sin(r) * 2.71), STEEL, "metal", seg=6))
    for ring, (h, rr) in enumerate(((2.15, 2.35), (2.75, 1.75))):
        for k in range(16):
            a = k / 16 * 360 + ring * 11
            r = math.radians(a)
            p.append(P("box", (0.06, 0.04, 0.9 - ring * 0.25), (math.cos(r) * rr, h, math.sin(r) * rr), shade(CONC, 0.75), "concrete", rot=(0, -a, 30 + ring * 15)))
    # бочки с водой и ящики у входа
    for i, z in enumerate((-1.5, 1.5)):
        p.append(P("cylinder", (0.5, 0.8, 0.5), (2.4, 0.7, z), "#2f6d9e", "paint", seg=14))
        p.append(P("torus", (0.52, 0.05, 0.52), (2.4, 0.9, z), DARK, "metal", seg=14))
        p.append(P("box", (0.6, 0.5, 0.6), (1.9, 0.55, z * 1.2), "#8a5a2e", "wood"))
    # знак «Укрытие»
    p.append(P("box", (0.06, 0.6, 0.6), (3.48, 1.95, -0.75), "#2f7d4a", "paint"))
    p.append(P("box", (0.07, 0.36, 0.1), (3.5, 1.95, -0.75), "#f2f2f2", "paint"))
    p.append(P("box", (0.07, 0.1, 0.36), (3.5, 1.95, -0.75), "#f2f2f2", "paint"))
    return M("Бункер", p, "Защита")


def shield_model():
    """Щит-купол 2×2: основание, четыре опоры, кольца излучателя и светящийся кристалл."""
    p = []
    p.append(P("cylinder", (3.6, 0.3, 3.6), (0, 0.15, 0), DARK, "metal", seg=24))
    p.append(P("cylinder", (3.0, 0.5, 3.0), (0, 0.55, 0), STEEL, "metal", seg=24))
    for k in range(4):
        a = k * 90 + 45
        r = math.radians(a)
        p.append(P("box", (0.3, 2.6, 0.3), (math.cos(r) * 1.15, 1.9, math.sin(r) * 1.15), "#4a5058", "metal", rot=(math.sin(r) * 12, 0, -math.cos(r) * 12)))
        p.append(P("sphere", (0.3, 0.3, 0.3), (math.cos(r) * 1.4, 0.75, math.sin(r) * 1.4), "#5fd0ff", "glow", anim="pulse", seg=8))
    for i, (y, d) in enumerate(((1.4, 2.2), (2.2, 1.8), (2.9, 1.4))):
        p.append(P("torus", (d, 0.16, d), (0, y, 0), STEEL if i % 2 == 0 else "#5fd0ff", "metal" if i % 2 == 0 else "glow", seg=24, anim="" if i % 2 == 0 else "pulse"))
    p.append(P("cylinder", (0.5, 2.6, 0.5), (0, 1.9, 0), DARK, "metal", seg=12))
    p.append(P("sphere", (0.9, 1.4, 0.9), (0, 3.6, 0), "#5fd0ff", "glow", anim="pulse", seg=16))
    p.append(P("torus", (1.2, 0.08, 1.2), (0, 3.6, 0), "#c8f0ff", "glow", anim="spin", seg=24))
    # катушки излучателя, кабели и заклёпки основания
    for k in range(12):
        a = k * 30
        r = math.radians(a)
        p.append(P("cylinder", (0.22, 0.34, 0.22), (math.cos(r) * 0.95, 2.2, math.sin(r) * 0.95), "#b87333", "metal", seg=10))
        p.append(P("cylinder", (0.06, 1.1, 0.06), (math.cos(r) * 1.3, 0.9, math.sin(r) * 1.3), DARK, "rubber" if False else "dark", rot=(math.sin(r) * 25, 0, -math.cos(r) * 25), seg=6))
    for k in range(32):
        r = math.radians(k * 11.25)
        p.append(P("sphere", (0.07, 0.07, 0.07), (math.cos(r) * 1.72, 0.31, math.sin(r) * 1.72), STEEL, "metal", seg=6))
    for k in range(6):
        a = k * 60
        r = math.radians(a)
        p.append(P("box", (0.08, 0.35, 0.5), (math.cos(r) * 1.5, 0.6, math.sin(r) * 1.5), "#3a3f47", "metal", rot=(0, -a, 0)))
        p.append(P("box", (0.03, 0.1, 0.3), (math.cos(r) * 1.55, 0.65, math.sin(r) * 1.55), "#5cff8c", "glow", rot=(0, -a, 0), anim="blink"))
    for k in range(8):
        a = k * 45
        r = math.radians(a)
        p.append(P("box", (0.5, 0.2, 0.12), (math.cos(r) * 1.6, 0.4, math.sin(r) * 1.6), "#f2a81f", "paint", rot=(0, -a, 0)))
    return M("Щит-купол", p, "Защита")


def apply(models, buildings, events, enemies):
    models["bunker"] = bunker_model()
    models["shield_dome"] = shield_model()
    buildings["bunker"] = {"name": "Бункер", "desc": "Укрытие от солнечного выброса и других бед: герой рядом с бункером (в радиусе укрытия) в безопасности. Энергия не нужна.",
                           "category": "defense", "behavior": "decor", "cost": {"concrete": 25, "iron_plate": 10}, "model": "bunker", "hp": 3000, "size": 3,
                           "params": {"shelter_radius": 4.0}}
    buildings["shield_dome"] = {"name": "Щит-купол", "desc": "Энергощит: всё под куполом — герой, здания и машины — защищено от солнечного выброса и работает дальше. Нужна энергия.",
                                "category": "defense", "behavior": "decor", "cost": {"steel": 15, "circuit": 8, "crystal": 4, "wire": 10}, "model": "shield_dome", "hp": 1200, "size": 2,
                                "params": {"power": 30, "shield_radius": 12.0, "shield_color": "#5fd0ff"}}
    enemies["worm"] = {"name": "Земляной червь", "model": "worm", "hp": 260, "speed": 5.0, "damage": 30, "rate": 1.4, "reach": 2.2, "reward": 14, "xp": 10,
                       "behavior": "nearest", "radius": 1.3, "burrow": True,
                       "drops": [{"item": "chitin", "chance": 0.8, "min": 2, "max": 4}, {"item": "raw_meat", "chance": 0.5, "min": 1, "max": 3}]}

    def ev(id, d):
        d.setdefault("actions", [])
        d.setdefault("prices", [])
        d.setdefault("end_text", "")
        events[id] = d

    ev("solar_flare", {"name": "Солнечный выброс", "kind": "flare", "color": "#ffb43a", "chance": 0.08, "min_day": 5, "duration": 75, "power": 1.0,
                       "text": "Солнечный выброс через 15 секунд! Бегите в бункер, под щит-купол или под навес штаба. Снаружи всё живое сгорит, машины встанут.",
                       "end_text": "Выброс закончился, можно выходить.", "delay": 15, "outdoor_dps": 12, "building_dmg": 0.3, "stop_machines": True, "no_loot": True,
                       "sky_color": "#ffcf7a", "sky_power": 0.75,
                       "prices": [{"item": "medkit", "category": "", "mult": 1.5}, {"item": "", "category": "Оборона", "mult": 1.3}]})
    ev("mother_roar", {"name": "Рёв матери", "kind": "horde", "color": "#ff4a3a", "chance": 0.07, "min_day": 6, "duration": 90, "power": 18,
                       "text": "Где-то далеко ревёт мать роя… Толпы монстров идут прямо на вас!", "end_text": "Рёв стих.",
                       "monsters": ["crawler", "runner", "spitter", "brute"], "spawn_dist": 42, "shake": 0.3, "sky_color": "#b03030", "sky_power": 0.25,
                       "prices": [{"item": "ammo", "category": "", "mult": 1.5}]})
    ev("ground_tremor", {"name": "Дрожь земли", "kind": "worms", "color": "#c89a5a", "chance": 0.08, "min_day": 4, "duration": 80, "power": 4,
                         "text": "Земля дрожит… Под базой роют черви! Они вылезают, чтобы ломать здания и кусать.", "end_text": "Черви ушли глубоко под землю.",
                         "monsters": ["worm"], "spawn_dist": 18, "shake": 0.5,
                         "prices": [{"item": "", "category": "Материалы", "mult": 1.15}]})
    ev("earthquake", {"name": "Землетрясение", "kind": "quake", "color": "#d08a4a", "chance": 0.05, "min_day": 6, "duration": 8, "power": 1.0,
                      "text": "Землетрясение! Здания теряют половину прочности (на фундаменте — четверть).", "end_text": "Толчки прекратились. Чините базу.",
                      "quake_dmg": 0.5, "quake_found_mult": 0.5, "quake_kill": False, "shake": 1.2,
                      "prices": [{"item": "concrete", "category": "", "mult": 1.4}, {"item": "", "category": "Материалы", "mult": 1.2}]})
