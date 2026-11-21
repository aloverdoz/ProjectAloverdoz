# 13.10 (2): переделка по просьбе — стартовая зона за бурей, расширение за ресурсы,
# месторождения на один бур, добыча руками с месторождения, сканирование ресурсов, новая оборона.
# Всё правится в редакторе («Настройки» → «Зона и буря», «Мир» → «Месторождения», «Предметы» → «Сканировать штук»).

ZONE_STEPS = [
    {"log": 20, "stone": 20},
    {"plank": 20, "stone": 40},
    {"iron_ingot": 20, "plank": 30},
    {"iron_ingot": 40, "copper_ingot": 20},
    {"iron_plate": 30, "wire": 30},
    {"gear": 30, "iron_plate": 40},
    {"concrete": 40, "steel": 20},
    {"steel": 40, "wire": 60},
    {"circuit": 20, "steel": 50},
    {"motor": 10, "circuit": 30},
    {"concrete": 100, "motor": 20},
    {"circuit": 60, "battery": 10},
]


def apply_zone(settings):
    settings["zone"] = {
        "enabled": True, "block_m": 8.0, "start_blocks": 10, "max_blocks": 90, "growth": 1.25,
        "steps": [{"cost": c} for c in ZONE_STEPS],
        "corner": 0.35, "wobble": 4.0, "shape_seed": 7, "soft": 5.0, "cloud_height": 2.4, "cloud_layers": 3,
        "cloud_density": 0.9, "cloud_far": 120.0, "lightning_every": 4.0, "flicker": 1.0, "cloud_speed": 1.0,
        "dark_color": "#0f0f17", "cloud_color": "#5a5478", "flash_color": "#a8c0ff",
    }
    settings.setdefault("modules", {})["zone"] = True


# ---------------------------------------------------------------- месторождения под один бур
def _shade(hx, k):
    h = hx.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    f = lambda v: max(0, min(255, int(v * k)))
    return "#%02x%02x%02x" % (f(r), f(g), f(b))


def marker_model(name, col):
    """Знак залежи: кристаллы и глыбы руды по краям клетки 2×2 м, в середине — тёмная выработка под бур."""
    import math
    import random
    rnd = random.Random(hash(name) & 0xffff)
    p = [{"shape": "cylinder", "size": [1.7, 0.06, 1.7], "pos": [0, 0.03, 0], "color": _shade(col, 0.55), "mat": "stone", "seg": 8}]
    for i in range(10):
        a = i / 10 * math.tau + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(0.72, 0.92)
        h = rnd.uniform(0.18, 0.42)
        shape = "prism" if i % 3 == 0 else "box"
        p.append({"shape": shape, "size": [rnd.uniform(0.16, 0.3), h, rnd.uniform(0.14, 0.26)],
                  "pos": [round(math.cos(a) * r, 3), round(h * 0.45, 3), round(math.sin(a) * r, 3)],
                  "rot": [rnd.uniform(-20, 20), math.degrees(-a), rnd.uniform(-25, 25)],
                  "color": col if i % 2 == 0 else _shade(col, 1.35), "mat": "metal" if i % 2 == 0 else "stone", "bevel": 0.03 if shape == "box" else 0.0})
    for i in range(4):
        a = (i + 0.5) / 4 * math.tau
        p.append({"shape": "prism", "size": [0.08, 0.5, 0.08], "pos": [round(math.cos(a) * 0.82, 3), 0.25, round(math.sin(a) * 0.82, 3)],
                  "rot": [0, 0, 12], "color": _shade(col, 1.6), "mat": "glow", "anim": "pulse", "tint": False})
    return {"name": "Знак месторождения: " + name, "category": "Месторождения", "parts": p}


def apply_deposits(models, world, items):
    for d in world.get("deposits", []):
        it = d.get("item", "")
        fluid = it in ("oil", "water")
        d["cells"] = 2 if fluid else 1
        d["hand"] = not fluid
        d["hand_hp"] = 25.0
        d["hand_tool"] = "pickaxe"
        d["rocks_around"] = 0 if fluid or not d.get("resource") else 2
        d["near_start"] = {"iron_ore": 3, "copper_ore": 2, "coal": 2, "stone": 2, "quartz": 1, "sulfur": 1, "oil": 0}.get(it, d.get("near_start", 0))
        mid = "dep_" + it
        models[mid] = marker_model(items.get(it, {}).get("name", it), d.get("color", "#808080"))
        d["marker"] = mid


# ---------------------------------------------------------------- находки и сканирование
SCAN_BY_CAT = {"Сырьё": 5, "Материалы": 5, "Руда": 5, "Детали": 5, "Добыча с монстров": 3}


