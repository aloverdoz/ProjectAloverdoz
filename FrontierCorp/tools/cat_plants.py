# Каталог — ПРИРОДА: деревья, кусты, цветы, травы, грибы, дикие овощи, кактусы, водные и инопланетные растения,
# камни, рудные жилы самоцветов и металлов, природные объекты. Всё — «ресурсы» (их рубят/копают), с добычей.
import math
from art_kit import P, M, shade
from art_world import roots, pine, oak, birch, dead_tree, rock_shape

resources, models = {}, {}


def D(item, a, b, on="break", ch=1.0):
    return {"item": item, "min": a, "max": b, "on": on, "chance": ch}


def RS(id, name, parts, cat, hp, tool, drops, blocks=False, stump="", respawn=0, scale=(0.8, 1.2), low=False, xp=1, mcat=None):
    models["cn_" + id] = M(name, parts, "Каталог: " + (mcat or cat))
    resources[id] = {"name": name, "model": "cn_" + id, "hp": hp, "tool": tool, "drops": drops, "category": cat, "blocks": blocks, "stump": stump,
                     "respawn": respawn, "scale": list(scale), "xp": xp, "low": low, "catalog": mcat or cat}


# ------------------------------------------------------------------ деревья
def fruit_tree(leaf, fruit, h=1.0, trunk="#6b4a2a"):
    a = []
    a.append(P("cylinder", (0.5, 1.8 * h, 0.5), (0, 0.9 * h, 0), trunk, "wood", top=0.7, seg=8))
    roots(a, 0.55, trunk, n=5, h=0.22)
    for k, ang in enumerate((0.4, 2.5, 4.4)):
        x, z = math.cos(ang), math.sin(ang)
        a.append(P("cylinder", (0.16, 1.0 * h, 0.16), (x * 0.35, 1.9 * h, z * 0.35), trunk, "wood", rot=(z * 40, 0, -x * 40), top=0.5, seg=6))
    for k, (x, y, z, s) in enumerate(((0, 2.8, 0, 2.2), (0.8, 2.5, 0.4, 1.5), (-0.7, 2.6, -0.3, 1.6), (0.2, 2.4, -0.8, 1.4), (-0.3, 3.4, 0.3, 1.4))):
        a.append(P("sphere", (s, s * 0.8, s), (x, y * h, z), shade(leaf, 0.9 + 0.08 * (k % 3)), "leaf", anim="sway", seg=8))
    if fruit:
        for k in range(14):
            ang = k * 2.4
            r = 0.8 + (k % 3) * 0.2
            a.append(P("sphere", (0.18, 0.18, 0.18), (math.cos(ang) * r, (2.1 + (k % 4) * 0.3) * h, math.sin(ang) * r), fruit, "paint", anim="sway", seg=6))
    return a


def palm(leaf="#3f9a3a", h=1.0, coco=True):
    a = []
    for k in range(7):
        a.append(P("cylinder", (0.36 - k * 0.02, 0.62 * h, 0.36 - k * 0.02), (k * k * 0.012, 0.31 * h + k * 0.6 * h, 0), "#8a6a40", "wood", rot=(0, 0, -k * 2.5), seg=7))
        a.append(P("torus", (0.38 - k * 0.02, 0.15, 0.38 - k * 0.02), (k * k * 0.012, 0.6 * h * (k + 1) - 0.02, 0), "#6b4a2a", "wood", seg=7))
    top = (0.6, 4.3 * h, 0)
    for k in range(8):
        ang = k * math.pi / 4
        a.append(P("box", (2.4, 0.05, 0.5), (top[0] + math.cos(ang) * 1.0, top[1] - 0.25, math.sin(ang) * 1.0), shade(leaf, 0.9 + 0.05 * (k % 3)), "leaf",
                   rot=(0, -math.degrees(ang), -22), anim="sway"))
    if coco:
        for k in range(4):
            a.append(P("sphere", (0.26, 0.28, 0.26), (top[0] + math.cos(k * 1.6) * 0.25, top[1] - 0.35, math.sin(k * 1.6) * 0.25), "#5a3a1a", "wood", seg=7))
    return a


def willow(leaf="#7fa83a"):
    a = []
    a.append(P("cylinder", (0.8, 2.4, 0.8), (0, 1.2, 0), "#5a4630", "wood", top=0.7, seg=8))
    roots(a, 0.8, "#5a4630", n=6, h=0.3)
    a.append(P("sphere", (3.2, 1.6, 3.2), (0, 3.2, 0), leaf, "leaf", anim="sway", seg=10))
    for k in range(14):
        ang = k * math.pi / 7
        a.append(P("cylinder", (0.35, 2.2, 0.15), (math.cos(ang) * 1.45, 2.2, math.sin(ang) * 1.45), shade(leaf, 0.85 + 0.05 * (k % 3)), "leaf",
                   rot=(0, -math.degrees(ang), 0), top=0.5, seg=5, anim="sway"))
    return a


def cypress(leaf="#2f5a2f"):
    a = [P("cylinder", (0.3, 1.0, 0.3), (0, 0.5, 0), "#5a4630", "wood", seg=6)]
    for k in range(5):
        a.append(P("sphere", (1.1 - k * 0.15, 1.5, 1.1 - k * 0.15), (0, 1.2 + k * 0.9, 0), shade(leaf, 0.9 + 0.05 * (k % 2)), "leaf", anim="sway", seg=8))
    a.append(P("cone", (0.5, 1.0, 0.5), (0, 5.2, 0), leaf, "leaf", anim="sway", seg=6))
    return a


def baobab():
    a = [P("cylinder", (1.6, 3.2, 1.6), (0, 1.6, 0), "#8a7058", "wood", top=0.8, seg=10)]
    for k in range(6):
        ang = k * math.pi / 3
        x, z = math.cos(ang), math.sin(ang)
        a.append(P("cylinder", (0.25, 1.4, 0.25), (x * 0.6, 3.6, z * 0.6), "#8a7058", "wood", rot=(z * 55, 0, -x * 55), top=0.4, seg=6))
        a.append(P("sphere", (1.0, 0.45, 1.0), (x * 1.3, 4.1, z * 1.3), "#5f8a3a", "leaf", anim="sway", seg=7))
    return a


def mushroom_tree(cap, stem="#e6dcc8", h=1.0, glow=False):
    a = [P("cylinder", (0.6, 3.0 * h, 0.6), (0, 1.5 * h, 0), stem, "paint", top=0.8, seg=10)]
    roots(a, 0.6, stem, n=5, h=0.25)
    a.append(P("sphere", (3.4, 1.3, 3.4), (0, 3.2 * h, 0), cap, "glow" if glow else "paint", seg=14, anim="pulse" if glow else ""))
    a.append(P("cylinder", (3.0, 0.1, 3.0), (0, 2.95 * h, 0), shade(cap, 0.6), "paint", seg=14))
    for k in range(9):
        ang = k * 2.4
        r = 0.6 + (k % 3) * 0.35
        a.append(P("sphere", (0.3, 0.12, 0.3), (math.cos(ang) * r, 3.65 * h, math.sin(ang) * r), "#f2f2e6" if not glow else "#ffffff", "glow" if glow else "paint", seg=6))
    return a


def crystal_tree(col):
    a = [P("prism", (0.5, 3.0, 0.5), (0, 1.5, 0), shade(col, 0.6), "glass", seg=6)]
    for k in range(7):
        ang = k * 0.9
        a.append(P("prism", (0.3, 1.5 - k * 0.1, 0.3), (math.cos(ang) * 0.4, 2.6 + k * 0.2, math.sin(ang) * 0.4), col, "glow", rot=(math.sin(ang) * 35, 0, -math.cos(ang) * 35), anim="pulse"))
    return a


def spiral_tree(col):
    a = []
    for k in range(14):
        ang = k * 0.6
        a.append(P("sphere", (0.5 - k * 0.02, 0.5, 0.5 - k * 0.02), (math.cos(ang) * 0.4, 0.3 + k * 0.32, math.sin(ang) * 0.4), shade(col, 0.6 + k * 0.03), "paint", seg=7))
    a.append(P("sphere", (1.2, 1.2, 1.2), (0, 4.9, 0), col, "glow", anim="pulse", seg=10))
    return a


