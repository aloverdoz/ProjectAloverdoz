# 14.23 «Звёздный патч»: тонкая настройка зданий (необязательная, даёт бонус), инженерный стол 4×4 (улучшенные рецепты),
# орбитальная торговля с НЛО с плавающими ценами, экзотические ресурсы, связная цепочка до мегапроекта «Звёздные врата»,
# настройки боссов. Вызывается из gen_core.py после atom.apply_atom. Всё, что здесь задано, правится в редакторе.
import math
from rework import _p

DK, MID, LT, STEEL, CONC = "#262a31", "#5d6672", "#c9d0d8", "#9aa3ad", "#8a8d90"
UFO, VOID, HE3, AM, DM = "#8ff0ff", "#9b6bff", "#a8f0ff", "#ff4fd8", "#3a2a5a"


# ---------------------------------------------------------------- модели

def m_ufo():
    p = [_p("cylinder", (5.0, 0.5, 5.0), (0, 0, 0), "#b8c4cf", "metal", seg=28, top=0.55),
         _p("cylinder", (5.0, 0.35, 5.0), (0, -0.4, 0), "#8a96a3", "metal", seg=28, top=0.6, rot=(180, 0, 0)),
         _p("sphere", (2.0, 1.3, 2.0), (0, 0.6, 0), UFO, "glass"),
         _p("cylinder", (5.1, 0.1, 5.1), (0, -0.1, 0), DK, seg=28)]
    for k in range(10):
        a = k / 10 * math.tau
        p.append(_p("sphere", (0.3, 0.2, 0.3), (math.cos(a) * 2.35, -0.12, math.sin(a) * 2.35), "#7dffb0" if k % 2 else "#ffd36a", "glow", anim="pulse", tint=False))
    p.append(_p("cylinder", (1.4, 0.2, 1.4), (0, -0.65, 0), "#b8fff0", "glow", anim="pulse", tint=False, seg=16))
    return {"name": "НЛО", "category": "Особые", "parts": p}


def m_ufo_pad():
    p = [_p("cylinder", (3.6, 0.25, 3.6), (0, 0.12, 0), CONC, "concrete", seg=24),
         _p("cylinder", (3.0, 0.06, 3.0), (0, 0.27, 0), "#2b3440", "dark", seg=24),
         _p("cylinder", (2.2, 0.03, 2.2), (0, 0.31, 0), UFO, "glow", anim="pulse", tint=False, seg=24),
         _p("cylinder", (1.8, 0.04, 1.8), (0, 0.32, 0), "#2b3440", "dark", seg=24),
         _p("box", (0.8, 1.0, 0.8), (1.2, 0.75, 1.2), MID, bevel=0.06),
         _p("box", (0.6, 0.3, 0.05), (1.2, 1.0, 1.61), "#122a33", "glass")]
    for k in range(8):
        a = k / 8 * math.tau
        p.append(_p("cylinder", (0.12, 0.5, 0.12), (math.cos(a) * 1.65, 0.45, math.sin(a) * 1.65), STEEL, seg=8))
        p.append(_p("sphere", (0.16, 0.16, 0.16), (math.cos(a) * 1.65, 0.75, math.sin(a) * 1.65), "#7dffb0", "glow", anim="pulse", tint=False))
    p.append(_p("cylinder", (0.08, 1.6, 0.08), (-1.3, 1.0, -1.3), STEEL, seg=6))
    p.append(_p("sphere", (0.5, 0.25, 0.5), (-1.3, 1.85, -1.3), LT, rot=(0, 0, 30), anim="spin"))
    return {"name": "Посадочная площадка НЛО", "category": "Особые", "parts": p}


def m_eng_table():
    p = [_p("box", (1.8, 0.1, 1.2), (0, 0.9, 0), "#3c4652", bevel=0.03)]
    for x in (-0.8, 0.8):
        for z in (-0.5, 0.5):
            p.append(_p("box", (0.1, 0.9, 0.1), (x, 0.45, z), DK))
    for i in range(4):
        for j in range(4):
            p.append(_p("box", (0.22, 0.02, 0.22), (-0.45 + i * 0.3, 0.96, -0.35 + j * 0.24), "#4ad0ff" if (i + j) % 3 == 0 else "#1c2a33", "glow" if (i + j) % 3 == 0 else "dark", tint=(i + j) % 3 != 0))
    p.append(_p("box", (0.6, 0.45, 0.05), (0, 1.25, -0.55), "#122a33", "glass", rot=(-15, 0, 0)))
    return {"name": "Инженерный стол", "category": "Производство", "parts": p}


