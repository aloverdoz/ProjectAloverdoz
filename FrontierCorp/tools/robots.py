# 13.10 (2): все монстры заменены роботами, гнёзд нет.
# Каждый вид — модель из простых деталей с костями (анимация кодом в scripts/creature_rig.gd) и 5 версий силы «Мк1…Мк5».
# Старые семейства (зомби, слизни, драконы…) и их модели удаляются из данных. НПС (торговец, путник, бандит, лазутчик) остаются.
# Всё правится в редакторе: «Монстры и НПС», «Модели», «Волны», «Мир».
import json
import math
from mech_style import P, glow, seg, bone, rig, DK, MID, LT, ACC, EG, drone as _drone

NPC_BEHAVIORS = ("trader", "traveler", "bandit", "infiltrator")


# ---------------------------------------------------------------- детали «под машину»: болты, решётки, швы
def bolts(c, sx, sz, top, role, n=2, r=0.035):
    """Болты по углам верхней грани коробки (центр c, размеры sx×sz, высота верха top)."""
    out = []
    for i in range(n):
        for j in range(n):
            x = c[0] + (i / max(1, n - 1) - 0.5) * sx * 0.82
            z = c[2] + (j / max(1, n - 1) - 0.5) * sz * 0.82
            out.append(P("cylinder", (r, 0.025, r), (x, top + 0.012, z), LT, role=role))
    return out


def vents(c, w, h, x_face, role, n=4, side=1):
    """Решётка-радиатор на боковой грани (плоскость z = x_face)."""
    out = [P("box", (w, h, 0.02), (c[0], c[1], x_face * side), DK, role=role)]
    for k in range(n):
        y = c[1] - h * 0.38 + k * h * 0.76 / max(1, n - 1)
        out.append(P("box", (w * 0.86, 0.018, 0.03), (c[0], y, x_face * side + 0.012 * side), MID, role=role))
    return out


def cable(a, b, role, w=0.035):
    return seg(a, b, w, DK, role, "cylinder")


def piston(a, b, role):
    """Гидроцилиндр: толстая часть + блестящий шток."""
    m = [(a[i] * 0.55 + b[i] * 0.45) for i in range(3)]
    return [seg(a, m, 0.075, MID, role, "cylinder"), seg(m, b, 0.04, LT, role, "cylinder")]


def leg3(p, bones, legs, hip, knee, foot, hn, kn, parent, ph, side, style, w=(0.11, 0.08), col=MID):
    bones += [bone(hn, parent, hip), bone(kn, hn, knee)]
    p.append(P("sphere", (w[0] * 1.5,) * 3, hip, DK, role=hn))
    p.append(seg(hip, knee, w[0], col, hn))
    p += piston((hip[0], hip[1] + 0.05, hip[2]), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2 + 0.08, (hip[2] + knee[2]) / 2), hn)
    p.append(P("sphere", (w[0] * 1.3,) * 3, knee, ACC, "paint", role=kn))
    p.append(seg(knee, foot, w[1], DK, kn))
    p.append(P("cone", (w[1] * 1.6, 0.14, w[1] * 1.6), (foot[0], 0.07, foot[2]), DK, rot=(180, 0, 0), role=kn))
    legs.append({"hip": hn, "knee": kn, "phase": ph, "side": side, "style": style})


def M(name, p, R):
    return {"name": name, "category": "Роботы", "parts": p, "rig": R, "toon": True}


# ---------------------------------------------------------------- камикадзе: катящийся шар с мигалкой
def bomber():
    y = 0.5
    p = [P("box", (0.5, 0.16, 0.7), (0, y + 0.26, 0), MID, role="b:body", bevel=0.05),
         P("box", (0.52, 0.04, 0.72), (0, y + 0.35, 0), ACC, "paint", role="b:body"),
         P("cylinder", (0.18, 0.12, 0.18), (0, y + 0.42, 0), DK, role="b:body"),
         glow("sphere", (0.16, 0.16, 0.16), (0, y + 0.52, 0), EG, "b:body", "blink"),
         P("box", (0.22, 0.12, 0.3), (0.26, y + 0.24, 0), DK, role="b:head", bevel=0.03),
         glow("box", (0.03, 0.06, 0.2), (0.375, y + 0.25, 0), EG, "b:head", "flicker")]
    for s in (-1, 1):
        p += [P("box", (0.12, 0.42, 0.06), (0, y, 0.36 * s), DK, role="b:body", bevel=0.02),
              P("cylinder", (0.16, 0.08, 0.16), (0, y, 0.4 * s), ACC, "paint", rot=(90, 0, 0), role="b:body")]
    p += bolts((0, 0, 0), 0.5, 0.7, y + 0.34, "b:body")
    # шар-колесо с полосами опасности: катится по пройденному пути
    p += [P("sphere", (0.86, 0.86, 0.62), (0, y, 0), MID, role="b:ball", seg=18),
          P("torus", (0.9, 0.9, 0.9), (0, y, 0), ACC, "paint", rot=(90, 0, 0), role="b:ball", seg=20),
          P("torus", (0.7, 0.7, 0.7), (0, y, 0), DK, rot=(90, 0, 0), role="b:ball", seg=18)]
    for a in range(0, 360, 45):
        r = math.radians(a)
        p.append(P("cone", (0.1, 0.14, 0.1), (math.cos(r) * 0.46, y + math.sin(r) * 0.46, 0), DK, rot=(0, 0, a - 90), role="b:ball"))
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.2, y + 0.24, 0)), bone("b:ball", "b:body", (0, y, 0))]
    return M("Робот-камикадзе", p, rig(bones, head="b:head", body="b:body", wheels=[{"bone": "b:ball", "axis": "z", "radius": 0.43}],
                                      gait={"stride": 2.0, "bob": 0.02, "lean": 2.0, "roll": 4.0, "bank": 10.0}))


