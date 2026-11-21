# Версия 1.0.8 (18.10): что попросили после игры по сети.
#  • Ящики: «Ящик» — 2 строки (20 ячеек), «Укреплённый ящик» — 3 строки, «Контейнер» — 4, «Склад» — 6.
#  • Месторождения разной формы, а не только цвета: кварц — друза кристаллов, железо — ржавые кубы, уголь — пласты,
#    медь — самородки с патиной, сера — жёлтые конусы с паром и т. д. (модели dep_<предмет>, правятся во вкладке «Модели»).
#  • Очередь крафта героя — 50 (settings.craft_queue_max).
#  • Явные режимы: крупная надпись сверху и цветные края экрана (settings.mode_hud) + пункт «Подсветка режимов» в настройках.
#  • «Ресурсы: мало / обычно / много» в новой игре и в сетевой комнате (world.res_levels).
#  • Сеть: порт по умолчанию 443 (свой — при создании комнаты), пробой роутера через сервер объявлений (coop.punch).
#  • Контуры развалин для роботов-строителей видны только при работе с мастерской (builders.ruins_when).
# Вызывается из gen_core.py последним; всё правится в редакторе.
import math
import random


def P(shape, size, pos, color, mat="stone", rot=(0, 0, 0), **kw):
    d = {"shape": shape, "size": [round(float(v), 3) for v in size], "pos": [round(float(v), 3) for v in pos],
         "rot": [round(float(v), 1) for v in rot], "color": color, "mat": mat}
    d.update(kw)
    return d


def _shade(hx, k):
    h = hx.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    f = lambda v: max(0, min(255, int(v * k)))
    return "#%02x%02x%02x" % (f(r), f(g), f(b))


# ---------------------------------------------------------------- ящики

def _chests(models, buildings, tech):
    ch = buildings.get("chest")
    if not ch:
        return
    ch["params"]["slots"] = 20
    ch["desc"] = "Хранит 2 строки по 10 ячеек (20 стаков). Принимает предметы с лент. Больше места — «Укреплённый ящик», «Контейнер», «Склад»."
    if "chest" in models:
        parts = []
        for p in models["chest"]["parts"]:
            q = dict(p)
            if q.get("mat") == "wood":
                q["color"] = "#7a828c"
                q["mat"] = "metal"
            elif q.get("color") == "#8f959c":
                q["color"] = "#c9a24a"
            parts.append(q)
        models["chest_iron"] = {"name": "Укреплённый ящик", "category": "Хранение", "parts": parts}
    buildings["chest_iron"] = dict(ch, **{
        "name": "Укреплённый ящик", "model": "chest_iron" if "chest_iron" in models else "chest", "hp": 300,
        "desc": "Железный ящик: 3 строки по 10 ячеек (30 стаков). Принимает предметы с лент.",
        "cost": {"plank": 8, "iron_plate": 6}, "params": {"slots": 30}})
    if "container" in buildings:
        c = buildings["container"]
        c["params"]["slots"] = 40
        c["desc"] = "Большое хранилище: 4 строки по 10 ячеек (40 стаков)."
        if "container" in models:
            blue = {"#77341a": "#2f5f8f", "#903f1f": "#3a6fa3", "#8a3a1c": "#356896"}
            parts = []
            for p in models["container"]["parts"]:
                q = dict(p)
                q["color"] = blue.get(q.get("color"), q.get("color"))
                parts.append(q)
            models["warehouse"] = {"name": "Склад", "category": "Хранение", "parts": parts}
        buildings["warehouse"] = dict(c, **{
            "name": "Склад", "model": "warehouse" if "warehouse" in models else "container", "hp": 900,
            "desc": "Склад: 6 строк по 10 ячеек (60 стаков). Принимает предметы с лент.",
            "cost": {"steel": 20, "concrete": 15, "iron_plate": 10}, "params": {"slots": 60}})
    early = tech.get("t_mining") or tech.get("t_start")
    late = tech.get("t_steel2") or tech.get("t_logistics")
    if early:
        early.setdefault("unlocks", {}).setdefault("buildings", []).append("chest_iron")
    if late and "warehouse" in buildings:
        late.setdefault("unlocks", {}).setdefault("buildings", []).append("warehouse")


