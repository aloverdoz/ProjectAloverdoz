# Каталог готового контента — ПРЕДМЕТЫ (около 500). Модели подробные; белые детали красятся в цвет предмета.
# Результат собирает tools/gen_catalog.py в папку catalog/.
import math
from art_kit import P, M, shade

W = "#ffffff"
WOOD_H, WOOD_D = "#7a5230", "#4a2e1a"
STEEL, DARK, BRASS, LEATHER, CHR = "#b8bec7", "#2a2d33", "#c9a227", "#5a3a22", "#d5dbe2"

items, models, recipes = {}, {}, {}


def I(id, name, desc, color, cat, model, stack=50, price=1, **kw):
    d = {"name": name, "desc": desc, "color": color, "category": cat, "stack": stack, "price": price, "model": model, "catalog": cat}
    d.update(kw)
    items[id] = d


def R(id, name, inp, out, time, stations):
    recipes[id] = {"name": name, "in": inp, "out": out, "time": time, "stations": stations}


def MOD(id, name, parts, cat):
    models[id] = M(name, parts, "Каталог: " + cat)


# ================================================================== модели форм (металлы и материалы)
def m_ingot():
    return [P("box", (0.5, 0.14, 0.26), (0, 0, 0), W, "metal"), P("box", (0.42, 0.06, 0.18), (0, 0.09, 0), W, "metal"),
            P("box", (0.14, 0.01, 0.07), (0, 0.125, 0), shade("#8c949e", 0.6), "metal", tint=False),
            P("box", (0.5, 0.14, 0.26), (0.04, 0.16, 0.02), W, "metal", rot=(0, 12, 0)), P("box", (0.42, 0.06, 0.18), (0.04, 0.25, 0.02), W, "metal", rot=(0, 12, 0))]


def m_plate():
    a = [P("box", (0.46, 0.035, 0.46), (0, k * 0.045, 0), W, "metal", rot=(0, k * 7, 0)) for k in range(3)]
    a += [P("cylinder", (0.035, 0.02, 0.035), (x, 0.11, z), "#8c949e", "metal", tint=False, seg=6) for x in (-0.18, 0.18) for z in (-0.18, 0.18)]
    return a


