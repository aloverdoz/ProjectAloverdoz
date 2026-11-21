# Проход детализации растений, камней и руды: листья по кроне, кора и корни у стволов, сколы, трещины,
# лишайник и камешки у камней, кристаллы у руды, травинки у основания.
# Мелочь (меньше «мелкой детали» в правилах) вдали не рисуется — это и есть упрощённая дальняя версия.
import math
from art_kit import P, shade
from creature_pass import Body, _part, _rot_to

TARGET = {"tree": 250, "bush": 150, "rock": 180, "ore": 180, "small": 80, "find": 150}


def _cat(cat, model):
    c = (cat or "").lower()
    if "дерев" in c or "пустын" in c:
        return "tree"
    if "куст" in c or "водн" in c:
        return "bush"
    if "руда" in c or "самоцвет" in c:
        return "ore"
    if "камн" in c:
        return "rock"
    if "наход" in c:
        return "find"
    return "small"


def _rnd(i, k=1.0):
    return (math.sin(i * 12.9898 + k * 78.233) * 43758.5453) % 1.0


def leaves(b, n, col, seed):
    out = []
    for i in range(n):
        th = -0.9 + 1.8 * _rnd(i, seed)
        ph = 2 * math.pi * _rnd(i, seed + 1)
        pos, nn = b.surf(th, ph, -0.005)
        c = shade(col, 0.85 + 0.3 * _rnd(i, seed + 2))
        s = 0.09 + 0.07 * _rnd(i, seed + 3)
        out.append(_part("prism", (s, 0.015, s * 1.4), pos, nn, c, "leaf", b.anim, spin=360 * _rnd(i, seed + 4)))
    return out


def bark(b, col, seed):
    out = []
    L = b.a[1] * 2
    for j in range(10):
        ph = j * math.pi / 5 + 0.3 * _rnd(j, seed)
        pos, nn = b.surf(0.0, ph, 0.0)
        r = b.a[0]
        out.append(P("box", (0.035, L * (0.6 + 0.3 * _rnd(j, seed + 1)), 0.03), pos, shade(col, 0.6), "wood", rot=[0, -math.degrees(ph), 0], anim=b.anim))
    for k in range(4):
        pos, nn = b.surf(-0.6 + 1.2 * _rnd(k, seed + 5), 2 * math.pi * _rnd(k, seed + 6), 0.0)
        out.append(_part("sphere", (0.09, 0.05, 0.09), pos, nn, shade(col, 0.5), "wood", b.anim, seg=6))
    return out


def roots(x, z, r, col, seed, n=6):
    out = []
    for i in range(n):
        a = i * 2 * math.pi / n + _rnd(i, seed)
        L = r * (1.6 + 0.6 * _rnd(i, seed + 1))
        cx, cz = x + math.cos(a) * L * 0.45, z + math.sin(a) * L * 0.45
        out.append(P("cone", (r * 0.5, L, r * 0.5), (cx, 0.05, cz), shade(col, 0.8), "wood", rot=[0, -math.degrees(a), -80], seg=6))
    return out


def chips(x, z, r, col, seed, n=10):
    out = []
    for i in range(n):
        a = 2 * math.pi * _rnd(i, seed)
        d = r * (0.9 + 0.7 * _rnd(i, seed + 1))
        s = 0.05 + 0.08 * _rnd(i, seed + 2)
        out.append(P("sphere", (s, s * 0.6, s * 0.8), (x + math.cos(a) * d, s * 0.25, z + math.sin(a) * d), shade(col, 0.8 + 0.4 * _rnd(i, seed + 3)), "stone",
                     rot=[0, 360 * _rnd(i, seed + 4), 0], seg=5))
    return out


def lichen(b, n, seed):
    out = []
    for i in range(n):
        pos, nn = b.surf(-0.2 + 1.0 * _rnd(i, seed), 2 * math.pi * _rnd(i, seed + 1), 0.0)
        if nn[1] < 0.1:
            continue
        s = 0.06 + 0.08 * _rnd(i, seed + 2)
        c = ("#7d9a3a", "#b8b04a", "#5f7f3a", "#a8c060")[i % 4]
        out.append(_part("sphere", (s, 0.015, s * 0.8), pos, nn, c, "leaf", b.anim, seg=6))
    return out


def cracks(b, n, col, seed):
    out = []
    for i in range(n):
        pos, nn = b.surf(-0.5 + 1.0 * _rnd(i, seed), 2 * math.pi * _rnd(i, seed + 1), 0.0)
        out.append(_part("box", (0.012, 0.01, 0.12 + 0.12 * _rnd(i, seed + 2)), pos, nn, shade(col, 0.35), "dark", b.anim, spin=180 * _rnd(i, seed + 3)))
    return out


