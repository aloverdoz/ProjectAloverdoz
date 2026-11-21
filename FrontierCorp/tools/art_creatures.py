# Подробные монстры с настоящим шагом: голень качается от колена («Шаг»), бедро неподвижно — сустав не разрывается.
# Монстр смотрит вдоль +X. Ноги ходят «треногой»: половина с фазой 0, половина с фазой 0.5.
import math
from art_kit import P, M, shade


def seg(a, top, bottom, r, col, mat="leg", anim="", shape="cylinder", taper=None, seg_n=8):
    """Деталь-отрезок от bottom до top (локальная ось Y смотрит от низа к верху; анимации шага качают вокруг верха)."""
    d = [top[k] - bottom[k] for k in range(3)]
    ln = math.sqrt(sum(v * v for v in d))
    dx, dy, dz = [v / ln for v in d]
    rz = -math.degrees(math.asin(max(-1.0, min(1.0, dx))))
    cz = math.cos(math.radians(rz))
    rx = math.degrees(math.atan2(dz / cz, dy / cz)) if cz > 1e-4 else 0.0
    c = [(top[k] + bottom[k]) / 2 for k in range(3)]
    a.append(P(shape, (r * 2, ln, r * 2), c, col, mat, rot=(rx, 0, rz), anim=anim, seg=seg_n, top=taper))


def leg(a, hip, knee, foot, r, col, claw, phase_b, joint=None):
    """Нога из бедра (неподвижно) и голени (шагает). Шарниры — шары."""
    seg(a, hip, knee, r, col, "leg", taper=None)
    a.append(P("sphere", (r * 2.6, r * 2.6, r * 2.6), knee, joint or shade(col, 1.2), "flesh", seg=8))
    an = "step_b" if phase_b else "step_a"
    seg(a, knee, foot, r * 0.8, shade(col, 0.85), "leg", anim=an, taper=0.5)
    # коготь — тоже качается вместе с голенью (тот же верх — колено)
    seg(a, knee, (foot[0] + 0.06, foot[1] - 0.02, foot[2]), r * 0.45, claw, "flesh", anim=an, shape="cone", taper=None)


def eyes(a, x, y, z, col, n=2, spread=0.12, s=0.08):
    for i in range(n):
        o = -spread * (n - 1) / 2 + i * spread
        a.append(P("sphere", (s, s, s * 0.7), (x, y + (0.03 if i % 2 else 0), z + o), col, "glow", anim="pulse", seg=8))


# ------------------------------------------------------------------ ползун: паук-жук на шести ногах
def crawler(body="#521f6b", shell="#2e0f40", eye="#ff2633", spikes="#cc33ff", s=1.0):
    a = []
    S = lambda v: tuple(x * s for x in v)
    # брюшко из сегментов-пластин
    a.append(P("sphere", S((1.2, 0.7, 1.0)), S((-0.55, 0.62, 0)), body, "flesh", anim="breathe", seg=14))
    for i in range(4):
        a.append(P("sphere", S((1.0 - i * 0.18, 0.18, 0.9 - i * 0.14)), S((-0.35 - i * 0.24, 0.92 - i * 0.04, 0)), shell, "flesh", anim="breathe", seg=12))
    # грудь и голова
    a.append(P("sphere", S((0.75, 0.55, 0.7)), S((0.2, 0.62, 0)), shell, "flesh", anim="bob", seg=12))
    a.append(P("sphere", S((0.5, 0.42, 0.52)), S((0.62, 0.6, 0)), body, "flesh", anim="bob", seg=12))
    eyes(a, 0.84 * s, 0.68 * s, 0, eye, n=4, spread=0.1 * s, s=0.08 * s)
    eyes(a, 0.8 * s, 0.78 * s, 0, eye, n=2, spread=0.2 * s, s=0.06 * s)
    # жвалы
    for z in (-0.12, 0.12):
        a.append(P("cone", S((0.08, 0.32, 0.08)), S((0.92, 0.5, z)), "#e8d8c0", "flesh", rot=(0, 0, -100), anim="jaw"))
    # усики
    for z in (-0.12, 0.12):
        seg(a, S((1.25, 1.2, z * 3)), S((0.75, 0.78, z)), 0.02 * s, shell, "leg", anim="sway")
    # шипы на спине
    for i in range(5):
        a.append(P("prism", S((0.12, 0.3 - i * 0.03, 0.1)), S((-0.2 - i * 0.22, 1.08 - i * 0.05, 0)), spikes, "glow", rot=(0, 0, 20 + i * 4), anim="pulse"))
    # шесть ног
    for k, x in enumerate((0.45, 0.15, -0.2)):
        for side in (-1, 1):
            hip = S((x, 0.6, side * 0.28))
            knee = S((x + 0.1, 1.0, side * 0.82))
            foot = S((x + 0.22 - k * 0.12, 0.0, side * 1.15))
            leg(a, hip, knee, foot, 0.05 * s, "#1a0d1f", "#e8d8c0", (k + (side > 0)) % 2 == 1)
    return a