def apply_scan(items, settings, quests):
    for iid, it in items.items():
        it["scan"] = SCAN_BY_CAT.get(it.get("category", ""), 0)
    for iid in ("leaves", "geode", "iron_ore_hq", "copper_ore_hq", "coal_hq", "crystal"):
        if iid in items:
            items[iid]["scan"] = 2 if iid != "geode" else 1
    settings["scan"] = {"enabled": True, "consume": True, "start_known": [], "start_researched": []}
    settings.setdefault("modules", {})["scan"] = True
    # обучение: после брёвен и камней — сканер
    for q in quests.values():
        if q.get("order", 0) >= 2:
            q["order"] = q["order"] + 1
    quests["q_scan"] = {"text": "Отсканируйте ветки, камень и волокно (I — сканер), чтобы делать из них вещи", "order": 2, "reward": 30,
                        "goal": "scan", "n": 3, "item": "", "buildings": [], "hint": "Ветки и волокно — с кустов и земли, камень — с камней. В сканере нажмите «Сканировать»."}


# ---------------------------------------------------------------- оборона: турели, энергощиты, поля
def _p(shape, size, pos, color, mat="metal", rot=(0, 0, 0), role="", anim="", tint=True, seg=None, top=None, bevel=None):
    d = {"shape": shape, "size": [round(float(v), 4) for v in size], "pos": [round(float(v), 4) for v in pos],
         "rot": [round(float(v), 2) for v in rot], "color": color, "mat": mat}
    for k, v in (("role", role), ("anim", anim)):
        if v:
            d[k] = v
    if not tint:
        d["tint"] = False
    for k, v in (("seg", seg), ("top", top), ("bevel", bevel)):
        if v is not None:
            d[k] = v
    return d


DK, MID, LT, ACC, RED, CYAN = "#262a31", "#5d6672", "#c9d0d8", "#f2a12e", "#d94020", "#38d6ff"


def _base(r=0.85, h=0.5):
    """Общая база турели: тумба, кольцо, болты, полосы."""
    import math
    p = [_p("cylinder", (r * 2, h, r * 2), (0, h / 2, 0), DK, "dark", seg=12, top=0.9),
         _p("cylinder", (r * 2.04, 0.08, r * 2.04), (0, h * 0.75, 0), ACC, "paint", seg=12),
         _p("cylinder", (r * 1.1, 0.5, r * 1.1), (0, h + 0.25, 0), MID, seg=12, top=0.8)]
    for k in range(8):
        a = k / 8 * math.tau
        p.append(_p("cylinder", (0.07, 0.04, 0.07), (math.cos(a) * r * 0.85, h + 0.01, math.sin(a) * r * 0.85), LT))
    return p


def m_gatling():
    p = _base()
    p += [_p("box", (0.9, 0.55, 0.8), (0, 1.3, 0), MID, role="head", bevel=0.06),
          _p("box", (0.92, 0.08, 0.82), (0, 1.48, 0), ACC, "paint", role="head"),
          _p("box", (0.4, 0.3, 0.3), (-0.45, 1.3, 0.48), DK, role="head", bevel=0.03),
          _p("cylinder", (0.36, 0.16, 0.36), (0.5, 1.3, 0), DK, rot=(0, 0, 90), role="head")]
    import math
    for k in range(6):
        a = k / 6 * math.tau
        p.append(_p("cylinder", (0.07, 0.95, 0.07), (1.0, 1.3 + math.cos(a) * 0.11, math.sin(a) * 0.11), LT, rot=(0, 0, 90), role="head"))
    p.append(_p("cylinder", (0.3, 0.06, 0.3), (1.45, 1.3, 0), DK, rot=(0, 0, 90), role="head"))
    p.append(_p("box", (0.04, 0.08, 0.4), (0.46, 1.5, 0), "#ffcc4d", "glow", role="head", tint=False))
    return {"name": "Пулемётная турель", "category": "Оборона", "parts": p}


def m_cannon():
    p = _base(0.95, 0.55)
    p += [_p("box", (1.2, 0.7, 1.0), (-0.1, 1.45, 0), MID, role="head", bevel=0.1),
          _p("wedge", (0.4, 0.7, 1.0), (0.65, 1.45, 0), MID, rot=(0, 180, 0), role="head"),
          _p("cylinder", (0.32, 1.6, 0.32), (1.3, 1.5, 0), DK, rot=(0, 0, 90), role="head"),
          _p("cylinder", (0.42, 0.3, 0.42), (2.0, 1.5, 0), MID, rot=(0, 0, 90), role="head"),
          _p("cylinder", (0.4, 0.1, 0.4), (0.8, 1.5, 0), ACC, "paint", rot=(0, 0, 90), role="head"),
          _p("box", (1.22, 0.08, 1.02), (-0.1, 1.82, 0), ACC, "paint", role="head"),
          _p("box", (0.4, 0.4, 0.5), (-0.75, 1.5, 0), DK, role="head", bevel=0.04)]
    return {"name": "Пушка", "category": "Оборона", "parts": p}


