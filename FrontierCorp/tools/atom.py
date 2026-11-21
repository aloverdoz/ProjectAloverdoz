# 14.22 «Атомный патч»: новые ресурсы, которые открываются по мере развития, химия, алюминий, уран и АЭС,
# опасности (серная кислота, радиация), заражение местности и его очистка.
# Вызывается из gen_core.py после rework.*. Всё, что здесь задано, правится в редакторе.
import math
import copy
from rework import _p, _shade, marker_model

DK, MID, LT, ACC, STEEL, CONC = "#262a31", "#5d6672", "#c9d0d8", "#f2a12e", "#9aa3ad", "#8a8d90"
ACID, RAD, ALU, NIT = "#c8e04a", "#5aff7a", "#d0d8e0", "#e8e4d8"


# ---------------------------------------------------------------- модели зданий

def m_chem_plant():
    """Химзавод 2×2: реакторные колонны, баки с кислотой, трубы, жёлтые полосы опасности."""
    p = [_p("box", (3.8, 0.35, 3.8), (0, 0.18, 0), CONC, "concrete", bevel=0.06),
         _p("box", (3.82, 0.08, 0.2), (0, 0.38, 1.82), ACC, "paint"), _p("box", (3.82, 0.08, 0.2), (0, 0.38, -1.82), ACC, "paint"),
         _p("box", (1.6, 1.6, 1.4), (-0.9, 1.15, -0.8), MID, bevel=0.08),
         _p("box", (1.62, 0.12, 1.42), (-0.9, 1.9, -0.8), ACC, "paint"),
         _p("box", (0.9, 0.5, 0.04), (-0.9, 1.25, -0.08), "#1b2d3a", "glass"),
         _p("box", (0.7, 0.08, 0.05), (-0.9, 1.6, -0.08), "#4de1ff", "glow", anim="pulse", tint=False)]
    for i, (x, z) in enumerate(((0.9, -0.9), (0.9, 0.2), (1.35, 1.2))):
        h = 2.6 - i * 0.4
        p += [_p("cylinder", (0.8, h, 0.8), (x, 0.35 + h / 2, z), LT, seg=14),
              _p("cylinder", (0.84, 0.1, 0.84), (x, 0.35 + h * 0.7, z), ACC, "paint", seg=14),
              _p("sphere", (0.8, 0.4, 0.8), (x, 0.35 + h, z), STEEL, seg=12),
              _p("cylinder", (0.12, 0.5, 0.12), (x, 0.6 + h, z), DK, seg=8)]
    # стеклянные колбы с кислотой
    for i in range(3):
        x = -1.4 + i * 0.55
        p += [_p("cylinder", (0.4, 0.9, 0.4), (x, 0.82, 1.15), "#a8e8ff", "glass", seg=10),
              _p("cylinder", (0.34, 0.55, 0.34), (x, 0.68, 1.15), ACID, "glow", anim="pulse", tint=False, seg=10),
              _p("cylinder", (0.44, 0.08, 0.44), (x, 1.3, 1.15), DK, seg=10)]
    # трубы
    p += [_p("cylinder", (0.16, 2.4, 0.16), (0.1, 2.0, -0.35), STEEL, rot=(0, 0, 90), seg=8),
          _p("cylinder", (0.16, 1.6, 0.16), (0.9, 2.0, 0.3), STEEL, rot=(90, 0, 0), seg=8),
          _p("cylinder", (0.12, 1.2, 0.12), (-0.2, 1.3, 1.15), STEEL, rot=(0, 0, 90), seg=8),
          _p("box", (0.5, 0.5, 0.06), (-0.9, 1.0, 0.0), "#ffd000", "paint"),
          _p("prism", (0.3, 0.3, 0.04), (-0.9, 1.0, 0.035), DK, "dark")]
    return {"name": "Химзавод", "category": "Производство", "parts": p}