def tentacle_tree(col):
    a = [P("sphere", (1.4, 0.8, 1.4), (0, 0.3, 0), shade(col, 0.5), "paint", seg=8)]
    for k in range(5):
        ang = k * 2 * math.pi / 5
        x, z = math.cos(ang), math.sin(ang)
        for j in range(5):
            a.append(P("sphere", (0.4 - j * 0.06, 0.6, 0.4 - j * 0.06), (x * (0.3 + j * 0.25), 0.6 + j * 0.55, z * (0.3 + j * 0.25)), shade(col, 0.7 + j * 0.07), "paint", seg=6, anim="sway"))
        a.append(P("sphere", (0.3, 0.3, 0.3), (x * 1.6, 3.5, z * 1.6), col, "glow", anim="pulse", seg=8))
    return a


def bubble_tree(col):
    a = [P("cylinder", (0.25, 2.5, 0.25), (0, 1.25, 0), "#4a3a5a", "wood", seg=6)]
    for k, (x, y, z, s) in enumerate(((0, 3.0, 0, 1.6), (0.8, 2.4, 0.4, 0.9), (-0.7, 2.6, -0.3, 1.0), (0.3, 3.8, -0.4, 0.8), (-0.3, 2.1, 0.7, 0.7))):
        a.append(P("sphere", (s, s, s), (x, y, z), col, "glass", seg=12, anim="breathe"))
        a.append(P("sphere", (s * 0.4, s * 0.4, s * 0.4), (x, y, z), shade(col, 1.3), "glow", seg=8, anim="pulse"))
    return a


def build_trees():
    T = "Деревья"
    wood = lambda lo=3, hi=5, extra=(): [D("branch", 1, 2, "hit", 0.6), D("log", lo, hi), D("leaves", 1, 2, "hit", 0.3)] + list(extra)
    for tid, nm, trunk, crown, h, layers, snow, tip in (
            ("pine_tall", "Высокая сосна", "#6b4a2a", "#2f5a2f", 1.35, 5, None, None), ("pine_snow", "Заснеженная ель", "#5a3d24", "#2a4a2a", 1.1, 5, "#f2f6fa", "#f2f6fa"),
            ("spruce_blue", "Голубая ель", "#5a3d24", "#4a7a8a", 1.0, 5, None, None), ("pine_young", "Молодая сосенка", "#6b4a2a", "#3f7a3a", 0.6, 3, None, None),
            ("larch", "Лиственница", "#6b4a2a", "#9ab83a", 1.15, 4, None, None), ("cedar", "Кедр", "#5a3d24", "#2a4f2a", 1.25, 5, None, None),
            ("pine_autumn", "Рыжая лиственница", "#6b4a2a", "#d0902a", 1.1, 4, None, None), ("fir_dark", "Тёмная пихта", "#4a3020", "#1f3f25", 1.2, 5, None, None)):
        RS("tree_" + tid, nm, pine(trunk, crown, h, layers, snow, tip), T, int(60 * h + 20), "axe", wood(), blocks=True, stump="stump", scale=(0.8, 1.3))
    for tid, nm, leaf, aut, h in (("oak_dark", "Тёмный дуб", "#2f5a24", None, 1.1), ("maple_red", "Красный клён", "#c0302a", "#e04a2a", 1.0),
                                  ("maple_orange", "Оранжевый клён", "#e0802a", "#f2a040", 1.0), ("maple_yellow", "Жёлтый клён", "#e6c040", "#f2d860", 1.0),
                                  ("linden", "Липа", "#5f9a3a", None, 1.1), ("elm", "Вяз", "#4f8a3a", None, 1.2), ("chestnut", "Каштан", "#3f7a2f", "#f2f2e6", 1.0),
                                  ("sakura", "Сакура", "#f2a0c8", "#ffd0e6", 0.9), ("sakura_white", "Белая сакура", "#f6e6f0", "#ffffff", 0.9),
                                  ("jacaranda", "Жакаранда", "#9a6ad8", "#b890f0", 1.0), ("ash", "Ясень", "#6aa040", None, 1.15)):
        RS("tree_" + tid, nm, oak("#5c3d24", leaf, h, aut), T, int(80 * h), "axe", wood(3, 6), blocks=True, stump="stump", scale=(0.8, 1.3))
    for tid, nm, h in (("birch_tall", "Высокая берёза", 1.3), ("birch_young", "Молодая берёзка", 0.7)):
        RS("tree_" + tid, nm, birch(h), T, int(60 * h), "axe", wood(2, 4), blocks=True, stump="stump")
    for tid, nm, leaf, fruit, item in (("apple_green", "Яблоня (зелёные)", "#4f8a2f", "#9ad040", "apple"), ("orange", "Апельсиновое дерево", "#3f7a2f", "#ff9a1a", "orange"),
                                       ("lemon", "Лимонное дерево", "#4f8a2f", "#f2e040", "lemon"), ("pear", "Груша", "#5f9a3a", "#c8d040", "pear"),
                                       ("peach", "Персиковое дерево", "#5f9a3a", "#ffb07a", "peach"), ("plum", "Слива", "#3f7a2f", "#6a2a8a", "plum"),
                                       ("cherry", "Вишня", "#4f8a2f", "#b0102a", "berry"), ("apple_red", "Яблоня (красные)", "#4f8a2f", "#d8322a", "apple_red")):
        RS("tree_" + tid, nm, fruit_tree(leaf, fruit), T, 70, "axe", wood(2, 4, (D(item, 1, 1, "hit", 0.35), D(item, 2, 4))), blocks=True, stump="stump", respawn=0)
    for tid, nm, leaf, coco in (("palm", "Пальма", "#3f9a3a", True), ("palm_date", "Финиковая пальма", "#6aa040", False), ("palm_tall", "Высокая пальма", "#2f8a3a", True)):
        RS("tree_" + tid, nm, palm(leaf, 1.2 if tid == "palm_tall" else 1.0, coco), T, 60, "axe", wood(2, 3, (D("fiber", 2, 4),)), blocks=True, stump="stump")
    RS("tree_willow", "Ива", willow(), T, 100, "axe", wood(4, 6, (D("fiber", 1, 3),)), blocks=True, stump="stump")
    RS("tree_willow_gold", "Золотая ива", willow("#c8c040"), T, 100, "axe", wood(4, 6), blocks=True, stump="stump")
    RS("tree_cypress", "Кипарис", cypress(), T, 70, "axe", wood(2, 4), blocks=True, stump="stump")
    RS("tree_thuja", "Туя", cypress("#3f6b3a"), T, 50, "axe", wood(1, 3), blocks=True, stump="stump", scale=(0.6, 0.9))
    RS("tree_baobab", "Баобаб", baobab(), T, 220, "axe", wood(8, 12), blocks=True, stump="stump", scale=(0.9, 1.2))
    for tid, nm in (("dead_grey", "Мёртвое дерево (серое)"), ("dead_burnt", "Обгоревшее дерево")):
        a = dead_tree()
        if tid == "dead_burnt":
            for p in a:
                if p["mat"] == "wood":
                    p["color"] = "#2a2420"
        RS("tree_" + tid, nm, a, T, 40, "axe", [D("branch", 2, 4), D("log", 1, 2), D("coal", 0, 2) if tid == "dead_burnt" else D("branch", 0, 1)], blocks=True)
    A = "Инопланетные деревья"
    for tid, nm, a, item in (("shroom_red", "Гриб-великан (красный)", mushroom_tree("#c0302a"), "mushroom"),
                             ("shroom_brown", "Гриб-великан (бурый)", mushroom_tree("#8a5a30"), "porcini"),
                             ("shroom_glow", "Светящийся гриб-дерево", mushroom_tree("#40c8ff", "#d0f0ff", 1.1, True), "glow_berry"),
                             ("shroom_violet", "Фиолетовый гриб-дерево", mushroom_tree("#9a4dff", "#e6d0ff", 1.0, True), "alien_fruit"),
                             ("crystal_tree_blue", "Кристаллическое дерево (синее)", crystal_tree("#40c8ff"), "crystal"),
                             ("crystal_tree_pink", "Кристаллическое дерево (розовое)", crystal_tree("#ff6ad8"), "crystal"),
                             ("spiral_tree", "Спиральное дерево", spiral_tree("#7dff5a"), "alien_tissue"),
                             ("tentacle_tree", "Щупальцевое дерево", tentacle_tree("#d84d9a"), "alien_tissue"),
                             ("bubble_tree", "Пузырчатое дерево", bubble_tree("#9fe8ff"), "alien_fruit"),
                             ("spiral_tree_gold", "Золотое спиральное дерево", spiral_tree("#f2c440"), "alien_fruit")):
        tool = "pickaxe" if "crystal" in tid else "axe"
        RS("alien_" + tid, nm, a, A, 120, tool, [D(item, 1, 3), D("log" if tool == "axe" else "quartz", 2, 4), D(item, 1, 1, "hit", 0.2)], blocks=True, scale=(0.8, 1.3), xp=3, mcat=A)


