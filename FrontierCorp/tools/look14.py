"""1.4: вид природы. Земля, трава и цвета — как в 1.3; здесь только осенняя палитра (look.autumn) для выбора
«Вид природы: лето / осень» при новой игре. Простые знаки месторождений (marker) оставлены выключенными."""
import random

LOOK = {
    # мелкая густая трава рябит в глазах — её нет (цветы и украшения земли остаются)
    "grass_off": True,
    # 2026-10-27: пользователь вернул землю и траву как в 1.3 (все пробы текстур земли, объёмной травы, кустов и луж убраны).
    # Остались новая вода и выбор «Вид природы: лето / осень» при новой игре.
    # осень: трава и земля в золотых и охристых тонах, листва рыжая (шейдер деталей, глобальный параметр autumn)
    "autumn": {"grass_a": "#7c6a24", "grass_b": "#a8842e", "grass_dry": "#c48a34", "clover": "#6e5420",
               "blade_base": "#5a4a16", "blade_tip": "#d9a640",
               "sun_color": "#ffcf94", "sky_horizon": "#efc896"},
}

# пользователь оставил прежние знаки месторождений (модели из Blender) — новые простые формы не ставим
REMAKE_MARKERS = False

ROCK = "#8e8273"
ROCK_D = "#6c6255"
ROCK_L = "#a89a87"

METALS = {"iron_ore", "copper_ore", "tin_ore", "nickel_ore", "lead_ore", "gold_ore", "tungsten_ore", "titanium_ore",
          "bauxite", "alunite"}
CRYSTALS = {"quartz", "resonite", "uranium_ore", "rare_earth_ore", "obsidian", "saltpeter"}
GLOWING = {"resonite", "uranium_ore", "rare_earth_ore"}


def P(shape, size, pos, color, mat="paint", rot=(0, 0, 0), **kw):
    d = {"shape": shape, "size": [round(v, 3) for v in size], "pos": [round(v, 3) for v in pos],
         "rot": [round(v, 1) for v in rot], "color": color, "mat": mat}
    d.update(kw)
    return d


def boulder(parts, r, x, z, s, h, col=ROCK):
    # валун: шар с малым числом граней — крупные плоские грани, как у рисованных камней
    parts.append(P("sphere", (s, h, s * r.uniform(0.8, 1.0)), (x, h * 0.38, z), col, "stone",
                   rot=(r.uniform(-12, 12), r.uniform(0, 360), r.uniform(-12, 12)), seg=6, surface="none", roughness=0.9))


def chunk(parts, r, x, y, z, s, col, metal):
    parts.append(P("box", (s, s * r.uniform(0.7, 1.0), s * r.uniform(0.7, 1.0)), (x, y, z), col, "paint",
                   rot=(r.uniform(-35, 35), r.uniform(0, 360), r.uniform(-35, 35)), bevel=0.12, surface="none",
                   metallic=0.35 if metal else 0.0, roughness=0.45 if metal else 0.7))


def crystal(parts, r, x, z, w, h, col, glow, tilt):
    rot = (r.uniform(-tilt, tilt), r.uniform(0, 360), r.uniform(-tilt, tilt))
    kw = {"emission": 1.2} if glow else {}
    mat = "glow" if glow else "paint"
    # шестигранная призма с острой верхушкой
    parts.append(P("cylinder", (w, h, w), (x, h * 0.5, z), col, mat, rot=rot, seg=6, surface="none", roughness=0.25, **kw))
    parts.append(P("cone", (w, w * 0.9, w), (x, h + w * 0.42, z), col, mat, rot=rot, seg=6, surface="none", roughness=0.25, **kw))


def mix_hex(a, b, k):
    a = a.lstrip("#"); b = b.lstrip("#")
    return "#%02x%02x%02x" % tuple(int(int(a[i:i + 2], 16) * (1 - k) + int(b[i:i + 2], 16) * k) for i in (0, 2, 4))


def lighter(c, k):
    c = c.lstrip("#")
    rgb = [int(c[i:i + 2], 16) for i in (0, 2, 4)]
    rgb = [max(0, min(255, int(v + (255 - v) * k if k > 0 else v * (1 + k)))) for v in rgb]
    return "#%02x%02x%02x" % tuple(rgb)