# ---------------------------------------------------------------- месторождения разной формы

def _base(col, kind="round"):
    c = _shade(col, 0.5)
    if kind == "square":
        return [P("box", (1.8, 0.06, 1.8), (0, 0.03, 0), c)]
    if kind == "hex":
        return [P("cylinder", (1.85, 0.06, 1.85), (0, 0.03, 0), c, seg=6)]
    return [P("cylinder", (1.8, 0.06, 1.8), (0, 0.03, 0), c, seg=10)]


def _ring(n, r0, r1, rnd, off=0.0):
    for i in range(n):
        a = (i + off) / n * math.tau + rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(r0, r1)
        yield a, math.cos(a) * r, math.sin(a) * r


def f_crystal(col, rnd, glow=False):
    """Друза: пучки шестигранных кристаллов, острые верхушки."""
    p = _base(col, "hex")
    hi = _shade(col, 1.4)
    for a, x, z in _ring(4, 0.62, 0.78, rnd, 0.5):
        for k in range(3):
            h = rnd.uniform(0.45, 0.95) * (1.0 if k == 0 else 0.65)
            tilt = rnd.uniform(10, 32)
            dx = rnd.uniform(-0.14, 0.14)
            dz = rnd.uniform(-0.14, 0.14)
            p.append(P("cylinder", (0.16, h, 0.16), (x + dx, h * 0.45, z + dz), col if k else hi, "glass",
                       rot=(tilt * math.sin(a + k), 0, tilt * math.cos(a + k)), seg=6, top=0.2))
    if glow:
        for a, x, z in _ring(3, 0.5, 0.6, rnd):
            p.append(P("sphere", (0.12, 0.12, 0.12), (x, 0.12, z), _shade(col, 1.7), "glow", anim="pulse", tint=False))
    return p


def f_cubes(col, rnd, small=False):
    """Кубы и блоки (железо, никель, соль): квадратная плита, по углам — стопки угловатых кусков."""
    p = _base(col, "square")
    for cx, cz in ((-0.62, -0.62), (0.62, -0.62), (-0.62, 0.62), (0.62, 0.62)):
        n = 4 if small else 2
        for k in range(n):
            s = rnd.uniform(0.12, 0.2) if small else rnd.uniform(0.28, 0.42) * (1.0 if k == 0 else 0.7)
            y = s * 0.5 + (0 if small or k == 0 else 0.3)
            p.append(P("box", (s, s, s), (cx + rnd.uniform(-0.15, 0.15), y, cz + rnd.uniform(-0.15, 0.15)),
                       col if k % 2 == 0 else _shade(col, 1.3), "metal" if not small else "glass",
                       rot=(0, rnd.uniform(0, 90), 0 if not small else rnd.uniform(-10, 10)), bevel=0.02))
    return p


def f_nuggets(col, rnd, patina=None):
    """Самородки: приплюснутые шары кучками (медь — с зелёной патиной, золото — на белой жиле)."""
    p = _base(col, "round")
    for a, x, z in _ring(6, 0.6, 0.8, rnd):
        s = rnd.uniform(0.22, 0.36)
        p.append(P("sphere", (s, s * 0.7, s), (x, s * 0.3, z), col if rnd.random() > 0.3 else _shade(col, 1.25), "metal"))
        if patina and rnd.random() > 0.4:
            p.append(P("sphere", (s * 0.5, s * 0.35, s * 0.5), (x + 0.08, s * 0.5, z), patina, "stone"))
    return p