def m_forge():
    p = [_p("box", (1.9, 0.3, 1.9), (0, 0.15, 0), CONC, "concrete", bevel=0.05),
         _p("cylinder", (1.3, 1.4, 1.3), (0, 1.0, 0), "#2a2440", "metal", seg=8),
         _p("cylinder", (1.34, 0.12, 1.34), (0, 1.3, 0), VOID, "glow", anim="pulse", tint=False, seg=8),
         _p("cylinder", (0.7, 0.6, 0.7), (0, 1.9, 0), MID, seg=8, top=0.6),
         _p("sphere", (0.5, 0.5, 0.5), (0, 2.35, 0), VOID, "glow", anim="pulse", tint=False)]
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        p.append(_p("box", (0.25, 1.6, 0.25), (math.cos(a) * 0.8, 1.0, math.sin(a) * 0.8), STEEL))
    return {"name": "Экзотическая кузня", "category": "Производство", "parts": p}


def m_fusion():
    p = [_p("box", (5.6, 0.4, 5.6), (0, 0.2, 0), CONC, "concrete", bevel=0.08),
         _p("torus", (3.6, 1.0, 3.6), (0, 1.6, 0), "#cdd6df", "metal", seg=24),
         _p("cylinder", (1.6, 2.6, 1.6), (0, 1.7, 0), "#3a4250", seg=16),
         _p("sphere", (1.2, 1.2, 1.2), (0, 3.0, 0), "#ffb0f0", "glow", anim="pulse", tint=False)]
    for k in range(8):
        a = k / 8 * math.tau
        p.append(_p("box", (0.4, 2.4, 0.4), (math.cos(a) * 2.4, 1.4, math.sin(a) * 2.4), "#ff7a2e" if k % 2 else MID, "paint"))
    return {"name": "Термоядерный реактор", "category": "Энергия", "parts": p}


def m_qasm():
    p = [_p("box", (1.9, 0.3, 1.9), (0, 0.15, 0), CONC, "concrete", bevel=0.05),
         _p("box", (1.6, 1.3, 1.6), (0, 0.95, 0), "#1f2833", bevel=0.12),
         _p("box", (1.62, 0.1, 1.62), (0, 1.3, 0), "#4affd8", "glow", anim="pulse", tint=False),
         _p("sphere", (0.7, 0.7, 0.7), (0, 1.95, 0), "#4affd8", "glass"),
         _p("torus", (1.1, 0.12, 1.1), (0, 1.95, 0), STEEL, anim="spin")]
    return {"name": "Квантовый сборщик", "category": "Производство", "parts": p}


def m_gate():
    p = [_p("box", (5.8, 0.4, 5.8), (0, 0.2, 0), CONC, "concrete", bevel=0.08),
         _p("torus", (5.0, 0.7, 5.0), (0, 3.2, 0), "#cfd8e2", "metal", seg=32, rot=(90, 0, 0)),
         _p("cylinder", (4.2, 0.06, 4.2), (0, 3.2, 0), VOID, "glow", anim="pulse", tint=False, seg=32, rot=(90, 0, 0))]
    for k in range(9):
        a = k / 9 * math.tau
        p.append(_p("box", (0.5, 0.3, 0.3), (math.cos(a) * 2.55, 3.2 + math.sin(a) * 2.55, 0), "#ff7a2e" if k % 3 == 0 else MID, "paint", rot=(0, 0, math.degrees(a))))
    p += [_p("box", (0.8, 1.2, 0.8), (-2.2, 0.8, 0), MID), _p("box", (0.8, 1.2, 0.8), (2.2, 0.8, 0), MID)]
    return {"name": "Звёздные врата", "category": "Особые", "parts": p}


# ---------------------------------------------------------------- данные

