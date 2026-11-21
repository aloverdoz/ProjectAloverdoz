# Стиль «механика фабрики» (13.10): герой — робот-инженер, первые враги — механические.
# Всё из простых деталей (куб, шар, цилиндр, конус), анимация кодом: кости скелета («rig») двигает
# scripts/creature_rig.gd (ноги, винты, колёса, парение), героя — scripts/player.gd.
# Цвета — из общей палитры «@имя» (settings.palette): поменяли цвет в «Настройках» — поменялся у всех.
# Старые модели (crawler, brute, spitter, runner, drone, hero) остаются в каталоге — вернуть можно полем «Модель».
import math

PALETTE = {
    "body_dark": "#262a31",    # тёмный металл: рамы, шарниры, колёса
    "body_mid": "#5d6672",     # корпус врагов
    "metal_light": "#c9d0d8",  # светлые панели героя, лопасти
    "accent": "#f2a12e",       # жёлтые полосы «фабрики»
    "enemy_glow": "#ff4a1c",   # свет врагов: глаза, сенсоры
    "hero_glow": "#38d6ff",    # свет героя: визор, индикаторы
}
STYLE = {"toon": True, "steps": 3, "shade": 0.38, "rim": 0.35, "spec": 0.45,
         "outline": True, "outline_width": 2.0, "outline_color": "#14161c"}

DK, MID, LT, ACC, EG, HG = "@body_dark", "@body_mid", "@metal_light", "@accent", "@enemy_glow", "@hero_glow"


def P(shape, size, pos, color, mat="metal", rot=(0, 0, 0), role="", anim="", tint=True, seg=None, top=None, bevel=None):
    d = {"shape": shape, "size": [round(float(v), 4) for v in size], "pos": [round(float(v), 4) for v in pos],
         "rot": [round(float(v), 2) for v in rot], "color": color, "mat": mat}
    if role: d["role"] = role
    if anim: d["anim"] = anim
    if not tint: d["tint"] = False
    if seg is not None: d["seg"] = seg
    if top is not None: d["top"] = top
    if bevel is not None: d["bevel"] = bevel
    return d


def glow(shape, size, pos, color, role="", anim="pulse", rot=(0, 0, 0)):
    return P(shape, size, pos, color, "glow", rot, role, anim, tint=False)


def seg(a, b, w, color, role, shape="box", mat="metal"):
    """Деталь-«палка» от точки a до точки b (ось детали — по отрезку)."""
    d = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(x * x for x in d)) or 1e-4
    dx, dy, dz = (x / L for x in d)
    rz = math.degrees(math.asin(max(-1.0, min(1.0, -dx))))
    rx = math.degrees(math.atan2(dz, dy))
    mid = [(a[i] + b[i]) / 2 for i in range(3)]
    return P(shape, (w, L, w), mid, color, mat, (rx, 0, rz), role)


def bone(name, parent, pivot):
    return {"name": name, "parent": parent, "pivot": [round(v, 4) for v in pivot]}


def rig(bones, **kw):
    r = {"bones": bones, "legs": [], "arms": [], "jaws": [], "chains": [], "breath": [], "head": "", "body": bones[0]["name"],
         "gait": {"stride": 1.2, "swing": 25.0, "lift": 20.0, "knee": 30.0, "duty": 0.6, "bob": 0.05, "roll": 4.0, "lean": 6.0}}
    for k, v in kw.items():
        if k == "gait":
            r["gait"].update(v)
        else:
            r[k] = v
    return r