# ---------------------------------------------------------------- снайпер: высокий четвероногий с длинной пушкой
def sniper():
    y = 1.5
    p = [P("box", (0.8, 0.34, 0.56), (0, y, 0), MID, role="b:body", bevel=0.08),
         P("box", (0.6, 0.06, 0.5), (-0.05, y + 0.2, 0), ACC, "paint", role="b:body"),
         P("box", (0.3, 0.3, 0.4), (-0.48, y + 0.06, 0), DK, role="b:body", bevel=0.05),
         P("cylinder", (0.08, 0.5, 0.08), (-0.52, y + 0.4, 0.14), DK, role="b:body"),
         glow("sphere", (0.06, 0.06, 0.06), (-0.52, y + 0.67, 0.14), EG, "b:body", "blink")]
    p += vents((-0.48, y + 0.06, 0), 0.24, 0.22, 0.205, "b:body")
    p += vents((-0.48, y + 0.06, 0), 0.24, 0.22, 0.205, "b:body", side=-1)
    p += bolts((0, 0, 0), 0.8, 0.56, y + 0.17, "b:body", 3)
    # башня с длинным стволом и прицелом
    p += [P("box", (0.46, 0.26, 0.42), (0.18, y + 0.32, 0), DK, role="b:head", bevel=0.05),
          P("cylinder", (0.11, 1.3, 0.11), (0.95, y + 0.34, 0), DK, rot=(0, 0, 90), role="b:head"),
          P("cylinder", (0.16, 0.24, 0.16), (1.5, y + 0.34, 0), MID, rot=(0, 0, 90), role="b:head"),
          P("cylinder", (0.18, 0.06, 0.18), (0.6, y + 0.34, 0), ACC, "paint", rot=(0, 0, 90), role="b:head"),
          P("cylinder", (0.1, 0.34, 0.1), (0.3, y + 0.52, -0.14), MID, rot=(0, 0, 90), role="b:head"),
          glow("cylinder", (0.08, 0.02, 0.08), (0.48, y + 0.52, -0.14), EG, "b:head", "pulse", (0, 0, 90)),
          glow("box", (0.03, 0.06, 0.3), (0.415, y + 0.32, 0.0), EG, "b:head")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.18, y + 0.2, 0))]
    legs = []
    for i, x in enumerate((0.3, -0.3)):
        for side, s in ((-1, "l"), (1, "r")):
            hip = (x, y - 0.1, 0.26 * side)
            knee = (x * 1.6, y + 0.15, 0.7 * side)
            foot = (x * 1.9, 0.02, 0.95 * side)
            ph = 0.0 if (i + (0 if s == "l" else 1)) % 2 == 0 else 0.5
            leg3(p, bones, legs, hip, knee, foot, "b:hip%d%s" % (i, s), "b:knee%d%s" % (i, s), "b:body", ph, side, "y", (0.12, 0.08))
    return M("Робот-снайпер", p, rig(bones, head="b:head", body="b:body", legs=legs,
                                    gait={"stride": 1.3, "swing": 18.0, "lift": 22.0, "knee": 18.0, "duty": 0.6, "bob": 0.03, "roll": 2.0, "lean": 3.0}))