def m_missile():
    p = _base(1.0, 0.55)
    p += [_p("box", (0.8, 0.5, 1.6), (0, 1.3, 0), MID, role="head", bevel=0.06),
          _p("box", (0.82, 0.06, 1.62), (0, 1.56, 0), ACC, "paint", role="head")]
    for sz in (-0.42, 0.42):
        p.append(_p("box", (1.1, 0.7, 0.62), (0.1, 1.95, sz), DK, role="head", bevel=0.05))
        for i in range(2):
            for j in range(2):
                p.append(_p("cylinder", (0.2, 0.06, 0.2), (0.66, 1.78 + i * 0.32, sz - 0.15 + j * 0.3), RED, "paint", rot=(0, 0, 90), role="head"))
                p.append(_p("cone", (0.16, 0.2, 0.16), (0.72, 1.78 + i * 0.32, sz - 0.15 + j * 0.3), LT, rot=(0, 0, -90), role="head"))
    p.append(_p("sphere", (0.12, 0.12, 0.12), (-0.3, 2.4, 0), RED, "glow", role="head", anim="blink", tint=False))
    return {"name": "Ракетная установка", "category": "Оборона", "parts": p}


def m_flamer():
    p = _base(0.8, 0.45)
    p += [_p("box", (0.8, 0.5, 0.7), (0, 1.2, 0), MID, role="head", bevel=0.08),
          _p("cylinder", (0.5, 0.7, 0.5), (-0.35, 1.3, 0.42), RED, "paint", role="head", seg=12),
          _p("cylinder", (0.5, 0.7, 0.5), (-0.35, 1.3, -0.42), RED, "paint", role="head", seg=12),
          _p("cylinder", (0.16, 0.9, 0.16), (0.75, 1.2, 0), DK, rot=(0, 0, 90), role="head"),
          _p("cone", (0.3, 0.3, 0.3), (1.25, 1.2, 0), DK, rot=(0, 0, -90), role="head"),
          _p("sphere", (0.12, 0.12, 0.12), (1.38, 1.2, 0), "#ff7a20", "glow", role="head", anim="flicker", tint=False)]
    return {"name": "Плазменный огнемёт", "category": "Оборона", "parts": p}


def m_sniper_tower():
    p = [_p("box", (1.6, 0.4, 1.6), (0, 0.2, 0), DK, "dark", bevel=0.08)]
    for sx in (-0.55, 0.55):
        for sz in (-0.55, 0.55):
            p.append(_p("box", (0.18, 3.0, 0.18), (sx * 0.8, 1.7, sz * 0.8), MID, rot=(sz * 8, 0, -sx * 8)))
    p += [_p("box", (1.3, 0.12, 1.3), (0, 1.6, 0), ACC, "paint"),
          _p("box", (1.4, 0.2, 1.4), (0, 3.2, 0), DK, bevel=0.05),
          _p("box", (0.8, 0.5, 0.6), (0, 3.6, 0), MID, role="head", bevel=0.06),
          _p("cylinder", (0.12, 2.0, 0.12), (1.3, 3.65, 0), DK, rot=(0, 0, 90), role="head"),
          _p("cylinder", (0.2, 0.3, 0.2), (2.3, 3.65, 0), MID, rot=(0, 0, 90), role="head"),
          _p("cylinder", (0.14, 0.5, 0.14), (0.2, 3.95, 0), DK, rot=(0, 0, 90), role="head"),
          _p("cylinder", (0.1, 0.02, 0.1), (0.46, 3.95, 0), "#ff4a1c", "glow", rot=(0, 0, 90), role="head", anim="pulse", tint=False)]
    return {"name": "Снайперская башня", "category": "Оборона", "parts": p}


def m_barrier(big=False):
    import math
    s = 1.5 if big else 1.0
    p = [_p("cylinder", (2.4 * s, 0.4, 2.4 * s), (0, 0.2, 0), DK, "dark", seg=16),
         _p("cylinder", (2.0 * s, 0.3, 2.0 * s), (0, 0.55, 0), MID, seg=16),
         _p("cylinder", (0.8 * s, 1.6 * s, 0.8 * s), (0, 1.2 * s, 0), MID, seg=12, top=0.7),
         _p("sphere", (0.9 * s, 0.9 * s, 0.9 * s), (0, 2.2 * s, 0), CYAN, "glow", anim="pulse", tint=False),
         _p("torus", (1.4 * s, 1.4 * s, 1.4 * s), (0, 2.2 * s, 0), ACC, "paint", rot=(90, 0, 0), anim="spin"),
         _p("torus", (1.2 * s, 1.2 * s, 1.2 * s), (0, 2.2 * s, 0), LT, rot=(0, 0, 90), anim="spin")]
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        p.append(_p("box", (0.3, 1.2 * s, 0.3), (math.cos(a) * 0.95 * s, 0.9 * s, math.sin(a) * 0.95 * s), DK, rot=(0, -math.degrees(a), 12), bevel=0.04))
        p.append(_p("box", (0.06, 0.6 * s, 0.32), (math.cos(a) * 1.08 * s, 1.0 * s, math.sin(a) * 1.08 * s), CYAN, "glow", rot=(0, -math.degrees(a), 12), anim="pulse", tint=False))
    return {"name": "Большой энергощит" if big else "Энергощит", "category": "Оборона", "parts": p}