def m_rod():
    a = []
    for k in range(5):
        a.append(P("cylinder", (0.06, 0.62, 0.06), (0, 0.04 + (k // 3) * 0.055, -0.1 + (k % 3) * 0.07 + (k // 3) * 0.035), W, "metal", rot=(0, 0, 90), seg=8))
    a += [P("torus", (0.28, 0.12, 0.28), (x, 0.05, 0), "#c03020", "cloth", tint=False, rot=(0, 0, 90), seg=10) for x in (-0.2, 0.2)]
    return a


def m_wire():
    return [P("cylinder", (0.38, 0.05, 0.38), (0, 0.12, -0.1), WOOD_H, "wood", tint=False, rot=(90, 0, 0), seg=12),
            P("cylinder", (0.38, 0.05, 0.38), (0, 0.12, 0.1), WOOD_H, "wood", tint=False, rot=(90, 0, 0), seg=12),
            P("cylinder", (0.3, 0.16, 0.3), (0, 0.12, 0), W, "metal", rot=(90, 0, 0), seg=12),
            P("torus", (0.31, 0.1, 0.31), (0, 0.12, -0.04), W, "metal", rot=(90, 0, 0), seg=12),
            P("torus", (0.31, 0.1, 0.31), (0, 0.12, 0.04), W, "metal", rot=(90, 0, 0), seg=12),
            P("cylinder", (0.08, 0.2, 0.08), (0, 0.12, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=8)]


def m_screw():
    a = []
    for k in range(3):
        x = -0.15 + k * 0.15
        a.append(P("screw", (0.07, 0.3, 0.07), (x, 0.0, 0.03 * k), W, "metal", seg=5, top=0.5, rot=(0, 0, 80 + k * 5)))
        a.append(P("cylinder", (0.13, 0.05, 0.13), (x - 0.16, 0.02, 0.03 * k), W, "metal", rot=(0, 0, 80 + k * 5), seg=8))
        a.append(P("box", (0.02, 0.06, 0.1), (x - 0.19, 0.03, 0.03 * k), DARK, "dark", tint=False, rot=(0, 0, 80 + k * 5)))
    return a


def m_bolt():
    return [P("cylinder", (0.08, 0.34, 0.08), (0, 0, 0), W, "metal", seg=8, rot=(0, 0, 90)),
            P("cylinder", (0.18, 0.08, 0.18), (-0.18, 0, 0), W, "metal", seg=6, rot=(0, 0, 90)),
            P("cylinder", (0.17, 0.08, 0.17), (0.08, 0, 0), W, "metal", seg=6, rot=(0, 0, 90)),
            P("cylinder", (0.12, 0.02, 0.12), (0.03, 0, 0), "#8c949e", "metal", tint=False, seg=10, rot=(0, 0, 90)),
            P("cylinder", (0.17, 0.08, 0.17), (0.2, -0.05, 0.15), W, "metal", seg=6),
            P("cylinder", (0.08, 0.09, 0.08), (0.2, -0.05, 0.15), DARK, "dark", tint=False, seg=8)]


def m_gear():
    return [P("gear", (0.46, 0.1, 0.46), (0, 0, 0), W, "metal", rot=(90, 0, 0), seg=14, top=0.8),
            P("gear", (0.28, 0.1, 0.28), (0.3, -0.06, 0.06), W, "metal", rot=(90, 0, 0), seg=10, top=0.76),
            P("cylinder", (0.12, 0.12, 0.12), (0, 0, 0), DARK, "dark", tint=False, rot=(90, 0, 0), seg=8),
            P("cylinder", (0.08, 0.12, 0.08), (0.3, -0.06, 0.06), DARK, "dark", tint=False, rot=(90, 0, 0), seg=8)]


def m_spring():
    a = [P("torus", (0.22, 0.2, 0.22), (0, -0.16 + k * 0.064, 0), W, "metal", seg=12, rot=(8 if k % 2 else -8, 0, 0)) for k in range(6)]
    a.append(P("cylinder", (0.24, 0.02, 0.24), (0, -0.19, 0), W, "metal", seg=12))
    return a


def m_beam():
    a = []
    for k in range(2):
        z = -0.1 + k * 0.22
        a += [P("box", (0.7, 0.03, 0.18), (0, 0.0 + k * 0.0, z), W, "metal"), P("box", (0.7, 0.03, 0.18), (0, 0.18, z), W, "metal"),
              P("box", (0.7, 0.16, 0.03), (0, 0.09, z), W, "metal")]
        for x in (-0.25, 0.0, 0.25):
            a.append(P("cylinder", (0.05, 0.035, 0.05), (x, 0.0, z), "#8c949e", "metal", tint=False, seg=6, rot=(90, 0, 0)))
    return a


def m_pipe():
    a = []
    for k in range(3):
        a.append(P("cylinder", (0.14, 0.6, 0.14), (0, 0.07 + (k // 2) * 0.12, -0.08 + (k % 2) * 0.16 + (k // 2) * 0.08), W, "metal", rot=(0, 0, 90), seg=12))
        a.append(P("cylinder", (0.1, 0.62, 0.1), (0, 0.07 + (k // 2) * 0.12, -0.08 + (k % 2) * 0.16 + (k // 2) * 0.08), DARK, "dark", tint=False, rot=(0, 0, 90), seg=10))
        a.append(P("torus", (0.18, 0.2, 0.18), (0.3, 0.07 + (k // 2) * 0.12, -0.08 + (k % 2) * 0.16 + (k // 2) * 0.08), W, "metal", rot=(0, 0, 90), seg=10))
    return a


def m_foil():
    return [P("cylinder", (0.22, 0.5, 0.22), (0, 0.11, 0), W, "metal", rot=(0, 0, 90), seg=14),
            P("cylinder", (0.08, 0.52, 0.08), (0, 0.11, 0), "#8a6a40", "paint", tint=False, rot=(0, 0, 90), seg=10),
            P("box", (0.5, 0.005, 0.3), (0, 0.003, 0.2), W, "metal", rot=(0, 0, 0)),
            P("box", (0.06, 0.24, 0.24), (0.27, 0.11, 0), "#c03020", "paint", tint=False)]


def m_dust():
    return [P("cylinder", (0.4, 0.42, 0.34), (0, 0.06, 0), "#c9b48a", "cloth", tint=False, top=0.8, seg=10),
            P("sphere", (0.36, 0.2, 0.3), (0, 0.28, 0), W, "stone", seg=8),
            P("torus", (0.3, 0.2, 0.26), (0, 0.24, 0), "#8a6a40", "cloth", tint=False, seg=10),
            P("box", (0.2, 0.14, 0.01), (0, 0.06, 0.17), W, "paint")]


def m_nugget():
    return [P("sphere", (0.3, 0.22, 0.26), (0, 0, 0), W, "metal", seg=6), P("sphere", (0.2, 0.16, 0.18), (0.16, -0.02, 0.1), W, "metal", seg=5),
            P("sphere", (0.16, 0.12, 0.14), (-0.13, -0.03, 0.12), W, "metal", seg=5)]


def m_raw_ore():
    return [P("sphere", (0.44, 0.34, 0.4), (0, 0, 0), "#6b6862", "stone", tint=False, seg=5),
            P("sphere", (0.26, 0.2, 0.22), (0.16, 0.06, 0.12), "#5f5c56", "stone", tint=False, seg=4),
            P("prism", (0.1, 0.16, 0.1), (-0.06, 0.15, -0.04), W, "metal", rot=(0, 0, 20)),
            P("prism", (0.08, 0.12, 0.08), (0.12, 0.14, -0.1), W, "metal", rot=(12, 0, -18)),
            P("box", (0.18, 0.04, 0.06), (-0.12, 0.05, 0.14), W, "metal", rot=(20, 30, 10)),
            P("sphere", (0.1, 0.08, 0.1), (0.08, 0.1, 0.16), W, "metal", seg=5)]


def m_gem_raw():
    return [P("sphere", (0.36, 0.26, 0.32), (0, -0.04, 0), "#7a7670", "stone", tint=False, seg=5),
            P("prism", (0.14, 0.3, 0.14), (0, 0.14, 0), W, "glow", rot=(0, 0, 8)),
            P("prism", (0.1, 0.2, 0.1), (0.1, 0.1, 0.05), W, "glow", rot=(10, 0, -25)),
            P("prism", (0.08, 0.16, 0.08), (-0.1, 0.08, -0.04), W, "glow", rot=(-8, 0, 28))]


def m_gem_cut():
    return [P("cylinder", (0.32, 0.1, 0.32), (0, 0.05, 0), W, "glass", seg=8),
            P("cone", (0.32, 0.26, 0.32), (0, -0.13, 0), W, "glass", seg=8, rot=(180, 0, 0)),
            P("cylinder", (0.2, 0.04, 0.2), (0, 0.12, 0), W, "glow", seg=8),
            P("sphere", (0.06, 0.06, 0.06), (0.06, 0.13, 0.04), "#ffffff", "glow", tint=False)]


METAL_FORMS = {
    "ingot": ("слиток", m_ingot, "Литой брусок металла."), "plate": ("пластины", m_plate, "Стопка прокатанных листов."),
    "rod": ("прутья", m_rod, "Связка прутьев для каркасов и деталей."), "wire": ("проволока", m_wire, "Катушка проволоки."),
    "screw": ("шурупы", m_screw, "Горсть шурупов."), "bolt": ("болты и гайки", m_bolt, "Крепёж для машин."),
    "gear": ("шестерни", m_gear, "Пара шестерён для механизмов."), "spring": ("пружина", m_spring, "Упругая пружина."),
    "beam": ("балка", m_beam, "Двутавровая балка для конструкций."), "pipe_part": ("трубки", m_pipe, "Отрезки труб."),
    "foil": ("фольга", m_foil, "Рулон тонкой фольги."), "dust": ("порошок", m_dust, "Мешочек металлического порошка."),
}
FORM_ORDER = ["ingot", "plate", "rod", "wire", "screw", "bolt", "gear", "spring", "beam", "pipe_part", "foil", "dust"]

# id, род. падеж для названий, цвет, есть руда (id руды) или сплав (состав)
METALS = [
    ("iron", "Железные", "Железная", "железа", "#c7ccd6", None, None),
    ("copper", "Медные", "Медная", "меди", "#e08a4a", None, None),
    ("steel", "Стальные", "Стальная", "стали", "#9aa5b5", None, None),
    ("tin", "Оловянные", "Оловянная", "олова", "#d8dde0", "Оловянная руда", "#8a8f94"),
    ("zinc", "Цинковые", "Цинковая", "цинка", "#b0bcc8", "Цинковая руда", "#7d8790"),
    ("lead", "Свинцовые", "Свинцовая", "свинца", "#6f7782", "Свинцовая руда", "#4f555c"),
    ("nickel", "Никелевые", "Никелевая", "никеля", "#c8c2a8", "Никелевая руда", "#8a8670"),
    ("aluminum", "Алюминиевые", "Алюминиевая", "алюминия", "#e2e6ea", "Боксит", "#b0603a"),
    ("silver", "Серебряные", "Серебряная", "серебра", "#e8ecf2", "Серебряная руда", "#9aa0aa"),
    ("gold", "Золотые", "Золотая", "золота", "#f2c440", "Золотая руда", "#c9a227"),
    ("platinum", "Платиновые", "Платиновая", "платины", "#dfe6ee", "Платиновая руда", "#a8b0bb"),
    ("titanium", "Титановые", "Титановая", "титана", "#a8b4c4", "Титановая руда", "#5f6b7a"),
    ("tungsten", "Вольфрамовые", "Вольфрамовая", "вольфрама", "#5c6370", "Вольфрамит", "#3a3f47"),
    ("cobalt", "Кобальтовые", "Кобальтовая", "кобальта", "#4a6fd0", "Кобальтовая руда", "#2f4a8a"),
    ("chromium", "Хромовые", "Хромовая", "хрома", "#d0d8e8", "Хромит", "#4a4f58"),
    ("lithium", "Литиевые", "Литиевая", "лития", "#c8e0d8", "Литиевая руда", "#8ab0a4"),
    ("uranium", "Урановые", "Урановая", "урана", "#7dff5a", "Урановая руда", "#3f6b2f"),
    ("bronze", "Бронзовые", "Бронзовая", "бронзы", "#c08040", {"copper_ingot": 3, "tin_ingot": 1}, None),
    ("brass", "Латунные", "Латунная", "латуни", "#d8b040", {"copper_ingot": 2, "zinc_ingot": 1}, None),
    ("electrum", "Электрумовые", "Электрумовая", "электрума", "#e6d080", {"gold_ingot": 1, "silver_ingot": 1}, None),
]
EXIST = {"iron_ingot", "copper_ingot", "steel", "iron_plate", "gear", "wire"}


def form_name(adj_pl, adj_f, gen, form):
    """Название изделия по форме: «Медные пластины», «Медная проволока», «Слиток олова»."""
    if form == "ingot":
        return "Слиток " + gen
    if form in ("wire", "spring", "beam", "foil"):
        return adj_f + " " + METAL_FORMS[form][0]
    if form == "dust":
        return "Порошок " + gen
    return adj_pl + " " + METAL_FORMS[form][0]


def build_metals():
    for f in FORM_ORDER + ["nugget", "raw_ore"]:
        fn = {"nugget": m_nugget, "raw_ore": m_raw_ore}.get(f) or METAL_FORMS[f][1]
        MOD("cat_" + f, {"nugget": "Самородок", "raw_ore": "Руда с прожилками"}.get(f, METAL_FORMS.get(f, (f,))[0].capitalize()), fn(), "Металлы")
    for mid, adj_pl, adj_f, gen, col, ore, ore_col in METALS:
        # руда
        if isinstance(ore, str):
            I(mid + "_ore", ore, "Порода с вкраплениями %s. Переплавьте в печи или плавильне." % gen, col, "Руда", "cat_raw_ore", price=3, catalog="Руда и металлы")
            I(mid + "_nugget", "Самородок " + gen, "Чистый кусочек %s — сразу в слиток без печи (3 штуки)." % gen, col, "Руда", "cat_nugget", price=6, rarity="rare", catalog="Руда и металлы")
        for f in FORM_ORDER:
            iid = mid + "_" + f
            if iid in EXIST or (mid == "steel" and f == "ingot"):
                continue
            nm = form_name(adj_pl, adj_f, gen, f)
            price = {"ingot": 6, "dust": 5}.get(f, 8)
            I(iid, nm, METAL_FORMS[f][2] + " Материал: %s." % gen, col, "Материалы" if f == "ingot" else "Детали", "cat_" + f, price=price,
              catalog="Руда и металлы")
        ingot = {"iron": "iron_ingot", "copper": "copper_ingot", "steel": "steel"}.get(mid, mid + "_ingot")
        # рецепты: руда → слиток, самородки → слиток, сплавы, слиток → формы
        if isinstance(ore, str):
            R("smelt_" + mid, "Слиток " + gen, {mid + "_ore": 2}, {ingot: 1}, 3.0, ["furnace", "smelter"])
            R("nuggets_" + mid, "Слиток %s из самородков" % gen, {mid + "_nugget": 3}, {ingot: 1}, 1.0, ["workbench"])
        elif isinstance(ore, dict):
            R("alloy_" + mid, "Сплав: " + gen, dict(ore), {ingot: 2}, 4.0, ["smelter"])
        outs = {"plate": ({ingot: 2}, 2), "rod": ({ingot: 1}, 2), "wire": ({ingot: 1}, 3), "screw": ({ingot: 1}, 6), "bolt": ({ingot: 1}, 4),
                "gear": ({ingot: 2}, 2), "spring": ({ingot: 1}, 1), "beam": ({ingot: 4}, 1), "pipe_part": ({ingot: 2}, 2), "foil": ({ingot: 1}, 2),
                "dust": ({ingot: 1}, 1)}
        for f, (inp, n) in outs.items():
            iid = mid + "_" + f
            if iid in EXIST or iid not in items:
                continue
            R("make_" + iid, items[iid]["name"], inp, {iid: n}, 2.0, ["workshop", "assembler"])


# ================================================================== самоцветы
GEMS = [("ruby", "Рубин", "#e0263d"), ("sapphire", "Сапфир", "#2f5fd6"), ("emerald", "Изумруд", "#2fb85a"), ("topaz", "Топаз", "#f2a81f"),
        ("amethyst", "Аметист", "#9a4dff"), ("diamond", "Алмаз", "#e6f6ff"), ("opal", "Опал", "#f0d8ff"), ("onyx", "Оникс", "#2a2830"),
        ("jade", "Нефрит", "#4fb88a"), ("garnet", "Гранат", "#8a1a2a"), ("aquamarine", "Аквамарин", "#6fe0e6"), ("citrine", "Цитрин", "#f2d24a")]


def build_gems():
    MOD("cat_gem_raw", "Самоцвет в породе", m_gem_raw(), "Самоцветы")
    MOD("cat_gem_cut", "Огранённый камень", m_gem_cut(), "Самоцветы")
    for gid, nm, col in GEMS:
        I(gid + "_raw", nm + " в породе", "Необработанный самоцвет. Огранка — на верстаке.", col, "Руда", "cat_gem_raw", stack=20, price=25, rarity="rare", catalog="Самоцветы")
        I(gid, nm, "Огранённый самоцвет: дорого продаётся, идёт на украшения, линзы и электронику.", col, "Материалы", "cat_gem_cut", stack=20, price=60, rarity="rare", catalog="Самоцветы")
        R("cut_" + gid, "Огранить: " + nm, {gid + "_raw": 1}, {gid: 1}, 4.0, ["workbench", "workshop"])


# ================================================================== электроника
def m_resistor():
    return [P("capsule", (0.1, 0.3, 0.1), (0, 0, 0), "#d9c9a0", "paint", tint=False, rot=(0, 0, 90))] + \
        [P("torus", (0.11, 0.2, 0.11), (-0.06 + k * 0.05, 0, 0), c, "paint", tint=False, rot=(0, 0, 90), seg=8) for k, c in enumerate(("#c03020", W, "#2a2d33"))] + \
        [P("cylinder", (0.015, 0.2, 0.015), (s * 0.24, 0, 0), CHR, "metal", tint=False, rot=(0, 0, 90), seg=4) for s in (-1, 1)]


def m_capacitor():
    return [P("cylinder", (0.18, 0.32, 0.18), (0, 0.06, 0), W, "paint", seg=12), P("cylinder", (0.18, 0.02, 0.18), (0, 0.23, 0), "#9aa3ad", "metal", tint=False, seg=12),
            P("box", (0.03, 0.3, 0.19), (0.08, 0.06, 0), "#e6e3d8", "paint", tint=False),
            P("cylinder", (0.015, 0.16, 0.015), (0.04, -0.17, 0), CHR, "metal", tint=False, seg=4), P("cylinder", (0.015, 0.16, 0.015), (-0.04, -0.17, 0), CHR, "metal", tint=False, seg=4)]


def m_chip(pins=6, size=0.3, glow=None):
    a = [P("box", (size, 0.06, size * 0.7), (0, 0, 0), "#1d1e21", "dark", tint=False), P("box", (size * 0.3, 0.005, size * 0.2), (0, 0.033, 0), W, "paint")]
    for k in range(pins):
        for s in (-1, 1):
            a.append(P("box", (0.02, 0.02, 0.06), (-size * 0.4 + k * size * 0.8 / max(1, pins - 1), -0.02, s * size * 0.38), CHR, "metal", tint=False))
    a.append(P("cylinder", (0.03, 0.007, 0.03), (-size * 0.38, 0.033, -size * 0.22), "#3a3f47", "dark", tint=False, seg=8))
    if glow:
        a.append(P("box", (size * 0.5, 0.01, size * 0.35), (0, 0.04, 0), glow, "glow", tint=False, anim="pulse"))
    return a


def m_cpu():
    a = [P("box", (0.36, 0.03, 0.36), (0, 0, 0), "#1f6b3d", "paint", tint=False), P("box", (0.26, 0.04, 0.26), (0, 0.03, 0), "#c0c4cc", "metal", tint=False),
         P("box", (0.12, 0.005, 0.06), (0, 0.052, 0), W, "paint")]
    for k in range(8):
        a.append(P("box", (0.02, 0.005, 0.32), (-0.14 + k * 0.04, -0.016, 0), BRASS, "metal", tint=False))
    return a


def m_board(chips=3, col="#1f6b3d"):
    a = [P("box", (0.5, 0.025, 0.36), (0, 0, 0), col, "paint", tint=False)]
    for k in range(chips):
        a.append(P("box", (0.1, 0.035, 0.08), (-0.15 + k * 0.15, 0.025, -0.08), "#1d1e21", "dark", tint=False))
    for k in range(6):
        a.append(P("box", (0.36, 0.004, 0.008), (0.03, 0.014, -0.15 + k * 0.05), BRASS, "metal", tint=False))
    a += [P("cylinder", (0.05, 0.08, 0.05), (0.17, 0.05, 0.1), W, "paint", seg=8), P("cylinder", (0.05, 0.08, 0.05), (0.08, 0.05, 0.12), W, "paint", seg=8),
          P("box", (0.12, 0.05, 0.05), (-0.17, 0.035, 0.13), "#2a2d33", "dark", tint=False),
          P("sphere", (0.03, 0.03, 0.03), (-0.2, 0.03, -0.14), "#40ff6a", "glow", tint=False, anim="blink")]
    return a


def m_display():
    return [P("box", (0.5, 0.34, 0.04), (0, 0.17, 0), "#1d1e21", "dark", tint=False), P("box", (0.44, 0.28, 0.01), (0, 0.17, 0.022), W, "glow", anim="flicker_soft"),
            P("box", (0.06, 0.12, 0.04), (0, -0.04, -0.02), "#3a3f47", "metal", tint=False), P("box", (0.26, 0.02, 0.16), (0, -0.1, -0.02), "#3a3f47", "metal", tint=False)]


def m_sensor():
    return [P("box", (0.3, 0.06, 0.24), (0, 0, 0), "#1f4a8a", "paint", tint=False), P("cylinder", (0.16, 0.12, 0.16), (0, 0.09, 0), W, "metal", seg=12),
            P("sphere", (0.12, 0.08, 0.12), (0, 0.16, 0), "#9fd8ff", "glass", tint=False, seg=10),
            P("box", (0.06, 0.02, 0.2), (0.15, -0.02, 0), BRASS, "metal", tint=False)]


def m_antenna():
    return [P("box", (0.16, 0.08, 0.16), (0, 0, 0), "#2a2d33", "dark", tint=False), P("cylinder", (0.03, 0.6, 0.03), (0, 0.32, 0), W, "metal", seg=6),
            P("sphere", (0.06, 0.06, 0.06), (0, 0.63, 0), "#ff3b2f", "glow", tint=False, anim="blink"),
            P("torus", (0.12, 0.2, 0.12), (0, 0.2, 0), W, "metal", seg=10), P("torus", (0.1, 0.2, 0.1), (0, 0.35, 0), W, "metal", seg=10)]


def m_coil():
    return [P("cylinder", (0.12, 0.36, 0.12), (0, 0.0, 0), "#3a3f47", "dark", tint=False, rot=(0, 0, 90), seg=10)] + \
        [P("torus", (0.24, 0.35, 0.24), (-0.14 + k * 0.056, 0, 0), W, "metal", rot=(0, 0, 90), seg=12) for k in range(6)]


def m_battery_cell():
    return [P("cylinder", (0.16, 0.42, 0.16), (x, 0.0, 0), W, "metal", seg=12) for x in (-0.1, 0.1)] + \
        [P("cylinder", (0.06, 0.04, 0.06), (x, 0.23, 0), CHR, "metal", tint=False, seg=8) for x in (-0.1, 0.1)] + \
        [P("box", (0.38, 0.12, 0.18), (0, -0.12, 0), "#2a2d33", "dark", tint=False)]


def m_magnet():
    return [P("torus", (0.4, 0.4, 0.14), (0, 0.05, 0), "#c03020", "metal", tint=False, rot=(90, 0, 0), seg=14),
            P("box", (0.1, 0.12, 0.14), (-0.15, -0.12, 0), "#e6e3d8", "metal", tint=False), P("box", (0.1, 0.12, 0.14), (0.15, -0.12, 0), "#e6e3d8", "metal", tint=False),
            P("sphere", (0.05, 0.05, 0.05), (0, 0.3, 0.07), W, "glow")]


def m_fan():
    a = [P("box", (0.36, 0.36, 0.08), (0, 0.18, 0), "#2a2d33", "dark", tint=False), P("cylinder", (0.3, 0.06, 0.3), (0, 0.18, 0.02), "#1d1e21", "dark", tint=False, rot=(90, 0, 0), seg=16)]
    for k in range(5):
        a.append(P("box", (0.12, 0.02, 0.05), (0, 0.18, 0.05), W, "paint", rot=(90, k * 72, 0)))
    a.append(P("cylinder", (0.08, 0.04, 0.08), (0, 0.18, 0.07), W, "paint", rot=(90, 0, 0), seg=10))
    return a


def m_servo():
    return [P("box", (0.3, 0.2, 0.16), (0, 0, 0), W, "paint"), P("box", (0.38, 0.03, 0.16), (0, 0.05, 0), "#2a2d33", "dark", tint=False),
            P("cylinder", (0.1, 0.06, 0.1), (0.08, 0.13, 0), "#d9d9d9", "metal", tint=False, seg=10),
            P("box", (0.24, 0.02, 0.05), (0.14, 0.17, 0), "#d9d9d9", "metal", tint=False), P("box", (0.02, 0.04, 0.12), (-0.16, -0.05, 0), "#c03020", "cloth", tint=False)]


def m_orb(core="#40e0ff"):
    return [P("sphere", (0.3, 0.3, 0.3), (0, 0.1, 0), core, "glow", tint=False, anim="pulse", seg=14),
            P("torus", (0.42, 0.12, 0.42), (0, 0.1, 0), W, "metal", seg=16, anim="spin_slow"),
            P("torus", (0.4, 0.12, 0.4), (0, 0.1, 0), W, "metal", rot=(90, 0, 0), seg=16, anim="spin_slow"),
            P("cylinder", (0.26, 0.06, 0.26), (0, -0.12, 0), "#2a2d33", "dark", tint=False, seg=12)]


ELEC = [  # id, имя, описание, цвет, модель-функция, цена, рецепт (вход), станция
    ("resistor", "Резистор", "Ограничивает ток в схемах.", "#d9c9a0", m_resistor, 2, {"copper_wire": 1, "coal": 1}),
    ("capacitor", "Конденсатор", "Копит заряд и сглаживает скачки.", "#2f6fc4", m_capacitor, 3, {"aluminum_foil": 1, "plastic": 1}),
    ("transistor", "Транзистор", "Ключ в любой электронике.", "#1d1e21", lambda: m_chip(3, 0.16), 4, {"silicon": 1, "copper_wire": 1}),
    ("diode", "Диод", "Пропускает ток в одну сторону.", "#2a2d33", lambda: m_chip(2, 0.12), 2, {"silicon": 1}),
    ("led", "Светодиод", "Яркая экономная лампочка.", "#ff4d33", lambda: m_chip(2, 0.12, "#ff4d33"), 3, {"silicon": 1, "glass": 1}),
    ("microchip", "Микросхема-контроллер", "Маленький мозг для машин.", "#40ff6a", lambda: m_chip(8, 0.3), 12, {"silicon": 2, "gold_wire": 1}),
    ("processor", "Процессор", "Считает быстро. Нужен компьютерам и роботам.", "#c0c4cc", m_cpu, 40, {"microchip": 4, "gold_foil": 1}),
    ("ram_module", "Модуль памяти", "Быстрая память для компьютеров.", "#1f6b3d", lambda: m_board(4, "#1f4a2e"), 30, {"microchip": 2, "circuit": 1}),
    ("motherboard", "Материнская плата", "Основа любого компьютера.", "#1f6b3d", lambda: m_board(5), 60, {"circuit": 2, "processor": 1, "capacitor": 4}),
    ("circuit_mk2", "Плата Mk2", "Многослойная плата для улучшенных машин.", "#2f6fc4", lambda: m_board(3, "#1f3a6b"), 20, {"circuit": 2, "transistor": 4}),
    ("circuit_mk3", "Плата Mk3", "Плата с процессором для тяжёлой техники.", "#9a4dff", lambda: m_board(4, "#3a1f6b"), 50, {"circuit_mk2": 2, "processor": 1}),
    ("display_panel", "Дисплей", "Экран для пультов и терминалов.", "#40c8ff", m_display, 25, {"glass": 2, "led": 4, "microchip": 1}),
    ("temp_sensor", "Датчик температуры", "Следит за нагревом печей и реакторов.", "#ff8c1a", m_sensor, 10, {"microchip": 1, "copper_wire": 1}),
    ("motion_sensor", "Датчик движения", "Замечает монстров у ворот.", "#40ff6a", m_sensor, 12, {"microchip": 1, "glass": 1}),
    ("camera_module", "Камера", "Глаз для дронов и турелей.", "#2a2d33", m_sensor, 18, {"glass": 1, "microchip": 1, "plastic": 1}),
    ("antenna_part", "Антенна", "Передаёт сигнал на большие расстояния.", "#c0c4cc", m_antenna, 8, {"aluminum_rod": 1, "copper_wire": 2}),
    ("radio_module", "Радиомодуль", "Связь со станцией и дронами.", "#c0c4cc", lambda: m_board(2, "#2a2d33"), 20, {"antenna_part": 1, "microchip": 1}),
    ("induction_coil", "Катушка индуктивности", "Медная обмотка для моторов и трансформаторов.", "#e08a4a", m_coil, 6, {"copper_wire": 4, "iron_rod": 1}),
    ("transformer_core", "Сердечник трансформатора", "Повышает и понижает напряжение.", "#9aa5b5", m_coil, 15, {"induction_coil": 2, "steel_plate": 1}),
    ("fuse", "Предохранитель", "Сгорает вместо машины при перегрузке.", "#f2d24a", m_resistor, 1, {"glass": 1, "tin_wire": 1}),
    ("relay", "Реле", "Переключает мощные цепи слабым сигналом.", "#2f6fc4", lambda: m_chip(4, 0.2), 6, {"induction_coil": 1, "plastic": 1}),
    ("battery_cell", "Аккумуляторная ячейка", "Литиевый элемент для батарей.", "#40ff6a", m_battery_cell, 14, {"lithium_dust": 1, "aluminum_foil": 1}),
    ("battery_pack", "Батарейный блок", "Большая батарея для машин и транспорта.", "#40ff6a", m_battery_cell, 60, {"battery_cell": 6, "steel_plate": 1}),
    ("solar_cell", "Солнечный элемент", "Пластинка, которая превращает свет в ток.", "#1d3a6b", lambda: m_board(0, "#1d3a6b"), 12, {"silicon": 2, "glass": 1}),
    ("silicon", "Кремний", "Очищенный кремний из кварца — основа микросхем.", "#7a8796", m_ingot, 6, {"quartz": 2, "coal": 1}),
    ("fiber_optic", "Оптоволокно", "Свет внутри стеклянной нити: быстрая связь.", "#9fe8ff", m_wire, 10, {"glass": 2, "plastic": 1}),
    ("laser_diode", "Лазерный диод", "Сердце лазерных турелей и резаков.", "#ff3a5a", lambda: m_chip(2, 0.14, "#ff3a5a"), 25, {"ruby": 1, "microchip": 1}),
    ("magnet", "Магнит", "Сильный магнит для моторов и генераторов.", "#c03020", m_magnet, 8, {"iron_ingot": 1, "cobalt_dust": 1}),
    ("electromagnet", "Электромагнит", "Магнит, который включается током.", "#c03020", m_coil, 18, {"induction_coil": 2, "iron_rod": 1}),
    ("cooling_fan", "Вентилятор охлаждения", "Не даёт машинам перегреться.", "#2a2d33", m_fan, 8, {"plastic": 1, "motor": 1}),
    ("servo_motor", "Сервопривод", "Точный мотор для роботов и манипуляторов.", "#2f6fc4", m_servo, 20, {"motor": 1, "microchip": 1, "gear": 1}),
    ("gyroscope", "Гироскоп", "Держит равновесие дронов и турелей.", "#c0c4cc", lambda: m_orb("#40c8ff"), 30, {"brass_gear": 2, "microchip": 1}),
    ("superconductor", "Сверхпроводник", "Проводит ток без потерь — для мощных машин.", "#40e0ff", m_wire, 80, {"titanium_wire": 2, "coolant": 1}),
    ("quantum_chip", "Квантовый чип", "Невероятно быстрый процессор из кристалла.", "#d9a6ff", lambda: m_chip(8, 0.3, "#d9a6ff"), 200, {"processor": 2, "crystal": 2}),
    ("ai_core", "Ядро ИИ", "Искусственный разум для роботов и заводов.", "#40e0ff", lambda: m_orb("#40e0ff"), 500, {"quantum_chip": 2, "motherboard": 1}),
    ("nanobots", "Наноботы", "Рой крошечных роботов: чинят и строят.", "#9fe8ff", m_dust, 150, {"microchip": 6, "platinum_dust": 1}),
    ("power_cell", "Энергоячейка", "Компактный источник энергии для оружия.", "#ffd040", lambda: m_orb("#ffd040"), 40, {"battery_cell": 2, "uranium_dust": 1}),
    ("plasma_core", "Плазменное ядро", "Сгусток плазмы в магнитной ловушке.", "#ff5a3a", lambda: m_orb("#ff5a3a"), 300, {"electromagnet": 4, "power_cell": 2}),
]


def build_electronics():
    for iid, nm, desc, col, fn, price, rin in ELEC:
        mid = "cat_e_" + iid
        MOD(mid, nm, fn(), "Электроника")
        I(iid, nm, desc, col, "Детали", mid, price=price, catalog="Электроника")
        R("make_" + iid, nm, rin, {iid: 1 if price > 10 else 2}, max(1.5, min(20.0, price / 10.0)), ["assembler"])


# ================================================================== химия и материалы
def m_bottle(cap="#2a2d33", label=True):
    a = [P("cylinder", (0.22, 0.34, 0.22), (0, 0, 0), W, "glass", seg=12), P("cylinder", (0.1, 0.12, 0.1), (0, 0.23, 0), W, "glass", seg=10),
         P("cylinder", (0.12, 0.06, 0.12), (0, 0.31, 0), cap, "dark", tint=False, seg=10)]
    if label:
        a.append(P("cylinder", (0.225, 0.14, 0.225), (0, -0.02, 0), "#f2f2e6", "paint", tint=False, seg=12, top=1.0))
        a.append(P("box", (0.05, 0.05, 0.01), (0, -0.02, 0.113), "#c03020", "paint", tint=False))
    return a


def m_jar():
    return [P("cylinder", (0.3, 0.3, 0.3), (0, 0, 0), W, "glass", seg=14), P("cylinder", (0.32, 0.06, 0.32), (0, 0.18, 0), "#9aa3ad", "metal", tint=False, seg=14),
            P("cylinder", (0.31, 0.1, 0.31), (0, -0.02, 0), "#e6dcc8", "paint", tint=False, seg=14)]


def m_canister_gas():
    return [P("capsule", (0.24, 0.6, 0.24), (0, 0.08, 0), W, "metal", seg=12), P("cylinder", (0.08, 0.1, 0.08), (0, 0.42, 0), "#2a2d33", "dark", tint=False, seg=8),
            P("torus", (0.12, 0.25, 0.12), (0, 0.47, 0), "#c03020", "metal", tint=False, seg=10), P("box", (0.05, 0.12, 0.01), (0, 0.1, 0.122), "#f2f2f2", "paint", tint=False)]


def m_bag():
    return [P("sphere", (0.44, 0.36, 0.34), (0, 0.0, 0), W, "cloth", seg=10), P("cone", (0.2, 0.18, 0.18), (0, 0.22, 0), W, "cloth", seg=8),
            P("torus", (0.14, 0.2, 0.14), (0, 0.17, 0), "#8a6a40", "cloth", tint=False, seg=10), P("box", (0.18, 0.12, 0.01), (0, 0.0, 0.17), "#f2f2e6", "paint", tint=False)]


def m_bucket():
    return [P("cylinder", (0.36, 0.34, 0.36), (0, 0, 0), "#9aa3ad", "metal", tint=False, top=1.2, seg=14), P("cylinder", (0.38, 0.03, 0.38), (0, 0.15, 0), W, "paint", seg=14),
            P("torus", (0.42, 0.06, 0.42), (0, 0.17, 0), "#8a9099", "metal", tint=False, seg=14), P("torus", (0.4, 0.06, 0.2), (0, 0.27, 0), "#5a5f68", "metal", tint=False, rot=(90, 0, 0), seg=12)]


def m_bricks():
    a = []
    for k in range(6):
        a.append(P("box", (0.26, 0.1, 0.12), (-0.07 + (k % 2) * 0.14, (k // 2) * 0.105, -0.04 + ((k // 2) % 2) * 0.08), W, "stone", rot=(0, 90 * ((k // 2) % 2), 0)))
    return a


def m_sheet_roll():
    return [P("cylinder", (0.2, 0.5, 0.2), (0, 0.1, 0), W, "cloth", rot=(0, 0, 90), seg=14), P("box", (0.48, 0.01, 0.3), (0, 0.005, 0.18), W, "cloth"),
            P("torus", (0.21, 0.12, 0.21), (-0.15, 0.1, 0), "#8a6a40", "cloth", tint=False, rot=(0, 0, 90), seg=10)]


def m_pellets():
    a = [P("cylinder", (0.4, 0.06, 0.4), (0, -0.05, 0), "#2a2d33", "dark", tint=False, seg=14)]
    for k in range(14):
        ang = k * 2.4
        r = 0.05 + (k % 4) * 0.04
        a.append(P("sphere", (0.07, 0.06, 0.07), (math.cos(ang) * r, 0.0 + (k % 3) * 0.035, math.sin(ang) * r), W, "paint", seg=6))
    return a


def m_tile():
    return [P("box", (0.36, 0.05, 0.36), (0, k * 0.055, 0), W, "stone", rot=(0, k * 9, 0)) for k in range(3)] + \
        [P("box", (0.37, 0.006, 0.02), (0, 0.14, 0), "#8a8478", "stone", tint=False)]


CHEM = [  # id, имя, описание, цвет, модель, цена, рецепт, станции
    ("sulfuric_acid", "Серная кислота", "Едкая кислота для батарей и химии.", "#e6e04d", "bottle", 10, {"sulfur": 2, "water_flask": 1}, ["refinery"]),
    ("nitric_acid", "Азотная кислота", "Нужна для взрывчатки и удобрений.", "#f2b84d", "bottle", 12, {"ammonia": 1, "water_flask": 1}, ["refinery"]),
    ("alkali", "Щёлочь", "Растворяет жир и окалину.", "#b8e0ff", "bottle", 8, {"lime": 1, "water_flask": 1}, ["refinery"]),
    ("solvent", "Растворитель", "Смывает краску и масло.", "#d0f0ff", "bottle", 8, {"oil": 2}, ["refinery"]),
    ("ethanol", "Спирт", "Топливо и антисептик.", "#e6f2ff", "bottle", 6, {"wheat": 3, "water_flask": 1}, ["refinery"]),
    ("ammonia", "Аммиак", "Основа удобрений.", "#d8f0e8", "gas", 10, {"nitrogen_tank": 1, "hydrogen_tank": 1}, ["refinery"]),
    ("nitrogen_tank", "Баллон азота", "Сжатый азот из воздуха.", "#4d8cff", "gas", 8, {"canister": 1}, ["packager"]),
    ("oxygen_tank", "Баллон кислорода", "Для дыхания под водой и сварки.", "#40c8ff", "gas", 8, {"canister": 1, "water": 4}, ["packager"]),
    ("hydrogen_tank", "Баллон водорода", "Лёгкий газ — топливо будущего.", "#ff8ad8", "gas", 10, {"canister": 1, "water": 6}, ["packager"]),
    ("helium_tank", "Баллон гелия", "Охлаждает сверхпроводники.", "#f2e6ff", "gas", 25, {"canister": 1, "uranium_dust": 1}, ["packager"]),
    ("coolant", "Хладагент", "Отводит тепло от реакторов и процессоров.", "#40e0ff", "bottle", 15, {"water_flask": 1, "alkali": 1}, ["refinery"]),
    ("lubricant", "Смазка", "Машины с ней служат дольше.", "#c9a227", "jar", 5, {"oil": 1}, ["refinery"]),
    ("epoxy", "Эпоксидная смола", "Крепкий клей для композитов.", "#f2d890", "jar", 10, {"plastic": 1, "solvent": 1}, ["refinery"]),
    ("glue", "Клей", "Склеивает дерево, ткань и бумагу.", "#f2f2e6", "jar", 3, {"resin": 1}, ["workbench"]),
    ("resin", "Смола", "Липкий сок хвойных деревьев.", "#d9a040", "jar", 3, {"log": 2}, ["furnace"]),
    ("wax", "Воск", "Для свечей и пропитки.", "#f2e6a0", "jar", 3, {"honey": 1}, ["workbench"]),
    ("paint_red", "Красная краска", "Покрасить здание или предмет.", "#e0263d", "bucket", 4, {"resin": 1, "iron_dust": 1}, ["workbench"]),
    ("paint_blue", "Синяя краска", "Покрасить здание или предмет.", "#2f6fc4", "bucket", 4, {"resin": 1, "cobalt_dust": 1}, ["workbench"]),
    ("paint_yellow", "Жёлтая краска", "Покрасить здание или предмет.", "#f2c440", "bucket", 4, {"resin": 1, "sulfur": 1}, ["workbench"]),
    ("paint_green", "Зелёная краска", "Покрасить здание или предмет.", "#2fb85a", "bucket", 4, {"resin": 1, "leaves": 2}, ["workbench"]),
    ("paint_white", "Белая краска", "Покрасить здание или предмет.", "#f2f2f2", "bucket", 4, {"resin": 1, "lime": 1}, ["workbench"]),
    ("paint_black", "Чёрная краска", "Покрасить здание или предмет.", "#1d1e21", "bucket", 4, {"resin": 1, "coal": 1}, ["workbench"]),
    ("fertilizer", "Удобрение", "Грядки растят урожай вдвое быстрее.", "#7a5a2a", "bag", 6, {"biomass": 2, "ammonia": 1}, ["refinery"]),
    ("gunpowder", "Порох", "Для патронов и гранат.", "#3a3a3f", "bag", 4, {"coal": 1, "sulfur": 1, "nitric_acid": 1}, ["workshop"]),
    ("explosive", "Взрывчатка", "Ломает скалы и монстров.", "#c03020", "bag", 20, {"gunpowder": 3, "plastic": 1}, ["workshop"]),
    ("thermite", "Термит", "Горит жарче печи — режет сталь.", "#ff8c1a", "bag", 25, {"aluminum_dust": 1, "iron_dust": 1}, ["workshop"]),
    ("carbon_fiber", "Углеволокно", "Лёгкое и прочнее стали.", "#2a2d33", "roll", 40, {"coal": 4, "epoxy": 1}, ["assembler"]),
    ("graphene", "Графен", "Один слой атомов углерода: проводит ток и тепло.", "#3a3f47", "roll", 120, {"carbon_fiber": 2, "coolant": 1}, ["assembler"]),
    ("kevlar", "Кевлар", "Ткань, которую не прокусить.", "#f2c440", "roll", 35, {"plastic": 3, "nitric_acid": 1}, ["assembler"]),
    ("ceramic", "Керамика", "Выдерживает жар реакторов.", "#e6dcc8", "tile", 8, {"clay": 2}, ["furnace"]),
    ("porcelain", "Фарфор", "Изоляторы для ЛЭП и посуда.", "#f8f8f2", "tile", 10, {"clay": 2, "quartz": 1}, ["furnace"]),
    ("cement", "Цемент", "Основа бетона.", "#b8b4a8", "bag", 3, {"lime": 1, "clay": 1}, ["furnace"]),
    ("lime", "Известь", "Обожжённый известняк.", "#f2f0e6", "bag", 2, {"stone": 3}, ["furnace"]),
    ("clay", "Глина", "Мягкая и пластичная — для кирпичей и керамики.", "#b0603a", "bag", 1, {"stone": 1, "water_flask": 1}, ["workbench"]),
    ("brick", "Кирпичи", "Для печей, стен и труб.", "#a04a32", "bricks", 3, {"clay": 2}, ["furnace"]),
    ("tempered_glass", "Закалённое стекло", "Не бьётся от ударов монстров.", "#9fd8ff", "tile", 8, {"glass": 2}, ["furnace", "smelter"]),
    ("armored_glass", "Бронестекло", "Окна, которые держат пулю.", "#7fb8e0", "tile", 30, {"tempered_glass": 2, "kevlar": 1}, ["assembler"]),
    ("lens", "Линза", "Для прицелов, телескопов и лазеров.", "#d0f0ff", "gem", 15, {"glass": 1, "quartz": 1}, ["workshop"]),
    ("plastic_pellets", "Гранулы пластика", "Сырьё для литья пластиковых деталей.", "#f2f2f2", "pellets", 2, {"plastic": 1}, ["assembler"]),
    ("rubber_sheet", "Листовая резина", "Прокладки, шины и изоляция.", "#2a2d33", "roll", 4, {"rubber": 2}, ["assembler"]),
]


def build_chem():
    shapes = {"bottle": m_bottle, "jar": m_jar, "gas": m_canister_gas, "bag": m_bag, "bucket": m_bucket, "bricks": m_bricks, "roll": m_sheet_roll,
              "pellets": m_pellets, "tile": m_tile, "gem": m_gem_cut}
    names = {"bottle": "Бутыль", "jar": "Банка", "gas": "Газовый баллон", "bag": "Мешок", "bucket": "Ведро краски", "bricks": "Кирпичи",
             "roll": "Рулон", "pellets": "Гранулы", "tile": "Плитки", "gem": "Линза"}
    for k, fn in shapes.items():
        MOD("cat_c_" + k, names[k], fn(), "Химия и материалы")
    for iid, nm, desc, col, shape, price, rin, st in CHEM:
        I(iid, nm, desc, col, "Материалы", "cat_c_" + shape, price=price, catalog="Химия и материалы",
          stack=20 if shape in ("gas", "bucket") else 50)
        R("make_" + iid, nm, rin, {iid: 1}, 2.5, st)