# ---------------------------------------------------------------- дрон
def drone():
    y = 1.45
    p = [P("sphere", (0.72, 0.42, 0.72), (0, y, 0), MID, role="b:body", seg=16),
         P("sphere", (0.46, 0.3, 0.46), (-0.04, y + 0.17, 0), DK, role="b:body", seg=14),
         P("cylinder", (0.82, 0.07, 0.82), (0, y - 0.04, 0), ACC, "paint", role="b:body", seg=20),
         P("cylinder", (0.06, 0.34, 0.06), (0.2, y - 0.26, 0), DK, rot=(0, 0, 90), role="b:body"),
         P("box", (0.14, 0.1, 0.16), (0.04, y - 0.24, 0), DK, role="b:body", bevel=0.03),
         P("cylinder", (0.025, 0.32, 0.025), (-0.18, y + 0.42, 0.06), DK, role="b:body"),
         glow("sphere", (0.07, 0.07, 0.07), (-0.18, y + 0.6, 0.06), EG, "b:body", "blink")]
    # глаз-сенсор: тёмное гнездо и светящийся «зрачок» — это голова, она поворачивается к цели
    p += [P("cylinder", (0.32, 0.1, 0.32), (0.3, y, 0), DK, rot=(0, 0, 90), role="b:eye", seg=16),
          glow("sphere", (0.24, 0.24, 0.24), (0.36, y, 0), EG, "b:eye"),
          P("torus", (0.3, 0.3, 0.3), (0.34, y, 0), ACC, "paint", rot=(0, 0, 90), role="b:eye", seg=18)]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:eye", "b:body", (0.3, y, 0))]
    rotors = []
    for i, (sx, sz) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        rx, rz = 0.48 * sx, 0.48 * sz
        ry = y + 0.14
        p.append(seg((0.12 * sx, y + 0.05, 0.12 * sz), (rx, ry, rz), 0.07, DK, "b:body"))
        p.append(P("torus", (0.62, 0.5, 0.62), (rx, ry, rz), ACC, "paint", role="b:body", seg=20))
        p.append(P("cylinder", (0.1, 0.1, 0.1), (rx, ry - 0.02, rz), DK, role="b:body"))
        nm = "b:rot%d" % i
        bones.append(bone(nm, "b:body", (rx, ry + 0.04, rz)))
        p.append(P("cylinder", (0.07, 0.05, 0.07), (rx, ry + 0.04, rz), LT, role=nm))
        for a in (0, 90):
            p.append(P("box", (0.5, 0.012, 0.07), (rx, ry + 0.05, rz), LT, rot=(0, a, 4 if a == 0 else -4), role=nm))
        rotors.append({"bone": nm, "axis": "y", "speed": 26.0 * (1 if i in (0, 3) else -1)})
    return {"name": "Дрон-охотник", "category": "Механика", "parts": p,
            "rig": rig(bones, head="b:eye", body="b:body", rotors=rotors,
                       hover={"amp": 0.1, "speed": 2.3},
                       gait={"stride": 2.4, "bob": 0.0, "lean": 18.0, "roll": 3.0, "bank": 16.0})}