# ------------------------------------------------------------------ кусты, цветы, травы, грибы
def bush(leaf, berry=None, n=4, flowers=None, s=1.0):
    a = []
    for k in range(n):
        ang = k * 2.4
        r = 0.0 if k == 0 else 0.4
        sz = (1.2 if k == 0 else 0.85) * s
        a.append(P("sphere", (sz, sz * 0.8, sz), (math.cos(ang) * r * s, sz * 0.38 + 0.05, math.sin(ang) * r * s), shade(leaf, 0.85 + 0.07 * (k % 3)), "leaf", anim="sway_bush", seg=8))
    for col in (berry, flowers):
        if col:
            for k in range(12):
                ang = k * 2.4
                r = (0.45 + (k % 3) * 0.12) * s
                a.append(P("sphere", (0.12, 0.12, 0.12) if col == berry else (0.18, 0.08, 0.18), (math.cos(ang) * r, (0.45 + (k % 4) * 0.1) * s, math.sin(ang) * r), col,
                           "paint", seg=6, anim="sway_bush"))
    return a


def fern(leaf):
    a = []
    for k in range(9):
        ang = k * 0.7
        a.append(P("box", (1.1, 0.03, 0.22), (math.cos(ang) * 0.4, 0.35 + (k % 3) * 0.05, math.sin(ang) * 0.4), shade(leaf, 0.85 + 0.05 * (k % 3)), "leaf",
                   rot=(0, -math.degrees(ang), 30 + (k % 3) * 8), anim="sway_grass"))
    return a


def flower(petal, center="#f2c440", h=0.5, n=3, kind="daisy"):
    a = []
    for k in range(n):
        x, z = math.cos(k * 2.1) * 0.15 * (k > 0), math.sin(k * 2.1) * 0.15 * (k > 0)
        hh = h * (1.0 - 0.15 * k)
        a.append(P("cylinder", (0.03, hh, 0.03), (x, hh / 2, z), "#4f8a2f", "leaf", seg=4, anim="sway_grass"))
        a.append(P("sphere", (0.18, 0.04, 0.08), (x + 0.06, hh * 0.4, z), "#5f9a3a", "leaf", rot=(0, k * 60, 25), seg=5, anim="sway_grass"))
        if kind == "daisy":
            for j in range(6):
                ang = j * math.pi / 3
                a.append(P("sphere", (0.12, 0.025, 0.05), (x + math.cos(ang) * 0.07, hh, z + math.sin(ang) * 0.07), petal, "paint", rot=(0, -math.degrees(ang), 0), seg=5, anim="sway_grass"))
            a.append(P("sphere", (0.07, 0.04, 0.07), (x, hh + 0.01, z), center, "paint", seg=6, anim="sway_grass"))
        elif kind == "tulip":
            a.append(P("sphere", (0.13, 0.18, 0.13), (x, hh + 0.04, z), petal, "paint", seg=7, anim="sway_grass"))
            a.append(P("cone", (0.13, 0.08, 0.13), (x, hh + 0.14, z), petal, "paint", seg=5, anim="sway_grass"))
        elif kind == "rose":
            a.append(P("sphere", (0.14, 0.12, 0.14), (x, hh + 0.02, z), petal, "paint", seg=7, anim="sway_grass"))
            a.append(P("torus", (0.16, 0.3, 0.16), (x, hh + 0.02, z), shade(petal, 0.8), "paint", seg=8, anim="sway_grass"))
        elif kind == "bell":
            for j in range(3):
                a.append(P("cone", (0.08, 0.1, 0.08), (x + 0.05, hh - j * 0.1, z), petal, "paint", rot=(180, 0, 0), seg=6, anim="sway_grass"))
        elif kind == "spike":
            for j in range(5):
                a.append(P("sphere", (0.07, 0.07, 0.07), (x, hh - j * 0.06, z), petal, "paint", seg=5, anim="sway_grass"))
        elif kind == "sun":
            a.append(P("cylinder", (0.4, 0.05, 0.4), (x, hh, z), petal, "paint", rot=(60, 0, 0), seg=12, anim="sway_grass"))
            a.append(P("cylinder", (0.22, 0.06, 0.22), (x, hh, z + 0.01), "#5a3a1a", "paint", rot=(60, 0, 0), seg=10, anim="sway_grass"))
    return a


def grass(col, tall=0.6, n=12, seed=None):
    a = []
    for k in range(n):
        ang = k * 2.4
        r = 0.05 + (k % 4) * 0.08
        a.append(P("cone", (0.06, tall * (0.7 + 0.1 * (k % 4)), 0.03), (math.cos(ang) * r, tall * 0.35, math.sin(ang) * r), shade(col, 0.85 + 0.05 * (k % 4)), "leaf",
                   rot=(math.sin(ang) * 15, -math.degrees(ang), math.cos(ang) * 15), seg=3, anim="sway_grass"))
        if seed and k % 3 == 0:
            a.append(P("capsule", (0.04, 0.12, 0.04), (math.cos(ang) * r * 1.3, tall * 0.75, math.sin(ang) * r * 1.3), seed, "paint", seg=4, anim="sway_grass"))
    return a


def mush(cap, n=3, glow=False, spots=True, s=1.0):
    a = []
    for k in range(n):
        x, z = math.cos(k * 2.3) * 0.2 * (k > 0) * s, math.sin(k * 2.3) * 0.2 * (k > 0) * s
        h = (0.35 - k * 0.07) * s
        a.append(P("cylinder", (0.08 * s, h, 0.08 * s), (x, h / 2, z), "#f2ead6", "paint", seg=6))
        a.append(P("sphere", (0.3 * s - k * 0.05, 0.16 * s, 0.3 * s - k * 0.05), (x, h, z), cap, "glow" if glow else "paint", seg=9, anim="pulse" if glow else ""))
        if spots:
            for j in range(3):
                a.append(P("sphere", (0.04, 0.02, 0.04), (x + math.cos(j * 2) * 0.07, h + 0.06, z + math.sin(j * 2) * 0.07), "#f6f2e8", "paint", seg=4))
    return a