TUNING_KINDS = {
    "heat": {"name": "Температура печи", "knob": "Жар", "lo": "Холодно", "hi": "Перегрев", "effects": {"speed": 0.35, "output": 0.1},
             "desc": "В «золотой» температуре плавка быстрее и иногда даёт лишний слиток. Слишком холодно — медленно, перегрев — печь портится."},
    "rpm": {"name": "Обороты бура", "knob": "Обороты", "lo": "Медленно", "hi": "Разнос", "effects": {"speed": 0.3},
            "desc": "Правильные обороты под вашу залежь — больше руды в минуту. На разносе бур изнашивается."},
    "pressure": {"name": "Давление насоса", "knob": "Давление", "lo": "Слабо", "hi": "Гидроудар", "effects": {"speed": 0.3},
                 "desc": "Подберите давление — насос качает больше. Слишком высокое ломает насос."},
    "calib": {"name": "Калибровка сборщика", "knob": "Точность", "lo": "Грубо", "hi": "Дрожь", "effects": {"output": 0.25, "speed": 0.1},
              "desc": "Точная калибровка иногда даёт лишнюю деталь из тех же материалов."},
    "mix": {"name": "Смесь топливо/воздух", "knob": "Смесь", "lo": "Бедная", "hi": "Богатая", "effects": {"fuel": 0.45},
            "desc": "Идеальная смесь — топливо горит дольше. Слишком богатая — копоть и износ."},
    "ph": {"name": "Кислотность (pH)", "knob": "pH", "lo": "Щёлочь", "hi": "Кислота", "effects": {"speed": 0.25, "output": 0.15},
           "desc": "Каждая химия любит свой pH: найдёте — реакции идут быстрее и с прибытком."},
    "spin": {"name": "Частота центрифуги", "knob": "Частота", "lo": "Вяло", "hi": "Резонанс", "effects": {"output": 0.3},
             "desc": "На правильной частоте центрифуга иногда отделяет вдвое больше. Резонанс разрушает её."},
    "aim": {"name": "Пристрелка турели", "knob": "Поправка", "lo": "Недолёт", "hi": "Перелёт", "effects": {"damage": 0.3},
            "desc": "Пристрелянная турель бьёт сильнее."},
    "tilt": {"name": "Наклон панели", "knob": "Угол", "lo": "Плоско", "hi": "Отвесно", "effects": {"supply": 0.35},
             "desc": "Под правильным углом панель ловит больше солнца."},
    "pitch": {"name": "Шаг лопастей", "knob": "Шаг", "lo": "Мелкий", "hi": "Флюгер", "effects": {"supply": 0.35},
              "desc": "Правильный шаг лопастей — больше энергии. На крайнем шаге ветряк трясёт."},
    "plasma": {"name": "Удержание плазмы", "knob": "Поле", "lo": "Слабое", "hi": "Пережатие", "effects": {"supply": 0.4, "fuel": 0.3},
               "desc": "Точное магнитное поле — больше энергии и дольше горит ячейка. Пережатие повреждает реактор."},
}

TUNE_OF = {"furnace": "heat", "smelter": "heat", "smelter_mk2": "heat",
           "miner": "rpm", "miner_mk2": "rpm", "miner_mk3": "rpm", "miner_mk4": "rpm", "miner_mk5": "rpm",
           "water_pump": "pressure", "oil_pump": "pressure",
           "assembler": "calib", "assembler_mk2": "calib", "quantum_assembler": "calib",
           "generator": "mix", "coal_generator": "mix", "fuel_generator": "mix", "biomass_burner": "mix",
           "chem_plant": "ph", "refinery": "ph", "centrifuge": "spin", "exotic_forge": "spin",
           "solar": "tilt", "wind_turbine": "pitch", "fusion_reactor": "plasma"}

