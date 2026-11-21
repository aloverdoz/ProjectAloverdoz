# Монстры и люди со скелетом. Каждая деталь привязана к кости (role "b:имя"), у модели есть "rig":
# кости (родитель и точка вращения), ноги (бедро, колено, фаза шага, стиль), голова, челюсти, хвосты и усики,
# дыхание и параметры походки. Игра двигает кости сама: шаги в такт скорости (ноги не скользят),
# перенос веса, наклоны на поворотах, замах и удар, вздрагивание от урона и падение при смерти.
# Монстр смотрит вдоль +X, вверх — Y, бока — Z.
import math
from art_kit import P, M, shade


def seg(top, bottom, r, col, mat="leg", shape="cylinder", taper=None, n=8, anim=""):
    """Деталь-отрезок от bottom до top."""
    d = [top[k] - bottom[k] for k in range(3)]
    ln = math.sqrt(sum(v * v for v in d)) or 1e-3
    dx, dy, dz = [v / ln for v in d]
    rz = -math.degrees(math.asin(max(-1.0, min(1.0, dx))))
    cz = math.cos(math.radians(rz))
    rx = math.degrees(math.atan2(dz / cz, dy / cz)) if cz > 1e-4 else 0.0
    c = [(top[k] + bottom[k]) / 2 for k in range(3)]
    return P(shape, (r * 2, ln, r * 2), c, col, mat, rot=(rx, 0, rz), seg=n, top=taper, anim=anim)


def lerp3(a, b, t):
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


class Rig:
    def __init__(self, scale=1.0):
        self.s = scale
        self.bones = []
        self.parts = []
        self.legs = []
        self.arms = []
        self.jaws = []
        self.chains = []
        self.breath = []
        self.head = ""
        self.body = ""

    def S(self, v):
        return tuple(x * self.s for x in v)

    def bone(self, name, parent, pivot):
        self.bones.append({"name": name, "parent": parent, "pivot": [round(v * self.s, 3) for v in pivot]})
        return name

    def add(self, bone, part):
        part["role"] = bone
        # размеры и положение — в масштабе модели
        part["pos"] = [round(v * self.s, 3) for v in part["pos"]]
        part["size"] = [round(v * self.s, 3) for v in part["size"]]
        self.parts.append(part)

    def seg(self, bone, top, bottom, r, col, mat="leg", **kw):
        self.add(bone, seg(top, bottom, r, col, mat, **kw))

    def rig(self, gait):
        return {"bones": self.bones, "legs": self.legs, "arms": self.arms, "jaws": self.jaws, "chains": self.chains,
                "breath": self.breath, "head": self.head, "body": self.body, "gait": gait}


def eyes(R, bone, x, y, z, col, n=2, spread=0.12, s=0.08, rows=1):
    for r in range(rows):
        for i in range(n):
            o = -spread * (n - 1) / 2 + i * spread
            R.add(bone, P("sphere", (s, s, s * 0.7), (x - r * 0.04, y + r * 0.07, z + o), col, "glow", anim="pulse", seg=8))
            R.add(bone, P("torus", (s * 1.3, s * 0.5, s * 1.3), (x - 0.01 - r * 0.04, y + r * 0.07, z + o), "#140a10", "dark", rot=(0, 0, 90), seg=8))


def hairs(R, bone, a, b, col, n=4, L=0.08, r=0.008):
    """Щетинки вдоль сегмента ноги."""
    for i in range(n):
        p = lerp3(a, b, (i + 0.5) / n)
        R.seg(bone, (p[0] + L * 0.3, p[1] + L, p[2] + (L * 0.5 if i % 2 else -L * 0.5)), p, r, col, "dark", n=4)


def insect_leg(R, name, body, hip, knee, foot, r, col, claw, phase, side, armor):
    h = R.bone("b:hip" + name, body, hip)
    k = R.bone("b:knee" + name, h, knee)
    R.seg(h, knee, hip, r, col, "leg", n=8)
    R.add(h, P("sphere", (r * 2.6, r * 2.6, r * 2.6), hip, shade(col, 1.2), "flesh", seg=8))
    R.seg(h, lerp3(hip, knee, 0.75), lerp3(hip, knee, 0.25), r * 1.35, armor, "flesh", n=8)
    R.add(k, P("sphere", (r * 2.5, r * 2.5, r * 2.5), knee, shade(col, 1.3), "flesh", seg=8))
    mid = lerp3(knee, foot, 0.55)
    R.seg(k, mid, knee, r * 0.9, shade(col, 0.9), "leg", n=8)
    R.add(k, P("sphere", (r * 1.9, r * 1.9, r * 1.9), mid, armor, "flesh", seg=8))
    R.seg(k, foot, mid, r * 0.7, shade(col, 0.8), "leg", taper=0.4, n=8)
    R.seg(k, (foot[0] + 0.07, foot[1] - 0.01, foot[2]), (foot[0], foot[1] + 0.05, foot[2]), r * 0.45, claw, "flesh", shape="cone", n=6)
    hairs(R, h, hip, knee, shade(col, 0.6), 4)
    hairs(R, k, knee, foot, shade(col, 0.6), 5)
    R.legs.append({"hip": h, "knee": k, "phase": phase, "side": side, "style": "y"})