# ---------------------------------------------------------------- паук
def spider():
    y = 0.55
    p = [P("box", (0.72, 0.24, 0.5), (0, y, 0), MID, role="b:body", bevel=0.06),
         P("box", (0.5, 0.06, 0.4), (-0.02, y + 0.15, 0), ACC, "paint", role="b:body", bevel=0.02),
         P("box", (0.12, 0.065, 0.42), (0.14, y + 0.155, 0), DK, role="b:body"),
         P("box", (0.12, 0.065, 0.42), (-0.18, y + 0.155, 0), DK, role="b:body"),
         P("cylinder", (0.3, 0.26, 0.3), (-0.44, y + 0.02, 0), DK, rot=(0, 0, 90), role="b:body", seg=14),
         glow("cylinder", (0.2, 0.03, 0.2), (-0.58, y + 0.02, 0), EG, "b:body", "pulse", (0, 0, 90)),
         P("box", (0.26, 0.2, 0.34), (0.47, y + 0.02, 0), DK, role="b:head", bevel=0.05),
         glow("sphere", (0.11, 0.11, 0.11), (0.6, y + 0.07, -0.09), EG, "b:head"),
         glow("sphere", (0.11, 0.11, 0.11), (0.6, y + 0.07, 0.09), EG, "b:head"),
         glow("sphere", (0.05, 0.05, 0.05), (0.6, y - 0.02, 0.0), EG, "b:head", "blink"),
         P("box", (0.18, 0.05, 0.05), (0.66, y - 0.08, -0.1), ACC, "paint", rot=(0, 20, 0), role="b:jawl"),
         P("box", (0.18, 0.05, 0.05), (0.66, y - 0.08, 0.1), ACC, "paint", rot=(0, -20, 0), role="b:jawr")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.38, y, 0)),
             bone("b:jawl", "b:head", (0.58, y - 0.08, -0.08)), bone("b:jawr", "b:head", (0.58, y - 0.08, 0.08))]
    legs = []
    for i, x in enumerate((0.24, 0.0, -0.24)):
        for side, sname in ((-1, "l"), (1, "r")):
            hip = (x, y, 0.24 * side)
            knee = (x + 0.06 * (1 - i), y + 0.22, 0.58 * side)
            foot = (x + 0.12 * (1 - i), 0.02, 0.86 * side)
            hn, kn = "b:hip%d%s" % (i, sname), "b:knee%d%s" % (i, sname)
            bones += [bone(hn, "b:body", hip), bone(kn, hn, knee)]
            p.append(P("sphere", (0.13, 0.13, 0.13), hip, DK, role=hn))
            p.append(seg(hip, knee, 0.075, MID, hn))
            p.append(P("sphere", (0.11, 0.11, 0.11), knee, ACC, "paint", role=kn))
            p.append(seg(knee, foot, 0.06, DK, kn))
            p.append(P("cone", (0.09, 0.12, 0.09), (foot[0], 0.06, foot[2]), DK, rot=(180, 0, 0), role=kn))
            # треножник: 0l, 1r, 2l идут вместе, остальные — в противофазе
            ph = 0.0 if (i + (0 if sname == "l" else 1)) % 2 == 0 else 0.5
            legs.append({"hip": hn, "knee": kn, "phase": ph, "side": side, "style": "y"})
    return {"name": "Паук-сборщик", "category": "Механика", "parts": p,
            "rig": rig(bones, head="b:head", body="b:body", legs=legs,
                       jaws=[{"bone": "b:jawl", "open": 18.0, "axis": "y"}, {"bone": "b:jawr", "open": -18.0, "axis": "y"}],
                       gait={"stride": 0.9, "swing": 22.0, "lift": 26.0, "knee": 20.0, "duty": 0.55, "bob": 0.03, "roll": 3.0, "lean": 4.0})}


