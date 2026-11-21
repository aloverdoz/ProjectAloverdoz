# 17.10: живая флора. Лёгкие модели украшений земли (кусты, поляны цветов, папоротники, высокая трава, мох, пни, грибные кольца)
# и плотная расстановка пятнами: у каждой записи «Украшений земли» может быть поле cluster — шум, который собирает цветы в поляны,
# а траву и папоротник — в заросли. Вызывается из gen_core.py после balance17.
# Всё правится в редакторе: «Модели» (категория «Украшения») и «Мир и генератор карты» → «Украшения земли».
import math
import random
import sys

gc = sys.modules["__main__"]
P, M = gc.P, gc.M
_r = random.Random(1710)


def _blades(n, h, greens, spread=0.12, lean=(8, 24), w=0.08, anim="sway_grass", y0=0.0, cx=0.0, cz=0.0):
    out = []
    for i in range(n):
        a = i * 360.0 / n + _r.uniform(-20, 20)
        rr = _r.uniform(0, spread)
        hh = h * _r.uniform(0.65, 1.15)
        ln = _r.uniform(*lean)
        out.append(P("cone", (w, hh, w * 0.4), (cx + math.cos(math.radians(a)) * rr, y0 + hh * 0.5, cz + math.sin(math.radians(a)) * rr),
                     greens[i % len(greens)], "leaf", rot=(ln * 0.5, a, ln), anim=anim, seg=3))
    return out


def _bloom(x, z, h, petal, center, size=1.0, petals=5):
    """Лёгкий цветок (~40 треугольников): стебель-конус, венчик из двух скрещённых пластинок и серединка."""
    s = size
    out = [P("cone", (0.03, h, 0.03), (x, h * 0.5, z), "#4a8a2c", "leaf", anim="sway_grass", seg=3)]
    for i in range(2):
        out.append(P("box", (0.17 * s, 0.025 * s, 0.17 * s), (x, h, z), petal, "paint", anim="sway_grass", rot=(0, i * 45 + (petals * 7) % 30, 0)))
    out.append(P("box", (0.07 * s, 0.045 * s, 0.07 * s), (x, h + 0.015, z), center, "paint", anim="sway_grass", rot=(0, 22, 0)))
    return out


def flower_patch(name, petal, center, n=6, h=0.45, size=1.0, leaves="#4f8f2e", petals=5):
    """Кустик из нескольких цветов на одном пучке листьев — из таких складываются поляны."""
    parts = _blades(5, h * 0.7, [leaves, "#5b9a34", "#467f29"], 0.1, (15, 35), 0.07)
    for i in range(n):
        a = _r.uniform(0, math.tau)
        rr = _r.uniform(0.05, 0.32)
        parts += _bloom(math.cos(a) * rr, math.sin(a) * rr, h * _r.uniform(0.75, 1.2), petal, center, size * _r.uniform(0.85, 1.15), petals)
    return M(name, parts, "Украшения")


def spike_patch(name, cols, n=5, h=0.8):
    """Колоски-свечки: люпин, иван-чай, лаванда."""
    parts = _blades(5, h * 0.45, ["#4a7d2c", "#578c31"], 0.12, (15, 35), 0.08)
    for i in range(n):
        a = _r.uniform(0, math.tau)
        rr = _r.uniform(0.04, 0.28)
        x, z = math.cos(a) * rr, math.sin(a) * rr
        hh = h * _r.uniform(0.75, 1.15)
        parts.append(P("cone", (0.03, hh, 0.03), (x, hh * 0.5, z), "#4f8a2e", "leaf", anim="sway_grass", seg=3))
        parts.append(P("sphere", (0.09, hh * 0.38, 0.09), (x, hh * 0.85, z), cols[i % len(cols)], "paint", anim="sway_grass", seg=4))
    return M(name, parts, "Украшения")