def marker(item, color, name):
    r = random.Random("dep14:" + item)
    parts = []
    hi = lighter(color, 0.25)
    if item in METALS:
        boulder(parts, r, -0.15, 0.05, 1.25, 0.95)
        boulder(parts, r, 0.45, -0.35, 0.75, 0.6, ROCK_D)
        boulder(parts, r, 0.35, 0.5, 0.55, 0.45, ROCK_L)
        for i in range(6):
            a = r.uniform(0, 6.28)
            rr = r.uniform(0.2, 0.55)
            import math
            chunk(parts, r, -0.15 + math.cos(a) * rr, r.uniform(0.35, 0.75), 0.05 + math.sin(a) * rr, r.uniform(0.22, 0.32),
                  hi if i % 3 == 0 else color, True)
        for i in range(3):
            chunk(parts, r, r.uniform(-0.8, 0.8), 0.08, r.uniform(-0.8, 0.8), r.uniform(0.12, 0.18), color, True)
    elif item in CRYSTALS:
        boulder(parts, r, 0.0, 0.0, 1.2, 0.5, ROCK_D if item != "saltpeter" else ROCK_L)
        boulder(parts, r, -0.55, 0.45, 0.55, 0.35)
        n = 6
        for i in range(n):
            import math
            a = i / n * 6.28 + r.uniform(-0.3, 0.3)
            rr = 0.0 if i == 0 else r.uniform(0.2, 0.42)
            h = 1.0 if i == 0 else r.uniform(0.4, 0.75)
            crystal(parts, r, math.cos(a) * rr, math.sin(a) * rr, r.uniform(0.18, 0.26) if i else 0.3, h,
                    hi if i % 2 else color, item in GLOWING, 6 if i == 0 else 28)
        for i in range(2):
            crystal(parts, r, r.uniform(-0.8, 0.8), r.uniform(-0.8, 0.8), 0.12, 0.22, color, item in GLOWING, 35)
    elif item == "coal":
        boulder(parts, r, 0.3, -0.3, 0.8, 0.55, ROCK_D)
        for i in range(9):
            chunk(parts, r, r.uniform(-0.55, 0.5), r.uniform(0.15, 0.55), r.uniform(-0.45, 0.55), r.uniform(0.26, 0.4),
                  "#2b2a2c" if i % 2 else "#3b3a3d", False)
    elif item == "salt":
        for i in range(7):
            s = r.uniform(0.25, 0.45)
            chunk(parts, r, r.uniform(-0.5, 0.5), s * 0.45, r.uniform(-0.5, 0.5), s, "#f3f0e8" if i % 2 else "#e2ddd0", False)
    elif item in ("sand", "clay", "sulfur", "limestone", "stone"):
        if item in ("sand", "clay"):
            # куча: низкая гора с гранями и пара комков
            mc = mix_hex(color, ROCK, 0.35)
            parts.append(P("sphere", (1.6, 0.6, 1.45), (0, 0.12, 0), mc, "stone", seg=10, surface="none", roughness=0.95))
            parts.append(P("sphere", (0.9, 0.5, 0.85), (0.3, 0.35, -0.2), lighter(mc, 0.12), "stone", seg=8, surface="none", roughness=0.95))
            boulder(parts, r, 0.55, 0.45, 0.35, 0.25, ROCK_D)
            boulder(parts, r, -0.7, 0.6, 0.4, 0.3)
        else:
            col = {"sulfur": color, "limestone": "#d6cdb5", "stone": ROCK}[item]
            boulder(parts, r, -0.1, 0.0, 1.2, 0.9, col)
            boulder(parts, r, 0.5, 0.45, 0.65, 0.55, lighter(col, 0.15))
            boulder(parts, r, -0.55, -0.5, 0.55, 0.4, lighter(col, -0.15))
            if item == "sulfur":
                for i in range(4):
                    chunk(parts, r, r.uniform(-0.6, 0.6), 0.1, r.uniform(-0.6, 0.6), 0.2, lighter(color, 0.35), False)
    elif item in ("oil", "natural_gas"):
        # лужа (нефть) или трещина с паром (газ) в кольце камней; модель на 1 клетку, игра растягивает её на 2×2
        if item == "oil":
            parts.append(P("cylinder", (1.3, 0.06, 1.15), (0, 0.04, 0), "#16121a", "paint", seg=9, surface="none", roughness=0.08, metallic=0.2))
            parts.append(P("cylinder", (0.7, 0.07, 0.55), (0.15, 0.045, -0.1), "#2a2232", "paint", seg=8, surface="none", roughness=0.05))
            for i in range(3):
                parts.append(P("sphere", (0.12, 0.08, 0.12), (r.uniform(-0.35, 0.35), 0.08, r.uniform(-0.3, 0.3)), "#3a3044", "paint", seg=6, surface="none", roughness=0.05))
        else:
            parts.append(P("cylinder", (0.6, 0.12, 0.6), (0, 0.05, 0), ROCK_D, "stone", seg=7, surface="none"))
            parts.append(P("cylinder", (0.35, 0.14, 0.35), (0, 0.07, 0), "#2d3330", "paint", seg=7, surface="none"))
            for i in range(3):
                parts.append(P("sphere", (0.35 - i * 0.07, 0.25, 0.35 - i * 0.07), (0.05 * i, 0.3 + i * 0.28, -0.04 * i), color,
                               "glow", seg=6, surface="none", emission=0.25, anim="pulse", speed=0.6 + i * 0.2))
        import math
        for i in range(8):
            a = i / 8 * 6.28 + r.uniform(-0.2, 0.2)
            boulder(parts, r, math.cos(a) * 0.78, math.sin(a) * 0.72, r.uniform(0.25, 0.4), r.uniform(0.18, 0.3),
                    ROCK if i % 2 else ROCK_D)
    else:
        return None
    return {"name": "Знак месторождения: %s (рисованный)" % name, "category": "Месторождения", "parts": parts}