def build_plants():
    K = "Кусты"
    for bid, nm, leaf, berry, item in (("blueberry", "Черничник", "#3f6b3a", "#3a3a9a", "blueberries"), ("raspberry", "Малина", "#4f8a3a", "#e0263d", "berry"),
                                       ("gooseberry", "Крыжовник", "#5f9a3a", "#9ad040", "berry"), ("currant_black", "Чёрная смородина", "#3f7a3a", "#1d1e2a", "berry"),
                                       ("currant_red", "Красная смородина", "#4f8a3a", "#e0263d", "berry"), ("strawberry", "Земляника", "#4f8a3a", "#ff3a3a", "strawberries"),
                                       ("glowberry", "Светоягодник", "#2f4a5a", "#7dff5a", "glow_berry"), ("grape_vine", "Дикий виноград", "#4f8a2f", "#7a3a9a", "grapes")):
        RS("bush_" + bid, nm, bush(leaf, berry), K, 10, "", [D(item, 2, 4), D("fiber", 0, 1), D("leaves", 0, 1)], respawn=180)
    for bid, nm, leaf, fl in (("round", "Круглый куст", "#3f7a3a", None), ("boxwood", "Самшит", "#2f5a2f", None), ("juniper", "Можжевельник", "#3a5a4a", "#4a6ab8"),
                              ("rose_bush", "Шиповник", "#3f7a3a", "#f2a0c8"), ("lilac", "Сирень", "#4f8a3a", "#b890f0"), ("hydrangea", "Гортензия", "#4f8a3a", "#7fb0f0"),
                              ("azalea", "Азалия", "#3f7a3a", "#ff6a9a"), ("jasmine", "Жасмин", "#4f8a3a", "#f8f8f2"), ("forsythia", "Форзиция", "#6a9a3a", "#f2d040"),
                              ("autumn_bush", "Осенний куст", "#c0502a", None), ("dry_bush", "Сухой куст", "#8a7a4a", None)):
        RS("bush_" + bid, nm, bush(leaf, None, 4, fl), K, 12, "", [D("leaves", 1, 3), D("fiber", 0, 2), D("branch", 0, 2)], respawn=240)
    for fid, nm, leaf in (("fern", "Папоротник", "#3f8f3a"), ("fern_dark", "Тёмный папоротник", "#2a5a2a"), ("fern_red", "Красный папоротник", "#a0402a")):
        RS("plant_" + fid, nm, fern(leaf), K, 4, "", [D("fiber", 1, 2), D("herbs", 0, 1, "break", 0.3)], respawn=200)
    F = "Цветы"
    FLOW = [("rose_red", "Красная роза", "#d8202a", "rose"), ("rose_white", "Белая роза", "#f6f2ea", "rose"), ("rose_yellow", "Жёлтая роза", "#f2d040", "rose"),
            ("rose_pink", "Розовая роза", "#f2a0c8", "rose"), ("tulip_red", "Красный тюльпан", "#e0263d", "tulip"), ("tulip_yellow", "Жёлтый тюльпан", "#f2d040", "tulip"),
            ("tulip_pink", "Розовый тюльпан", "#ff8ac8", "tulip"), ("tulip_purple", "Фиолетовый тюльпан", "#8a3ac8", "tulip"), ("tulip_white", "Белый тюльпан", "#f8f8f2", "tulip"),
            ("daisy", "Ромашка", "#f8f8f2", "daisy"), ("chamomile", "Аптечная ромашка", "#ffffff", "daisy"), ("poppy", "Мак", "#e0301a", "daisy"),
            ("cornflower", "Василёк", "#3a6ad8", "daisy"), ("dandelion", "Одуванчик", "#f2d040", "daisy"), ("marigold", "Бархатцы", "#ff9a1a", "daisy"),
            ("aster", "Астра", "#b070e0", "daisy"), ("bluebell", "Колокольчик", "#5a7ae0", "bell"), ("lily_valley", "Ландыш", "#f8f8f2", "bell"),
            ("foxglove", "Наперстянка", "#d070b0", "bell"), ("lavender", "Лаванда", "#9a7ad8", "spike"), ("lupine", "Люпин", "#6a5ad8", "spike"),
            ("salvia", "Шалфей", "#c0304a", "spike"), ("sunflower_wild", "Дикий подсолнух", "#f2c440", "sun"), ("orchid", "Орхидея", "#e6a0f0", "tulip"),
            ("violet", "Фиалка", "#7a3ac8", "daisy"), ("iris", "Ирис", "#5a4ad8", "tulip"), ("alien_starflower", "Звёздоцвет", "#40e0ff", "daisy"),
            ("alien_bellglow", "Светоколокол", "#7dff5a", "bell")]
    for fid, nm, col, kind in FLOW:
        drops = [D("fiber", 0, 1), D("herbs", 0, 1, "break", 0.25)]
        if fid in ("chamomile", "lavender", "salvia"):
            drops = [D("herbs", 1, 2), D("fiber", 0, 1)]
        if fid == "sunflower_wild":
            drops = [D("sunflower", 1, 1), D("sunflower_seeds", 1, 2)]
        a = flower(col, "#f2c440" if kind != "daisy" or fid != "cornflower" else "#2a3a8a", 0.5 if kind != "sun" else 1.1, 3 if kind != "sun" else 1, kind)
        if fid.startswith("alien"):
            for p in a:
                if p["color"] == col:
                    p["mat"] = "glow"
                    p["anim"] = "pulse"
        RS("flower_" + fid, nm, a, F, 3, "", drops, respawn=120, scale=(0.8, 1.3))
    G = "Травы"
    for gid, nm, col, tall, seed, drops in (("tall", "Высокая трава", "#6a9a3a", 0.9, None, [D("fiber", 1, 2)]), ("short", "Низкая трава", "#5f9a3a", 0.4, None, [D("fiber", 0, 1)]),
                                            ("dry", "Сухая трава", "#c8b070", 0.7, None, [D("fiber", 1, 2)]), ("blue", "Сизая трава", "#6a9aa0", 0.7, None, [D("fiber", 1, 2)]),
                                            ("red", "Красная трава", "#a04a3a", 0.6, None, [D("fiber", 1, 2)]), ("wild_wheat", "Дикая пшеница", "#d8c070", 0.9, "#e6c060", [D("wheat", 1, 2), D("wheat_seeds", 0, 1)]),
                                            ("wild_rice", "Дикий рис", "#a8c070", 0.8, "#f2eee0", [D("rice", 1, 2)]), ("reed", "Камыш", "#7a8a4a", 1.4, "#5a3a1a", [D("fiber", 2, 3)]),
                                            ("cattail", "Рогоз", "#6a8a3a", 1.5, "#4a2a1a", [D("fiber", 2, 3)]), ("clover", "Клевер", "#4f9a3a", 0.25, "#f2a0c8", [D("herbs", 0, 1, "break", 0.4)]),
                                            ("glow_grass", "Светящаяся трава", "#40e0ff", 0.6, "#ffffff", [D("fiber", 1, 2), D("glow_berry", 0, 1, "break", 0.2)]),
                                            ("cotton_wild", "Дикий хлопок", "#5f8a3a", 0.8, "#f8f8f2", [D("cotton", 1, 2)]), ("flax_wild", "Дикий лён", "#6a8a4a", 0.8, "#7fa0e0", [D("flax", 1, 2)])):
        a = grass(col, tall, 14, seed)
        if gid == "glow_grass":
            for p in a:
                p["mat"] = "glow"
        RS("grass_" + gid, nm, a, G, 2, "", drops, respawn=90, scale=(0.8, 1.4))
    MU = "Грибы"
    for mid, nm, cap, glow, item, spots in (("porcini", "Белые грибы", "#8a5a30", False, "porcini", False), ("chanterelle", "Лисички", "#f2a81f", False, "chanterelle", False),
                                            ("fly_agaric", "Мухоморы", "#e0263d", False, "fly_agaric", True), ("honey", "Опята", "#c08040", False, "mushroom", False),
                                            ("puffball", "Дождевики", "#f2ead6", False, "mushroom", False), ("blue_glow", "Синие светогрибы", "#40a0ff", True, "mushroom", False),
                                            ("pink_glow", "Розовые светогрибы", "#ff6ad8", True, "alien_fruit", False), ("green_glow", "Зелёные светогрибы", "#7dff5a", True, "glow_berry", False),
                                            ("morel", "Сморчки", "#a08060", False, "mushroom", False), ("russula", "Сыроежки", "#c84a6a", False, "mushroom", False)):
        RS("mush_" + mid, nm, mush(cap, 3, glow, spots), MU, 4, "", [D(item, 1, 2)], respawn=240, scale=(0.8, 1.5))
    for mid, nm, cap in (("giant_red", "Огромный мухомор", "#e0263d"), ("giant_brown", "Огромный боровик", "#8a5a30")):
        RS("mush_" + mid, nm, mush(cap, 1, False, True, 3.2), MU, 30, "axe", [D("mushroom", 3, 6)], blocks=True, respawn=600)


# ------------------------------------------------------------------ дикие овощи
WILD = [("potato", "Дикий картофель", "#5f9a3a", "#c8a060", "bush"), ("carrot", "Дикая морковь", "#5fa83a", "#ff8a1a", "tuft"), ("tomato", "Дикие помидоры", "#4f8a3a", "#e0322a", "bush"),
        ("cabbage", "Дикая капуста", "#8ac060", "#a8d070", "head"), ("corn", "Дикая кукуруза", "#6a9a3a", "#f2d040", "tall"), ("cucumber", "Дикие огурцы", "#3f8a3a", "#3f9a3a", "bush"),
        ("pumpkin", "Дикая тыква", "#4f8a3a", "#f28a1a", "head"), ("watermelon", "Дикий арбуз", "#4f8a3a", "#2f8a3a", "head"), ("melon", "Дикая дыня", "#5f9a3a", "#e6d070", "head"),
        ("beet", "Дикая свёкла", "#4f8a3a", "#8a1a3a", "tuft"), ("onion", "Дикий лук", "#5fa83a", "#d8b070", "tuft"), ("lettuce", "Дикий салат", "#7fd050", "#7fd050", "head"),
        ("pepper", "Дикий перец", "#4f8a3a", "#e0263d", "bush"), ("eggplant", "Дикий баклажан", "#4f8a3a", "#4a2a6a", "bush"), ("coffee_beans", "Кофейный куст", "#2f6a2f", "#8a1a1a", "bush"),
        ("herbs", "Лечебные травы", "#6fc04a", "#f2f2e6", "tuft")]


