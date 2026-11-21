# Версия 1.1.15 (02.11): канал штаба, оборона на энергии и своих патронах, метеориты раз в ~5 минут,
# команда camera, пауза между расширениями зоны. Вызывается из gen_core.py последним.

# мощность турелей с патронами (раньше 0 — стреляли без энергии)
TURRET_POWER = {"turret": 3, "gatling_turret": 6, "cannon_turret": 8, "sniper_tower": 5, "missile_turret": 10}


TUT_OLD = "Патроны она берёт со склада штаба — на старте там уже есть запас. "
TUT_NEW = ("Ей нужна энергия, а патроны кладите в саму турель: откройте её (E) → «Положить» "
           "(стартовый запас лежит в штабе), позже — лентой или через канал штаба. ")


def _swap(o, old, new):
    """Заменить текст во всех строках вложенных словарей и списков."""
    if isinstance(o, dict):
        for k in o:
            if isinstance(o[k], str):
                o[k] = o[k].replace(old, new)
            else:
                _swap(o[k], old, new)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            if isinstance(v, str):
                o[i] = v.replace(old, new)
            else:
                _swap(v, old, new)


def apply(settings, buildings, tech, commands, recipes, quests=None):
    n = 0
    settings["defense115"] = {"local_ammo": True}
    settings["hq_link115"] = {"power_per_cell": 2.0, "power_min": 2.0, "loss_every": 2, "take_per_min": 60.0, "max_items": 5}
    settings["meteor115"] = {"enabled": True, "every": 300.0, "min": 1, "max": 2,
                             "text": "С неба упал метеорит — в нём руда и кристаллы!"}
    fu = settings.setdefault("fusion", {})
    nm = fu.setdefault("no_merge", [])
    if "hq_link" not in nm:
        nm.append("hq_link")   # два канала рядом объединять незачем (только удваивает расход энергии)
    z = settings.setdefault("zone", {})
    z["expand_cooldown"] = 60.0
    for bid, pw in TURRET_POWER.items():
        b = buildings.get(bid)
        if not b:
            continue
        p = b.setdefault("params", {})
        p["power_old114"] = p.get("power", 0)
        p["power"] = pw
        if p.get("ammo"):
            p["ammo_slots"] = 2
        n += 1
    for bid, b in buildings.items():
        if b.get("behavior") == "turret" and b.get("params", {}).get("ammo"):
            d = b.get("desc", "")
            for old in ("Берёт патроны со склада штаба.", "Берёт патроны из штаба.", "Нужны патроны и энергия.", "Нужна энергия и патроны."):
                d = d.replace(old, "")
            b["desc"] = (" ".join(d.split()) + " Нужны энергия и патроны: лентой, через канал штаба или руками в турель.").strip()
    # обучение и задание про турели — по новым правилам
    _swap(settings, TUT_OLD, TUT_NEW)
    if quests is not None:
        _swap(quests, "Постройте 2 турели у базы: патроны они берут из штаба", "Постройте 2 турели у базы, дайте им энергию и патроны")
    # канал штаба: 1-й этап, всё, что пришло на вход, — сразу в штабе (или выбранное из штаба — на выход)
    buildings["hq_link"] = {
        "name": "Канал штаба",
        "desc": ("Связь со штабом без лент. «В штаб»: всё, что пришло на вход, сразу появляется в штабе. "
                 "«Из штаба»: выбранные предметы выходят на ленту. Каждый второй предмет теряется в пути. "
                 "Энергия: клеток до штаба × 2."),
        "category": "logistics", "behavior": "hq_link",
        "cost": {"crystal": 1, "gear": 4, "iron_ingot": 6, "stone": 10},
        "model": "drop_beacon", "hp": 250, "size": 1,
        "params": {"power": 3}, "sounds": {},
    }
    st = tech.get("t_start")
    if st is not None:
        bl = st.setdefault("unlocks", {}).setdefault("buildings", [])
        if "hq_link" not in bl:
            bl.append("hq_link")
    # порох и патроны — с «Химией». Химзавод открывается только на 3-м этапе (кислоты), поэтому порох делает
    # новый «Пороховой цех» (открыт «Химией»), а патроны из пороха — сборщик (открыт «Энергией», нужной для «Химии»).
    buildings["powder_mill"] = {
        "name": "Пороховой цех",
        "desc": "Мешает порох из серы, селитры и угля. Патроны из пороха и пластин делает сборщик. Нужна энергия.",
        "category": "production", "behavior": "crafter",
        "cost": {"iron_plate": 8, "gear": 4, "stone": 10},
        "model": "cb_mixer", "hp": 350, "size": 2, "size0": 1,
        "params": {"station": "powder_mill", "speed": 1.0, "power": 8, "in_slots": 3},
        "sounds": {"work": "work_bubble"},
    }
    gp = recipes.get("gunpowder")
    if gp is not None and "powder_mill" not in gp.setdefault("stations", []):
        gp["stations"].insert(0, "powder_mill")
    ch = tech.get("t_chem")
    if ch is not None:
        u = ch.setdefault("unlocks", {})
        rl = u.setdefault("recipes", [])
        for r in ("gunpowder", "ammo"):
            if r in recipes and r not in rl:
                rl.append(r)
        bl = u.setdefault("buildings", [])
        if "powder_mill" not in bl:
            bl.insert(0, "powder_mill")
        ch["desc"] = "На карте появляются залежи серы и селитры. Пороховой цех: порох; сборщик: патроны. Батареи и гранаты."
    commands["camera"] = {"desc": "Свободная камера для съёмки: WASD, Пробел/Ctrl, ПКМ — повернуть, колесо — FOV, F12 — снимок; ещё раз camera — выйти",
                          "usage": "camera", "actions": [{"do": "camera"}], "cheat": False}
    return n