def m_centrifuge():
    p = [_p("cylinder", (1.8, 0.3, 1.8), (0, 0.15, 0), CONC, "concrete", seg=16),
         _p("cylinder", (1.3, 1.6, 1.3), (0, 1.1, 0), LT, seg=20, top=0.9),
         _p("cylinder", (1.34, 0.1, 1.34), (0, 0.6, 0), "#2f8f4a", "paint", seg=20),
         _p("cylinder", (1.34, 0.1, 1.34), (0, 1.6, 0), "#2f8f4a", "paint", seg=20),
         _p("cylinder", (0.9, 0.3, 0.9), (0, 2.05, 0), MID, seg=16, anim="spin"),
         _p("box", (0.9, 0.06, 0.12), (0, 2.22, 0), ACC, "paint", anim="spin"),
         _p("sphere", (0.22, 0.22, 0.22), (0, 2.35, 0), RAD, "glow", anim="pulse", tint=False)]
    for k in range(6):
        a = k / 6 * math.tau
        p.append(_p("box", (0.06, 1.4, 0.06), (math.cos(a) * 0.68, 1.1, math.sin(a) * 0.68), DK))
    p += [_p("box", (0.4, 0.3, 0.05), (0, 1.1, 0.66), "#1b2d3a", "glass"),
          _p("box", (0.3, 0.06, 0.05), (0, 1.15, 0.69), RAD, "glow", anim="blink", tint=False)]
    return {"name": "Центрифуга", "category": "Производство", "parts": p}


def m_reactor():
    """АЭС 3×3: купол реактора, две градирни с паром, машинный зал, знак радиации, сигнальные огни."""
    p = [_p("box", (5.8, 0.4, 5.8), (0, 0.2, 0), CONC, "concrete", bevel=0.08),
         _p("box", (5.82, 0.1, 0.25), (0, 0.45, 2.78), ACC, "paint"), _p("box", (5.82, 0.1, 0.25), (0, 0.45, -2.78), ACC, "paint"),
         # купол
         _p("cylinder", (2.6, 2.0, 2.6), (-0.9, 1.4, -0.6), "#d8dbe0", "concrete", seg=24),
         _p("sphere", (2.6, 2.0, 2.6), (-0.9, 2.4, -0.6), "#e2e5ea", "concrete", seg=20),
         _p("cylinder", (2.64, 0.14, 2.64), (-0.9, 1.0, -0.6), "#c0392b", "paint", seg=24),
         _p("cylinder", (0.5, 0.3, 0.5), (-0.9, 3.45, -0.6), MID, seg=12),
         _p("sphere", (0.2, 0.2, 0.2), (-0.9, 3.7, -0.6), "#ff3a2a", "glow", anim="blink", tint=False),
         # знак радиации на куполе
         _p("cylinder", (0.9, 0.04, 0.9), (-0.9, 1.6, 0.72), "#ffd000", "paint", rot=(90, 0, 0), seg=16),
         _p("cylinder", (0.18, 0.05, 0.18), (-0.9, 1.6, 0.75), DK, "dark", rot=(90, 0, 0), seg=10)]
    for k in range(3):
        a = k / 3 * math.tau + math.pi / 2
        p.append(_p("prism", (0.28, 0.3, 0.05), (-0.9 + math.cos(a) * 0.25, 1.6 + math.sin(a) * 0.25, 0.75), DK, "dark", rot=(0, 0, math.degrees(a) + 90)))
    # градирни
    for x, z in ((1.6, -1.6), (1.9, 0.6)):
        p += [_p("cylinder", (1.5, 2.8, 1.5), (x, 1.8, z), "#c9ccd1", "concrete", seg=20, top=0.72),
              _p("cylinder", (1.12, 0.9, 1.12), (x, 3.6, z), "#c9ccd1", "concrete", seg=20, top=1.15),
              _p("cylinder", (1.3, 0.12, 1.3), (x, 4.08, z), "#9e9c91", "concrete", seg=20),
              _p("sphere", (1.3, 0.8, 1.3), (x, 4.5, z), "#f2f4f7", "glass", anim="pulse", tint=False, seg=12),
              _p("cylinder", (1.52, 0.1, 1.52), (x, 0.9, z), "#c0392b", "paint", seg=20)]
    # машинный зал и трубы
    p += [_p("box", (2.2, 1.4, 1.4), (-0.4, 1.1, 2.0), MID, bevel=0.08),
          _p("box", (2.22, 0.12, 1.42), (-0.4, 1.82, 2.0), ACC, "paint"),
          _p("box", (1.6, 0.4, 0.04), (-0.4, 1.2, 2.71), "#1b2d3a", "glass"),
          _p("box", (1.4, 0.08, 0.05), (-0.4, 1.5, 2.72), "#4de1ff", "glow", anim="pulse", tint=False),
          _p("cylinder", (0.3, 3.0, 0.3), (0.4, 1.9, -1.0), STEEL, rot=(0, 0, 90), seg=10),
          _p("cylinder", (0.3, 2.0, 0.3), (0.9, 1.3, 1.0), STEEL, rot=(90, 0, 0), seg=10),
          _p("cylinder", (0.22, 1.4, 0.22), (-2.4, 1.0, 1.6), "#3a8fe0", "paint", seg=8),
          _p("cylinder", (0.22, 1.4, 0.22), (-2.4, 1.0, -2.2), "#3a8fe0", "paint", seg=8)]
    for k in range(6):
        p.append(_p("sphere", (0.12, 0.12, 0.12), (-2.7 + k * 1.08, 0.55, 2.9), "#ff8c1a", "glow", anim="blink", tint=False))
    return {"name": "АЭС", "category": "Энергия", "parts": p}