def lush_bush(seed):
    """Объёмный куст из пухлых шапок листвы (как кроны деревьев игры), по грудь герою — сквозь него можно пройти."""
    import math
    r = random.Random(seed)
    parts = []
    cols = ["#245a15", "#2d6a19", "#377a1f", "#428724"]
    n = 9
    for i in range(n):
        a = i / n * 6.283 + r.uniform(-0.3, 0.3)
        rr = 0.0 if i == 0 else r.uniform(0.35, 0.75)
        s = r.uniform(0.7, 1.0) if i else 1.15
        y = r.uniform(0.45, 0.75) if i else 0.85
        parts.append(P("sphere", (s, s * 0.85, s), (math.cos(a) * rr, y, math.sin(a) * rr), cols[min(3, int(y * 4))], "leaf",
                       seg=8, surface="leaf", roughness=0.85, anim="sway_bush", speed=0.6))
    for i in range(6):
        a = r.uniform(0, 6.283)
        parts.append(P("sphere", (0.5, 0.42, 0.5), (math.cos(a) * 0.55, r.uniform(1.05, 1.3), math.sin(a) * 0.55), cols[3], "leaf",
                       seg=7, surface="leaf", roughness=0.85, anim="sway_bush", speed=0.6))
    return {"name": "Куст пышный", "category": "Украшения", "parts": parts}


def pebbles(seed):
    """Пара серых камешков в траве — просто украшение."""
    import math
    r = random.Random(seed)
    parts = []
    for i in range(r.randint(2, 3)):
        s = r.uniform(0.3, 0.6) if i else r.uniform(0.6, 0.85)
        parts.append(P("sphere", (s, s * 0.6, s * 0.85), (r.uniform(-0.4, 0.4), s * 0.22, r.uniform(-0.4, 0.4)),
                       r.choice(["#8a8580", "#7b7672", "#9a948c"]), "stone", rot=(0, r.uniform(0, 360), r.uniform(-10, 10)),
                       seg=7, surface="none", roughness=0.9))
    return {"name": "Камешки", "category": "Украшения", "parts": parts}


def apply(models, world, items):
    world.setdefault("look", {}).update(LOOK)
    n = 0
    if not REMAKE_MARKERS:
        return n
    for d in world.get("deposits", []):
        item = str(d.get("item", ""))
        mid = str(d.get("marker", ""))
        if not mid.startswith("dep_") or mid == "dep_magma":
            continue
        nm = items.get(item, {}).get("name", item)
        m = marker(item, d.get("color", "#808080"), nm)
        if m:
            models[mid] = m
            n += 1
    return n