def m_slow():
    import math
    p = [_p("cylinder", (1.6, 0.35, 1.6), (0, 0.175, 0), DK, "dark", seg=12),
         _p("cylinder", (0.5, 1.6, 0.5), (0, 1.1, 0), MID, seg=10),
         _p("sphere", (0.7, 0.7, 0.7), (0, 2.1, 0), "#7a6cff", "glow", anim="pulse", tint=False)]
    for k in range(3):
        a = k / 3 * math.tau
        p.append(_p("box", (0.12, 1.4, 0.12), (math.cos(a) * 0.55, 1.2, math.sin(a) * 0.55), LT, rot=(math.sin(a) * 14, 0, -math.cos(a) * 14)))
        p.append(_p("sphere", (0.18, 0.18, 0.18), (math.cos(a) * 0.4, 1.95, math.sin(a) * 0.4), "#b8a8ff", "glow", anim="blink", tint=False))
    p.append(_p("torus", (1.3, 1.3, 1.3), (0, 2.1, 0), ACC, "paint", anim="spin"))
    return {"name": "Стазис-поле", "category": "Оборона", "parts": p}


def m_repair():
    p = [_p("box", (1.5, 0.4, 1.5), (0, 0.2, 0), DK, "dark", bevel=0.06),
         _p("box", (0.9, 1.4, 0.9), (0, 1.1, 0), MID, bevel=0.08),
         _p("box", (0.92, 0.1, 0.92), (0, 1.4, 0), ACC, "paint"),
         _p("box", (0.5, 0.14, 0.14), (0, 1.1, 0.46), "#4dff73", "glow", anim="pulse", tint=False),
         _p("box", (0.14, 0.5, 0.14), (0, 1.1, 0.46), "#4dff73", "glow", anim="pulse", tint=False),
         _p("cylinder", (0.12, 0.8, 0.12), (0, 2.2, 0), DK),
         _p("cylinder", (0.6, 0.12, 0.6), (0, 2.55, 0), MID, anim="spin"),
         _p("sphere", (0.22, 0.22, 0.22), (0, 2.7, 0), "#4dff73", "glow", anim="blink", tint=False)]
    for s in (-1, 1):
        p += [_p("box", (0.1, 0.7, 0.1), (0.5 * s, 1.75, 0), LT, rot=(0, 0, -25 * s)),
              _p("box", (0.2, 0.08, 0.08), (0.72 * s, 2.05, 0), ACC, "paint")]
    return {"name": "Ремонтная башня", "category": "Оборона", "parts": p}


def m_shock_floor():
    p = [_p("box", (2.0, 0.12, 2.0), (0, 0.06, 0), DK, "dark")]
    for i in range(4):
        x = -0.75 + i * 0.5
        p.append(_p("box", (0.08, 0.06, 1.8), (x, 0.14, 0), "#7ad8ff", "glow", anim="flicker", tint=False))
    p += [_p("box", (2.0, 0.08, 0.1), (0, 0.13, 0.95), ACC, "paint"), _p("box", (2.0, 0.08, 0.1), (0, 0.13, -0.95), ACC, "paint")]
    return {"name": "Электропол", "category": "Оборона", "parts": p}