def bush(name, greens, r=0.7, h=0.75, berries=None, blossom=None):
    parts = []
    k = 0
    for (dx, dz, s) in [(0, 0, 1.0), (0.35, 0.15, 0.75), (-0.3, 0.2, 0.7), (0.05, -0.35, 0.72), (-0.2, -0.2, 0.6)]:
        parts.append(P("sphere", (r * s * 1.2, h * s, r * s * 1.1), (dx * r, h * s * 0.45, dz * r), greens[k % len(greens)], "leaf",
                       anim="sway_bush", seg=6))
        k += 1
    for col, n in ((berries, 7), (blossom, 9)):
        if not col:
            continue
        for i in range(n):
            a = _r.uniform(0, math.tau)
            y = _r.uniform(0.35, 0.9) * h
            rr = r * 0.62 * math.sqrt(max(0.15, 1.0 - (y / h - 0.45) ** 2))
            parts.append(P("sphere", (0.09, 0.09, 0.09), (math.cos(a) * rr, y, math.sin(a) * rr), col, "paint", anim="sway_bush", seg=4))
    return M(name, parts, "Украшения")


def rock(name, col, moss=None, s=1.0):
    parts = [P("sphere", (0.7 * s, 0.42 * s, 0.6 * s), (0, 0.12 * s, 0), col, "stone", rot=(0, 20, 6), seg=6),
             P("sphere", (0.38 * s, 0.26 * s, 0.34 * s), (0.42 * s, 0.06 * s, 0.2 * s), col, "stone", seg=5),
             P("sphere", (0.22 * s, 0.14 * s, 0.2 * s), (-0.4 * s, 0.03 * s, -0.25 * s), col, "stone", seg=5)]
    if moss:
        parts += [P("sphere", (0.62 * s, 0.14 * s, 0.5 * s), (-0.04 * s, 0.3 * s, 0.02 * s), moss, "leaf", seg=6),
                  P("sphere", (0.3 * s, 0.08 * s, 0.26 * s), (0.4 * s, 0.15 * s, 0.2 * s), moss, "leaf", seg=5)]
    return M(name, parts, "Украшения")


