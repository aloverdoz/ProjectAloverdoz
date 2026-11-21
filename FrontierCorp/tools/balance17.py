# 17.10: баланс. Скорости лент и буров, энергия машин и станций, расход топлива,
# соотношения рецептов (вход → выход и время) — там, где у нас та же вещь.
# Вызывается из gen_core.py последним (после doc17). Всё правится в редакторе: «Здания» → «Параметры», «Рецепты».

# ленты: Mk1–Mk5 = 60 / 120 / 270 / 480 / 780 в минуту
BELTS = {"belt": 60, "belt_mk2": 120, "belt_mk3": 270, "belt_mk4": 480, "belt_mk5": 780}
# буры: Mk1 ×1, Mk2 ×2, Mk3 ×4 от качества залежи (бедная 30 / нормальная 60 / богатая 120 в минуту); Mk4–5 — наши
MINER_MULT = {"miner": 1, "miner_mk2": 2, "miner_mk3": 4, "miner_mk4": 6, "miner_mk5": 8}
# энергия, МВт: плавильня 4, конструктор 4, сборщик 15, литейная 16, производитель 55, нефтезавод 30, смеситель 75
POWER = {"miner": 5, "miner_mk2": 12, "miner_mk3": 30, "miner_mk4": 45, "miner_mk5": 60,
         "smelter": 4, "smelter_mk2": 10, "assembler": 15, "assembler_mk2": 38, "constructor": 4, "foundry": 16, "manufacturer": 55,
         "refinery": 30, "chem_plant": 75, "packager": 10, "water_pump": 20, "oil_pump": 40, "gas_extractor": 40,
         "coke_oven": 0, "crusher": 12, "mixer": 16, "arc_furnace": 40, "clean_room": 30, "blast_furnace": 75, "crystal_cutter": 100, "synthesizer": 250,
         "sawmill": 4, "stone_cutter": 4, "sink": 30}
# скорость машин: всё ×1, улучшенные Mk2 — ×2; каменная печь — вдвое медленнее плавильни
SPEED = {"furnace": 0.5, "smelter": 1.0, "smelter_mk2": 2.0, "assembler": 1.0, "assembler_mk2": 2.0}
# генераторы: мощность и сколько секунд горит одна единица топлива
GEN = {"biomass_burner": (30, None), "coal_generator": (75, 4.0), "fuel_generator": (250, 3.0)}

# рецепты: id → (вход, выход, время)
SF = {
    "iron_plate": ({"iron_ingot": 3}, {"iron_plate": 2}, 6.0),
    "wire": ({"copper_ingot": 1}, {"wire": 2}, 4.0),
    "iron_rod": ({"iron_ingot": 1}, {"iron_rod": 1}, 4.0),
    "screw": ({"iron_rod": 1}, {"screw": 4}, 6.0),
    "cable": ({"wire": 2}, {"cable": 1}, 2.0),
    "d17_concrete_mix": ({"limestone": 3}, {"concrete": 1}, 4.0),
    "concrete": ({"stone": 3}, {"concrete": 1}, 4.0),
    "reinforced_plate": ({"iron_plate": 6, "screw": 12}, {"reinforced_plate": 1}, 12.0),
    "modular_frame": ({"reinforced_plate": 3, "iron_rod": 12}, {"modular_frame": 2}, 60.0),
    "rotor": ({"iron_rod": 5, "screw": 25}, {"rotor": 1}, 15.0),
    "stator": ({"steel_pipe": 3, "wire": 8}, {"stator": 1}, 12.0),
    "d17_motor": ({"rotor": 2, "stator": 2}, {"motor": 1}, 12.0),
    "d17_steel_coke": ({"iron_ore": 3, "coal": 3}, {"steel": 3}, 4.0),
    "steel_beam": ({"steel": 4}, {"steel_beam": 1}, 4.0),
    "steel_pipe": ({"steel": 3}, {"steel_pipe": 2}, 6.0),
    "heavy_frame": ({"modular_frame": 5, "steel_pipe": 15, "steel_beam": 5, "screw": 100}, {"heavy_frame": 1}, 30.0),
    "pcb": ({"copper_ingot": 4, "plastic": 4, "silicon": 1}, {"pcb": 1}, 8.0),
    "computer": ({"pcb": 10, "cable": 9, "plastic": 18}, {"computer": 1}, 24.0),
    "refine_plastic": ({"oil": 3}, {"plastic": 2}, 6.0),
    "refine_rubber": ({"oil": 3}, {"rubber": 2}, 6.0),
    "refine_fuel": ({"oil": 6}, {"fuel": 4}, 6.0),
    "smelt_iron": ({"iron_ore": 1}, {"iron_ingot": 1}, 2.0),
    "smelt_copper": ({"copper_ore": 1}, {"copper_ingot": 1}, 2.0),
    "tin_ingot": ({"tin_ore": 1}, {"tin_ingot": 1}, 2.0),
    "smelt_glass": ({"quartz": 5}, {"glass": 3}, 8.0),
    "d17_glass_sand": ({"sand": 3, "limestone": 1}, {"glass": 2}, 6.0),
    "silicon": ({"quartz": 3, "coal": 2}, {"silicon": 2}, 8.0),
    "sulfuric_acid": ({"sulfur": 5, "water": 5}, {"sulfuric_acid": 5}, 6.0),
    "d17_battery": ({"lead_ingot": 2, "sulfuric_acid": 3, "plastic": 1}, {"battery": 1}, 6.0),
    "gunpowder": ({"sulfur": 1, "saltpeter": 2, "coal": 1}, {"gunpowder": 2}, 4.0),
    "d17_alumina": ({"bauxite": 12, "water": 18}, {"alumina": 12}, 6.0),
    "d17_aluminum": ({"alumina": 4, "coal": 1}, {"aluminum_ingot": 2}, 4.0),
    "aluminum_sheet": ({"aluminum_ingot": 3}, {"aluminum_sheet": 3}, 4.0),
    "turbine": ({"titanium_ingot": 4, "bearing": 4, "rotor": 2}, {"turbine": 1}, 32.0),
    "heat_exchanger": ({"stainless_steel": 3, "copper_ingot": 5, "steel_pipe": 4}, {"heat_exchanger": 1}, 16.0),
    "ai_module": ({"computer": 1, "circuit": 4}, {"ai_module": 1}, 24.0),
    "coke": ({"coal": 2}, {"coke": 1}, 4.0),
    "quicklime": ({"limestone": 3}, {"quicklime": 1}, 4.0),
}
# старые «упрощённые» рецепты остаются (начало игры), но становятся честнее по сырью
SIMPLER = {
    "motor": ({"gear": 10, "wire": 16, "steel": 8}, {"motor": 1}, 15.0),
    "gear": ({"iron_ingot": 2}, {"gear": 1}, 4.0),
    "circuit": ({"wire": 6, "iron_plate": 2, "glass": 1}, {"circuit": 1}, 8.0),
    "circuit_plastic": ({"wire": 4, "plastic": 2}, {"circuit": 1}, 8.0),
    "battery": ({"sulfur": 3, "copper_ingot": 3, "iron_plate": 2}, {"battery": 1}, 8.0),
    "steel": ({"iron_ingot": 2, "coal": 2}, {"steel": 1}, 4.0),
}