def crawler(body="#521f6b", shell="#2e0f40", eye="#ff2633", spikes="#cc33ff", s=1.0):
    """Ползун: паук-жук. Брюшко дышит, жвалы щёлкают, усики качаются, шесть ног ходят треногой."""
    R = Rig(s)
    R.body = R.bone("b:body", "", (0.15, 0.65, 0))
    abd = R.bone("b:abd", R.body, (-0.15, 0.7, 0))
    R.head = R.bone("b:head", R.body, (0.48, 0.62, 0))
    R.breath = [abd]
    # брюшко: ядро, пластины, светящиеся метки, паутинные бородавки
    R.add(abd, P("sphere", (1.25, 0.75, 1.05), (-0.62, 0.66, 0), body, "flesh", seg=16))
    for i in range(7):
        R.add(abd, P("sphere", (1.05 - i * 0.12, 0.2, 0.95 - i * 0.1), (-0.25 - i * 0.16, 0.98 - i * 0.03 - (i * i) * 0.006, 0), shell, "flesh", seg=12))
    for i in range(6):
        R.add(abd, P("sphere", (0.09, 0.04, 0.09), (-0.4 - i * 0.14, 1.06 - i * 0.02, (0.16 if i % 2 else -0.16)), spikes, "glow", anim="pulse", seg=8))
    for i in range(5):
        R.add(abd, P("cone", (0.1, 0.32 - i * 0.03, 0.1), (-0.25 - i * 0.2, 1.18 - i * 0.04, 0), spikes, "glow", rot=(0, 0, 20 + i * 5), anim="pulse", seg=6))
    for z in (-0.08, 0.08):
        R.add(abd, P("cone", (0.08, 0.16, 0.08), (-1.24, 0.6, z), shade(body, 0.7), "flesh", rot=(0, 0, 100), seg=6))
    for i in range(4):
        R.add(abd, P("torus", (0.9 - i * 0.12, 0.08, 0.85 - i * 0.1), (-0.45 - i * 0.18, 0.62, 0), shade(shell, 1.2), "flesh", rot=(0, 0, 90), seg=14))
    # грудь
    R.add(R.body, P("sphere", (0.78, 0.56, 0.72), (0.18, 0.64, 0), shell, "flesh", seg=14))
    R.add(R.body, P("sphere", (0.62, 0.22, 0.6), (0.16, 0.9, 0), shade(shell, 1.25), "flesh", seg=12))
    for i in range(3):
        R.add(R.body, P("cone", (0.07, 0.18, 0.07), (0.02 + i * 0.16, 1.02, 0), spikes, "glow", rot=(0, 0, 15), anim="pulse", seg=6))
    # голова: глаза в два ряда, жвалы с зубцами, щупики
    R.add(R.head, P("sphere", (0.52, 0.44, 0.54), (0.62, 0.62, 0), body, "flesh", seg=14))
    R.add(R.head, P("sphere", (0.4, 0.16, 0.44), (0.62, 0.84, 0), shell, "flesh", seg=12))
    eyes(R, R.head, 0.86, 0.68, 0, eye, n=4, spread=0.09, s=0.07, rows=2)
    for side in (-1, 1):
        j = R.bone("b:jaw" + ("l" if side < 0 else "r"), R.head, (0.8, 0.52, side * 0.1))
        R.jaws.append({"bone": j, "axis": "y", "open": 28 * -side})
        R.seg(j, (1.08, 0.46, side * 0.04), (0.8, 0.52, side * 0.12), 0.045, "#e8d8c0", "flesh", shape="cone", taper=None, n=6)
        for t in range(4):
            p = lerp3((0.8, 0.52, side * 0.12), (1.08, 0.46, side * 0.04), 0.2 + t * 0.2)
            R.add(j, P("cone", (0.025, 0.06, 0.025), (p[0], p[1] - 0.02, p[2] - side * 0.03), "#fff2dc", "flesh", rot=(side * 90, 0, 0), seg=4))
        # щупики-педипальпы
        pa = R.bone("b:palp" + ("l" if side < 0 else "r"), R.head, (0.82, 0.58, side * 0.2))
        R.seg(pa, (1.0, 0.7, side * 0.28), (0.82, 0.58, side * 0.2), 0.025, shell, "leg")
        R.seg(pa, (1.12, 0.6, side * 0.3), (1.0, 0.7, side * 0.28), 0.02, shell, "leg")
        R.add(pa, P("sphere", (0.05, 0.05, 0.05), (1.12, 0.6, side * 0.3), spikes, "glow", anim="pulse", seg=6))
        R.chains.append({"bones": [pa], "axis": "z", "amp": 14, "speed": 5.0})
        # усики из трёх звеньев
        prev = R.head
        base = (0.78, 0.8, side * 0.1)
        chain = []
        for t in range(3):
            tip = (base[0] + 0.18, base[1] + 0.16 - t * 0.04, base[2] + side * 0.12)
            b = R.bone("b:ant" + ("l" if side < 0 else "r") + str(t), prev, base)
            R.seg(b, tip, base, 0.018 - t * 0.004, shell, "leg", n=5)
            chain.append(b)
            prev, base = b, tip
        R.chains.append({"bones": chain, "axis": "y", "amp": 12, "speed": 3.0})
    # шесть ног, «тренога»: одна сторона передняя и задняя + другая средняя
    for k, x in enumerate((0.42, 0.16, -0.14)):
        for side in (-1, 1):
            hip = (x, 0.6, side * 0.3)
            knee = (x + 0.12 - k * 0.08, 1.05, side * 0.88)
            foot = (x + 0.26 - k * 0.2, 0.0, side * 1.25)
            ph = 0.5 if (k + (side > 0)) % 2 else 0.0
            insect_leg(R, "%d%s" % (k, "l" if side < 0 else "r"), R.body, hip, knee, foot, 0.052, "#1a0d1f", "#e8d8c0", ph, side, shade(shell, 1.1))
    return R, {"stride": 1.0, "swing": 26, "lift": 24, "knee": 18, "bob": 0.04, "roll": 3, "duty": 0.55, "lean": 6}