EXOTICS = [  # id, имя, цвет, модель, описание, ценность (в кредитах), во что котируется
    ("helium3", "Гелий-3", HE3, "drop_vial", "Лунный изотоп. Топливо термоядерных ячеек и охладитель сверхпроводников.", 6000, "circuit"),
    ("antimatter", "Антиматерия", AM, "drop_crystal", "Капля антивещества в магнитной ловушке. Самое мощное топливо.", 90000, "circuit"),
    ("void_crystal", "Кристалл пустоты", VOID, "drop_crystal", "Кристалл, который не отражает свет. Основа квантовых ядер.", 24000, "steel"),
    ("neutronium", "Нейтроний", "#d8dde8", "drop_ingot", "Сверхплотный металл с нейтронной звезды. Делает звёздный сплав.", 9000, "steel"),
    ("dark_matter", "Тёмная материя", DM, "drop_vial", "Невидимая масса в колбе. Нужна линзам и синтезу кристаллов.", 45000, "battery"),
    ("chronium", "Хроний", "#ffd36a", "drop_crystal", "Металл, в котором время течёт иначе. Для хроношестерён.", 30000, "motor"),
]


def apply_endgame(models, buildings, items, recipes, settings, tech):
    def I(id, name, desc, color, cat, model, stack=50, price=4, **kw):
        d = {"name": name, "desc": desc, "color": color, "category": cat, "stack": stack, "price": price, "model": model, "scan": kw.pop("scan", 3)}
        d.update(kw)
        items[id] = d

    def R(id, name, ins, out, time, stations, **kw):
        recipes[id] = {"name": name, "in": ins, "out": out, "time": time, "stations": stations}
        recipes[id].update(kw)

    def B(id, name, desc, cat, beh, cost, model, hp, size, **params):
        buildings[id] = {"name": name, "desc": desc, "category": cat, "behavior": beh, "cost": cost, "model": model, "hp": hp,
                         "size": size, "params": params, "sounds": {}}

    # --- экзотика (сначала только у НЛО, позже часть можно синтезировать)
    for id, nm, col, mdl, desc, val, _q in EXOTICS:
        I(id, nm, desc + " Добывается обменом с НЛО на посадочной площадке.", col, "Экзотика", mdl, stack=50, price=val, scan=0, exotic=True)
    I("superconductor", "Сверхпроводник", "Провод без сопротивления (охлаждается гелием-3). Магнитные ловушки, квантовая техника.", "#bfe8ff", "Детали", "drop_plate", price=120)
    I("stellar_alloy", "Звёздный сплав", "Сталь, алюминий и нейтроний. Корпуса для самых тяжёлых машин.", "#e6ecf5", "Материалы", "drop_ingot", price=300)
    I("fusion_cell", "Термоядерная ячейка", "Топливо термоядерного реактора.", "#ffb0f0", "Энергия", "drop_battery", stack=20, price=600, fuel=900, special_fuel=True)
    I("magnetic_trap", "Магнитная ловушка", "Держит антиматерию, не давая ей коснуться стенок.", "#9ad8ff", "Детали", "drop_block", price=900)
    I("antimatter_cell", "Ячейка антиматерии", "Антиматерия в ловушке. Мегапроект и синтез.", AM, "Энергия", "drop_battery", stack=20, price=4500)
    I("quantum_core", "Квантовое ядро", "Мозг квантовой техники.", "#4affd8", "Детали", "drop_circuit", price=2500)
    I("chrono_gear", "Хроношестерня", "Шестерня из хрония: механизмы, которые опережают время.", "#ffd36a", "Детали", "drop_ingot", price=900)
    I("dark_lens", "Линза тёмной материи", "Фокусирует пространство. Сердце звёздных врат.", "#6b4bd8", "Детали", "drop_crystal", price=6000)
    I("bio_gel", "Биогель", "Из биомассы, хитина и слизи монстров. Катализатор и живая изоляция.", "#7ad86b", "Материалы", "drop_vial", price=40)

    # --- рецепты: связная цепочка (железо, медь, сталь, пластик, алюминий, уран, химия, монстры → экзотика → врата)
    R("bio_gel", "Биогель", {"biomass": 10, "chitin": 2, "goo": 2}, {"bio_gel": 2}, 6.0, ["chem_plant"])
    R("superconductor", "Сверхпроводник", {"aluminum_sheet": 2, "wire": 4, "helium3": 1}, {"superconductor": 4}, 6.0, ["assembler", "quantum_assembler"])
    R("stellar_alloy", "Звёздный сплав", {"steel": 4, "aluminum_ingot": 2, "neutronium": 1}, {"stellar_alloy": 2}, 8.0, ["exotic_forge"])
    R("fusion_cell", "Термоядерная ячейка", {"helium3": 2, "superconductor": 1, "aluminum_casing": 1}, {"fusion_cell": 1}, 8.0, ["assembler", "quantum_assembler"])
    R("magnetic_trap", "Магнитная ловушка", {"superconductor": 4, "circuit": 4, "stellar_alloy": 1}, {"magnetic_trap": 1}, 10.0, ["exotic_forge"])
    R("antimatter_cell", "Ячейка антиматерии", {"antimatter": 1, "magnetic_trap": 1}, {"antimatter_cell": 1}, 12.0, ["exotic_forge"])
    R("quantum_core", "Квантовое ядро", {"void_crystal": 2, "circuit": 10, "crystal": 2, "superconductor": 2, "bio_gel": 2}, {"quantum_core": 1}, 15.0, ["exotic_forge"])
    R("chrono_gear", "Хроношестерня", {"chronium": 1, "gear": 10, "stellar_alloy": 1}, {"chrono_gear": 2}, 10.0, ["exotic_forge"])
    R("dark_lens", "Линза тёмной материи", {"dark_matter": 1, "glass": 10, "quantum_core": 1}, {"dark_lens": 1}, 20.0, ["exotic_forge"])
    # улучшенные рецепты: открываются, когда игрок соберёт узор на инженерном столе
    R("steel_arc", "Сталь (дуговая плавка)", {"iron_ingot": 2, "coal_hq": 1}, {"steel": 3}, 3.0, ["smelter", "smelter_mk2"], pattern="p_steel")
    R("circuit_dense", "Плотная микросхема", {"wire": 2, "plastic": 1, "quartz": 1}, {"circuit": 2}, 3.0, ["assembler", "assembler_mk2", "quantum_assembler"], pattern="p_circuit")
    R("helium_from_waste", "Гелий-3 из отходов", {"nuclear_waste": 4, "superconductor": 1}, {"helium3": 3}, 20.0, ["centrifuge"], pattern="p_helium")
    R("void_synth", "Синтез кристалла пустоты", {"crystal": 4, "dark_matter": 1, "monster_core": 1}, {"void_crystal": 3}, 25.0, ["exotic_forge"], pattern="p_void")
    R("alu_catalyst", "Алюминий с катализатором", {"bio_gel": 1, "alumina": 4}, {"aluminum_scrap": 10}, 3.0, ["chem_plant"], pattern="p_alu")
    R("antimatter_cold", "Холодный синтез антиматерии", {"fusion_cell": 2, "dark_matter": 1}, {"antimatter": 1}, 30.0, ["exotic_forge"], pattern="p_anti")

    # --- здания
    models["ufo"] = m_ufo()
    models["ufo_pad"] = m_ufo_pad()
    B("ufo_pad", "Посадочная площадка НЛО", "Сюда прилетает НЛО торговцев. Сложите товары (руками, лентой, дронами), выберите в окне, что хотите взамен. "
      "НЛО заберёт, сколько унесёт, и через время привезёт заказ. Цены меняются каждый день.",
      "special", "storage", {"steel": 60, "aluminum_sheet": 30, "circuit": 40, "concrete": 40}, "ufo_pad", 1500, 3, slots=24, ufo_pad=True, no_fusion=True)
    models["eng_table"] = m_eng_table()
    B("eng_table", "Инженерный стол", "Сетка 4×4: разложите предметы узором. Подсказка показывает, сколько клеток совпало. Верный узор навсегда открывает улучшенный рецепт.",
      "production", "decor", {"iron_plate": 20, "circuit": 10, "glass": 10}, "eng_table", 300, 1, eng_table=True, no_fusion=True)
    models["exotic_forge"] = m_forge()
    B("exotic_forge", "Экзотическая кузня", "Работает с экзотикой: звёздный сплав, ловушки, квантовые ядра, линзы. Много энергии.", "production", "crafter",
      {"stellar_alloy": 0, "steel": 60, "superconductor": 10, "circuit": 30, "aluminum_casing": 20}, "exotic_forge", 900, 2,
      station="exotic_forge", speed=1.0, power=250, in_slots=5, out_slots=2)
    buildings["exotic_forge"]["cost"].pop("stellar_alloy")
    models["fusion_reactor"] = m_fusion()
    B("fusion_reactor", "Термоядерный реактор", "5000 энергии на термоядерных ячейках. Безопаснее АЭС: без ячеек просто гаснет. Настройка поля даёт до +40%.",
      "energy", "generator", {"stellar_alloy": 40, "superconductor": 60, "magnetic_trap": 6, "concrete": 200, "circuit": 80}, "fusion_reactor", 5000, 5,
      power=5000, fuels=["fusion_cell"], fuel_slots=2, burn_mult=1.0, radius=18, no_fusion=True)
    models["quantum_assembler"] = m_qasm()
    B("quantum_assembler", "Квантовый сборщик", "Сборщик в 4 раза быстрее Mk1. Делает и сверхпроводники, и ячейки.", "production", "crafter",
      {"quantum_core": 2, "stellar_alloy": 10, "circuit": 40, "motor": 10}, "quantum_assembler", 800, 2, station="assembler", speed=4.0, power=200, in_slots=5, out_slots=3)
    models["star_gate"] = m_gate()
    B("star_gate", "Звёздные врата", "Мегапроект: 5 этапов, каждый просит много редких деталей. Подавайте лентами, дронами или руками. Открыть врата — главная цель для идеального завода.",
      "special", "storage", {"concrete": 500, "steel": 400, "stellar_alloy": 50, "superconductor": 100}, "star_gate", 20000, 5, slots=30, megaproject=True, no_fusion=True)
    for bid, kind in TUNE_OF.items():
        if bid in buildings:
            buildings[bid]["params"]["tune"] = kind

    # --- дерево открытий
    def TN(id, name, tier, order, icon, desc, cost, unlocks, requires, research=30):
        tech[id] = {"name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost, "unlocks": unlocks, "requires": requires, "research": research}
    TN("t_tuning", "Тонкая настройка", 2, 6, "furnace", "В окнах машин видна «золотая зона» настройки (без открытия её приходится искать по индикатору эффективности).",
       {"gear": 30, "circuit": 5}, {}, ["t_power"], 15)
    TN("t_patterns", "Инженерия", 3, 6, "eng_table", "Инженерный стол: собирайте узоры 4×4 и открывайте улучшенные рецепты.", {"circuit": 20, "steel": 20, "glass": 10},
       {"buildings": ["eng_table"]}, ["t_tuning", "t_mk2"], 25)
    TN("t_ufo", "Контакт", 5, 3, "ufo_pad", "Посадочная площадка НЛО: обмен товаров на экзотику по плавающим ценам.",
       {"aluminum_sheet": 40, "circuit": 60, "steel": 60}, {"buildings": ["ufo_pad"]}, ["t_transport", "t_aluminum"], 40)
    TN("t_exotic", "Экзотическая материя", 6, 2, "exotic_forge", "Сверхпроводники, звёздный сплав, биогель, экзотическая кузня.",
       {"helium3": 10, "neutronium": 5, "aluminum_casing": 40}, {"buildings": ["exotic_forge"], "recipes": ["superconductor", "stellar_alloy", "bio_gel"]}, ["t_ufo"], 60)
    TN("t_fusion", "Термоядерный синтез", 7, 1, "fusion_reactor", "Термоядерные ячейки и реактор на 5000 энергии.",
       {"superconductor": 60, "stellar_alloy": 30, "helium3": 30}, {"buildings": ["fusion_reactor"], "recipes": ["fusion_cell", "magnetic_trap"]}, ["t_exotic", "t_nuclear"], 80)
    TN("t_quantum2", "Квантовая инженерия", 7, 2, "quantum_assembler", "Квантовые ядра, хроношестерни, квантовый сборщик.",
       {"void_crystal": 20, "superconductor": 40, "circuit": 200}, {"buildings": ["quantum_assembler"], "recipes": ["quantum_core", "chrono_gear"]}, ["t_exotic", "t_mk5"], 90)
    TN("t_antimatter2", "Ловушки антиматерии", 8, 1, "antimatter", "Ячейки антиматерии и линзы тёмной материи.",
       {"magnetic_trap": 10, "quantum_core": 10, "antimatter": 5}, {"recipes": ["antimatter_cell", "dark_lens"]}, ["t_fusion", "t_quantum2"], 120)
    TN("t_stargate", "Звёздные врата", 9, 1, "star_gate", "Мегапроект в 5 этапов — вершина завода.",
       {"antimatter_cell": 10, "dark_lens": 2, "quantum_core": 30}, {"buildings": ["star_gate"]}, ["t_antimatter2"], 200)

    # --- настройки
    settings["tuning"] = {"enabled": True, "width": 12.0, "danger": 92.0, "low": 8.0, "low_pen": 0.25, "danger_pen": 0.3, "wear_dps": 4.0,
                          "hint_tech": "t_tuning", "golden_min": 12.0, "golden_max": 88.0, "neutral": 50.0, "kinds": TUNING_KINDS}
    settings["patterns"] = {"enabled": True, "list": [
        {"id": "p_steel", "name": "Дуговая плавка", "recipe": "steel_arc", "hint": "Уголь сверху и снизу, железо в середине — как электроды.",
         "grid": ["....", "CCCC", "IIII", "CCCC"], "key": {"C": "coal_hq", "I": "iron_ingot"}},
        {"id": "p_circuit", "name": "Плотная плата", "recipe": "circuit_dense", "hint": "Кварц по углам, провода крестом, пластик в центре.",
         "grid": ["QW.Q", "WPPW", "WPPW", "Q.WQ"], "key": {"Q": "quartz", "W": "wire", "P": "plastic"}},
        {"id": "p_helium", "name": "Отбор гелия", "recipe": "helium_from_waste", "hint": "Отходы — в кольцо вокруг сверхпроводника.",
         "grid": [".NN.", "NSSN", "NSSN", ".NN."], "key": {"N": "nuclear_waste", "S": "superconductor"}},
        {"id": "p_void", "name": "Решётка пустоты", "recipe": "void_synth", "hint": "Шахматная доска из кристаллов и ядер монстров.",
         "grid": ["CMCM", "MCMC", "CMCM", "MCMC"], "key": {"C": "crystal", "M": "monster_core"}},
        {"id": "p_alu", "name": "Каталитическая сетка", "recipe": "alu_catalyst", "hint": "Биогель по диагонали, остальное — листы алюминия.",
         "grid": ["GAAA", "AGAA", "AAGA", "AAAG"], "key": {"G": "bio_gel", "A": "aluminum_sheet"}},
        {"id": "p_anti", "name": "Холодная ловушка", "recipe": "antimatter_cold", "hint": "Рамка из сверхпроводников, внутри — ячейки.",
         "grid": ["SSSS", "SFFS", "SFFS", "SSSS"], "key": {"S": "superconductor", "F": "fusion_cell"}},
    ]}
    settings["ufo"] = {"enabled": True, "interval": 420.0, "first": 120.0, "stay": 20.0, "capacity": 1000, "day_len": 1200.0,
                       "swing_min": 0.5, "swing_max": 1.6, "step": 0.35, "sell_k": 0.6, "height": 40.0,
                       "goods": {id: {"value": val, "quote": q} for id, _n, _c, _m, _d, val, q in EXOTICS},
                       "beam_color": "#8ff0ff", "sound": "omen"}
    settings["megaproject"] = {"victory": True, "reward": 50000, "stages": [
        {"name": "Фундамент врат", "need": {"concrete": 2000, "steel": 1500, "stellar_alloy": 100}},
        {"name": "Кольцо", "need": {"superconductor": 800, "magnetic_trap": 60, "aluminum_casing": 500}},
        {"name": "Ядро", "need": {"quantum_core": 100, "chrono_gear": 200, "fusion_cell": 300}},
        {"name": "Линза", "need": {"dark_lens": 40, "antimatter_cell": 50, "bio_gel": 400}},
        {"name": "Запуск", "need": {"antimatter_cell": 200, "quantum_core": 200, "void_crystal": 300}}]}
    settings["bosses"] = {"player_aggro": 10.0, "revenge_time": 6.0}
    mods = settings.setdefault("modules", {})
    mods.setdefault("tuning", True)
    mods.setdefault("ufo", True)