def build_models(models):
    m = models
    # поляны цветов: каждая модель — кустик из 5–8 цветков, вместе ложатся пятнами
    m["fl_poppy"] = flower_patch("Маки", "#e3262f", "#2a1c18", 6, 0.5, 1.15)
    m["fl_cornflower"] = flower_patch("Васильки", "#3d6cf0", "#25307a", 6, 0.48, 0.95, petals=6)
    m["fl_buttercup"] = flower_patch("Лютики", "#ffd21a", "#f29b11", 8, 0.36, 0.75)
    m["fl_daisy"] = flower_patch("Ромашки", "#fbf8ef", "#ffc21f", 7, 0.42, 1.0, petals=7)
    m["fl_bluebell"] = flower_patch("Колокольчики", "#8a7cf2", "#5946c9", 6, 0.4, 0.8, petals=4)
    m["fl_pink"] = flower_patch("Гвоздики", "#f06aa6", "#c2306c", 6, 0.4, 0.85)
    m["fl_orange"] = flower_patch("Купальницы", "#ff8a1c", "#d9520f", 5, 0.46, 1.05)
    m["fl_lupine"] = spike_patch("Люпин", ["#7d5cf0", "#c05cd6", "#e8e2f7"], 5, 0.95)
    m["fl_fireweed"] = spike_patch("Иван-чай", ["#e04fa5", "#d1418f"], 5, 1.15)
    m["fl_lavender"] = spike_patch("Лаванда", ["#8f74d9", "#9c82e0"], 7, 0.55)
    # одуванчики: жёлтые и пушистые шарики
    parts = _blades(6, 0.22, ["#4f8f2e", "#5b9a34"], 0.12, (50, 75), 0.1, "")
    for i, col in enumerate(["#ffd21a", "#ffd21a", "#f4f1e8", "#ffd21a", "#f4f1e8"]):
        a = i * 1.3
        x, z = math.cos(a) * 0.2, math.sin(a) * 0.2
        h = _r.uniform(0.25, 0.42)
        parts.append(P("cone", (0.02, h, 0.02), (x, h * 0.5, z), "#5b9a34", "leaf", anim="sway_grass", seg=3))
        parts.append(P("sphere", (0.1, 0.07 if col != "#f4f1e8" else 0.1, 0.1), (x, h, z), col, "paint", anim="sway_grass", seg=4))
    parts.insert(0, parts.pop(6))  # первым идёт качающийся стебель — у всей модели будет качание травы
    m["fl_dandelion"] = M("Одуванчики", parts, "Украшения")
    # травы
    m["gr_thick"] = M("Густая трава", _blades(14, 0.7, ["#3f7326", "#4c8530", "#5a9436", "#6aa13c"], 0.28, (6, 26), 0.09), "Украшения")
    m["gr_tall"] = M("Высокая трава с метёлками", _blades(12, 1.25, ["#4f7d2a", "#5c8c31", "#6c9a38"], 0.22, (6, 20), 0.08)
                     + [P("sphere", (0.05, 0.22, 0.05), (_r.uniform(-0.15, 0.15), 1.3, _r.uniform(-0.15, 0.15)), "#c9b979", "leaf", anim="sway_grass", seg=4)
                        for _ in range(4)], "Украшения")
    wheat = []
    for i in range(9):
        a = _r.uniform(0, math.tau)
        rr = _r.uniform(0, 0.25)
        x, z = math.cos(a) * rr, math.sin(a) * rr
        h = _r.uniform(0.9, 1.2)
        wheat.append(P("cone", (0.025, h, 0.025), (x, h * 0.5, z), "#c2a74f", "leaf", anim="sway_grass", seg=3))
        wheat.append(P("sphere", (0.07, 0.24, 0.07), (x, h + 0.08, z), "#e0c068", "leaf", anim="sway_grass", seg=4))
    m["gr_wheat"] = M("Дикая пшеница", wheat, "Украшения")
    m["gr_dry_thick"] = M("Сухой ковыль", _blades(12, 0.75, ["#b9a25a", "#c9b56d", "#a99250", "#d4c27e"], 0.25, (10, 32), 0.06), "Украшения")
    m["gr_shore"] = M("Осока", _blades(12, 0.95, ["#5c8a3a", "#6b9a40", "#4d7b33"], 0.2, (4, 16), 0.07), "Украшения")
    m["gr_snow"] = M("Северная трава", _blades(8, 0.45, ["#8ca482", "#9fb395", "#7d9574"], 0.2, (10, 30), 0.07), "Украшения")
    # кусты
    m["bu_round"] = bush("Куст", ["#3f7a2d", "#4b8a33", "#356b28"], 0.65, 0.8)
    m["bu_berry"] = bush("Куст с ягодами", ["#3a7330", "#467f35"], 0.6, 0.75, berries="#c8233a")
    m["bu_blossom"] = bush("Цветущий шиповник", ["#41782f", "#4e8836"], 0.65, 0.8, blossom="#f5a3c7")
    m["bu_white"] = bush("Цветущий кустарник", ["#3d7230", "#4a8236"], 0.6, 0.85, blossom="#f7f4ea")
    m["bu_dry"] = bush("Сухой кустарник", ["#8a7f45", "#9b8f52", "#7a6f3b"], 0.55, 0.6)
    m["bu_snow"] = bush("Куст под снегом", ["#5d7a5a", "#e9eff3", "#6b8668"], 0.55, 0.6)
    # папоротник большой
    fern = []
    for i in range(9):
        a = i * 40 + _r.uniform(-10, 10)
        l = _r.uniform(0.75, 1.05)
        fern.append(P("sphere", (l, 0.04, 0.2), (math.cos(math.radians(a)) * l * 0.45, 0.32, math.sin(math.radians(a)) * l * 0.45),
                      ["#2f6e2c", "#3b7f34", "#2a6427"][i % 3], "leaf", anim="sway_bush", rot=(0, -a, 32), seg=5))
    fern.append(P("sphere", (0.18, 0.1, 0.18), (0, 0.08, 0), "#3a5a24", "leaf", anim="sway_bush", seg=5))
    m["fe_big"] = M("Большой папоротник", fern, "Украшения")
    # камни, мох, пни, брёвна, грибы
    m["ro_moss"] = rock("Камень со мхом", "#8b877e", "#4f7a2e", 1.0)
    m["ro_moss_small"] = rock("Камешек со мхом", "#97938a", "#5a8534", 0.55)
    m["ro_lichen"] = rock("Камень с лишайником", "#9a968e", "#b8b07a", 0.8)
    m["ro_sand"] = rock("Песчаник", "#c2a676", None, 0.6)
    m["wo_stump"] = M("Пень", [
        P("cylinder", (0.55, 0.45, 0.55), (0, 0.22, 0), "#6b4a2c", "wood", top=0.85, seg=8),
        P("cylinder", (0.48, 0.03, 0.48), (0, 0.45, 0), "#c49a62", "wood", seg=8),
        P("sphere", (0.4, 0.1, 0.3), (0.2, 0.47, 0.05), "#4f7a2e", "leaf", seg=5),
        P("sphere", (0.12, 0.05, 0.12), (-0.3, 0.2, 0.22), "#d9a24a", "paint", seg=5),
        P("sphere", (0.1, 0.04, 0.1), (-0.32, 0.12, 0.26), "#d9a24a", "paint", seg=5),
    ], "Украшения")
    m["wo_log"] = M("Поваленное бревно со мхом", [
        P("cylinder", (0.42, 2.2, 0.42), (0, 0.2, 0), "#6e4c2e", "wood", rot=(0, 15, 90), seg=8),
        P("cylinder", (0.36, 0.02, 0.36), (math.cos(math.radians(15)) * 1.1, 0.2, -math.sin(math.radians(15)) * 1.1), "#c49a62", "wood", rot=(0, 15, 90), seg=8),
        P("sphere", (1.4, 0.14, 0.42), (0.1, 0.38, 0), "#4a7a2c", "leaf", rot=(0, 15, 0), seg=6),
        P("sphere", (0.12, 0.08, 0.12), (-0.5, 0.42, 0.18), "#c9772e", "paint", seg=5),
        P("sphere", (0.1, 0.07, 0.1), (-0.35, 0.44, 0.22), "#b5652a", "paint", seg=5),
    ], "Украшения")
    ring = []
    for i in range(8):
        a = i * math.tau / 8 + _r.uniform(-0.2, 0.2)
        x, z = math.cos(a) * 0.55, math.sin(a) * 0.55
        h = _r.uniform(0.1, 0.18)
        cap = "#e8e2d4" if i % 3 == 0 else "#c9772e" if i % 3 == 1 else "#d63a2e"
        ring.append(P("cylinder", (0.05, h, 0.05), (x, h * 0.5, z), "#efe6d2", "paint", seg=4))
        ring.append(P("sphere", (0.15, 0.08, 0.15), (x, h + 0.02, z), cap, "paint", seg=4))
    m["sh_ring"] = M("Грибное кольцо", ring, "Украшения")
    m["sh_amanita"] = M("Мухоморы", [
        P("cylinder", (0.07, 0.26, 0.07), (0, 0.13, 0), "#f2ecdf", "paint", seg=5),
        P("sphere", (0.26, 0.12, 0.26), (0, 0.27, 0), "#d42a22", "paint", seg=8),
        P("sphere", (0.04, 0.03, 0.04), (0.06, 0.33, 0.03), "#ffffff", "paint", seg=4),
        P("sphere", (0.04, 0.03, 0.04), (-0.05, 0.32, -0.05), "#ffffff", "paint", seg=4),
        P("cylinder", (0.05, 0.16, 0.05), (0.18, 0.08, 0.1), "#f2ecdf", "paint", seg=5),
        P("sphere", (0.17, 0.08, 0.17), (0.18, 0.17, 0.1), "#d42a22", "paint", seg=7),
    ], "Украшения")
    # клевер ковром
    clov = []
    for i in range(9):
        a = _r.uniform(0, math.tau)
        rr = _r.uniform(0, 0.4)
        clov.append(P("sphere", (0.2, 0.05, 0.2), (math.cos(a) * rr, 0.05 + _r.uniform(0, 0.04), math.sin(a) * rr),
                      ["#3f8a2e", "#4a9634", "#36792a"][i % 3], "leaf", seg=5))
    for i in range(3):
        a = i * 2.1
        clov.append(P("sphere", (0.09, 0.09, 0.09), (math.cos(a) * 0.22, 0.17, math.sin(a) * 0.22), "#f0c9dc" if i else "#ffffff", "paint", seg=5))
    m["cl_patch"] = M("Клеверная поляна", clov, "Украшения")
    # молодое деревце (не ресурс: просто красота)
    m["tr_sapling"] = M("Молодое деревце", [
        P("cylinder", (0.06, 1.0, 0.06), (0, 0.5, 0), "#6e4a2c", "wood", anim="sway_bush", top=0.6, seg=5),
        P("sphere", (0.55, 0.5, 0.55), (0, 1.05, 0), "#4a8a33", "leaf", anim="sway_bush", seg=7),
        P("sphere", (0.35, 0.32, 0.35), (0.18, 0.85, 0.1), "#579a3a", "leaf", anim="sway_bush", seg=6),
        P("sphere", (0.3, 0.28, 0.3), (-0.15, 0.9, -0.12), "#3f7a2d", "leaf", anim="sway_bush", seg=6),
    ], "Украшения")
    m["tr_sapling"]["parts"].insert(0, m["tr_sapling"]["parts"].pop(1))
    # пустыня
    m["ds_succulent"] = M("Суккулент", [
        P("cone", (0.12, 0.35, 0.06), (math.cos(i * 0.9) * 0.06, 0.15, math.sin(i * 0.9) * 0.06), ["#6f9a5a", "#7fa868"][i % 2], "leaf",
          rot=(0, -i * 52, 25 + (i % 3) * 10), seg=3) for i in range(7)
    ] + [P("sphere", (0.07, 0.07, 0.07), (0, 0.33, 0), "#e8604a", "paint", seg=4)], "Украшения")


