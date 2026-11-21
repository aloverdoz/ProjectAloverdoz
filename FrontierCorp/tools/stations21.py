"""Этап 21: станции энергопередачи вместо проводов.
Станция отдаёт не больше своей мощности зданиям в своём радиусе (ближним первыми), Mk1–Mk5.
Станции, генераторы и аккумуляторы связываются в сеть сами, если стоят в радиусе связи друг друга."""

# id, имя, мощность, радиус, радиус связи, цена, тир, технология
STATIONS = [
    ("pole", "Станция энергии Mk1", 20, 3, 8, {"plank": 2, "wire": 2}, 1, None),
    ("pole_mk2", "Станция энергии Mk2", 80, 4, 10, {"steel": 4, "wire": 6, "circuit": 2}, 2, "t_mk2"),
    ("pole_mk3", "Станция энергии Mk3", 250, 5, 12, {"steel": 8, "wire": 10, "circuit": 4, "plastic": 4}, 3, "t_mk3"),
    ("pole_mk4", "Станция энергии Mk4", 800, 6, 15, {"steel": 12, "circuit": 8, "battery": 2, "plastic": 6}, 4, "t_mk4"),
    ("pole_mk5", "Станция энергии Mk5", 2500, 8, 20, {"steel": 20, "circuit": 12, "crystal": 6, "monster_core": 1}, 5, "t_mk5"),
]


def apply(buildings, tech, settings, models):
    base = buildings["pole"]
    for sid, name, cap, rad, link, cost, tier, tid in STATIONS:
        b = dict(base) if sid != "pole" else base
        b["params"] = dict(base.get("params", {}))
        b["name"] = name
        b["desc"] = ("Передаёт до %d энергии зданиям в радиусе %d клеток: ближние к станции получают первыми, "
                     "кому не хватило — стоят. Сама связывается с генераторами и станциями в радиусе %d клеток. "
                     "Покрытие видно в режиме энергии (V). Поставьте станцию выше уровнем прямо на старую — она обновится." % (cap, rad, link))
        b["cost"] = cost
        if sid not in models and "pole" in models:
            import copy
            models[sid] = copy.deepcopy(models["pole"])   # своя модель приходит из models20 (art20)
        b["model"] = sid
        b["hp"] = 100 + 60 * (tier - 1)
        b["params"].update({"radius": rad, "link": link, "transfer": cap, "tier": tier, "any_ground": True, "wire_height": 3.6})
        buildings[sid] = b
        if tid and tid in tech:
            ul = tech[tid].setdefault("unlocks", {}).setdefault("buildings", [])
            if sid not in ul:
                ul.append(sid)
    hq = buildings.get("hq")
    if hq:
        hq.setdefault("params", {}).update({"transfer": 40, "station_radius": 5})
    settings["power_mode"] = "stations"
    settings["hq_transfer"] = 40
    settings["hq_station_radius"] = 5
    settings["auto_wire"] = False
    # обучение: про станции, а не про провода
    for st in settings.get("tutorial", {}).get("steps", []) if isinstance(settings.get("tutorial"), dict) else []:
        if st.get("hint") == "Опоры соединяются проводами и несут энергию дальше.":
            st["hint"] = "Поставьте станцию энергии: машины в её круге получают энергию, ближние — первыми. V — карта энергии."
            st["text"] = ("Поставьте генератор и положите в него топливо, рядом — станцию энергии. Машины в круге станции получают энергию. "
                          "Угольному генератору позже понадобится вода по трубе.")
    _belts(buildings, tech, settings, models)
    return len(STATIONS)


def _model(models, mid, like):
    import copy
    if mid not in models and like in models:
        models[mid] = copy.deepcopy(models[like])   # своя модель приходит из models20 (art20)
        models[mid]["name"] = mid


def _belts(buildings, tech, settings, models):
    """Кротовина (лента через ленту), бортики (предметы не слетают с поворотов), умный разделитель."""
    _model(models, "mole_junction", "merger")
    buildings["mole_junction"] = {
        "name": "Кротовина", "category": "logistics", "behavior": "junction", "model": "mole_junction", "hp": 150, "size": 1,
        "desc": "Лента через ленту: предметы ныряют в нору и выходят с противоположной стороны. "
                "Две ленты крест-накрест не мешают друг другу. Поставьте на место пересечения.",
        "cost": {"iron_ingot": 4, "gear": 2}, "params": {"per_min": 1360, "any_ground": True}, "sounds": {}}
    if "belt_rails" not in models:
        models["belt_rails"] = {"name": "Бортики", "category": "Логистика", "parts": [
            {"shape": "box", "size": [2.0, 0.3, 0.12], "pos": [0, 0.2, 0.85], "color": "#c9a227", "mat": "paint"},
            {"shape": "box", "size": [2.0, 0.3, 0.12], "pos": [0, 0.2, -0.85], "color": "#c9a227", "mat": "paint"}]}
    _model(models, "belt_rails_corner", "belt_rails")   # Г-образные бортики на повороте
    buildings["belt_rails"] = {
        "name": "Бортики", "category": "logistics", "behavior": "rails", "model": "belt_rails", "hp": 60, "size": 1,
        "desc": "Ставятся на готовую ленту: на повороте предметы с неё больше не слетают. Нужны лентам Mk1 и Mk2.",
        "cost": {"iron_plate": 1}, "params": {"any_ground": True}, "sounds": {}}
    for tid, bid in [("t_logistics", "mole_junction"), ("t_logistics", "belt_rails")]:
        if tid in tech:
            ul = tech[tid].setdefault("unlocks", {}).setdefault("buildings", [])
            if bid not in ul:
                ul.append(bid)
    if "smart_splitter" in buildings:
        buildings["smart_splitter"]["desc"] = ("Сортирует ленту: откройте (E) и нажмите стрелку у предмета — он поедет только в этот выход "
                                               "(например, руда прямо, уголь вправо). Остальное идёт в свободные выходы.")
    settings["belt_spill_pct"] = 2.0
    settings["physics"] = {"enabled": True, "debris": True, "blast": True, "knock": True, "ragdoll": True, "roll": True,
                           "debris_per_cell": 9, "debris_max": 500, "debris_life": 7.0, "debris_force": 1.0,
                           "blast_force": 14.0, "blast_radius": 2.2, "blast_hero": 0.6, "hit_knock": 2.5, "gravity": 18.0}
    settings["render_chunk"] = 64.0      # завод рисуется участками: в кадре и в тенях только видимое
    settings["climb_roofs"] = True       # прыжком на крышу машины, по крышам — через ряд печей
    settings["climb_roof_max"] = 4.0
