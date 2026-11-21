# 17.10 (вечер): то, что осталось из документа_идеи, — в основной игре.
#  • Магма: выходы магмы на дальних кольцах (видны после «Геология III»). Геотермальная станция ставится только на них,
#    магматический отвод качает магму по трубам в доменную печь (вольфрам вдвое выгоднее). Рядом с магмой жарко — нужен жаростойкий костюм.
#  • Жаростойкий костюм, еда, вода, медицина и расходники для базы.
#  • АЭС: 2500 МВт, один ТВЭЛ на 5 минут работы, ТВЭЛ — долгий дорогой рецепт.
# Вызывается из gen_core.py после flora17. Всё правится в редакторе: «Предметы», «Рецепты», «Здания», «Дерево открытий»,
# «Мир» → «Месторождения», «Настройки» → «Реактор».
import sys
gc = sys.modules["__main__"]
P, M = gc.P, gc.M


def _price(items, inp, n=1, t=3.0):
    c = sum(float(items.get(k, {}).get("price", 1)) * v for k, v in inp.items())
    return max(1, int(round(c / max(1, n) * 1.1 + t * 0.2)))


def _rec(recipes, rid, name, inp, out, t, st):
    recipes[rid] = {"name": name, "in": dict(inp), "out": dict(out), "time": float(t), "stations": list(st)}


def _item(items, iid, name, desc, col, cat, model, stack, inp=None, n=1, t=3.0, **kw):
    d = {"name": name, "desc": desc, "color": col, "category": cat, "stack": stack, "model": model, "scan": 0,
         "price": _price(items, inp or {}, n, t) if inp else int(kw.pop("price", 5))}
    kw.pop("price", None)
    d.update(kw)
    items[iid] = d


WB = ["hand", "workbench"]
WBO = ["workbench"]


def apply(models, buildings, items, recipes, settings, world, tech):
    _magma(models, buildings, items, recipes, settings, world, tech)
    _gear(items, recipes, tech)
    _nuclear(buildings, items, recipes, settings)
    _steam(buildings, tech, settings)