# ---------------------------------------------------------------- ремонтник: летающий дрон с манипуляторами
def medic():
    y = 1.6
    p = [P("box", (0.62, 0.34, 0.62), (0, y, 0), MID, role="b:body", bevel=0.12),
         P("box", (0.64, 0.06, 0.64), (0, y + 0.08, 0), ACC, "paint", role="b:body", bevel=0.03),
         P("box", (0.12, 0.04, 0.4), (0, y + 0.19, 0), EG, "glow", role="b:body", anim="pulse", tint=False),
         P("box", (0.4, 0.04, 0.12), (0, y + 0.19, 0), EG, "glow", role="b:body", anim="pulse", tint=False),
         P("cylinder", (0.3, 0.1, 0.3), (0, y - 0.22, 0), DK, role="b:body"),
         glow("sphere", (0.18, 0.18, 0.18), (0, y - 0.3, 0), EG, "b:body", "pulse"),
         P("box", (0.16, 0.18, 0.3), (0.34, y, 0), DK, role="b:head", bevel=0.04),
         glow("box", (0.03, 0.08, 0.22), (0.425, y, 0), EG, "b:head")]
    p += bolts((0, 0, 0), 0.62, 0.62, y + 0.17, "b:body")
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.3, y, 0))]
    rotors = []
    for i, s in enumerate((-1, 1)):
        rx, rz = 0.0, 0.62 * s
        p.append(seg((0, y + 0.05, 0.3 * s), (rx, y + 0.12, rz), 0.08, DK, "b:body"))
        p.append(P("cylinder", (0.66, 0.12, 0.66), (rx, y + 0.12, rz), DK, role="b:body", seg=20))
        p.append(P("torus", (0.7, 0.5, 0.7), (rx, y + 0.17, rz), ACC, "paint", role="b:body", seg=20))
        nm = "b:rot%d" % i
        bones.append(bone(nm, "b:body", (rx, y + 0.16, rz)))
        for a in (0, 60, 120):
            p.append(P("box", (0.56, 0.012, 0.07), (rx, y + 0.17, rz), LT, rot=(0, a, 5), role=nm))
        rotors.append({"bone": nm, "axis": "y", "speed": 30.0 * s})
    arms = []
    for s, nm in ((-1, "b:arml"), (1, "b:armr")):
        sh = (0.2, y - 0.15, 0.2 * s)
        bones.append(bone(nm, "b:body", sh))
        p.append(P("sphere", (0.12, 0.12, 0.12), sh, DK, role=nm))
        el = (0.42, y - 0.42, 0.24 * s)
        p.append(seg(sh, el, 0.06, MID, nm))
        p.append(seg(el, (0.62, y - 0.36, 0.2 * s), 0.05, DK, nm))
        p.append(P("box", (0.08, 0.04, 0.03), (0.68, y - 0.34, 0.2 * s + 0.03), ACC, "paint", rot=(0, 0, 20), role=nm))
        p.append(P("box", (0.08, 0.04, 0.03), (0.68, y - 0.38, 0.2 * s - 0.03), ACC, "paint", rot=(0, 0, -20), role=nm))
        arms.append({"bone": nm, "phase": 0.0 if s < 0 else 0.5, "amp": 18.0})
    return M("Робот-ремонтник", p, rig(bones, head="b:head", body="b:body", rotors=rotors, arms=arms,
                                      hover={"amp": 0.12, "speed": 2.0}, gait={"stride": 2.2, "bob": 0.0, "lean": 12.0, "roll": 2.0, "bank": 14.0}))


# ---------------------------------------------------------------- сборщик-вор: быстрый четвероногий с клешнёй и контейнером
def thief():
    y = 0.62
    p = [P("box", (0.62, 0.22, 0.38), (0, y, 0), MID, role="b:body", bevel=0.06),
         P("box", (0.34, 0.24, 0.34), (-0.16, y + 0.22, 0), DK, role="b:body", bevel=0.04),
         P("box", (0.36, 0.04, 0.36), (-0.16, y + 0.35, 0), ACC, "paint", role="b:body"),
         P("box", (0.2, 0.14, 0.26), (0.36, y + 0.03, 0), DK, role="b:head", bevel=0.04),
         glow("sphere", (0.07, 0.07, 0.07), (0.46, y + 0.06, -0.07), EG, "b:head"),
         glow("sphere", (0.07, 0.07, 0.07), (0.46, y + 0.06, 0.07), EG, "b:head")]
    p += bolts((-0.16, 0, 0), 0.34, 0.34, y + 0.37, "b:body")
    # клешня на спине — хватает добычу
    p += [seg((0.05, y + 0.12, 0), (0.2, y + 0.46, 0), 0.06, DK, "b:claw"),
          seg((0.2, y + 0.46, 0), (0.42, y + 0.4, 0), 0.05, MID, "b:claw"),
          P("box", (0.12, 0.04, 0.03), (0.47, y + 0.37, 0.04), ACC, "paint", rot=(0, 0, -30), role="b:claw"),
          P("box", (0.12, 0.04, 0.03), (0.47, y + 0.37, -0.04), ACC, "paint", rot=(0, 0, -30), role="b:claw")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.3, y, 0)), bone("b:claw", "b:body", (0.05, y + 0.12, 0))]
    legs = []
    for i, x in enumerate((0.2, -0.2)):
        for side, s in ((-1, "l"), (1, "r")):
            ph = 0.0 if (i + (0 if s == "l" else 1)) % 2 == 0 else 0.5
            leg3(p, bones, legs, (x, y - 0.04, 0.18 * side), (x + 0.08, y + 0.08, 0.42 * side), (x + 0.12, 0.02, 0.56 * side),
                 "b:hip%d%s" % (i, s), "b:knee%d%s" % (i, s), "b:body", ph, side, "y", (0.07, 0.05))
    return M("Робот-сборщик", p, rig(bones, head="b:head", body="b:body", legs=legs, arms=[{"bone": "b:claw", "phase": 0.25, "amp": 12.0}],
                                    gait={"stride": 1.1, "swing": 26.0, "lift": 30.0, "knee": 22.0, "duty": 0.45, "bob": 0.04, "roll": 3.0, "lean": 6.0}))


