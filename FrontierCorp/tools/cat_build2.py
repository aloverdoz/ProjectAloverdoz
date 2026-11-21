# Каталог — ЗДАНИЯ, часть 2: оборона, свет, мебель и декор, фермы, фундаменты и полы, особые здания.
import math
from art_kit import *
from art_buildings import foundation_pad, chimney, CONC, BRICK, WOOD, WOOD_D
from cat_build1 import B, TIERS, BRASS, buildings, models

# ------------------------------------------------------------------ стены из разных материалов
WALL_MATS = [  # id, имя (род. ж./м./ср.), цвет, мат, hp, стоимость (за стену), вид
    ("log", ("Бревенчатая", "Бревенчатый", "Бревенчатые"), "#7a5230", "wood", 450, {"log": 3}, "logs"),
    ("plank", ("Дощатая", "Дощатый", "Дощатые"), "#a0703a", "wood", 380, {"plank": 4}, "planks"),
    ("stone", ("Каменная", "Каменный", "Каменные"), "#8a8478", "stone", 900, {"stone": 6}, "blocks"),
    ("brick", ("Кирпичная", "Кирпичный", "Кирпичные"), "#a04a32", "stone", 1100, {"brick": 6}, "bricks"),
    ("concrete", ("Бетонная", "Бетонный", "Бетонные"), "#9e9c91", "concrete", 1600, {"concrete": 4}, "slab"),
    ("reinforced", ("Армированная", "Армированный", "Армированные"), "#7e7c74", "concrete", 2600, {"concrete": 4, "steel_rod": 2}, "ribbed"),
    ("steel", ("Стальная", "Стальной", "Стальные"), "#5c6370", "metal", 3200, {"steel_plate": 4}, "plates"),
    ("titanium", ("Титановая", "Титановый", "Титановые"), "#a8b4c4", "metal", 5200, {"titanium_plate": 3}, "plates"),
    ("energy", ("Энергетическая", "Энергетический", "Энергетические"), "#40c8ff", "glow", 8000, {"power_cell": 1, "tungsten_plate": 2}, "energy"),
]


def wall_body(a, col, mat, style, h=2.2, w=1.96, z=0.0, th=0.4, low=False):
    if low:
        h = 0.9
    if style == "logs":
        n = int(h / 0.32)
        for k in range(n):
            a.append(P("cylinder", (0.34, w, 0.34), (0, 0.17 + k * 0.32, z), shade(col, 0.9 + 0.1 * (k % 2)), "wood", rot=(0, 0, 90), seg=8))
            a.append(P("cylinder", (0.28, 0.02, 0.28), (w / 2 + 0.01, 0.17 + k * 0.32, z), "#c49a6c", "wood", rot=(0, 0, 90), seg=8))
        if not low:
            for x in (-0.6, 0.0, 0.6):
                a.append(P("cone", (0.3, 0.4, 0.3), (x, h + 0.15, z), col, "wood", seg=6))
    elif style == "planks":
        for k in range(7):
            a.append(P("box", (0.26, h, 0.08), (-w / 2 + 0.14 + k * 0.28, h / 2, z), shade(col, 0.85 + 0.05 * (k % 3)), "wood"))
            a.append(P("prism", (0.26, 0.18, 0.08), (-w / 2 + 0.14 + k * 0.28, h + 0.09, z), shade(col, 0.85 + 0.05 * (k % 3)), "wood"))
        for y in (h * 0.25, h * 0.75):
            a.append(P("box", (w, 0.12, 0.06), (0, y, z - 0.07), shade(col, 0.7), "wood"))
            for k in range(5):
                a.append(P("cylinder", (0.03, 0.02, 0.03), (-0.8 + k * 0.4, y, z + 0.045), STEEL, "metal", rot=(90, 0, 0), seg=5))
    elif style in ("blocks", "bricks"):
        rows = int(h / (0.3 if style == "blocks" else 0.18))
        bw = 0.48 if style == "blocks" else 0.32
        bh = h / rows
        for r in range(rows):
            off = (bw / 2) * (r % 2)
            x = -w / 2 + off
            while x < w / 2 - 0.02:
                ww = min(bw, w / 2 - x)
                a.append(P("box", (ww - 0.03, bh - 0.03, th), (x + ww / 2, bh / 2 + r * bh, z), shade(col, 0.88 + 0.12 * ((r * 7 + int(x * 10)) % 3) / 2), mat))
                x += bw
        a.append(P("box", (w - 0.1, h - 0.05, th - 0.06), (0, h / 2, z), shade(col, 0.6), mat))
        if not low:
            a.append(P("box", (w + 0.04, 0.12, th + 0.08), (0, h + 0.06, z), shade(col, 0.8), mat))
    elif style in ("slab", "ribbed"):
        a.append(P("box", (w, h, th), (0, h / 2, z), col, mat))
        a.append(P("box", (w + 0.04, 0.14, th + 0.1), (0, h, z), shade(col, 0.85), mat))
        a.append(P("box", (w + 0.04, 0.2, th + 0.14), (0, 0.1, z), shade(col, 0.75), mat))
        for x in (-0.65, 0.0, 0.65):
            a.append(P("box", (0.03, h - 0.4, th + 0.01), (x, h / 2, z), shade(col, 0.8), mat))
        if style == "ribbed":
            for x in (-0.9, 0.9):
                a.append(P("box", (0.16, h, th + 0.16), (x, h / 2, z), shade(col, 0.9), mat))
            for y in (h * 0.3, h * 0.65):
                a.append(P("box", (w, 0.06, th + 0.03), (0, y, z), "#5c6370", "metal"))
            a.append(P("box", (w, 0.08, 0.05), (0, h * 0.85, z + th / 2 + 0.02), YEL))
    elif style == "plates":
        a.append(P("box", (w, h, th * 0.6), (0, h / 2, z), shade(col, 0.6), "dark"))
        for i in range(2):
            for j in range(max(1, int(h / 0.7))):
                for s in (-1, 1):
                    a.append(P("box", (w / 2 - 0.05, h / max(1, int(h / 0.7)) - 0.05, 0.06), (-w / 4 + i * w / 2, (j + 0.5) * h / max(1, int(h / 0.7)), z + s * th * 0.33), col, mat))
        for x in (-w / 2 + 0.06, w / 2 - 0.06):
            a.append(P("box", (0.12, h + 0.1, th + 0.06), (x, h / 2, z), shade(col, 0.8), mat))
        for k in range(6):
            a.append(P("cylinder", (0.05, 0.03, 0.05), (-0.75 + k * 0.3, h - 0.12, z + th / 2 + 0.02), CHR, "metal", rot=(90, 0, 0), seg=6))
    elif style == "energy":
        for x in (-0.9, 0.9):
            a.append(P("box", (0.2, h + 0.2, 0.3), (x, (h + 0.2) / 2, z), "#3a3f47", "metal"))
            a.append(P("box", (0.06, h, 0.32), (x, h / 2 + 0.1, z), col, "glow", anim="pulse"))
        a.append(P("box", (1.6, h - 0.1, 0.06), (0, h / 2 + 0.05, z), col, "glass", anim="flicker_soft"))
        for k in range(4):
            a.append(P("box", (1.6, 0.03, 0.08), (0, 0.4 + k * 0.45, z), col, "glow", anim="pulse"))


