# Версия 1.1.18 (08.11): понятный прогресс.
#  • у штаба по одной залежи железа, меди и камня; остальные залежи появляются, когда изучен узел, которому они нужны
#    (уголь — «Уголь и сталь», олово, известняк и глина — «Бронза и детали», кварц и песок — «Электричество»);
#  • ранние рецепты и стоимости узлов не требуют того, что ещё закрыто (уголь до «Угля и стали» — древесный уголь);
#  • каждый рецепт, который открывает узел, можно делать в здании, открытом этим узлом или раньше.
# Вызывается из gen_core.py последним. Старые миры (без флага dep118 в сохранении) — с прежними залежами (main.gd).

START_ONE = {"iron_ore", "copper_ore", "stone"}
DEP118 = {"t_coal": ["coal"], "t_metal": ["tin_ore", "limestone", "clay"], "t_power": ["quartz", "sand"]}
# узел → чего ему не хватало в требованиях (стоимость или рецепты из ещё закрытых узлов)
REQ118 = {"t_sink": ["t_workshop"], "t_def2": ["t_coal", "t_workshop"], "t_mk4": ["t_chem"], "t_def4": ["t_chem"],
          "t_fuse4": ["t_chem"], "t_electro": ["t_acid"]}


def _swap(o, old, new):
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


def apply(settings, world, tech, recipes, buildings, quests=None):
    n = 0
    # 1. у штаба — по одной стартовой залежи
    world["start_one"] = 1
    old = {}
    for d in world.get("deposits", []):
        if "near_start" in d:
            old[d.get("item")] = d["near_start"]
            d["near_start"] = 1 if d.get("item") in START_ONE else 0
            n += 1
    # 2. залежи открываются узлами, которым нужны
    for tid, items in DEP118.items():
        u = tech[tid].setdefault("unlocks", {})
        dl = u.setdefault("deposits", [])
        for it in items:
            if it not in dl:
                dl.append(it)
    settings["dep118"] = {k: list(v) for k, v in DEP118.items()}
    settings["near118_old"] = old   # старые проверки (main._legacy_115) — с прежними залежами у штаба
    # 3. стоимости и требования без закрытого сырья
    tech["t_coal"]["cost"] = {"charcoal": 20, "iron_ingot": 40}
    tech["t_coal"]["desc"] = ("Открывает залежи угля на карте, угольный генератор и сталь. "
                              "Сталь варится в Плавильне (нужна энергия) из железных слитков и угля.")
    c = tech["t_metal"].get("cost", {})
    if "tin_ingot" in c:
        c.pop("tin_ingot")
        c["copper_ingot"] = int(c.get("copper_ingot", 0)) + 10
    REQ118["t_chem"] = ["t_coal"]
    for tid, more in REQ118.items():
        req = tech[tid].setdefault("requires", [])
        for q in more:
            if q not in req:
                req.append(q)
    # газовый баллон делает Упаковщик («Нефть») — рецепт открывает «Электроника» (после «Нефти»), а не «Геология II»
    g2 = tech["t_geo2"].get("unlocks", {}).get("recipes", [])
    if "d17_gas_canister" in g2:
        g2.remove("d17_gas_canister")
        tech["t_electro"].setdefault("unlocks", {}).setdefault("recipes", []).append("d17_gas_canister")
    # 4. ранние патроны и салют — на древесном угле; кустарные патроны умеет и Сборщик (лентой)
    for rid in ("ammo_crude", "firework"):
        r = recipes.get(rid)
        if r and "coal" in r.get("in", {}):
            r["in"]["charcoal"] = r["in"].pop("coal")
    if "ammo_crude" in recipes and "assembler" not in recipes["ammo_crude"]["stations"]:
        recipes["ammo_crude"]["stations"].append("assembler")
    # 5. обучение: шаг «Уголь» убран (угля у штаба теперь нет), топливо для печи — ветки, брёвна, древесный уголь
    tut = settings.get("tutorial", {})
    steps = tut.get("steps", []) if isinstance(tut, dict) else []
    tut["steps"] = [s for s in steps if not (s.get("goal") == "have" and s.get("item") == "coal")]
    _swap(settings.get("tutorial", {}), "руду и топливо (уголь, ветки или брёвна)", "руду и топливо (ветки, брёвна или древесный уголь)")
    _swap(settings.get("tutorial", {}), "положите топливо: уголь, брёвна или ветки", "положите топливо: брёвна, ветки или древесный уголь")
    if quests is not None:
        _swap(quests, "ветки, брёвна или уголь", "ветки, брёвна или древесный уголь")
    return n