# ------------------------------------------------------------------ громила: панцирный зверь, ходит на руках-кулаках
def brute(body="#661f0f", shell="#381209", eye="#ff800d", spikes="#ff730d", s=1.0):
    a = []
    S = lambda v: tuple(x * s for x in v)
    a.append(P("sphere", S((1.5, 1.1, 1.3)), S((-0.2, 1.15, 0)), body, "flesh", anim="breathe", seg=16))
    a.append(P("sphere", S((1.3, 0.75, 1.25)), S((-0.25, 1.55, 0)), shell, "flesh", anim="breathe", seg=14))
    for i in range(4):
        a.append(P("sphere", S((0.35, 0.22, 1.1)), S((-0.75 + i * 0.32, 1.78 - abs(i - 1.5) * 0.06, 0)), shade(shell, 0.8), "flesh", anim="breathe", seg=10))
    # голова опущена вперёд, рога и челюсть
    a.append(P("sphere", S((0.62, 0.55, 0.62)), S((0.68, 1.05, 0)), body, "flesh", anim="bob", seg=12))
    a.append(P("box", S((0.4, 0.16, 0.5)), S((0.86, 0.86, 0)), shell, "flesh", anim="jaw"))
    for z in (-0.18, 0.18):
        a.append(P("cone", S((0.06, 0.14, 0.06)), S((0.98, 0.98, z)), "#f2ead8", "flesh", rot=(0, 0, -90)))
        a.append(P("cone", S((0.12, 0.55, 0.12)), S((0.82, 1.38, z * 2.2)), "#e8e0cc", "flesh", rot=(z * 120, 0, -30), seg=8))
    eyes(a, 0.97 * s, 1.12 * s, 0, eye, n=2, spread=0.22 * s, s=0.09 * s)
    for i in range(6):
        a.append(P("cone", S((0.16, 0.42, 0.16)), S((-0.75 + i * 0.22, 1.98, 0)), spikes, "glow", rot=(0, 0, 15), anim="pulse", seg=6))
    # передние лапы-руки: толстое плечо, предплечье шагает
    for side in (-1, 1):
        ph = side > 0
        hip = S((0.3, 1.35, side * 0.6))
        knee = S((0.55, 0.85, side * 0.9))
        foot = S((0.72, 0.0, side * 0.92))
        seg(a, hip, knee, 0.2 * s, body, "flesh")
        a.append(P("sphere", S((0.42, 0.42, 0.42)), knee, shell, "flesh", seg=10))
        an = "step_b" if ph else "step_a"
        seg(a, knee, foot, 0.17 * s, shade(body, 0.9), "flesh", anim=an, taper=0.8)
        seg(a, knee, (foot[0] + 0.05 * s, 0.0, foot[2]), 0.24 * s, shell, "flesh", anim=an, shape="sphere")
    # задние короткие лапы
    for side in (-1, 1):
        hip = S((-0.75, 0.9, side * 0.5))
        knee = S((-0.85, 0.5, side * 0.68))
        foot = S((-0.7, 0.0, side * 0.7))
        leg(a, hip, knee, foot, 0.13 * s, body, "#e8e0cc", side < 0, joint=shell)
    return a


# ------------------------------------------------------------------ плевун: раздутый клещ с кислотным мешком
def spitter(body="#1f6b3d", shell="#0f402a", eye="#ccff33", spikes="#66ff33", s=1.0):
    a = []
    S = lambda v: tuple(x * s for x in v)
    a.append(P("sphere", S((1.2, 0.8, 1.1)), S((-0.2, 0.7, 0)), body, "flesh", anim="breathe", seg=14))
    a.append(P("sphere", S((0.95, 0.85, 0.9)), S((-0.45, 1.2, 0)), "#b8ff4d", "glass", anim="breathe", seg=14))
    a.append(P("sphere", S((0.6, 0.55, 0.55)), S((-0.45, 1.2, 0)), spikes, "glow", anim="pulse", seg=10))
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.append(P("torus", S((0.95, 0.12, 0.95)), S((-0.45, 0.9 + i * 0.1, 0)), shell, "flesh", anim="breathe", seg=14)) if i in (0, 3) else None
    a.append(P("sphere", S((0.5, 0.45, 0.5)), S((0.45, 0.72, 0)), shell, "flesh", anim="bob", seg=12))
    # хобот-плевалка
    seg(a, S((0.62, 0.8, 0)), S((1.05, 0.95, 0)), 0.09 * s, body, "flesh", anim="bob", taper=0.7)
    a.append(P("torus", S((0.22, 0.25, 0.22)), S((1.05, 0.95, 0)), spikes, "glow", rot=(0, 0, 70), anim="pulse", seg=10))
    eyes(a, 0.66 * s, 0.85 * s, 0, eye, n=3, spread=0.12 * s, s=0.07 * s)
    for i in range(7):
        ang = math.pi * i / 6
        a.append(P("cone", S((0.08, 0.22, 0.08)), S((-0.45 + math.cos(ang) * 0.3, 1.62, math.sin(ang) * 0.3 - 0.15)), spikes, "glow", anim="pulse", seg=6))
    for k, x in enumerate((0.3, 0.0, -0.35)):
        for side in (-1, 1):
            hip = S((x, 0.6, side * 0.42))
            knee = S((x + 0.05, 0.85, side * 0.85))
            foot = S((x + 0.15 - k * 0.1, 0.0, side * 1.05))
            leg(a, hip, knee, foot, 0.05 * s, "#0f2a1a", "#d8f0c0", (k + (side > 0)) % 2 == 1)
    return [p for p in a if p]