def f_slabs(col, rnd, glossy=False):
    """Пласты: плоские плиты стопками, как слоёный камень (уголь, известняк, алунит)."""
    p = _base(col, "square")
    for i, (cx, cz) in enumerate(((-0.6, 0), (0.6, 0), (0, -0.6), (0, 0.6))):
        y = 0.0
        for k in range(3):
            h = rnd.uniform(0.08, 0.14)
            w = 0.55 - k * 0.12
            p.append(P("box", (w if i < 2 else w * 1.4, h, w * 1.4 if i < 2 else w), (cx, y + h * 0.5, cz),
                       col if k % 2 == 0 else _shade(col, 1.35), "glass" if glossy else "stone", rot=(0, rnd.uniform(-12, 12), 0), bevel=0.02))
            y += h
    return p


def f_boulders(col, rnd):
    """Валуны: крупные круглые камни."""
    p = _base(col, "round")
    for a, x, z in _ring(4, 0.6, 0.72, rnd, 0.25):
        s = rnd.uniform(0.45, 0.6)
        p.append(P("sphere", (s, s * 0.75, s * 0.9), (x, s * 0.3, z), col if rnd.random() > 0.5 else _shade(col, 1.2), "stone",
                   rot=(0, math.degrees(-a), 0), seg=8))
    return p


def f_mound(col, rnd, needles=False, puddle=False):
    """Насыпь: невысокие кучи (песок, глина, селитра)."""
    p = _base(col, "round")
    for a, x, z in _ring(3, 0.55, 0.7, rnd):
        s = rnd.uniform(0.6, 0.8)
        p.append(P("cone", (s, rnd.uniform(0.3, 0.45), s), (x, 0.18, z), _shade(col, 1.1), "stone", seg=10))
    if puddle:
        p.append(P("cylinder", (0.7, 0.02, 0.5), (0.0, 0.07, 0.62), "#4a3428", "glass", seg=12))
    if needles:
        for a, x, z in _ring(8, 0.5, 0.82, rnd):
            p.append(P("prism", (0.05, rnd.uniform(0.25, 0.45), 0.05), (x, 0.18, z), "#ffffff", "glass", rot=(rnd.uniform(-25, 25), 0, rnd.uniform(-25, 25))))
    return p


def f_cones(col, rnd):
    """Сера: острые жёлтые наросты и светящийся выход газа."""
    p = _base(col, "round")
    for a, x, z in _ring(5, 0.6, 0.8, rnd):
        h = rnd.uniform(0.35, 0.7)
        p.append(P("cone", (0.3, h, 0.3), (x, h * 0.5, z), col if rnd.random() > 0.4 else _shade(col, 1.3), "stone", seg=7))
    p.append(P("torus", (0.4, 0.06, 0.4), (0.62, 0.08, -0.55), "#fff27a", "glow", anim="pulse", tint=False))
    return p


def f_rods(col, rnd):
    """Уран: светящиеся стержни по кругу на тёмной плите с жёлто-чёрной окантовкой."""
    p = [P("cylinder", (1.85, 0.06, 1.85), (0, 0.03, 0), "#1c1f1a", seg=12), P("torus", (1.8, 0.05, 1.8), (0, 0.07, 0), "#f2c21a", "paint", seg=24)]
    for a, x, z in _ring(6, 0.62, 0.7, rnd):
        h = rnd.uniform(0.35, 0.6)
        p.append(P("capsule", (0.14, h, 0.14), (x, h * 0.5, z), col, "glow", rot=(rnd.uniform(-12, 12), 0, rnd.uniform(-12, 12)), anim="pulse", tint=False))
    return p


def f_columns(col, rnd, seg=6, flat=True, mat="metal"):
    """Столбы: шестигранные колонны разной высоты (титан, олово, вольфрам)."""
    p = _base(col, "hex" if seg == 6 else "round")
    for a, x, z in _ring(7, 0.6, 0.8, rnd):
        h = rnd.uniform(0.3, 0.85)
        p.append(P("cylinder", (0.22, h, 0.22), (x, h * 0.5, z), col if rnd.random() > 0.4 else _shade(col, 1.25), mat,
                   seg=seg, top=1.0 if flat else 0.3))
    return p