def apply_defense(models, buildings, tech):
    def B(id, name, desc, beh, cost, model, hp, size, **params):
        buildings[id] = {"name": name, "desc": desc, "category": "defense", "behavior": beh, "cost": cost, "model": id, "hp": hp,
                         "size": size, "params": params, "sounds": {}}
        models[id] = model
    B("gatling_turret", "Пулемётная турель", "Очень быстрая стрельба мелкими пулями. Берёт патроны из штаба.", "turret",
      {"iron_plate": 10, "gear": 6, "motor": 1}, m_gatling(), 700, 1, range=26, damage=6, rate=0.07, ammo="ammo", power=0, beam_color="#ffd060")
    B("cannon_turret", "Пушка", "Медленный мощный выстрел со взрывом: ранит всех рядом с целью. Берёт патроны.", "turret",
      {"steel": 12, "gear": 8, "iron_plate": 10}, m_cannon(), 1100, 1, range=40, damage=70, rate=1.8, ammo="ammo", power=0, splash=3.5, splash_k=0.6, beam_color="#ffb040")
    B("missile_turret", "Ракетная установка", "Бьёт очень далеко ракетами с большим взрывом. Нужны патроны и энергия.", "turret",
      {"steel": 20, "circuit": 8, "motor": 4}, m_missile(), 1300, 1, range=60, damage=140, rate=3.0, ammo="ammo", power=10, splash=5.0, splash_k=0.7, beam_color="#ff6a30")
    B("flame_turret", "Плазменный огнемёт", "Близко, но жжёт всех перед собой. Патроны не нужны, нужна энергия.", "turret",
      {"steel": 10, "circuit": 6, "crystal": 2}, m_flamer(), 900, 1, range=11, damage=9, rate=0.12, ammo="", power=20, splash=2.2, splash_k=0.8, beam_color="#ff7a20")
    B("sniper_tower", "Снайперская башня", "Самая дальняя стрельба: выбивает опасных роботов издалека. Берёт патроны.", "turret",
      {"steel": 15, "glass": 6, "circuit": 4}, m_sniper_tower(), 900, 1, range=75, damage=180, rate=3.5, ammo="ammo", power=0, beam_color="#ff4a1c")
    B("barrier_small", "Энергощит", "Купол принимает на себя урон: герой и здания внутри целы, пока у щита есть запас. Восстанавливается сам. Нужна энергия.",
      "decor", {"steel": 10, "circuit": 6, "wire": 12}, m_barrier(), 900, 2, defense="barrier", barrier_radius=9.0, barrier_hp=600.0,
      barrier_regen=15.0, barrier_delay=8.0, barrier_color="#5fd0ff", power=25)
    B("barrier_large", "Большой энергощит", "Огромный купол с большим запасом. Нужна энергия.", "decor",
      {"steel": 30, "circuit": 20, "crystal": 6, "battery": 4}, m_barrier(True), 2500, 3, defense="barrier", barrier_radius=18.0,
      barrier_hp=2500.0, barrier_regen=40.0, barrier_delay=12.0, barrier_color="#7ab8ff", power=70)
    B("stasis_field", "Стазис-поле", "Роботы рядом идут вдвое медленнее — турели успевают их добить. Нужна энергия.", "decor",
      {"circuit": 6, "wire": 10, "crystal": 2}, m_slow(), 600, 1, defense="slow", slow_radius=12.0, slow_k=0.45, power=20)
    B("repair_tower", "Ремонтная башня", "Сама чинит здания вокруг. Нужна энергия.", "decor",
      {"steel": 8, "circuit": 4, "motor": 2}, m_repair(), 700, 1, defense="repair", repair_radius=14.0, repair_rate=25.0, power=15)
    B("shock_floor", "Электропол", "Ловушка: роботы, которые идут по полу, получают сильный удар током. Изнашивается медленно.", "floor",
      {"copper_ingot": 6, "wire": 8}, m_shock_floor(), 400, 1, trap_dps=70.0, trap_wear=0.5)
    T = lambda id, name, tier, order, icon, desc, cost, blds, req, research=0: tech.__setitem__(id, {
        "name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost, "unlocks": {"buildings": blds},
        "requires": req, **({"research": research} if research else {})})
    T("t_def2", "Тяжёлая оборона", 2, 5, "gatling_turret", "Пулемёт, пушка, электропол и ремонтная башня.",
      {"iron_plate": 30, "gear": 20, "steel": 10}, ["gatling_turret", "cannon_turret", "shock_floor", "repair_tower"], ["t_defense"])
    T("t_def3", "Энергощиты", 3, 5, "barrier_small", "Энергощит, стазис-поле и снайперская башня.",
      {"steel": 30, "circuit": 20, "wire": 30}, ["barrier_small", "stasis_field", "sniper_tower"], ["t_def2", "t_power"], 10)
    T("t_def4", "Ракеты и плазма", 4, 5, "missile_turret", "Ракетная установка, плазменный огнемёт и большой энергощит.",
      {"steel": 60, "circuit": 40, "crystal": 10, "battery": 6}, ["missile_turret", "flame_turret", "barrier_large"], ["t_def3", "t_laser"], 20)


# ---------------------------------------------------------------- качество залежей и скорость буров и лент (13.10)
PURITY = [
    {"id": "poor", "name": "Бедная", "per_min": 30, "chance": 20, "color": "#9aa0a6"},
    {"id": "normal", "name": "Нормальная", "per_min": 60, "chance": 45, "color": "#e8e8e8"},
    {"id": "rich", "name": "Богатая", "per_min": 120, "chance": 30, "color": "#ffd24a"},
    {"id": "legendary", "name": "Легендарная", "per_min": 240, "chance": 5, "color": "#c77dff"},
]
BELT_RATES = {"belt": 120, "belt_mk2": 300, "belt_mk3": 520, "belt_mk4": 880, "belt_mk5": 1360}


def apply_purity(buildings, settings):
    settings["purity"] = [dict(p) for p in PURITY]
    settings["purity_start"] = "normal,rich"
    for bid, b in buildings.items():
        pr = b.get("params", {})
        if b.get("behavior") == "miner" and pr.get("extracts", "solid") != "fluid" and not pr.get("water_item"):
            pr["rate_mult"] = float(pr.get("tier", 1))   # Mk2 — ×2 от Mk1, Mk3 — ×3...
    for bid, b in buildings.items():   # разветвители и соединители не тормозят линию
        if b.get("behavior") in ("splitter", "merger"):
            b.setdefault("params", {})["per_min"] = 1360
    for bid, pm in BELT_RATES.items():
        if bid in buildings:
            buildings[bid].setdefault("params", {})["per_min"] = pm


def apply(models, buildings, items, resources, recipes, settings, world, tech, sounds, quests):
    apply_purity(buildings, settings)
    apply_zone(settings)
    apply_deposits(models, world, items)
    apply_scan(items, settings, quests)
    apply_defense(models, buildings, tech)
    world["start_clear_radius"] = 8   # лес и камни ближе к штабу: всё нужное для старта — внутри зоны