def spitter(body="#1f6b3d", shell="#0f402a", eye="#ccff33", spikes="#66ff33", s=1.0):
    """Плевун: раздутый клещ с кислотным мешком (мешок дышит и вздувается перед плевком)."""
    R = Rig(s)
    R.body = R.bone("b:body", "", (0.0, 0.7, 0))
    sac = R.bone("b:sac", R.body, (-0.35, 0.95, 0))
    R.head = R.bone("b:head", R.body, (0.4, 0.72, 0))
    R.breath = [sac]
    R.add(R.body, P("sphere", (1.25, 0.82, 1.1), (-0.2, 0.7, 0), body, "flesh", seg=16))
    for i in range(5):
        R.add(R.body, P("torus", (1.15 - i * 0.12, 0.1, 1.05 - i * 0.1), (-0.2 - i * 0.05, 0.5 + i * 0.1, 0), shell, "flesh", seg=16))
    R.add(sac, P("sphere", (0.98, 0.88, 0.92), (-0.45, 1.22, 0), "#b8ff4d", "glass", seg=16))
    R.add(sac, P("sphere", (0.62, 0.56, 0.56), (-0.45, 1.2, 0), spikes, "glow", anim="pulse", seg=12))
    for i in range(8):
        a = i * math.pi / 4
        R.add(sac, P("cylinder", (0.03, 0.7, 0.03), (-0.45 + math.cos(a) * 0.46, 1.2, math.sin(a) * 0.44), "#1f5a2a", "flesh", rot=(math.degrees(math.sin(a)) * 0.5, 0, math.degrees(math.cos(a)) * 0.5), seg=5))
    for i in range(7):
        ang = math.pi * i / 6
        R.add(sac, P("cone", (0.08, 0.24, 0.08), (-0.45 + math.cos(ang) * 0.3, 1.66, math.sin(ang) * 0.3 - 0.15), spikes, "glow", anim="pulse", seg=6))
    R.add(R.head, P("sphere", (0.52, 0.46, 0.52), (0.48, 0.72, 0), shell, "flesh", seg=14))
    eyes(R, R.head, 0.7, 0.86, 0, eye, n=3, spread=0.11, s=0.07)
    # хобот-плевалка из двух звеньев с кольцами
    t1 = R.bone("b:trunk0", R.head, (0.62, 0.8, 0))
    t2 = R.bone("b:trunk1", t1, (0.86, 0.88, 0))
    R.seg(t1, (0.86, 0.88, 0), (0.62, 0.8, 0), 0.1, body, "flesh", taper=0.85)
    R.seg(t2, (1.1, 0.95, 0), (0.86, 0.88, 0), 0.085, body, "flesh", taper=0.7)
    for i in range(3):
        R.add(t1 if i < 2 else t2, P("torus", (0.22, 0.12, 0.22), lerp3((0.66, 0.81, 0), (1.06, 0.94, 0), i / 2.5), shell, "flesh", rot=(0, 0, 70), seg=10))
    R.add(t2, P("torus", (0.24, 0.24, 0.24), (1.1, 0.95, 0), spikes, "glow", rot=(0, 0, 70), anim="pulse", seg=10))
    R.chains.append({"bones": [t1, t2], "axis": "z", "amp": 8, "speed": 2.0})
    R.jaws.append({"bone": t1, "axis": "z", "open": 22})
    for k, x in enumerate((0.3, 0.0, -0.35)):
        for side in (-1, 1):
            hip = (x, 0.6, side * 0.45)
            knee = (x + 0.06, 0.9, side * 0.9)
            foot = (x + 0.16 - k * 0.12, 0.0, side * 1.1)
            ph = 0.5 if (k + (side > 0)) % 2 else 0.0
            insect_leg(R, "%d%s" % (k, "l" if side < 0 else "r"), R.body, hip, knee, foot, 0.05, "#0f2a1a", "#d8f0c0", ph, side, shade(shell, 1.2))
    return R, {"stride": 0.9, "swing": 22, "lift": 20, "knee": 14, "bob": 0.05, "roll": 4, "duty": 0.6, "lean": 4}


