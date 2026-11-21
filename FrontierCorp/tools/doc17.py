# 17.10: всё из «дизайн-справочника» (документ_идеи) в основной игре: новые руды и залежи по «слоям»,
# компоненты T0–T5, здания (литейный цех, конструктор, производитель, коксовая печь, дробилка, смеситель,
# дуговая печь, чистый цех, доменная печь, кристаллорез, синтезатор, лесопилка, камнерез),
# утилизатор за очки, магазин утилизации, разгонитель облаков, «Геология II / III / аномальная».
# Слой глубины в нашей игре — это кольцо от старта: чем дальше залежь, тем она «глубже», а с «Геология II»
# и дальше залежь не видна и не добывается, пока технология не изучена (как руды в Террарии).
# Вызывается из gen_core.py последним. Всё правится в редакторе: «Предметы», «Рецепты», «Здания», «Дерево открытий»,
# «Мир» → «Месторождения», «Настройки» → «Зона и буря».
import sys
gc = sys.modules["__main__"]
P, M = gc.P, gc.M

import cat_items, cat_items2, cat_build1, cat_build2, cat_plants
from rework import marker_model

_built = False


def _catalog():
    global _built
    if not _built:
        cat_items.build_metals(); cat_items.build_gems(); cat_items.build_electronics(); cat_items.build_chem()
        cat_items2.build_all()
        cat_build1.build_all()
        cat_build2.build_all()
        _built = True


def _cat_model(models, mid):
    """Модель из каталога → в игру (под тем же id)."""
    if mid in models:
        return mid
    for src in (cat_items.models, cat_build1.models, cat_plants.models):
        if mid in src:
            models[mid] = src[mid]
            return mid
    return ""


# ---------------------------------------------------------------- предметы
# id: (название, описание, цвет, категория, модель, стопка) — модели drop_* красятся в цвет предмета
RAW = {
    "clay": ("Глина", "Мягкая порода у воды. Обжиг в печи → кирпич; из неё же тигли и керамика.", "#b0603a", "Сырьё", "drop_stone", 50),
    "sand": ("Песок", "Копается на песчаных пятнах. Стекло, кремний, литейные формы.", "#e0cc8a", "Сырьё", "drop_stone", 50),
    "tin_ore": ("Оловянная руда", "Пещерный слой. Олово → бронза, припой и жесть.", "#c9d0d6", "Руда", "drop_ore", 50),
    "limestone": ("Известняк", "Пещерный слой. Бетон, флюс для плавки, негашёная известь.", "#d8d2bf", "Руда", "drop_stone", 50),
    "bauxite": ("Боксит", "Слой «Глубины» (виден после «Геология II»). Глинозём → алюминий.", "#c46a3c", "Руда", "drop_ore", 50),
    "nickel_ore": ("Никелевая руда", "Слой «Глубины». Нержавеющая сталь.", "#9fae8a", "Руда", "drop_ore", 50),
    "lead_ore": ("Свинцовая руда", "Слой «Глубины». Аккумуляторы и защита от радиации.", "#6a7280", "Руда", "drop_ore", 50),
    "salt": ("Соль", "Слой «Глубины». Консервы, хладагент, хлор для титана.", "#f1efe8", "Руда", "drop_stone", 50),
    "gold_ore": ("Золотая руда", "Слой «Глубины». Золотая проволока для микросхем.", "#e8c33a", "Руда", "drop_ore", 50),
    "natural_gas": ("Природный газ", "Слой «Глубины»: газовые карманы. Качает газовый экстрактор, сжигают генераторы.", "#b9e6d0", "Жидкости", "drop_fluid", 100),
    "tungsten_ore": ("Вольфрамовая руда", "Магматический пояс (после «Геология III»). Только бур Mk2 и выше или стальная кирка.", "#4a4f5c", "Руда", "drop_ore", 50),
    "titanium_ore": ("Титановая руда", "Магматический пояс. Лёгкие прочные рамы и броня.", "#b9c3d9", "Руда", "drop_ore", 50),
    "obsidian": ("Обсидиан", "Магматический пояс. Жаропрочные блоки и клинки.", "#2a2236", "Руда", "drop_stone", 50),
    "resonite": ("Резонит", "Бездна (после «Аномальная геология»). Кристалл, который копит энергию. Только бур Mk3+.", "#c25cff", "Руда", "drop_crystal", 50),
    "rare_earth_ore": ("Редкоземельная руда", "Бездна. Магниты и сверхпроводники.", "#5fd0b8", "Руда", "drop_ore", 50),
    "anomaly_matter": ("Аномальная материя", "Остаётся от боссов осад. Финальные технологии и ядро разгона облаков.", "#ff4fd8", "Экзотика", "drop_core", 20),
}