# ---------------------------------------------------------------- носитель: большой летающий ангар, выпускает дронов
def carrier():
    y = 2.3
    p = [P("box", (1.8, 0.6, 1.1), (0, y, 0), MID, role="b:body", bevel=0.14),
         P("box", (1.82, 0.08, 1.12), (0, y + 0.14, 0), ACC, "paint", role="b:body"),
         P("box", (0.9, 0.3, 0.8), (-0.3, y + 0.42, 0), DK, role="b:body", bevel=0.08),
         P("box", (1.0, 0.1, 0.7), (0.1, y - 0.34, 0), DK, role="b:body"),
         glow("box", (0.8, 0.03, 0.5), (0.1, y - 0.4, 0), EG, "b:body", "pulse"),
         P("cylinder", (0.05, 0.6, 0.05), (-0.6, y + 0.85, 0.3), DK, role="b:body"),
         glow("sphere", (0.09, 0.09, 0.09), (-0.6, y + 1.17, 0.3), EG, "b:body", "blink"),
         P("box", (0.4, 0.32, 0.6), (0.98, y, 0), DK, role="b:head", bevel=0.06),
         glow("box", (0.03, 0.1, 0.46), (1.19, y + 0.03, 0), EG, "b:head"),
         P("cylinder", (0.08, 0.5, 0.08), (1.3, y - 0.12, 0.2), DK, rot=(0, 0, 90), role="b:head"),
         P("cylinder", (0.08, 0.5, 0.08), (1.3, y - 0.12, -0.2), DK, rot=(0, 0, 90), role="b:head")]
    for s in (-1, 1):
        p += vents((-0.3, y, 0), 0.8, 0.36, 0.555, "b:body", 5, s)
    p += bolts((-0.3, 0, 0), 0.9, 0.8, y + 0.57, "b:body", 3)
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.9, y, 0))]
    rotors = []
    for i, (sx, sz) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        rx, rz = 0.85 * sx, 0.95 * sz
        p.append(seg((0.4 * sx, y, 0.4 * sz), (rx, y + 0.05, rz), 0.12, DK, "b:body"))
        p.append(P("cylinder", (0.9, 0.22, 0.9), (rx, y + 0.05, rz), DK, role="b:body", seg=22))
        p.append(P("torus", (0.96, 0.6, 0.96), (rx, y + 0.16, rz), ACC, "paint", role="b:body", seg=22))
        nm = "b:rot%d" % i
        bones.append(bone(nm, "b:body", (rx, y + 0.12, rz)))
        p.append(P("cylinder", (0.14, 0.1, 0.14), (rx, y + 0.12, rz), LT, role=nm))
        for a in (0, 45, 90, 135):
            p.append(P("box", (0.78, 0.015, 0.09), (rx, y + 0.13, rz), LT, rot=(0, a, 6), role=nm))
        rotors.append({"bone": nm, "axis": "y", "speed": 22.0 * (1 if i in (0, 3) else -1)})
    return M("Робот-носитель", p, rig(bones, head="b:head", body="b:body", rotors=rotors, breath=["b:body"],
                                     hover={"amp": 0.15, "speed": 1.4}, gait={"stride": 2.6, "bob": 0.0, "lean": 8.0, "roll": 2.0, "bank": 10.0}))


# ---------------------------------------------------------------- бур-змей: сегменты, вращающийся бур (роет под землёй)
def driller():
    y = 0.6
    p = [P("cylinder", (0.84, 0.5, 0.84), (0.0, y, 0), MID, rot=(0, 0, 90), role="b:body", seg=16),
         P("cylinder", (0.9, 0.08, 0.9), (0.2, y, 0), ACC, "paint", rot=(0, 0, 90), role="b:body", seg=16),
         P("cylinder", (0.9, 0.08, 0.9), (-0.2, y, 0), DK, rot=(0, 0, 90), role="b:body", seg=16),
         glow("box", (0.3, 0.05, 0.03), (0, y + 0.15, 0.43), EG, "b:body"),
         glow("box", (0.3, 0.05, 0.03), (0, y + 0.15, -0.43), EG, "b:body")]
    # голова с буром
    p += [P("cylinder", (0.8, 0.3, 0.8), (0.42, y, 0), DK, rot=(0, 0, 90), role="b:head", seg=16),
          glow("torus", (0.82, 0.82, 0.82), (0.56, y, 0), EG, "b:head", "pulse", (0, 0, 90))]
    p += [P("cone", (0.74, 0.8, 0.74), (0.98, y, 0), LT, rot=(0, 0, -90), role="b:drill", seg=12),
          P("screw", (0.6, 0.7, 0.6), (0.92, y, 0), ACC, "paint", rot=(0, 0, -90), role="b:drill")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.3, y, 0)), bone("b:drill", "b:head", (0.7, y, 0))]
    chain = []
    par = "b:body"
    for k in range(5):
        x = -0.5 - k * 0.48
        nm = "b:seg%d" % k
        bones.append(bone(nm, par, (x + 0.24, y, 0)))
        r = 0.8 - k * 0.08
        p.append(P("cylinder", (r, 0.4, r), (x, y - k * 0.02, 0), MID if k % 2 == 0 else DK, rot=(0, 0, 90), role=nm, seg=14))
        p.append(P("cylinder", (r + 0.05, 0.06, r + 0.05), (x + 0.16, y - k * 0.02, 0), ACC if k % 2 == 0 else MID, "paint", rot=(0, 0, 90), role=nm, seg=14))
        for s in (-1, 1):
            p.append(P("cone", (0.08, 0.16, 0.08), (x, y - k * 0.02 - r * 0.45, 0.2 * s), DK, rot=(180, 0, 0), role=nm))
        chain.append(nm)
        par = nm
    return M("Бур-змей", p, rig(bones, head="b:head", body="b:body", rotors=[{"bone": "b:drill", "axis": "x", "speed": 24.0}],
                               chains=[{"bones": chain, "axis": "y", "amp": 14.0, "speed": 4.0, "lag": 0.7, "follow": True}],
                               gait={"stride": 2.0, "bob": 0.03, "lean": 2.0, "roll": 3.0, "bank": 6.0}))


