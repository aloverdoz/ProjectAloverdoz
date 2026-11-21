# Каталог — ПРЕДМЕТЫ, часть 2: еда, инструменты, оружие, броня, медицина, семена, дерево, части монстров, разное.
import math
from art_kit import P, shade
from cat_items import I, R, MOD, items, W, WOOD_H, WOOD_D, STEEL, DARK, BRASS, LEATHER, m_bag, m_jar, m_bottle, m_dust

GREEN, RED = "#3f8f3a", "#c03020"


# ================================================================== еда
def f_round(r=0.24, leaf=True, stem=True):
    a = [P("sphere", (r, r * 0.92, r), (0, 0, 0), W, "paint", seg=12)]
    if stem:
        a.append(P("cylinder", (0.025, 0.08, 0.025), (0, r * 0.5, 0), WOOD_D, "wood", tint=False, seg=5))
    if leaf:
        a.append(P("sphere", (0.12, 0.02, 0.06), (0.05, r * 0.52, 0), GREEN, "paint", tint=False, rot=(0, 0, 20), seg=6))
    a.append(P("sphere", (r * 0.35, r * 0.2, r * 0.35), (r * 0.18, r * 0.25, r * 0.22), "#ffffff", "glass", tint=False, seg=6))
    return a


def f_long(l=0.36, r=0.1, tip=GREEN):
    return [P("capsule", (r, l, r), (0, 0, 0), W, "paint", rot=(0, 0, 80), seg=10), P("cone", (0.1, 0.12, 0.1), (-l * 0.55, 0.06, 0), tip, "paint", tint=False, rot=(0, 0, 80), seg=6)]


def f_bunch():
    a = []
    for k in range(9):
        ang = k * 2.1
        r = 0.04 + (k % 3) * 0.04
        a.append(P("sphere", (0.09, 0.09, 0.09), (math.cos(ang) * r, 0.12 - k * 0.022, math.sin(ang) * r), W, "paint", seg=8))
    return a + [P("cylinder", (0.02, 0.18, 0.02), (0, 0.24, 0), WOOD_D, "wood", tint=False, seg=4), P("sphere", (0.14, 0.02, 0.09), (0.06, 0.28, 0), GREEN, "paint", tint=False, seg=6)]


def f_leafy():
    a = [P("sphere", (0.3, 0.24, 0.3), (0, 0, 0), W, "paint", seg=10)]
    for k in range(6):
        a.append(P("sphere", (0.22, 0.04, 0.16), (math.cos(k) * 0.1, 0.05 + (k % 2) * 0.04, math.sin(k) * 0.1), shade("#6fc04a", 0.85 + 0.05 * (k % 3)), "paint", tint=False, rot=(25, k * 60, 0), seg=8))
    return a


def f_mush():
    return [P("cylinder", (0.08, 0.14, 0.08), (0, -0.04, 0), "#f2ead6", "paint", tint=False, seg=8), P("sphere", (0.28, 0.14, 0.28), (0, 0.06, 0), W, "paint", seg=12)] + \
        [P("sphere", (0.04, 0.02, 0.04), (math.cos(k * 1.3) * 0.08, 0.12, math.sin(k * 1.3) * 0.08), "#f2f2e6", "paint", tint=False, seg=5) for k in range(5)]


def f_meat():
    return [P("sphere", (0.36, 0.18, 0.26), (0, 0, 0), W, "paint", seg=10), P("sphere", (0.3, 0.14, 0.2), (0.02, 0.03, 0), shade("#ffffff", 1.0), "paint", seg=8),
            P("cylinder", (0.05, 0.22, 0.05), (0.24, 0.02, 0), "#f2ead6", "paint", tint=False, rot=(0, 0, 90), seg=6),
            P("sphere", (0.08, 0.08, 0.08), (0.36, 0.02, 0), "#f2ead6", "paint", tint=False, seg=6)]


def f_fish():
    return [P("sphere", (0.4, 0.16, 0.1), (0, 0, 0), W, "metal", seg=10), P("prism", (0.14, 0.16, 0.02), (-0.24, 0, 0), W, "metal", rot=(0, 0, 90)),
            P("sphere", (0.03, 0.03, 0.03), (0.14, 0.03, 0.045), "#101010", "dark", tint=False, seg=5), P("prism", (0.12, 0.08, 0.02), (0, 0.09, 0), W, "metal")]


def f_bread():
    return [P("capsule", (0.24, 0.42, 0.2), (0, 0, 0), W, "paint", rot=(0, 0, 90), seg=10)] + \
        [P("box", (0.03, 0.02, 0.18), (-0.1 + k * 0.1, 0.1, 0), shade("#ffffff", 0.8), "paint", tint=False, rot=(0, 25, 0)) for k in range(3)]


def f_bowl():
    return [P("cylinder", (0.36, 0.12, 0.36), (0, -0.04, 0), "#8a5a30", "wood", tint=False, top=1.35, seg=14), P("cylinder", (0.4, 0.02, 0.4), (0, 0.03, 0), W, "paint", seg=14),
            P("sphere", (0.06, 0.04, 0.06), (0.07, 0.05, 0.05), "#e08a4a", "paint", tint=False, seg=5), P("sphere", (0.05, 0.04, 0.05), (-0.08, 0.05, -0.02), GREEN, "paint", tint=False, seg=5),
            P("cylinder", (0.03, 0.34, 0.03), (0.12, 0.12, 0), "#d9c9a0", "wood", tint=False, rot=(0, 0, -40), seg=5)]


def f_can():
    return [P("cylinder", (0.22, 0.26, 0.22), (0, 0, 0), "#b8bec7", "metal", tint=False, seg=14), P("cylinder", (0.225, 0.18, 0.225), (0, 0, 0), W, "paint", seg=14),
            P("torus", (0.22, 0.05, 0.22), (0, 0.13, 0), "#9aa3ad", "metal", tint=False, seg=14), P("torus", (0.06, 0.2, 0.03), (0.04, 0.14, 0), "#c0c4cc", "metal", tint=False, seg=8)]


def f_pie():
    return [P("cylinder", (0.4, 0.1, 0.4), (0, 0, 0), "#d9a050", "paint", tint=False, top=1.15, seg=16), P("cylinder", (0.38, 0.03, 0.38), (0, 0.055, 0), W, "paint", seg=16)] + \
        [P("box", (0.32, 0.02, 0.03), (0, 0.075, 0), "#d9a050", "paint", tint=False, rot=(0, k * 45, 0)) for k in range(4)]


def f_drink():
    return m_bottle("#c03020", True)


def f_cheese():
    return [P("prism", (0.34, 0.2, 0.3), (0, 0, 0), W, "paint", rot=(90, 0, 0))] + \
        [P("sphere", (0.05, 0.05, 0.02), (-0.04 + k * 0.05, -0.02 + (k % 2) * 0.06, 0.1), shade("#f2c440", 0.8), "paint", tint=False, seg=6) for k in range(3)]


def f_egg():
    return [P("sphere", (0.18, 0.24, 0.18), (x, 0, z), W, "paint", seg=10) for x, z in ((0, 0), (0.15, 0.06), (-0.12, 0.08))] + \
        [P("cylinder", (0.44, 0.06, 0.34), (0, -0.12, 0.03), "#c49a6c", "cloth", tint=False, seg=10)]


FOOD_SHAPES = {"round": f_round, "long": f_long, "bunch": f_bunch, "leafy": f_leafy, "mush": f_mush, "meat": f_meat, "fish": f_fish,
               "bread": f_bread, "bowl": f_bowl, "can": f_can, "pie": f_pie, "drink": f_drink, "cheese": f_cheese, "egg": f_egg, "jar": m_jar, "bag": m_bag}
FOOD_NAMES = {"round": "Плод", "long": "Корнеплод", "bunch": "Гроздь", "leafy": "Кочан", "mush": "Гриб", "meat": "Мясо", "fish": "Рыба", "bread": "Хлеб",
              "bowl": "Миска еды", "can": "Консервы", "pie": "Пирог", "drink": "Напиток", "cheese": "Сыр", "egg": "Яйца", "jar": "Банка", "bag": "Мешок"}