# Компоненты: id: (название, описание, цвет, категория, модель, стопка, вход, выход_кол-во, время, станции, тир)
# Цена (и очки утилизатора) считается сама из цены сырья — см. _price().
CO = "constructor"
AS = "assembler"
MF = "manufacturer"
FD = "foundry"
COMP = {
    # T0 — руки, костёр, печь
    "cloth": ("Ткань", "Из волокна. Ремни, бинты, кабель.", "#d8cfae", "Материалы", "drop_rope", 50, {"fiber": 3}, 1, 2.0, ["hand", "workbench"], 0),
    "brick": ("Кирпич", "Обожжённая глина. Печи и прочные стены.", "#a8482e", "Материалы", "drop_block", 50, {"clay": 2}, 1, 3.0, ["furnace", "smelter"], 0),
    "stone_block": ("Каменный блок", "Тёсаный камень для фундаментов и печей.", "#a3a19a", "Материалы", "drop_block", 50, {"stone": 3}, 1, 2.0, ["hand", "workbench", "stone_cutter"], 0),
    "charcoal": ("Древесный уголь", "Топливо из брёвен: горит вдвое дольше бревна.", "#2e2a28", "Материалы", "drop_coal", 50, {"log": 2}, 1, 4.0, ["furnace", "coke_oven"], 0),
    "rough_glass": ("Грубое стекло", "Мутное стекло из песка — окна, лампы.", "#cfe6e0", "Материалы", "drop_glass", 50, {"sand": 3}, 1, 3.0, ["furnace", "smelter"], 0),
    # T1 — медь, железо, олово
    "tin_ingot": ("Оловянный слиток", "Олово: для бронзы, жести и припоя.", "#d9dee3", "Материалы", "drop_ingot", 50, {"tin_ore": 1}, 1, 2.0, ["furnace", "smelter"], 1),
    "bronze_ingot": ("Бронзовый слиток", "Сплав 3 меди и 1 олова. Шестерни, подшипники, клапаны.", "#c08a3e", "Материалы", "drop_ingot", 50, {"copper_ingot": 3, "tin_ingot": 1}, 4, 4.0, [FD], 1),
    "cable": ("Кабель", "Провод в изоляции. Для машин и ЛЭП.", "#3a3a40", "Детали", "drop_wire", 100, {"wire": 2, "cloth": 1}, 1, 2.0, [CO, "workshop"], 1),
    "iron_rod": ("Железный прут", "Рамы, винты, роторы.", "#9aa3ad", "Детали", "drop_wire", 100, {"iron_ingot": 1}, 1, 1.5, [CO, "workshop"], 1),
    "screw": ("Винты", "Крепёж для пластин и рам.", "#b8bec7", "Детали", "drop_gear", 200, {"iron_rod": 1}, 4, 1.5, [CO, "workshop"], 1),
    "bronze_gear": ("Бронзовая шестерня", "Не ржавеет: для насосов и клапанов.", "#c08a3e", "Детали", "drop_gear", 50, {"bronze_ingot": 2}, 1, 2.0, [CO, "workshop"], 1),
    "tinplate": ("Жесть", "Лужёная пластина: консервы и корпуса.", "#d0d6dc", "Детали", "drop_plate", 50, {"iron_plate": 1, "tin_ingot": 1}, 2, 2.5, [AS, "workshop"], 1),
    "quicklime": ("Негашёная известь", "Флюс для плавки и сырьё для бетона.", "#efeadc", "Материалы", "drop_stone", 50, {"limestone": 2}, 1, 3.0, ["furnace", "smelter"], 1),
    "reinforced_plate": ("Укреплённая пластина", "Пластина на винтах: каркасы машин.", "#8d96a3", "Детали", "drop_plate", 50, {"iron_plate": 4, "screw": 8}, 1, 6.0, [AS, "workshop"], 1),
    "simple_frame": ("Простая рама", "Каркас из прутьев и пластин.", "#7f8893", "Детали", "drop_box", 50, {"iron_rod": 4, "iron_plate": 2}, 1, 5.0, [AS, "workshop"], 1),
    # T2 — сталь и механика
    "coke": ("Кокс", "Обожжённый уголь: для стали и карбида. Горит жарче угля.", "#2a2b30", "Материалы", "drop_coal", 50, {"coal": 2}, 1, 3.0, ["coke_oven"], 2),
    "steel_beam": ("Стальная балка", "Тяжёлые рамы и фундаменты.", "#7d8796", "Детали", "drop_plate", 50, {"steel": 3}, 1, 4.0, [CO], 2),
    "steel_pipe": ("Стальная труба", "Статоры, клапаны, теплообменники.", "#8a94a3", "Детали", "drop_wire", 50, {"steel": 2}, 1, 3.0, [CO], 2),
    "steel_sheet": ("Стальной лист", "Корпуса тяжёлых машин.", "#9aa4b2", "Детали", "drop_plate", 50, {"steel": 2}, 1, 3.0, [CO], 2),
    "steel_rod": ("Стальной прут", "Пружины и цепи.", "#8c96a4", "Детали", "drop_wire", 100, {"steel": 1}, 1, 2.0, [CO], 2),
    "bearing": ("Подшипник", "Сталь и бронза: всё, что крутится.", "#c9ccd2", "Детали", "drop_gear", 50, {"steel": 1, "bronze_ingot": 1}, 2, 4.0, [AS], 2),
    "spring": ("Пружина", "Поршни, клапаны, механизмы.", "#b0b7c0", "Детали", "drop_wire", 100, {"steel_rod": 1}, 2, 2.0, [CO], 2),
    "rotor": ("Ротор", "Вращающаяся часть мотора.", "#8592a3", "Детали", "drop_gear", 50, {"iron_rod": 5, "screw": 10}, 1, 6.0, [AS], 2),
    "stator": ("Статор", "Неподвижная обмотка мотора.", "#6f7e93", "Детали", "drop_motor", 50, {"steel_pipe": 1, "wire": 8}, 1, 6.0, [AS], 2),
    "modular_frame": ("Модульная рама", "Каркас средних машин.", "#7b8696", "Детали", "drop_box", 50, {"reinforced_plate": 2, "iron_rod": 6}, 1, 8.0, [AS], 2),
    "heavy_frame": ("Тяжёлая рама", "Каркас тяжёлых машин и реакторов.", "#5d6878", "Детали", "drop_box", 20, {"modular_frame": 2, "steel_beam": 2, "steel_pipe": 4}, 1, 12.0, [MF], 2),
    "valve": ("Клапан", "Управляет потоком в трубах.", "#b58a4a", "Детали", "drop_gear", 50, {"bronze_ingot": 2, "steel_pipe": 1}, 1, 4.0, [AS], 2),
    "piston": ("Поршень", "Гидравлика и двигатели.", "#a3acb8", "Детали", "drop_motor", 50, {"steel": 2, "spring": 2}, 1, 4.0, [AS], 2),
    "chain": ("Цепь", "Привод конвейеров и подъёмников.", "#8a929c", "Детали", "drop_rope", 50, {"steel_rod": 2}, 1, 3.0, [CO], 2),
    "lamp_bulb": ("Лампа", "Стекло и проволока: свет для зданий.", "#fff3b0", "Детали", "drop_glass", 50, {"glass": 1, "wire": 2}, 1, 2.0, [AS, "workshop"], 2),
    "crushed_iron": ("Дроблёная железная руда", "Из дробилки: 2 из одной руды; при плавке даёт на 50% больше металла.", "#9e6152", "Руда", "drop_stone", 100, {"iron_ore": 1}, 2, 2.0, ["crusher"], 2),
    "crushed_copper": ("Дроблёная медная руда", "Из дробилки: 2 из одной руды; при плавке даёт на 50% больше металла.", "#f28c38", "Руда", "drop_stone", 100, {"copper_ore": 1}, 2, 2.0, ["crusher"], 2),
    "crushed_tin": ("Дроблёная оловянная руда", "Из дробилки: 2 из одной руды; при плавке даёт на 50% больше металла.", "#c9d0d6", "Руда", "drop_stone", 100, {"tin_ore": 1}, 2, 2.0, ["crusher"], 2),
    # T3 — электроника, алюминий, нефть
    "lubricant": ("Смазка", "Из нефти. Гидравлика и тяжёлые машины.", "#c9a64a", "Материалы", "drop_vial", 50, {"oil": 3}, 2, 3.0, ["refinery"], 3),
    "nickel_ingot": ("Никелевый слиток", "Для нержавеющей стали.", "#b9c2a8", "Материалы", "drop_ingot", 50, {"nickel_ore": 1}, 1, 3.0, ["smelter"], 3),
    "lead_ingot": ("Свинцовый слиток", "Аккумуляторы и защитные экраны.", "#7a8290", "Материалы", "drop_ingot", 50, {"lead_ore": 1}, 1, 3.0, ["smelter"], 3),
    "stainless_steel": ("Нержавеющая сталь", "Сталь с никелем: насосы, теплообменники, ТВЭЛы.", "#c4ccd6", "Материалы", "drop_ingot", 50, {"steel": 2, "nickel_ingot": 1}, 2, 5.0, [FD], 3),
    "silicon": ("Кремний", "Из кварца и угля в дуговой печи. Основа микросхем.", "#7a8796", "Материалы", "drop_crystal", 50, {"quartz": 2, "coal": 1}, 1, 4.0, ["arc_furnace"], 3),
    "gold_wire": ("Золотая проволока", "Контакты микросхем.", "#f2cf4a", "Детали", "drop_wire", 100, {"gold_ore": 1}, 2, 3.0, ["smelter", CO], 3),
    "pcb": ("Печатная плата", "Пластик, медь и кремний: основа электроники.", "#2f8a4a", "Детали", "drop_circuit", 50, {"plastic": 1, "copper_ingot": 2, "silicon": 1}, 1, 6.0, [AS], 3),
    "pump_unit": ("Насосный узел", "Мотор, клапан и нержавейка.", "#4a7ab8", "Детали", "drop_motor", 20, {"motor": 1, "valve": 2, "stainless_steel": 2}, 1, 10.0, [MF], 3),
    "hydraulics": ("Гидравлика", "Поршень на смазке: тяжёлые машины и буры.", "#b04a3a", "Детали", "drop_motor", 20, {"piston": 2, "lubricant": 2, "steel_pipe": 1}, 1, 8.0, [AS], 3),
    "computer": ("Компьютер", "Плата, микросхема и корпус: управление машинами.", "#2a3a4a", "Детали", "drop_box", 20, {"pcb": 2, "circuit": 2, "plastic": 4}, 1, 14.0, [MF], 3),
    "canned_food": ("Консервы", "Еда в жестяной банке: не портится. +40 сытости.", "#c9302c", "Еда", "drop_box", 20, {"tinplate": 1, "berry": 3, "salt": 1}, 2, 4.0, ["kitchen", AS], 3),
    "explosive": ("Взрывчатка", "Порох и кислота: мины, снаряды, проходка.", "#d23a2a", "Материалы", "drop_grenade", 50, {"gunpowder": 2, "sulfuric_acid": 1}, 1, 5.0, ["chem_plant"], 3),
    # T4 — жар и атом
    "tungsten_ingot": ("Вольфрамовый слиток", "Самый тугоплавкий металл. Плавится только в доменной печи.", "#5a606c", "Материалы", "drop_ingot", 50, {"tungsten_ore": 2, "coke": 1}, 1, 6.0, ["blast_furnace"], 4),
    "tungsten_carbide": ("Карбид вольфрама", "Твёрже стали: буровые головки.", "#3e434c", "Материалы", "drop_ingot", 50, {"tungsten_ingot": 1, "coke": 2}, 1, 6.0, [FD], 4),
    "drill_head": ("Буровая головка", "Карбид на стальной основе: буры Mk4–Mk5.", "#8a5ab8", "Детали", "drop_tool", 20, {"tungsten_carbide": 2, "steel": 4}, 1, 10.0, [MF], 4),
    "titanium_ingot": ("Титановый слиток", "Из руды и хлора (соль): лёгкий и прочный.", "#c7d0e3", "Материалы", "drop_ingot", 50, {"titanium_ore": 2, "salt": 1}, 1, 6.0, ["chem_plant", FD], 4),
    "titanium_frame": ("Титановая рама", "Каркас турбин и реакторов.", "#aab6cc", "Детали", "drop_box", 20, {"titanium_ingot": 4, "heavy_frame": 1}, 1, 14.0, [MF], 4),
    "obsidian_plate": ("Обсидиановая плита", "Тёсаный обсидиан.", "#3a2f4a", "Материалы", "drop_block", 50, {"obsidian": 2}, 1, 4.0, ["stone_cutter"], 4),
    "heatproof_block": ("Жаропрочный блок", "Обсидиан с вольфрамом: стенки печей и реакторов.", "#4a3a5a", "Материалы", "drop_block", 50, {"obsidian_plate": 2, "tungsten_ingot": 1}, 1, 6.0, [AS], 4),
    "turbine": ("Турбина", "Титан, подшипники, ротор: генераторы и реакторы.", "#9fb2c8", "Детали", "drop_motor", 10, {"titanium_ingot": 4, "bearing": 4, "rotor": 2}, 1, 16.0, [MF], 4),
    "heat_exchanger": ("Теплообменник", "Нержавейка, медь и трубы: охлаждение реакторов.", "#b87a4a", "Детали", "drop_box", 20, {"stainless_steel": 3, "copper_ingot": 4, "steel_pipe": 4}, 1, 10.0, [AS], 4),
    "coolant": ("Хладагент", "Вода, соль и кислота: охлаждающие модули.", "#6ad0ff", "Материалы", "drop_vial", 50, {"water": 4, "salt": 1, "sulfuric_acid": 1}, 2, 4.0, ["chem_plant"], 4),
    "cooling_module": ("Охлаждающий модуль", "Алюминий и хладагент.", "#8ae0ff", "Детали", "drop_box", 20, {"aluminum_sheet": 2, "coolant": 4}, 1, 8.0, [AS], 4),
    "lead_shield": ("Свинцовый экран", "Свинец и бетон: защита от радиации.", "#5a6270", "Детали", "drop_plate", 20, {"lead_ingot": 4, "concrete": 4}, 1, 6.0, [AS], 4),
    "ai_module": ("ИИ-модуль", "Компьютер и микросхемы: умные машины.", "#3ab8ff", "Детали", "drop_circuit", 10, {"computer": 1, "circuit": 4}, 1, 20.0, [MF], 4),
    # T5 — бездна
    "cut_resonite": ("Огранённый резонит", "Кристалл после кристаллореза: держит огромный заряд.", "#d98cff", "Экзотика", "drop_crystal", 20, {"resonite": 2}, 1, 8.0, ["crystal_cutter"], 5),
    "resonant_capacitor": ("Резонансный конденсатор", "Резонит и аккумулятор.", "#b45cff", "Экзотика", "drop_battery", 20, {"cut_resonite": 1, "battery": 1}, 1, 10.0, [AS], 5),
    "rare_earth_magnet": ("Редкоземельный магнит", "Сильнейший постоянный магнит.", "#4ac0a8", "Детали", "drop_gear", 20, {"rare_earth_ore": 2}, 1, 6.0, [FD], 5),
    "quantum_processor": ("Квантовый процессор", "ИИ-модуль, огранённый резонит, сверхпроводник.", "#7a5cff", "Экзотика", "drop_circuit", 10, {"ai_module": 1, "cut_resonite": 2, "superconductor": 2}, 1, 30.0, [MF], 5),
    "anomaly_stabilizer": ("Стабилизатор аномалии", "Удерживает аномальную материю.", "#ff7ae0", "Экзотика", "drop_core", 10, {"anomaly_matter": 1, "resonite": 4}, 1, 20.0, ["synthesizer"], 5),
    "cloud_core": ("Ядро разгона облаков", "Финальный компонент: открывает самые дальние участки бури.", "#ffe07a", "Экзотика", "drop_core", 5, {"anomaly_stabilizer": 1, "turbine": 1, "quantum_processor": 1}, 1, 40.0, ["synthesizer"], 5),
    "terraform_module": ("Модуль терраформинга", "Ядро разгона в титановой раме — вершина технологий.", "#9aff7a", "Экзотика", "drop_core", 5, {"cloud_core": 1, "titanium_frame": 2}, 1, 60.0, ["synthesizer"], 5),
}