def f_shards(col, rnd, mat="glass"):
    """Осколки: острые клинья, торчат в стороны (обсидиан, вольфрам)."""
    p = _base(col, "round")
    for a, x, z in _ring(6, 0.55, 0.8, rnd):
        h = rnd.uniform(0.4, 0.8)
        p.append(P("prism", (0.18, h, 0.3), (x, h * 0.42, z), col if rnd.random() > 0.3 else _shade(col, 1.6), mat,
                   rot=(rnd.uniform(-30, 30), math.degrees(-a), rnd.uniform(-30, 30))))
    return p


def f_geode(col, rnd):
    """Редкоземельные: разломленная жеода — каменное кольцо, внутри мелкие светлые кристаллы."""
    p = _base(col, "round")
    for cx, cz in ((-0.6, -0.55), (0.62, 0.58)):
        p.append(P("torus", (0.6, 0.22, 0.6), (cx, 0.12, cz), "#5a5650", "stone", seg=10))
        for k in range(5):
            p.append(P("cylinder", (0.07, 0.2, 0.07), (cx + rnd.uniform(-0.15, 0.15), 0.12, cz + rnd.uniform(-0.15, 0.15)), col, "glow",
                       seg=6, top=0.2, rot=(rnd.uniform(-30, 30), 0, rnd.uniform(-30, 30)), tint=False))
    return p


def f_pool(col, rnd, gas=False):
    """Нефть: чёрная лужа с пузырями; газ: трещины с бледными светящимися кольцами."""
    if gas:
        p = _base("#6f7f78", "round")
        for a, x, z in _ring(3, 0.45, 0.65, rnd):
            p.append(P("cone", (0.4, 0.25, 0.4), (x, 0.12, z), "#8a958f", "stone", seg=8))
            p.append(P("torus", (0.3, 0.05, 0.3), (x, 0.32, z), col, "glow", anim="pulse", tint=False))
        return p
    p = [P("cylinder", (1.7, 0.04, 1.6), (0, 0.03, 0), "#0b0a0e", "glass", seg=14)]
    for a, x, z in _ring(5, 0.2, 0.6, rnd):
        s = rnd.uniform(0.08, 0.16)
        p.append(P("sphere", (s, s * 0.6, s), (x, 0.06, z), "#2a2433", "glass", anim="bob"))
    p.append(P("box", (0.12, 0.6, 0.12), (0.78, 0.3, 0.0), "#5a3a22", "metal"))
    p.append(P("box", (0.12, 0.6, 0.12), (-0.78, 0.3, 0.0), "#5a3a22", "metal"))
    return p


FAMILIES = {
    "quartz": lambda c, r: f_crystal(c, r), "resonite": lambda c, r: f_crystal(c, r, glow=True),
    "iron_ore": lambda c, r: f_cubes(c, r), "nickel_ore": lambda c, r: f_cubes(c, r), "salt": lambda c, r: f_cubes(c, r, small=True),
    "copper_ore": lambda c, r: f_nuggets(c, r, patina="#4fae8a"), "bauxite": lambda c, r: f_nuggets(c, r),
    "gold_ore": lambda c, r: f_nuggets(c, r, patina="#f3f0e6"),
    "coal": lambda c, r: f_slabs(c, r, glossy=True), "limestone": lambda c, r: f_slabs(c, r), "alunite": lambda c, r: f_slabs(c, r),
    "lead_ore": lambda c, r: f_slabs(c, r),
    "stone": lambda c, r: f_boulders(c, r),
    "sand": lambda c, r: f_mound(c, r), "clay": lambda c, r: f_mound(c, r, puddle=True), "saltpeter": lambda c, r: f_mound(c, r, needles=True),
    "sulfur": lambda c, r: f_cones(c, r),
    "uranium_ore": lambda c, r: f_rods(c, r),
    "titanium_ore": lambda c, r: f_columns(c, r), "tin_ore": lambda c, r: f_columns(c, r, seg=10),
    "tungsten_ore": lambda c, r: f_shards(c, r, mat="metal"), "obsidian": lambda c, r: f_shards(c, r),
    "rare_earth_ore": lambda c, r: f_geode(c, r),
    "oil": lambda c, r: f_pool(c, r), "natural_gas": lambda c, r: f_pool(c, r, gas=True),
}