def brute(body="#661f0f", shell="#381209", eye="#ff800d", spikes="#ff730d", s=1.0):
    """Громила: ходит на руках-кулаках, как горилла. Тяжёлая походка, панцирь, рога, челюсть."""
    R = Rig(s)
    R.body = R.bone("b:body", "", (-0.2, 1.15, 0))
    R.head = R.bone("b:head", R.body, (0.5, 1.15, 0))
    back = R.bone("b:back", R.body, (-0.3, 1.5, 0))
    R.breath = [back]
    R.add(R.body, P("sphere", (1.55, 1.15, 1.35), (-0.2, 1.15, 0), body, "flesh", seg=18))
    R.add(R.body, P("sphere", (1.0, 0.7, 1.1), (-0.65, 0.95, 0), shade(body, 0.9), "flesh", seg=14))
    for i in range(6):
        R.add(R.body, P("box", (0.12, 0.06, 0.5), (0.25 - i * 0.14, 0.62, 0), shade(body, 1.2), "flesh", rot=(0, 0, 10)))
    R.add(back, P("sphere", (1.35, 0.78, 1.28), (-0.25, 1.58, 0), shell, "flesh", seg=16))
    for i in range(5):
        R.add(back, P("sphere", (0.36, 0.24, 1.15), (-0.8 + i * 0.28, 1.82 - abs(i - 2) * 0.06, 0), shade(shell, 0.8), "flesh", seg=12))
    for i in range(7):
        R.add(back, P("cone", (0.17, 0.48 - abs(i - 3) * 0.05, 0.17), (-0.85 + i * 0.22, 2.02, (0.06 if i % 2 else -0.06)), spikes, "glow", rot=(0, 0, 15), anim="pulse", seg=6))
    for side in (-1, 1):
        for i in range(4):
            R.add(back, P("cone", (0.1, 0.26, 0.1), (-0.7 + i * 0.3, 1.62, side * 0.62), shade(shell, 1.3), "flesh", rot=(side * 60, 0, 0), seg=6))
    R.add(R.head, P("sphere", (0.66, 0.58, 0.66), (0.72, 1.06, 0), body, "flesh", seg=14))
    R.add(R.head, P("sphere", (0.5, 0.2, 0.6), (0.7, 1.32, 0), shell, "flesh", seg=12))
    eyes(R, R.head, 1.0, 1.14, 0, eye, n=2, spread=0.22, s=0.09)
    for z in (-0.18, 0.18):
        R.add(R.head, P("cone", (0.13, 0.6, 0.13), (0.84, 1.42, z * 2.3), "#e8e0cc", "flesh", rot=(z * 130, 0, -30), seg=8))
        R.add(R.head, P("torus", (0.18, 0.1, 0.18), (0.8, 1.24, z * 2.0), shell, "flesh", rot=(z * 130, 0, -30), seg=8))
    jaw = R.bone("b:jaw", R.head, (0.62, 0.92, 0))
    R.jaws.append({"bone": jaw, "axis": "z", "open": -26})
    R.add(jaw, P("box", (0.46, 0.16, 0.52), (0.88, 0.86, 0), shell, "flesh"))
    for z in (-0.18, -0.06, 0.06, 0.18):
        R.add(jaw, P("cone", (0.06, 0.16, 0.06), (1.04, 0.98, z), "#f2ead8", "flesh", seg=5))
    for z in (-0.2, 0.2):
        R.add(R.head, P("cone", (0.06, 0.14, 0.06), (1.0, 0.96, z), "#f2ead8", "flesh", rot=(0, 0, 180), seg=5))
    # передние лапы-руки (кулаки) и короткие задние
    for side in (-1, 1):
        sd = "l" if side < 0 else "r"
        sh = R.bone("b:hipF" + sd, R.body, (0.3, 1.35, side * 0.62))
        el = R.bone("b:kneeF" + sd, sh, (0.55, 0.82, side * 0.92))
        R.seg(sh, (0.55, 0.82, side * 0.92), (0.3, 1.35, side * 0.62), 0.22, body, "flesh")
        R.add(sh, P("sphere", (0.5, 0.5, 0.5), (0.3, 1.35, side * 0.62), shell, "flesh", seg=12))
        R.add(el, P("sphere", (0.42, 0.42, 0.42), (0.55, 0.82, side * 0.92), shell, "flesh", seg=10))
        R.seg(el, (0.7, 0.1, side * 0.94), (0.55, 0.82, side * 0.92), 0.18, shade(body, 0.9), "flesh", taper=0.8)
        R.add(el, P("sphere", (0.46, 0.34, 0.46), (0.72, 0.12, side * 0.94), shell, "flesh", seg=12))
        for f in range(3):
            R.add(el, P("cone", (0.07, 0.16, 0.07), (0.92, 0.06, side * 0.94 + (f - 1) * 0.12), "#e8e0cc", "flesh", rot=(0, 0, -100), seg=5))
        R.legs.append({"hip": sh, "knee": el, "phase": 0.0 if side < 0 else 0.5, "side": side, "style": "z"})
        hp = R.bone("b:hipB" + sd, R.body, (-0.75, 0.9, side * 0.5))
        kn = R.bone("b:kneeB" + sd, hp, (-0.86, 0.48, side * 0.68))
        R.seg(hp, (-0.86, 0.48, side * 0.68), (-0.75, 0.9, side * 0.5), 0.15, body, "flesh")
        R.add(kn, P("sphere", (0.26, 0.26, 0.26), (-0.86, 0.48, side * 0.68), shell, "flesh", seg=10))
        R.seg(kn, (-0.72, 0.04, side * 0.7), (-0.86, 0.48, side * 0.68), 0.12, shade(body, 0.85), "flesh", taper=0.8)
        R.add(kn, P("sphere", (0.3, 0.14, 0.26), (-0.68, 0.05, side * 0.7), shell, "flesh", seg=10))
        R.legs.append({"hip": hp, "knee": kn, "phase": 0.5 if side < 0 else 0.0, "side": side, "style": "z"})
    return R, {"stride": 1.6, "swing": 24, "lift": 0, "knee": 30, "bob": 0.12, "roll": 6, "duty": 0.62, "lean": 8}