# Новые рецепты для того, что уже было в игре (по справочнику), — старые остаются.
EXTRA = [
    # id, название, вход, выход, время, станции
    ("d17_glass_sand", "Стекло из песка", {"sand": 2, "limestone": 1}, {"glass": 2}, 3.0, ["smelter"]),
    ("d17_concrete_mix", "Бетон (смеситель)", {"limestone": 1, "stone": 2, "water": 2}, {"concrete": 3}, 3.0, ["mixer"]),
    ("d17_steel_coke", "Сталь из руды и кокса", {"iron_ore": 2, "coke": 1}, {"steel": 2}, 4.0, [FD]),
    ("d17_motor", "Электромотор (ротор + статор)", {"rotor": 1, "stator": 1}, {"motor": 1}, 6.0, [AS]),
    ("d17_circuit", "Микросхема (чистый цех)", {"silicon": 1, "gold_wire": 2}, {"circuit": 2}, 6.0, ["clean_room"]),
    ("d17_battery", "Аккумулятор (свинцовый)", {"lead_ingot": 2, "sulfuric_acid": 2, "plastic": 1}, {"battery": 2}, 6.0, [AS]),
    ("d17_alumina", "Глинозём из боксита", {"bauxite": 2, "water": 2}, {"alumina": 4}, 4.0, ["chem_plant"]),
    ("d17_aluminum", "Алюминий из глинозёма", {"alumina": 4, "coal": 1}, {"aluminum_ingot": 2}, 5.0, [FD]),
    ("d17_superconductor", "Сверхпроводник (редкоземы)", {"rare_earth_magnet": 1, "coolant": 2, "copper_ingot": 4}, {"superconductor": 4}, 8.0, [MF]),
    ("d17_fuel_rod", "ТВЭЛ из нержавейки", {"enriched_uranium": 2, "stainless_steel": 2}, {"fuel_rod": 1}, 12.0, [MF]),
    ("d17_iron_crushed", "Железо из дроблёной руды", {"crushed_iron": 4}, {"iron_ingot": 3}, 4.0, ["furnace", "smelter"]),
    ("d17_copper_crushed", "Медь из дроблёной руды", {"crushed_copper": 4}, {"copper_ingot": 3}, 4.0, ["furnace", "smelter"]),
    ("d17_tin_crushed", "Олово из дроблёной руды", {"crushed_tin": 4}, {"tin_ingot": 3}, 4.0, ["furnace", "smelter"]),
    ("d17_planks_saw", "Доски (лесопилка)", {"log": 1}, {"plank": 5}, 1.5, ["sawmill"]),
    ("d17_quicklime_concrete", "Бетон на извести", {"quicklime": 1, "stone": 2}, {"concrete": 3}, 2.5, ["furnace", "smelter", "mixer"]),
    ("d17_gas_canister", "Канистра газа", {"natural_gas": 4, "canister": 1}, {"canister_gas": 1}, 1.0, ["packager"]),
]