def build_defense():
    D = "Оборона"
    for mid, adj, col, mat, hp, cost, style in WALL_MATS:
        # стена
        a = []
        wall_body(a, col, mat, style)
        B("wall_" + mid, adj[0] + " стена", "Преграда для монстров. Прочность %d." % hp, "defense", "wall", dict(cost), a, hp, params={}, catalog=D + ": стены")
        # низкая стена
        a = []
        wall_body(a, col, mat, style, low=True)
        B("wall_" + mid + "_low", adj[0] + " низкая стена", "Полстены: герой перепрыгнет, монстры — нет.", "defense", "wall", {k: max(1, v // 2) for k, v in cost.items()}, a, hp // 2,
          params={"low": True}, catalog=D + ": стены")
        # стена с бойницей
        a = []
        wall_body(a, col, mat, style)
        a.append(P("box", (0.5, 0.25, 0.5), (0, 1.4, 0), "#141414", "dark"))
        a.append(P("box", (0.6, 0.06, 0.55), (0, 1.25, 0), shade(col, 0.6), mat))
        B("wall_" + mid + "_loop", adj[0] + " стена с бойницей", "Стена с узкой щелью для стрельбы.", "defense", "wall", dict(cost), a, int(hp * 0.9), params={}, catalog=D + ": стены")
        # угловая колонна
        a = []
        a.append(P("box" if style not in ("logs",) else "cylinder", (0.7, 2.6, 0.7), (0, 1.3, 0), col, mat, seg=10))
        a.append(P("box", (0.85, 0.15, 0.85), (0, 2.65, 0), shade(col, 0.8), mat))
        a.append(P("box", (0.85, 0.25, 0.85), (0, 0.12, 0), shade(col, 0.7), mat))
        if style == "energy":
            a.append(P("sphere", (0.4, 0.4, 0.4), (0, 2.95, 0), col, "glow", anim="pulse"))
        B("pillar_" + mid, adj[1] + " столб", "Угловая опора для стен.", "defense", "wall", dict(cost), a, int(hp * 1.2), params={}, catalog=D + ": стены")
        # ворота
        a = []
        for x in (-0.9, 0.9):
            a.append(P("box", (0.2, 2.5, 0.5), (x, 1.25, 0), shade(col, 0.85), mat))
        a.append(P("box", (2.0, 0.25, 0.5), (0, 2.5, 0), shade(col, 0.85), mat))
        wall_body(a, col, mat, style, h=2.1, w=1.6, z=0.0, th=0.16)
        a.append(P("box", (0.06, 0.3, 0.1), (0.15, 1.1, 0.12), BRASS, "metal"))
        a.append(P("box", (0.06, 0.3, 0.1), (-0.15, 1.1, 0.12), BRASS, "metal"))
        B("gate_" + mid, adj[2] + " ворота", "Герой проходит, монстры — ломают.", "defense", "wall", {k: v + 2 for k, v in cost.items()}, a, hp, params={"gate": True},
          catalog=D + ": стены")
        # шипы
        a = []
        a.append(P("box", (1.9, 0.15, 0.6), (0, 0.08, 0), shade(col, 0.6), mat))
        for k in range(7):
            for j in (-1, 1):
                a.append(P("cone", (0.12, 0.7, 0.12), (-0.8 + k * 0.27, 0.4, j * 0.15), col if style != "logs" else "#c49a6c", mat if style != "energy" else "glow",
                           rot=(j * 30, 0, 0), seg=5))
        B("spikes_" + mid, adj[2] + " шипы", "Низкая преграда с шипами: монстры застревают.", "defense", "wall", {k: max(1, v // 2) for k, v in cost.items()}, a, hp // 2,
          params={"low": True}, catalog=D + ": стены")
    # турели
    def turret_model(col, acc, kind, t):
        a = []
        foundation_pad(a)
        a.append(P("cylinder", (1.3, 0.5, 1.3), (0, 0.45, 0), shade(col, 0.6), "dark", seg=8))
        a.append(P("cylinder", (1.0, 0.3, 1.0), (0, 0.85, 0), col, seg=16, role="head"))
        a.append(P("box", (0.8, 0.6, 0.8), (0, 1.3, 0), col, role="head"))
        a.append(P("box", (0.82, 0.08, 0.82), (0, 1.62, 0), DARK, "dark", role="head"))
        if kind == "gun":
            for z in ((0,) if t < 3 else (-0.15, 0.15)):
                a.append(P("cylinder", (0.12, 1.0, 0.12), (0.8, 1.3, z), DARK, "dark", rot=(0, 0, 90), seg=8, role="head"))
                a.append(P("cylinder", (0.18, 0.15, 0.18), (1.25, 1.3, z), DARK, "dark", rot=(0, 0, 90), seg=8, role="head"))
            a.append(P("box", (0.3, 0.3, 0.2), (-0.1, 1.2, 0.5), "#3a4a2a", "metal", role="head"))
        elif kind == "laser":
            a.append(P("cylinder", (0.22, 0.9, 0.22), (0.75, 1.3, 0), CHR, "metal", rot=(0, 0, 90), seg=12, role="head"))
            for k in range(3):
                a.append(P("torus", (0.3, 0.2, 0.3), (0.5 + k * 0.18, 1.3, 0), acc, "glow", rot=(0, 0, 90), seg=12, role="head", anim="pulse"))
            a.append(P("sphere", (0.12, 0.12, 0.12), (1.22, 1.3, 0), acc, "glow", role="head", anim="pulse"))
        elif kind == "tesla":
            coil(a, 0, 1.6, 0, 0.18, 1.2, "#c87533")
            a.append(P("torus", (0.9, 0.4, 0.9), (0, 2.9, 0), CHR, "metal", seg=20))
            a.append(P("sphere", (0.4, 0.4, 0.4), (0, 2.9, 0), acc, "glow", anim="flicker"))
        elif kind == "flame":
            a.append(P("cylinder", (0.2, 0.8, 0.2), (0.7, 1.3, 0), DARK, "dark", rot=(0, 0, 90), seg=10, role="head"))
            a.append(P("cone", (0.3, 0.2, 0.3), (1.15, 1.3, 0), DARK, "dark", rot=(0, 0, -90), seg=10, role="head"))
            a.append(P("sphere", (0.12, 0.12, 0.12), (1.27, 1.3, 0), "#ff6a1a", "glow", anim="flicker", role="head"))
            for z in (-0.3, 0.3):
                a.append(P("capsule", (0.25, 0.6, 0.25), (-0.4, 1.3, z), "#c03020", "metal", rot=(0, 0, 90), role="head", seg=10))
        elif kind == "rocket":
            for y in (1.15, 1.45):
                for z in (-0.25, 0.25):
                    a.append(P("cylinder", (0.22, 0.8, 0.22), (0.4, y, z), "#3f6b2f", "metal", rot=(0, 0, 90), seg=8, role="head"))
                    a.append(P("cone", (0.16, 0.2, 0.16), (0.82, y, z), "#c03020", "paint", rot=(0, 0, -90), seg=8, role="head"))
        elif kind == "sniper":
            a.append(P("cylinder", (0.09, 1.7, 0.09), (1.0, 1.35, 0), DARK, "dark", rot=(0, 0, 90), seg=8, role="head"))
            a.append(P("cylinder", (0.16, 0.5, 0.16), (0.2, 1.75, 0), DARK, "dark", rot=(0, 0, 90), seg=10, role="head"))
            a.append(P("cylinder", (0.13, 0.02, 0.13), (0.46, 1.75, 0), acc, "glow", rot=(0, 0, 90), seg=10, role="head"))
        elif kind == "cannon":
            a.append(P("cylinder", (0.4, 1.2, 0.4), (0.7, 1.4, 0), DARK, "dark", rot=(0, 0, 70), seg=12, role="head"))
            a.append(P("torus", (0.45, 0.2, 0.45), (1.05, 1.6, 0), col, rot=(0, 0, 70), seg=12, role="head"))
        tier_pips(a, -0.42, 1.3, 0, t, acc)
        beacon(a, -0.3, 1.66, -0.3, acc)
        return a
    TUR = [  # вид, имя, урон, дальность, темп, патроны, энергия, стоимость
        ("gun", "Пулемётная турель", 12, 28, 0.2, "ammo", 0, {"iron_plate": 8, "iron_gear": 3}),
        ("laser", "Лазерная турель", 26, 34, 0.35, "", 12, {"steel_plate": 6, "laser_diode": 1, "circuit": 2}),
        ("tesla", "Тесла-башня", 30, 16, 1.0, "", 15, {"copper_wire": 10, "induction_coil": 4, "steel_plate": 2}),
        ("flame", "Огнемётная турель", 18, 12, 0.1, "", 8, {"steel_plate": 6, "steel_pipe_part": 2, "fuel": 4}),
        ("rocket", "Ракетная турель", 90, 40, 2.2, "ammo", 6, {"steel_plate": 8, "explosive": 4, "microchip": 2}),
        ("sniper", "Снайперская башня", 120, 60, 2.5, "ammo", 4, {"steel_rod": 6, "lens": 2, "microchip": 1}),
        ("cannon", "Пушка", 150, 45, 3.0, "ammo", 0, {"steel_plate": 12, "steel_pipe_part": 2, "gunpowder": 4}),
    ]
    for kind, nm, dmg, rng, rate, ammo, pw, cost in TUR:
        for t in range(1, 6):
            tn, MAIN, ACC = TIERS[t - 1]
            iid = "turret_%s" % kind if t == 1 else "turret_%s_mk%d" % (kind, t)
            k = 1.0 + (t - 1) * 0.6
            c = {kk: int(v * (1 + (t - 1) * 0.8)) for kk, v in cost.items()}
            if t >= 3:
                c["circuit_mk2"] = t - 1
            name = nm if t == 1 else "%s %s" % (nm, tn)
            if kind == "tesla":
                B(iid, name, "Бьёт молнией ближайшего монстра: урон %d. Нужна энергия." % int(dmg * k), "defense", "decor", c, turret_model(MAIN, ACC, kind, t), 500 + t * 200,
                  params={"power": int(pw * k)}, blocks=[{"type": "shoot", "damage": int(dmg * k), "range": rng + t * 2, "rate": rate, "color": "#80c0ff", "needs_power": True}],
                  catalog=D + ": турели")
            else:
                B(iid, name, "Стреляет по монстрам: урон %d, дальность %d." % (int(dmg * k), rng + t * 3) + (" Берёт патроны со склада штаба." if ammo else " Нужна энергия."),
                  "defense", "turret", c, turret_model(MAIN, ACC, kind, t), 500 + t * 250,
                  params={"range": rng + t * 3, "damage": int(dmg * k), "rate": round(rate / (1 + (t - 1) * 0.15), 3), "ammo": ammo, "power": int(pw * k)},
                  catalog=D + ": турели")
    # ловушки
    for tid, nm, col, v, dist, cd, cost in (("trap_spike", "Капкан с шипами", "#8c949e", 60, 1.5, 10, {"iron_plate": 2, "iron_spring": 1}),
                                            ("trap_fire", "Огненная ловушка", "#ff6a1a", 90, 2.5, 20, {"steel_plate": 2, "fuel": 2}),
                                            ("trap_shock", "Электроловушка", "#40c8ff", 70, 3.0, 8, {"copper_wire": 4, "battery_cell": 1}),
                                            ("trap_mine_big", "Тяжёлая мина", "#5a6a3a", 250, 4.0, 45, {"explosive": 2, "steel_plate": 1}),
                                            ("trap_acid", "Кислотная ловушка", "#b8ff3a", 80, 3.0, 15, {"acid_sac": 1, "iron_plate": 2})):
        a = [P("cylinder", (0.9, 0.12, 0.9), (0, 0.06, 0), DARK, "dark", seg=12), P("cylinder", (0.7, 0.06, 0.7), (0, 0.14, 0), col, "metal", seg=12)]
        for k in range(8):
            ang = k * math.pi / 4
            a.append(P("cone", (0.08, 0.2, 0.08), (math.cos(ang) * 0.38, 0.2, math.sin(ang) * 0.38), STEEL, "metal", seg=5))
        a.append(P("sphere", (0.12, 0.08, 0.12), (0, 0.2, 0), col, "glow", anim="blink"))
        B(tid, nm, "Срабатывает, когда монстр рядом: %d урона. Перезарядка %d с." % (v, cd), "defense", "decor", cost, a, 80, params={"low": True},
          blocks=[{"type": "trigger", "event": "enemy_near", "radius": dist, "cooldown": cd, "actions": [{"do": "explode", "x": "$x", "z": "$z", "v": str(v), "dist": str(dist)}]}],
          catalog=D + ": ловушки")
    # вышки и прожекторы
    a = []
    lattice(a, -0.7, 0.7, -0.7, 0.7, 0, 3.2, WOOD, levels=3)
    platform(a, -0.9, 0.9, -0.9, 0.9, 3.25, WOOD_D, WOOD)
    a.append(P("prism", (2.0, 0.6, 2.0), (0, 4.6, 0), "#8a2a2a", "paint"))
    for x in (-0.85, 0.85):
        for z in (-0.85, 0.85):
            a.append(P("box", (0.08, 1.2, 0.08), (x, 3.9, z), WOOD_D, "wood"))
    ladder(a, 0.72, 0, 0, 3.25, WOOD_D, WOOD, along="z")
    B("watchtower", "Сторожевая вышка", "Высокая вышка: видно далеко, сверху удобно стрелять.", "defense", "decor", {"log": 10, "plank": 10}, a, 600, params={}, catalog=D)
    a = []
    lattice(a, -0.3, 0.3, -0.3, 0.3, 0, 2.6, STEEL, levels=2, thick=0.06)
    a.append(P("cylinder", (0.6, 0.5, 0.6), (0.2, 2.9, 0), DARK, "dark", rot=(0, 0, 70), seg=16))
    a.append(P("cylinder", (0.5, 0.02, 0.5), (0.43, 2.98, 0), "#fff6d0", "glow", rot=(0, 0, 70), seg=16, anim="pulse"))
    B("searchlight", "Прожектор", "Яркий луч освещает подступы к базе.", "defense", "light", {"steel_rod": 4, "glass": 2, "copper_wire": 2}, a, 300,
      params={"light_color": "#fff6d0", "light_range": 26, "power": 4}, catalog=D)
    a = []
    for x in (-0.6, 0.6):
        for z in (-0.6, 0.6):
            a.append(P("box", (0.6, 0.35, 0.6), (x * 0.9, 0.18, z * 0.9), "#c8b070", "cloth"))
    for k in range(8):
        ang = k * math.pi / 4
        a.append(P("box", (0.6, 0.32, 0.4), (math.cos(ang) * 0.75, 0.52, math.sin(ang) * 0.75), "#b8a060", "cloth", rot=(0, -math.degrees(ang), 0)))
    B("sandbags", "Мешки с песком", "Низкое укрытие: перепрыгнуть можно.", "defense", "wall", {"fiber": 4, "stone": 4}, a, 600, params={"low": True}, catalog=D)


# ------------------------------------------------------------------ освещение
def light_model(kind, col, glow):
    a = []
    if kind == "street":
        a.append(P("cylinder", (0.3, 0.15, 0.3), (0, 0.08, 0), DARK, "dark", seg=8))
        a.append(P("cylinder", (0.1, 3.0, 0.1), (0, 1.6, 0), col, "metal", seg=8))
        a.append(P("box", (0.7, 0.06, 0.08), (0.3, 3.05, 0), col, "metal"))
        a.append(P("cone", (0.4, 0.2, 0.4), (0.6, 2.95, 0), col, "metal", seg=10))
        a.append(P("sphere", (0.2, 0.1, 0.2), (0.6, 2.85, 0), glow, "glow", anim="flicker_soft"))
    elif kind == "lantern":
        a.append(P("box", (0.3, 0.1, 0.3), (0, 0.05, 0), DARK, "dark"))
        a.append(P("cylinder", (0.08, 1.4, 0.08), (0, 0.75, 0), col, "metal", seg=6))
        a.append(P("box", (0.32, 0.4, 0.32), (0, 1.65, 0), "#ffd27a", "glass"))
        a.append(P("sphere", (0.16, 0.2, 0.16), (0, 1.65, 0), glow, "glow", anim="flicker"))
        a.append(P("prism", (0.4, 0.2, 0.4), (0, 1.95, 0), col, "metal"))
        for x in (-0.16, 0.16):
            a.append(P("box", (0.03, 0.42, 0.34), (x, 1.65, 0), col, "metal"))
    elif kind == "torch":
        a.append(P("cylinder", (0.08, 1.4, 0.08), (0, 0.7, 0), WOOD_D, "wood", seg=6))
        a.append(P("cylinder", (0.16, 0.2, 0.16), (0, 1.45, 0), "#5a3a22", "cloth", seg=8))
        a.append(P("cone", (0.2, 0.4, 0.2), (0, 1.7, 0), glow, "glow", anim="flicker", seg=8))
    elif kind == "brazier":
        a.append(P("cylinder", (0.8, 0.5, 0.8), (0, 0.9, 0), col, "metal", seg=12, top=1.4))
        for k in range(3):
            ang = k * 2 * math.pi / 3
            a.append(P("box", (0.07, 0.8, 0.07), (math.cos(ang) * 0.3, 0.4, math.sin(ang) * 0.3), col, "metal", rot=(math.sin(ang) * 15, 0, -math.cos(ang) * 15)))
        a.append(P("cone", (0.6, 0.6, 0.6), (0, 1.4, 0), glow, "glow", anim="flicker", seg=10))
        for k in range(4):
            a.append(P("cylinder", (0.1, 0.5, 0.1), (math.cos(k) * 0.15, 1.15, math.sin(k) * 0.15), "#3a2a1a", "wood", rot=(0, k * 45, 70), seg=6))
    elif kind == "floor":
        a.append(P("cylinder", (0.4, 0.06, 0.4), (0, 0.03, 0), col, "metal", seg=12))
        a.append(P("cylinder", (0.05, 1.5, 0.05), (0, 0.8, 0), col, "metal", seg=6))
        a.append(P("cylinder", (0.5, 0.4, 0.5), (0, 1.6, 0), "#f2ead6", "cloth", seg=12, top=0.6))
        a.append(P("sphere", (0.2, 0.2, 0.2), (0, 1.5, 0), glow, "glow", anim="flicker_soft"))
    elif kind == "neon":
        a.append(P("box", (0.2, 0.1, 0.2), (0, 0.05, 0), DARK, "dark"))
        a.append(P("box", (0.08, 2.0, 0.08), (0, 1.05, 0), glow, "glow", anim="pulse"))
        a.append(P("torus", (0.6, 0.15, 0.6), (0, 2.3, 0), glow, "glow", rot=(90, 0, 0), seg=20, anim="pulse"))
    elif kind == "crystal":
        hex_base(a, 0.35, 0.1, 0.2, DARK, glow)
        crystal_cluster(a, 0, 0.2, 0, glow, 1.2)
    elif kind == "flood":
        a.append(P("box", (0.6, 0.15, 0.4), (0, 0.08, 0), DARK, "dark"))
        for x in (-0.25, 0.25):
            a.append(P("box", (0.05, 0.5, 0.05), (x, 0.4, 0), col, "metal"))
        a.append(P("box", (0.7, 0.4, 0.2), (0, 0.65, 0), col, "metal", rot=(30, 0, 0)))
        a.append(P("box", (0.6, 0.3, 0.02), (0, 0.67, 0.11), glow, "glow", rot=(30, 0, 0), anim="pulse"))
    elif kind == "garland":
        for x in (-0.9, 0.9):
            a.append(P("cylinder", (0.06, 2.2, 0.06), (x, 1.1, 0), WOOD_D, "wood", seg=6))
        for k in range(9):
            x = -0.8 + k * 0.2
            y = 2.1 - math.sin(k / 8 * math.pi) * 0.35
            a.append(P("sphere", (0.09, 0.12, 0.09), (x, y, 0), ["#ff3a3a", "#ffd040", "#40ff6a", "#40c8ff"][k % 4], "glow", anim="blink"))
    return a


def build_lights():
    L = "Свет"
    for kind, nm, cost, rng in (("street", "Уличный фонарь", {"steel_rod": 2, "glass": 1, "copper_wire": 1}, 16), ("lantern", "Фонарь-столбик", {"iron_rod": 1, "glass": 1}, 10),
                                ("torch", "Факел", {"plank": 1, "fiber": 1}, 7), ("brazier", "Жаровня", {"iron_plate": 3, "log": 2}, 11),
                                ("floor", "Торшер", {"iron_rod": 1, "cloth": 1, "glass": 1}, 8), ("flood", "Напольный прожектор", {"steel_plate": 1, "led": 4}, 18),
                                ("garland", "Гирлянда", {"plank": 2, "led": 6, "copper_wire": 2}, 9)):
        for cid, cn, col, glow in (("", "", DARK, "#fff1c4"), ("_warm", " (тёплый)", "#5a3a22", "#ffb060"), ("_cold", " (холодный)", "#c0c4cc", "#c8e8ff")):
            if kind in ("torch", "brazier", "garland") and cid:
                continue
            if kind in ("torch", "brazier"):
                glow = "#ff8c1a"
            B("light_" + kind + cid, nm + cn, "Освещает базу ночью.", "decor", "light", cost, light_model(kind, col, glow), 80,
              params={"light_color": glow, "light_range": rng, **({"power": 1} if kind in ("street", "flood", "garland") else {})}, catalog=L)
    for cid, cn, glow in (("red", "красная", "#ff3a5a"), ("green", "зелёная", "#40ff6a"), ("blue", "синяя", "#40a0ff"), ("pink", "розовая", "#ff6ad8"),
                          ("yellow", "жёлтая", "#ffd040"), ("violet", "фиолетовая", "#a66aff")):
        B("neon_" + cid, "Неоновая стойка, " + cn, "Яркий цветной свет.", "decor", "light", {"glass": 2, "led": 2}, light_model("neon", DARK, glow), 80,
          params={"light_color": glow, "light_range": 9, "power": 1}, catalog=L)
        B("crystal_lamp_" + cid, "Кристальная лампа, " + cn, "Светящийся кристалл на подставке.", "decor", "light", {"crystal": 1, "iron_plate": 1}, light_model("crystal", DARK, glow), 80,
          params={"light_color": glow, "light_range": 8}, catalog=L)


# ------------------------------------------------------------------ мебель и декор
def fx_table(col, w=1.4, d=0.8, h=0.8, round_=False):
    a = [P("cylinder" if round_ else "box", (w, 0.06, d), (0, h, 0), col, "wood", seg=16)]
    if round_:
        a.append(P("cylinder", (0.12, h, 0.12), (0, h / 2, 0), shade(col, 0.8), "wood", seg=8))
        a.append(P("cylinder", (0.6, 0.05, 0.6), (0, 0.03, 0), shade(col, 0.8), "wood", seg=12))
    else:
        for x in (-w / 2 + 0.08, w / 2 - 0.08):
            for z in (-d / 2 + 0.08, d / 2 - 0.08):
                a.append(P("box", (0.07, h, 0.07), (x, h / 2, z), shade(col, 0.8), "wood"))
        a.append(P("box", (w - 0.16, 0.1, 0.03), (0, h - 0.08, d / 2 - 0.08), shade(col, 0.8), "wood"))
        a.append(P("box", (w - 0.16, 0.1, 0.03), (0, h - 0.08, -d / 2 + 0.08), shade(col, 0.8), "wood"))
    return a


def fx_chair(col, arm=False, soft=None):
    a = [P("box", (0.5, 0.06, 0.5), (0, 0.48, 0), col, "wood")]
    for x in (-0.2, 0.2):
        for z in (-0.2, 0.2):
            a.append(P("box", (0.05, 0.48, 0.05), (x, 0.24, z), shade(col, 0.8), "wood"))
    a.append(P("box", (0.5, 0.5, 0.05), (0, 0.78, -0.23), col, "wood"))
    for x in (-0.15, 0.0, 0.15):
        a.append(P("box", (0.04, 0.4, 0.06), (x, 0.75, -0.22), shade(col, 0.85), "wood"))
    if soft:
        a.append(P("box", (0.46, 0.08, 0.46), (0, 0.55, 0), soft, "cloth"))
    if arm:
        for x in (-0.25, 0.25):
            a.append(P("box", (0.05, 0.05, 0.45), (x, 0.7, 0), col, "wood"))
            a.append(P("box", (0.04, 0.22, 0.04), (x, 0.6, 0.18), col, "wood"))
    return a


def fx_bed(col, sheet, double=False):
    w = 1.6 if double else 0.9
    a = [P("box", (w, 0.35, 1.9), (0, 0.3, 0), col, "wood"), P("box", (w - 0.06, 0.18, 1.8), (0, 0.55, 0), "#f2f2ea", "cloth"),
         P("box", (w + 0.02, 0.06, 1.2), (0, 0.66, 0.3), sheet, "cloth"), P("box", (w + 0.04, 0.9, 0.08), (0, 0.6, -0.95), col, "wood"),
         P("box", (w + 0.04, 0.5, 0.08), (0, 0.4, 0.95), col, "wood")]
    for x in ((-0.35, 0.35) if double else (0,)):
        a.append(P("capsule", (0.5, 0.18, 0.25), (x, 0.7, -0.68), "#ffffff", "cloth", rot=(0, 0, 90), seg=8))
    return a


def fx_sofa(col):
    a = [P("box", (1.8, 0.4, 0.8), (0, 0.3, 0), shade(col, 0.8), "cloth"), P("box", (1.8, 0.6, 0.2), (0, 0.65, -0.32), col, "cloth")]
    for x in (-0.45, 0.45):
        a.append(P("box", (0.86, 0.14, 0.62), (x, 0.55, 0.07), col, "cloth"))
    for x in (-0.95, 0.95):
        a.append(P("box", (0.18, 0.55, 0.8), (x, 0.42, 0), col, "cloth"))
    a.append(P("box", (0.4, 0.3, 0.12), (0.55, 0.78, -0.18), "#f2d24a", "cloth", rot=(-15, 0, 10)))
    return a


def fx_shelf(col):
    a = []
    for x in (-0.6, 0.6):
        a.append(P("box", (0.06, 1.9, 0.4), (x, 0.95, 0), col, "wood"))
    for k in range(5):
        a.append(P("box", (1.2, 0.05, 0.4), (0, 0.05 + k * 0.45, 0), col, "wood"))
        if k < 4:
            for j in range(7):
                if (k * 3 + j) % 5:
                    a.append(P("box", (0.08 + 0.03 * (j % 2), 0.32 - 0.04 * (j % 3), 0.28), (-0.48 + j * 0.15, 0.25 + k * 0.45, 0),
                               ["#8a2a2a", "#2a4a8a", "#2a6a3a", "#c9a227", "#5a3a6a"][(k + j) % 5], "cloth"))
    a.append(P("box", (1.2, 1.9, 0.03), (0, 0.95, -0.19), shade(col, 0.8), "wood"))
    return a


def fx_wardrobe(col):
    a = [P("box", (1.2, 2.0, 0.6), (0, 1.0, 0), col, "wood"), P("box", (0.02, 1.8, 0.62), (0, 1.0, 0), shade(col, 0.7), "wood"),
         P("box", (1.26, 0.08, 0.66), (0, 2.04, 0), shade(col, 0.8), "wood"), P("box", (1.24, 0.1, 0.62), (0, 0.05, 0), shade(col, 0.7), "wood")]
    for x in (-0.06, 0.06):
        a.append(P("cylinder", (0.03, 0.2, 0.03), (x, 1.1, 0.31), BRASS, "metal", seg=6))
    for x in (-0.3, 0.3):
        a.append(P("box", (0.45, 0.6, 0.02), (x, 1.45, 0.305), shade(col, 0.9), "wood"))
        a.append(P("box", (0.45, 0.6, 0.02), (x, 0.65, 0.305), shade(col, 0.9), "wood"))
    return a


def fx_plant_pot(leaf, pot="#b0603a", tall=False):
    a = [P("cylinder", (0.45, 0.45, 0.45), (0, 0.22, 0), pot, "stone", seg=12, top=1.25), P("cylinder", (0.5, 0.05, 0.5), (0, 0.45, 0), shade(pot, 0.85), "stone", seg=12),
         P("cylinder", (0.44, 0.02, 0.44), (0, 0.44, 0), "#3a2a1a", "paint", seg=12)]
    if tall:
        a.append(P("cylinder", (0.06, 1.2, 0.06), (0, 1.0, 0), WOOD_D, "wood", seg=6))
        for k in range(10):
            ang = k * 2.4
            a.append(P("sphere", (0.4, 0.06, 0.15), (math.cos(ang) * 0.2, 1.1 + k * 0.08, math.sin(ang) * 0.2), shade(leaf, 0.85 + 0.03 * (k % 4)), "paint",
                       rot=(0, -math.degrees(ang), 20 + k * 3), seg=6, anim="sway_bush"))
    else:
        for k in range(7):
            ang = k * 0.9
            a.append(P("sphere", (0.35, 0.05, 0.12), (math.cos(ang) * 0.12, 0.6 + (k % 3) * 0.06, math.sin(ang) * 0.12), shade(leaf, 0.85 + 0.04 * (k % 3)), "paint",
                       rot=(0, -math.degrees(ang), 35), seg=6, anim="sway_bush"))
    return a


def fx_statue(col, kind):
    a = [P("box", (0.9, 0.5, 0.9), (0, 0.25, 0), shade(col, 0.8), "stone"), P("box", (1.0, 0.08, 1.0), (0, 0.52, 0), shade(col, 0.7), "stone")]
    if kind == "hero":
        a += [P("capsule", (0.3, 0.6, 0.22), (0, 1.2, 0), col, "stone"), P("sphere", (0.24, 0.26, 0.24), (0, 1.65, 0), col, "stone"),
              P("capsule", (0.12, 0.45, 0.12), (-0.08, 0.75, 0), col, "stone"), P("capsule", (0.12, 0.45, 0.12), (0.08, 0.75, 0), col, "stone"),
              P("capsule", (0.1, 0.45, 0.1), (0.22, 1.4, 0), col, "stone", rot=(0, 0, -150)), P("capsule", (0.1, 0.4, 0.1), (-0.2, 1.15, 0), col, "stone", rot=(0, 0, 15))]
    elif kind == "obelisk":
        a += [P("cylinder", (0.5, 2.4, 0.5), (0, 1.75, 0), col, "stone", seg=4, top=0.6), P("cone", (0.32, 0.3, 0.32), (0, 3.1, 0), BRASS, "metal", seg=4)]
    elif kind == "sphere":
        a += [P("cylinder", (0.4, 0.5, 0.4), (0, 0.8, 0), col, "stone", seg=10), P("sphere", (0.8, 0.8, 0.8), (0, 1.45, 0), col, "stone", seg=16)]
    elif kind == "monster":
        a += [P("sphere", (0.9, 0.6, 0.6), (0, 0.95, 0), col, "stone", seg=10), P("sphere", (0.4, 0.35, 0.4), (0.5, 1.15, 0), col, "stone", seg=8)]
        for k in range(3):
            for s in (-1, 1):
                a.append(P("cylinder", (0.06, 0.5, 0.06), (-0.25 + k * 0.25, 0.75, s * 0.35), col, "stone", rot=(s * 40, 0, 0), seg=5))
    elif kind == "gear":
        a += [P("gear", (1.2, 0.2, 1.2), (0, 1.25, 0), col, "metal", rot=(90, 0, 0), seg=14, top=0.8, anim="gear_slow"),
              P("cylinder", (0.12, 0.6, 0.12), (0, 0.85, 0), DARK, "dark", seg=8)]
    return a


def fx_fountain(col):
    a = [P("cylinder", (1.9, 0.4, 1.9), (0, 0.2, 0), col, "stone", seg=20), P("cylinder", (1.7, 0.05, 1.7), (0, 0.36, 0), "#5ab4ff", "water", seg=20),
         P("cylinder", (0.3, 1.0, 0.3), (0, 0.8, 0), col, "stone", seg=10), P("cylinder", (0.9, 0.15, 0.9), (0, 1.3, 0), col, "stone", seg=16),
         P("cylinder", (0.8, 0.04, 0.8), (0, 1.38, 0), "#5ab4ff", "water", seg=16), P("sphere", (0.2, 0.3, 0.2), (0, 1.55, 0), col, "stone", seg=10)]
    for k in range(6):
        ang = k * math.pi / 3
        a.append(P("cylinder", (0.04, 0.5, 0.04), (math.cos(ang) * 0.3, 1.2, math.sin(ang) * 0.3), "#9fe8ff", "glass", rot=(math.sin(ang) * 40, 0, -math.cos(ang) * 40), anim="pulse", seg=5))
    return a


def fx_bench(col, metal=DARK):
    a = []
    for k in range(3):
        a.append(P("box", (1.6, 0.05, 0.12), (0, 0.45, -0.15 + k * 0.15), col, "wood"))
    for k in range(2):
        a.append(P("box", (1.6, 0.1, 0.04), (0, 0.65 + k * 0.15, -0.26), col, "wood", rot=(-10, 0, 0)))
    for x in (-0.7, 0.7):
        a.append(P("box", (0.06, 0.45, 0.5), (x, 0.22, 0), metal, "metal"))
        a.append(P("box", (0.06, 0.5, 0.06), (x, 0.7, -0.27), metal, "metal", rot=(-10, 0, 0)))
    return a


def fx_simple(kind, col):
    a = []
    if kind == "trash":
        a += [P("cylinder", (0.5, 0.8, 0.5), (0, 0.4, 0), col, "metal", seg=12, top=1.1), P("cylinder", (0.58, 0.08, 0.58), (0, 0.84, 0), shade(col, 0.8), "metal", seg=12)]
        a += [P("box", (0.02, 0.6, 0.04), (math.cos(k) * 0.25, 0.4, math.sin(k) * 0.25), shade(col, 0.75), "metal", rot=(0, -math.degrees(k), 0)) for k in range(0, 6)]
    elif kind == "hydrant":
        a += [P("cylinder", (0.3, 0.7, 0.3), (0, 0.35, 0), col, "metal", seg=10), P("sphere", (0.32, 0.25, 0.32), (0, 0.72, 0), col, "metal", seg=10),
              P("cylinder", (0.12, 0.18, 0.12), (0.18, 0.45, 0), col, "metal", rot=(0, 0, 90), seg=8), P("cylinder", (0.12, 0.18, 0.12), (-0.18, 0.45, 0), col, "metal", rot=(0, 0, 90), seg=8),
              P("cylinder", (0.42, 0.06, 0.42), (0, 0.06, 0), shade(col, 0.7), "metal", seg=10)]
    elif kind == "mailbox":
        a += [P("box", (0.08, 1.0, 0.08), (0, 0.5, 0), DARK, "dark"), P("capsule", (0.35, 0.6, 0.3), (0, 1.15, 0), col, "metal", rot=(90, 0, 0), seg=10),
              P("box", (0.03, 0.2, 0.05), (0.18, 1.25, -0.1), "#e0263d", "paint")]
    elif kind == "tent":
        a += [P("prism", (1.8, 1.4, 1.8), (0, 0.7, 0), col, "cloth", rot=(0, 90, 0)), P("box", (0.5, 0.9, 0.02), (0, 0.45, 0.9), shade(col, 0.6), "cloth"),
              P("cylinder", (0.04, 1.5, 0.04), (0, 0.75, 0.92), WOOD_D, "wood", seg=5)]
        for x in (-0.95, 0.95):
            a.append(P("cylinder", (0.02, 0.6, 0.02), (x, 0.15, 0.9), "#f2f2e6", "cloth", rot=(40, 0, 0), seg=4))
    elif kind == "well":
        a += [P("cylinder", (1.3, 0.8, 1.3), (0, 0.4, 0), col, "stone", seg=14), P("cylinder", (1.0, 0.04, 1.0), (0, 0.75, 0), "#2a4a6a", "water", seg=14)]
        for x in (-0.6, 0.6):
            a.append(P("box", (0.1, 1.4, 0.1), (x, 1.2, 0), WOOD_D, "wood"))
        a += [P("prism", (1.6, 0.5, 1.2), (0, 2.1, 0), "#8a2a2a", "paint", rot=(0, 90, 0)), P("cylinder", (0.15, 1.1, 0.15), (0, 1.6, 0), WOOD, "wood", rot=(0, 0, 90), seg=8, anim="spin_slow"),
              P("cylinder", (0.25, 0.3, 0.25), (0, 1.0, 0), WOOD, "wood", seg=8)]
    elif kind == "cart":
        a += [P("box", (1.2, 0.4, 0.8), (0, 0.6, 0), col, "wood"), P("box", (1.24, 0.06, 0.84), (0, 0.8, 0), shade(col, 0.8), "wood")]
        for z in (-0.45, 0.45):
            a.append(P("cylinder", (0.6, 0.06, 0.6), (0.2, 0.3, z), WOOD_D, "wood", rot=(90, 0, 0), seg=12))
        a.append(P("box", (1.0, 0.06, 0.06), (-1.0, 0.55, 0.2), WOOD_D, "wood"))
        a.append(P("box", (1.0, 0.06, 0.06), (-1.0, 0.55, -0.2), WOOD_D, "wood"))
        for k in range(4):
            a.append(P("sphere", (0.25, 0.2, 0.25), (-0.3 + k * 0.2, 0.9, (k % 2) * 0.2 - 0.1), ["#d8322a", "#ff9a1a", "#f2c440", "#3f9a3a"][k], "paint", seg=8))
    elif kind == "anvil":
        a += [P("cylinder", (0.6, 0.5, 0.6), (0, 0.25, 0), WOOD_D, "wood", seg=10), P("box", (0.3, 0.2, 0.25), (0, 0.6, 0), col, "metal"),
              P("box", (0.6, 0.15, 0.3), (0.05, 0.77, 0), col, "metal"), P("cone", (0.15, 0.3, 0.15), (0.45, 0.77, 0), col, "metal", rot=(0, 0, -90), seg=6),
              P("box", (0.08, 0.3, 0.06), (-0.2, 0.95, 0.1), WOOD, "wood", rot=(0, 0, 30)), P("box", (0.15, 0.08, 0.08), (-0.25, 1.08, 0.1), DARK, "metal")]
    elif kind == "barrels":
        for x, z, y in ((-0.35, -0.3, 0), (0.35, -0.3, 0), (0, 0.3, 0), (0, -0.05, 0.85)):
            barrel(a, x, z, col, y)
    elif kind == "crates":
        for x, z, y, s in ((-0.4, -0.3, 0, 0.7), (0.4, -0.3, 0, 0.7), (0, 0.35, 0, 0.6), (-0.2, -0.2, 0.7, 0.55)):
            a.append(P("box", (s, s, s), (x, y + s / 2, z), col, "wood", rot=(0, 10 * x * 10 % 20, 0)))
            a.append(P("box", (s + 0.02, 0.06, s + 0.02), (x, y + s * 0.85, z), shade(col, 0.7), "wood"))
            a.append(P("box", (s + 0.02, 0.06, s + 0.02), (x, y + s * 0.15, z), shade(col, 0.7), "wood"))
    elif kind == "pallet":
        for k in range(5):
            a.append(P("box", (1.2, 0.04, 0.14), (0, 0.16, -0.4 + k * 0.2), col, "wood"))
        for z in (-0.4, 0, 0.4):
            a.append(P("box", (1.2, 0.12, 0.1), (0, 0.06, z), shade(col, 0.8), "wood"))
        for k in range(3):
            a.append(P("box", (1.0, 0.3, 0.8), (0, 0.33 + k * 0.31, 0), "#c49a6c" if k % 2 else "#a8784a", "cloth"))
    elif kind == "rug":
        a += [P("box", (1.9, 0.02, 1.4), (0, 0.01, 0), col, "cloth"), P("box", (1.6, 0.025, 1.1), (0, 0.012, 0), shade(col, 1.3), "cloth"),
              P("box", (1.2, 0.03, 0.7), (0, 0.014, 0), shade(col, 0.7), "cloth"), P("cylinder", (0.4, 0.035, 0.4), (0, 0.015, 0), "#f2d24a", "cloth", seg=12)]
    elif kind == "piano":
        a += [P("box", (1.5, 1.2, 0.6), (0, 0.7, -0.1), col, "wood"), P("box", (1.4, 0.08, 0.3), (0, 0.8, 0.3), col, "wood"),
              P("box", (1.3, 0.03, 0.25), (0, 0.85, 0.3), "#f8f8f2", "paint")]
        a += [P("box", (0.04, 0.035, 0.14), (-0.6 + k * 0.09, 0.875, 0.26), "#101010", "dark") for k in range(14) if k % 7 not in (2, 6)]
        a += [P("box", (0.06, 0.6, 0.06), (x, 0.4, 0.38), col, "wood") for x in (-0.65, 0.65)]
    elif kind == "clock":
        a += [P("box", (0.5, 2.0, 0.35), (0, 1.0, 0), col, "wood"), P("cylinder", (0.4, 0.04, 0.4), (0, 1.65, 0.18), "#f8f2e0", "paint", rot=(90, 0, 0), seg=16),
              P("box", (0.02, 0.15, 0.01), (0, 1.7, 0.21), "#101010", "dark"), P("box", (0.02, 0.11, 0.01), (0.04, 1.63, 0.21), "#101010", "dark", rot=(0, 0, -70)),
              P("box", (0.3, 0.6, 0.02), (0, 0.9, 0.18), "#ffd27a", "glass"), P("cylinder", (0.12, 0.02, 0.12), (0, 0.75, 0.17), BRASS, "metal", rot=(90, 0, 0), seg=10, anim="swing")]
    elif kind == "computer":
        a += fx_table(col, 1.2, 0.6, 0.75)
        a += [P("box", (0.6, 0.38, 0.04), (0, 1.05, -0.15), DARK, "dark"), P("box", (0.55, 0.32, 0.01), (0, 1.05, -0.125), "#40c8ff", "glow", anim="flicker_soft"),
              P("box", (0.1, 0.2, 0.08), (0, 0.85, -0.17), DARK, "dark"), P("box", (0.45, 0.02, 0.15), (0, 0.79, 0.1), "#2a2d33", "dark"),
              P("box", (0.2, 0.45, 0.45), (0.45, 1.0, -0.05), "#2a2d33", "dark"), P("sphere", (0.03, 0.03, 0.03), (0.56, 1.1, 0.18), "#40ff6a", "glow", anim="blink")]
    elif kind == "lab":
        a += fx_table("#e6eaee", 1.6, 0.7, 0.85)
        for k in range(4):
            a.append(P("cylinder", (0.12, 0.25, 0.12), (-0.5 + k * 0.3, 1.0, -0.1), ["#40ff6a", "#40c8ff", "#ff6ad8", "#ffd040"][k], "glass", seg=8))
            a.append(P("sphere", (0.08, 0.08, 0.08), (-0.5 + k * 0.3, 0.98, -0.1), ["#40ff6a", "#40c8ff", "#ff6ad8", "#ffd040"][k], "glow", anim="bob"))
        a += [P("box", (0.35, 0.4, 0.3), (0.5, 1.07, 0.1), DARK, "dark"), P("cylinder", (0.12, 0.3, 0.12), (0.5, 1.4, 0.1), "#9fe8ff", "glass", seg=8)]
    elif kind == "stove":
        a += [P("box", (0.8, 0.9, 0.7), (0, 0.45, 0), col, "metal"), P("box", (0.5, 0.35, 0.02), (0, 0.45, 0.36), "#ff6a1a", "glow", anim="flicker"),
              P("cylinder", (0.25, 1.5, 0.25), (-0.2, 1.65, -0.2), DARK, "dark", seg=8)]
        a += [P("cylinder", (0.2, 0.03, 0.2), (x, 0.92, 0.1), DARK, "dark", seg=10) for x in (-0.2, 0.2)]
    elif kind == "flagpole":
        a += [P("cylinder", (0.4, 0.2, 0.4), (0, 0.1, 0), CONC, "concrete", seg=10), P("cylinder", (0.07, 4.0, 0.07), (0, 2.1, 0), CHR, "metal", seg=8),
              P("sphere", (0.12, 0.12, 0.12), (0, 4.12, 0), BRASS, "metal"), P("box", (1.2, 0.7, 0.02), (0.62, 3.6, 0), col, "cloth", anim="wave"),
              P("box", (0.3, 0.7, 0.025), (0.25, 3.6, 0), shade(col, 0.6), "cloth", anim="wave")]
    elif kind == "banner":
        a += [P("cylinder", (0.06, 2.6, 0.06), (0, 1.3, 0), WOOD_D, "wood", seg=6), P("cylinder", (0.04, 0.9, 0.04), (0, 2.5, 0), WOOD_D, "wood", rot=(0, 0, 90), seg=6),
              P("box", (0.8, 1.4, 0.02), (0, 1.75, 0.02), col, "cloth", anim="sway"), P("prism", (0.8, 0.3, 0.02), (0, 0.9, 0.02), col, "cloth", rot=(0, 0, 180), anim="sway"),
              P("cylinder", (0.25, 0.03, 0.25), (0, 1.9, 0.04), "#f2d24a", "paint", rot=(90, 0, 0), seg=10, anim="sway")]
    elif kind == "scarecrow":
        a += [P("cylinder", (0.07, 2.0, 0.07), (0, 1.0, 0), WOOD_D, "wood", seg=6), P("cylinder", (0.06, 1.3, 0.06), (0, 1.5, 0), WOOD_D, "wood", rot=(0, 0, 90), seg=6),
              P("box", (0.5, 0.6, 0.25), (0, 1.35, 0), col, "cloth"), P("sphere", (0.35, 0.35, 0.35), (0, 1.9, 0), "#d9c9a0", "cloth", seg=8),
              P("cone", (0.6, 0.25, 0.6), (0, 2.12, 0), "#c8a060", "cloth", seg=10)]
    elif kind == "rover":
        a += [P("box", (1.6, 0.5, 1.0), (0, 0.65, 0), col, "metal"), P("box", (0.7, 0.45, 0.9), (-0.3, 1.1, 0), shade(col, 0.9), "metal"),
              P("box", (0.02, 0.3, 0.8), (0.06, 1.12, 0), "#7fc8ff", "glass"), P("box", (1.62, 0.06, 1.02), (0, 0.4, 0), DARK, "dark")]
        for x in (-0.55, 0.55):
            for z in (-0.55, 0.55):
                a.append(P("cylinder", (0.5, 0.25, 0.5), (x, 0.28, z), RUB, "dark", rot=(90, 0, 0), seg=12))
                a.append(P("cylinder", (0.25, 0.27, 0.25), (x, 0.28, z), CHR, "metal", rot=(90, 0, 0), seg=8))
        a += [P("cylinder", (0.03, 0.8, 0.03), (0.6, 1.3, -0.4), DARK, "dark", seg=4), P("sphere", (0.06, 0.06, 0.06), (0.6, 1.72, -0.4), "#ff3b2f", "glow", anim="blink")]
    elif kind == "wreck":
        a += [P("box", (1.8, 0.6, 1.2), (0, 0.4, 0), col, "metal", rot=(0, 15, 8)), P("box", (0.8, 0.6, 1.1), (-0.4, 0.9, 0.1), shade(col, 0.7), "metal", rot=(0, 15, 14)),
              P("cylinder", (0.6, 0.25, 0.6), (0.6, 0.25, 0.6), RUB, "dark", rot=(70, 0, 20), seg=10), P("box", (0.3, 0.05, 0.6), (0.9, 0.05, -0.6), shade(col, 0.6), "metal", rot=(0, 40, 0))]
        exhaust(a, -0.6, 0.9, -0.4, 0.4, 0.06)
    elif kind == "satellite":
        a += [P("box", (0.6, 0.3, 0.6), (0, 0.15, 0), DARK, "dark"), P("cylinder", (0.12, 1.0, 0.12), (0, 0.8, 0), STEEL, "metal", seg=8),
              P("sphere", (1.6, 0.5, 1.6), (0.2, 1.5, 0), "#e6eaee", "paint", rot=(0, 0, -50), seg=16), P("cylinder", (0.04, 0.6, 0.04), (0.45, 1.8, 0), DARK, "dark", rot=(0, 0, -50), seg=5),
              P("sphere", (0.1, 0.1, 0.1), (0.7, 2.0, 0), "#ff3b2f", "glow", anim="blink")]
    elif kind == "pond":
        a += [P("cylinder", (1.9, 0.12, 1.5), (0, 0.06, 0), "#7a7468", "stone", seg=14), P("cylinder", (1.7, 0.04, 1.3), (0, 0.11, 0), "#3a7ab8", "water", seg=14)]
        for k in range(10):
            ang = k * math.pi / 5
            a.append(P("sphere", (0.3, 0.2, 0.25), (math.cos(ang) * 0.9, 0.12, math.sin(ang) * 0.72), shade("#8a8478", 0.9 + 0.05 * (k % 3)), "stone", seg=6))
        for k in range(3):
            a.append(P("cylinder", (0.3, 0.02, 0.3), (-0.3 + k * 0.3, 0.14, 0.2 - k * 0.15), "#3f8f3a", "paint", seg=8))
    return a


FURN_COLS = [("oak", "дуб", "#a0703a"), ("birch", "берёза", "#e6d0a0"), ("dark", "тёмное дерево", "#5a3a22"), ("white", "белый", "#e8e8e2"), ("black", "чёрный", "#2a2a2e"), ("cherry", "вишня", "#8a2a2a"), ("grey", "серый", "#8a8c90")]
SOFT_COLS = [("red", "красный", "#b8323a"), ("blue", "синий", "#2f5fa8"), ("green", "зелёный", "#3f8f4a"), ("grey", "серый", "#7a7f88"), ("yellow", "жёлтый", "#e0b030")]


def build_decor():
    F = "Мебель"
    for cid, cn, col in FURN_COLS:
        B("table_" + cid, "Стол (%s)" % cn, "Обеденный стол.", "decor", "decor", {"plank": 4}, fx_table(col), 120, params={}, catalog=F)
        B("table_round_" + cid, "Круглый стол (%s)" % cn, "Столик для чая.", "decor", "decor", {"plank": 3}, fx_table(col, 1.1, 1.1, 0.75, True), 100, params={}, catalog=F)
        B("chair_" + cid, "Стул (%s)" % cn, "Простой стул.", "decor", "decor", {"plank": 2}, fx_chair(col), 60, params={"low": True}, catalog=F)
        B("shelf_" + cid, "Книжный шкаф (%s)" % cn, "Полки с книгами.", "decor", "decor", {"plank": 5, "book": 1}, fx_shelf(col), 120, params={}, catalog=F)
        B("wardrobe_" + cid, "Гардероб (%s)" % cn, "Шкаф для одежды.", "decor", "decor", {"plank": 6, "iron_screw": 2}, fx_wardrobe(col), 140, params={}, catalog=F)
        B("desk_pc_" + cid, "Рабочее место (%s)" % cn, "Стол с компьютером.", "decor", "decor", {"plank": 3, "display_panel": 1, "microchip": 1}, fx_simple("computer", col), 100,
          params={}, catalog=F)
    for sid, sn, scol in SOFT_COLS:
        B("sofa_" + sid, "Диван (%s)" % sn, "Мягкий диван для отдыха.", "decor", "decor", {"plank": 3, "cloth": 4}, fx_sofa(scol), 120, params={}, catalog=F)
        B("armchair_" + sid, "Кресло (%s)" % sn, "Мягкое кресло.", "decor", "decor", {"plank": 2, "cloth": 2}, fx_chair("#5a3a22", True, scol), 80, params={"low": True}, catalog=F)
        B("bed_" + sid, "Кровать (%s)" % sn, "Односпальная кровать.", "decor", "decor", {"plank": 4, "cloth": 3}, fx_bed("#8a5a32", scol), 120, params={"low": True}, catalog=F)
        B("bed_double_" + sid, "Двуспальная кровать (%s)" % sn, "Большая кровать.", "decor", "decor", {"plank": 6, "cloth": 5}, fx_bed("#5a3a22", scol, True), 150, params={"low": True},
          catalog=F)
        B("rug_" + sid, "Ковёр (%s)" % sn, "Ковёр на пол.", "decor", "floor", {"cloth": 3}, fx_simple("rug", scol), 40, params={}, catalog=F)
        B("tent_" + sid, "Палатка (%s)" % sn, "Походная палатка.", "decor", "decor", {"canvas": 3, "plank": 2}, fx_simple("tent", scol), 100, params={}, catalog="Декор")
        B("banner_" + sid, "Знамя (%s)" % sn, "Знамя колонии.", "decor", "decor", {"cloth": 2, "plank": 1}, fx_simple("banner", scol), 60, params={"low": True}, catalog="Декор")
        B("flagpole_" + sid, "Флагшток (%s)" % sn, "Высокий флаг над базой.", "decor", "decor", {"steel_rod": 2, "cloth": 2}, fx_simple("flagpole", scol), 80, params={}, catalog="Декор")
    DEC = "Декор"
    for pid, pn, leaf, pot, tall in (("fern", "Папоротник в горшке", "#3f8f3a", "#b0603a", False), ("palm", "Пальма в кадке", "#4fa83a", "#7a5230", True),
                                     ("ficus", "Фикус", "#2f6b3a", "#e8e8e2", True), ("succulent", "Суккулент", "#7fb88a", "#5a6a7a", False),
                                     ("flower_pot_red", "Красные цветы в горшке", "#d8322a", "#b0603a", False), ("flower_pot_blue", "Синие цветы в горшке", "#4060d0", "#e8e8e2", False),
                                     ("bonsai", "Бонсай", "#3f7a3a", "#2a2a2e", True), ("alien_pot", "Светящийся цветок", "#40e0ff", "#3a3f47", False)):
        B("pot_" + pid, pn, "Растение для уюта.", "decor", "decor", {"clay": 1, "leaves": 2}, fx_plant_pot(leaf, pot, tall), 40, params={"low": not tall}, catalog=DEC)
    for sid, sn, col, kind in (("hero_stone", "Статуя колониста", "#b8b4a8", "hero"), ("hero_bronze", "Бронзовая статуя колониста", "#c08040", "hero"),
                               ("obelisk", "Обелиск", "#5a5a60", "obelisk"), ("obelisk_marble", "Мраморный обелиск", "#f2f0ea", "obelisk"),
                               ("globe", "Каменный шар", "#8a8478", "sphere"), ("monster_stone", "Статуя монстра", "#6a6a70", "monster"),
                               ("gear_monument", "Памятник шестерне", "#c9a227", "gear")):
        B("statue_" + sid, sn, "Украшение для площади.", "decor", "decor", {"stone": 10} if kind != "gear" else {"brass_gear": 4, "stone": 6}, fx_statue(col, kind), 600, params={}, catalog=DEC)
    for fid, fn_, col in (("stone", "Фонтан", "#b8b4a8"), ("marble", "Мраморный фонтан", "#f2f0ea")):
        B("fountain_" + fid, fn_, "Журчащий фонтан.", "decor", "decor", {"stone": 20, "steel_pipe_part": 2}, fx_fountain(col), 800, params={}, catalog=DEC)
    for bid, bn, col, met in (("wood", "Скамейка", "#a0703a", DARK), ("park", "Парковая скамейка", "#2f6b3a", "#1d1e21"), ("white", "Белая скамейка", "#e8e8e2", STEEL)):
        B("bench_" + bid, bn, "Посидеть и отдохнуть.", "decor", "decor", {"plank": 3, "iron_rod": 1}, fx_bench(col, met), 80, params={"low": True}, catalog=DEC)
    for kind, nm, col, cost, low in (
            ("trash", "Урна", "#3f6b3a", {"iron_plate": 1}, True), ("hydrant", "Пожарный гидрант", "#d8322a", {"iron_plate": 2}, True),
            ("mailbox", "Почтовый ящик", "#2f5fa8", {"iron_plate": 1, "iron_rod": 1}, True), ("well", "Колодец", "#8a8478", {"stone": 12, "plank": 4, "rope": 1}, False),
            ("cart", "Тележка с фруктами", "#a0703a", {"plank": 6}, True), ("anvil", "Наковальня", "#3a3f47", {"iron_ingot": 6}, True),
            ("barrels", "Бочки штабелем", "#7a5230", {"plank": 6, "iron_plate": 1}, False), ("crates", "Ящики горой", "#a0703a", {"plank": 6}, False),
            ("pallet", "Поддон с мешками", "#c49a6c", {"plank": 3, "cloth": 2}, True), ("piano", "Пианино", "#1d1e21", {"hardwood": 8, "iron_wire": 4}, False),
            ("clock", "Напольные часы", "#5a3a22", {"hardwood": 4, "brass_gear": 2, "glass": 1}, False), ("lab", "Лабораторный стол", "#e6eaee", {"steel_plate": 2, "glass": 4}, False),
            ("stove", "Печка-буржуйка", "#2a2a2e", {"iron_plate": 4}, False), ("scarecrow", "Пугало", "#5a6a8a", {"plank": 2, "fiber": 4}, False),
            ("rover", "Вездеход (декор)", "#e0b030", {"steel_plate": 10, "rubber": 4}, False), ("wreck", "Обломки машины", "#7a5a4a", {"iron_plate": 3}, False),
            ("satellite", "Спутниковая тарелка", "#e6eaee", {"aluminum_plate": 4, "antenna_part": 1}, False), ("pond", "Пруд", "#3a7ab8", {"stone": 8}, True)):
        B("decor_" + kind, nm, "Украшение для базы.", "decor", "decor", cost, fx_simple(kind, col), 120, params={"low": True} if low else {}, catalog=DEC)
    for col_id, cn, col in (("wood", "деревянная", "#8a5a32"), ("red", "красная", "#b8323a"), ("blue", "синяя", "#2f5fa8"), ("white", "белая", "#e8e8e2")):
        B("barrel_" + col_id, "Бочка (%s)" % cn, "Бочка для декора.", "decor", "decor", {"plank": 2} if col_id == "wood" else {"iron_plate": 1}, (lambda c: (lambda a: (barrel(a, 0, 0, c), a)[1])([]))(col),
          80, params={"low": True}, catalog=DEC)
    # заборы и живые изгороди
    for fid, fn_, col, kind in (("picket", "Штакетник", "#e8e8e2", "picket"), ("rail", "Жердевой забор", "#8a5a32", "rail"), ("iron", "Кованый забор", "#2a2a2e", "iron"),
                                ("chain", "Сетка-рабица", "#9aa3ad", "chain"), ("hedge", "Живая изгородь", "#3f7a3a", "hedge"), ("stone_low", "Каменная оградка", "#8a8478", "stone")):
        a = []
        if kind == "picket":
            a.append(P("box", (1.96, 0.06, 0.04), (0, 0.35, 0), col, "wood"))
            a.append(P("box", (1.96, 0.06, 0.04), (0, 0.75, 0), col, "wood"))
            for k in range(9):
                a.append(P("box", (0.12, 1.0, 0.03), (-0.88 + k * 0.22, 0.5, 0.035), col, "wood"))
                a.append(P("prism", (0.12, 0.1, 0.03), (-0.88 + k * 0.22, 1.05, 0.035), col, "wood"))
        elif kind == "rail":
            for x in (-0.9, 0.9):
                a.append(P("cylinder", (0.12, 1.1, 0.12), (x, 0.55, 0), col, "wood", seg=6))
            for y in (0.4, 0.8):
                a.append(P("cylinder", (0.08, 1.9, 0.08), (0, y, 0), shade(col, 1.1), "wood", rot=(0, 0, 90), seg=6))
        elif kind == "iron":
            a.append(P("box", (1.96, 0.05, 0.05), (0, 0.15, 0), col, "metal"))
            a.append(P("box", (1.96, 0.05, 0.05), (0, 1.1, 0), col, "metal"))
            for k in range(12):
                a.append(P("cylinder", (0.03, 1.2, 0.03), (-0.9 + k * 0.164, 0.65, 0), col, "metal", seg=5))
                a.append(P("cone", (0.06, 0.12, 0.06), (-0.9 + k * 0.164, 1.3, 0), BRASS, "metal", seg=5))
        elif kind == "chain":
            for x in (-0.95, 0.95):
                a.append(P("cylinder", (0.06, 1.6, 0.06), (x, 0.8, 0), col, "metal", seg=6))
            a.append(P("box", (1.9, 1.5, 0.01), (0, 0.78, 0), col, "glass"))
            for k in range(8):
                a.append(P("box", (0.01, 1.5, 0.015), (-0.85 + k * 0.24, 0.78, 0), col, "metal", rot=(0, 0, 30)))
                a.append(P("box", (0.01, 1.5, 0.015), (-0.85 + k * 0.24, 0.78, 0), col, "metal", rot=(0, 0, -30)))
        elif kind == "hedge":
            for k in range(5):
                a.append(P("sphere", (0.6, 1.1, 0.7), (-0.8 + k * 0.4, 0.55, 0), shade(col, 0.9 + 0.05 * (k % 3)), "paint", seg=8, anim="sway_bush"))
            a.append(P("box", (1.96, 0.9, 0.6), (0, 0.5, 0), col, "paint"))
        else:
            for k in range(6):
                a.append(P("sphere", (0.38, 0.32, 0.4), (-0.82 + k * 0.33, 0.16, 0), shade(col, 0.85 + 0.05 * (k % 3)), "stone", seg=6))
            for k in range(5):
                a.append(P("sphere", (0.34, 0.28, 0.36), (-0.66 + k * 0.33, 0.4, 0), shade(col, 0.9 + 0.05 * (k % 2)), "stone", seg=6))
        B("fence_" + fid, fn_, "Низкий забор: его можно перепрыгнуть.", "decor", "wall", {"plank": 2} if kind in ("picket", "rail") else ({"leaves": 6} if kind == "hedge" else
          ({"stone": 4} if kind == "stone" else {"iron_rod": 2})), a, 150, params={"low": True}, catalog=DEC)
    # таблички
    for sid, sn, col in (("arrow", "Указатель", "#f2d24a"), ("danger", "Знак «Опасно»", "#e0263d"), ("info", "Информационный щит", "#2f5fa8")):
        a = [P("cylinder", (0.06, 1.4, 0.06), (0, 0.7, 0), DARK, "dark", seg=6)]
        if sid == "arrow":
            a += [P("box", (0.8, 0.25, 0.04), (0.2, 1.25, 0), col, "paint"), P("prism", (0.3, 0.3, 0.04), (0.7, 1.25, 0), col, "paint", rot=(0, 0, -90))]
        elif sid == "danger":
            a += [P("prism", (0.7, 0.6, 0.04), (0, 1.4, 0), col, "paint"), P("box", (0.06, 0.25, 0.05), (0, 1.38, 0), "#101010", "dark"),
                  P("sphere", (0.06, 0.06, 0.05), (0, 1.2, 0), "#101010", "dark")]
        else:
            a += [P("box", (1.0, 0.7, 0.05), (0, 1.5, 0), col, "paint"), P("box", (0.9, 0.6, 0.01), (0, 1.5, 0.03), "#f2f2f2", "paint")]
            a += [P("box", (0.6 - k * 0.1, 0.04, 0.01), (-0.1, 1.68 - k * 0.12, 0.04), "#2a2a2e", "dark") for k in range(4)]
        B("sign_" + sid, sn, "Табличка для базы.", "decor", "decor", {"plank": 1, "iron_rod": 1}, a, 60, params={"low": True}, catalog=DEC)


# ------------------------------------------------------------------ фермы
CROPS = [("wheat", "#e6c060", "long"), ("potato", "#7fb84a", "bush"), ("carrot", "#5fa83a", "tuft"), ("tomato", "#e0322a", "bush"), ("cabbage", "#a8d070", "head"),
         ("corn", "#e6d070", "tall"), ("cucumber", "#3f9a3a", "bush"), ("pumpkin", "#f28a1a", "head"), ("watermelon", "#2f8a3a", "head"), ("melon", "#e6d070", "head"),
         ("beet", "#8a1a3a", "tuft"), ("onion", "#d8b070", "tuft"), ("lettuce", "#7fd050", "head"), ("pepper", "#e0263d", "bush"), ("eggplant", "#4a2a6a", "bush"),
         ("strawberries", "#e0263d", "bush"), ("rice", "#c8d890", "long"), ("coffee_beans", "#4a2e1a", "tall"), ("cotton", "#f8f8f2", "bush"), ("flax", "#7fa0e0", "long"),
         ("herbs", "#6fc04a", "tuft"), ("sunflower", "#f2c440", "tall")]


def crop_bed(col, kind, glass=False, tier=1):
    a = [P("box", (1.9, 0.25, 1.9), (0, 0.12, 0), "#7a5230", "wood"), P("box", (1.8, 0.06, 1.8), (0, 0.26, 0), "#4a2e1a", "paint")]
    for k in range(4):
        a.append(P("box", (1.8, 0.04, 0.18), (0, 0.3, -0.66 + k * 0.44), "#3a2416", "paint"))
    for i in range(4):
        for j in range(4):
            x, z = -0.66 + i * 0.44, -0.66 + j * 0.44
            if kind == "long":
                for k in range(3):
                    a.append(P("cylinder", (0.03, 0.7, 0.03), (x + k * 0.06 - 0.06, 0.65, z), "#a8b860", "paint", seg=4, anim="sway_grass"))
                    a.append(P("capsule", (0.06, 0.16, 0.06), (x + k * 0.06 - 0.06, 1.02, z), col, "paint", seg=5, anim="sway_grass"))
            elif kind == "bush":
                a.append(P("sphere", (0.36, 0.3, 0.36), (x, 0.45, z), "#3f8f3a", "paint", seg=7, anim="sway_bush"))
                for k in range(3):
                    a.append(P("sphere", (0.08, 0.09, 0.08), (x + math.cos(k * 2.1) * 0.13, 0.42 + k * 0.05, z + math.sin(k * 2.1) * 0.13), col, "paint", seg=6, anim="sway_bush"))
            elif kind == "tuft":
                for k in range(4):
                    a.append(P("cone", (0.06, 0.35, 0.06), (x + math.cos(k * 1.6) * 0.05, 0.47, z + math.sin(k * 1.6) * 0.05), "#5fa83a", "paint", seg=4,
                               rot=(math.sin(k) * 15, 0, math.cos(k) * 15), anim="sway_grass"))
                a.append(P("sphere", (0.12, 0.1, 0.12), (x, 0.32, z), col, "paint", seg=6))
            elif kind == "head":
                a.append(P("sphere", (0.3, 0.26, 0.3), (x, 0.42, z), col, "paint", seg=9))
                for k in range(3):
                    a.append(P("sphere", (0.22, 0.03, 0.12), (x + math.cos(k * 2.1) * 0.14, 0.33, z + math.sin(k * 2.1) * 0.14), "#3f8f3a", "paint", rot=(0, k * 120, 10), seg=6))
            elif kind == "tall":
                a.append(P("cylinder", (0.05, 1.3, 0.05), (x, 0.95, z), "#5f9a3a", "paint", seg=5, anim="sway_grass"))
                for k in range(3):
                    a.append(P("sphere", (0.26, 0.03, 0.1), (x, 0.7 + k * 0.25, z), "#4f8a2f", "paint", rot=(0, k * 120, 25), seg=6, anim="sway_grass"))
                a.append(P("sphere" if col != "#f2c440" else "cylinder", (0.16, 0.22, 0.16) if col != "#f2c440" else (0.3, 0.06, 0.3), (x, 1.62, z), col, "paint", seg=8,
                           rot=(60, 0, 0) if col == "#f2c440" else (0, 0, 0), anim="sway_grass"))
    if glass:
        for x in (-0.95, 0.95):
            for z in (-0.95, 0.95):
                a.append(P("box", (0.06, 2.2, 0.06), (x, 1.1, z), "#e6eaee", "metal"))
        a.append(P("prism", (2.0, 0.6, 2.0), (0, 2.5, 0), "#bfe8ff", "glass"))
        for x in (-0.97, 0.97):
            a.append(P("box", (0.02, 1.9, 1.9), (x, 1.15, 0), "#bfe8ff", "glass"))
        a.append(P("box", (1.9, 1.9, 0.02), (0, 1.15, -0.97), "#bfe8ff", "glass"))
        if tier >= 2:
            a.append(P("box", (1.6, 0.04, 0.1), (0, 2.1, 0), "#ff6ad8", "glow", anim="pulse"))
            a.append(P("box", (0.1, 0.04, 1.6), (0, 2.1, 0), "#ff6ad8", "glow", anim="pulse"))
    return a


def build_farm():
    FM = "Ферма"
    for crop, col, kind in CROPS:
        nm = {"wheat": "пшеница", "potato": "картофель", "carrot": "морковь", "tomato": "помидоры", "cabbage": "капуста", "corn": "кукуруза", "cucumber": "огурцы",
              "pumpkin": "тыквы", "watermelon": "арбузы", "melon": "дыни", "beet": "свёкла", "onion": "лук", "lettuce": "салат", "pepper": "перец", "eggplant": "баклажаны",
              "strawberries": "клубника", "rice": "рис", "coffee_beans": "кофе", "cotton": "хлопок", "flax": "лён", "herbs": "травы", "sunflower": "подсолнухи"}[crop]
        B("bed_" + crop, "Грядка: " + nm, "Сама растит урожай (%s). Поставьте ленту — урожай поедет на склад." % nm, "special", "decor", {"plank": 4, crop + "_seeds": 2},
          crop_bed(col, kind), 100, params={}, blocks=[{"type": "produce", "item": crop, "n": 1, "every": 30, "needs_power": False}], catalog=FM + ": грядки")
    for t in (1, 2):
        B("greenhouse_mk%d" % t, "Теплица" + (" Mk2" if t == 2 else ""), "Под стеклом растёт быстрее: помидоры%s." % (" и клубника, с фитолампами" if t == 2 else ""), "special", "decor",
          {"glass": 8, "steel_rod": 4, "tomato_seeds": 2} if t == 1 else {"tempered_glass": 8, "aluminum_rod": 4, "led": 6, "strawberries_seeds": 2}, crop_bed("#e0322a" if t == 1 else "#e0263d", "bush", True, t),
          300, params={"power": 0 if t == 1 else 5},
          blocks=[{"type": "produce", "item": "tomato" if t == 1 else "strawberries", "n": 2, "every": 20 if t == 1 else 12, "needs_power": t == 2}], catalog=FM)
    # животные и прочее
    def pen(col, animal):
        a = []
        for x in (-0.95, 0.95):
            for z in (-0.95, 0.95):
                a.append(P("box", (0.1, 0.9, 0.1), (x, 0.45, z), WOOD_D, "wood"))
        for s in (-0.95, 0.95):
            for y in (0.35, 0.75):
                a.append(P("box", (1.9, 0.06, 0.05), (0, y, s), WOOD, "wood"))
                a.append(P("box", (0.05, 0.06, 1.9), (s, y, 0), WOOD, "wood"))
        a.append(P("box", (1.8, 0.04, 1.8), (0, 0.02, 0), "#8a7a40", "paint"))
        a.append(P("box", (0.6, 0.2, 0.25), (-0.5, 0.15, -0.6), "#7a5230", "wood"))
        a.append(P("box", (0.55, 0.06, 0.2), (-0.5, 0.24, -0.6), "#e6c060", "paint"))
        for k, (x, z) in enumerate(((0.3, 0.2), (-0.2, 0.4)) if animal != "bee" else ()):
            if animal == "chicken":
                a += [P("sphere", (0.3, 0.26, 0.22), (x, 0.25, z), col, "cloth", seg=8, anim="bob"), P("sphere", (0.14, 0.15, 0.14), (x + 0.15, 0.42, z), col, "cloth", seg=8, anim="bob"),
                      P("cone", (0.05, 0.08, 0.05), (x + 0.24, 0.42, z), "#f2a81f", "paint", rot=(0, 0, -90), seg=4, anim="bob"),
                      P("box", (0.04, 0.08, 0.02), (x + 0.15, 0.52, z), "#e0263d", "paint", anim="bob")]
            else:
                big = animal == "cow"
                s = 1.0 if big else 0.75
                a += [P("capsule", (0.45 * s, 0.85 * s, 0.4 * s), (x, 0.55 * s, z), col, "cloth", rot=(0, 0, 90), seg=8, anim="breathe"),
                      P("sphere", (0.28 * s, 0.3 * s, 0.25 * s), (x + 0.5 * s, 0.7 * s, z), col, "cloth", seg=8)]
                for dx in (-0.25, 0.25):
                    for dz in (-0.12, 0.12):
                        a.append(P("cylinder", (0.08 * s, 0.35 * s, 0.08 * s), (x + dx * s, 0.18 * s, z + dz * s), shade(col, 0.7), "cloth", seg=5))
                if big:
                    a.append(P("sphere", (0.2, 0.15, 0.02), (x - 0.1, 0.62, z + 0.2), "#1d1e21", "cloth", seg=6))
        if animal == "bee":
            a = [P("box", (0.6, 0.12, 0.6), (0, 0.06, 0), WOOD_D, "wood")]
            for k in range(4):
                a.append(P("box", (0.55, 0.22, 0.55), (0, 0.24 + k * 0.23, 0), "#e6c060" if k % 2 else "#f2d890", "wood"))
            a += [P("prism", (0.7, 0.25, 0.7), (0, 1.25, 0), "#8a2a2a", "paint"), P("box", (0.15, 0.04, 0.02), (0, 0.2, 0.28), "#1d1e21", "dark")]
            for k in range(5):
                a.append(P("sphere", (0.05, 0.04, 0.04), (math.cos(k * 1.3) * 0.5, 0.6 + k * 0.1, math.sin(k * 1.3) * 0.5), "#f2c440", "glow", anim="hover"))
        return a
    for aid, nm, col, item, n, every, cost in (("chicken", "Курятник", "#f2f2ea", "egg", 2, 40, {"plank": 8, "wheat": 4}),
                                               ("cow", "Коровник", "#f2f2ea", "milk", 1, 45, {"plank": 12, "wheat": 8}),
                                               ("sheep", "Овчарня", "#e6e0d0", "wool", 1, 60, {"plank": 10, "wheat": 6}),
                                               ("bee", "Улей", "#e6c060", "honey", 1, 90, {"plank": 4, "wax": 1})):
        B("pen_" + aid, nm, "Даёт %s каждые %d с." % ({"egg": "яйца", "milk": "молоко", "wool": "шерсть", "honey": "мёд"}[item], every), "special", "decor", cost, pen(col, aid), 200,
          params={}, blocks=[{"type": "produce", "item": item, "n": n, "every": every, "needs_power": False}], catalog=FM)
    a = [P("box", (1.2, 0.8, 1.2), (0, 0.4, 0), "#5a3a22", "wood")]
    for k in range(4):
        a.append(P("box", (1.22, 0.05, 0.06), (0, 0.15 + k * 0.2, 0.6), "#3a2416", "wood"))
    a += [P("box", (1.1, 0.1, 1.1), (0, 0.82, 0), "#3a2a1a", "paint"), P("sphere", (0.4, 0.15, 0.3), (0.2, 0.9, 0.1), "#5f8a3a", "paint", seg=6)]
    B("composter", "Компостер", "Перерабатывает 3 гнилых продукта в удобрение.", "special", "decor", {"plank": 6}, a, 120, params={},
      blocks=[{"type": "convert", "in": {"rotten": 3}, "out": {"fertilizer": 1}, "time": 10, "needs_power": False}], catalog=FM)
    a = [P("cylinder", (1.0, 0.1, 1.0), (0, 0.05, 0), "#7a5230", "wood", seg=12)]
    for k in range(6):
        ang = k * math.pi / 3
        a.append(P("box", (0.05, 0.6, 0.05), (math.cos(ang) * 0.45, 0.35, math.sin(ang) * 0.45), WOOD_D, "wood"))
    a += [P("torus", (1.0, 0.06, 1.0), (0, 0.6, 0), WOOD_D, "wood", seg=12), P("cylinder", (0.8, 0.02, 0.8), (0, 0.4, 0), "#3a7ab8", "water", seg=12)]
    B("fish_trap", "Садок для рыбы", "Ставьте у воды: ловит рыбу каждые 60 с.", "special", "decor", {"plank": 4, "rope": 2}, a, 100, params={"low": True},
      blocks=[{"type": "produce", "item": "raw_fish", "n": 1, "every": 60, "needs_power": False}], catalog=FM)
    B("water_well", "Колодец с водой", "Даёт фляги воды каждые 30 с.", "special", "decor", {"stone": 12, "plank": 4, "rope": 1}, fx_simple("well", "#8a8478"), 400, params={},
      blocks=[{"type": "produce", "item": "water_flask", "n": 1, "every": 30, "needs_power": False}], catalog=FM)
    B("scarecrow", "Пугало", "Украшение для огорода.", "decor", "decor", {"plank": 2, "fiber": 4}, fx_simple("scarecrow", "#5a6a8a"), 60, params={}, catalog=FM)


# ------------------------------------------------------------------ фундаменты и полы
FOUND_MATS = [("wood", "Деревянный", "Деревянная", "#8a5a32", "wood", {"plank": 4}), ("stone", "Каменный", "Каменная", "#8a8478", "stone", {"stone": 4}),
              ("brick", "Кирпичный", "Кирпичная", "#a04a32", "stone", {"brick": 4}), ("concrete", "Бетонный", "Бетонная", "#b8b4a8", "concrete", {"concrete": 2}),
              ("steel", "Стальной", "Стальная", "#5c6370", "metal", {"steel_plate": 2}), ("glass", "Стеклянный", "Стеклянная", "#9fd8ff", "glass", {"tempered_glass": 3})]


def found_model(col, mat, kind, size=1):
    w = 1.98 * size
    a = []
    if kind == "flat":
        a.append(P("box", (w, 1.0, w), (0, 0.5, 0), shade(col, 0.8), mat))
        a.append(P("box", (w, 0.1, w), (0, 0.95, 0), col, mat))
        n = 2 * size
        for i in range(n):
            for j in range(n):
                a.append(P("box", (w / n - 0.04, 0.02, w / n - 0.04), (-w / 2 + (i + 0.5) * w / n, 1.005, -w / 2 + (j + 0.5) * w / n), shade(col, 1.0 + 0.06 * ((i + j) % 2)), mat))
        for x in (-w / 2, w / 2):
            a.append(P("box", (0.08, 1.0, w), (x, 0.5, 0), shade(col, 0.7), mat))
    elif kind == "tall":
        a.append(P("box", (w, 2.0, w), (0, 1.0, 0), shade(col, 0.8), mat))
        a.append(P("box", (w, 0.1, w), (0, 1.95, 0), col, mat))
        for y in (0.5, 1.0, 1.5):
            a.append(P("box", (w + 0.02, 0.04, w + 0.02), (0, y, 0), shade(col, 0.65), mat))
    elif kind == "ramp":
        a.append(P("wedge", (w, 1.0, w), (0, 0.5, 0), col, mat, rot=(0, 90, 0)))
        for k in range(5):
            a.append(P("box", (w, 0.04, 0.08), (0, 0.12 + k * 0.2, -0.8 + k * 0.4), shade(col, 0.7), mat, rot=(26.5, 0, 0)))
    elif kind == "wall":
        a.append(P("box", (w, 2.4, 0.3), (0, 1.2, 0), col, mat))
        window_strip(a, 0, 1.4, 0, 0.8, 0.6, "x", shade(col, 0.6))
        a.append(P("box", (w + 0.02, 0.12, 0.36), (0, 2.4, 0), shade(col, 0.8), mat))
    elif kind == "floor":
        a.append(P("box", (w, 0.06, w), (0, 0.03, 0), col, mat))
        for i in range(4):
            a.append(P("box", (w, 0.065, 0.02), (0, 0.033, -w / 2 + (i + 1) * w / 5), shade(col, 0.75), mat))
    return a


def build_structures():
    S = "Фундаменты"
    for mid, adj_m, adj_f, col, mat, cost in FOUND_MATS:
        B("found_" + mid, adj_m + " фундамент 1×1", "Ровная площадка, на которой можно строить.", "structure", "foundation", dict(cost), found_model(col, mat, "flat"), 1200,
          params={"height": 1.0}, catalog=S)
        B("found_" + mid + "_2x2", adj_m + " фундамент 2×2", "Большая площадка 2×2 клетки.", "structure", "foundation", {k: v * 4 for k, v in cost.items()},
          found_model(col, mat, "flat", 2), 3000, size=2, params={"height": 1.0}, catalog=S)
        B("found_" + mid + "_tall", adj_m + " фундамент 2 м", "Высокий ярус.", "structure", "foundation", {k: v * 2 for k, v in cost.items()}, found_model(col, mat, "tall"), 1600,
          params={"height": 2.0}, catalog=S)
        B("ramp_" + mid, adj_f + " рампа", "Подъём на ярус выше.", "structure", "foundation", dict(cost), found_model(col, mat, "ramp"), 1000, params={"height": 1.0, "ramp": True},
          catalog=S)
        B("fwall_" + mid, adj_f + " стена с окном", "Стена здания с окошком.", "structure", "wall", dict(cost), found_model(col, mat, "wall"), 1400, params={}, catalog=S)
    FL = [("wood", "Дощатый пол", "#a0703a", "wood", {"plank": 2}), ("parquet", "Паркет", "#8a5a32", "wood", {"oak_plank": 2}),
          ("stone", "Каменная плитка", "#a8a498", "stone", {"stone": 2}), ("marble", "Мраморный пол", "#f2f0ea", "stone", {"stone": 3, "lime": 1}),
          ("brick", "Кирпичная дорожка", "#a04a32", "stone", {"brick": 2}), ("concrete", "Бетонный пол", "#b8b4a8", "concrete", {"concrete": 1}),
          ("metal", "Металлический настил", "#5c6370", "metal", {"steel_plate": 1}), ("tile_white", "Белая плитка", "#f2f2ee", "stone", {"ceramic": 2}),
          ("tile_blue", "Синяя плитка", "#4a7ac8", "stone", {"ceramic": 2, "paint_blue": 1}), ("tile_red", "Красная плитка", "#c84a4a", "stone", {"ceramic": 2, "paint_red": 1}),
          ("grass", "Газон", "#5f9a3a", "paint", {"leaves": 4}), ("gravel", "Гравийная дорожка", "#9a948a", "stone", {"stone": 1}),
          ("sand", "Песчаная дорожка", "#e0cc90", "stone", {"stone": 1}), ("hazard", "Пол с разметкой", "#f2c440", "paint", {"concrete": 1, "paint_yellow": 1}),
          ("glow", "Светящийся пол", "#40c8ff", "glow", {"glass": 2, "led": 2})]
    for fid, fn_, col, mat, cost in FL:
        B("floor_" + fid, fn_, "Красивый пол. По нему можно ходить.", "decor", "floor", cost, found_model(col, mat, "floor"), 100, params={}, catalog="Полы")


# ------------------------------------------------------------------ особые здания
def build_special():
    SP = "Особые"
    for t in range(1, 4):
        tn, MAIN, ACC = TIERS[t - 1]
        a = []
        foundation_pad(a)
        a.append(P("box", (1.6, 0.9, 1.0), (0, 0.65, -0.3), "#f2f2f2", "paint"))
        a.append(P("box", (0.5, 0.15, 0.52), (0, 0.65, 0.21), "#e0263d", "paint"))
        a.append(P("box", (0.15, 0.5, 0.52), (0, 0.65, 0.21), "#e0263d", "paint"))
        a.append(P("box", (1.2, 0.3, 0.7), (0.1, 0.4, 0.5), MAIN, "cloth"))
        a.append(P("box", (1.1, 0.08, 0.6), (0.1, 0.58, 0.5), "#f2f2ea", "cloth"))
        a.append(P("cylinder", (0.05, 1.4, 0.05), (-0.7, 1.0, 0.6), CHR, "metal", seg=6))
        a.append(P("capsule", (0.15, 0.25, 0.08), (-0.7, 1.6, 0.6), "#e0263d", "glass", seg=8))
        energy_ring(a, 0, 1.4, 0, 0.5 + t * 0.1, "#40ff6a", thick=0.1)
        B("medbay_mk%d" % t, "Медпункт %s" % tn, "Лечит героя на %d в секунду и чинит здания рядом." % (5 + t * 5), "special", "decor",
          [{"iron_plate": 4, "glass": 2, "medkit": 1}, {"steel_plate": 6, "big_medkit": 1, "circuit": 2}, {"titanium_plate": 6, "nano_medkit": 1, "circuit_mk2": 2}][t - 1], a, 300 + t * 100,
          params={"power": 4 + t * 3}, blocks=[{"type": "heal_area", "radius": 5 + t * 2, "heal": 5 + t * 5, "repair": 8 + t * 6, "needs_power": True}], catalog=SP)
    for sid, nm, stat, val, col, cost in (("beacon_speed", "Маяк скорости", "move", 0.25, "#66ffcc", {"steel_rod": 2, "crystal": 1, "led": 2}),
                                           ("beacon_gather", "Маяк добычи", "gather", 0.4, "#ffd040", {"steel_rod": 2, "crystal": 1, "iron_gear": 2}),
                                           ("beacon_damage", "Маяк ярости", "damage", 0.3, "#ff5a3a", {"steel_rod": 2, "crystal": 1, "monster_gland": 1}),
                                           ("beacon_craft", "Маяк мастера", "craft_speed", 0.4, "#40c8ff", {"steel_rod": 2, "crystal": 1, "microchip": 1}),
                                           ("beacon_regen", "Маяк здоровья", "regen", 1.0, "#40ff6a", {"steel_rod": 2, "crystal": 1, "herbs": 4}),
                                           ("beacon_machines", "Маяк разгона машин", "machine_speed", 0.25, "#d9a6ff", {"steel_rod": 4, "quantum_chip": 1})):
        a = []
        hex_base(a, 0.6, 0.15, 0.3, DARK, col)
        a.append(P("cylinder", (0.25, 1.8, 0.25), (0, 1.2, 0), STEEL, "metal", seg=8, top=0.6))
        crystal_cluster(a, 0, 2.05, 0, col, 0.8)
        energy_ring(a, 0, 1.4, 0, 0.5, col)
        energy_ring(a, 0, 0.9, 0, 0.65, col, anim="spin", thick=0.15)
        B(sid, nm, "Рядом с ним: %s +%d%%. Нужна энергия." % ({"move": "скорость бега", "gather": "скорость добычи", "damage": "урон", "craft_speed": "скорость крафта",
                                                                "regen": "восстановление", "machine_speed": "скорость машин"}[stat], round(val * 100)), "special", "decor", cost, a, 200,
          params={"power": 4}, blocks=[{"type": "buff_area", "radius": 10, "stat": stat, "value": val, "needs_power": True}], catalog=SP)
    a = []
    foundation_pad(a)
    lattice(a, -0.4, 0.4, -0.4, 0.4, 0.2, 3.0, STEEL, levels=3, thick=0.06)
    a.append(P("sphere", (1.8, 0.6, 1.8), (0, 3.4, 0), "#e6eaee", "paint", rot=(0, 0, -30), seg=16, anim="spin_slow"))
    a.append(P("cylinder", (0.05, 0.7, 0.05), (0, 3.6, 0), DARK, "dark", seg=5, anim="spin_slow"))
    panel(a, 0.7, 0.6, 0.5, "#2e6bc7", face=1, screen="#40ff6a")
    B("radar", "Радар", "Сирена при приближении монстров на 40 клеток.", "special", "decor", {"steel_beam": 2, "antenna_part": 2, "microchip": 2}, a, 300, params={"power": 6},
      blocks=[{"type": "trigger", "event": "enemy_near", "radius": 40, "cooldown": 30, "actions": [{"do": "notify", "text": "Радар: монстры приближаются!"}, {"do": "sound", "key": "alarm", "x": "$x", "z": "$z"}]}],
      catalog=SP)
    a = []
    foundation_pad(a)
    a.append(P("box", (1.6, 1.3, 1.4), (0, 0.85, 0), "#e6eaee", "paint"))
    window_strip(a, 0.81, 1.0, 0, 1.0, 0.6, "z", "#2e6bc7")
    a.append(P("sphere", (0.9, 0.7, 0.9), (0, 1.55, 0), "#9fe8ff", "glass", seg=14))
    a.append(P("cylinder", (0.4, 0.5, 0.4), (0, 1.7, 0), "#d9a6ff", "glow", seg=10, anim="pulse"))
    for x in (-0.5, 0.5):
        tank_v(a, x, 0.2, -0.6, 0.15, 0.6, "#40ff6a")
    B("xeno_lab", "Ксенолаборатория", "Изучает ткани пришельцев: даёт очки исследований и чертежи.", "special", "decor",
      {"steel_plate": 8, "glass": 6, "microchip": 2}, a, 400, params={"power": 10},
      blocks=[{"type": "research", "in": {"alien_tissue": 1}, "points": 8, "time": 20, "needs_power": True},
              {"type": "convert", "in": {"alien_tissue": 3}, "out": {"blueprint_basic": 1}, "time": 30, "needs_power": True}], catalog=SP)
    a = []
    hex_base(a, 0.9, 0.15, 0.3, DARK, "#d9a6ff")
    for k in range(4):
        ang = k * math.pi / 2 + 0.78
        a.append(P("box", (0.15, 2.4, 0.15), (math.cos(ang) * 0.75, 1.5, math.sin(ang) * 0.75), "#3a3f47", "metal"))
        a.append(P("sphere", (0.2, 0.2, 0.2), (math.cos(ang) * 0.75, 2.75, math.sin(ang) * 0.75), "#d9a6ff", "glow", anim="pulse"))
    a.append(P("cylinder", (1.2, 0.04, 1.2), (0, 0.5, 0), "#d9a6ff", "glow", seg=24, anim="pulse"))
    energy_ring(a, 0, 1.4, 0, 0.6, "#d9a6ff", thick=0.3)
    energy_ring(a, 0, 1.4, 0, 0.45, "#ffffff", anim="spin", thick=0.15)
    B("teleporter", "Телепорт к штабу", "Встаньте на платформу — мгновенно перенесёт к штабу.", "special", "decor", {"quantum_chip": 1, "superconductor": 4, "titanium_plate": 6}, a, 600,
      params={"power": 20}, blocks=[{"type": "trigger", "event": "player_near", "radius": 1.2, "cooldown": 8, "actions": [{"do": "tp_hq"}]}], catalog=SP)
    a = []
    foundation_pad(a)
    a.append(P("box", (1.5, 1.6, 1.0), (0, 1.0, -0.3), "#c9a227", "metal"))
    a.append(P("box", (1.1, 0.6, 0.04), (0, 1.3, 0.22), "#1b2d3a", "glass"))
    a.append(P("box", (1.0, 0.5, 0.02), (0, 1.3, 0.24), "#40ff6a", "glow", anim="flicker_soft"))
    a.append(P("box", (1.2, 0.1, 0.5), (0, 0.85, 0.3), "#3a3f47", "metal"))
    for k in range(5):
        a.append(P("cylinder", (0.12, 0.04, 0.12), (-0.4 + k * 0.2, 0.92, 0.35), "#f2c440", "metal", seg=10))
    B("trade_post", "Торговая лавка", "Продаёт всё, что в неё положат, по полной цене.", "special", "decor", {"steel_plate": 6, "display_panel": 1, "gold_coin": 5}, a, 300, params={},
      blocks=[{"type": "sell", "items": [], "k": 1.0}], catalog=SP)
    a = []
    foundation_pad(a)
    for k in range(3):
        a.append(P("box", (1.4 - k * 0.3, 0.6, 1.4 - k * 0.3), (0, 0.5 + k * 0.6, 0), ["#8a8478", "#a8a498", "#c8c4b8"][k], "stone"))
    a.append(P("sphere", (0.5, 0.5, 0.5), (0, 2.25, 0), "#f2c440", "glow", anim="pulse"))
    for k in range(4):
        ang = k * math.pi / 2
        a.append(P("cylinder", (0.06, 0.06, 0.06), (math.cos(ang) * 0.6, 0.85, math.sin(ang) * 0.6), "#f2c440", "glow", anim="blink", seg=6))
    B("monument_victory", "Монумент победы", "Символ процветания колонии. +10% опыта рядом.", "special", "decor", {"gold_ingot": 10, "stone": 30, "trophy": 1}, a, 2000, params={},
      blocks=[{"type": "buff_area", "radius": 15, "stat": "xp", "value": 0.1, "needs_power": False}], catalog=SP)


def build_all():
    build_defense(); build_lights(); build_decor(); build_farm(); build_structures(); build_special()