# ---------------------------------------------------------------- зловещие надписи перед событиями (13.10)
OMENS = {
    "meteor_shower": ("Небо раскалывается огненными трещинами...", "#ff8c3a"),
    "storm": ("Ветер воет всё громче. Надвигается буря...", "#9fb4ff"),
    "invasion": ("Земля гудит от тысяч металлических шагов...", "#ff4a3a"),
    "supply_drop": ("В небе мигает сигнальный огонь станции.", "#8fe0ff"),
    "trader_visit": ("Вдали скрипят колёса каравана.", "#ffd77a"),
    "travelers": ("На горизонте показались чьи-то силуэты...", "#d8d8d8"),
    "bandit_raid": ("Кто-то следит за вашей базой из темноты...", "#ff6a4a"),
    "stranger": ("Чужие шаги звучат совсем рядом...", "#c8b0ff"),
    "solar_flare": ("Солнце наливается кровавым светом...", "#ff5a2a"),
    "mother_roar": ("Из глубины туч доносится гудящий сигнал роя...", "#ff4a6a"),
    "ground_tremor": ("Под ногами что-то скребётся и сверлит камень...", "#c89a6a"),
    "earthquake": ("Земля содрогается от чудовищной силы из глубины!", "#ff7a3a"),
    "acid_rain": ("Тучи желтеют. Воздух пахнет кислотой...", "#c8ff4a"),
    "frost": ("Дыхание стынет. Мороз сковывает всё живое...", "#9fe0ff"),
    "heatwave": ("Воздух дрожит от жара, земля трескается...", "#ffb03a"),
    "eclipse": ("Свет меркнет. Что-то закрывает солнце...", "#b08aff"),
    "dense_fog": ("Белая мгла ползёт со всех сторон...", "#e0e8f0"),
    "locusts": ("Слышите жужжание? Сборщики идут за вашими запасами...", "#ffd04a"),
    "capsule_crash": ("Что-то огромное с рёвом падает с орбиты!", "#ff8a4a"),
    "rich_vein": ("Земля трескается, обнажая блеск руды...", "#ffe08a"),
    "gnome_raid": ("Писк сканеров. Разведчики уже рядом...", "#ff9a6a"),
    "robot_invasion": ("Красные огни загораются в тучах. Роботы идут...", "#ff3a3a"),
    "alien_landing": ("Небо прорезают огни посадочных двигателей...", "#ff5ab0"),
}


def apply_omens(events, waves):
    for eid, (txt, col) in OMENS.items():
        if eid in events:
            e = events[eid]
            e["omen"] = txt
            e["omen_color"] = col
            e["omen_lead"] = 6.0      # за сколько секунд до начала
            e["omen_time"] = 5.0      # сколько висит надпись
            e["omen_sound"] = "omen"
    for eid, e in events.items():   # свои события без текста — общая фраза
        e.setdefault("omen", "")
    waves["omen"] = "Холод пробегает по спине... Из туч выходят роботы!"
    waves["omen_color"] = "#ff4a3a"
    waves["omen_lead"] = 8.0
    waves["omen_time"] = 5.0
    waves["omen_sound"] = "omen"
    waves["boss_omen"] = "Вы чувствуете на себе взгляд чего-то огромного..."


# ---------------------------------------------------------------- кислотный зонтик (13.10)
def apply_umbrella(models, items, recipes):
    canopy, rib, handle = "#7fd04a", "#3b4a2a", "#5a4632"
    parts = [_p("cylinder", (0.05, 1.5, 0.05), (0, 1.55, 0), handle, "wood", seg=8),
             _p("cylinder", (0.12, 0.16, 0.12), (0, 0.85, 0), "#2b2b2b", "rubber", seg=8),
             _p("cone", (1.9, 0.5, 1.9), (0, 2.45, 0), canopy, "cloth", seg=10),
             _p("cylinder", (1.92, 0.05, 1.92), (0, 2.22, 0), rib, "paint", seg=10),
             _p("sphere", (0.1, 0.1, 0.1), (0, 2.72, 0), rib, "metal")]
    for k in range(5):
        import math
        a = k * math.tau / 5
        parts.append(_p("box", (0.9, 0.03, 0.03), (math.cos(a) * 0.45, 2.36, math.sin(a) * 0.45), rib, "metal", rot=(0, -math.degrees(a), -14)))
    models["m_umbrella"] = {"name": "Кислотный зонтик", "category": "Инструменты", "parts": parts}
    items["acid_umbrella"] = {"name": "Кислотный зонтик", "desc": "Сам раскрывается над головой в кислотный дождь и снимает весь урон от него. Быстро разъедается: хватает примерно на минуту дождя. Лежит в рюкзаке — достаточно.",
                              "color": canopy, "category": "Инструменты", "stack": 1, "price": 8, "model": "m_umbrella",
                              "durability": 60, "outdoor_guard": 1.0, "guard_events": ["acid_rain"], "guard_wear": 1.0, "guard_model": "m_umbrella", "scan": 0}
    recipes["acid_umbrella"] = {"name": "Кислотный зонтик", "in": {"fiber": 5, "branch": 2}, "out": {"acid_umbrella": 1}, "time": 2.0, "stations": ["hand", "workbench"]}