# Инструменты и оружие по тирам (справочник: кирки камень → медь → бронза → железо → сталь)
GEAR = [
    # id, название, описание, цвет, модель, поля, вход, станции, тир
    ("copper_pickaxe", "Медная кирка", "Втрое быстрее рук. Берёт руду пещерного слоя.", "#d9823a", "drop_pickaxe",
     {"tool": "pickaxe", "power": 3.0, "durability": 220}, {"plank": 2, "copper_ingot": 4, "rope": 1}, ["workbench"], 1),
    ("bronze_pickaxe", "Бронзовая кирка", "Вчетверо быстрее рук, не тупится так быстро.", "#c08a3e", "drop_pickaxe",
     {"tool": "pickaxe", "power": 4.0, "durability": 500}, {"plank": 2, "bronze_ingot": 4, "rope": 1}, ["workbench"], 1),
    ("steel_pickaxe", "Стальная кирка", "Вшестеро быстрее рук. Берёт руду магматического пояса.", "#8c96a4", "drop_pickaxe",
     {"tool": "pickaxe", "power": 6.0, "durability": 900}, {"plank": 2, "steel": 4, "cloth": 1}, ["workbench", "workshop"], 2),
    ("titanium_pickaxe", "Титановая кирка", "Восьмикратная скорость, почти вечная.", "#c7d0e3", "drop_pickaxe",
     {"tool": "pickaxe", "power": 8.0, "durability": 2000}, {"titanium_ingot": 4, "steel_rod": 2, "cloth": 1}, ["workshop"], 4),
    ("tungsten_pickaxe", "Вольфрамовая кирка", "Десятикратная скорость. Берёт резонит и редкоземы бездны.", "#6a5a9a", "drop_pickaxe",
     {"tool": "pickaxe", "power": 10.0, "durability": 3000}, {"tungsten_carbide": 3, "titanium_ingot": 2, "cloth": 1}, ["workshop"], 4),
    ("bronze_sword", "Бронзовый меч", "Крепче железного.", "#c08a3e", "drop_sword",
     {"weapon": "melee", "damage": 38, "range": 3.0, "rate": 0.55, "durability": 400}, {"bronze_ingot": 4, "plank": 1, "cloth": 1}, ["workbench", "workshop"], 1),
    ("steel_cleaver", "Стальной тесак", "Тяжёлый широкий клинок.", "#9aa4b2", "drop_sword",
     {"weapon": "melee", "damage": 55, "range": 3.2, "rate": 0.6, "durability": 700}, {"steel": 5, "plank": 1, "cloth": 1}, ["workshop"], 2),
    ("obsidian_blade", "Обсидиановый клинок", "Острый как стекло, режет броню роботов.", "#3a2f4a", "drop_sword",
     {"weapon": "melee", "damage": 80, "range": 3.2, "rate": 0.5, "durability": 900}, {"obsidian_plate": 3, "titanium_ingot": 1, "cloth": 1}, ["workshop"], 4),
    ("resonant_blade", "Резонансный клинок", "Клинок из резонита: разряд при каждом ударе.", "#c25cff", "drop_sword",
     {"weapon": "melee", "damage": 130, "range": 3.4, "rate": 0.45, "durability": 2000}, {"cut_resonite": 2, "titanium_ingot": 2, "superconductor": 1}, ["workshop"], 5),
    ("bandage", "Бинт", "Быстро останавливает кровь: +20 здоровья.", "#f2f2ee", "drop_medkit",
     {"heal": 20}, {"cloth": 2}, ["hand", "workbench"], 0),
    ("gas_mask", "Противогаз", "Защищает от газа и кислотного дождя (как зонтик от кислоты).", "#4a5a4a", "drop_suit",
     {"durability": 600, "outdoor_guard": 0.8, "guard_events": ["acid_rain", "dense_fog"], "guard_wear": 0.25}, {"rubber": 2, "rough_glass": 1, "cloth": 2}, ["workshop"], 3),
    ("ration", "Сухпаёк", "Не портится: +60 сытости.", "#a88a5a", "drop_box",
     {"food": 60, "heal": 5}, {"canned_food": 1, "berry": 2}, ["kitchen", "workbench"], 3),
]