def m_waste_storage():
    p = [_p("box", (1.8, 0.3, 1.8), (0, 0.15, 0), CONC, "concrete", bevel=0.05),
         _p("box", (1.5, 1.2, 1.5), (0, 0.9, 0), "#4a4f45", "metal", bevel=0.1),
         _p("box", (1.52, 0.12, 1.52), (0, 1.3, 0), "#ffd000", "paint"),
         _p("box", (1.52, 0.12, 1.52), (0, 0.6, 0), "#ffd000", "paint"),
         _p("cylinder", (0.7, 0.04, 0.7), (0, 0.95, 0.77), "#ffd000", "paint", rot=(90, 0, 0), seg=14),
         _p("cylinder", (0.14, 0.05, 0.14), (0, 0.95, 0.8), DK, "dark", rot=(90, 0, 0), seg=10),
         _p("box", (1.2, 0.2, 1.2), (0, 1.6, 0), MID, bevel=0.05),
         _p("box", (0.3, 0.1, 0.3), (0, 1.75, 0), RAD, "glow", anim="pulse", tint=False)]
    return {"name": "Хранилище отходов", "category": "Хранение", "parts": p}


def m_decon_station():
    p = [_p("box", (1.8, 0.3, 1.8), (0, 0.15, 0), CONC, "concrete", bevel=0.05),
         _p("cylinder", (1.0, 1.2, 1.0), (0, 0.9, 0), "#3a8fe0", "paint", seg=16),
         _p("cylinder", (1.04, 0.1, 1.04), (0, 1.2, 0), LT, seg=16),
         _p("cylinder", (0.16, 1.4, 0.16), (0, 2.2, 0), STEEL, seg=8),
         _p("cylinder", (1.2, 0.08, 1.2), (0, 2.9, 0), MID, seg=16, anim="spin")]
    for k in range(6):
        a = k / 6 * math.tau
        p += [_p("cylinder", (0.06, 0.5, 0.06), (math.cos(a) * 0.55, 2.7, math.sin(a) * 0.55), STEEL, rot=(math.degrees(math.sin(a)) * 0.5, 0, -math.degrees(math.cos(a)) * 0.5), anim="spin"),
              _p("sphere", (0.12, 0.12, 0.12), (math.cos(a) * 0.62, 2.45, math.sin(a) * 0.62), "#6ad0ff", "glow", anim="pulse", tint=False)]
    return {"name": "Станция дезактивации", "category": "Особые", "parts": p}