def wild_plant(leaf, fruit, kind):
    a = []
    if kind == "bush":
        a += bush(leaf, fruit, 3, None, 0.7)
    elif kind == "tuft":
        a += grass(leaf, 0.5, 10)
        a.append(P("sphere", (0.18, 0.14, 0.18), (0, 0.06, 0), fruit, "paint", seg=6))
    elif kind == "head":
        for k in range(5):
            a.append(P("sphere", (0.35, 0.04, 0.2), (math.cos(k * 1.25) * 0.25, 0.05, math.sin(k * 1.25) * 0.25), shade(leaf, 0.85 + 0.05 * (k % 3)), "leaf", rot=(0, k * 72, 8), seg=6))
        a.append(P("sphere", (0.42, 0.36, 0.42), (0.1, 0.18, 0.05), fruit, "paint", seg=10))
        a.append(P("cylinder", (0.02, 0.6, 0.02), (-0.2, 0.06, 0.2), leaf, "leaf", rot=(0, 30, 85), seg=4))
    elif kind == "tall":
        for k in range(3):
            x = -0.15 + k * 0.15
            a.append(P("cylinder", (0.05, 1.5, 0.05), (x, 0.75, 0.05 * k), leaf, "leaf", seg=5, anim="sway_grass"))
            a.append(P("sphere", (0.28, 0.03, 0.1), (x, 0.8, 0.05 * k), shade(leaf, 1.1), "leaf", rot=(0, k * 120, 25), seg=5, anim="sway_grass"))
            a.append(P("capsule", (0.1, 0.3, 0.1), (x + 0.06, 1.1, 0.05 * k), fruit, "paint", rot=(0, 0, -15), seg=6, anim="sway_grass"))
    return a


def build_wild():
    W = "Дикие овощи"
    for crop, nm, leaf, fruit, kind in WILD:
        drops = [D(crop, 1, 3), D(crop + "_seeds", 0, 1, "break", 0.5)] if crop != "herbs" else [D("herbs", 1, 3)]
        RS("wild_" + crop, nm, wild_plant(leaf, fruit, kind), W, 6, "", drops, respawn=300)


# ------------------------------------------------------------------ кактусы, пустыня, вода
def saguaro(col="#4f8a4a"):
    a = [P("capsule", (0.5, 3.2, 0.5), (0, 1.6, 0), col, "leaf", seg=10)]
    for k in range(8):
        a.append(P("box", (0.02, 3.0, 0.52), (0, 1.6, 0), shade(col, 0.8), "leaf", rot=(0, k * 22.5, 0)))
    for s, h in ((1, 1.4), (-1, 1.9)):
        a.append(P("capsule", (0.32, 0.7, 0.32), (s * 0.4, h, 0), col, "leaf", rot=(0, 0, 90), seg=8))
        a.append(P("capsule", (0.32, 1.0, 0.32), (s * 0.7, h + 0.45, 0), col, "leaf", seg=8))
    a.append(P("sphere", (0.18, 0.1, 0.18), (0, 3.25, 0), "#f2f2e6", "paint", seg=6))
    return a


def barrel_cactus(col="#5f9a4a", flower=None):
    a = [P("sphere", (0.8, 0.7, 0.8), (0, 0.32, 0), col, "leaf", seg=12)]
    for k in range(10):
        a.append(P("box", (0.02, 0.62, 0.82), (0, 0.32, 0), shade(col, 0.75), "leaf", rot=(0, k * 18, 0)))
    if flower:
        for k in range(5):
            a.append(P("sphere", (0.12, 0.06, 0.12), (math.cos(k * 1.25) * 0.12, 0.66, math.sin(k * 1.25) * 0.12), flower, "paint", seg=6))
    return a


def prickly(col="#6aa04a", fruit="#c0304a"):
    a = []
    for k, (x, y, z, r) in enumerate(((0, 0.3, 0, 0), (0.25, 0.75, 0, 20), (-0.25, 0.8, 0.05, -25), (0.4, 1.15, 0, 35), (-0.1, 1.2, 0, -5))):
        a.append(P("sphere", (0.5, 0.6, 0.12), (x, y, z), shade(col, 0.9 + 0.05 * (k % 3)), "leaf", rot=(0, 0, r), seg=8))
        a.append(P("sphere", (0.1, 0.12, 0.1), (x, y + 0.32, z), fruit, "paint", seg=6))
    return a


def agave(col="#6a9a8a"):
    a = []
    for k in range(12):
        ang = k * 2.4
        a.append(P("cone", (0.25, 1.1 - (k % 3) * 0.15, 0.08), (math.cos(ang) * 0.15, 0.45, math.sin(ang) * 0.15), shade(col, 0.85 + 0.05 * (k % 3)), "leaf",
                   rot=(math.sin(ang) * 40, -math.degrees(ang), math.cos(ang) * 40), seg=4))
    return a


def tumbleweed():
    a = [P("sphere", (0.9, 0.8, 0.9), (0, 0.42, 0), "#a88a5a", "wood", seg=7)]
    for k in range(9):
        a.append(P("torus", (0.85, 0.06, 0.85), (0, 0.42, 0), "#8a6a40", "wood", rot=(k * 20, k * 40, 0), seg=10))
    return a


def water_lily(col="#f2a0c8"):
    a = [P("cylinder", (0.9, 0.02, 0.9), (0, 0.02, 0), "#3f8f3a", "leaf", seg=12), P("cylinder", (0.6, 0.025, 0.6), (0.6, 0.02, 0.4), "#4f9a3a", "leaf", seg=10)]
    for k in range(8):
        ang = k * math.pi / 4
        a.append(P("sphere", (0.12, 0.06, 0.25), (math.cos(ang) * 0.1, 0.12, math.sin(ang) * 0.1), col, "paint", rot=(30, -math.degrees(ang) + 90, 0), seg=6))
    a.append(P("sphere", (0.1, 0.08, 0.1), (0, 0.16, 0), "#f2d040", "paint", seg=6))
    return a


def seaweed(col):
    a = []
    for k in range(6):
        x, z = math.cos(k * 1.1) * 0.2, math.sin(k * 1.1) * 0.2
        for j in range(4):
            a.append(P("sphere", (0.12, 0.45, 0.06), (x + math.sin(j) * 0.05, 0.2 + j * 0.35, z), shade(col, 0.85 + 0.05 * j), "leaf", seg=5, anim="sway"))
    return a


def coral(col):
    a = [P("sphere", (0.6, 0.3, 0.6), (0, 0.1, 0), shade(col, 0.6), "stone", seg=7)]
    for k in range(7):
        ang = k * 0.9
        a.append(P("cylinder", (0.1, 0.6 + (k % 3) * 0.2, 0.1), (math.cos(ang) * 0.18, 0.4, math.sin(ang) * 0.18), col, "paint", rot=(math.sin(ang) * 25, 0, -math.cos(ang) * 25), top=0.6, seg=6))
        a.append(P("sphere", (0.13, 0.13, 0.13), (math.cos(ang) * 0.32, 0.75 + (k % 3) * 0.2, math.sin(ang) * 0.32), shade(col, 1.2), "paint", seg=6))
    return a


def build_desert_water():
    C = "Пустыня"
    RS("cactus_saguaro", "Кактус-сагуаро", saguaro(), C, 30, "axe", [D("fiber", 2, 4), D("water_flask", 0, 1, "break", 0.3)], blocks=True, low=False, scale=(0.8, 1.3))
    RS("cactus_barrel", "Кактус-бочка", barrel_cactus(), C, 15, "axe", [D("fiber", 1, 2)], blocks=True, low=True)
    RS("cactus_flowering", "Цветущий кактус", barrel_cactus("#5f9a4a", "#ff6ad8"), C, 15, "axe", [D("fiber", 1, 2), D("herbs", 0, 1)], blocks=True, low=True)
    RS("cactus_prickly", "Опунция", prickly(), C, 15, "axe", [D("fiber", 1, 2), D("berry", 1, 2)], blocks=True, low=True)
    RS("cactus_blue", "Голубой кактус", saguaro("#5a8a9a"), C, 30, "axe", [D("fiber", 2, 4)], blocks=True)
    RS("plant_agave", "Агава", agave(), C, 8, "", [D("fiber", 2, 3), D("sugar", 0, 1, "break", 0.3)], respawn=300)
    RS("plant_aloe", "Алоэ", agave("#7ab88a"), C, 6, "", [D("herbs", 1, 2)], respawn=300)
    RS("tumbleweed", "Перекати-поле", tumbleweed(), C, 3, "", [D("branch", 1, 3), D("fiber", 1, 2)], respawn=200)
    WA = "Водные растения"
    for lid, nm, col in (("pink", "Кувшинка розовая", "#f2a0c8"), ("white", "Кувшинка белая", "#f8f8f2"), ("yellow", "Кубышка", "#f2d040")):
        RS("lily_" + lid, nm, water_lily(col), WA, 3, "", [D("fiber", 0, 1), D("herbs", 0, 1, "break", 0.3)], respawn=200, low=True)
    for sid, nm, col in (("green", "Водоросли", "#3f8a4a"), ("brown", "Ламинария", "#8a6a2a")):
        RS("seaweed_" + sid, nm, seaweed(col), WA, 3, "", [D("fiber", 1, 2), D("biomass", 0, 1)], respawn=200)
    for cid, nm, col in (("red", "Красный коралл", "#e0503a"), ("pink", "Розовый коралл", "#ff8ab8"), ("blue", "Синий коралл", "#4a8ae0"), ("yellow", "Жёлтый коралл", "#f2c440")):
        RS("coral_" + cid, nm, coral(col), WA, 15, "pickaxe", [D("lime", 1, 2), D("stone", 0, 1)], respawn=0, low=True)