# id, имя, цвет, форма, еда, вода, здоровье, порча(с, 0=не портится), цена, рецепт (вход), станции, описание
FOOD = [
    ("apple_red", "Красное яблоко", "#d8322a", "round", 18, 6, 4, 1200, 2, None, None, "Сочное и хрустящее."),
    ("pear", "Груша", "#c8d040", "round", 18, 8, 3, 1000, 2, None, None, "Мягкая и сладкая."),
    ("orange", "Апельсин", "#ff9a1a", "round", 16, 12, 4, 1400, 3, None, None, "Много сока и витаминов."),
    ("lemon", "Лимон", "#f2e040", "round", 4, 8, 6, 1800, 3, None, None, "Кислый, но лечит простуду."),
    ("peach", "Персик", "#ffb07a", "round", 15, 8, 3, 800, 3, None, None, "Бархатистый и душистый."),
    ("plum", "Слива", "#6a2a8a", "round", 12, 6, 2, 900, 2, None, None, "Тёмная и сладкая."),
    ("melon", "Дыня", "#e6d070", "round", 30, 25, 4, 1600, 5, None, None, "Большая и ароматная."),
    ("watermelon", "Арбуз", "#2f8a3a", "round", 25, 40, 2, 1600, 5, None, None, "Почти одна вода — отлично утоляет жажду."),
    ("pumpkin", "Тыква", "#f28a1a", "round", 35, 5, 2, 3600, 4, None, None, "Хранится долго, хороша в пироге."),
    ("tomato", "Помидор", "#e0322a", "round", 12, 10, 2, 900, 2, None, None, "Для салата и супа."),
    ("onion", "Лук", "#d8b070", "round", 6, 2, 4, 3000, 1, None, None, "Острый, отпугивает болезни."),
    ("potato", "Картофель", "#c8a060", "round", 22, 0, 0, 4000, 1, None, None, "Сытный клубень. Лучше сварить."),
    ("cabbage", "Капуста", "#a8d070", "leafy", 18, 8, 2, 2400, 2, None, None, "Крепкий хрустящий кочан."),
    ("lettuce", "Салат", "#7fd050", "leafy", 8, 8, 3, 600, 1, None, None, "Листья для лёгкого перекуса."),
    ("carrot", "Морковь", "#ff8a1a", "long", 12, 4, 3, 2400, 1, None, None, "Полезна для глаз."),
    ("beet", "Свёкла", "#8a1a3a", "long", 14, 4, 2, 3000, 1, None, None, "Сладкий корень для борща."),
    ("corn", "Кукуруза", "#f2d040", "long", 20, 2, 1, 2000, 2, None, None, "Сладкий початок."),
    ("cucumber", "Огурец", "#3f9a3a", "long", 8, 14, 1, 900, 1, None, None, "Свежий и водянистый."),
    ("eggplant", "Баклажан", "#4a2a6a", "long", 14, 4, 1, 1200, 2, None, None, "Хорош запечённым."),
    ("pepper", "Перец", "#e0263d", "long", 10, 6, 3, 1200, 2, None, None, "Сладкий и яркий."),
    ("grapes", "Виноград", "#7a3a9a", "bunch", 14, 10, 3, 700, 3, None, None, "Гроздь сладких ягод."),
    ("blueberries", "Черника", "#3a3a9a", "bunch", 10, 4, 6, 600, 2, None, None, "Лесная ягода, лечит глаза и раны."),
    ("strawberries", "Клубника", "#e0263d", "bunch", 10, 5, 4, 500, 3, None, None, "Самая вкусная ягода."),
    ("wheat", "Пшеница", "#e6c060", "long", 2, 0, 0, 0, 1, None, None, "Зерно для муки. Сырым не наесться."),
    ("rice", "Рис", "#f2eee0", "bag", 3, 0, 0, 0, 1, None, None, "Сварите в котле."),
    ("flour", "Мука", "#f6f2e8", "bag", 1, 0, 0, 0, 2, {"wheat": 3}, ["workbench"], "Перемолотое зерно для хлеба и пирогов."),
    ("bread", "Хлеб", "#d9a050", "bread", 40, 0, 5, 2400, 6, {"flour": 2, "water_flask": 1}, ["furnace"], "Тёплый хлеб — основа рациона."),
    ("chanterelle", "Лисички", "#f2a81f", "mush", 14, 2, 3, 900, 2, None, None, "Жёлтые лесные грибы."),
    ("porcini", "Белый гриб", "#8a5a30", "mush", 22, 2, 5, 900, 4, None, None, "Король грибов."),
    ("fly_agaric", "Мухомор", "#e0263d", "mush", 5, 0, -30, 900, 1, None, None, "Ядовит! Зато идёт на зелья."),
    ("cooked_meat", "Жареное мясо", "#9a4a2a", "meat", 50, 0, 10, 1800, 8, {"raw_meat": 1}, ["furnace", "hand"], "Горячее мясо прямо с огня."),
    ("steak", "Стейк", "#7a3020", "meat", 65, 0, 15, 1800, 12, {"raw_meat": 2, "salt": 1}, ["furnace"], "Толстый сочный кусок."),
    ("sausage", "Колбаса", "#a03a3a", "long", 40, 0, 4, 4800, 10, {"raw_meat": 2, "salt": 1}, ["workshop"], "Копчёная, долго хранится."),
    ("raw_fish", "Сырая рыба", "#8ab0c8", "fish", 12, 2, -2, 600, 3, None, None, "Свежий улов. Лучше пожарить."),
    ("cooked_fish", "Жареная рыба", "#c08040", "fish", 40, 0, 10, 1500, 8, {"raw_fish": 1}, ["furnace", "hand"], "Ароматная и полезная."),
    ("egg", "Яйца", "#f2ead6", "egg", 10, 0, 2, 1800, 2, None, None, "Сырые яйца — сварите или испеките."),
    ("omelette", "Омлет", "#f2d050", "bowl", 35, 0, 6, 1200, 6, {"egg": 2}, ["furnace"], "Быстрый сытный завтрак."),
    ("cheese", "Сыр", "#f2c440", "cheese", 30, 0, 4, 6000, 10, {"milk": 3, "salt": 1}, ["workshop"], "Не портится неделями."),
    ("milk", "Молоко", "#f8f8f2", "drink", 10, 25, 3, 900, 3, None, None, "Свежее молоко."),
    ("honey", "Мёд", "#f2a81f", "jar", 20, 0, 12, 0, 8, None, None, "Сладкий и целебный, никогда не портится."),
    ("salt", "Соль", "#f6f6f6", "bag", 0, -5, 0, 0, 2, {"water": 10}, ["refinery", "furnace"], "Для заготовок и колбас."),
    ("sugar", "Сахар", "#fafafa", "bag", 5, 0, 0, 0, 3, {"beet": 2}, ["refinery"], "Сладость для пирогов и напитков."),
    ("vegetable_soup", "Овощной суп", "#e08a4a", "bowl", 45, 30, 10, 1200, 10, {"potato": 1, "carrot": 1, "onion": 1, "water_flask": 1}, ["furnace"], "Горячий суп: и еда, и питьё."),
    ("meat_stew", "Мясное рагу", "#8a4a2a", "bowl", 70, 20, 15, 1200, 16, {"raw_meat": 2, "potato": 1, "water_flask": 1}, ["furnace"], "Самое сытное блюдо колонии."),
    ("mushroom_soup", "Грибной суп", "#c49a6c", "bowl", 40, 25, 8, 1200, 9, {"mushroom": 3, "water_flask": 1}, ["furnace"], "Наваристый и душистый."),
    ("borscht", "Борщ", "#a01a3a", "bowl", 55, 30, 12, 1200, 14, {"beet": 1, "cabbage": 1, "raw_meat": 1, "water_flask": 1}, ["furnace"], "Красный суп по бабушкиному рецепту."),
    ("salad", "Салат из овощей", "#7fd050", "bowl", 25, 10, 8, 600, 7, {"lettuce": 1, "tomato": 1, "cucumber": 1}, ["workbench", "hand"], "Свежо и полезно."),
    ("fruit_salad", "Фруктовый салат", "#ff9a1a", "bowl", 30, 15, 8, 600, 9, {"apple_red": 1, "orange": 1, "grapes": 1}, ["workbench", "hand"], "Витаминный заряд."),
    ("apple_pie", "Яблочный пирог", "#d9a050", "pie", 60, 0, 10, 3600, 18, {"flour": 2, "apple_red": 3, "sugar": 1}, ["furnace"], "Поднимает настроение всей колонии."),
    ("berry_pie", "Ягодный пирог", "#8a1a3a", "pie", 55, 0, 12, 3600, 16, {"flour": 2, "berry": 6, "sugar": 1}, ["furnace"], "Сладкий пирог из лесных ягод."),
    ("pumpkin_pie", "Тыквенный пирог", "#f28a1a", "pie", 65, 0, 8, 3600, 16, {"flour": 2, "pumpkin": 1, "sugar": 1}, ["furnace"], "Осенний праздник в каждом куске."),
    ("baked_potato", "Печёная картошка", "#b08040", "round", 35, 0, 4, 1500, 4, {"potato": 1}, ["furnace", "hand"], "Простая и сытная еда."),
    ("popcorn", "Попкорн", "#fafae0", "bag", 15, -5, 0, 0, 4, {"corn": 1}, ["furnace"], "Хрустящая закуска."),
    ("canned_meat", "Мясные консервы", "#c03020", "can", 55, 0, 6, 0, 14, {"cooked_meat": 2, "iron_plate": 1}, ["packager"], "Не портится никогда. Запас на чёрный день."),
    ("canned_vegetables", "Овощные консервы", "#3f8f3a", "can", 40, 10, 6, 0, 12, {"carrot": 1, "potato": 1, "tomato": 1, "iron_plate": 1}, ["packager"], "Вечный запас овощей."),
    ("canned_fish", "Рыбные консервы", "#2f6fc4", "can", 45, 0, 8, 0, 13, {"cooked_fish": 2, "iron_plate": 1}, ["packager"], "Шпроты для колонистов."),
    ("ration", "Сухой паёк", "#6a7a4a", "can", 80, 20, 10, 0, 25, {"canned_meat": 1, "bread": 1, "water_flask": 1}, ["packager"], "Полный обед в одной коробке."),
    ("juice", "Сок", "#ff9a1a", "drink", 8, 35, 4, 1200, 5, {"orange": 2}, ["workbench", "hand"], "Свежевыжатый сок."),
    ("tea", "Чай", "#8a5a30", "drink", 0, 35, 6, 0, 4, {"leaves": 3, "water_flask": 1}, ["furnace"], "Согревает и бодрит."),
    ("coffee", "Кофе", "#4a2e1a", "drink", 0, 25, 0, 0, 8, {"coffee_beans": 2, "water_flask": 1}, ["furnace"], "Бодрит: быстрее работаешь."),
    ("coffee_beans", "Кофейные зёрна", "#4a2e1a", "bag", 2, 0, 0, 0, 4, None, None, "Обжарьте и сварите кофе."),
    ("lemonade", "Лимонад", "#f2e040", "drink", 5, 40, 3, 1800, 6, {"lemon": 1, "sugar": 1, "water_flask": 1}, ["workbench"], "Освежает в жару."),
    ("energy_drink", "Энергетик", "#40ff6a", "drink", 0, 30, 0, 0, 20, {"sugar": 1, "coffee_beans": 2, "water_flask": 1}, ["refinery"], "Резкий прилив сил."),
    ("purified_water", "Очищенная вода", "#9fe8ff", "drink", 0, 60, 2, 0, 5, {"water": 4}, ["refinery"], "Кристально чистая вода в бутылке."),
    ("smoothie", "Смузи", "#ff7ab0", "drink", 20, 30, 8, 900, 9, {"strawberries": 1, "milk": 1, "honey": 1}, ["workbench"], "Густой ягодный коктейль."),
    ("cookie", "Печенье", "#d9a050", "bread", 15, 0, 2, 0, 4, {"flour": 1, "sugar": 1}, ["furnace"], "Сладость к чаю. Не портится."),
    ("candy", "Конфеты", "#ff4db8", "bag", 8, 0, 4, 0, 5, {"sugar": 2, "honey": 1}, ["workshop"], "Подарок для торговцев и детей."),
    ("alien_fruit", "Инопланетный плод", "#40e0ff", "round", 30, 20, 20, 1200, 25, None, None, "Светится в темноте и сильно лечит."),
    ("glow_berry", "Светоягода", "#7dff5a", "bunch", 12, 6, 10, 900, 10, None, None, "Ягоды со светящимися косточками."),
]