def m_fuel_rod():
    return {"name": "ТВЭЛ", "category": "Предметы", "parts": [
        _p("cylinder", (0.16, 0.9, 0.16), (0, 0.45, 0), ALU, seg=10),
        _p("cylinder", (0.12, 0.7, 0.12), (0, 0.45, 0), RAD, "glow", anim="pulse", tint=False, seg=10),
        _p("cylinder", (0.2, 0.08, 0.2), (0, 0.04, 0), DK, seg=10), _p("cylinder", (0.2, 0.08, 0.2), (0, 0.86, 0), DK, seg=10)]}


def m_hazmat():
    return {"name": "Защитный костюм", "category": "Одежда", "parts": [
        _p("box", (0.5, 0.6, 0.28), (0, 0.6, 0), "#ffd000", "cloth", bevel=0.08),
        _p("sphere", (0.36, 0.36, 0.36), (0, 1.08, 0), "#ffd000", "cloth"),
        _p("box", (0.26, 0.14, 0.05), (0, 1.1, 0.16), "#1b2d3a", "glass"),
        _p("cylinder", (0.1, 0.12, 0.1), (0, 0.98, 0.17), DK, rot=(90, 0, 0)),
        _p("box", (0.14, 0.5, 0.14), (-0.33, 0.6, 0), "#ffd000", "cloth"), _p("box", (0.14, 0.5, 0.14), (0.33, 0.6, 0), "#ffd000", "cloth"),
        _p("box", (0.16, 0.36, 0.18), (0, 0.65, -0.22), MID)]}


def m_spray():
    return {"name": "Дезактивационный баллон", "category": "Предметы", "parts": [
        _p("cylinder", (0.22, 0.6, 0.22), (0, 0.3, 0), "#3a8fe0", "paint", seg=10),
        _p("cylinder", (0.24, 0.06, 0.24), (0, 0.4, 0), LT, seg=10),
        _p("cylinder", (0.06, 0.18, 0.06), (0, 0.68, 0), DK, seg=8),
        _p("box", (0.2, 0.05, 0.05), (0.08, 0.76, 0), DK)]}


def recolor(model, col, mats=("paint",)):
    m = copy.deepcopy(model)
    for p in m.get("parts", []):
        if p.get("mat") in mats:
            p["color"] = col
    return m


# ---------------------------------------------------------------- данные