# ------------------------------------------------------------------ инопланетные растения
def alien_plant(kind, col):
    a = []
    if kind == "tendril":
        for k in range(5):
            ang = k * 1.25
            for j in range(6):
                a.append(P("sphere", (0.12 - j * 0.012, 0.25, 0.12 - j * 0.012), (math.cos(ang) * (0.1 + j * 0.06), 0.12 + j * 0.2, math.sin(ang) * (0.1 + j * 0.06)),
                           shade(col, 0.6 + j * 0.08), "paint", seg=5, anim="sway"))
            a.append(P("sphere", (0.12, 0.12, 0.12), (math.cos(ang) * 0.48, 1.32, math.sin(ang) * 0.48), col, "glow", seg=6, anim="pulse"))
    elif kind == "bulb":
        a.append(P("cylinder", (0.1, 0.8, 0.1), (0, 0.4, 0), shade(col, 0.5), "leaf", seg=6, anim="sway"))
        a.append(P("sphere", (0.6, 0.75, 0.6), (0, 1.0, 0), col, "glass", seg=10, anim="breathe"))
        a.append(P("sphere", (0.3, 0.4, 0.3), (0, 1.0, 0), shade(col, 1.3), "glow", seg=8, anim="pulse"))
        for k in range(4):
            a.append(P("sphere", (0.45, 0.04, 0.16), (math.cos(k * 1.57) * 0.2, 0.1, math.sin(k * 1.57) * 0.2), shade(col, 0.6), "leaf", rot=(0, k * 90, 10), seg=6))
    elif kind == "pod":
        for k in range(5):
            ang = k * 1.25
            a.append(P("capsule", (0.25, 0.5, 0.25), (math.cos(ang) * 0.25, 0.25, math.sin(ang) * 0.25), col, "paint", rot=(math.sin(ang) * 25, 0, -math.cos(ang) * 25), seg=8))
            a.append(P("sphere", (0.08, 0.08, 0.08), (math.cos(ang) * 0.33, 0.52, math.sin(ang) * 0.33), "#ffffff", "glow", seg=5, anim="blink"))
    elif kind == "eye":
        a.append(P("cylinder", (0.12, 1.0, 0.12), (0, 0.5, 0), "#4a3a5a", "leaf", seg=6, anim="sway"))
        a.append(P("sphere", (0.45, 0.45, 0.45), (0, 1.1, 0), "#f2ead6", "paint", seg=10, anim="sway"))
        a.append(P("sphere", (0.25, 0.25, 0.1), (0, 1.1, 0.19), col, "glow", seg=8, anim="sway"))
        a.append(P("sphere", (0.1, 0.1, 0.05), (0, 1.1, 0.24), "#101010", "dark", seg=6, anim="sway"))
    elif kind == "pitcher":
        a.append(P("cylinder", (0.45, 0.8, 0.45), (0, 0.45, 0), col, "paint", seg=10, top=1.3))
        a.append(P("cylinder", (0.4, 0.04, 0.4), (0, 0.84, 0), "#7dff5a", "glow", seg=10, anim="pulse"))
        a.append(P("sphere", (0.5, 0.1, 0.35), (0.1, 1.0, -0.15), shade(col, 0.7), "paint", rot=(30, 0, 0), seg=8))
        for k in range(4):
            a.append(P("sphere", (0.45, 0.04, 0.15), (math.cos(k * 1.57) * 0.3, 0.08, math.sin(k * 1.57) * 0.3), "#3f7a3a", "leaf", rot=(0, k * 90, 10), seg=6))
    elif kind == "crystal_flower":
        a.append(P("cylinder", (0.06, 0.7, 0.06), (0, 0.35, 0), "#3a5a6a", "leaf", seg=5))
        for k in range(6):
            ang = k * math.pi / 3
            a.append(P("prism", (0.12, 0.35, 0.05), (math.cos(ang) * 0.12, 0.78, math.sin(ang) * 0.12), col, "glow", rot=(math.sin(ang) * 50, 0, -math.cos(ang) * 50), anim="pulse"))
        a.append(P("sphere", (0.1, 0.1, 0.1), (0, 0.75, 0), "#ffffff", "glow", seg=6))
    elif kind == "fan":
        for k in range(5):
            a.append(P("cylinder", (0.9, 0.03, 0.9), (0, 0.3 + k * 0.25, 0), shade(col, 0.7 + k * 0.08), "paint", rot=(15 * (k % 2), k * 30, 10), top=0.0, seg=10, anim="sway"))
        a.append(P("cylinder", (0.08, 1.4, 0.08), (0, 0.7, 0), "#3a2a4a", "wood", seg=5))
    elif kind == "spore":
        a.append(P("cylinder", (0.18, 0.6, 0.18), (0, 0.3, 0), shade(col, 0.6), "paint", seg=7))
        a.append(P("sphere", (0.7, 0.7, 0.7), (0, 0.9, 0), col, "paint", seg=10, anim="breathe"))
        for k in range(10):
            ang = k * 2.4
            a.append(P("sphere", (0.08, 0.08, 0.08), (math.cos(ang) * 0.36, 0.9 + math.sin(k) * 0.25, math.sin(ang) * 0.36), "#ffffff", "glow", seg=5, anim="bob"))
    return a


ALIEN = [("tendril", "Усики", "alien_tissue"), ("bulb", "Светолуковица", "alien_fruit"), ("pod", "Споровик", "biomass"), ("eye", "Глаз-цветок", "monster_eye"),
         ("pitcher", "Кувшинник-хищник", "acid_sac"), ("crystal_flower", "Кристальный цветок", "crystal"), ("fan", "Веер-растение", "fiber"), ("spore", "Шар спор", "alien_tissue")]
ALIEN_COLS = [("cyan", "голубой", "#40e0ff"), ("violet", "фиолетовый", "#b34dff"), ("lime", "лаймовый", "#9dff3a")]


def build_alien():
    A = "Инопланетная флора"
    for kind, nm, item in ALIEN:
        for cid, cn, col in ALIEN_COLS:
            RS("alien_%s_%s" % (kind, cid), "%s (%s)" % (nm, cn), alien_plant(kind, col), A, 8, "", [D(item, 1, 1, "break", 0.6), D("fiber", 0, 1)], respawn=300, xp=2)


# ------------------------------------------------------------------ камни и жилы
ROCKS = [("granite", "Гранит", "#8a8478", None), ("basalt", "Базальт", "#3a3a40", None), ("sandstone", "Песчаник", "#d0b080", None), ("marble", "Мрамор", "#f0eee6", None),
         ("limestone", "Известняк", "#d8d2c0", None), ("slate", "Сланец", "#4a5058", None), ("red_rock", "Красная скала", "#a0503a", None), ("obsidian", "Обсидиан", "#1d1a24", None),
         ("mossy", "Камень во мху", "#7a7a70", "#4f7a3a"), ("snowy", "Камень в снегу", "#8a8a90", "#f2f6fa"), ("clay_rock", "Глиняный холм", "#b0603a", None),
         ("chalk", "Мел", "#f6f6f0", None)]