# ---------------------------------------------------------------- колёсный громила
def roller():
    y = 1.0
    p = [P("box", (1.3, 0.56, 0.9), (0, y, 0), MID, role="b:body", bevel=0.08),
         P("box", (1.32, 0.08, 0.92), (0, y - 0.2, 0), DK, role="b:body"),
         P("wedge", (0.34, 0.42, 1.0), (0.78, y - 0.18, 0), ACC, "paint", rot=(0, 180, 0), role="b:body"),
         P("box", (0.06, 0.4, 0.14), (0.83, y - 0.16, -0.3), DK, role="b:body"),
         P("box", (0.06, 0.4, 0.14), (0.83, y - 0.16, 0.3), DK, role="b:body"),
         P("cylinder", (0.12, 0.42, 0.12), (-0.6, y + 0.42, -0.26), DK, role="b:body"),
         P("cylinder", (0.12, 0.42, 0.12), (-0.6, y + 0.42, 0.26), DK, role="b:body"),
         glow("cylinder", (0.09, 0.03, 0.09), (-0.6, y + 0.64, -0.26), EG, "b:body", "flicker"),
         glow("cylinder", (0.09, 0.03, 0.09), (-0.6, y + 0.64, 0.26), EG, "b:body", "flicker")]
    for k in range(4):
        p.append(P("box", (0.08, 0.04, 0.92), (-0.4 + k * 0.24, y + 0.28, 0), ACC if k % 2 == 0 else DK, "paint", role="b:body"))
    # башня-голова: поворачивается к цели, щель-визор светится
    p += [P("box", (0.72, 0.36, 0.62), (-0.04, y + 0.5, 0), DK, role="b:head", bevel=0.06),
          glow("box", (0.04, 0.11, 0.5), (0.33, y + 0.53, 0), EG, "b:head"),
          glow("box", (0.5, 0.05, 0.03), (-0.04, y + 0.5, 0.315), EG, "b:head"),
          glow("box", (0.5, 0.05, 0.03), (-0.04, y + 0.5, -0.315), EG, "b:head"),
          P("cylinder", (0.1, 0.5, 0.1), (0.5, y + 0.44, 0.18), DK, rot=(0, 0, 90), role="b:head"),
          P("cylinder", (0.1, 0.5, 0.1), (0.5, y + 0.44, -0.18), DK, rot=(0, 0, 90), role="b:head"),
          P("cylinder", (0.03, 0.4, 0.03), (-0.2, y + 0.86, 0.2), DK, role="b:head"),
          glow("sphere", (0.07, 0.07, 0.07), (-0.2, y + 1.07, 0.2), EG, "b:head", "blink")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.0, y + 0.32, 0))]
    wheels = []
    for i, (wx, wz) in enumerate(((0.44, -0.58), (0.44, 0.58), (-0.44, -0.58), (-0.44, 0.58))):
        nm = "b:wheel%d" % i
        bones.append(bone(nm, "b:body", (wx, 0.42, wz)))
        p.append(P("cylinder", (0.84, 0.26, 0.84), (wx, 0.42, wz), DK, "dark", rot=(90, 0, 0), role=nm, seg=18))
        p.append(P("cylinder", (0.46, 0.28, 0.46), (wx, 0.42, wz), ACC, "paint", rot=(90, 0, 0), role=nm, seg=6))
        for a in (0, 60, 120):
            p.append(P("box", (0.08, 0.86, 0.27), (wx, 0.42, wz), MID, rot=(0, 0, a), role=nm))
        wheels.append({"bone": nm, "axis": "z", "radius": 0.42})
    # кулаки-манипуляторы по бокам
    for side, s in ((-1, "l"), (1, "r")):
        nm = "b:arm" + s
        sh = (0.3, y + 0.2, 0.52 * side)
        bones.append(bone(nm, "b:body", sh))
        p.append(P("sphere", (0.22, 0.22, 0.22), sh, DK, role=nm))
        p.append(seg(sh, (0.62, y - 0.05, 0.6 * side), 0.13, MID, nm))
        p.append(P("box", (0.26, 0.24, 0.24), (0.7, y - 0.08, 0.6 * side), ACC, "paint", role=nm, bevel=0.04))
    return {"name": "Колёсный громила", "category": "Механика", "parts": p,
            "rig": rig(bones, head="b:head", body="b:body", wheels=wheels,
                       arms=[{"bone": "b:arml", "phase": 0.0, "amp": 8.0}, {"bone": "b:armr", "phase": 0.5, "amp": 8.0}],
                       gait={"stride": 2.0, "bob": 0.015, "lean": 3.0, "roll": 1.5})}