# ---------------------------------------------------------------- охранник: тяжёлый двуногий со щитом и пулемётом
def guard(big=False):
    y = 1.5
    p = [P("box", (0.62, 0.7, 0.86), (0, y + 0.3, 0), MID, role="b:body", bevel=0.12),
         P("box", (0.64, 0.12, 0.88), (0, y + 0.02, 0), DK, role="b:body"),
         P("box", (0.64, 0.08, 0.88), (0.0, y + 0.5, 0), ACC, "paint", role="b:body"),
         P("box", (0.36, 0.5, 0.6), (-0.42, y + 0.32, 0), DK, role="b:body", bevel=0.06),
         P("box", (0.5, 0.3, 0.5), (0, y - 0.18, 0), DK, role="b:body", bevel=0.05)]
    p += vents((-0.42, y + 0.32, 0), 0.3, 0.4, 0.305, "b:body", 5)
    p += vents((-0.42, y + 0.32, 0), 0.3, 0.4, 0.305, "b:body", 5, -1)
    p += bolts((0, 0, 0), 0.62, 0.86, y + 0.66, "b:body", 3)
    p += [P("box", (0.38, 0.3, 0.4), (0.12, y + 0.82, 0), DK, role="b:head", bevel=0.08),
          glow("box", (0.03, 0.08, 0.32), (0.315, y + 0.84, 0), EG, "b:head"),
          P("box", (0.06, 0.2, 0.1), (0.1, y + 0.82, 0.22), ACC, "paint", role="b:head"),
          P("box", (0.06, 0.2, 0.1), (0.1, y + 0.82, -0.22), ACC, "paint", role="b:head")]
    bones = [bone("b:body", "", (0, y, 0)), bone("b:head", "b:body", (0.1, y + 0.7, 0))]
    # левая рука — щит, правая — пулемёт
    for s, nm in ((-1, "b:arml"), (1, "b:armr")):
        sh = (0.05, y + 0.52, 0.56 * s)
        bones.append(bone(nm, "b:body", sh))
        p.append(P("sphere", (0.3, 0.3, 0.3), sh, ACC, "paint", role=nm))
        p.append(seg(sh, (0.2, y + 0.05, 0.6 * s), 0.18, DK, nm))
        if s < 0:
            p += [P("box", (0.1, 0.9, 0.7), (0.42, y + 0.1, 0.72 * s), MID, role=nm, bevel=0.05),
                  P("box", (0.12, 0.7, 0.08), (0.43, y + 0.1, 0.72 * s), ACC, "paint", role=nm),
                  glow("box", (0.03, 0.06, 0.4), (0.48, y + 0.42, 0.72 * s), EG, nm)]
        else:
            p += [P("box", (0.5, 0.22, 0.22), (0.36, y, 0.6 * s), DK, role=nm, bevel=0.03)]
            for k in range(3):
                a = math.radians(k * 120)
                p.append(P("cylinder", (0.06, 0.5, 0.06), (0.78, y + math.cos(a) * 0.06, 0.6 * s + math.sin(a) * 0.06), MID, rot=(0, 0, 90), role=nm))
            p.append(P("cylinder", (0.2, 0.05, 0.2), (0.95, y, 0.6 * s), ACC, "paint", rot=(0, 0, 90), role=nm))
    legs = []
    for side, s in ((-1, "l"), (1, "r")):
        hip = (0.0, y - 0.2, 0.28 * side)
        knee = (0.16, 0.78, 0.32 * side)
        foot = (0.0, 0.08, 0.32 * side)
        hn, kn = "b:hip" + s, "b:knee" + s
        bones += [bone(hn, "b:body", hip), bone(kn, hn, knee)]
        p.append(P("sphere", (0.24, 0.24, 0.24), hip, DK, role=hn))
        p.append(seg(hip, knee, 0.22, MID, hn))
        p += piston((hip[0] - 0.12, hip[1], hip[2]), (knee[0] - 0.1, knee[1] + 0.1, knee[2]), hn)
        p.append(P("sphere", (0.2, 0.2, 0.2), knee, ACC, "paint", role=kn))
        p.append(seg(knee, foot, 0.17, DK, kn))
        p.append(P("box", (0.48, 0.12, 0.3), (foot[0] + 0.06, 0.06, foot[2]), DK, role=kn, bevel=0.03))
        legs.append({"hip": hn, "knee": kn, "phase": 0.0 if s == "l" else 0.5, "side": side, "style": "z"})
    if big:
        # титан: пушки на плечах и антенны
        for s in (-1, 1):
            p += [P("box", (0.5, 0.26, 0.26), (-0.05, y + 0.85, 0.36 * s), DK, role="b:body", bevel=0.04),
                  P("cylinder", (0.12, 0.6, 0.12), (0.45, y + 0.85, 0.36 * s), MID, rot=(0, 0, 90), role="b:body"),
                  glow("cylinder", (0.09, 0.02, 0.09), (0.76, y + 0.85, 0.36 * s), EG, "b:body", "pulse", (0, 0, 90)),
                  P("cylinder", (0.03, 0.5, 0.03), (-0.5, y + 0.85, 0.3 * s), DK, role="b:body"),
                  glow("sphere", (0.06, 0.06, 0.06), (-0.5, y + 1.12, 0.3 * s), EG, "b:body", "blink")]
    return M("Титан" if big else "Робот-охранник", p,
             rig(bones, head="b:head", body="b:body", legs=legs,
                 arms=[{"bone": "b:arml", "phase": 0.0, "amp": 10.0}, {"bone": "b:armr", "phase": 0.5, "amp": 14.0}],
                 gait={"stride": 1.5, "swing": 24.0, "knee": 36.0, "duty": 0.6, "bob": 0.07, "roll": 3.0, "lean": 5.0}))