def _price(items, inp, n_out, time):
    tot = 0.0
    for k, v in inp.items():
        tot += float(items.get(k, {}).get("price", 2)) * v
    return max(1, int(round(tot / max(1, n_out) * 1.15 + time * 0.4)))


def apply(models, buildings, items, resources, recipes, settings, world, tech, enemies):
    _catalog()
    # --- сырьё
    base_price = {"clay": 1, "sand": 1, "tin_ore": 2, "limestone": 2, "bauxite": 4, "nickel_ore": 4, "lead_ore": 4, "salt": 3, "gold_ore": 6,
                  "natural_gas": 3, "tungsten_ore": 8, "titanium_ore": 8, "obsidian": 6, "resonite": 20, "rare_earth_ore": 16, "anomaly_matter": 300}
    for iid, (name, desc, col, cat, model, stack) in RAW.items():
        if iid in items:
            continue
        d = {"name": name, "desc": desc, "color": col, "category": cat, "stack": stack, "price": base_price.get(iid, 2), "model": model, "scan": 5}
        if iid == "natural_gas":
            d["fluid"] = True
            d["fuel"] = 14
            d["scan"] = 0
        items[iid] = d
    if "canister_gas" not in items:
        items["canister_gas"] = {"name": "Канистра газа", "desc": "Природный газ в канистре: едет по лентам, горит в генераторах.", "color": "#7ac0a0",
                                 "category": "Жидкости в таре", "stack": 20, "price": 14, "model": "drop_canister", "fuel": 60, "scan": 0}

    # --- компоненты (порядок в словаре = порядок цепочки, цена считается по уже известным)
    tier_of = {}
    for iid, (name, desc, col, cat, model, stack, inp, n, t, st, tier) in COMP.items():
        tier_of[iid] = tier
        if iid not in items:
            items[iid] = {"name": name, "desc": desc, "color": col, "category": cat, "stack": stack, "price": _price(items, inp, n, t), "model": model, "scan": 5}
        rid = iid if iid not in recipes else "d17_" + iid
        recipes[rid] = {"name": name, "in": dict(inp), "out": {iid: n}, "time": t, "stations": list(st)}
    items["charcoal"]["fuel"] = 24
    items["coke"]["fuel"] = 45
    items["canned_food"].update({"food": 40, "heal": 5})
    for rid, name, inp, out, t, st in EXTRA:
        recipes[rid] = {"name": name, "in": dict(inp), "out": dict(out), "time": t, "stations": list(st)}
    gear_tier = {}
    for iid, name, desc, col, model, fields, inp, st, tier in GEAR:
        gear_tier[iid] = tier
        if iid not in items:
            d = {"name": name, "desc": desc, "color": col, "category": "Инструменты" if fields.get("tool") else ("Оружие" if fields.get("weapon") else ("Еда" if "food" in fields else "Снаряжение")),
                 "stack": 1 if (fields.get("tool") or fields.get("weapon") or fields.get("durability")) else 20, "price": _price(items, inp, 1, 3.0), "model": model, "scan": 0}
            d.update(fields)
            items[iid] = d
        recipes[iid if iid not in recipes else "d17_" + iid] = {"name": name, "in": dict(inp), "out": {iid: 1}, "time": 3.0, "stations": list(st)}

    # --- залежи («слои» = кольца от старта; глубокие скрыты до технологии)
    # item, цвет, пятен, у старта, мин. расстояние, прочность руками, нужна кирка (мощность), нужен бур (тир), жидкость
    DEP = [
        ("clay", "#b0603a", 18, 2, 0, 20, 0, 1, False),
        ("sand", "#e0cc8a", 18, 2, 0, 15, 0, 1, False),
        ("tin_ore", "#c9d0d6", 22, 1, 20, 25, 2, 1, False),
        ("limestone", "#d8d2bf", 20, 1, 20, 25, 2, 1, False),
        ("bauxite", "#c46a3c", 16, 0, 40, 35, 3, 1, False),
        ("nickel_ore", "#9fae8a", 12, 0, 40, 35, 3, 1, False),
        ("lead_ore", "#6a7280", 12, 0, 40, 35, 3, 1, False),
        ("salt", "#f1efe8", 12, 0, 40, 30, 3, 1, False),
        ("gold_ore", "#e8c33a", 9, 0, 50, 40, 3, 1, False),
        ("natural_gas", "#b9e6d0", 8, 0, 45, 25, 0, 1, True),
        ("tungsten_ore", "#4a4f5c", 9, 0, 70, 60, 6, 2, False),
        ("titanium_ore", "#b9c3d9", 9, 0, 70, 60, 6, 2, False),
        ("obsidian", "#2a2236", 9, 0, 70, 55, 6, 2, False),
        ("resonite", "#c25cff", 6, 0, 100, 90, 10, 3, False),
        ("rare_earth_ore", "#5fd0b8", 6, 0, 100, 80, 10, 3, False),
    ]
    have = {d.get("item") for d in world.get("deposits", [])}
    for it, col, patches, near, mind, hp, pw, mt, fluid in DEP:
        if it in have:
            continue
        d = {"resource": "", "item": it, "color": col, "patches": patches, "size_min": 2.0, "size_max": 3.5, "near_start": near,
             "drops": [], "cells": 2 if fluid else 1, "hand": not fluid, "hand_hp": float(hp), "hand_tool": "pickaxe", "rocks_around": 0,
             "marker": "dep_" + it}
        if mind:
            d["min_dist"] = mind
        if pw:
            d["hand_power"] = float(pw)
        if mt > 1:
            d["miner_tier"] = mt
        if it in ("tin_ore", "limestone"):
            d["near_ring"] = 2
            d["ring_width"] = 14.0
        world.setdefault("deposits", []).append(d)
        models["dep_" + it] = marker_model(items[it]["name"], col)
    # руда с прожилками богаче у дальних залежей (как в справочнике: на поверхности бедные узлы, в глубине богатые)
    pur = settings.get("purity")
    if isinstance(pur, dict):
        pur.setdefault("far_bonus", 0.35)

    # --- модели новых зданий из каталога (подробные, со своими анимациями)
    for mid in ("cb_foundry", "cb_crusher", "cb_mixer", "cb_kiln_mk2", "cb_sawmill", "cb_lathe", "cb_press_mk2", "cb_chip_fab", "cb_printer3d_mk3",
                "cb_foundry_mk4", "cb_crystal_grower", "cb_crystal_grower_mk5", "cb_geothermal", "cb_compactor", "cb_trade_post", "cb_kiln_mk4",
                "cb_medicine_cabinet", "cb_fridge", "cb_searchlight", "cb_gas_turbine", "cb_electrolyzer"):
        _cat_model(models, mid)

    def B(id, name, desc, cat, beh, cost, model, hp, size=1, **params):
        if not models.get(model):
            model = "assembler"
        buildings[id] = {"name": name, "desc": desc, "category": cat, "behavior": beh, "cost": cost, "model": model, "hp": hp, "size": size, "params": params, "sounds": {}}
    B("foundry", "Литейный цех", "Сплавы из двух входов: бронза, сталь из руды и кокса, нержавейка, алюминий, карбид. Нужна энергия.", "production", "crafter",
      {"iron_plate": 10, "brick": 20, "gear": 4}, "cb_foundry", 420, station=FD, speed=1.0, power=10, tier=1, in_slots=3, heat=10, heat_radius=3)
    B("constructor", "Конструктор", "1 вход → 1 выход: прутья, винты, балки, трубы, листы, пружины. Нужна энергия.", "production", "crafter",
      {"iron_plate": 6, "iron_rod": 6, "wire": 6}, "cb_press_mk2", 350, station=CO, speed=1.0, power=4, tier=1)
    B("manufacturer", "Производитель", "4 входа → 1 выход: тяжёлые рамы, компьютеры, турбины, ИИ-модули. Нужна энергия.", "production", "crafter",
      {"modular_frame": 4, "motor": 4, "steel_beam": 10, "cable": 20}, "cb_printer3d_mk3", 600, size=2, station=MF, speed=1.0, power=40, tier=2, in_slots=4)
    B("coke_oven", "Коксовая печь", "Уголь → кокс и брёвна → древесный уголь. Работает на топливе, без электричества.", "production", "crafter",
      {"brick": 30, "iron_plate": 4}, "cb_kiln_mk2", 400, station="coke_oven", speed=1.0, power=0, fuel=True, heat=14, heat_radius=3)
    B("crusher", "Дробилка", "Руда → 2 дроблёной руды. При плавке дроблёная руда даёт на 50% больше металла. Нужна энергия.", "production", "crafter",
      {"steel": 8, "gear": 6, "motor": 1}, "cb_crusher", 420, station="crusher", speed=1.0, power=12, tier=2)
    B("mixer", "Смеситель", "Твёрдое + жидкость: бетон из известняка, камня и воды (вода по трубам). Нужна энергия.", "production", "crafter",
      {"iron_plate": 8, "gear": 4, "motor": 1}, "cb_mixer", 400, station="mixer", speed=1.0, power=8, pipes=True, in_slots=3)
    B("arc_furnace", "Дуговая печь", "Кремний из кварца и угля. Много энергии.", "production", "crafter",
{"steel_sheet": 10, "cable": 10, "brick": 20}, "cb_kiln_mk4", 500, station="arc_furnace", speed=1.0, power=30, tier=3, heat=16, heat_radius=4)
    B("clean_room", "Чистый цех", "Микросхемы из кремния и золотой проволоки — вдвое выгоднее старого рецепта.", "production", "crafter",
{"steel_sheet": 10, "glass": 20, "motor": 2}, "cb_chip_fab", 500, station="clean_room", speed=1.0, power=25, tier=3)
    B("blast_furnace", "Доменная печь", "Вольфрам из руды и кокса. Огромный жар — нужна энергия и топливо.", "production", "crafter",
{"brick": 60, "steel_beam": 10, "stainless_steel": 10}, "cb_foundry_mk4", 900, size=2, station="blast_furnace", speed=1.0, power=60, fuel=True, tier=4, heat=24, heat_radius=5)
    B("crystal_cutter", "Кристаллорез", "Гранит резонит. Нужна энергия.", "production", "crafter",
      {"titanium_ingot": 10, "tungsten_carbide": 6, "computer": 2}, "cb_crystal_grower", 600, station="crystal_cutter", speed=1.0, power=80, tier=5)
    B("synthesizer", "Синтезатор", "Финальные компоненты: стабилизатор аномалии, ядро разгона облаков, модуль терраформинга.", "production", "crafter",
      {"titanium_frame": 4, "ai_module": 2, "superconductor": 10}, "cb_crystal_grower_mk5", 1200, size=2, station="synthesizer", speed=1.0, power=200, tier=5, in_slots=4)
    B("sawmill", "Лесопилка", "Бревно → 5 досок (на верстаке — 3). Нужна энергия.", "production", "crafter",
      {"plank": 10, "iron_ingot": 6, "gear": 2}, "cb_sawmill", 300, station="sawmill", speed=1.0, power=4)
    B("stone_cutter", "Камнерез", "Каменные блоки и обсидиановые плиты. Нужна энергия.", "production", "crafter",
      {"stone_block": 10, "iron_plate": 4, "gear": 2}, "cb_lathe", 300, station="stone_cutter", speed=1.0, power=4)
    B("gas_extractor", "Газовый экстрактор", "Ставится на газовый карман (бирюзовое пятно) и качает природный газ в трубы.", "fluids", "miner",
{"steel": 8, "valve": 4, "motor": 2}, "cb_electrolyzer", 450, size=2, period=1.0, power=12, any_ground=True, extracts="fluid", pipes=True)
    B("geothermal", "Геотермальная станция", "Даёт 180 энергии без топлива — жар магматического пояса.", "energy", "generator",
      {"heat_exchanger": 4, "steel_beam": 10, "heatproof_block": 10}, "cb_geothermal", 900, power=180, radius=10)
    B("resonance_reactor", "Резонансный реактор", "Финальная энергия: 1500 от огранённого резонита.", "energy", "generator",
      {"titanium_frame": 4, "resonant_capacitor": 6, "cooling_module": 6}, "cb_crystal_grower_mk5", 2000, size=2, power=1500, radius=16, fuels=["cut_resonite"], burn_mult=1.0, fuel_slots=2)
    B("fridge", "Ледник", "Хранит еду: 20 стаков. Принимает предметы с лент.", "storage", "storage", {"tinplate": 6, "coolant": 2, "motor": 1}, "cb_fridge", 270, slots=20)
    B("medicine_cabinet", "Аптечный шкаф", "Хранит лекарства и снаряжение: 12 стаков.", "storage", "storage", {"glass": 2, "iron_plate": 3}, "cb_medicine_cabinet", 220, slots=12)
    B("searchlight", "Прожектор", "Светит далеко: ночная оборона базы.", "defense", "decor", {"steel": 4, "lamp_bulb": 2, "cable": 2}, "cb_searchlight", 300, power=3, light=1)
    # генераторы жгут природный газ
    for gid in ("fuel_generator", "gas_turbine"):
        if gid in buildings:
            f = buildings[gid]["params"].setdefault("fuels", [])
            for x in ("natural_gas", "canister_gas"):
                if x not in f:
                    f.append(x)
    if "coal_generator" in buildings:
        f = buildings["coal_generator"]["params"].setdefault("fuels", [])
        for x in ("charcoal", "coke"):
            if f and x not in f:
                f.append(x)
    for sid, snd in (("foundry", "work_smelt"), ("coke_oven", "work_smelt"), ("crusher", "work_crush"), ("mixer", "work_bubble"), ("arc_furnace", "work_electric"),
                     ("clean_room", "work_assembly"), ("blast_furnace", "work_smelt"), ("crystal_cutter", "work_electric"), ("synthesizer", "work_electric"),
                     ("sawmill", "work_saw"), ("stone_cutter", "work_saw"), ("constructor", "work_press"), ("manufacturer", "work_assembly"),
                     ("gas_extractor", "work_pump"), ("geothermal", "work_bubble"), ("resonance_reactor", "work_electric")):
        buildings[sid]["sounds"] = {"work": snd}

    # --- утилизатор за очки, магазин утилизации, разгонитель облаков
    items["sink_coupon"] = {"name": "Купон утилизации", "desc": "Утилизатор выдаёт купон за каждые 100 очков. Тратится в магазине утилизации и на расширение зоны.",
                            "color": "#ff9a2a", "category": "Особое", "stack": 500, "price": 0, "model": "drop_box", "scan": 0, "no_sink": True}
    models["sink"] = M("Утилизатор очков", [
        P("box", (1.9, 0.25, 1.9), (0, 0.125, 0), "#4a4f58", "concrete"),
        P("cylinder", (1.5, 1.6, 1.5), (0, 1.05, 0), "#e07a1f", "paint", seg=16),
        P("cylinder", (1.62, 0.12, 1.62), (0, 1.9, 0), "#2f3238", "dark", seg=16),
        P("cylinder", (1.1, 0.08, 1.1), (0, 1.97, 0), "#ff6a20", "glow", anim="pulse", seg=16),
        P("box", (0.5, 0.7, 0.9), (0.95, 0.6, 0), "#3a3d44", "dark"),
        P("box", (0.06, 0.3, 0.6), (1.21, 0.75, 0), "#ffd23f", "glow", anim="pulse"),
        P("cylinder", (0.18, 0.5, 0.18), (-0.55, 2.2, 0.4), "#8c949e", "metal", anim="spin", seg=8),
        P("cylinder", (0.18, 0.5, 0.18), (0.4, 2.2, -0.5), "#8c949e", "metal", anim="spin", seg=8),
    ], "Утилизация")
    buildings["sink"] = {"name": "Утилизатор очков", "desc": "Принимает с ленты ЛЮБОЙ предмет, уничтожает его и начисляет очки по его ценности (поле «Цена» предмета). За каждые 100 очков — купон утилизации на выход. Чем выше тир, тем выгоднее сжигать.",
                         "category": "special", "behavior": "decor", "cost": {"iron_plate": 20, "motor": 2, "wire": 20}, "model": "sink", "hp": 500, "size": 1,
                         "params": {"power": 15}, "blocks": [{"type": "sink", "k": 1.0, "coupon": 100, "items": [], "needs_power": True}], "sounds": {"work": "work_crush"}}
    buildings["sink_shop"] = {"name": "Магазин утилизации", "desc": "Купоны → чертежи, расходники, редкое сырьё. Подойдите и нажмите E.", "category": "stations", "behavior": "station",
                              "cost": {"plank": 10, "iron_plate": 6}, "model": "cb_trade_post" if "cb_trade_post" in models else "market", "hp": 300, "size": 1,
                              "params": {"station": "sink_shop"}, "sounds": {}}
    shop = [("berry", 10, 1), ("medkit", 2, 2), ("canned_food", 4, 2), ("ammo", 50, 2), ("fuel_rod", 1, 15), ("crystal", 2, 6), ("monster_core", 1, 10),
            ("resonite", 2, 8), ("rare_earth_ore", 2, 8), ("anomaly_matter", 1, 60), ("bp_plasma_turret", 1, 40), ("bp_teleporter", 1, 60), ("lucky_box", 1, 3)]
    for iid, n, c in shop:
        if iid in items:
            recipes["shop_" + iid] = {"name": "Купить: %s ×%d" % (items[iid]["name"], n), "in": {"sink_coupon": c}, "out": {iid: n}, "time": 0.5, "stations": ["sink_shop"]}
    models["cloud_breaker"] = M("Разгонитель облаков", [
        P("box", (1.9, 0.3, 1.9), (0, 0.15, 0), "#3a3f48", "concrete"),
        P("cylinder", (0.7, 3.4, 0.7), (0, 2.0, 0), "#9aa4b2", "metal", seg=10),
        P("cylinder", (1.6, 0.18, 1.6), (0, 3.6, 0), "#2f3238", "dark", seg=16, anim="spin"),
        P("box", (0.12, 0.12, 1.8), (0, 3.75, 0), "#7ac8ff", "glow", anim="spin"),
        P("box", (1.8, 0.12, 0.12), (0, 3.75, 0), "#7ac8ff", "glow", anim="spin"),
        P("sphere", (0.6, 0.6, 0.6), (0, 4.1, 0), "#bfe8ff", "glow", anim="pulse"),
        P("box", (0.9, 0.9, 0.9), (0.6, 0.75, 0.6), "#e07a1f", "paint"),
    ], "Утилизация")
    buildings["cloud_breaker"] = {"name": "Разгонитель облаков", "desc": "Сам расширяет зону: подвозите лентой то, что просит следующее расширение (видно в окне здания), — когда всё набрано, буря отступает на шаг. Нужна энергия.",
                                  "category": "special", "behavior": "decor", "cost": {"steel": 10, "motor": 2, "circuit": 4}, "model": "cloud_breaker", "hp": 600, "size": 1,
                                  "params": {"power": 20}, "blocks": [{"type": "zone_push", "needs_power": True}], "sounds": {"work": "work_electric"}}

    # --- расширение зоны: кольца по справочнику (дальше — сырьё всё более глубоких слоёв + купоны)
    zs = settings.get("zone")
    if isinstance(zs, dict):
        zs["steps"] = [
            {"cost": {"log": 20, "stone": 20}}, {"cost": {"plank": 20, "stone": 40}}, {"cost": {"plank": 30, "stone_block": 20, "copper_ingot": 10}},
            {"cost": {"iron_ingot": 40, "copper_ingot": 20, "brick": 20}}, {"cost": {"iron_plate": 30, "wire": 30, "bronze_ingot": 10}},
            {"cost": {"iron_plate": 40, "concrete": 30, "sink_coupon": 2}}, {"cost": {"reinforced_plate": 10, "concrete": 60, "sink_coupon": 4}},
            {"cost": {"steel_beam": 20, "motor": 6, "sink_coupon": 6}}, {"cost": {"steel_beam": 30, "modular_frame": 6, "sink_coupon": 10}},
            {"cost": {"pcb": 20, "aluminum_ingot": 30, "battery": 10, "sink_coupon": 15}}, {"cost": {"computer": 6, "stainless_steel": 30, "sink_coupon": 20}},
            {"cost": {"ai_module": 4, "titanium_ingot": 40, "sink_coupon": 30}}, {"cost": {"turbine": 4, "tungsten_ingot": 30, "sink_coupon": 40}},
            {"cost": {"cloud_core": 1, "sink_coupon": 60}},
        ]
        zs["patch_cost_k"] = zs.get("patch_cost_k", 0.6)

    # --- аномальная материя — с боссов осад
    for eid, e in enemies.items():
        if e.get("boss"):
            drops = e.setdefault("drops", [])
            if not any(d.get("item") == "anomaly_matter" for d in drops):
                drops.append({"item": "anomaly_matter", "chance": 1.0, "min": 1, "max": 2, "on": "break"})

    # --- дерево открытий
    def TN(id, name, tier, order, icon, desc, cost, unlocks, requires, research=20):
        tech[id] = {"name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost, "unlocks": unlocks, "requires": requires, "research": research}

    def comp_of(tier):
        return [k for k, t in tier_of.items() if t == tier]
    t1 = [r for r in comp_of(1)]
    TN("t_metal", "Бронза и детали", 1, 6, "bronze_ingot", "Литейный цех и конструктор. Олово → бронза; прутья, винты, жесть, укреплённые пластины, рамы, кабель. Медная и бронзовая кирки, бронзовый меч.",
       {"iron_ingot": 20, "copper_ingot": 15, "tin_ingot": 5}, {"buildings": ["foundry", "constructor", "sawmill", "stone_cutter"],
                                                                 "recipes": [r for r in t1 if r != "tin_ingot"] + ["copper_pickaxe", "bronze_pickaxe", "bronze_sword"]}, ["t_workshop"], 5)
    TN("t_sink", "Утилизация", 1, 7, "sink", "Утилизатор очков (сжигает любые предметы и выдаёт купоны), магазин утилизации, разгонитель облаков.",
       {"iron_plate": 15, "wire": 15}, {"buildings": ["sink", "sink_shop", "cloud_breaker"]}, ["t_mining"], 5)
    TN("t_steel2", "Сталь и механика", 2, 8, "bearing", "Коксовая печь, дробилка (+50% металла), смеситель, производитель. Балки, трубы, листы, подшипники, роторы и статоры, рамы, клапаны, поршни. Стальная кирка и тесак.",
       {"steel": 30, "bronze_ingot": 20, "gear": 20}, {"buildings": ["coke_oven", "crusher", "mixer", "manufacturer", "searchlight", "fridge", "medicine_cabinet"],
                                                       "recipes": comp_of(2) + ["d17_steel_coke", "d17_motor", "d17_iron_crushed", "d17_copper_crushed", "d17_tin_crushed", "d17_concrete_mix", "steel_pickaxe", "steel_cleaver"]},
       ["t_coal", "t_metal"], 15)
    TN("t_geo2", "Геология II", 3, 8, "bauxite", "Мир меняется: проявляются залежи слоя «Глубины» — боксит, никель, свинец, соль, золото и газовые карманы. Нужна железная кирка.",
       {"steel_beam": 10, "motor": 4, "bearing": 10}, {"deposits": ["bauxite", "nickel_ore", "lead_ore", "salt", "gold_ore", "natural_gas"], "buildings": ["gas_extractor"],
                                                       "recipes": ["d17_gas_canister"]}, ["t_steel2", "t_mk2"], 25)
    TN("t_electro", "Электроника", 4, 8, "pcb", "Дуговая печь и чистый цех: кремний, золотая проволока, печатные платы, микросхемы вдвое выгоднее. Нержавейка, свинец, аккумуляторы, насосный узел, гидравлика, компьютеры, консервы, взрывчатка, противогаз.",
       {"steel_sheet": 20, "copper_ingot": 40, "gold_ore": 10}, {"buildings": ["arc_furnace", "clean_room"],
                                                                 "recipes": comp_of(3) + ["d17_circuit", "d17_battery", "d17_alumina", "d17_aluminum", "gas_mask", "ration"]}, ["t_geo2", "t_oil"], 40)
    TN("t_geo3", "Геология III", 5, 8, "tungsten_ore", "Магматический пояс: вольфрам, титан и обсидиан проявляются. Добывать — стальной киркой или буром Mk2+. Доменная печь, геотермальная станция.",
       {"computer": 4, "stainless_steel": 30, "hydraulics": 6}, {"deposits": ["tungsten_ore", "titanium_ore", "obsidian"], "buildings": ["blast_furnace", "geothermal"],
                                                                  "recipes": comp_of(4) + ["d17_fuel_rod", "titanium_pickaxe", "tungsten_pickaxe", "obsidian_blade"]}, ["t_electro"], 60)
    TN("t_geo4", "Аномальная геология", 7, 8, "resonite", "Бездна: резонит и редкоземельная руда (вольфрамовой киркой или буром Mk3+). Кристаллорез, синтезатор, резонансный реактор, ядро разгона облаков. Аномальная материя — с боссов осад.",
       {"ai_module": 4, "turbine": 4, "anomaly_matter": 2}, {"deposits": ["resonite", "rare_earth_ore"], "buildings": ["crystal_cutter", "synthesizer", "resonance_reactor"],
                                                              "recipes": comp_of(5) + ["d17_superconductor", "resonant_blade"]}, ["t_geo3"], 120)
    # ранние вещи (T0, олово, кирпич, бинт) — без исследования, как в справочнике (костёр и верстак)