def pebbles(col):
    a = []
    for k in range(9):
        ang = k * 2.4
        r = 0.15 + (k % 3) * 0.2
        a.append(P("sphere", (0.18 + 0.05 * (k % 3), 0.1, 0.15 + 0.04 * (k % 2)), (math.cos(ang) * r, 0.04, math.sin(ang) * r), shade(col, 0.85 + 0.05 * (k % 4)), "stone", seg=5))
    return a


def stalagmite(col):
    a = []
    for k, (x, z, h, r) in enumerate(((0, 0, 2.2, 0.6), (0.4, 0.2, 1.3, 0.4), (-0.3, -0.25, 1.0, 0.35), (0.15, -0.45, 0.7, 0.25))):
        a.append(P("cone", (r, h, r), (x, h / 2, z), shade(col, 0.9 + 0.05 * k), "stone", seg=7))
        for j in range(3):
            a.append(P("torus", (r * (1 - j * 0.28), 0.1, r * (1 - j * 0.28)), (x, 0.15 + j * h * 0.25, z), shade(col, 0.8), "stone", seg=7))
    return a


def build_rocks():
    R_ = "Камни"
    for rid, nm, col, moss in ROCKS:
        drop = {"marble": "stone", "limestone": "lime", "clay_rock": "clay", "chalk": "lime", "obsidian": "stone"}.get(rid, "stone")
        RS("rock_" + rid, nm, rock_shape(col, 1.0, moss=moss), R_, 45, "pickaxe", [D(drop, 2, 4), D("stone", 0, 1, "hit", 0.5), D("geode", 1, 1, "break", 0.02)],
           blocks=True, low=True, scale=(0.7, 1.4))
        RS("boulder_" + rid, "Валун: " + nm.lower(), rock_shape(col, 1.8, moss=moss), R_, 120, "pickaxe", [D(drop, 6, 10), D("geode", 1, 1, "break", 0.05)],
           blocks=True, scale=(0.9, 1.3))
    for pid, nm, col in (("grey", "Галька", "#8a8478"), ("sand", "Песчаная галька", "#d0b080"), ("dark", "Тёмная галька", "#3a3a40")):
        RS("pebbles_" + pid, nm, pebbles(col), R_, 4, "", [D("stone", 1, 2)], respawn=600, scale=(0.8, 1.3))
    for sid, nm, col in (("stalagmite", "Сталагмит", "#a8a090"), ("stalagmite_dark", "Тёмный сталагмит", "#5a5560"), ("ice_spire", "Ледяной шпиль", "#bfe8ff")):
        RS(sid, nm, stalagmite(col), R_, 60, "pickaxe", [D("stone" if sid != "ice_spire" else "water_flask", 2, 4)], blocks=True, scale=(0.7, 1.4))
    O = "Руда и самоцветы"
    # жилы новых металлов
    from cat_items import METALS, GEMS
    for mid, adj_pl, adj_f, gen, col, ore, ore_col in METALS:
        if not isinstance(ore, str):
            continue
        RS("ore_" + mid, ore, rock_shape(ore_col or "#6a6a70", 0.9, veins=col), O, 60, "pickaxe",
           [D(mid + "_ore", 1, 1, "hit", 0.6), D(mid + "_ore", 2, 4), D(mid + "_nugget", 1, 1, "break", 0.05)], blocks=True, low=True, respawn=300, scale=(0.6, 1.0), xp=2)
    for gid, nm, col in GEMS:
        RS("gem_" + gid, "Жила: " + nm.lower(), rock_shape("#4a4550", 0.8, crystal=col), O, 70, "pickaxe", [D(gid + "_raw", 1, 2), D("stone", 1, 2)], blocks=True, low=True,
           respawn=600, scale=(0.6, 1.0), xp=3)
    RS("ore_salt", "Соляная залежь", rock_shape("#e6e2da", 0.9, crystal="#ffffff"), O, 40, "pickaxe", [D("salt", 2, 4)], blocks=True, low=True, respawn=300)
    RS("ore_clay", "Глиняная залежь", rock_shape("#b0603a", 0.8), O, 25, "", [D("clay", 2, 4)], blocks=True, low=True, respawn=300)
    RS("ore_meteorite", "Метеорит", rock_shape("#2a2428", 1.2, veins="#ff6a1a", crystal="#ffd040"), O, 200, "pickaxe",
       [D("titanium_ore", 3, 6), D("tungsten_ore", 2, 4), D("crystal", 1, 2), D("void_essence", 1, 1, "break", 0.1)], blocks=True, respawn=0, xp=10)