# ------------------------------------------------------------------ магма
def _magma(models, buildings, items, recipes, settings, world, tech):
    items["magma"] = {"name": "Магма", "desc": "Расплав из выходов магмы. Качает магматический отвод; греет доменную печь (вольфрам вдвое выгоднее).",
                      "color": "#ff5a1f", "category": "Жидкости", "stack": 100, "price": 6, "model": "drop_fluid", "fluid": True, "scan": 0}
    models["dep_magma"] = M("Выход магмы", [
        P("cylinder", (2.6, 0.18, 2.6), (0, 0.09, 0), "#2a1d1a", "stone", seg=10, top=0.8),
        P("cylinder", (1.7, 0.08, 1.7), (0, 0.17, 0), "#ff5a1f", "glow", anim="pulse", seg=10),
        P("sphere", (0.9, 0.5, 0.8), (0.9, 0.2, 0.6), "#3a2620", "stone", seg=6),
        P("sphere", (0.7, 0.4, 0.8), (-0.9, 0.18, -0.5), "#3a2620", "stone", seg=6),
        P("sphere", (0.5, 0.18, 0.5), (0.2, 0.22, -0.2), "#ffb23a", "glow", anim="pulse", seg=6),
        P("sphere", (0.35, 0.12, 0.35), (-0.4, 0.21, 0.3), "#ff7a2a", "glow", anim="pulse", seg=6),
    ], "Месторождения")
    if not any(d.get("item") == "magma" for d in world.get("deposits", [])):
        world.setdefault("deposits", []).append({
            "resource": "", "item": "magma", "color": "#ff4a10", "patches": 10, "size_min": 2.0, "size_max": 3.0, "near_start": 0,
            "drops": [], "cells": 2, "hand": False, "hand_hp": 25.0, "hand_tool": "pickaxe", "rocks_around": 2, "marker": "dep_magma", "min_dist": 70})
    # жар выходов магмы (поверх погоды): «Настройки» → «Климат» → magma_heat / magma_radius
    cl = settings.get("climate")
    if isinstance(cl, dict):
        cl.setdefault("magma_heat", 55.0)
        cl.setdefault("magma_radius", 4.0)
    models["magma_tap"] = M("Магматический отвод", [
        P("box", (3.6, 0.35, 3.6), (0, 0.17, 0), "#2f2a2a", "concrete"),
        P("cylinder", (1.6, 1.4, 1.6), (0, 1.0, 0), "#5a4a44", "metal", seg=12),
        P("cylinder", (1.75, 0.16, 1.75), (0, 1.75, 0), "#2a2226", "dark", seg=12),
        P("cylinder", (0.9, 0.08, 0.9), (0, 1.84, 0), "#ff6a20", "glow", anim="pulse", seg=12),
        P("cylinder", (0.32, 2.4, 0.32), (1.1, 1.6, 1.1), "#7a6a62", "metal", seg=8),
        P("cylinder", (0.32, 2.4, 0.32), (-1.1, 1.6, -1.1), "#7a6a62", "metal", seg=8),
        P("box", (2.6, 0.22, 0.3), (0, 2.8, 0), "#3a3236", "dark", rot=(0, 45, 0)),
        P("cylinder", (0.45, 0.7, 0.45), (1.3, 0.55, -1.2), "#c0482a", "paint", seg=8),
        P("box", (0.5, 0.12, 0.12), (1.3, 0.95, -0.95), "#ffb23a", "glow", anim="pulse"),
        P("cylinder", (0.22, 0.8, 0.22), (0, 2.3, 0), "#ff8a3a", "glow", anim="spin", seg=6),
    ], "Энергия")
    buildings["magma_tap"] = {"name": "Магматический отвод", "desc": "Ставится на выход магмы (оранжевое пятно, видно после «Геология III») и качает 60 магмы в минуту в трубы. Магма по трубам — в доменную печь.",
                              "category": "fluids", "behavior": "miner", "cost": {"heatproof_block": 8, "steel_pipe": 10, "motor": 2}, "model": "magma_tap", "hp": 700, "size": 2,
                              "params": {"period": 1.0, "power": 30, "any_ground": True, "extracts": "fluid", "pipes": True, "tier": 1}, "sounds": {"work": "work_pump"}}
    if "geothermal" in buildings:
        g = buildings["geothermal"]
        g["desc"] = "Ставится только на выход магмы (оранжевое пятно, видно после «Геология III»). Даёт 200 энергии без топлива."
        g["params"].update({"power": 200, "on_deposit": "magma", "any_ground": True})
        g["size"] = 2
    if "blast_furnace" in buildings:
        buildings["blast_furnace"]["params"]["pipes"] = True
        buildings["blast_furnace"]["desc"] = "Вольфрам из руды и кокса. С магмой по трубам (магматический отвод) — вдвое выгоднее и без кокса. Нужна энергия и топливо."
    _rec(recipes, "m17_tungsten_magma", "Вольфрам на магме", {"tungsten_ore": 2, "magma": 6}, {"tungsten_ingot": 2}, 6.0, ["blast_furnace"])
    _rec(recipes, "m17_obsidian_magma", "Обсидиан из магмы", {"magma": 10, "water": 10}, {"obsidian": 2}, 8.0, ["blast_furnace"])
    # жаростойкий костюм
    _item(items, "heat_suit", "Жаростойкий костюм", "Носится как одежда: −70° жары. Без него у выходов магмы герой перегревается.", "#e0703a",
          "Одежда", "drop_suit", 1, {"obsidian_plate": 4, "cloth": 6, "coolant": 2}, clothes="body", cooling=70, warmth=0)
    _rec(recipes, "heat_suit", "Жаростойкий костюм", {"obsidian_plate": 4, "cloth": 6, "coolant": 2}, {"heat_suit": 1}, 8.0, WBO)
    t = tech.get("t_geo3")
    if t:
        u = t.setdefault("unlocks", {})
        if "magma" not in u.setdefault("deposits", []):
            u["deposits"].append("magma")
        for b in ("magma_tap",):
            if b not in u.setdefault("buildings", []):
                u["buildings"].append(b)
        for r in ("m17_tungsten_magma", "m17_obsidian_magma", "heat_suit"):
            if r not in u.setdefault("recipes", []):
                u["recipes"].append(r)
        t["desc"] = "Магматический пояс: вольфрам, титан, обсидиан и выходы магмы проявляются. Геотермальная станция и магматический отвод — только на выходах магмы. Доменная печь, жаростойкий костюм."