def apply(buildings, recipes, items, settings):
    for bid, pm in BELTS.items():
        if bid in buildings:
            buildings[bid]["params"]["per_min"] = pm
            buildings[bid]["desc"] = {"belt": "Везёт 60 предметов в минуту.", "belt_mk2": "120 предметов в минуту.", "belt_mk3": "270 предметов в минуту.",
                                      "belt_mk4": "480 предметов в минуту.", "belt_mk5": "780 предметов в минуту."}[bid] + \
                " Тяни мышью, чтобы проложить линию; ставится поверх старой ленты."
    for bid, k in MINER_MULT.items():
        if bid in buildings:
            buildings[bid]["params"]["rate_mult"] = float(k)
            buildings[bid]["desc"] = "Ставится на месторождение. Выдаёт %d / %d / %d / %d руды в минуту (бедная / нормальная / богатая / легендарная). Нужна энергия." % (30 * k, 60 * k, 120 * k, 240 * k)
    for bid, pw in POWER.items():
        if bid in buildings and pw is not None:
            buildings[bid]["params"]["power"] = pw
    for bid, sp in SPEED.items():
        if bid in buildings:
            buildings[bid]["params"]["speed"] = sp
    for bid, (pw, sec) in GEN.items():
        if bid not in buildings:
            continue
        p = buildings[bid]["params"]
        p["power"] = pw
        fuels = p.get("fuels", [])
        if sec and fuels:
            base = float(items.get(fuels[0], {}).get("fuel", 30)) or 30.0
            p["burn_mult"] = round(sec / base, 4)
    if "biomass_burner" in buildings:
        buildings["biomass_burner"]["params"]["burn_mult"] = 0.28   # бревно ≈ 3.4 с при 30 МВт
    if "coal_generator" in buildings:
        buildings["coal_generator"]["desc"] = "Жжёт уголь (15 в минуту) и даёт 75 энергии. Уголь подаётся лентой; одного нормального бура хватает на 4 генератора."
    if "fuel_generator" in buildings:
        buildings["fuel_generator"]["desc"] = "Жжёт топливо или природный газ из труб (или канистры с ленты) и даёт 250 энергии."
    for rid, (i, o, t) in list(SF.items()) + list(SIMPLER.items()):
        if rid in recipes:
            recipes[rid]["in"] = dict(i)
            recipes[rid]["out"] = dict(o)
            recipes[rid]["time"] = t
    # цены: пересчитать производные по сырью, чтобы утилизатор и торговля не давали «вечный двигатель»
    _reprice(items, recipes)
    settings.setdefault("balance", {})["source"] = "Базовый баланс: ленты 60/120/270/480/780, буры ×1/×2/×4, рецепты и МВт по базовой таблице"


def _reprice(items, recipes):
    """Цена предмета ≥ цены сырья по самому дешёвому рецепту × 1.1 (+ немного за время), чтобы переработка всегда была выгодна,
    но продажа сырья через цепочку не давала больше, чем сырьё стоит само по себе на каждом шаге."""
    for _ in range(8):
        best = {}
        for rid, r in recipes.items():
            outs = {k: v for k, v in r.get("out", {}).items() if not (k in items and items[k].get("fluid"))}
            # A-4 r9: побочная жидкость (вода и т.п.) не мешает учесть рецепт — иначе цену задавал дорогой «узорный» рецепт
            if len(outs) != 1 or rid.startswith(("shop_", "unpack_", "recycle_")):
                continue
            (oid, n), = outs.items()
            if oid not in items or items[oid].get("exotic") or oid == "sink_coupon":
                continue
            cost = 0.0
            ok = True
            for k, v in r.get("in", {}).items():
                if k not in items or k == "sink_coupon":
                    ok = False
                    break
                cost += float(items[k].get("price", 1)) * v
            if not ok or cost <= 0:
                continue
            want = int(round(cost / max(1, n) * 1.1 + r.get("time", 1.0) * 0.2))
            best[oid] = min(best.get(oid, 10 ** 9), want)
        changed = False
        for oid, want in best.items():
            if int(items[oid].get("price", 1)) < want:
                items[oid]["price"] = want
                changed = True
        if not changed:
            break