# ------------------------------------------------------------------ природные объекты и находки
def props():
    out = {}
    a = [P("cylinder", (0.6, 2.6, 0.6), (0, 0.3, 0), "#6b4a2a", "wood", rot=(0, 0, 90), seg=9), P("cylinder", (0.5, 0.02, 0.5), (1.31, 0.3, 0), "#c49a6c", "wood", rot=(0, 0, 90), seg=9),
         P("cylinder", (0.5, 0.02, 0.5), (-1.31, 0.3, 0), "#c49a6c", "wood", rot=(0, 0, 90), seg=9), P("sphere", (0.6, 0.12, 0.4), (0.2, 0.6, 0), "#4f7a3a", "leaf", seg=6),
         P("sphere", (0.12, 0.08, 0.12), (-0.6, 0.58, 0.1), "#c2331f", "paint", seg=5)]
    out["fallen_log"] = ("Упавшее бревно", a, 30, "axe", [D("log", 2, 3), D("mushroom", 0, 1, "break", 0.3)], True, 0)
    a = [P("cylinder", (0.9, 2.4, 0.9), (0, 0.45, 0), "#5a3d24", "wood", rot=(0, 0, 90), seg=10), P("cylinder", (0.6, 2.42, 0.6), (0, 0.45, 0), "#1a120a", "dark", rot=(0, 0, 90), seg=10),
         P("sphere", (0.8, 0.15, 0.6), (0, 0.9, 0), "#4f7a3a", "leaf", seg=6)]
    out["hollow_log"] = ("Полое бревно", a, 40, "axe", [D("log", 3, 4), D("honey", 0, 1, "break", 0.2)], True, 0)
    a = []
    for k in range(6):
        a.append(P("cylinder", (0.08, 0.6, 0.08), (math.cos(k) * 0.3, 0.08, math.sin(k) * 0.3), "#f2ead6", "paint", rot=(80, k * 60, 0), seg=5))
    a += [P("sphere", (0.35, 0.3, 0.4), (0, 0.15, 0), "#f2ead6", "paint", seg=8), P("sphere", (0.08, 0.08, 0.05), (-0.08, 0.2, 0.18), "#101010", "dark", seg=5),
          P("sphere", (0.08, 0.08, 0.05), (0.08, 0.2, 0.18), "#101010", "dark", seg=5)]
    out["bone_pile"] = ("Груда костей", a, 10, "", [D("bone", 2, 4), D("monster_claw", 0, 1, "break", 0.3)], False, 0)
    a = [P("capsule", (0.5, 1.2, 0.5), (0, 0.3, 0), "#e6dcc8", "paint", rot=(0, 0, 90), seg=10)]
    for k in range(6):
        a.append(P("torus", (0.6, 0.15, 0.6), (-0.5 + k * 0.2, 0.3, 0), "#f2ead6", "paint", rot=(0, 0, 90), seg=10))
    a.append(P("sphere", (0.6, 0.5, 0.6), (0.8, 0.35, 0), "#f2ead6", "paint", seg=10))
    out["skeleton_big"] = ("Скелет гиганта", a, 40, "pickaxe", [D("bone", 5, 9), D("horn", 1, 2), D("trophy_skull", 1, 1, "break", 0.2)], True, 0)
    a = [P("torus", (0.7, 0.4, 0.7), (0, 0.15, 0), "#7a5a3a", "wood", seg=12), P("cylinder", (0.5, 0.1, 0.5), (0, 0.1, 0), "#5a3d24", "wood", seg=12)]
    for k in range(3):
        a.append(P("sphere", (0.14, 0.18, 0.14), (math.cos(k * 2.1) * 0.12, 0.2, math.sin(k * 2.1) * 0.12), "#cfe6ff", "paint", seg=7))
    out["bird_nest"] = ("Гнездо", a, 4, "", [D("egg", 1, 3), D("branch", 1, 2)], False, 600)
    a = [P("cylinder", (0.4, 0.5, 0.4), (0, 2.5, 0), "#c8a040", "wood", seg=10, top=0.8)]
    for k in range(4):
        a.append(P("torus", (0.42 - k * 0.04, 0.12, 0.42 - k * 0.04), (0, 2.3 + k * 0.12, 0), "#a8803a", "wood", seg=10))
    a += pine("#6b4a2a", "#2f5a2f", 0.8, 3)
    out["wild_beehive"] = ("Дикий улей на ели", a, 60, "axe", [D("honey", 1, 3), D("wax", 1, 2), D("log", 2, 3)], True, 0)
    a = [P("cone", (1.4, 1.2, 1.4), (0, 0.6, 0), "#8a6a40", "stone", seg=10)]
    for k in range(12):
        a.append(P("sphere", (0.04, 0.03, 0.06), (math.cos(k) * 0.5, 0.15 + (k % 4) * 0.2, math.sin(k) * 0.5), "#2a1a10", "dark", seg=4, anim="bob"))
    out["anthill"] = ("Муравейник", a, 20, "", [D("biomass", 1, 3)], False, 400)
    a = [P("cone", (1.2, 2.6, 1.2), (0, 1.3, 0), "#a0603a", "stone", seg=8)]
    for k in range(4):
        a.append(P("cone", (0.4, 1.2, 0.4), (math.cos(k * 1.6) * 0.5, 0.6, math.sin(k * 1.6) * 0.5), "#b0703a", "stone", seg=6))
    out["termite_mound"] = ("Термитник", a, 80, "pickaxe", [D("clay", 3, 6), D("biomass", 1, 2)], True, 0)
    a = [P("box", (1.2, 0.8, 0.8), (0, 0.4, 0), "#5a6a3a", "metal", rot=(0, 20, 10)), P("box", (1.24, 0.08, 0.84), (0, 0.8, 0), "#3a4a2a", "metal", rot=(0, 20, 30)),
         P("box", (0.3, 0.3, 0.02), (0.1, 0.45, 0.41), "#f2f2f2", "paint", rot=(0, 20, 10)), P("box", (0.06, 0.2, 0.02), (0.1, 0.45, 0.42), "#e0263d", "paint", rot=(0, 20, 10))]
    out["supply_drop"] = ("Сброшенный груз", a, 30, "", [D("ration", 1, 2), D("ammo", 20, 40), D("medkit", 0, 1), D("supply_crate", 0, 1, "break", 0.3)], True, 0)
    a = [P("capsule", (1.4, 2.4, 1.4), (0, 0.6, 0), "#d5dbe2", "metal", rot=(0, 0, 70), seg=12), P("box", (0.6, 0.4, 0.02), (0.2, 0.9, 0.7), "#7fc8ff", "glass", rot=(0, 0, 70)),
         P("cone", (1.6, 0.6, 1.6), (-1.1, 0.25, 0), "#3a3f47", "metal", rot=(0, 0, 70), seg=12), P("sphere", (0.12, 0.12, 0.12), (0.8, 1.3, 0), "#ff3b2f", "glow", anim="blink")]
    exh = []
    out["crashed_pod"] = ("Разбитая капсула", a + exh, 80, "pickaxe", [D("aluminum_plate", 3, 6), D("microchip", 1, 3), D("battery_cell", 1, 2), D("blueprint_basic", 0, 1, "break", 0.5)], True, 0)
    a = [P("sphere", (0.7, 0.9, 0.7), (0, 0.45, 0), "#5a8a4a", "paint", seg=10, anim="breathe"), P("sphere", (0.4, 0.5, 0.4), (0, 0.5, 0), "#9dff3a", "glow", seg=8, anim="pulse")]
    for k in range(4):
        a.append(P("sphere", (0.3, 0.06, 0.12), (math.cos(k * 1.57) * 0.3, 0.05, math.sin(k * 1.57) * 0.3), "#3a5a2a", "paint", rot=(0, k * 90, 0), seg=5))
    out["monster_egg"] = ("Яйцо монстра", a, 25, "", [D("monster_gland", 1, 2), D("alien_tissue", 0, 1, "break", 0.5), D("goo", 1, 3)], True, 0)
    for rid, nm, col in (("pillar", "Руины: колонна", "#c8c4b8"), ("wall", "Руины: стена", "#a8a498"), ("arch", "Руины: арка", "#b8b4a8")):
        a = []
        if rid == "pillar":
            a += [P("cylinder", (0.6, 2.6, 0.6), (0, 1.3, 0), col, "stone", seg=10), P("box", (0.9, 0.25, 0.9), (0, 0.12, 0), shade(col, 0.85), "stone"),
                  P("box", (0.8, 0.2, 0.8), (0.1, 2.7, 0), shade(col, 0.85), "stone", rot=(0, 10, 12))]
            for k in range(8):
                a.append(P("box", (0.03, 2.4, 0.06), (math.cos(k * 0.78) * 0.3, 1.3, math.sin(k * 0.78) * 0.3), shade(col, 0.8), "stone", rot=(0, -k * 45, 0)))
        elif rid == "wall":
            for k in range(5):
                for j in range(4 - (k % 3)):
                    a.append(P("box", (0.38, 0.28, 0.4), (-0.8 + k * 0.4, 0.14 + j * 0.3, 0), shade(col, 0.85 + 0.05 * ((k + j) % 3)), "stone"))
            a.append(P("sphere", (0.8, 0.2, 0.5), (-0.4, 0.95, 0), "#4f7a3a", "leaf", seg=6))
        else:
            for x in (-0.8, 0.8):
                a.append(P("box", (0.4, 2.2, 0.5), (x, 1.1, 0), col, "stone"))
            for k in range(7):
                ang = math.pi * k / 6
                a.append(P("box", (0.35, 0.3, 0.5), (math.cos(ang) * 0.8, 2.2 + math.sin(ang) * 0.6, 0), shade(col, 0.9), "stone", rot=(0, 0, math.degrees(ang) - 90)))
        out["ruins_" + rid] = (nm, a, 150, "pickaxe", [D("stone", 4, 8), D("old_key", 1, 1, "break", 0.05), D("gold_coin", 0, 2, "break", 0.3)], True, 0)
    a = [P("box", (1.8, 0.7, 1.1), (0, 0.45, 0), "#7a4a3a", "metal", rot=(0, 15, 6)), P("box", (0.9, 0.6, 1.0), (-0.3, 0.95, 0.05), "#5a3a2a", "metal", rot=(0, 15, 10)),
         P("cylinder", (0.55, 0.25, 0.55), (0.6, 0.2, 0.6), "#1d1e21", "dark", rot=(80, 0, 10), seg=10), P("sphere", (0.8, 0.2, 0.5), (0.3, 0.85, -0.2), "#4f7a3a", "leaf", seg=6)]
    out["old_car"] = ("Ржавая машина", a, 120, "pickaxe", [D("iron_plate", 3, 6), D("rubber", 1, 2), D("iron_gear", 1, 2), D("battery", 0, 1, "break", 0.3)], True, 0)
    a = [P("cylinder", (0.9, 0.1, 0.9), (0, 0.05, 0), "#2a2420", "dark", seg=10)]
    for k in range(6):
        ang = k * math.pi / 3
        a.append(P("sphere", (0.25, 0.18, 0.25), (math.cos(ang) * 0.5, 0.08, math.sin(ang) * 0.5), "#6a6660", "stone", seg=5))
        a.append(P("cylinder", (0.07, 0.5, 0.07), (math.cos(ang) * 0.15, 0.1, math.sin(ang) * 0.15), "#2a1a10", "wood", rot=(80, k * 60, 0), seg=5))
    out["old_campfire"] = ("Старое кострище", a, 5, "", [D("coal", 1, 2), D("branch", 0, 2)], False, 0)
    a = [P("cylinder", (1.2, 0.3, 1.2), (0, 0.15, 0), "#7a6a58", "stone", seg=10), P("cylinder", (0.4, 0.05, 0.4), (0, 0.32, 0), "#5ab4ff", "water", seg=8)]
    out["geyser"] = ("Гейзер", a, 999, "pickaxe", [D("stone", 1, 2)], True, 0)
    return out


def build_props():
    PR = "Находки и объекты"
    for pid, (nm, a, hp, tool, drops, blocks, respawn) in props().items():
        RS("prop_" + pid, nm, a, PR, hp, tool, drops, blocks=blocks, respawn=respawn, scale=(0.9, 1.1), xp=2)
    models["cn_prop_geyser"]["emitters"] = [{"kind": "steam", "pos": [0, 0.4, 0], "when": "always", "rate": 2.0, "size": 1.5}]


def build_all():
    build_trees(); build_plants(); build_wild(); build_desert_water(); build_alien(); build_rocks(); build_props()