def runner(body="#6b5c1f", shell="#40360f", eye="#ff3333", spikes="#ffcc33", s=1.0):
    """Бегун: двуногий ящер. Бег с наклоном корпуса, хвост-противовес, пасть открывается на бегу."""
    R = Rig(s)
    R.body = R.bone("b:body", "", (0.0, 1.0, 0))
    neck = R.bone("b:neck", R.body, (0.4, 1.15, 0))
    R.head = R.bone("b:head", neck, (0.75, 1.55, 0))
    R.seg(R.body, (0.45, 1.18, 0), (-0.5, 1.0, 0), 0.3, body, "flesh", shape="capsule", n=14)
    R.add(R.body, P("sphere", (0.64, 0.52, 0.52), (0.1, 1.02, 0), shade(body, 1.15), "flesh", seg=14))
    for i in range(6):
        R.add(R.body, P("prism", (0.08, 0.22, 0.06), (0.5 - i * 0.2, 1.32 - i * 0.02, 0), spikes, "glow", anim="pulse", rot=(0, 0, 15)))
    for i in range(5):
        R.add(R.body, P("box", (0.1, 0.04, 0.36), (0.3 - i * 0.16, 0.78, 0), shade(body, 1.3), "flesh"))
    R.seg(neck, (0.8, 1.58, 0), (0.35, 1.15, 0), 0.13, body, "flesh", shape="capsule", n=12)
    for i in range(3):
        R.add(neck, P("prism", (0.06, 0.14, 0.05), (0.45 + i * 0.12, 1.36 + i * 0.1, 0), spikes, "glow", anim="pulse", rot=(0, 0, 40)))
    R.seg(R.head, (1.24, 1.56, 0), (0.72, 1.64, 0), 0.17, shell, "flesh", shape="capsule", n=12)
    R.add(R.head, P("sphere", (0.18, 0.08, 0.22), (0.86, 1.78, 0), shade(shell, 1.3), "flesh", seg=8))
    eyes(R, R.head, 1.0, 1.72, 0, eye, n=2, spread=0.2, s=0.07)
    for i in range(6):
        R.add(R.head, P("cone", (0.035, 0.07, 0.035), (0.9 + i * 0.065, 1.5, (0.08 if i % 2 else -0.08)), "#f2ead8", "flesh", rot=(0, 0, 180), seg=4))
    jaw = R.bone("b:jaw", R.head, (0.78, 1.52, 0))
    R.jaws.append({"bone": jaw, "axis": "z", "open": -30})
    R.add(jaw, P("box", (0.44, 0.07, 0.2), (1.02, 1.47, 0), shell, "flesh"))
    for i in range(5):
        R.add(jaw, P("cone", (0.03, 0.06, 0.03), (0.88 + i * 0.07, 1.52, (0.07 if i % 2 else -0.07)), "#f2ead8", "flesh", seg=4))
    # хвост — цепочка из четырёх костей
    prev, base = R.body, (-0.45, 1.02, 0)
    chain = []
    for i in range(4):
        tip = (base[0] - 0.42, base[1] + 0.03, 0)
        b = R.bone("b:tail%d" % i, prev, base)
        R.seg(b, tip, base, 0.17 - i * 0.035, body if i % 2 == 0 else shell, "flesh", shape="cone" if i == 3 else "capsule", n=10)
        R.add(b, P("prism", (0.06, 0.14 - i * 0.02, 0.05), lerp3(base, tip, 0.5)[:1] + (base[1] + 0.16 - i * 0.03,) + (0,), spikes, "glow", anim="pulse", rot=(0, 0, 20)))
        chain.append(b)
        prev, base = b, tip
    R.chains.append({"bones": chain, "axis": "y", "amp": 12, "speed": 4.0, "follow": True})
    # ноги: бедро, голень, ступня с когтями
    for side in (-1, 1):
        sd = "l" if side < 0 else "r"
        h = R.bone("b:hip" + sd, R.body, (-0.05, 0.95, side * 0.25))
        k = R.bone("b:knee" + sd, h, (0.2, 0.55, side * 0.32))
        R.seg(h, (0.2, 0.55, side * 0.32), (-0.05, 0.95, side * 0.25), 0.15, body, "flesh", n=10)
        R.add(h, P("sphere", (0.36, 0.4, 0.34), (-0.02, 0.9, side * 0.27), shade(body, 1.1), "flesh", seg=12))
        R.add(k, P("sphere", (0.23, 0.23, 0.23), (0.2, 0.55, side * 0.32), shell, "flesh", seg=8))
        R.seg(k, (-0.1, 0.08, side * 0.32), (0.2, 0.55, side * 0.32), 0.08, shade(body, 0.85), "leg", n=8)
        for f in (-1, 0, 1):
            R.seg(k, (0.16, 0.02, side * 0.32 + f * 0.07), (-0.1, 0.06, side * 0.32), 0.035, "#e8d8c0", "flesh", shape="cone", n=5)
        R.legs.append({"hip": h, "knee": k, "phase": 0.0 if side < 0 else 0.5, "side": side, "style": "z"})
        a = R.bone("b:arm" + sd, R.body, (0.55, 1.25, side * 0.18))
        R.seg(a, (0.75, 0.95, side * 0.22), (0.55, 1.25, side * 0.18), 0.045, shell, "leg")
        for f in (-1, 1):
            R.seg(a, (0.86, 0.9, side * 0.22 + f * 0.04), (0.75, 0.95, side * 0.22), 0.02, "#e8d8c0", "flesh", shape="cone", n=4)
        R.arms.append({"bone": a, "phase": 0.5 if side < 0 else 0.0, "amp": 30})
    return R, {"stride": 1.7, "swing": 34, "lift": 0, "knee": 55, "bob": 0.07, "roll": 5, "duty": 0.42, "lean": 14}