# ---------------------------------------------------------------- шагоход-разведчик
def scout():
    y = 1.15
    p = [P("box", (0.6, 0.36, 0.46), (0, y, 0), MID, role="b:body", bevel=0.08),
         P("wedge", (0.26, 0.3, 0.44), (0.38, y - 0.02, 0), DK, rot=(0, 180, 0), role="b:body"),
         P("box", (0.5, 0.05, 0.48), (-0.02, y + 0.2, 0), ACC, "paint", role="b:body"),
         P("box", (0.3, 0.1, 0.1), (-0.42, y + 0.12, 0), DK, rot=(0, 0, -20), role="b:body"),
         P("box", (0.3, 0.12, 0.12), (0.16, y - 0.06, -0.31), DK, role="b:body"),
         P("cylinder", (0.06, 0.32, 0.06), (0.36, y - 0.06, -0.31), DK, rot=(0, 0, 90), role="b:body"),
         P("box", (0.3, 0.12, 0.12), (0.16, y - 0.06, 0.31), DK, role="b:body"),
         P("cylinder", (0.06, 0.32, 0.06), (0.36, y - 0.06, 0.31), DK, rot=(0, 0, 90), role="b:body"),
         P("box", (0.24, 0.16, 0.3), (0.34, y + 0.1, 0), DK, role="b:head", bevel=0.04),
         glow("box", (0.04, 0.09, 0.26), (0.47, y + 0.11, 0), EG, "b:head"),
         glow("box", (0.16, 0.04, 0.03), (0.34, y + 0.1, 0.155), EG, "b:head"),
         glow("box", (0.16, 0.04, 0.03), (0.34, y + 0.1, -0.155), EG, "b:head"),
         P("cylinder", (0.02, 0.3, 0.02), (0.22, y + 0.32, -0.1), DK, role="b:head"),
         glow("sphere", (0.05, 0.05, 0.05), (0.22, y + 0.48, -0.1), EG, "b:head", "blink")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.28, y + 0.05, 0))]
    legs = []
    for side, s in ((-1, "l"), (1, "r")):
        hip = (0.0, y - 0.12, 0.26 * side)
        knee = (-0.2, 0.58, 0.3 * side)        # колено назад, как у птицы
        foot = (0.06, 0.04, 0.3 * side)
        hn, kn = "b:hip" + s, "b:knee" + s
        bones += [bone(hn, "b:body", hip), bone(kn, hn, knee)]
        p.append(P("sphere", (0.16, 0.16, 0.16), hip, DK, role=hn))
        p.append(seg(hip, knee, 0.12, MID, hn))
        p.append(P("sphere", (0.12, 0.12, 0.12), knee, ACC, "paint", role=kn))
        p.append(seg(knee, foot, 0.08, DK, kn))
        p.append(P("box", (0.3, 0.05, 0.14), (foot[0] + 0.06, 0.03, foot[2]), DK, role=kn, bevel=0.02))
        legs.append({"hip": hn, "knee": kn, "phase": 0.0 if s == "l" else 0.5, "side": side, "style": "z"})
    return {"name": "Шагоход-разведчик", "category": "Механика", "parts": p,
            "rig": rig(bones, head="b:head", body="b:body", legs=legs,
                       gait={"stride": 1.6, "swing": 30.0, "knee": 45.0, "duty": 0.5, "bob": 0.06, "roll": 3.0, "lean": 10.0})}