def crystals(b, n, col, seed):
    out = []
    for i in range(n):
        pos, nn = b.surf(-0.3 + 1.2 * _rnd(i, seed), 2 * math.pi * _rnd(i, seed + 1), 0.0)
        L = 0.08 + 0.14 * _rnd(i, seed + 2)
        tip = [pos[k] + nn[k] * L * 0.4 for k in range(3)]
        out.append(_part("cone", (L * 0.35, L, L * 0.35), tip, nn, col, "glow" if i % 3 == 0 else "metal", "pulse" if i % 3 == 0 else b.anim, seg=5, tint=False))
    return out


def blades(x, z, r, col, seed, n=12):
    out = []
    for i in range(n):
        a = 2 * math.pi * _rnd(i, seed)
        d = r * (0.7 + 0.6 * _rnd(i, seed + 1))
        h = 0.12 + 0.18 * _rnd(i, seed + 2)
        out.append(P("box", (0.015, h, 0.04), (x + math.cos(a) * d, h / 2, z + math.sin(a) * d), shade(col, 0.8 + 0.4 * _rnd(i, seed + 3)), "leaf",
                     rot=[10 * _rnd(i, seed + 4), -math.degrees(a), 12], anim="sway_grass"))
    return out


def enrich_plant(model, category, seed=1):
    parts = model.get("parts", [])
    kind = _cat(category, model)
    target = TARGET[kind]
    if len(parts) >= target or model.get("glb"):
        return len(parts)
    add = []
    bodies = [(max(p["size"]), p) for p in parts if p.get("shape") in ("sphere", "capsule", "cylinder", "cone", "box") and not p.get("role")
              and p.get("anim", "") in ("", "sway", "sway_bush", "sway_grass", "bob", "pulse") and max(p["size"]) >= 0.12]
    bodies.sort(key=lambda t: -t[0])
    lo_x = min((p["pos"][0] for p in parts), default=0)
    hi_x = max((p["pos"][0] for p in parts), default=0)
    span = max(0.4, (hi_x - lo_x) / 2 + 0.3)
    # основание: корни, камешки, трава
    leaf_col = next((p["color"] for p in parts if p.get("mat") == "leaf"), "#4f8a3a")
    wood_col = next((p["color"] for p in parts if p.get("mat") == "wood"), "#6e4a28")
    stone_col = next((p["color"] for p in parts if p.get("mat") == "stone"), "#8a8a84")
    if kind == "tree":
        trunk = next((p for p in parts if p.get("mat") == "wood" and p.get("shape") in ("cylinder", "capsule", "cone")), None)
        if trunk:
            add += roots(trunk["pos"][0], trunk["pos"][2], trunk["size"][0] / 2, wood_col, seed, 7)
        add += blades(0, 0, span * 0.8, leaf_col, seed, 10)
    elif kind in ("rock", "ore", "find"):
        add += chips(0, 0, span, stone_col, seed, 14)
    elif kind in ("bush", "small"):
        add += blades(0, 0, span * 0.7, leaf_col, seed, 14 if kind == "bush" else 10)
    for k, (sz, p) in enumerate(bodies):
        if len(parts) + len(add) >= target:
            break
        b = Body(p)
        mat = p.get("mat", "")
        area = p["size"][0] * p["size"][1] + p["size"][1] * p["size"][2] + p["size"][0] * p["size"][2]
        if mat == "leaf":
            add += leaves(b, max(8, min(90, int(area * 40))), p.get("color", leaf_col), seed + k * 7)
        elif mat == "wood" and p.get("shape") in ("cylinder", "capsule", "cone"):
            add += bark(b, p.get("color", wood_col), seed + k)
        elif mat in ("stone", "dark", "paint", "metal"):
            add += cracks(b, max(4, min(16, int(area * 8))), p.get("color", stone_col), seed + k)
            add += lichen(b, max(3, min(14, int(area * 6))), seed + k * 3)
            if kind == "ore":
                ore_col = next((q["color"] for q in parts if q.get("mat") in ("glow", "metal") and q is not p), "#d0a040")
                add += crystals(b, max(6, min(24, int(area * 10))), ore_col, seed + k)
        elif mat == "glow" and kind == "ore":
            add += crystals(b, 6, p.get("color", "#d0a040"), seed + k)
    # второй круг для крупных крон и камней, если не добрали
    for k, (sz, p) in enumerate(bodies):
        if len(parts) + len(add) >= target:
            break
        b = Body(p)
        if p.get("mat") == "leaf":
            add += leaves(b, min(60, target - len(parts) - len(add)), p.get("color", leaf_col), seed + 100 + k)
        elif p.get("mat") == "stone":
            add += lichen(b, 10, seed + 200 + k) + cracks(b, 8, p.get("color", stone_col), seed + 300 + k)
    model["parts"] = parts + add
    return len(model["parts"])