# зона, модель, плотность, масштаб, кластер (размер пятна в клетках, порог — чем выше, тем реже пятна)
# клетка карты — 2×2 м, поэтому всё растёт в 1.5 раза крупнее модели: иначе с высоты камеры не видно
GROW = 1.5
# мелочь (цветы, трава, клевер) видна только рядом: дальше её всё равно не разглядеть, а видеокарте тяжело
SMALL = ("fl_", "gr_", "cl_", "deco_")
SMALL_FAR = 50.0


def _d(model, zone, dens, sc=(0.8, 1.3), cl=None, thr=0.15):
    e = {"model": model, "zone": zone, "density": dens, "scale": [round(sc[0] * GROW, 2), round(sc[1] * GROW, 2)]}
    if model.startswith(SMALL):
        e["far"] = SMALL_FAR
    if cl:
        e["cluster"] = cl
        e["cluster_thr"] = thr
    return e


DECOR = [
    # луг: трава всюду, цветы — полянами разных цветов (у каждого цвета своё пятно)
    _d("gr_thick", "meadow", 0.42, (0.8, 1.3)),
    _d("deco_grass", "meadow", 0.25, (0.8, 1.3)),
    _d("gr_tall", "meadow", 0.5, (0.8, 1.2), 14, 0.25),
    _d("gr_wheat", "meadow", 0.55, (0.85, 1.15), 18, 0.42),
    _d("fl_poppy", "meadow", 0.6, (0.9, 1.3), 10, 0.35),
    _d("fl_cornflower", "meadow", 0.5, (0.9, 1.3), 11, 0.35),
    _d("fl_buttercup", "meadow", 0.6, (0.9, 1.4), 9, 0.25),
    _d("fl_daisy", "meadow", 0.6, (0.9, 1.4), 12, 0.25),
    _d("fl_dandelion", "meadow", 0.12, (0.9, 1.3)),
    _d("fl_lupine", "meadow", 0.45, (0.9, 1.25), 13, 0.4),
    _d("fl_pink", "meadow", 0.4, (0.9, 1.3), 8, 0.4),
    _d("fl_orange", "meadow", 0.35, (0.9, 1.3), 9, 0.45),
    _d("cl_patch", "meadow", 0.4, (0.8, 1.3), 10, 0.3),
    _d("bu_round", "meadow", 0.025, (0.7, 1.2)),
    _d("bu_blossom", "meadow", 0.12, (0.7, 1.15), 16, 0.45),
    _d("ro_moss_small", "meadow", 0.012, (0.7, 1.4)),
    _d("tr_sapling", "meadow", 0.008, (0.7, 1.2)),
    # опушка
    _d("gr_thick", "forest_edge", 0.4, (0.8, 1.3)),
    _d("fl_bluebell", "forest_edge", 0.45, (0.9, 1.3), 9, 0.25),
    _d("fl_fireweed", "forest_edge", 0.5, (0.9, 1.25), 12, 0.35),
    _d("fe_big", "forest_edge", 0.08, (0.7, 1.2)),
    _d("bu_round", "forest_edge", 0.06, (0.7, 1.3)),
    _d("bu_berry", "forest_edge", 0.035, (0.7, 1.2)),
    _d("bu_white", "forest_edge", 0.15, (0.7, 1.2), 14, 0.45),
    _d("wo_stump", "forest_edge", 0.008, (0.7, 1.1)),
    _d("tr_sapling", "forest_edge", 0.03, (0.7, 1.3)),
    # лес: папоротник зарослями, мох, грибы, брёвна
    _d("fe_big", "forest", 0.5, (0.8, 1.4), 9, 0.0),
    _d("ro_moss", "forest", 0.02, (0.6, 1.3)),
    _d("ro_moss_small", "forest", 0.04, (0.6, 1.3)),
    _d("wo_log", "forest", 0.006, (0.8, 1.2)),
    _d("wo_stump", "forest", 0.012, (0.7, 1.2)),
    _d("sh_ring", "forest", 0.004, (0.8, 1.2)),
    _d("sh_amanita", "forest", 0.02, (0.8, 1.3)),
    _d("bu_berry", "forest", 0.02, (0.7, 1.1)),
    _d("fl_bluebell", "forest", 0.3, (0.8, 1.2), 7, 0.45),
    _d("gr_thick", "forest", 0.12, (0.7, 1.1)),
    # сухие земли
    _d("gr_dry_thick", "dry", 0.4, (0.8, 1.3)),
    _d("deco_grass_dry", "dry", 0.15, (0.8, 1.3)),
    _d("fl_lavender", "dry", 0.5, (0.9, 1.3), 11, 0.35),
    _d("bu_dry", "dry", 0.05, (0.7, 1.2)),
    _d("ro_lichen", "dry", 0.02, (0.6, 1.3)),
    _d("fl_buttercup", "dry", 0.25, (0.8, 1.2), 8, 0.5),
    # песок
    _d("gr_dry_thick", "sand", 0.06, (0.6, 1.0)),
    _d("ds_succulent", "sand", 0.03, (0.8, 1.4)),
    _d("ro_sand", "sand", 0.015, (0.6, 1.4)),
    _d("bu_dry", "sand", 0.01, (0.6, 1.0)),
    # берег
    _d("gr_shore", "shore", 0.4, (0.8, 1.3)),
    _d("deco_reeds", "shore", 0.12, (0.8, 1.3)),
    _d("fl_bluebell", "shore", 0.3, (0.8, 1.2), 8, 0.45),
    # снег
    _d("gr_snow", "snow", 0.12, (0.8, 1.2)),
    _d("bu_snow", "snow", 0.03, (0.7, 1.2)),
    _d("ro_lichen", "snow", 0.02, (0.6, 1.2)),
]