# ---------------------------------------------------------------- маленький дрон (вызывают носители)
def mini():
    m = _drone()
    m["name"] = "Мини-дрон"
    m["category"] = "Роботы"
    for p in m["parts"]:
        p["size"] = [round(v * 0.7, 4) for v in p["size"]]
        p["pos"] = [round(v * 0.7, 4) for v in p["pos"]]
    for b in m["rig"]["bones"]:
        b["pivot"] = [round(v * 0.7, 4) for v in b["pivot"]]
    return m


# ---------------------------------------------------------------- штурмовой корабль (босс): носитель с крыльями и пушками
def gunship():
    m = carrier()
    m["name"] = "Штурмовой корабль"
    y = 2.3
    for s in (-1, 1):
        m["parts"] += [P("wedge", (1.2, 0.08, 1.0), (-0.2, y + 0.05, 1.05 * s), MID, rot=(0, 0, 0), role="b:body"),
                       P("box", (0.6, 0.2, 0.2), (0.4, y - 0.2, 0.75 * s), DK, role="b:body", bevel=0.03),
                       P("cylinder", (0.1, 0.8, 0.1), (0.9, y - 0.2, 0.75 * s), MID, rot=(0, 0, 90), role="b:body"),
                       glow("cylinder", (0.07, 0.02, 0.07), (1.31, y - 0.2, 0.75 * s), EG, "b:body", "pulse", (0, 0, 90)),
                       glow("box", (0.8, 0.03, 0.04), (-0.2, y + 0.1, 1.55 * s), EG, "b:body")]
    return m


# ---------------------------------------------------------------- список роботов
# id, модель, название, характеристики, с какого дня, вес появления, правила
def _R(cond, then, n=None, **kw):
    r = {"if": cond, "then": then, "stop": True}
    if n is not None:
        r["n"] = n
    r.update(kw)
    return r


DROPS_LIGHT = [{"item": "chitin", "chance": 0.5, "min": 1, "max": 2}, {"item": "goo", "chance": 0.3, "min": 1, "max": 1}]
DROPS_HEAVY = [{"item": "chitin", "chance": 0.9, "min": 2, "max": 4}, {"item": "goo", "chance": 0.6, "min": 1, "max": 3},
               {"item": "circuit", "chance": 0.15, "min": 1, "max": 1}]

ROBOTS = [
    ("crawler", "mech_spider", "Паук-сборщик", dict(hp=45, speed=6.0, damage=9, rate=0.7, reach=1.3, radius=0.8), 1, 0, DROPS_LIGHT, []),
    ("runner", "mech_scout", "Шагоход-разведчик", dict(hp=25, speed=10.0, damage=6, rate=0.5, reach=1.1, radius=0.6, behavior="player"), 1, 0, DROPS_LIGHT,
     [_R("hp_below", "flee", 0.3), _R("always", "normal")]),
    ("spitter", "mech_drone", "Дрон-охотник", dict(hp=80, speed=4.0, damage=12, rate=1.5, reach=10.0, radius=1.0, ranged=True), 2, 0, DROPS_LIGHT, []),
    ("brute", "mech_roller", "Колёсный громила", dict(hp=320, speed=3.2, damage=45, rate=1.3, reach=2.2, radius=1.7, behavior="base"), 3, 0, DROPS_HEAVY,
     [_R("hp_below", "speed", 0.5, value=1.6, cooldown=8), _R("always", "normal")]),
    ("bomber", "mech_bomber", "Робот-камикадзе", dict(hp=60, speed=7.0, damage=5, radius=0.7, explode_damage=60, explode_radius=4.0), 3, 0.8, DROPS_LIGHT, []),
    ("thief", "mech_thief", "Робот-сборщик", dict(hp=70, speed=8.0, damage=4, radius=0.7, steal=8), 4, 0.6, DROPS_LIGHT,
     [_R("hit", "flee", cooldown=6), _R("always", "normal")]),
    ("drone", "mech_mini", "Мини-дрон", dict(hp=50, speed=8.0, damage=8, rate=1.6, reach=10.0, radius=0.6, fly=True, fly_height=4.0, ranged=True), 4, 0.8, DROPS_LIGHT, []),
    ("worm", "mech_driller", "Бур-змей", dict(hp=260, speed=5.0, damage=30, rate=1.4, reach=2.2, radius=1.3, burrow=True), 5, 0.4, DROPS_HEAVY, []),
    ("sniper", "mech_sniper", "Робот-снайпер", dict(hp=90, speed=3.5, damage=24, rate=1.6, reach=18.0, radius=1.0, ranged=True, teleport_every=9, teleport_range=25), 5, 0.5, DROPS_HEAVY,
     [_R("player_far", "attack_building", 20), _R("always", "normal")]),
    ("medic", "mech_medic", "Робот-ремонтник", dict(hp=110, speed=4.0, damage=6, radius=0.9, heal_every=4, heal_amount=25, heal_radius=10), 6, 0.4, DROPS_HEAVY,
     [_R("hp_below", "flee", 0.3), _R("always", "normal")]),
    ("guard", "mech_guard", "Робот-охранник", dict(hp=260, speed=3.5, damage=22, rate=1.0, reach=1.6, radius=1.1), 6, 0.6, DROPS_HEAVY,
     [_R("sees_player", "attack_player", 15), _R("always", "go_home")]),
    ("carrier", "mech_carrier", "Робот-носитель", dict(hp=700, speed=2.4, damage=20, rate=1.6, reach=12.0, radius=1.6, ranged=True, fly=True, fly_height=1.0,
                                                       summon="drone", summon_every=12, summon_n=2, summon_max=6), 9, 0.15, DROPS_HEAVY,
     [_R("hit", "summon", value=2, enemy="drone", cooldown=10), _R("always", "normal")]),
]