def apply_atom(models, buildings, items, recipes, settings, world, tech):
    def I(id, name, desc, color, cat, model, stack=50, price=4, **kw):
        d = {"name": name, "desc": desc, "color": color, "category": cat, "stack": stack, "price": price, "model": model, "scan": kw.pop("scan", 3)}
        d.update(kw)
        items[id] = d

    def R(id, name, ins, out, time, stations):
        recipes[id] = {"name": name, "in": ins, "out": out, "time": time, "stations": stations}

    def B(id, name, desc, cat, beh, cost, model, hp, size, **params):
        buildings[id] = {"name": name, "desc": desc, "category": cat, "behavior": beh, "cost": cost, "model": model, "hp": hp,
                         "size": size, "params": params, "sounds": {}}

    # --- предметы
    I("saltpeter", "Селитра", "Белые кристаллы. С серой и углём — порох. Залежи появляются после открытия «Химия».", NIT, "Руда", "drop_ore", scan=5)
    I("alunite", "Алунит", "Розоватая руда алюминия. Сначала её выщелачивают кислотой и водой на химзаводе, потом плавят.", "#c98f6b", "Руда", "drop_ore", scan=5)
    I("uranium_ore", "Урановая руда", "Радиоактивна! Рядом с залежью и с рудой в рюкзаке герой получает облучение. Защитный костюм почти полностью снимает его.",
      RAD, "Руда", "drop_ore", scan=5, rad=0.03)
    I("gunpowder", "Порох", "Сера, селитра и уголь. Нужен для патронов и взрывчатки.", "#3a3a3a", "Материалы", "drop_ore", price=6)
    I("sulfuric_acid", "Серная кислота", "Опасна! Разъедает обычные трубы и баки (нужны кислотостойкие или трубы Mk4), обжигает героя, если нести её без защитного костюма. При разрыве трубы разливается лужей.",
      ACID, "Жидкости", "drop_fluid", stack=100, price=3, fluid=True, hazard="acid", carry_dps=0.08, scan=0)
    I("canister_acid", "Канистра кислоты", "Серная кислота в таре: едет по лентам, но если нести в рюкзаке без защитного костюма — обжигает.", ACID,
      "Жидкости в таре", "drop_canister", stack=20, price=8, hazard="acid", carry_dps=0.3, scan=0)
    I("alumina", "Раствор глинозёма", "Алунит, растворённый в воде. Из него с углём получают алюминиевый лом.", "#e8eef5", "Жидкости", "drop_fluid", stack=100, price=2, fluid=True, scan=0)
    I("aluminum_scrap", "Алюминиевый лом", "Сырой алюминий. Плавится в плавильне с кварцем в слитки.", "#b8c0c8", "Материалы", "drop_ore", price=5)
    I("aluminum_ingot", "Алюминиевый слиток", "Лёгкий прочный металл.", ALU, "Материалы", "drop_ingot", price=10)
    I("aluminum_sheet", "Алюминиевый лист", "Для корпусов, костюмов и тяжёлой техники.", "#dfe6ec", "Детали", "drop_plate", price=12)
    I("aluminum_casing", "Алюминиевый корпус", "Оболочка для ТВЭЛов и точной техники.", "#c8d0d8", "Детали", "drop_block", price=18)
    I("yellowcake", "Жёлтый кек", "Урановый концентрат. Слабо радиоактивен.", "#e8c83a", "Материалы", "drop_ore", price=20, rad=0.02)
    I("enriched_uranium", "Обогащённый уран", "Сильно радиоактивен. Из него делают ТВЭЛы для АЭС.", "#7dff5a", "Материалы", "drop_crystal", price=60, rad=0.08)
    models["m_fuel_rod"] = m_fuel_rod()
    I("fuel_rod", "Урановый ТВЭЛ", "Топливо АЭС. Сильно радиоактивен: в рюкзаке держите недолго. Отработав, становится отработанным ТВЭЛом.", RAD, "Энергия", "m_fuel_rod", stack=10, price=200, rad=0.12,
      fuel=600, reactor_fuel=True)
    I("nuclear_waste", "Отработанный ТВЭЛ", "Опасные отходы АЭС: очень радиоактивны. Храните в хранилище отходов (оно не фонит) или перерабатывайте в центрифуге.",
      "#3a6a3a", "Энергия", "m_fuel_rod", stack=10, price=0, rad=0.2)
    models["m_hazmat"] = m_hazmat()
    I("hazmat_suit", "Защитный костюм", "Одежда: снимает 90% облучения и весь урон от кислоты. ПКМ — надеть.", "#ffd000", "Одежда", "m_hazmat", stack=1, price=120,
      clothes="body", warmth=5, rad_protect=0.9, acid_protect=1.0, scan=0)
    I("decon_solution", "Дезактивирующий раствор", "Для станции дезактивации и баллонов: смывает радиацию с земли.", "#6ad0ff", "Материалы", "drop_vial", price=6)
    models["m_decon_spray"] = m_spray()
    I("decon_spray", "Дезактивационный баллон", "ПКМ — распылить вокруг героя: заметно снижает заражение радиацией рядом.", "#3a8fe0", "Инструменты", "m_decon_spray", stack=10, price=30,
      decon=25.0, decon_radius=8.0, use_sound="click", scan=0)

    # --- рецепты
    R("gunpowder", "Порох", {"sulfur": 1, "saltpeter": 2, "coal": 1}, {"gunpowder": 2}, 3.0, ["workshop", "chem_plant"])
    R("ammo", "Патроны", {"iron_plate": 1, "gunpowder": 1}, {"ammo": 8}, 2.0, ["workshop", "assembler"])
    R("ammo_crude", "Патроны (кустарные)", {"iron_ingot": 2, "coal": 1}, {"ammo": 2}, 4.0, ["workbench", "workshop"])
    R("sulfuric_acid", "Серная кислота", {"sulfur": 2, "water": 2}, {"sulfuric_acid": 2}, 3.0, ["chem_plant"])
    R("pack_sulfuric_acid", "Налить канистру кислоты", {"sulfuric_acid": 4, "canister": 1}, {"canister_acid": 1}, 1.5, ["packager"])
    R("unpack_sulfuric_acid", "Вылить канистру кислоты", {"canister_acid": 1}, {"sulfuric_acid": 4, "canister": 1}, 1.5, ["packager"])
    R("alumina", "Раствор глинозёма", {"alunite": 4, "water": 4}, {"alumina": 4}, 4.0, ["chem_plant"])
    R("aluminum_scrap", "Алюминиевый лом", {"alumina": 4, "coal": 2}, {"aluminum_scrap": 6, "water": 2}, 3.0, ["chem_plant"])
    R("aluminum_ingot", "Алюминиевый слиток", {"aluminum_scrap": 4, "quartz": 1}, {"aluminum_ingot": 3}, 4.0, ["smelter"])
    R("aluminum_sheet", "Алюминиевый лист", {"aluminum_ingot": 2}, {"aluminum_sheet": 3}, 2.0, ["workshop", "assembler"])
    R("aluminum_casing", "Алюминиевый корпус", {"aluminum_ingot": 3, "steel": 1}, {"aluminum_casing": 2}, 4.0, ["assembler"])
    R("yellowcake", "Жёлтый кек", {"uranium_ore": 5, "sulfuric_acid": 2}, {"yellowcake": 2}, 6.0, ["chem_plant"])
    R("enriched_uranium", "Обогащённый уран", {"yellowcake": 3}, {"enriched_uranium": 1}, 10.0, ["centrifuge"])
    R("fuel_rod", "Урановый ТВЭЛ", {"enriched_uranium": 2, "aluminum_casing": 2, "circuit": 1}, {"fuel_rod": 1}, 8.0, ["assembler"])
    R("recycle_waste", "Переработка отходов", {"nuclear_waste": 2, "sulfuric_acid": 4}, {"enriched_uranium": 1}, 20.0, ["centrifuge"])
    R("hazmat_suit", "Защитный костюм", {"rubber": 4, "aluminum_sheet": 4, "plastic": 2}, {"hazmat_suit": 1}, 6.0, ["workshop"])
    R("decon_solution", "Дезактивирующий раствор", {"water": 4, "saltpeter": 1}, {"decon_solution": 4}, 3.0, ["chem_plant"])
    R("decon_spray", "Дезактивационный баллон", {"decon_solution": 5, "aluminum_sheet": 1}, {"decon_spray": 1}, 2.0, ["workshop"])

    # --- здания
    models["chem_plant"] = m_chem_plant()
    B("chem_plant", "Химзавод", "Кислоты, растворы, порох, жёлтый кек. Жидкости — по трубам (кислоте нужны кислотостойкие трубы). Нужна энергия.",
      "production", "crafter", {"steel": 12, "glass": 6, "motor": 2, "iron_plate": 10}, "chem_plant", 500, 2,
      station="chem_plant", speed=1.0, power=15, pipes=True, in_slots=3, out_slots=3, acid_proof=True)
    models["centrifuge"] = m_centrifuge()
    B("centrifuge", "Центрифуга", "Обогащает уран и перерабатывает отработанные ТВЭЛы. Много энергии.", "production", "crafter",
      {"aluminum_casing": 4, "motor": 4, "circuit": 6, "steel": 8}, "centrifuge", 400, 1, station="centrifuge", speed=1.0, power=40, in_slots=2, out_slots=2)
    models["nuclear_reactor"] = m_reactor()
    B("nuclear_reactor", "АЭС (ядерный реактор)",
      "До 1500 энергии. Нужны ТВЭЛы и вода по трубам (охлаждение). В окне: стержни управления, загрузка ТВЭЛов, насосы охлаждения, АЗ-5. "
      "Перегрев — авария: взрыв разрушает всё рядом и заражает местность радиацией.",
      "energy", "generator", {"steel": 80, "concrete": 60, "aluminum_casing": 20, "circuit": 30, "motor": 10}, "nuclear_reactor", 3000, 3,
      power=1500, reactor=True, fuels=["fuel_rod"], fuel_slots=4, pipes=True, radius=14, no_fusion=True)
    models["waste_storage"] = m_waste_storage()
    B("waste_storage", "Хранилище отходов", "Свинцовые стенки: радиоактивное внутри не фонит наружу. Для отработанных ТВЭЛов и урана.",
      "storage", "storage", {"concrete": 20, "steel": 10, "aluminum_sheet": 6}, "waste_storage", 800, 1, slots=12, rad_shield=True)
    models["decon_station"] = m_decon_station()
    B("decon_station", "Станция дезактивации", "Очищает заражённую радиацией землю вокруг себя, расходуя дезактивирующий раствор (подавайте лентой или кладите руками). Нужна энергия.",
      "special", "storage", {"steel": 10, "aluminum_sheet": 6, "motor": 2, "circuit": 4}, "decon_station", 400, 1,
      slots=4, power=10, decon_radius=16.0, decon_rate=1.5, decon_per_item=200.0, decon_item="decon_solution")
    models["pipe_acid"] = recolor(models.get("pipe_mk2", {}), "#7ac03a", ("paint", "rubber"))
    if "pipe_arm_mk2" in models:
        models["pipe_arm_acid"] = recolor(models["pipe_arm_mk2"], "#7ac03a", ("paint", "rubber"))
    B("pipe_acid", "Кислотостойкая труба", "Пластиковая футеровка: кислота её не разъедает. 600 в минуту.", "fluids", "pipe", {"plastic": 1, "steel": 1}, "pipe_acid", 120, 1,
      pipe_per_min=600, pipe_capacity=10, tier=2, any_ground=True, arm_model="pipe_arm_acid" if "pipe_arm_mk2" in models else "pipe_arm_mk2", acid_proof=True)
    models["acid_tank"] = recolor(models.get("tank", {}), "#7ac03a", ("paint",))
    B("acid_tank", "Кислотостойкий бак", "Бак на 400 единиц, которому не страшна кислота.", "fluids", "tank", {"plastic": 8, "steel": 6}, "acid_tank", 600, 2,
      pipe_capacity=400, acid_proof=True)
    if "pipe_mk4" in buildings:
        buildings["pipe_mk4"]["params"]["acid_proof"] = True
        buildings["pipe_mk4"]["desc"] = buildings["pipe_mk4"].get("desc", "") + " Кислотостойкая."
    if "tank" in buildings:
        buildings["acid_tank"]["size"] = buildings["tank"]["size"]

    # --- залежи (появляются после открытия узла в дереве)
    for it, col, patches, near in (("saltpeter", NIT, 14, 0), ("alunite", "#c98f6b", 14, 0), ("uranium_ore", RAD, 8, 0)):
        if any(d.get("item") == it for d in world.get("deposits", [])):
            continue
        world.setdefault("deposits", []).append({
            "resource": "", "item": it, "color": col, "patches": patches, "size_min": 2.0, "size_max": 3.5, "near_start": near,
            "drops": [], "cells": 1, "hand": True, "hand_hp": 40.0 if it == "uranium_ore" else 25.0, "hand_tool": "pickaxe", "rocks_around": 0,
            "marker": "dep_" + it, "min_dist": 60 if it == "uranium_ore" else 30})
        models["dep_" + it] = marker_model(items[it]["name"], col)

    # --- дерево открытий
    def TN(id, name, tier, order, icon, desc, cost, unlocks, requires, research=20):
        tech[id] = {"name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost, "unlocks": unlocks, "requires": requires, "research": research}
    chem = tech.get("t_chem")
    if chem is not None:
        u = chem.setdefault("unlocks", {})
        u.setdefault("deposits", [])
        if "saltpeter" not in u["deposits"]:
            u["deposits"].append("saltpeter")
        u.setdefault("recipes", [])
        for r in ("gunpowder", "ammo"):
            if r not in u["recipes"]:
                u["recipes"].append(r)
        chem["desc"] = "На карте появляются залежи серы и селитры. Порох и патроны, батареи и гранаты."
    TN("t_acid", "Кислоты", 3, 4, "chem_plant", "Химзавод, серная кислота, кислотостойкие трубы и баки. Осторожно: кислота разъедает обычные трубы.",
       {"steel": 30, "glass": 20, "sulfur": 30}, {"buildings": ["chem_plant", "pipe_acid", "acid_tank"], "recipes": ["sulfuric_acid", "pack_sulfuric_acid", "unpack_sulfuric_acid"]}, ["t_oil", "t_chem"], 25)
    TN("t_aluminum", "Алюминий", 4, 3, "alunite", "Залежи алунита. Раствор глинозёма → алюминиевый лом → слитки, листы и корпуса. Защитный костюм.",
       {"steel": 50, "plastic": 20, "sulfuric_acid": 20} if False else {"steel": 50, "plastic": 20, "circuit": 20},
       {"deposits": ["alunite"], "recipes": ["alumina", "aluminum_scrap", "aluminum_ingot", "aluminum_sheet", "aluminum_casing", "hazmat_suit"]}, ["t_acid"], 35)
    TN("t_uranium", "Уран", 5, 2, "uranium_ore", "Урановые залежи (радиоактивны!), жёлтый кек, центрифуга, хранилище отходов, дезактивация.",
       {"aluminum_sheet": 40, "circuit": 30, "steel": 60}, {"deposits": ["uranium_ore"], "buildings": ["centrifuge", "waste_storage", "decon_station"],
       "recipes": ["yellowcake", "enriched_uranium", "decon_solution", "decon_spray"]}, ["t_aluminum"], 45)
    TN("t_nuclear", "Атомная энергия", 6, 1, "nuclear_reactor", "АЭС: огромная энергия, если правильно настроить охлаждение, загрузку и стержни. Переработка отходов.",
       {"aluminum_casing": 30, "enriched_uranium": 10, "circuit": 50}, {"buildings": ["nuclear_reactor"], "recipes": ["fuel_rod", "recycle_waste"]}, ["t_uranium"], 60)

    # --- настройки
    settings["radiation"] = {
        "enabled": True, "dmg_k": 1.0, "deposit_strength": 1.5, "deposit_radius": 7.0, "item_k": 1.0, "item_cap": 6.0,
        "building_radius": 8.0, "zone_decay": 0.003, "build_block": 3.0, "show_meter": True, "warn_at": 0.5,
        "reactor_leak": 0.5, "reactor_hot": 2.0, "zone_color": "#7dff5a", "zone_k": 0.05, "zone_grid": 2, "building_k": 0.3,
        "dose_k": 1.0, "recover": 0.5, "sick_dps": 1.0, "geiger": True}
    settings["acid"] = {"enabled": True, "pipe_dps": 1.5, "spill_radius": 4.0, "spill_dps": 10.0, "spill_time": 45.0, "carry_k": 1.0, "carry_cap": 5.0, "color": "#c8e04a"}
    settings["reactor"] = {
        "heat_per_rod": 600.0, "power_per_heat": 1.0, "steam_t": 100.0, "max_flow": 5.0, "cool_per_water": 300.0, "cool_full_at": 150.0,
        "passive": 0.5, "heat_cap": 40.0, "warn_t": 500.0, "crit_t": 800.0, "melt_t": 1100.0, "crit_time": 15.0, "rod_life": 600.0,
        "rod_speed": 20.0, "scram_speed": 60.0, "water_buf": 60.0, "boom_radius": 14.0, "hurt_radius": 28.0, "boom_damage": 400.0,
        "zone_radius": 40.0, "zone_strength": 60.0, "slots": 4,
        "coolant": "water", "waste": "nuclear_waste", "auto_scram_default": False, "boom_hq": False}
    mods = settings.setdefault("modules", {})
    mods.setdefault("hazards", True)