# ---------------------------------------------------------------- герой: робот-инженер
def hero(old_hero):
    p = [
        # таз и пояс
        P("box", (0.36, 0.22, 0.52), (0, 0, 0), DK, role="hips", bevel=0.05),
        P("box", (0.4, 0.07, 0.56), (0, 0.08, 0), ACC, "paint", role="hips"),
        P("box", (0.14, 0.12, 0.12), (0.12, -0.02, 0.2), MID, role="hips", bevel=0.02),
        # корпус: грудь, полоса цвета профессии (белая), ранец с охлаждением
        P("box", (0.46, 0.5, 0.64), (0.02, 0.38, 0), LT, "paint", role="torso", bevel=0.09),
        P("box", (0.48, 0.1, 0.66), (0.02, 0.2, 0), DK, role="torso"),
        P("box", (0.05, 0.2, 0.3), (0.255, 0.42, 0), "#ffffff", "paint", role="torso", bevel=0.02),
        glow("box", (0.03, 0.04, 0.12), (0.28, 0.55, 0.16), HG, "torso"),
        P("box", (0.28, 0.44, 0.48), (-0.3, 0.4, 0), MID, role="torso", bevel=0.06),
        glow("box", (0.03, 0.26, 0.05), (-0.45, 0.4, -0.12), HG, "torso", "pulse"),
        glow("box", (0.03, 0.26, 0.05), (-0.45, 0.4, 0.12), HG, "torso", "pulse"),
        P("cylinder", (0.18, 0.16, 0.18), (0.0, 0.66, 0), DK, role="torso"),
        # голова с визором
        P("box", (0.42, 0.34, 0.42), (0.0, 0.2, 0), LT, "paint", role="head", bevel=0.12),
        P("box", (0.08, 0.2, 0.38), (0.19, 0.2, 0), DK, role="head", bevel=0.04),
        glow("box", (0.03, 0.1, 0.32), (0.235, 0.21, 0), HG, "head", "pulse"),
        P("cylinder", (0.16, 0.06, 0.16), (0.0, 0.2, -0.23), ACC, "paint", rot=(90, 0, 0), role="head"),
        P("cylinder", (0.16, 0.06, 0.16), (0.0, 0.2, 0.23), ACC, "paint", rot=(90, 0, 0), role="head"),
        P("cylinder", (0.02, 0.26, 0.02), (-0.08, 0.48, 0.14), DK, role="head"),
        glow("sphere", (0.06, 0.06, 0.06), (-0.08, 0.62, 0.14), HG, "head", "blink"),
    ]
    for s, side in (("l", 1), ("r", -1)):
        p += [P("sphere", (0.28, 0.26, 0.28), (0, 0.02, 0), ACC, "paint", role="arm_" + s, seg=14),
              P("cylinder", (0.13, 0.36, 0.13), (0, -0.22, 0), DK, role="arm_" + s),
              P("sphere", (0.15, 0.15, 0.15), (0, -0.42, 0), MID, role="arm_" + s),
              P("box", (0.17, 0.3, 0.17), (0, -0.16, 0), LT, "paint", role="fore_" + s, bevel=0.04),
              glow("box", (0.03, 0.08, 0.06), (0.09, -0.14, 0), HG, "fore_" + s),
              P("box", (0.06, 0.14, 0.04), (0.02, -0.38, 0.05), ACC, "paint", rot=(12, 0, 0), role="fore_" + s),
              P("box", (0.06, 0.14, 0.04), (0.02, -0.38, -0.05), ACC, "paint", rot=(-12, 0, 0), role="fore_" + s),
              P("cylinder", (0.16, 0.42, 0.16), (0, -0.22, 0), DK, role="leg_" + s),
              P("sphere", (0.17, 0.17, 0.17), (0, -0.45, 0), MID, role="leg_" + s),
              P("box", (0.2, 0.38, 0.22), (0, -0.19, 0), LT, "paint", role="shin_" + s, bevel=0.05),
              P("box", (0.05, 0.16, 0.16), (0.11, -0.12, 0), ACC, "paint", role="shin_" + s),
              P("box", (0.36, 0.11, 0.26), (0.06, -0.42, 0), DK, role="shin_" + s, bevel=0.03)]
    # оружие — как у прежнего героя
    p += [dict(x) for x in old_hero.get("parts", []) if x.get("role") == "gun"]
    m = {"name": "Робот-инженер", "category": "Механика", "parts": p, "scale": 1.25}
    if "bones" in old_hero:
        m["bones"] = dict(old_hero["bones"])
    return m


# какие враги получают механический вид (поле «Модель» у монстра — можно вернуть старый)
ENEMY_MODELS = {"crawler": "mech_spider", "runner": "mech_scout", "spitter": "mech_drone", "brute": "mech_roller", "drone": "mech_drone"}


def apply(models, enemies, settings):
    settings["palette"] = dict(PALETTE)
    settings["char_style"] = dict(STYLE)
    models["mech_drone"] = drone()
    models["mech_spider"] = spider()
    models["mech_roller"] = roller()
    models["mech_scout"] = scout()
    models["hero_robot"] = hero(models.get("hero", {}))
    settings["hero_model"] = "hero_robot"
    for eid, mid in ENEMY_MODELS.items():
        if eid in enemies:
            enemies[eid]["model"] = mid