# ---------------------------------------------------------------- рюкзак растёт за ресурсы (13.10)
BAG_STEPS = [
    {"fiber": 20, "log": 10},
    {"plank": 20, "fiber": 30},
    {"iron_plate": 20, "plank": 20},
    {"gear": 20, "wire": 30},
    {"steel": 20, "iron_plate": 40},
]


def apply_bag(settings):
    settings["bag"] = {"enabled": True, "start": 36, "max": 81,
                       "steps": [{"add": 9, "cost": c} for c in BAG_STEPS]}


# ---------------------------------------------------------------- обучение для новичков (13.10)
def T(title, text, goal="next", hint="", highlight="", **kw):
    d = {"title": title, "text": text, "goal": goal, "hint": hint, "highlight": highlight, "can_skip": goal != "next"}
    d.update(kw)
    return d


TUTORIAL = [
    T("Добро пожаловать, колонист!",
      "Вы — робот корпорации [b]Frontier[/b]. Задача — построить завод, который сам добывает и перерабатывает ресурсы, и отбиться от машин-захватчиков.\n\nЭто обучение покажет основы шаг за шагом. Его можно пропустить кнопкой сверху."),
    T("Ходьба", "Ходите клавишами {key:move_up} {key:move_left} {key:move_down} {key:move_right}. Зажмите {key:sprint}, чтобы бежать. Колесо мыши — приблизить или отдалить камеру.",
      "move", n=20),
    T("Сканер", "Новые вещи сначала нужно изучить. Откройте сканер ({key:scan}) и отсканируйте ветки, камень и волокно — после этого из них можно делать вещи.",
      "scan", "Подберите по паре штук каждого: ветки и волокно лежат на траве, камни — на земле.", n=3),
    T("Добыча", "Подойдите к дереву и бейте его [b]левой кнопкой мыши[/b]. Брёвна попадут в рюкзак.",
      "have", "Добыча идёт быстрее с топором — его можно сделать в окне крафта.", item="log", n=5),
    T("Камень", "Камни лежат на земле и торчат из скал. Бейте их так же, как деревья.",
      "have", item="stone", n=10),
    T("Рюкзак", "Откройте рюкзак ({key:inventory}). Первые ячейки с цифрами — панель быстрого доступа внизу экрана: цифрой выбираете, что держать в руках.",
      "open", "Ненужное перетащите в красную ячейку «мусор».", highlight="hotbar", window="inventory"),
    T("Крафт", "Откройте окно крафта ({key:craft}) и сделайте каменную кирку — ей быстрее добывать камень и руду.",
      "have", "Наведите на рецепт — подсказка покажет, чего не хватает.", item="stone_pickaxe", n=1),
    T("Руда", "Цветные пятна на земле — залежи руды. Бейте залежь железа киркой, чтобы набрать руду руками.",
      "have", "Залежи бывают бедные, нормальные, богатые и легендарные: наведите на залежь, чтобы увидеть качество.", item="iron_ore", n=8),
    T("Печь", "Откройте меню стройки ({key:build_menu}) и поставьте каменную печь. Положите в неё руду и топливо (ветки или брёвна) — она сама выплавит слитки.",
      "build", "{key:rotate} — повернуть здание, ПКМ — отменить стройку.", building="furnace", n=1),
    T("Железо", "Заберите из печи железные слитки. Из них делаются шестерни, бур и конвейеры.",
      "have", "Подойдите к печи и нажмите {key:interact}, чтобы открыть её.", item="iron_ingot", n=10),
    T("Штаб", "Штаб — сердце базы. Всё, что сложено в штаб, можно тратить на стройку. Кнопка «Сложить в штаб» в рюкзаке переносит туда всё лишнее.",
      highlight="storage"),
    T("Бур", "Поставьте бур прямо на залежь руды. Он сам добывает руду и выдаёт её по стрелке. Буру нужна энергия.",
      "build", "Бур Mk2 добывает в 2 раза больше, Mk3 — в 3 раза.", building="miner", n=1),
    T("Энергия", "Поставьте генератор и положите в него топливо. Машины рядом с генератором или опорами получают энергию.",
      "build", "Опоры соединяются проводами и несут энергию дальше.", building="generator", n=1),
    T("Конвейер", "Протяните конвейер от бура к печи или в штаб: зажмите левую кнопку и ведите мышью. Повороты собираются сами.",
      "build", "Разветвитель делит поток на 3 части, соединитель собирает потоки в один.", building="belt", n=5),
    T("Защита", "Каждые несколько дней с края зоны приходит волна машин-захватчиков. Таймер волны — сверху экрана. Поставьте турель рядом с базой — она берёт патроны со склада штаба.",
      "build", "Перед событиями на экране появляется зловещая надпись — готовьтесь!", building="turret", highlight="wave", n=1),
    T("Зона и тучи", "Вокруг базы — граница из грозовых туч. За ней ничего не видно и нельзя строить. Расширить зону можно за ресурсы в окне штаба.",
      highlight="minimap"),
    T("Всё готово!", "Основы вы знаете. Список задач справа подскажет, что делать дальше. Окно «Как играть» ({key:help}) — все клавиши.\n\nУдачи, колонист!",
      highlight="quests"),
]