def worm(body="#7a5a3e", shell="#4a3423", eye="#ffb21a", spikes="#e8d8b0", s=1.0):
    """Земляной червь: роет под землёй, вылезает передней частью и бьёт. Тело — цепочка колец, пасть-воронка с зубами."""
    R = Rig(s)
    R.body = R.bone("b:body", "", (0.0, 0.5, 0))
    # передняя часть поднята «свечой»: три кости вверх и вперёд
    prev, base = R.body, (0.0, 0.5, 0)
    up = []
    for i in range(3):
        tip = (base[0] + 0.22, base[1] + 0.45, 0)
        b = R.bone("b:rise%d" % i, prev, base)
        R.seg(b, lerp3(base, tip, 1.35), lerp3(base, tip, -0.3), 0.42 - i * 0.03, body if i % 2 == 0 else shade(body, 0.85), "flesh", shape="cylinder", n=14)
        for k in range(10):
            a = k / 10.0 * math.tau
            R.add(b, P("box", (0.05, 0.12, 0.18), (lerp3(base, tip, 0.5)[0] + math.cos(a) * (0.4 - i * 0.03), lerp3(base, tip, 0.5)[1], math.sin(a) * (0.4 - i * 0.03)), shell, "flesh", rot=(0, -math.degrees(a), 0)))
        up.append(b)
        prev, base = b, tip
    R.head = R.bone("b:head", prev, base)
    R.breath = [up[0]]
    hx, hy = base[0] + 0.12, base[1] + 0.2
    R.add(R.head, P("cylinder", (0.84, 0.36, 0.84), (hx, hy, 0), shade(body, 1.1), "flesh", seg=18, top=0.75))
    R.add(R.head, P("torus", (0.86, 0.22, 0.86), (hx, hy + 0.18, 0), shell, "flesh", seg=18))
    R.add(R.head, P("cylinder", (0.6, 0.06, 0.6), (hx, hy + 0.16, 0), "#2a0c0c", "dark", seg=16))
    for ring, rad, n in ((0, 0.34, 14), (1, 0.24, 10), (2, 0.14, 7)):
        for k in range(n):
            a = (k + ring * 0.5) / n * math.tau
            R.add(R.head, P("cone", (0.05, 0.14 - ring * 0.02, 0.05), (hx + math.cos(a) * rad, hy + 0.16 - ring * 0.05, math.sin(a) * rad), spikes, "flesh", rot=(math.degrees(math.sin(a)) * 0.5, 0, -math.degrees(math.cos(a)) * 0.5), seg=5))
    for k in range(6):
        a = k / 6.0 * math.tau
        eyes(R, R.head, hx + math.cos(a) * 0.4, hy - 0.05, math.sin(a) * 0.4, eye, n=1, s=0.06)
    # четыре челюсти-лепестка раскрываются при ударе
    for k in range(4):
        a = k / 4.0 * math.tau + 0.4
        jx, jz = hx + math.cos(a) * 0.38, math.sin(a) * 0.38
        j = R.bone("b:jaw%d" % k, R.head, (jx, hy + 0.15, jz))
        R.jaws.append({"bone": j, "axis": "z" if k % 2 == 0 else "x", "open": 35 if k < 2 else -35})
        R.seg(j, (hx + math.cos(a) * 0.5, hy + 0.55, math.sin(a) * 0.5), (jx, hy + 0.15, jz), 0.07, shell, "flesh", shape="cone", n=8)
        for t in range(3):
            R.add(j, P("cone", (0.03, 0.08, 0.03), (hx + math.cos(a) * (0.4 + t * 0.03), hy + 0.25 + t * 0.1, math.sin(a) * (0.4 + t * 0.03)), spikes, "flesh", seg=4))
    # хвост тянется по земле — цепочка колец, извивается
    prev, base = R.body, (0.0, 0.45, 0)
    chain = []
    for i in range(6):
        tip = (base[0] - 0.5, max(0.25, base[1] - 0.04), 0)
        b = R.bone("b:seg%d" % i, prev, base)
        r = 0.4 - i * 0.045
        R.seg(b, lerp3(base, tip, 1.3), lerp3(base, tip, -0.25), r, body if i % 2 == 0 else shade(body, 0.85), "flesh", shape="cylinder" if i < 5 else "cone", n=12)
        R.add(b, P("sphere", (r * 2.0, r * 2.0, r * 2.0), base, shade(body, 0.92), "flesh", seg=12))
        R.add(b, P("torus", (r * 2.1, 0.08, r * 2.1), lerp3(base, tip, 0.5), shell, "flesh", rot=(0, 0, 90), seg=14))
        for k in range(4):
            R.add(b, P("prism", (0.06, 0.16 - i * 0.015, 0.05), (lerp3(base, tip, 0.25 + k * 0.17)[0], base[1] + r * 0.9, 0), spikes, "flesh", rot=(0, 0, 25)))
        chain.append(b)
        prev, base = b, tip
    R.chains.append({"bones": chain, "axis": "y", "amp": 18, "speed": 3.5, "follow": True})
    R.chains.append({"bones": up, "axis": "z", "amp": 6, "speed": 1.6})
    return R, {"stride": 1.6, "swing": 0, "lift": 0, "knee": 0, "bob": 0.05, "roll": 4, "duty": 0.5, "lean": 8}