# версии силы: суффикс id, название, hp, урон, скорость, размер, награда, день позже, вес
TIERS = [("", "", 1.0, 1.0, 1.0, 1.0, 1.0, 0, 1.0),
         ("_t2", "Мк2", 1.8, 1.35, 1.05, 1.08, 1.8, 3, 0.5),
         ("_t3", "Мк3", 3.0, 1.8, 1.08, 1.16, 3.0, 7, 0.25),
         ("_t4", "Мк4", 5.0, 2.4, 1.1, 1.26, 5.0, 12, 0.08),
         ("_t5", "Мк5", 9.0, 3.2, 1.12, 1.4, 9.0, 18, 0.03)]


def apply(models, enemies, waves, events, items, settings, world, quests, menu):
    # 1) убрать всех старых монстров (НПС остаются)
    for eid in list(enemies):
        if str(enemies[eid].get("behavior", "")) not in NPC_BEHAVIORS:
            del enemies[eid]
    # 2) модели роботов
    models["mech_bomber"] = bomber()
    models["mech_sniper"] = sniper()
    models["mech_medic"] = medic()
    models["mech_thief"] = thief()
    models["mech_carrier"] = carrier()
    models["mech_driller"] = driller()
    models["mech_guard"] = guard()
    models["mech_titan"] = guard(True)
    models["mech_mini"] = mini()
    models["mech_gunship"] = gunship()
    for mid in ("mech_drone", "mech_spider", "mech_roller", "mech_scout"):
        models[mid]["category"] = "Роботы"
        models[mid]["toon"] = True
    # 3) роботы и их версии силы
    for eid, mid, name, st, day, w, drops, rules in ROBOTS:
        for suf, tname, hk, dk, sk, sc, rk, dd, tw in TIERS:
            base = dict(st)
            e = {"name": name + (" " + tname if tname else ""), "model": mid, "family": "Роботы",
                 "hp": round(base.pop("hp") * hk), "damage": round(base.pop("damage") * dk, 1),
                 "speed": round(base.pop("speed") * sk, 2), "rate": base.pop("rate", 1.0), "reach": base.pop("reach", 1.4),
                 "radius": round(base.pop("radius", 0.8) * sc, 2), "scale": round(sc, 2), "behavior": base.pop("behavior", "nearest"),
                 "reward": max(1, round((3 + day) * rk)), "xp": max(1, round((2 + day * 0.5) * rk)),
                 "spawn_weight": round(w * tw if suf == "" else max(w, 0.6) * tw, 3), "from_day": day + dd,
                 "spawn_leader": suf in ("_t4", "_t5"), "spawn_where": "both",
                 "drops": [dict(d, max=max(d["max"], round(d["max"] * rk ** 0.5))) for d in drops]}
            e.update(base)
            if rules:
                e["rules"] = [dict(r) for r in rules]
            enemies[eid + suf] = e
    # первые четыре Мк1 идут в волны по списку «Волны → Группы», остальные — по весу появления
    waves["groups"] = [{"enemy": "crawler", "weight": 10, "from_wave": 1}, {"enemy": "runner", "weight": 4, "from_wave": 2},
                       {"enemy": "spitter", "weight": 3, "from_wave": 3}, {"enemy": "brute", "weight": 2, "from_wave": 3}]
    waves["guards"] = {"enemy": "guard", "count": 6, "boss": "brute"}
    waves["roaming"]["groups"] = [{"enemy": "crawler", "weight": 10, "from_day": 1}, {"enemy": "runner", "weight": 5, "from_day": 1},
                                  {"enemy": "spitter", "weight": 3, "from_day": 2}, {"enemy": "brute", "weight": 1, "from_day": 3, "leader": True}]
    # 4) боссы осад
    def BOSS(id, src, model, name, scale, hp, dmg, speed, reach, radius, reward, rules, **kw):
        e = json.loads(json.dumps(enemies[src]))
        e.update({"name": name, "model": model, "scale": scale, "hp": hp, "damage": dmg, "speed": speed, "reach": reach, "radius": radius,
                  "reward": reward, "xp": reward // 10, "boss": True, "behavior": "base", "spawn_weight": 0, "rules": rules,
                  "drops": [{"item": "crystal", "chance": 1.0, "min": 6, "max": 12, "on": "break"}, {"item": "circuit", "chance": 1.0, "min": 8, "max": 16, "on": "break"}]})
        e.update(kw)
        enemies[id] = e
    BOSS("boss_titan", "guard", "mech_titan", "Титан", 3.0, 6000, 90, 3.0, 3.6, 2.6, 900,
         [_R("hp_below", "summon", 0.5, value=3, enemy="guard", cooldown=30), _R("hp_below", "speed", 0.25, value=1.5, cooldown=8),
          _R("timer", "say", 2, text="ЦЕЛЬ: ШТАБ. УНИЧТОЖИТЬ.", cooldown=9999), _R("always", "attack_base")])
    BOSS("boss_dragon", "carrier", "mech_gunship", "Штурмовой корабль", 2.2, 4500, 60, 4.5, 14.0, 2.2, 1000,
         [_R("hp_below", "teleport", 0.6, cooldown=20), _R("sees_player", "attack_player", 25), _R("always", "attack_base")],
         fly=True, fly_height=5.0, ranged=True, summon="drone", summon_every=15, summon_n=2)
    BOSS("boss_worm", "worm", "mech_driller", "Бур-пожиратель", 2.8, 5500, 80, 3.6, 3.2, 2.4, 950,
         [_R("hit", "call_allies", value=30, cooldown=15), _R("always", "attack_base")], burrow=True)
    BOSS("boss_hive", "carrier", "mech_carrier", "Матка-фабрика", 2.6, 4000, 50, 3.0, 12.0, 2.4, 850,
         [_R("hit", "summon", value=4, enemy="drone", cooldown=12), _R("hp_below", "heal_self", 0.3, value=800, cooldown=40), _R("always", "attack_base")])
    BOSS("boss_lich", "sniper", "mech_sniper", "Командир-призрак", 2.4, 4200, 70, 3.4, 20.0, 1.8, 1100,
         [_R("hit", "teleport", cooldown=10), _R("hp_below", "summon", 0.7, value=3, enemy="bomber", cooldown=20), _R("always", "attack_base")])
    # 5) события: только роботы
    ev = {"mother_roar": ["crawler", "runner", "spitter", "brute"], "ground_tremor": ["worm"], "locusts": ["drone", "thief"],
          "capsule_crash": ["guard", "drone"], "gnome_raid": ["thief", "bomber", "runner"], "robot_invasion": ["guard", "drone", "bomber", "brute"],
          "alien_landing": ["sniper", "medic", "guard", "carrier"]}
    for k, lst in ev.items():
        if k in events:
            events[k]["monsters"] = lst
    texts = {"mother_roar": ("Сигнал роя", "Где-то далеко включился маяк роя… Толпы роботов идут прямо на вас!", "Маяк замолчал."),
             "ground_tremor": ("Дрожь земли", "Земля дрожит… Под базой роют бур-змеи! Они вылезают и ломают здания.", "Бур-змеи ушли глубоко под землю."),
             "locusts": ("Налёт сборщиков", "Мини-дроны и роботы-сборщики летят к складам! Защитите запасы.", "Сборщики улетели."),
             "gnome_raid": ("Набег разведчиков", "Набег разведчиков! Камикадзе и сборщики идут к штабу.", ""),
             "alien_landing": ("Десант с орбиты", "Десант с орбиты! Носитель сбросил отряд — он идёт к штабу.", "")}
    for k, (nm, tx, et) in texts.items():
        if k in events:
            events[k]["name"], events[k]["text"] = nm, tx
            if et:
                events[k]["end_text"] = et
    # подземелья (выключены) — охрана из роботов
    dg = settings.get("dungeons")
    if isinstance(dg, dict):
        dg["guards"] = [{"enemy": "guard", "n": 3, "from_day": 0}, {"enemy": "sniper", "n": 1, "from_day": 0}, {"enemy": "bomber", "n": 1, "from_day": 3}]
        dg["boss"] = "guard_t4"
    # 6) добыча с роботов: прежние предметы, новые названия
    if "chitin" in items:
        items["chitin"]["name"] = "Обломки брони"
        items["chitin"]["desc"] = "Пластины брони сломанных роботов. Идут на броню и в лабораторию."
    if "goo" in items:
        items["goo"]["name"] = "Машинное масло"
        items["goo"]["desc"] = "Масло из разбитых роботов. Для смазки, топлива и исследований."
    # 7) гнёзд нет: победа — отбить волны
    world.setdefault("nests", {})["count"] = 0
    quests.pop("q_nest", None)
    if "q_win" in quests:
        quests["q_win"]["text"] = "Отбейте 20 волн роботов"
        quests["q_win"]["goal"] = "waves"
        quests["q_win"]["n"] = 20
    if "q_waves" in quests:
        quests["q_waves"]["text"] = "Отбейте 3 волны роботов"
    menu["victory"] = {"mode": "waves", "value": 20}
    # 8) старые модели монстров больше не нужны — убираем, если на них никто не ссылается
    return _drop_unused(models)


OLD_CATS = ("Монстры", "Существа")


def _drop_unused(models):
    """Удаляет модели старых монстров (категория «Монстры: …» и прежние базовые), на которые никто не ссылается.
    Ссылки ищутся вызывающим кодом — здесь только список кандидатов."""
    return [mid for mid, m in models.items() if str(m.get("category", "")).startswith(OLD_CATS)]