# ресурсы (то, что собирается) на лугу и опушке — немного гуще, чтобы земля не была пустой
FLORA_BOOST = {("tree_oak", "meadow"): 0.018, ("bush_berry", "meadow"): 0.02, ("leaf_bush", "meadow"): 0.016,
               ("flowers", "meadow"): 0.03, ("burdock", "meadow"): 0.012, ("tree_birch", "forest_edge"): 0.1,
               ("leaf_bush", "forest_edge"): 0.045, ("fallen_branch", "meadow"): 0.006}


def apply(models, world):
    build_models(models)
    # «Меньше растительности» (галочка в меню): прежний редкий набор украшений, как было до 17.10
    import copy
    world["decor_lite"] = copy.deepcopy(world.get("decor", []))
    keep = [d for d in world.get("decor", []) if d.get("model") in ("deco_shroom", "deco_pebbles")]
    world["decor"] = DECOR + keep
    for f in world.get("flora", []):
        k = (f.get("resource"), f.get("zone"))
        if k in FLORA_BOOST:
            f["density"] = FLORA_BOOST[k]
    look = world.setdefault("look", {})
    look["decor_per_cell"] = 3
    look["decor_distance"] = 85.0
    # трава: сочнее и теплее, без серого налёта
    look.update({"grass_a": "#3d7428", "grass_b": "#679a36", "blade_base": "#2d5a1f", "blade_tip": "#86b246", "clover": "#356b2a"})