def human(name, shirt, pants, skin, hat=(), extra=(), s=1.0):
    """Человек-НПС со скелетом как у героя: шаги, взмах рук, поворот головы."""
    R = Rig(s)
    R.body = R.bone("b:hips", "", (0, 0.9, 0))
    torso = R.bone("b:torso", R.body, (0, 1.0, 0))
    R.head = R.bone("b:head", torso, (0, 1.62, 0))
    R.breath = [torso]
    R.add(R.body, P("box", (0.32, 0.18, 0.5), (0, 0.92, 0), pants, "cloth"))
    R.add(R.body, P("box", (0.36, 0.1, 0.56), (0, 0.98, 0), "#3a2a1c", "wood"))
    R.add(R.body, P("box", (0.06, 0.08, 0.1), (0.19, 0.98, 0), "#c9a227", "metal"))
    R.add(torso, P("box", (0.34, 0.6, 0.54), (0, 1.3, 0), shirt, "cloth"))
    R.add(torso, P("box", (0.36, 0.12, 0.58), (0, 1.56, 0), shade(shirt, 0.85), "cloth"))
    for i in range(3):
        R.add(torso, P("sphere", (0.03, 0.03, 0.03), (0.175, 1.42 - i * 0.12, 0), "#e8e0c8", "paint", seg=6))
    R.add(R.head, P("cylinder", (0.13, 0.12, 0.2), (0, 1.66, 0), skin, "flesh", seg=8))
    R.add(R.head, P("sphere", (0.36, 0.38, 0.34), (0.02, 1.86, 0), skin, "flesh", seg=14))
    for z in (-0.08, 0.08):
        R.add(R.head, P("box", (0.04, 0.05, 0.06), (0.19, 1.9, z), "#1a1a1a", "dark"))
        R.add(R.head, P("sphere", (0.05, 0.08, 0.04), (0.0, 1.86, z * 2.3), skin, "flesh", seg=6))
    R.add(R.head, P("box", (0.03, 0.06, 0.04), (0.2, 1.83, 0), shade(skin, 0.85), "flesh"))
    R.add(R.head, P("box", (0.02, 0.02, 0.1), (0.19, 1.76, 0), "#8a3a3a", "flesh"))
    for part in hat:
        R.add(R.head, part)
    for side in (-1, 1):
        sd = "l" if side < 0 else "r"
        lg = R.bone("b:leg" + sd, R.body, (0, 0.88, side * 0.14))
        sh = R.bone("b:shin" + sd, lg, (0, 0.48, side * 0.14))
        R.add(lg, P("cylinder", (0.2, 0.42, 0.2), (0, 0.68, side * 0.14), pants, "cloth", seg=10))
        R.add(sh, P("cylinder", (0.17, 0.4, 0.17), (0, 0.28, side * 0.14), pants, "cloth", seg=10))
        R.add(sh, P("box", (0.3, 0.1, 0.16), (0.05, 0.05, side * 0.14), "#2a1c12", "wood"))
        R.legs.append({"hip": lg, "knee": sh, "phase": 0.0 if side < 0 else 0.5, "side": side, "style": "z"})
        ar = R.bone("b:arm" + sd, torso, (0, 1.5, side * 0.34))
        fo = R.bone("b:fore" + sd, ar, (0, 1.2, side * 0.36))
        R.add(ar, P("cylinder", (0.15, 0.34, 0.15), (0, 1.34, side * 0.35), shirt, "cloth", seg=8))
        R.add(fo, P("cylinder", (0.13, 0.3, 0.13), (0, 1.04, side * 0.36), shirt, "cloth", seg=8))
        R.add(fo, P("sphere", (0.12, 0.12, 0.1), (0, 0.86, side * 0.36), skin, "flesh", seg=8))
        R.arms.append({"bone": ar, "fore": fo, "phase": 0.0 if side > 0 else 0.5, "amp": 26})
    for bone, part in extra:
        R.add(bone, part)
    return R, {"stride": 1.3, "swing": 28, "lift": 0, "knee": 45, "bob": 0.04, "roll": 2, "duty": 0.58, "lean": 5}


ANIMS = {
    "jaw": {"name": "Челюсть", "type": "swing", "speed": 6.0, "amount": 0.25, "always": True},
    "tail": {"name": "Хвост", "type": "sway", "speed": 3.0, "amount": 0.25, "always": True},
}


def model(name, R, gait, cat="Монстры"):
    m = M(name, R.parts, cat)
    m["rig"] = R.rig(gait)
    return m


def all_models():
    out = {}
    for mid, name, fn, sc in (("crawler", "Ползун", crawler, 1.0), ("brute", "Громила", brute, 1.25), ("spitter", "Плевун", spitter, 1.15), ("runner", "Бегун", runner, 0.85), ("worm", "Земляной червь", worm, 1.8)):
        R, g = fn(s=sc)
        g["stride"] = round(g["stride"] * sc, 3)
        out[mid] = model(name, R, g)
    return out