# ------------------------------------------------------------------ еда, вода, медицина, расходники
CONS = [
    # id, название, описание, цвет, модель, поля, вход, n, время, станции, технология
    ("boiled_water", "Кипячёная вода", "Безопасная вода: +50 воды.", "#7ac8ff", "drop_flask", {"water": 50}, {"water_flask": 1, "branch": 1}, 1, 3.0, ["kitchen", "furnace", "workbench"], ""),
    ("filtered_water", "Фильтрованная вода", "Чистая вода: +80 воды и немного здоровья.", "#5ae0ff", "drop_flask", {"water": 80, "heal": 5}, {"water_flask": 2, "charcoal": 1}, 2, 4.0, WBO, ""),
    ("stimulant", "Стимулятор", "На 60 секунд бег на 25% быстрее.", "#ffd23f", "drop_flask", {"boost": {"stat": "move", "value": 0.25, "time": 60}}, {"berry": 4, "mushroom": 1}, 1, 4.0, WBO, ""),
    ("painkiller", "Обезболивающее", "На 60 секунд урон по герою −20%.", "#f2f2ee", "drop_box", {"boost": {"stat": "armor", "value": 0.2, "time": 60}, "heal": 10}, {"mushroom": 2, "bandage": 1}, 1, 4.0, WBO, ""),
    ("antirad", "Антирад", "Снимает 50% накопленной дозы облучения.", "#7dff5a", "drop_flask", {"rad_cure": 50}, {"lead_ingot": 1, "salt": 2, "glass": 1}, 1, 5.0, WBO, "t_electro"),
    ("splint", "Шина", "Быстрая починка героя после падения или удара: +40 здоровья, 30 секунд регенерация вдвое быстрее.", "#d9c28c", "drop_box", {"heal": 40, "boost": {"stat": "regen", "value": 1.0, "time": 30}}, {"plank": 2, "cloth": 2}, 1, 3.0, WB, ""),
    ("repair_patch", "Заплатка", "Чинит ближайшее здание на 300 прочности (ПКМ рядом со зданием).", "#c0c6cf", "drop_box", {"repair_near": 300}, {"iron_plate": 2, "screw": 4}, 2, 3.0, WBO, ""),
    ("fuel_briquette", "Топливный брикет", "Прессованная щепа и уголь: горит долго (как 3 угля).", "#5a4632", "drop_box", {"fuel": 90}, {"log": 2, "coal": 1}, 2, 4.0, WBO, ""),
    ("grilled_mushrooms", "Жареные грибы", "+30 сытости, +10 здоровья.", "#a8622a", "drop_meat", {"food": 30, "heal": 10, "spoil": 1800}, {"mushroom": 3}, 1, 3.0, ["kitchen", "furnace"], ""),
    ("salted_meat", "Солонина", "Не портится: +40 сытости.", "#b04a3a", "drop_meat", {"food": 40, "heal": 5}, {"raw_meat": 2, "salt": 1}, 2, 4.0, WBO, "t_geo2"),
]


def _gear(items, recipes, tech):
    for iid, name, desc, col, model, fields, inp, n, t, st, tn in CONS:
        if not all(x in items for x in inp):
            inp = {k: v for k, v in inp.items() if k in items}
            if not inp:
                continue
        _item(items, iid, name, desc, col, "Еда" if ("food" in fields or "water" in fields) else "Снаряжение", model, 20, inp, n, t, **fields)
        _rec(recipes, iid, name, inp, {iid: n}, t, st)
        if tn and tn in tech:
            r = tech[tn].setdefault("unlocks", {}).setdefault("recipes", [])
            if iid not in r:
                r.append(iid)