# ------------------------------------------------------------------ бегун: двуногий ящер с хвостом
def runner(body="#6b5c1f", shell="#40360f", eye="#ff3333", spikes="#ffcc33", s=1.0):
    a = []
    S = lambda v: tuple(x * s for x in v)
    seg(a, S((0.45, 1.18, 0)), S((-0.5, 1.0, 0)), 0.3 * s, body, "flesh", anim="bob", shape="capsule")
    a.append(P("sphere", S((0.62, 0.5, 0.5)), S((0.1, 1.02, 0)), shade(body, 1.15), "flesh", anim="bob", seg=12))
    seg(a, S((0.8, 1.58, 0)), S((0.35, 1.15, 0)), 0.13 * s, body, "flesh", anim="bob", shape="capsule")
    seg(a, S((1.22, 1.56, 0)), S((0.72, 1.64, 0)), 0.17 * s, shell, "flesh", anim="bob", shape="capsule")
    a.append(P("box", S((0.42, 0.07, 0.2)), S((1.02, 1.47, 0)), shell, "flesh", anim="jaw"))
    for i in range(5):
        a.append(P("cone", S((0.04, 0.08, 0.04)), S((0.88 + i * 0.07, 1.5, 0.08)), "#f2ead8", "flesh", rot=(0, 0, 180), seg=4))
    eyes(a, 1.0 * s, 1.72 * s, 0, eye, n=2, spread=0.2 * s, s=0.07 * s)
    # хвост из трёх кусков, машет
    for i in range(3):
        a.append(P("cone", S((0.34 - i * 0.08, 0.5, 0.3 - i * 0.07)), S((-0.75 - i * 0.4, 1.02 + i * 0.06, 0)), body if i % 2 == 0 else shell, "flesh",
                   rot=(0, 0, 95), anim="tail", seg=8))
    for i in range(6):
        a.append(P("prism", S((0.08, 0.2, 0.06)), S((0.5 - i * 0.25, 1.32 - i * 0.02, 0)), spikes, "glow", anim="pulse", rot=(0, 0, 15)))
    # мощные ноги: бедро, голень с шагом, ступня
    for side in (-1, 1):
        ph = side > 0
        hip = S((-0.05, 0.95, side * 0.25))
        knee = S((0.2, 0.55, side * 0.32))
        foot = S((-0.1, 0.0, side * 0.32))
        seg(a, hip, knee, 0.14 * s, body, "flesh")
        a.append(P("sphere", S((0.22, 0.22, 0.22)), knee, shell, "flesh", seg=8))
        an = "step_b" if ph else "step_a"
        seg(a, knee, foot, 0.08 * s, shade(body, 0.85), "leg", anim=an)
        seg(a, knee, (foot[0] + 0.22 * s, 0.0, foot[2]), 0.06 * s, "#e8d8c0", "flesh", anim=an, shape="cone")
    # лапки-ручки
    for side in (-1, 1):
        seg(a, S((0.55, 1.25, side * 0.18)), S((0.75, 0.95, side * 0.22)), 0.04 * s, shell, "leg", anim="step_b" if side < 0 else "step_a")
    return a


ANIMS = {
    "step_a": {"name": "Шаг (первая нога)", "type": "step", "speed": 11.0, "amount": 0.45, "always": False, "phase": 0.0},
    "step_b": {"name": "Шаг (вторая нога)", "type": "step", "speed": 11.0, "amount": 0.45, "always": False, "phase": 0.5},
    "jaw": {"name": "Челюсть", "type": "swing", "speed": 6.0, "amount": 0.25, "always": True},
    "tail": {"name": "Хвост", "type": "sway", "speed": 3.0, "amount": 0.25, "always": True},
}


def all_models():
    return {
        "crawler": M("Ползун", crawler(), "Монстры"),
        "brute": M("Громила", brute(s=1.25), "Монстры"),
        "spitter": M("Плевун", spitter(s=1.15), "Монстры"),
        "runner": M("Бегун", runner(s=0.85), "Монстры"),
    }