SHAPE_NAMES = {
    "quartz": "друза кристаллов", "resonite": "светящиеся кристаллы", "iron_ore": "ржавые кубы", "nickel_ore": "серо-зелёные кубы",
    "salt": "белые кубики", "copper_ore": "самородки с патиной", "bauxite": "красная галька", "gold_ore": "самородки на белой жиле",
    "coal": "чёрные блестящие пласты", "limestone": "светлые пласты", "alunite": "полосатые пласты", "lead_ore": "тёмные плиты",
    "stone": "валуны", "sand": "песчаные кучки", "clay": "мокрые кучки и лужа", "saltpeter": "белые иглы", "sulfur": "жёлтые конусы",
    "uranium_ore": "светящиеся стержни", "titanium_ore": "шестигранные колонны", "tin_ore": "круглые столбики",
    "tungsten_ore": "металлические клинья", "obsidian": "чёрные осколки", "rare_earth_ore": "жеоды", "oil": "чёрная лужа",
    "natural_gas": "газовые выходы",
}


def _deposits(models, world, items):
    for d in world.get("deposits", []):
        it = d.get("item", "")
        if it not in FAMILIES:
            continue
        mid = d.get("marker") or ("dep_" + it)
        rnd = random.Random(sum(ord(ch) for ch in it) * 7919)
        name = items.get(it, {}).get("name", it)
        models[mid] = {"name": "Знак месторождения: %s (%s)" % (name, SHAPE_NAMES.get(it, "")), "category": "Месторождения",
                       "parts": FAMILIES[it](d.get("color", "#808080"), rnd)}
        d["marker"] = mid
    world["res_levels"] = [{"id": "few", "name": "Мало", "k": 0.5}, {"id": "normal", "name": "Обычно", "k": 1.0},
                           {"id": "many", "name": "Много", "k": 1.8}]


# ---------------------------------------------------------------- настройки

def _settings(settings, options):
    settings["craft_queue_max"] = 50
    settings["mode_hud"] = {
        "enabled": True, "edge": True, "edge_width": 0.11, "title_size": 26, "top": 92,
        "colors": {"wire": "#3fa4ff", "demolish": "#ff5a45", "build": "#ffc23f", "zone": "#b38cff", "route": "#3fe0c8"},
        "edge_wire": 0.55, "edge_demolish": 0.55, "edge_build": 0.3, "edge_zone": 0.45, "edge_route": 0.4,
    }
    c = settings.setdefault("coop", {})
    c["port"] = 443
    c["punch"] = True
    c["punch_poll"] = 2.0
    c["punch_wait"] = 2.5
    c["punch_time"] = 15.0
    c["stun"] = ["stun.l.google.com:19302", "stun.cloudflare.com:3478", "stun.nextcloud.com:443"]
    settings.setdefault("builders", {})["ruins_when"] = "bay"
    for sec in options.get("sections", []):
        if sec.get("id") == "game":
            if not any(i.get("key") == "show_modes" for i in sec.get("items", [])):
                sec["items"].append({"key": "show_modes", "name": "Подсветка режимов (провода, разбор, стройка): надпись и края экрана",
                                     "type": "check", "default": True})


def apply(models, buildings, tech, world, items, settings, options):
    _chests(models, buildings, tech)
    _deposits(models, world, items)
    _settings(settings, options)