# ------------------------------------------------------------------ АЭС
def _nuclear(buildings, items, recipes, settings):
    # 2500 МВт, 0.2 ТВЭЛа в минуту (5 минут на стержень), 240 воды в минуту, отходы — 10 на ТВЭЛ.
    # У нас: 4 ТВЭЛа в зоне дают тепло на 2500, каждый горит 20 минут → один стержень на 5 минут работы.
    if "nuclear_reactor" in buildings:
        b = buildings["nuclear_reactor"]
        b["params"]["power"] = 2500
        b["desc"] = "До 2500 энергии. 4 ТВЭЛа в зоне: при полной мощности уходит один ТВЭЛ за 5 минут. Нужна вода по трубам (охлаждение). В окне: стержни управления, загрузка ТВЭЛов, насосы, АЗ-5. Перегрев — авария."
    r = settings.get("reactor")
    if isinstance(r, dict):
        r.update({"heat_per_rod": 650.0, "max_flow": 9.0, "rod_life": 1200.0, "cool_full_at": 250.0})  # 4 ТВЭЛа: стержни наполовину ≈1.2 МВт при ~135°, подняты ≈2.5 МВт при ~250°
    if "fuel_rod" in items:
        items["fuel_rod"]["fuel"] = 1200
        items["fuel_rod"]["desc"] = "Топливо АЭС. В зоне горит 20 минут (4 стержня — один в 5 минут на полной мощности)."
    # цепочка: руда + кислота → кек → обогащённый уран (+бетон как оболочка) → ТВЭЛ за 150 секунд
    if "yellowcake" in recipes:
        recipes["yellowcake"].update({"in": {"uranium_ore": 10, "sulfuric_acid": 8}, "out": {"yellowcake": 5}, "time": 12.0})
    if "enriched_uranium" in recipes:
        recipes["enriched_uranium"].update({"in": {"yellowcake": 2, "concrete": 1}, "out": {"enriched_uranium": 2}, "time": 6.0})
    if "fuel_rod" in recipes:
        recipes["fuel_rod"].update({"in": {"enriched_uranium": 50, "steel_beam": 3, "circuit": 5}, "out": {"fuel_rod": 1}, "time": 150.0})
    if "d17_fuel_rod" in recipes:
        recipes["d17_fuel_rod"].update({"in": {"enriched_uranium": 50, "stainless_steel": 6}, "out": {"fuel_rod": 1}, "time": 150.0})
    if "recycle_waste" in recipes:
        recipes["recycle_waste"].update({"in": {"nuclear_waste": 1, "sulfuric_acid": 10}, "out": {"enriched_uranium": 10}, "time": 30.0})


# ------------------------------------------------------------------ вода для угольных генераторов, мастерство, рекорды
def _steam(buildings, tech, settings):
    if "coal_generator" in buildings:
        g = buildings["coal_generator"]
        g["params"].update({"pipes": True, "water_per_min": 30})
        g["desc"] = ("Жжёт уголь (15 в минуту) и пьёт воду (30 в минуту по трубе от водяного насоса), даёт 75 энергии. "
                     "Без воды стоит. Один насос поит два генератора.")
    # насос и трубы открываются вместе с угольным генератором
    for tid, t in tech.items():
        u = t.get("unlocks", {})
        if tid != "t_coal":
            for x in ("water_pump", "pipe"):
                if x in u.get("buildings", []):
                    u["buildings"].remove(x)
    if "t_coal" in tech:
        ub = tech["t_coal"].setdefault("unlocks", {}).setdefault("buildings", [])
        for x in ("water_pump", "pipe"):
            if x not in ub:
                ub.append(x)
        tech["t_coal"]["desc"] = "Угольный генератор, водяной насос и трубы: генератор пьёт воду — без неё не работает."
    settings.setdefault("mastery", {"enabled": True, "steps": [200, 1000, 5000], "bonus": 0.05, "chain_bonus": 0.1, "chain_max": 2})
    settings.setdefault("milestones", {"enabled": True, "steps": [100, 1000, 10000], "credit_k": 0.15, "coupon_k": 0.002})
    settings.setdefault("daily", {"enabled": True, "speed_bonus": 0.25, "value": 3000, "credit_k": 0.5})