def build_food():
    for k, fn in FOOD_SHAPES.items():
        MOD("cat_f_" + k, FOOD_NAMES[k], fn(), "Еда")
    for iid, nm, col, shape, food, water, heal, spoil, price, rin, st, desc in FOOD:
        kw = {}
        if food: kw["food"] = food
        if water: kw["water"] = water
        if heal: kw["heal"] = heal
        if spoil: kw["spoil"] = spoil
        parts = []
        if food > 0: parts.append("сытость +%d" % food)
        if water > 0: parts.append("вода +%d" % water)
        if heal > 0: parts.append("здоровье +%d" % heal)
        if heal < 0: parts.append("здоровье %d" % heal)
        full = desc + (" Съешь (ПКМ): " + ", ".join(parts) + "." if parts else "") + (" Портится через %d мин." % (spoil // 60) if spoil else "")
        I(iid, nm, full, col, "Еда", "cat_f_" + shape, stack=30 if price < 10 else 15, price=price, catalog="Еда и напитки", **kw)
        if iid == "coffee":
            items[iid]["boost"] = {"stat": "craft_speed", "value": 0.25, "time": 120}
        if iid == "energy_drink":
            items[iid]["boost"] = {"stat": "move", "value": 0.3, "time": 90}
        if rin:
            R("cook_" + iid, nm, rin, {iid: 1 if price > 3 else 2}, 3.0 if "furnace" in st else 2.0, st)


# ================================================================== инструменты и оружие ближнего боя
def t_axe(double=False):
    a = [P("cylinder", (0.07, 0.9, 0.07), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7),
         P("torus", (0.1, 0.25, 0.1), (0, -0.3, 0), LEATHER, "cloth", tint=False, seg=8), P("torus", (0.1, 0.25, 0.1), (0, -0.25, 0), LEATHER, "cloth", tint=False, seg=8),
         P("box", (0.26, 0.24, 0.06), (0.12, 0.3, 0), W, "metal"), P("prism", (0.14, 0.34, 0.06), (0.3, 0.3, 0), W, "metal", rot=(0, 0, -90)),
         P("box", (0.03, 0.34, 0.065), (0.36, 0.3, 0), "#e8eef4", "metal", tint=False), P("box", (0.12, 0.12, 0.08), (-0.02, 0.32, 0), DARK, "dark", tint=False)]
    if double:
        a += [P("box", (0.26, 0.24, 0.06), (-0.12, 0.3, 0), W, "metal"), P("prism", (0.14, 0.34, 0.06), (-0.3, 0.3, 0), W, "metal", rot=(0, 0, 90)),
              P("box", (0.03, 0.34, 0.065), (-0.36, 0.3, 0), "#e8eef4", "metal", tint=False)]
    return a


def t_pick():
    return [P("cylinder", (0.07, 0.9, 0.07), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7), P("torus", (0.1, 0.25, 0.1), (0, -0.28, 0), LEATHER, "cloth", tint=False, seg=8),
            P("box", (0.12, 0.14, 0.1), (0, 0.38, 0), DARK, "dark", tint=False),
            P("cylinder", (0.07, 0.42, 0.07), (0.22, 0.4, 0), W, "metal", rot=(0, 0, -80), top=0.15, seg=6),
            P("cylinder", (0.07, 0.42, 0.07), (-0.22, 0.4, 0), W, "metal", rot=(0, 0, 80), top=0.15, seg=6)]


def t_hammer():
    return [P("cylinder", (0.07, 0.8, 0.07), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7), P("torus", (0.1, 0.25, 0.1), (0, -0.26, 0), LEATHER, "cloth", tint=False, seg=8),
            P("box", (0.4, 0.18, 0.18), (0, 0.4, 0), W, "metal"), P("box", (0.06, 0.2, 0.2), (0.2, 0.4, 0), shade("#ffffff", 0.9), "metal"),
            P("box", (0.06, 0.2, 0.2), (-0.2, 0.4, 0), shade("#ffffff", 0.9), "metal")]


def t_shovel():
    return [P("cylinder", (0.06, 0.9, 0.06), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7), P("box", (0.24, 0.05, 0.05), (0, -0.46, 0), WOOD_D, "wood", tint=False),
            P("box", (0.26, 0.32, 0.03), (0, 0.6, 0), W, "metal"), P("prism", (0.26, 0.1, 0.03), (0, 0.8, 0), W, "metal")]


def t_sickle():
    a = [P("cylinder", (0.07, 0.3, 0.07), (0, -0.15, 0), WOOD_H, "wood", tint=False, seg=7)]
    for k in range(7):
        ang = math.radians(10 + k * 25)
        a.append(P("box", (0.1, 0.05, 0.02), (math.cos(ang) * 0.22 - 0.05, 0.05 + math.sin(ang) * 0.22, 0), W, "metal", rot=(0, 0, math.degrees(ang) + 90)))
    return a


def t_drill():
    return [P("box", (0.36, 0.24, 0.16), (0, 0.1, 0), W, "paint"), P("box", (0.1, 0.3, 0.12), (-0.08, -0.12, 0), DARK, "dark", tint=False, rot=(0, 0, -12)),
            P("cylinder", (0.12, 0.12, 0.12), (0.22, 0.1, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=10),
            P("screw", (0.07, 0.36, 0.07), (0.44, 0.1, 0), STEEL, "metal", tint=False, rot=(0, 0, -90), seg=6, top=0.2, anim="spin"),
            P("box", (0.12, 0.08, 0.17), (-0.06, -0.26, 0), "#40ff6a", "glow", tint=False)]


def t_chainsaw():
    return [P("box", (0.34, 0.24, 0.18), (-0.1, 0.1, 0), W, "paint"), P("torus", (0.18, 0.2, 0.08), (-0.1, 0.27, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=10),
            P("box", (0.56, 0.1, 0.03), (0.34, 0.1, 0), STEEL, "metal", tint=False), P("box", (0.6, 0.13, 0.02), (0.34, 0.1, 0), DARK, "dark", tint=False),
            P("cylinder", (0.13, 0.03, 0.13), (0.62, 0.1, 0), STEEL, "metal", tint=False, rot=(90, 0, 0), seg=10)]


def w_blade(l=0.7, w=0.1, guard=True):
    a = [P("box", (w, l, 0.025), (0, 0.06 + l / 2, 0), W, "metal"), P("box", (0.02, l * 0.9, 0.03), (0, 0.06 + l / 2, 0), "#e8eef4", "metal", tint=False),
         P("prism", (w, 0.14, 0.025), (0, 0.13 + l, 0), W, "metal"),
         P("cylinder", (0.06, 0.2, 0.06), (0, -0.1, 0), LEATHER, "cloth", tint=False, seg=6), P("sphere", (0.08, 0.08, 0.08), (0, -0.22, 0), BRASS, "metal", tint=False, seg=8)]
    if guard:
        a.append(P("box", (0.3, 0.05, 0.08), (0, 0.03, 0), BRASS, "metal", tint=False))
    return a


def w_katana():
    a = []
    for k in range(6):
        a.append(P("box", (0.07, 0.15, 0.02), (0.012 * k * k * 0.3, 0.1 + k * 0.14, 0), W, "metal", rot=(0, 0, -k * 1.5)))
    return a + [P("cylinder", (0.12, 0.03, 0.12), (0, 0.02, 0), BRASS, "metal", tint=False, seg=8),
                P("cylinder", (0.05, 0.3, 0.05), (0, -0.15, 0), "#1d1e21", "cloth", tint=False, seg=6)]


def w_spear():
    return [P("cylinder", (0.05, 1.3, 0.05), (0, 0, 0), WOOD_H, "wood", tint=False, seg=7), P("cone", (0.1, 0.3, 0.04), (0, 0.8, 0), W, "metal", seg=4),
            P("torus", (0.07, 0.2, 0.07), (0, 0.63, 0), LEATHER, "cloth", tint=False, seg=8), P("sphere", (0.08, 0.1, 0.08), (0, -0.66, 0), W, "metal", seg=6)]


def w_mace():
    a = [P("cylinder", (0.06, 0.7, 0.06), (0, 0, 0), WOOD_D, "wood", tint=False, seg=7), P("sphere", (0.24, 0.24, 0.24), (0, 0.42, 0), W, "metal", seg=10)]
    for k in range(8):
        ang = k * math.pi / 4
        a.append(P("cone", (0.06, 0.12, 0.06), (math.cos(ang) * 0.13, 0.42 + (0.05 if k % 2 else -0.05), math.sin(ang) * 0.13), W, "metal",
                   rot=(0, -math.degrees(ang), -90), seg=5))
    return a


def w_club():
    return [P("cylinder", (0.12, 0.8, 0.12), (0, 0.1, 0), WOOD_H, "wood", tint=False, top=1.8, seg=8)] + \
        [P("cone", (0.04, 0.08, 0.04), (math.cos(k) * 0.1, 0.35 + (k % 3) * 0.06, math.sin(k) * 0.1), STEEL, "metal", tint=False, rot=(0, -math.degrees(k), -90), seg=4) for k in range(6)]


def w_pistol():
    return [P("box", (0.34, 0.12, 0.08), (0.05, 0.1, 0), W, "metal"), P("box", (0.1, 0.22, 0.08), (-0.06, -0.04, 0), DARK, "dark", tint=False, rot=(0, 0, -12)),
            P("cylinder", (0.05, 0.16, 0.05), (0.26, 0.12, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=8),
            P("torus", (0.1, 0.2, 0.05), (0.02, -0.0, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=8)]


def w_rifle(long=1.0, scope=False, mag=True, glow=None):
    a = [P("box", (0.6 * long, 0.12, 0.08), (0.1, 0.1, 0), W, "metal"), P("box", (0.3, 0.14, 0.07), (-0.36, 0.06, 0), WOOD_H, "wood", tint=False, rot=(0, 0, 8)),
         P("cylinder", (0.05, 0.4 * long, 0.05), (0.4 + 0.25 * long, 0.12, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=8),
         P("box", (0.08, 0.16, 0.07), (0.0, -0.06, 0), DARK, "dark", tint=False, rot=(0, 0, -15))]
    if mag:
        a.append(P("box", (0.08, 0.18, 0.06), (0.16, -0.06, 0), DARK, "dark", tint=False, rot=(0, 0, 10)))
    if scope:
        a += [P("cylinder", (0.07, 0.3, 0.07), (0.12, 0.22, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=10),
              P("cylinder", (0.06, 0.01, 0.06), (0.275, 0.22, 0), "#40c8ff", "glow", tint=False, rot=(0, 0, 90), seg=10)]
    if glow:
        a += [P("torus", (0.1, 0.25, 0.1), (0.5 + k * 0.1, 0.12, 0), glow, "glow", tint=False, rot=(0, 0, 90), seg=10, anim="pulse") for k in range(3)]
        a.append(P("box", (0.2, 0.04, 0.09), (0.1, 0.17, 0), glow, "glow", tint=False))
    return a


def w_launcher():
    return [P("cylinder", (0.18, 0.9, 0.18), (0.1, 0.12, 0), W, "metal", rot=(0, 0, 90), seg=12),
            P("cylinder", (0.22, 0.12, 0.22), (0.54, 0.12, 0), DARK, "dark", tint=False, rot=(0, 0, 90), seg=12),
            P("box", (0.1, 0.18, 0.08), (0.0, -0.06, 0), DARK, "dark", tint=False), P("box", (0.1, 0.1, 0.12), (0.1, 0.26, 0), DARK, "dark", tint=False)]


def w_bow():
    a = []
    for k in range(9):
        ang = math.radians(-60 + k * 15)
        a.append(P("cylinder", (0.045, 0.16, 0.045), (math.cos(ang) * 0.4 - 0.35, math.sin(ang) * 0.4, 0), W, "wood", rot=(0, 0, math.degrees(ang)), seg=6))
    return a + [P("cylinder", (0.01, 0.7, 0.01), (-0.15, 0, 0), "#f2f2e6", "cloth", tint=False, seg=4)]


def w_shield():
    return [P("cylinder", (0.6, 0.06, 0.6), (0, 0.3, 0), W, "metal", rot=(90, 0, 0), seg=16), P("torus", (0.62, 0.08, 0.62), (0, 0.3, 0), BRASS, "metal", tint=False, rot=(90, 0, 0), seg=16),
            P("sphere", (0.14, 0.1, 0.14), (0, 0.3, 0.04), BRASS, "metal", tint=False, seg=10)]


TOOL_MATS = [  # id, прилагательные (м/ж/ср), цвет, сила инструмента, прочность, урон×, слиток, цена×
    ("copper", ("Медный", "Медная", "Медное"), "#e08a4a", 3.0, 250, 1.0, "copper_ingot", 1.0),
    ("bronze", ("Бронзовый", "Бронзовая", "Бронзовое"), "#c08040", 4.0, 450, 1.2, "bronze_ingot", 1.4),
    ("steel", ("Стальной", "Стальная", "Стальное"), "#9aa5b5", 6.0, 800, 1.5, "steel", 2.0),
    ("titanium", ("Титановый", "Титановая", "Титановое"), "#a8b4c4", 9.0, 1400, 1.9, "titanium_ingot", 3.5),
    ("tungsten", ("Вольфрамовый", "Вольфрамовая", "Вольфрамовое"), "#5c6370", 12.0, 2200, 2.4, "tungsten_ingot", 5.0),
]
# id, род (0 м, 1 ж, 2 ср), имя, модель, tool/weapon, базовый урон, дальность, темп, металла
TOOL_KINDS = [
    ("axe", 0, "топор", "cat_t_axe", ("tool", "axe"), 0, 0, 0, 3),
    ("pickaxe", 1, "кирка", "cat_t_pick", ("tool", "pickaxe"), 0, 0, 0, 3),
    ("sword", 0, "меч", "cat_w_sword", ("melee",), 28, 3.0, 0.55, 4),
    ("spear", 1, "копьё", "cat_w_spear", ("melee",), 22, 4.2, 0.7, 2),
    ("mace", 1, "булава", "cat_w_mace", ("melee",), 36, 2.6, 0.8, 5),
]


def build_tools():
    for mid, fn in (("cat_t_axe", t_axe), ("cat_t_pick", t_pick), ("cat_t_hammer", t_hammer), ("cat_t_shovel", t_shovel), ("cat_t_sickle", t_sickle),
                    ("cat_t_drill", t_drill), ("cat_t_chainsaw", t_chainsaw), ("cat_t_axe2", lambda: t_axe(True)),
                    ("cat_w_sword", w_blade), ("cat_w_dagger", lambda: w_blade(0.36, 0.08)), ("cat_w_greatsword", lambda: w_blade(1.05, 0.15)),
                    ("cat_w_katana", w_katana), ("cat_w_spear", w_spear), ("cat_w_mace", w_mace), ("cat_w_club", w_club), ("cat_w_pistol", w_pistol),
                    ("cat_w_rifle", w_rifle), ("cat_w_sniper", lambda: w_rifle(1.5, True)), ("cat_w_shotgun", lambda: w_rifle(1.1, False, False)),
                    ("cat_w_smg", lambda: w_rifle(0.7)), ("cat_w_laser", lambda: w_rifle(1.0, True, False, "#ff3a5a")),
                    ("cat_w_plasma", lambda: w_rifle(1.1, False, False, "#d9a6ff")), ("cat_w_launcher", w_launcher), ("cat_w_bow", w_bow), ("cat_w_shield", w_shield)):
        MOD(mid, mid.split("_", 2)[2].capitalize(), fn(), "Инструменты и оружие")
    for mid, adj, col, power, dur, dmg, ingot, pm in TOOL_MATS:
        for kid, g, nm, model, kind, base, rng, rate, n in TOOL_KINDS:
            iid = mid + "_" + kid
            name = adj[g] + " " + nm
            if kind[0] == "tool":
                I(iid, name, "Добывает в %g раз быстрее рук. Прочность %d." % (power, dur), col, "Инструменты", model, stack=1, price=int(20 * pm),
                  tool=kind[1], power=power, durability=dur, catalog="Инструменты и оружие")
            else:
                I(iid, name, "Оружие ближнего боя: урон %d." % int(base * dmg), col, "Оружие", model, stack=1, price=int(30 * pm),
                  weapon="melee", damage=int(base * dmg), range=rng, rate=rate, durability=dur, catalog="Инструменты и оружие")
            R("make_" + iid, name, {ingot: n, "plank" if kid != "spear" else "log": 1}, {iid: 1}, 4.0, ["workshop"])
    EXTRA = [  # id, имя, цвет, модель, поля, цена, рецепт, станции, описание
        ("power_drill", "Электробур", "#f2c440", "cat_t_drill", {"tool": "pickaxe", "power": 14.0, "durability": 2000}, 120, {"motor": 1, "battery_cell": 2, "steel_rod": 1}, ["assembler"], "Ручной бур на батареях: добывает в 14 раз быстрее рук."),
        ("chainsaw", "Бензопила", "#e0632a", "cat_t_chainsaw", {"tool": "axe", "power": 14.0, "durability": 2000}, 120, {"motor": 1, "fuel": 1, "steel_plate": 2}, ["assembler"], "Валит деревья за секунды."),
        ("double_axe", "Двуручная секира", "#9aa5b5", "cat_t_axe2", {"weapon": "melee", "damage": 55, "range": 3.2, "rate": 1.0, "durability": 900}, 90, {"steel": 6, "plank": 2}, ["workshop"], "Медленный, но страшный удар."),
        ("hammer", "Молот строителя", "#9aa5b5", "cat_t_hammer", {"weapon": "melee", "damage": 20, "range": 2.4, "rate": 0.6, "durability": 600}, 30, {"iron_ingot": 3, "plank": 1}, ["workbench"], "Для стройки и драки."),
        ("shovel", "Лопата", "#c7ccd6", "cat_t_shovel", {"weapon": "melee", "damage": 14, "range": 2.8, "rate": 0.6, "durability": 500}, 15, {"iron_plate": 2, "plank": 1}, ["workbench"], "Копает грядки и отбивается от монстров."),
        ("sickle", "Серп", "#c7ccd6", "cat_t_sickle", {"tool": "axe", "power": 2.0, "durability": 300}, 12, {"iron_ingot": 1, "plank": 1}, ["workbench"], "Быстро собирает траву и урожай."),
        ("dagger", "Кинжал", "#d9dee6", "cat_w_dagger", {"weapon": "melee", "damage": 18, "range": 2.2, "rate": 0.25, "durability": 300}, 25, {"steel": 1, "rubber": 1}, ["workshop"], "Очень быстрые удары."),
        ("greatsword", "Двуручный меч", "#d9dee6", "cat_w_greatsword", {"weapon": "melee", "damage": 60, "range": 3.6, "rate": 1.0, "durability": 1000}, 110, {"steel": 8, "rubber": 1}, ["workshop"], "Тяжёлый и длинный клинок."),
        ("katana", "Катана", "#e8eef4", "cat_w_katana", {"weapon": "melee", "damage": 40, "range": 3.0, "rate": 0.4, "durability": 900}, 150, {"steel": 5, "carbon_fiber": 1}, ["workshop"], "Быстрая и острая."),
        ("club", "Дубина", "#7a5230", "cat_w_club", {"weapon": "melee", "damage": 16, "range": 2.6, "rate": 0.7, "durability": 200}, 5, {"log": 2, "iron_screw": 2}, ["hand"], "Первое оружие колониста."),
        ("bow", "Лук", "#8a5a30", "cat_w_bow", {"weapon": "gun", "damage": 14, "range": 26, "rate": 0.8, "durability": 300}, 30, {"plank": 3, "rope": 2}, ["workbench"], "Тихое оружие. Стреляет патронами."),
        ("pistol", "Пистолет", "#5c6370", "cat_w_pistol", {"weapon": "gun", "damage": 14, "range": 30, "rate": 0.3, "durability": 800}, 70, {"steel": 2, "iron_spring": 1, "gunpowder": 1}, ["workshop"], "Надёжный и простой."),
        ("revolver", "Револьвер", "#9aa5b5", "cat_w_pistol", {"weapon": "gun", "damage": 24, "range": 32, "rate": 0.6, "durability": 900}, 90, {"steel": 3, "brass_gear": 1}, ["workshop"], "Мощный выстрел, медленная перезарядка."),
        ("rifle", "Винтовка", "#5c6370", "cat_w_rifle", {"weapon": "gun", "damage": 22, "range": 45, "rate": 0.35, "durability": 1200}, 140, {"steel": 4, "plank": 2, "iron_spring": 2}, ["workshop"], "Точная и дальнобойная."),
        ("smg", "Пистолет-пулемёт", "#3a3f47", "cat_w_smg", {"weapon": "gun", "damage": 8, "range": 28, "rate": 0.07, "durability": 1000}, 160, {"steel": 3, "iron_spring": 3, "plastic": 2}, ["assembler"], "Шквал пуль в упор."),
        ("shotgun", "Дробовик", "#5c6370", "cat_w_shotgun", {"weapon": "gun", "damage": 40, "range": 16, "rate": 0.9, "durability": 900}, 130, {"steel": 4, "plank": 2}, ["workshop"], "Сносит монстров вблизи."),
        ("sniper_rifle", "Снайперская винтовка", "#2a2d33", "cat_w_sniper", {"weapon": "gun", "damage": 90, "range": 80, "rate": 1.4, "durability": 1500}, 300, {"titanium_ingot": 4, "lens": 2, "steel_spring": 1}, ["assembler"], "Убивает гнездо с другого берега."),
        ("laser_rifle", "Лазерная винтовка", "#ff3a5a", "cat_w_laser", {"weapon": "gun", "damage": 30, "range": 55, "rate": 0.15, "durability": 2500}, 450, {"laser_diode": 2, "power_cell": 1, "titanium_plate": 2}, ["assembler"], "Луч, который не промахивается."),
        ("plasma_gun", "Плазменная пушка", "#d9a6ff", "cat_w_plasma", {"weapon": "gun", "damage": 70, "range": 40, "rate": 0.5, "durability": 3000}, 800, {"plasma_core": 1, "tungsten_plate": 2, "superconductor": 1}, ["assembler"], "Шары плазмы плавят всё."),
        ("rocket_launcher", "Ракетница", "#3f6b2f", "cat_w_launcher", {"weapon": "gun", "damage": 150, "range": 50, "rate": 2.0, "durability": 600}, 600, {"steel_pipe_part": 2, "explosive": 2, "microchip": 1}, ["assembler"], "Одним выстрелом по толпе монстров."),
    ]
    for iid, nm, col, model, kw, price, rin, st, desc in EXTRA:
        cat = "Инструменты" if "tool" in kw else "Оружие"
        I(iid, nm, desc, col, cat, model, stack=1, price=price, catalog="Инструменты и оружие", **kw)
        R("make_" + iid, nm, rin, {iid: 1}, 6.0, st)
    MOD("cat_w_ammo_box", "Ящик патронов", [P("box", (0.4, 0.2, 0.26), (0, 0, 0), W, "metal"), P("box", (0.42, 0.04, 0.28), (0, 0.11, 0), DARK, "dark", tint=False),
                                             P("box", (0.12, 0.04, 0.04), (0, 0.15, 0), DARK, "dark", tint=False)] +
        [P("cylinder", (0.04, 0.12, 0.04), (-0.12 + k * 0.06, 0.18, 0.06), BRASS, "metal", tint=False, seg=6) for k in range(5)], "Инструменты и оружие")
    AMMO = [("ammo_heavy", "Тяжёлые патроны", "#c9a227", {"ammo": 10, "steel": 1, "gunpowder": 1}), ("ammo_energy", "Энергобатарея к оружию", "#40c8ff", {"battery_cell": 1, "copper_wire": 2}),
            ("arrows", "Стрелы", "#8a5a30", {"plank": 1, "iron_screw": 1}), ("shotgun_shells", "Патроны для дробовика", "#c03020", {"lead_dust": 1, "gunpowder": 1, "plastic": 1})]
    for iid, nm, col, rin in AMMO:
        I(iid, nm, "Боеприпасы. Оружие пока берёт обычные патроны — эти идут на продажу и на будущие виды оружия.", col, "Оборона", "cat_w_ammo_box", stack=200, price=4, catalog="Инструменты и оружие")
        R("make_" + iid, nm, rin, {iid: 20}, 3.0, ["workshop", "assembler"])
    MOD("cat_w_grenade", "Граната", [P("sphere", (0.2, 0.24, 0.2), (0, 0, 0), W, "metal", seg=10), P("cylinder", (0.08, 0.08, 0.08), (0, 0.14, 0), DARK, "dark", tint=False, seg=8),
                                     P("torus", (0.08, 0.2, 0.08), (0.06, 0.19, 0), STEEL, "metal", tint=False, rot=(90, 0, 0), seg=8)] +
        [P("box", (0.21, 0.01, 0.21), (0, -0.06 + k * 0.06, 0), shade("#ffffff", 0.75), "metal") for k in range(3)], "Инструменты и оружие")
    for iid, nm, col, v, dist, rin in (("frag_grenade", "Осколочная граната", "#5a6a3a", 140, 5, {"explosive": 1, "iron_plate": 1}),
                                         ("fire_grenade", "Зажигательная граната", "#ff6a1a", 110, 6, {"thermite": 1, "iron_plate": 1}),
                                         ("emp_grenade", "ЭМИ-граната", "#40c8ff", 90, 7, {"electromagnet": 1, "battery_cell": 1}),
                                         ("dynamite", "Динамит", "#c03020", 200, 4, {"explosive": 2, "paper": 1})):
        I(iid, nm, "Взрыв вокруг героя: %d урона в радиусе %d клеток." % (v, dist), col, "Бой", "cat_w_grenade", stack=10, price=v // 5, catalog="Инструменты и оружие",
          on_use=[{"do": "explode", "x": "$x", "z": "$z", "v": str(v), "dist": str(dist)}], use_sound="boom")
        R("make_" + iid, nm, rin, {iid: 2}, 4.0, ["workshop"])
    I("wooden_shield", "Деревянный щит", "Надеть (ПКМ): −15% урона на 20 минут.", "#8a5a30", "Броня", "cat_w_shield", stack=1, price=15,
      boost={"stat": "armor", "value": 0.15, "time": 1200}, catalog="Броня и одежда")
    R("make_wooden_shield", "Деревянный щит", {"plank": 6, "iron_screw": 4}, {"wooden_shield": 1}, 4.0, ["workbench"])
    I("steel_shield", "Стальной щит", "Надеть (ПКМ): −30% урона на 20 минут.", "#9aa5b5", "Броня", "cat_w_shield", stack=1, price=60,
      boost={"stat": "armor", "value": 0.3, "time": 1200}, catalog="Броня и одежда")
    R("make_steel_shield", "Стальной щит", {"steel_plate": 4, "leather": 1}, {"steel_shield": 1}, 5.0, ["workshop"])


# ================================================================== броня и одежда
def a_helmet():
    return [P("sphere", (0.4, 0.34, 0.42), (0, 0.06, 0), W, "metal", seg=14), P("box", (0.42, 0.06, 0.1), (0, -0.04, 0.17), W, "metal"),
            P("box", (0.3, 0.06, 0.02), (0, 0.04, 0.215), "#1d2a3a", "glass", tint=False), P("torus", (0.42, 0.06, 0.44), (0, -0.08, 0), DARK, "dark", tint=False, seg=14)]


def a_vest():
    return [P("box", (0.5, 0.56, 0.24), (0, 0.1, 0), W, "cloth"), P("box", (0.18, 0.12, 0.26), (-0.14, 0.42, 0), W, "cloth"), P("box", (0.18, 0.12, 0.26), (0.14, 0.42, 0), W, "cloth"),
            P("box", (0.14, 0.12, 0.04), (-0.12, 0.0, 0.13), shade("#ffffff", 0.8), "cloth"), P("box", (0.14, 0.12, 0.04), (0.12, 0.0, 0.13), shade("#ffffff", 0.8), "cloth"),
            P("box", (0.52, 0.05, 0.25), (0, -0.14, 0), DARK, "dark", tint=False), P("box", (0.06, 0.06, 0.02), (0, -0.14, 0.13), BRASS, "metal", tint=False)]


def a_boots():
    return [p for x in (-0.12, 0.12) for p in (P("box", (0.16, 0.3, 0.18), (x, 0.1, 0), W, "cloth"), P("box", (0.17, 0.08, 0.32), (x, -0.08, 0.06), DARK, "dark", tint=False),
                                                 P("box", (0.17, 0.04, 0.04), (x, 0.2, 0.09), shade("#ffffff", 0.75), "cloth"))]


def a_gloves():
    a = []
    for x in (-0.14, 0.14):
        a += [P("box", (0.16, 0.2, 0.08), (x, 0.0, 0), W, "cloth"), P("cylinder", (0.11, 0.12, 0.11), (x, -0.15, 0), DARK, "dark", tint=False, seg=8)]
        a += [P("capsule", (0.035, 0.12, 0.035), (x - 0.06 + k * 0.04, 0.15, 0), W, "cloth", seg=6) for k in range(4)]
    return a


def a_backpack():
    return [P("box", (0.44, 0.52, 0.24), (0, 0.1, 0), W, "cloth"), P("box", (0.36, 0.2, 0.08), (0, -0.02, 0.15), shade("#ffffff", 0.85), "cloth"),
            P("capsule", (0.24, 0.42, 0.24), (0, 0.42, 0), "#5a6a3a", "cloth", tint=False, rot=(0, 0, 90), seg=10),
            P("box", (0.06, 0.5, 0.04), (-0.14, 0.1, -0.14), DARK, "dark", tint=False), P("box", (0.06, 0.5, 0.04), (0.14, 0.1, -0.14), DARK, "dark", tint=False)]


def a_mask():
    return [P("sphere", (0.36, 0.34, 0.2), (0, 0.1, 0), W, "paint", seg=12), P("sphere", (0.1, 0.08, 0.04), (-0.08, 0.16, 0.09), "#1d2a3a", "glass", tint=False, seg=8),
            P("sphere", (0.1, 0.08, 0.04), (0.08, 0.16, 0.09), "#1d2a3a", "glass", tint=False, seg=8),
            P("cylinder", (0.14, 0.1, 0.14), (0, 0.0, 0.12), DARK, "dark", tint=False, rot=(90, 0, 0), seg=10),
            P("cylinder", (0.12, 0.02, 0.12), (0, 0.0, 0.17), "#40c8ff", "glow", tint=False, rot=(90, 0, 0), seg=10)]


ARMOR = [  # id, имя, цвет, модель, защита, время, цена, рецепт, станции
    ("leather_helmet", "Кожаный шлем", "#8a5a30", "helmet", 0.06, 1800, 15, {"leather": 3}, ["workbench"]),
    ("leather_vest", "Кожаная куртка", "#8a5a30", "vest", 0.1, 1800, 25, {"leather": 6, "rope": 1}, ["workbench"]),
    ("leather_boots", "Кожаные сапоги", "#5a3a22", "boots", 0.04, 1800, 12, {"leather": 3}, ["workbench"]),
    ("work_gloves", "Рабочие перчатки", "#c8a060", "gloves", 0.03, 1800, 8, {"leather": 2}, ["workbench"]),
    ("iron_helmet", "Железный шлем", "#c7ccd6", "helmet", 0.1, 1800, 35, {"iron_plate": 4}, ["workshop"]),
    ("chainmail", "Кольчуга", "#c7ccd6", "vest", 0.18, 1800, 60, {"iron_wire": 8, "leather": 1}, ["workshop"]),
    ("steel_helmet", "Стальной шлем", "#9aa5b5", "helmet", 0.14, 1800, 60, {"steel_plate": 4, "leather": 1}, ["workshop"]),
    ("steel_armor", "Стальной доспех", "#9aa5b5", "vest", 0.25, 1800, 120, {"steel_plate": 8, "leather": 2}, ["workshop"]),
    ("steel_boots", "Стальные сапоги", "#9aa5b5", "boots", 0.08, 1800, 45, {"steel_plate": 3, "leather": 2}, ["workshop"]),
    ("kevlar_vest", "Бронежилет", "#3a4a2a", "vest", 0.3, 1800, 180, {"kevlar": 4, "steel_plate": 2}, ["assembler"]),
    ("combat_helmet", "Каска с визором", "#3a4a2a", "helmet", 0.18, 1800, 120, {"kevlar": 2, "armored_glass": 1}, ["assembler"]),
    ("titanium_armor", "Титановый доспех", "#a8b4c4", "vest", 0.38, 1800, 400, {"titanium_plate": 6, "kevlar": 2}, ["assembler"]),
    ("exo_boots", "Экзо-ботинки", "#f2c440", "boots", 0.12, 1800, 300, {"servo_motor": 2, "titanium_plate": 2}, ["assembler"]),
    ("power_armor", "Силовая броня", "#f2a81f", "vest", 0.5, 1800, 1200, {"titanium_armor": 1, "power_cell": 2, "servo_motor": 4}, ["assembler"]),
    ("gas_mask", "Противогаз", "#5a6a3a", "mask", 0.05, 1800, 30, {"rubber_sheet": 2, "glass": 1, "coal": 2}, ["workshop"]),
    ("hazmat_mask", "Маска химзащиты", "#f2d24a", "mask", 0.08, 1800, 80, {"rubber_sheet": 3, "tempered_glass": 1}, ["assembler"]),
    ("small_backpack", "Маленький рюкзак", "#8a6a40", "backpack", 0.0, 0, 20, {"leather": 4, "rope": 2}, ["workbench"]),
    ("big_backpack", "Большой рюкзак", "#5a6a3a", "backpack", 0.0, 0, 60, {"kevlar": 2, "leather": 4}, ["workshop"]),
    ("winter_coat", "Тёплая куртка", "#c03020", "vest", 0.05, 3600, 30, {"wool": 6, "leather": 2}, ["workbench"]),
    ("raincoat", "Плащ-дождевик", "#f2d24a", "vest", 0.03, 3600, 15, {"rubber_sheet": 3}, ["workbench"]),
]


def build_armor():
    for k, fn in (("helmet", a_helmet), ("vest", a_vest), ("boots", a_boots), ("gloves", a_gloves), ("backpack", a_backpack), ("mask", a_mask)):
        MOD("cat_a_" + k, {"helmet": "Шлем", "vest": "Нагрудник", "boots": "Сапоги", "gloves": "Перчатки", "backpack": "Рюкзак", "mask": "Маска"}[k], fn(), "Броня и одежда")
    for iid, nm, col, shape, prot, t, price, rin, st in ARMOR:
        if shape == "backpack":
            I(iid, nm, "Надеть (ПКМ): +%d%% к скорости бега с грузом на 30 минут." % (10 if price < 50 else 20), col, "Броня", "cat_a_backpack", stack=1, price=price,
              boost={"stat": "move", "value": 0.1 if price < 50 else 0.2, "time": 1800}, catalog="Броня и одежда")
        else:
            I(iid, nm, "Надеть (ПКМ): −%d%% урона от монстров на %d мин." % (round(prot * 100), t // 60), col, "Броня", "cat_a_" + shape, stack=1, price=price,
              boost={"stat": "armor", "value": prot, "time": t}, catalog="Броня и одежда")
        R("make_" + iid, nm, rin, {iid: 1}, 5.0, st)


# ================================================================== медицина
def md_pill():
    return [P("cylinder", (0.22, 0.3, 0.22), (0, 0, 0), "#f2f2f2", "paint", tint=False, seg=12), P("cylinder", (0.24, 0.08, 0.24), (0, 0.18, 0), W, "paint", seg=12),
            P("cylinder", (0.225, 0.12, 0.225), (0, -0.02, 0), W, "paint", seg=12)] + \
        [P("capsule", (0.05, 0.12, 0.05), (0.18 + k * 0.06, -0.12, 0.05), W, "paint", rot=(0, k * 40, 90), seg=6) for k in range(2)]


def md_syringe():
    return [P("cylinder", (0.08, 0.36, 0.08), (0, 0, 0), W, "glass", rot=(0, 0, 90), seg=10), P("cylinder", (0.02, 0.16, 0.02), (0.26, 0, 0), STEEL, "metal", tint=False, rot=(0, 0, 90), seg=4),
            P("cylinder", (0.04, 0.16, 0.04), (-0.24, 0, 0), "#f2f2f2", "paint", tint=False, rot=(0, 0, 90), seg=6),
            P("cylinder", (0.14, 0.02, 0.14), (-0.32, 0, 0), "#f2f2f2", "paint", tint=False, rot=(0, 0, 90), seg=8)]


def md_bandage():
    return [P("cylinder", (0.26, 0.14, 0.26), (0, 0, 0), "#f6f2e8", "cloth", tint=False, rot=(90, 0, 0), seg=14), P("cylinder", (0.1, 0.15, 0.1), (0, 0, 0), "#d9c9a0", "cloth", tint=False, rot=(90, 0, 0), seg=10),
            P("box", (0.14, 0.01, 0.14), (0.0, -0.13, 0.12), "#f6f2e8", "cloth", tint=False), P("box", (0.06, 0.06, 0.15), (0, 0.0, 0), W, "paint")]


def md_kit_big():
    return [P("box", (0.6, 0.4, 0.26), (0, 0, 0), W, "paint"), P("box", (0.26, 0.08, 0.27), (0, 0, 0), "#f2f2f2", "paint", tint=False),
            P("box", (0.08, 0.26, 0.27), (0, 0, 0), "#f2f2f2", "paint", tint=False), P("torus", (0.2, 0.2, 0.06), (0, 0.26, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=10)]


MED = [  # id, имя, цвет, модель, лечит, буст, цена, рецепт, станции, описание
    ("bandage", "Бинт", "#f6f2e8", "bandage", 20, None, 4, {"fiber": 3}, ["hand", "workbench"], "Перевяжите рану: +20 здоровья."),
    ("herbal_poultice", "Травяная примочка", "#6fc04a", "bandage", 30, None, 6, {"leaves": 4, "fiber": 1}, ["hand", "workbench"], "Листья и травы: +30 здоровья."),
    ("painkillers", "Обезболивающее", "#e0263d", "pill", 15, {"stat": "regen", "value": 0.5, "time": 120}, 10, {"herbs": 2, "ethanol": 1}, ["workshop"], "+15 здоровья и восстановление 2 минуты."),
    ("antibiotics", "Антибиотики", "#2f6fc4", "pill", 40, None, 25, {"fly_agaric": 1, "ethanol": 1}, ["refinery"], "Лечат заражение и раны: +40 здоровья."),
    ("vitamins", "Витамины", "#ff9a1a", "pill", 5, {"stat": "regen", "value": 1.0, "time": 300}, 15, {"orange": 2, "lemon": 1}, ["workshop"], "Быстрое восстановление 5 минут."),
    ("adrenaline", "Адреналин", "#e0263d", "syringe", 10, {"stat": "attack_speed", "value": 0.5, "time": 45}, 30, {"monster_gland": 1, "ethanol": 1}, ["refinery"], "Бьёшь в полтора раза быстрее 45 секунд."),
    ("morphine", "Морфин", "#d0f0ff", "syringe", 60, None, 35, {"painkillers": 2, "ethanol": 1}, ["refinery"], "Сильное лекарство: +60 здоровья."),
    ("stim_strength", "Стимулятор силы", "#ff5a3a", "syringe", 0, {"stat": "damage", "value": 0.4, "time": 60}, 30, {"monster_gland": 1, "sugar": 1}, ["refinery"], "+40% урона на минуту."),
    ("stim_jump", "Стимулятор прыжка", "#7dff5a", "syringe", 0, {"stat": "jump", "value": 0.6, "time": 60}, 25, {"glow_berry": 2, "sugar": 1}, ["refinery"], "Прыгаешь выше на минуту."),
    ("stim_xp", "Стимулятор ума", "#d9a6ff", "syringe", 0, {"stat": "xp", "value": 0.5, "time": 300}, 50, {"alien_fruit": 1, "coffee": 1}, ["refinery"], "+50% опыта 5 минут."),
    ("big_medkit", "Большая аптечка", "#e0263d", "kit", 200, None, 90, {"medkit": 1, "bandage": 3, "antibiotics": 1}, ["workshop"], "Полностью поднимает на ноги: +200 здоровья."),
    ("nano_medkit", "Нано-аптечка", "#40e0ff", "kit", 400, {"stat": "regen", "value": 3.0, "time": 60}, 300, {"big_medkit": 1, "nanobots": 1}, ["assembler"], "Наноботы чинят тело изнутри."),
    ("antidote", "Противоядие", "#7dff5a", "syringe", 25, None, 20, {"monster_gland": 1, "honey": 1}, ["refinery"], "Нейтрализует яд пауков: +25 здоровья."),
    ("herbs", "Лечебные травы", "#6fc04a", "bandage", 8, None, 2, None, None, "Растут в лесу. Сырьё для лекарств."),
]


def build_medical():
    for k, fn in (("pill", md_pill), ("syringe", md_syringe), ("bandage", md_bandage), ("kit", md_kit_big)):
        MOD("cat_m_" + k, {"pill": "Таблетки", "syringe": "Шприц", "bandage": "Бинт", "kit": "Аптечка"}[k], fn(), "Медицина")
    for iid, nm, col, shape, heal, boost, price, rin, st, desc in MED:
        kw = {"heal": heal} if heal else {}
        if boost:
            kw["boost"] = boost
        I(iid, nm, desc, col, "Бустеры" if boost and not heal else "Еда", "cat_m_" + shape, stack=20, price=price, catalog="Медицина", **kw)
        if rin:
            R("make_" + iid, nm, rin, {iid: 1}, 3.0, st)


# ================================================================== семена и саженцы
def s_seeds():
    return [P("box", (0.26, 0.34, 0.04), (0, 0, 0), "#f2ead6", "paint", tint=False), P("box", (0.2, 0.18, 0.045), (0, 0.04, 0), W, "paint"),
            P("box", (0.26, 0.04, 0.045), (0, 0.16, 0), "#c49a6c", "paint", tint=False)] + \
        [P("sphere", (0.04, 0.03, 0.04), (0.18 + (k % 3) * 0.04, -0.15, 0.06 + (k // 3) * 0.04), W, "paint", seg=5) for k in range(5)]


def s_sapling():
    return [P("cylinder", (0.22, 0.2, 0.22), (0, -0.1, 0), "#b0603a", "stone", tint=False, top=1.25, seg=12), P("cylinder", (0.24, 0.02, 0.24), (0, 0.0, 0), "#4a2e1a", "paint", tint=False, seg=12),
            P("cylinder", (0.025, 0.3, 0.025), (0, 0.15, 0), WOOD_H, "wood", tint=False, seg=5)] + \
        [P("sphere", (0.14, 0.04, 0.08), (math.cos(k * 2.1) * 0.06, 0.2 + k * 0.05, math.sin(k * 2.1) * 0.06), W, "paint", rot=(0, k * 120, 25), seg=6) for k in range(4)]


SEEDS = ["wheat", "potato", "carrot", "tomato", "cabbage", "corn", "cucumber", "pumpkin", "watermelon", "melon", "beet", "onion", "lettuce", "pepper",
         "eggplant", "strawberries", "rice", "coffee_beans", "cotton", "flax", "herbs", "sunflower"]
SAPLINGS = [("pine", "сосны", "#2f6b3a"), ("oak", "дуба", "#4f8a2f"), ("birch", "берёзы", "#7fb84a"), ("apple", "яблони", "#d8322a"),
            ("orange", "апельсина", "#ff9a1a"), ("lemon", "лимона", "#f2e040"), ("pear", "груши", "#c8d040"), ("peach", "персика", "#ffb07a")]


def build_seeds():
    MOD("cat_s_seeds", "Пакет семян", s_seeds(), "Семена")
    MOD("cat_s_sapling", "Саженец в горшке", s_sapling(), "Семена")
    for s in SEEDS:
        nm = items.get(s, {}).get("name", {"cotton": "Хлопок", "flax": "Лён", "sunflower": "Подсолнух"}.get(s, s))
        col = items.get(s, {}).get("color", {"cotton": "#f8f8f2", "flax": "#7fa0e0", "sunflower": "#f2c440"}.get(s, "#7fb84a"))
        I(s + "_seeds", "Семена: " + nm.lower(), "Посадите на грядку. Урожай: %s." % nm.lower(), col, "Семена", "cat_s_seeds", stack=50, price=2, catalog="Семена и саженцы")
        if s in items:
            R("seeds_" + s, "Семена: " + nm.lower(), {s: 1}, {s + "_seeds": 2}, 1.0, ["hand", "workbench"])
    for s, gen, col in SAPLINGS:
        I("sapling_" + s, "Саженец " + gen, "Посадите — через время вырастет дерево.", col, "Семена", "cat_s_sapling", stack=20, price=5, catalog="Семена и саженцы")
    I("cotton", "Хлопок", "Мягкое волокно для ткани.", "#f8f8f2", "Сырьё", "cat_f_bunch", stack=50, price=2, catalog="Семена и саженцы")
    I("flax", "Лён", "Стебли для льняной ткани и верёвки.", "#c8b070", "Сырьё", "cat_f_long", stack=50, price=2, catalog="Семена и саженцы")
    I("sunflower", "Подсолнух", "Семечки и масло.", "#f2c440", "Сырьё", "cat_f_round", stack=30, price=2, catalog="Семена и саженцы")


# ================================================================== дерево, ткань, кожа
def w_planks(n=4):
    return [P("box", (0.7, 0.05, 0.14), (0, k * 0.055, -0.08 + (k % 2) * 0.16), W, "wood", rot=(0, (k % 3) * 4 - 4, 0)) for k in range(n)] + \
        [P("box", (0.7, 0.012, 0.02), (0, 0.03 + k * 0.055, -0.08 + (k % 2) * 0.16), "#3a2416", "wood", tint=False) for k in range(n)]


def w_beam():
    return [P("box", (0.9, 0.14, 0.14), (0, 0, 0), W, "wood"), P("box", (0.9, 0.14, 0.14), (0, 0.15, 0.05), W, "wood", rot=(0, 5, 0)),
            P("box", (0.91, 0.02, 0.02), (0, 0.04, 0.072), shade("#ffffff", 0.7), "wood")]


def w_cloth():
    return [P("box", (0.5, 0.06, 0.4), (0, k * 0.065, 0), W, "cloth", rot=(0, k * 6, 0)) for k in range(4)] + \
        [P("box", (0.52, 0.02, 0.06), (0, 0.13, 0), "#8a6a40", "cloth", tint=False)]


def w_hide():
    return [P("sphere", (0.6, 0.04, 0.44), (0, 0, 0), W, "cloth", seg=10)] + \
        [P("sphere", (0.16, 0.035, 0.12), (math.cos(k * 1.57 + 0.78) * 0.28, 0.0, math.sin(k * 1.57 + 0.78) * 0.2), W, "cloth", seg=6) for k in range(4)]


WOOD = [  # id, имя, цвет, модель, цена, рецепт, станции, описание
    ("pine_plank", "Сосновые доски", "#d9b070", "planks", 2, {"log": 1}, ["workbench"], "Светлые лёгкие доски."),
    ("oak_plank", "Дубовые доски", "#a0703a", "planks", 3, {"log": 1}, ["workbench"], "Крепкие тёмные доски для мебели."),
    ("birch_plank", "Берёзовые доски", "#f2e0b0", "planks", 2, {"log": 1}, ["workbench"], "Почти белое дерево."),
    ("hardwood", "Морёный дуб", "#5a3a22", "planks", 8, {"oak_plank": 2, "resin": 1}, ["workshop"], "Тёмное дерево, крепкое как камень."),
    ("plywood", "Фанера", "#d9c090", "planks", 3, {"plank": 2, "glue": 1}, ["workshop"], "Склеенные листы — для мебели и ящиков."),
    ("wood_beam", "Деревянная балка", "#8a5a30", "beam", 4, {"log": 2}, ["workbench"], "Опора для крыш и мостов."),
    ("charcoal", "Древесный уголь", "#2a2a2a", "planks", 2, {"log": 2}, ["furnace"], "Топливо без дыма."),
    ("sawdust", "Опилки", "#e6c890", "dust", 1, {"plank": 1}, ["workbench"], "Растопка и наполнитель."),
    ("paper", "Бумага", "#f6f2e8", "cloth", 2, {"sawdust": 2, "water_flask": 1}, ["workshop"], "Для чертежей, книг и динамита."),
    ("book", "Книга", "#8a2a2a", "cloth", 15, {"paper": 4, "leather": 1}, ["workshop"], "Учёные платят за неё хорошие деньги."),
    ("cloth", "Ткань", "#e6dcc8", "cloth", 4, {"cotton": 3}, ["workshop"], "Для одежды, мешков и парусов."),
    ("linen", "Льняная ткань", "#d9c9a0", "cloth", 4, {"flax": 3}, ["workshop"], "Прочная лёгкая ткань."),
    ("wool", "Шерсть", "#f2eee0", "cloth", 3, None, None, "Тёплая шерсть — для зимней одежды."),
    ("leather", "Кожа", "#8a5a30", "hide", 5, {"monster_hide": 1, "salt": 1}, ["workshop"], "Выделанная шкура монстра."),
    ("monster_hide", "Шкура монстра", "#5a4a3a", "hide", 3, None, None, "Сырая шкура. Выделайте в кожу."),
    ("canvas", "Брезент", "#a8a070", "cloth", 6, {"cloth": 2, "wax": 1}, ["workshop"], "Непромокаемая ткань для палаток."),
]


def build_wood():
    for k, fn in (("planks", w_planks), ("beam", w_beam), ("cloth", w_cloth), ("hide", w_hide), ("dust", m_dust)):
        MOD("cat_wd_" + k, {"planks": "Доски", "beam": "Балка", "cloth": "Ткань", "hide": "Шкура", "dust": "Опилки"}[k], fn(), "Дерево и ткань")
    for iid, nm, col, shape, price, rin, st, desc in WOOD:
        I(iid, nm, desc, col, "Материалы", "cat_wd_" + shape, stack=50, price=price, catalog="Дерево и ткань", **({"fuel": 4} if shape in ("planks", "beam") else {}))
        if rin:
            R("make_" + iid, nm, rin, {iid: 4 if shape == "planks" and price <= 3 else 1}, 2.0, st)


# ================================================================== части монстров
def mp_claw():
    return [P("cone", (0.12, 0.4, 0.12), (math.sin(k) * 0.1, 0.08, k * 0.08 - 0.08), W, "paint", rot=(0, 0, -30 - k * 6), seg=6) for k in range(3)] + \
        [P("box", (0.2, 0.1, 0.3), (-0.08, -0.08, 0), "#5a4a3a", "cloth", tint=False)]


def mp_eye():
    return [P("sphere", (0.3, 0.3, 0.3), (0, 0, 0), "#f2ead6", "paint", tint=False, seg=12), P("sphere", (0.16, 0.16, 0.06), (0, 0, 0.13), W, "glow", seg=10),
            P("sphere", (0.07, 0.07, 0.03), (0, 0, 0.16), "#101010", "dark", tint=False, seg=8)]


def mp_gland():
    return [P("sphere", (0.3, 0.24, 0.26), (0, 0, 0), W, "glass", seg=10), P("sphere", (0.18, 0.14, 0.16), (0.08, 0.06, 0.04), W, "glow", anim="pulse", seg=8),
            P("cylinder", (0.04, 0.16, 0.04), (-0.16, 0.06, 0), "#8a3a3a", "paint", tint=False, rot=(0, 0, 60), seg=5)]


def mp_carapace():
    return [P("sphere", (0.5, 0.18, 0.4), (0, 0, 0), W, "metal", seg=12)] + \
        [P("box", (0.5, 0.02, 0.04), (0, 0.06 - abs(k) * 0.02, k * 0.08), shade("#ffffff", 0.7), "metal", rot=(0, 0, 0)) for k in range(-2, 3)]


MONSTER = [  # id, имя, цвет, модель, цена, описание
    ("monster_claw", "Коготь монстра", "#f2ead6", "claw", 8, "Острый коготь. Для оружия и трофеев."),
    ("monster_eye", "Глаз монстра", "#ff3a3a", "eye", 12, "Светится даже после смерти. Для линз и зелий."),
    ("monster_gland", "Железа монстра", "#7dff5a", "gland", 15, "Ядовитая железа — сырьё для стимуляторов и противоядий."),
    ("carapace", "Панцирь", "#4a3a5a", "carapace", 14, "Прочная пластина брони жука."),
    ("spider_silk", "Паучий шёлк", "#f2f2f2", "cloth", 10, "Невероятно прочная нить."),
    ("acid_sac", "Кислотный мешок", "#b8ff3a", "gland", 18, "Из плевальщика. Для кислоты и гранат."),
    ("bone", "Кость", "#f2ead6", "claw", 3, "Для клея, удобрений и украшений."),
    ("horn", "Рог", "#d9c9a0", "claw", 10, "Тяжёлый рог громилы."),
    ("alien_tissue", "Инопланетная ткань", "#40e0ff", "gland", 30, "Странная живая материя. Учёные в восторге."),
    ("void_essence", "Эссенция пустоты", "#9a4dff", "eye", 80, "Выпадает только из боссов. Для квантовых технологий."),
    ("blood_vial", "Кровь монстра", "#8a1a2a", "gland", 6, "Для алхимии и удобрений."),
    ("trophy_skull", "Череп-трофей", "#f2ead6", "eye", 50, "Украшение для штаба. Дорого продаётся."),
]


def build_monster():
    for k, fn in (("claw", mp_claw), ("eye", mp_eye), ("gland", mp_gland), ("carapace", mp_carapace)):
        MOD("cat_mp_" + k, {"claw": "Коготь", "eye": "Глаз", "gland": "Железа", "carapace": "Панцирь"}[k], fn(), "Части монстров")
    for iid, nm, col, shape, price, desc in MONSTER:
        model = "cat_wd_cloth" if shape == "cloth" else "cat_mp_" + shape
        I(iid, nm, desc, col, "Сырьё", model, stack=50, price=price, rarity="rare" if price >= 30 else "", catalog="Части монстров")
        if not items[iid]["rarity"]:
            items[iid].pop("rarity")


# ================================================================== разное
def x_key():
    return [P("torus", (0.18, 0.2, 0.18), (-0.18, 0, 0), W, "metal", rot=(90, 0, 0), seg=10), P("box", (0.34, 0.04, 0.03), (0.06, 0, 0), W, "metal"),
            P("box", (0.04, 0.08, 0.03), (0.16, -0.05, 0), W, "metal"), P("box", (0.04, 0.06, 0.03), (0.22, -0.04, 0), W, "metal")]


def x_coin():
    return [P("cylinder", (0.16, 0.03, 0.16), (math.cos(k) * 0.08 * (k % 2), k * 0.032, math.sin(k) * 0.06), W, "metal", seg=12) for k in range(6)]


def x_crate():
    return [P("box", (0.5, 0.4, 0.4), (0, 0, 0), W, "wood"), P("box", (0.52, 0.06, 0.42), (0, 0.17, 0), shade("#ffffff", 0.75), "wood"),
            P("box", (0.52, 0.06, 0.42), (0, -0.17, 0), shade("#ffffff", 0.75), "wood"), P("box", (0.06, 0.4, 0.42), (0, 0, 0), shade("#ffffff", 0.75), "wood"),
            P("box", (0.1, 0.1, 0.01), (0.15, 0, 0.205), "#f2f2e6", "paint", tint=False)]


def x_blueprint():
    return [P("cylinder", (0.12, 0.6, 0.12), (0, 0, 0), W, "cloth", rot=(0, 0, 90), seg=10), P("box", (0.5, 0.005, 0.4), (0.0, -0.06, 0.18), W, "cloth", rot=(8, 0, 0)),
            P("box", (0.3, 0.006, 0.01), (0.0, -0.055, 0.12), "#f2f2f2", "glow", tint=False), P("box", (0.01, 0.006, 0.2), (-0.1, -0.055, 0.2), "#f2f2f2", "glow", tint=False)]


def x_lantern():
    return [P("cylinder", (0.2, 0.04, 0.2), (0, -0.16, 0), DARK, "dark", tint=False, seg=8), P("cylinder", (0.16, 0.26, 0.16), (0, 0, 0), "#ffd27a", "glass", tint=False, seg=8),
            P("sphere", (0.08, 0.12, 0.08), (0, 0, 0), W, "glow", anim="flicker", seg=6), P("cone", (0.22, 0.1, 0.22), (0, 0.18, 0), DARK, "dark", tint=False, seg=8),
            P("torus", (0.08, 0.2, 0.08), (0, 0.27, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=8)]


MISC = [  # id, имя, цвет, модель, цена, описание, extra
    ("gold_coin", "Золотые монеты", "#f2c440", "coin", 10, "Старинные монеты. Торговцы любят их.", {}),
    ("silver_coin", "Серебряные монеты", "#e8ecf2", "coin", 4, "Мелкая монета для торговли.", {}),
    ("old_key", "Старый ключ", "#c9a227", "key", 20, "Открывает что-то на этой планете…", {}),
    ("keycard", "Ключ-карта", "#40c8ff", "key", 40, "Пропуск к запертым комплексам.", {}),
    ("supply_crate", "Ящик снабжения", "#7a5230", "crate", 50, "Откройте (ПКМ): случайные полезные вещи.", {"on_use": [{"do": "give", "item": "ration", "n": "2"}, {"do": "give", "item": "ammo", "n": "30"}]}),
    ("blueprint_basic", "Чертёж", "#2f6fc4", "blueprint", 30, "Изучите (ПКМ): +50 опыта.", {"on_use": [{"do": "xp", "n": "50"}]}),
    ("lantern", "Фонарь", "#ffd27a", "lantern", 12, "Тёплый свет в руках.", {}),
    ("candle", "Свеча", "#f2e6a0", "lantern", 3, "Немного света и уюта.", {}),
    ("fishing_rod", "Удочка", "#8a5a30", "rod", 15, "Ловите рыбу у воды.", {}),
    ("compass", "Компас", "#c9a227", "coin", 25, "Всегда показывает на штаб.", {}),
    ("map_fragment", "Обрывок карты", "#e6dcc8", "blueprint", 15, "Кусочек старой карты планеты.", {}),
    ("gift_box", "Подарок", "#e0263d", "crate", 30, "Красивый подарок для торговца.", {}),
    ("toolbox", "Ящик с инструментами", "#e0263d", "crate", 40, "Используйте (ПКМ), чтобы получить инструменты.", {"on_use": [{"do": "give", "item": "iron_axe", "n": "1"}, {"do": "give", "item": "iron_pickaxe", "n": "1"}]}),
    ("repair_kit", "Ремкомплект", "#f2a81f", "crate", 25, "Детали для ремонта зданий.", {}),
    ("fuel_cell", "Топливный элемент", "#ffd040", "lantern", 20, "Горит в генераторах дольше угля.", {"fuel": 120}),
    ("trophy", "Кубок", "#f2c440", "lantern", 200, "Награда лучшему колонисту.", {}),
]


def build_misc():
    for k, fn in (("key", x_key), ("coin", x_coin), ("crate", x_crate), ("blueprint", x_blueprint), ("lantern", x_lantern)):
        MOD("cat_x_" + k, {"key": "Ключ", "coin": "Монеты", "crate": "Ящик", "blueprint": "Чертёж", "lantern": "Фонарь"}[k], fn(), "Разное")
    for iid, nm, col, shape, price, desc, extra in MISC:
        model = "cat_w_spear" if shape == "rod" else "cat_x_" + shape
        I(iid, nm, desc, col, "Разное", model, stack=20, price=price, catalog="Разное", **extra)
    R("make_lantern", "Фонарь", {"glass": 1, "iron_plate": 1, "wax": 1}, {"lantern": 1}, 3.0, ["workbench"])
    R("make_candle", "Свеча", {"wax": 1, "fiber": 1}, {"candle": 2}, 1.0, ["hand", "workbench"])
    R("make_fishing_rod", "Удочка", {"plank": 2, "rope": 1, "iron_screw": 1}, {"fishing_rod": 1}, 2.0, ["workbench"])
    R("make_compass", "Компас", {"magnet": 1, "glass": 1, "brass_plate": 1}, {"compass": 1}, 3.0, ["workshop"])
    R("make_repair_kit", "Ремкомплект", {"iron_screw": 4, "iron_plate": 2}, {"repair_kit": 1}, 2.0, ["workbench"])
    R("make_fuel_cell", "Топливный элемент", {"fuel": 2, "steel_plate": 1}, {"fuel_cell": 1}, 3.0, ["refinery"])
    R("make_toolbox", "Ящик с инструментами", {"iron_ingot": 6, "plank": 3}, {"toolbox": 1}, 4.0, ["workshop"])


def build_all():
    build_food(); build_tools(); build_armor(); build_medical(); build_seeds(); build_wood(); build_monster(); build_misc()