def apply_tutorial(settings):
    settings["tutorial"] = {"enabled": True, "steps": TUTORIAL}



# ---------------------------------------------------------------- объединение зданий (14.10)
def apply_fusion(settings):
    settings["fusion"] = {
        "enabled": True, "combo": True, "ask": True, "ask_time": 20.0,
        "max_level": 5, "level_mult": [1, 2, 3, 4, 5], "power_scale": True,
        "max_parts": 5, "furnace_power": 4.0,
        "no_merge": ["belt", "splitter", "merger", "pipe", "foundation", "wall", "floor", "hq", "pole", "tank", "decor"],
        "scale_step": 0.1, "host_scale": 0.72, "module_scale": 0.42, "roof_scale": 0.55, "roof_h": 2.0, "corner_k": 0.62,
        "platform_k": 1.25, "color": "#ffb040", "label_size": 1.0, "label_dist": 35.0,
    }
    mods = settings.setdefault("modules", {})
    mods["fusion"] = True
    mods["combo"] = True


def m_drone_station():
    """Станция дронов: бетонная площадка с буквой H, зарядные стойки, мачта с антенной, кольцо огней."""
    import math
    p = [_p("box", (1.9, 0.3, 1.9), (0, 0.15, 0), "#7d8288", "concrete", bevel=0.05),
         _p("box", (1.6, 0.06, 1.6), (0, 0.33, 0), "#2b3646", "paint"),
         _p("box", (0.12, 0.03, 0.8), (-0.25, 0.37, 0), "#f2f2f2", "paint"),
         _p("box", (0.12, 0.03, 0.8), (0.25, 0.37, 0), "#f2f2f2", "paint"),
         _p("box", (0.5, 0.03, 0.12), (0, 0.37, 0), "#f2f2f2", "paint"),
         _p("box", (0.45, 0.9, 0.45), (-0.7, 0.75, -0.7), "#3d7bd9", "paint", bevel=0.05),
         _p("box", (0.36, 0.22, 0.04), (-0.7, 0.95, -0.47), "#4de1ff", "glow", anim="pulse", tint=False),
         _p("cylinder", (0.08, 1.6, 0.08), (0.75, 1.1, -0.75), "#9aa3ad"),
         _p("cylinder", (0.4, 0.06, 0.4), (0.75, 1.9, -0.75), "#5d6672", anim="spin"),
         _p("sphere", (0.16, 0.16, 0.16), (0.75, 2.0, -0.75), "#ff8c1a", "glow", anim="blink", tint=False)]
    for s in (-1, 1):
        p += [_p("box", (0.14, 0.5, 0.14), (0.75 * s, 0.6, 0.75), "#262a31", "dark"),
              _p("box", (0.16, 0.08, 0.16), (0.75 * s, 0.86, 0.75), "#4dff73", "glow", anim="pulse", tint=False)]
    for k in range(8):
        a = k / 8 * math.tau
        p.append(_p("sphere", (0.07, 0.07, 0.07), (math.cos(a) * 0.62, 0.38, math.sin(a) * 0.62), "#ffd060", "glow", anim="blink", tint=False))
    return {"name": "Станция дронов", "category": "Транспорт", "parts": p}


def apply_drones(models, buildings, tech, settings):
    models["drone_station"] = m_drone_station()
    buildings["drone_station"] = {
        "name": "Станция дронов", "category": "special", "behavior": "decor", "model": "drone_station", "hp": 400, "size": 1,
        "desc": "Дом для дронов-грузчиков. Откройте станцию (E) → «Добавить маршрут» → укажите на карте, откуда брать и куда везти. "
                "Дроны летают сами, заряжаются на станции и чинятся. Объедините две станции: «Объединение 2» — 2 дрона, 3 — 4, 4 — 8, 5 — 15. Нужна энергия.",
        "cost": {"iron_plate": 12, "circuit": 4, "motor": 2},
        "params": {"power": 6, "pollution": 0, "drone_station": True, "drones_k": 1},
        "sounds": {}}
    t = tech.get("t_transport")
    if t is not None:
        lst = t.setdefault("unlocks", {}).setdefault("buildings", [])
        if "drone_station" not in lst:
            lst.insert(0, "drone_station")
    settings["drones"] = {
        "per_level": [1, 2, 4, 8, 15], "capacity": 10, "capacity_per_level": 0.0, "speed": 12.0, "speed_per_level": 0.0,
        "battery_m": 400.0, "charge_rate": 25.0, "reserve": 0.15, "range": 150.0, "hp": 60.0, "repair": 2.0,
        "threat_r": 7.0, "low_h": 3.0, "dmg_k": 1.0, "rebuild_s": 30.0, "rebuild_cost": {"iron_plate": 4, "circuit": 2, "motor": 1},
        "cruise_h": 7.0, "retry_s": 4.0, "model": "drone_carrier", "scale": 0.8,
    }
    fz = settings.setdefault("fusion", {})
    fz.update({"furnace_fuel": "fuel", "fuel_from_line": True, "fuel_from_chest": True, "chest_default": "auto", "overflow_default": "wait"})
