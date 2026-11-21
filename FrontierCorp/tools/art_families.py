# 14.4 Около 500 монстров: 12 семейств × 8 видов × 5 вариантов силы (+ вожаки семейств).
# Каждый вид — своя модель на скелете (игра сама двигает кости), варианты силы — та же модель
# другой окраски и размера («Окраска варианта» и «Сила окраски» в «Монстры и НПС»).
# Модель смотрит вдоль +X, вверх — Y, бока — Z.
import math
from art_kit import P, M, shade
import art_rigged as AR
from art_rigged import Rig, lerp3, eyes


# ------------------------------------------------------------------ части

def wings(R, parent, root, span, col, membrane, n=3, flap=38, speed=9.0, mat="flesh"):
    """Пара крыльев из n звеньев: кости машут вместе (ось x, у правого знак −1)."""
    for side in (-1, 1):
        sd = "l" if side < 0 else "r"
        prev, base = parent, (root[0], root[1], side * root[2])
        chain = []
        for i in range(n):
            seg_len = span / n
            tip = (base[0] - 0.12 * seg_len, base[1] + (0.12 if i == 0 else -0.04) * seg_len, base[2] + side * seg_len)
            b = R.bone("b:wing%s%d" % (sd, i), prev, base)
            R.seg(b, tip, base, 0.035 + 0.02 * (n - i), col, "leg", n=6)
            mid = lerp3(base, tip, 0.5)
            depth = (0.75 - i * 0.18) * seg_len * 1.4
            R.add(b, P("box", (depth, 0.025, seg_len * 1.04), (mid[0] - depth * 0.45, mid[1] - 0.02, mid[2]), membrane, mat))
            for k in range(2):
                R.add(b, P("box", (depth * 0.9, 0.03, 0.03), (mid[0] - depth * 0.45, mid[1] - 0.005, mid[2] + side * (k - 0.5) * seg_len * 0.5), shade(col, 0.8), "leg"))
            R.add(b, P("cone", (0.05, 0.12, 0.05), (tip[0] - 0.02, tip[1], tip[2]), "#e8d8c0", "flesh", rot=(side * 90, 0, 0), seg=5))
            chain.append(b)
            prev, base = b, tip
        R.chains.append({"bones": chain, "axis": "x", "amp": flap, "speed": speed, "sign": -side, "lag": 0.25})


def humanoid(spec):
    """Человекоподобный монстр: зомби, ведьма, гигант, гном, тролль, призрак, робот, пришелец.
    spec: s, skin, shirt, pants, mat (ткань: cloth, metal, glow), head_k, lean, eye, ghost, bulk, extras(R, bones)."""
    s = spec.get("s", 1.0)
    skin, shirt, pants = spec["skin"], spec["shirt"], spec["pants"]
    cm = spec.get("mat", "cloth")
    fm = spec.get("flesh_mat", "flesh" if cm != "metal" else "metal")
    hk = spec.get("head_k", 1.0)
    bulk = spec.get("bulk", 1.0)
    eye = spec.get("eye", "#ffdd33")
    R = Rig(s)
    R.body = R.bone("b:hips", "", (0, 0.9, 0))
    torso = R.bone("b:torso", R.body, (0, 1.0, 0))
    R.head = R.bone("b:head", torso, (0, 1.62, 0))
    R.breath = [torso]
    # таз и пояс
    R.add(R.body, P("box", (0.32 * bulk, 0.2, 0.52 * bulk), (0, 0.92, 0), pants, cm))
    R.add(R.body, P("box", (0.36 * bulk, 0.08, 0.56 * bulk), (0, 1.0, 0), shade(pants, 0.6), cm))
    # корпус: грудь, плечи, живот
    R.add(torso, P("box", (0.36 * bulk, 0.62, 0.56 * bulk), (0, 1.31, 0), shirt, cm))
    R.add(torso, P("box", (0.38 * bulk, 0.14, 0.62 * bulk), (0, 1.56, 0), shade(shirt, 0.85), cm))
    R.add(torso, P("sphere", (0.3 * bulk, 0.3, 0.5 * bulk), (0.05, 1.18, 0), shade(shirt, 0.92), cm, seg=12))
    for side in (-1, 1):
        R.add(torso, P("sphere", (0.24 * bulk, 0.2, 0.24 * bulk), (0, 1.56, side * 0.31 * bulk), shade(shirt, 1.1), cm, seg=10))
    # шея и голова
    R.add(R.head, P("cylinder", (0.13, 0.12, 0.13), (0, 1.67, 0), skin, fm, seg=8))
    R.add(R.head, P("sphere", (0.36 * hk, 0.38 * hk, 0.34 * hk), (0.02, 1.62 + 0.24 * hk, 0), skin, fm, seg=14))
    hy = 1.62 + 0.24 * hk
    for z in (-0.08 * hk, 0.08 * hk):
        R.add(R.head, P("sphere", (0.07 * hk, 0.07 * hk, 0.05 * hk), (0.17 * hk, hy + 0.04 * hk, z), eye, "glow", anim="pulse", seg=8))
        R.add(R.head, P("sphere", (0.05, 0.08, 0.04), (0.0, hy, z * 2.3), skin, fm, seg=6))
    R.add(R.head, P("box", (0.03 * hk, 0.06 * hk, 0.04 * hk), (0.2 * hk, hy - 0.03 * hk, 0), shade(skin, 0.85), fm))
    jaw = R.bone("b:jaw", R.head, (0.08, hy - 0.12 * hk, 0))
    R.jaws.append({"bone": jaw, "axis": "z", "open": -22})
    R.add(jaw, P("box", (0.16 * hk, 0.06 * hk, 0.2 * hk), (0.12 * hk, hy - 0.15 * hk, 0), shade(skin, 0.8), fm))
    # ноги (у призрака — хвост-балахон)
    if spec.get("ghost"):
        tail = R.bone("b:tail0", R.body, (0, 0.85, 0))
        R.add(tail, P("cone", (0.62 * bulk, 0.9, 0.7 * bulk), (0, 0.45, 0), pants, cm, rot=(0, 0, 180), seg=14))
        t1 = R.bone("b:tail1", tail, (0, 0.2, 0))
        R.add(t1, P("cone", (0.3, 0.5, 0.34), (-0.15, 0.0, 0), shade(pants, 0.8), cm, rot=(0, 0, 160), seg=10))
        R.chains.append({"bones": [tail, t1], "axis": "z", "amp": 10, "speed": 2.0})
    else:
        for side in (-1, 1):
            sd = "l" if side < 0 else "r"
            lg = R.bone("b:leg" + sd, R.body, (0, 0.88, side * 0.14 * bulk))
            sh = R.bone("b:shin" + sd, lg, (0, 0.48, side * 0.14 * bulk))
            R.add(lg, P("cylinder", (0.2 * bulk, 0.42, 0.2 * bulk), (0, 0.68, side * 0.14 * bulk), pants, cm, seg=10))
            R.add(lg, P("sphere", (0.2 * bulk, 0.16, 0.2 * bulk), (0, 0.48, side * 0.14 * bulk), shade(pants, 0.85), cm, seg=8))
            R.add(sh, P("cylinder", (0.17 * bulk, 0.4, 0.17 * bulk), (0, 0.28, side * 0.14 * bulk), pants, cm, seg=10))
            R.add(sh, P("box", (0.32 * bulk, 0.12, 0.18 * bulk), (0.05, 0.06, side * 0.14 * bulk), spec.get("boot", "#2a1c12"), "wood" if cm == "cloth" else cm))
            R.legs.append({"hip": lg, "knee": sh, "phase": 0.0 if side < 0 else 0.5, "side": side, "style": "z"})
    # руки
    arm_k = spec.get("arm_k", 1.0)
    for side in (-1, 1):
        sd = "l" if side < 0 else "r"
        ar = R.bone("b:arm" + sd, torso, (0, 1.5, side * 0.34 * bulk))
        fo = R.bone("b:fore" + sd, ar, (0, 1.5 - 0.3 * arm_k, side * 0.36 * bulk))
        R.add(ar, P("cylinder", (0.15 * bulk, 0.34 * arm_k, 0.15 * bulk), (0, 1.5 - 0.16 * arm_k, side * 0.35 * bulk), shirt, cm, seg=8))
        R.add(fo, P("cylinder", (0.13 * bulk, 0.3 * arm_k, 0.13 * bulk), (0, 1.5 - 0.46 * arm_k, side * 0.36 * bulk), skin if spec.get("bare_arms") else shirt, cm if not spec.get("bare_arms") else fm, seg=8))
        R.add(fo, P("sphere", (0.13 * bulk, 0.13 * bulk, 0.11 * bulk), (0, 1.5 - 0.64 * arm_k, side * 0.36 * bulk), skin, fm, seg=8))
        for f in range(3):
            R.add(fo, P("cone", (0.025, 0.07, 0.025), (0.04, 1.5 - 0.71 * arm_k, side * 0.36 * bulk + (f - 1) * 0.035), shade(skin, 0.8), fm, rot=(0, 0, 180), seg=4))
        R.arms.append({"bone": ar, "fore": fo, "phase": 0.0 if side > 0 else 0.5, "amp": spec.get("arm_amp", 26)})
    bones = {"hips": R.body, "torso": torso, "head": R.head, "hy": hy, "hk": hk, "bulk": bulk, "jaw": jaw}
    for fn in spec.get("extras", []):
        fn(R, bones)
    gait = {"stride": 1.3, "swing": 28, "lift": 0, "knee": 45, "bob": 0.04, "roll": 2, "duty": 0.58, "lean": spec.get("lean", 5)}
    gait.update(spec.get("gait", {}))
    if spec.get("ghost"):
        gait.update({"swing": 0, "knee": 0, "bob": 0.12, "roll": 4})
    return R, gait


def blob(spec):
    """Слизень: дрожащее тело-капля с ядром и пузырями; без ног, ползёт волной."""
    s = spec.get("s", 1.0)
    col, core, eye = spec["col"], spec["core"], spec.get("eye", "#1a1a1a")
    mat = spec.get("mat", "flesh")
    R = Rig(s)
    R.body = R.bone("b:body", "", (0, 0.4, 0))
    top = R.bone("b:top", R.body, (0, 0.7, 0))
    R.head = top
    R.breath = [R.body, top]
    R.add(R.body, P("sphere", (1.5, 0.8, 1.3), (0, 0.4, 0), col, mat, seg=20))
    R.add(R.body, P("cylinder", (1.6, 0.12, 1.4), (0, 0.06, 0), shade(col, 0.8), mat, seg=20))
    R.add(top, P("sphere", (1.0, 0.7, 0.9), (0.05, 0.85, 0), shade(col, 1.15), mat, seg=18))
    R.add(top, P("sphere", (0.45, 0.45, 0.45), (0, 0.6, 0), core, "glow", anim="pulse", seg=14))
    for i in range(14):
        a = i / 14 * math.tau
        r = 0.5 + 0.2 * ((i * 7) % 3)
        R.add(R.body if i % 2 else top, P("sphere", (0.12 + (i % 3) * 0.04,) * 3, (math.cos(a) * r * 0.9, 0.3 + (i % 4) * 0.15, math.sin(a) * r * 0.8), shade(col, 1.35), "glow", anim="pulse", seg=8))
    for z in (-0.18, 0.18):
        R.add(top, P("sphere", (0.18, 0.2, 0.16), (0.45, 0.98, z), "#f4f4f4", "paint", seg=10))
        R.add(top, P("sphere", (0.09, 0.1, 0.08), (0.53, 0.98, z), eye, "dark", seg=8))
    jaw = R.bone("b:jaw", top, (0.45, 0.7, 0))
    R.jaws.append({"bone": jaw, "axis": "z", "open": -25})
    R.add(jaw, P("box", (0.1, 0.06, 0.4), (0.48, 0.68, 0), shade(col, 0.5), "dark"))
    for fn in spec.get("extras", []):
        fn(R, {"body": R.body, "top": top})
    return R, {"stride": 1.2, "swing": 0, "lift": 0, "knee": 0, "bob": 0.14, "roll": 6, "duty": 0.5, "lean": 4}


# ------------------------------------------------------------------ обвес

def hat_witch(col="#2a1a3a", band="#8a2bd8"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("cylinder", (0.62 * hk, 0.04, 0.62 * hk), (0.02, hy + 0.14 * hk, 0), col, "cloth", seg=18))
        R.add(b["head"], P("cone", (0.34 * hk, 0.55 * hk, 0.34 * hk), (-0.04, hy + 0.42 * hk, 0), col, "cloth", rot=(0, 0, 12), seg=14))
        R.add(b["head"], P("torus", (0.36 * hk, 0.06, 0.36 * hk), (0.0, hy + 0.2 * hk, 0), band, "glow", seg=14))
    return f


def helmet(col="#5a5f66", lamp=False):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("sphere", (0.4 * hk, 0.24 * hk, 0.38 * hk), (0.02, hy + 0.1 * hk, 0), col, "metal", seg=14))
        R.add(b["head"], P("cylinder", (0.46 * hk, 0.03, 0.44 * hk), (0.02, hy + 0.02 * hk, 0), shade(col, 0.8), "metal", seg=14))
        if lamp:
            R.add(b["head"], P("cylinder", (0.09, 0.08, 0.09), (0.2 * hk, hy + 0.14 * hk, 0), "#2a2a2a", "metal", rot=(0, 0, 90), seg=8))
            R.add(b["head"], P("sphere", (0.07, 0.07, 0.07), (0.25 * hk, hy + 0.14 * hk, 0), "#fff2a8", "glow", seg=8))
    return f


def cap(col="#c0302a"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("cone", (0.4 * hk, 0.6 * hk, 0.4 * hk), (-0.06, hy + 0.38 * hk, 0), col, "cloth", rot=(0, 0, 25), seg=14))
        R.add(b["head"], P("sphere", (0.08, 0.08, 0.08), (-0.26, hy + 0.62 * hk, 0), "#f4f4f4", "cloth", seg=8))
    return f


def beard(col="#d8d8d0", long=1.0):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["jaw"], P("cone", (0.3 * hk, 0.42 * long * hk, 0.26 * hk), (0.17 * hk, hy - 0.3 * hk * long, 0), col, "cloth", rot=(0, 0, 180), seg=10))
        R.add(b["head"], P("box", (0.06, 0.04, 0.2 * hk), (0.2 * hk, hy - 0.05 * hk, 0), col, "cloth"))
    return f


def horns(col="#e8d8c0", n=2, size=1.0):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        for i in range(n):
            z = (i - (n - 1) / 2) * 0.16 * hk
            R.add(b["head"], P("cone", (0.07 * size, 0.28 * size, 0.07 * size), (-0.02, hy + 0.2 * hk, z * 1.4), col, "flesh", rot=(z * 120, 0, -20), seg=6))
    return f


def tusks(col="#efe6cc"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        for z in (-0.07, 0.07):
            R.add(b["jaw"], P("cone", (0.04, 0.14, 0.04), (0.2 * hk, hy - 0.1 * hk, z * hk), col, "flesh", seg=5))
    return f


def weapon(kind="club", col="#6a4a2a", side=1):
    def f(R, b):
        fo = "b:fore" + ("r" if side > 0 else "l")
        z = side * 0.36 * b["bulk"]
        if kind == "club":
            R.add(fo, P("cylinder", (0.07, 0.8, 0.07), (0.3, 0.86, z), col, "wood", rot=(0, 0, -70), seg=8))
            R.add(fo, P("sphere", (0.22, 0.3, 0.22), (0.66, 0.98, z), shade(col, 0.8), "wood", seg=10))
            for k in range(5):
                a = k / 5 * math.tau
                R.add(fo, P("cone", (0.04, 0.1, 0.04), (0.66 + math.cos(a) * 0.12, 0.98 + math.sin(a) * 0.15, z), "#9a9a9a", "metal", seg=4))
        elif kind == "staff":
            R.add(fo, P("cylinder", (0.05, 1.5, 0.05), (0.1, 1.1, z), col, "wood", seg=8))
            R.add(fo, P("sphere", (0.18, 0.18, 0.18), (0.1, 1.9, z), "#a050ff", "glow", anim="pulse", seg=10))
        elif kind == "broom":
            R.add(fo, P("cylinder", (0.05, 1.4, 0.05), (0.05, 0.85, z), col, "wood", rot=(0, 0, 60), seg=8))
            R.add(fo, P("cone", (0.24, 0.4, 0.24), (-0.55, 0.5, z), "#c8a050", "cloth", rot=(0, 0, 60), seg=10))
        elif kind == "gun":
            R.add(fo, P("box", (0.5, 0.12, 0.1), (0.25, 0.86, z), "#3a3f47", "metal"))
            R.add(fo, P("cylinder", (0.05, 0.3, 0.05), (0.6, 0.88, z), "#2a2a2a", "metal", rot=(0, 0, 90), seg=8))
            R.add(fo, P("sphere", (0.05, 0.05, 0.05), (0.76, 0.88, z), "#ff4a2a", "glow", seg=6))
        elif kind == "pick":
            R.add(fo, P("cylinder", (0.05, 0.9, 0.05), (0.2, 0.9, z), col, "wood", rot=(0, 0, -60), seg=8))
            R.add(fo, P("box", (0.08, 0.5, 0.06), (0.58, 1.12, z), "#8c949e", "metal", rot=(0, 0, 30)))
        elif kind == "bow":
            R.add(fo, P("torus", (0.7, 0.04, 0.3), (0.15, 0.86, z), col, "wood", rot=(90, 0, 0), seg=14))
        elif kind == "claws":
            for k in range(3):
                R.add(fo, P("cone", (0.04, 0.28, 0.04), (0.12, 0.72, z + (k - 1) * 0.06), "#f0e8d8", "flesh", rot=(0, 0, -150), seg=5))
    return f


def backpack(col="#5a4a2a", bomb=False):
    def f(R, b):
        bulk = b["bulk"]
        R.add(b["torso"], P("box", (0.26, 0.5, 0.42 * bulk), (-(0.18 * bulk + 0.12), 1.3, 0), col, "cloth"))
        if bomb:
            for k in range(3):
                R.add(b["torso"], P("cylinder", (0.14, 0.4, 0.14), (-(0.18 * bulk + 0.26), 1.3, (k - 1) * 0.15), "#c0302a", "paint", seg=10))
                R.add(b["torso"], P("sphere", (0.05, 0.05, 0.05), (-(0.18 * bulk + 0.26), 1.53, (k - 1) * 0.15), "#ffcc33", "glow", anim="blink", seg=6))
    return f


def antenna(col="#c0c4cc", glow="#5cff8c"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        for z in (-0.1, 0.1):
            R.add(b["head"], P("cylinder", (0.025, 0.3, 0.025), (0, hy + 0.3 * hk, z * hk), col, "metal", seg=6))
            R.add(b["head"], P("sphere", (0.06, 0.06, 0.06), (0, hy + 0.47 * hk, z * hk), glow, "glow", anim="blink", seg=6))
    return f


def robot_head(col="#8c949e", visor="#ff3b30"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("box", (0.38 * hk, 0.34 * hk, 0.38 * hk), (0.02, hy, 0), col, "metal"))
        R.add(b["head"], P("box", (0.04, 0.08 * hk, 0.3 * hk), (0.22 * hk, hy + 0.03 * hk, 0), visor, "glow", anim="pulse"))
        for z in (-0.2, 0.2):
            R.add(b["head"], P("cylinder", (0.1, 0.06, 0.1), (0, hy, z * hk), "#3a3f47", "metal", rot=(90, 0, 0), seg=10))
    return f


def crown(col="#ffcc33"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("cylinder", (0.38 * hk, 0.12, 0.38 * hk), (0.02, hy + 0.22 * hk, 0), col, "metal", seg=12))
        for k in range(6):
            a = k / 6 * math.tau
            R.add(b["head"], P("cone", (0.06, 0.14, 0.06), (0.02 + math.cos(a) * 0.17 * hk, hy + 0.34 * hk, math.sin(a) * 0.17 * hk), col, "metal", seg=4))
    return f


def cyclops_eye(col="#ff2a2a"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        R.add(b["head"], P("sphere", (0.16 * hk, 0.16 * hk, 0.16 * hk), (0.17 * hk, hy + 0.06 * hk, 0), "#f4f4f4", "paint", seg=12))
        R.add(b["head"], P("sphere", (0.09 * hk, 0.09 * hk, 0.09 * hk), (0.24 * hk, hy + 0.06 * hk, 0), col, "glow", anim="pulse", seg=10))
    return f


def big_eyes(col="#101010"):
    def f(R, b):
        hy, hk = b["hy"], b["hk"]
        for z in (-0.1, 0.1):
            R.add(b["head"], P("sphere", (0.12 * hk, 0.16 * hk, 0.1 * hk), (0.16 * hk, hy + 0.04 * hk, z * hk), col, "glow", rot=(z * -200, 0, 0), seg=10))
    return f


def glow_aura(col="#9ad8ff"):
    def f(R, b):
        for i in range(8):
            a = i / 8 * math.tau
            R.add(b["torso"], P("sphere", (0.08, 0.08, 0.08), (math.cos(a) * 0.45, 1.3 + (i % 3) * 0.15, math.sin(a) * 0.45), col, "glow", anim="pulse", seg=6))
    return f


def bwings(col, membrane, span=1.6, mat="flesh"):
    def f(R, b):
        wings(R, b.get("torso", b.get("body")), (-0.15, 1.5, 0.2), span, col, membrane, mat=mat)
    return f


def blob_spikes(col):
    def f(R, b):
        for i in range(10):
            a = i / 10 * math.tau
            R.add(b["body"], P("cone", (0.1, 0.3, 0.1), (math.cos(a) * 0.65, 0.55, math.sin(a) * 0.55), col, "metal", rot=(math.sin(a) * 50, 0, -math.cos(a) * 50), seg=6))
    return f


def blob_crown(col="#ffcc33"):
    def f(R, b):
        for k in range(6):
            a = k / 6 * math.tau
            R.add(b["top"], P("cone", (0.08, 0.2, 0.08), (math.cos(a) * 0.25, 1.25, math.sin(a) * 0.25), col, "metal", seg=4))
        R.add(b["top"], P("cylinder", (0.6, 0.1, 0.6), (0, 1.15, 0), col, "metal", seg=12))
    return f


# ------------------------------------------------------------------ существа на основе готовых скелетов

def insect(body, shell, eye, spikes, s=1.0, wing=None, spit=False):
    R, g = (AR.spitter if spit else AR.crawler)(body, shell, eye, spikes, s=1.0)
    if wing:
        wings(R, R.body, (0.1, 0.95, 0.25), 1.2, wing[0], wing[1], n=2, flap=50, speed=16.0, mat="glass" if wing[1].startswith("#c") else "flesh")
    return R, g


def dragon(body, shell, eye, spikes, membrane, s=1.0, fly=True):
    R, g = AR.runner(body, shell, eye, spikes, s=1.0)
    if fly:
        wings(R, R.body, (0.15, 1.3, 0.2), 1.9, shell, membrane, n=3, flap=16, speed=7.0)
    for z in (-0.08, 0.08):
        R.add(R.head, P("cone", (0.06, 0.3, 0.06), (0.78, 1.82, z), "#e8d8c0", "flesh", rot=(z * 200, 0, 35), seg=6))
    return R, g


def worm_v(body, shell, eye, spikes, s=1.0):
    return AR.worm(body, shell, eye, spikes, s=1.0)


# ------------------------------------------------------------------ 12 семейств × 8 видов

def H(**kw):
    return ("human", kw)


FAMILIES = [
    # (id, название семейства, день появления, [виды])
    ("zombie", "Зомби", 2, [
        ("zombie", "Зомби", H(skin="#7a9a6a", shirt="#5a6a7a", pants="#3a3f4a", lean=16, arm_amp=8, eye="#e8ff6a", bare_arms=True,
                              gait={"stride": 1.0, "duty": 0.62}), dict(hp=60, speed=3.2, damage=10, reach=1.3)),
        ("zombie_miner", "Зомби-шахтёр", H(skin="#7a8a6a", shirt="#c08a2a", pants="#3a3a3a", lean=14, arm_amp=10, eye="#e8ff6a", extras=[helmet("#d8a020", True), weapon("pick")]),
         dict(hp=80, speed=3.0, damage=14)),
        ("zombie_fat", "Зомби-толстяк", H(skin="#8aa070", shirt="#9a8a6a", pants="#4a4038", bulk=1.5, lean=8, arm_amp=6, eye="#ffd02a", extras=[backpack("#6a5a3a", True)]),
         dict(hp=110, speed=2.6, damage=8, explode_damage=55, explode_radius=4.0)),
        ("zombie_runner", "Зомби-бегун", H(skin="#6a8a5a", shirt="#7a3a3a", pants="#2a2f3a", lean=24, arm_amp=40, eye="#ff4a2a", bare_arms=True,
                                       gait={"stride": 1.6, "duty": 0.42}), dict(hp=40, speed=8.5, damage=8)),
        ("zombie_soldier", "Зомби-солдат", H(skin="#6a7a5a", shirt="#4a5a3a", pants="#3a4a2a", lean=10, arm_amp=12, eye="#ff6a2a", extras=[helmet("#4a5a3a"), weapon("gun", side=1)]),
         dict(hp=140, speed=3.4, damage=16)),
        ("zombie_spitter", "Зомби-плевака", H(skin="#7aa060", shirt="#4a6a3a", pants="#2a3a2a", lean=12, arm_amp=10, eye="#aaff33"),
         dict(hp=55, speed=3.0, damage=12, reach=9.0, ranged=True)),
        ("zombie_screamer", "Зомби-крикун", H(skin="#8a9a7a", shirt="#3a2a4a", pants="#2a2a2a", lean=6, arm_amp=30, eye="#ff2a6a", head_k=1.2),
         dict(hp=90, speed=3.0, damage=8, summon="zombie", summon_every=14, summon_n=2)),
        ("zombie_thief", "Зомби-воришка", H(skin="#7a9a7a", shirt="#2a2a3a", pants="#1a1a2a", lean=18, arm_amp=30, eye="#ffd02a", extras=[backpack("#3a2a1a")],
                                         gait={"stride": 1.5, "duty": 0.45}), dict(hp=45, speed=7.0, damage=4, steal=6)),
    ]),
    ("witch", "Ведьмы", 4, [
        ("witch", "Ведьма", H(skin="#b8c8a0", shirt="#3a2a4a", pants="#2a1a3a", eye="#a0ff40", extras=[hat_witch(), weapon("staff")]),
         dict(hp=70, speed=4.0, damage=14, reach=11.0, ranged=True)),
        ("witch_swamp", "Болотная ведьма", H(skin="#7a9a5a", shirt="#3a4a2a", pants="#2a3a1a", eye="#d0ff40", extras=[hat_witch("#2a3a1a", "#6aff40"), weapon("staff", "#4a3a1a")]),
         dict(hp=80, speed=3.6, damage=8, heal_every=5, heal_amount=25, heal_radius=10)),
        ("witch_summoner", "Ведьма-призывательница", H(skin="#c8b8d8", shirt="#2a1a2a", pants="#1a0a1a", eye="#ff40ff", extras=[hat_witch("#1a0a1a", "#ff40ff"), weapon("staff")]),
         dict(hp=75, speed=3.6, damage=8, summon="slime_small", summon_every=12, summon_n=2)),
        ("witch_ice", "Ледяная ведьма", H(skin="#d8e8f8", shirt="#4a6a9a", pants="#2a3a6a", eye="#7ad8ff", extras=[hat_witch("#2a3a6a", "#7ad8ff"), weapon("staff")]),
         dict(hp=75, speed=4.0, damage=16, reach=12.0, ranged=True)),
        ("witch_blink", "Ведьма-тень", H(skin="#a8a0b8", shirt="#1a1a2a", pants="#0a0a1a", eye="#b080ff", extras=[hat_witch("#0a0a1a", "#b080ff")]),
         dict(hp=65, speed=4.5, damage=15, teleport_every=6, teleport_range=35)),
        ("witch_broom", "Ведьма на метле", H(skin="#c8d0a8", shirt="#4a1a2a", pants="#2a0a1a", eye="#ff8040", extras=[hat_witch("#2a0a1a", "#ff8040"), weapon("broom")]),
         dict(hp=60, speed=6.5, damage=12, reach=10.0, ranged=True, fly=True, fly_height=3.0)),
        ("witch_thief", "Ведьма-воровка", H(skin="#b8b0a0", shirt="#2a3a2a", pants="#1a2a1a", eye="#ffd040", extras=[hat_witch("#1a2a1a", "#ffd040"), backpack("#4a3a2a")]),
         dict(hp=55, speed=6.0, damage=6, steal=5, teleport_every=10)),
        ("witch_elder", "Старшая ведьма", H(skin="#a8b098", shirt="#3a0a3a", pants="#2a0a2a", eye="#ff2a2a", head_k=1.1, extras=[hat_witch("#1a0a1a", "#ff2a2a"), weapon("staff"), glow_aura("#ff60ff")]),
         dict(hp=160, speed=3.4, damage=18, reach=12.0, ranged=True, heal_every=8, heal_amount=20, summon="witch", summon_every=25, summon_n=1)),
    ]),
    ("giant", "Гиганты", 8, [
        ("giant", "Гигант", H(s=2.3, skin="#c8a080", shirt="#6a5a3a", pants="#4a3a2a", eye="#3a2a1a", bulk=1.2, extras=[weapon("club")], gait={"stride": 1.2, "bob": 0.06}),
         dict(hp=600, speed=2.6, damage=55, reach=3.6, radius=2.0)),
        ("giant_stone", "Каменный гигант", H(s=2.4, skin="#8a8a86", shirt="#6a6a66", pants="#5a5a56", mat="stone", flesh_mat="stone", eye="#ffa040", bulk=1.4),
         dict(hp=900, speed=2.0, damage=60, reach=3.6, radius=2.2)),
        ("giant_ice", "Ледяной гигант", H(s=2.3, skin="#c8e0f0", shirt="#7aa8d8", pants="#4a78a8", eye="#7ad8ff", bulk=1.2, extras=[horns("#e0f4ff"), weapon("club", "#a8c8e0")]),
         dict(hp=650, speed=2.6, damage=50, reach=3.6, radius=2.0)),
        ("giant_fire", "Огненный гигант", H(s=2.3, skin="#c85a2a", shirt="#5a1a0a", pants="#3a0a0a", eye="#ffd040", bulk=1.2, extras=[horns("#2a1a1a"), glow_aura("#ff7a2a")]),
         dict(hp=620, speed=2.8, damage=45, reach=14.0, ranged=True, radius=2.0)),
        ("giant_forest", "Лесной гигант", H(s=2.4, skin="#7a5a3a", shirt="#3a6a2a", pants="#4a3a1a", mat="wood", flesh_mat="wood", eye="#90ff60", bulk=1.3, extras=[horns("#4a3a1a", 4)]),
         dict(hp=700, speed=2.2, damage=40, reach=3.6, radius=2.1, heal_every=6, heal_amount=40, heal_radius=14)),
        ("giant_thunder", "Гигант-громовержец", H(s=2.3, skin="#b0a8c8", shirt="#3a3a6a", pants="#2a2a4a", eye="#7ad8ff", bulk=1.2, extras=[crown("#7ad8ff"), weapon("staff", "#4a4a6a")]),
         dict(hp=600, speed=2.6, damage=40, reach=16.0, ranged=True, radius=2.0, teleport_every=15)),
        ("cyclops", "Циклоп", H(s=2.5, skin="#b89878", shirt="#5a4a3a", pants="#3a2a1a", eye="#000000", bulk=1.3, extras=[cyclops_eye(), weapon("club")]),
         dict(hp=800, speed=2.6, damage=65, reach=3.8, radius=2.2)),
        ("giant_chief", "Вождь гигантов", H(s=2.8, skin="#a88868", shirt="#7a2a1a", pants="#3a2a1a", eye="#ff3a2a", bulk=1.4, extras=[crown(), weapon("club", "#4a3020")]),
         dict(hp=1400, speed=2.4, damage=70, reach=4.0, radius=2.4, summon="gnome", summon_every=18, summon_n=3)),
    ]),
    ("gnome", "Гномы", 3, [
        ("gnome", "Гном", H(s=0.6, skin="#e8b898", shirt="#3a6a3a", pants="#5a4a2a", eye="#2a2a2a", head_k=1.3, extras=[cap(), beard()]), dict(hp=35, speed=5.0, damage=7, radius=0.5)),
        ("gnome_miner", "Гном-землекоп", H(s=0.6, skin="#d8a888", shirt="#6a5a2a", pants="#3a3a3a", eye="#2a2a2a", head_k=1.3, extras=[helmet("#d8a020", True), beard("#a87a4a"), weapon("pick")]),
         dict(hp=45, speed=4.5, damage=10, radius=0.5, burrow=True)),
        ("gnome_bomber", "Гном-подрывник", H(s=0.6, skin="#e8b898", shirt="#7a2a1a", pants="#3a2a1a", eye="#2a2a2a", head_k=1.3, extras=[cap("#2a2a2a"), beard("#8a8a8a"), backpack("#5a4a2a", True)]),
         dict(hp=30, speed=6.0, damage=5, radius=0.5, explode_damage=45, explode_radius=3.5)),
        ("gnome_thief", "Гном-воришка", H(s=0.6, skin="#e8c8a8", shirt="#2a2a2a", pants="#1a1a1a", eye="#ffd040", head_k=1.3, extras=[cap("#2a2a3a"), backpack("#3a2a1a")],
                                       gait={"stride": 1.5, "duty": 0.45}), dict(hp=25, speed=8.5, damage=3, radius=0.5, steal=8)),
        ("gnome_mage", "Гном-маг", H(s=0.6, skin="#e8b898", shirt="#3a3a8a", pants="#2a2a6a", eye="#7ad8ff", head_k=1.3, extras=[cap("#3a3a8a"), beard("#f4f4f4", 1.4), weapon("staff")]),
         dict(hp=35, speed=4.5, damage=12, radius=0.5, reach=10.0, ranged=True, teleport_every=8)),
        ("gnome_archer", "Гном-арбалетчик", H(s=0.6, skin="#d8a888", shirt="#5a3a2a", pants="#3a2a1a", eye="#2a2a2a", head_k=1.3, extras=[cap("#5a3a2a"), beard("#6a4a2a"), weapon("bow")]),
         dict(hp=30, speed=5.0, damage=10, radius=0.5, reach=13.0, ranged=True)),
        ("gnome_healer", "Гном-знахарь", H(s=0.6, skin="#e8b898", shirt="#f4f4f4", pants="#5a4a2a", eye="#2a2a2a", head_k=1.3, extras=[cap("#3a8a3a"), beard("#f4f4f4", 1.2), weapon("staff", "#4a3a1a")]),
         dict(hp=35, speed=4.5, damage=5, radius=0.5, heal_every=4, heal_amount=15, heal_radius=8)),
        ("gnome_elder", "Гном-старейшина", H(s=0.7, skin="#d8a888", shirt="#7a1a1a", pants="#3a2a1a", eye="#ffd040", head_k=1.3, extras=[crown(), beard("#f4f4f4", 1.6), weapon("staff")]),
         dict(hp=90, speed=4.0, damage=10, radius=0.6, summon="gnome", summon_every=12, summon_n=3)),
    ]),
    ("troll", "Тролли", 6, [
        ("troll", "Тролль", H(s=1.5, skin="#6a8a5a", shirt="#5a4a3a", pants="#3a3020", eye="#ffd040", bulk=1.3, lean=12, bare_arms=True, arm_k=1.3, extras=[tusks(), weapon("club")]),
         dict(hp=260, speed=3.6, damage=28, reach=2.4, radius=1.3)),
        ("troll_cave", "Пещерный тролль", H(s=1.6, skin="#7a7a72", shirt="#4a4a42", pants="#2a2a22", eye="#ff8040", bulk=1.4, lean=16, bare_arms=True, arm_k=1.4, extras=[tusks(), horns("#3a3a32")]),
         dict(hp=340, speed=3.0, damage=32, reach=2.4, radius=1.4)),
        ("troll_swamp", "Болотный тролль", H(s=1.5, skin="#4a7a4a", shirt="#3a4a2a", pants="#2a3a1a", eye="#d0ff40", bulk=1.3, lean=12, bare_arms=True, arm_k=1.3, extras=[tusks("#c8d0a0")]),
         dict(hp=280, speed=3.2, damage=24, reach=2.4, radius=1.3, heal_every=6, heal_amount=30, heal_radius=8)),
        ("troll_mountain", "Горный тролль", H(s=1.7, skin="#9a8a7a", shirt="#6a5a4a", pants="#4a3a2a", eye="#ffa040", bulk=1.4, lean=10, bare_arms=True, arm_k=1.3, extras=[tusks(), weapon("club", "#7a7a7a")]),
         dict(hp=420, speed=2.8, damage=38, reach=2.6, radius=1.5)),
        ("troll_shaman", "Тролль-шаман", H(s=1.4, skin="#6a8a6a", shirt="#7a3a2a", pants="#3a2a1a", eye="#ff40ff", bulk=1.2, lean=10, extras=[tusks(), horns("#e8d8c0", 2, 1.4), weapon("staff")]),
         dict(hp=220, speed=3.2, damage=20, reach=2.2, radius=1.2, summon="troll", summon_every=24, summon_n=1, heal_every=8, heal_amount=30)),
        ("troll_thrower", "Тролль-метатель", H(s=1.5, skin="#7a8a5a", shirt="#5a4a2a", pants="#3a3020", eye="#ffd040", bulk=1.3, lean=10, bare_arms=True, arm_k=1.3, extras=[tusks(), backpack("#5a5a5a")]),
         dict(hp=240, speed=3.4, damage=26, reach=13.0, radius=1.3, ranged=True)),
        ("troll_berserk", "Тролль-берсерк", H(s=1.5, skin="#9a5a4a", shirt="#3a1a1a", pants="#2a1a1a", eye="#ff2a2a", bulk=1.3, lean=22, bare_arms=True, arm_k=1.3, arm_amp=40, extras=[tusks(), weapon("claws"), weapon("claws", side=-1)],
                                            gait={"stride": 1.7, "duty": 0.45}), dict(hp=240, speed=6.5, damage=30, reach=2.2, radius=1.3)),
        ("troll_river", "Речной тролль", H(s=1.5, skin="#4a7a8a", shirt="#2a4a5a", pants="#1a3a4a", eye="#7ad8ff", bulk=1.3, lean=14, bare_arms=True, arm_k=1.3, extras=[tusks("#d0e8f0"), weapon("claws")]),
         dict(hp=280, speed=4.0, damage=26, reach=2.3, radius=1.3)),
    ]),
    ("dragon", "Драконы", 10, [
        ("dragonling", "Дракончик", ("dragon", dict(body="#6a8a3a", shell="#3a5a1a", eye="#ffd040", spikes="#ffa040", membrane="#8aa060")), dict(hp=120, speed=7.0, damage=14, fly=True, fly_height=3.5)),
        ("dragon_fire", "Огненный дракон", ("dragon", dict(body="#a82a1a", shell="#5a0a0a", eye="#ffd040", spikes="#ffa040", membrane="#d85a2a")),
         dict(hp=420, speed=6.5, damage=30, reach=14.0, ranged=True, fly=True, fly_height=5.0, radius=1.4)),
        ("dragon_ice", "Ледяной дракон", ("dragon", dict(body="#8ab8e0", shell="#3a6aa8", eye="#e0f8ff", spikes="#ffffff", membrane="#b0d8f0")),
         dict(hp=420, speed=6.0, damage=28, reach=14.0, ranged=True, fly=True, fly_height=5.0, radius=1.4)),
        ("dragon_poison", "Ядовитый дракон", ("dragon", dict(body="#5a8a2a", shell="#2a4a1a", eye="#d0ff40", spikes="#a0ff40", membrane="#7aa040")),
         dict(hp=380, speed=6.5, damage=24, reach=13.0, ranged=True, fly=True, fly_height=4.5, radius=1.4)),
        ("wyvern", "Виверна", ("dragon", dict(body="#7a5a8a", shell="#4a2a5a", eye="#ff4a8a", spikes="#ff8ad8", membrane="#9a7aa8")),
         dict(hp=260, speed=9.0, damage=22, fly=True, fly_height=4.0, radius=1.2)),
        ("dragon_stone", "Каменный дракон", ("dragon", dict(body="#7a7a76", shell="#4a4a46", eye="#ffa040", spikes="#c8c8c0", membrane="#8a8a86", fly=False)),
         dict(hp=800, speed=3.5, damage=45, reach=2.6, radius=1.6)),
        ("dragon_shadow", "Теневой дракон", ("dragon", dict(body="#2a2a3a", shell="#0a0a1a", eye="#b080ff", spikes="#b080ff", membrane="#3a3a5a")),
         dict(hp=380, speed=7.0, damage=30, fly=True, fly_height=4.0, radius=1.4, teleport_every=7, teleport_range=40)),
        ("dragon_mother", "Мать драконов", ("dragon", dict(body="#c8902a", shell="#7a4a0a", eye="#ff2a2a", spikes="#ffd040", membrane="#e0b060")),
         dict(hp=1600, speed=5.5, damage=50, reach=15.0, ranged=True, fly=True, fly_height=6.0, radius=2.0, summon="dragonling", summon_every=20, summon_n=2)),
    ]),
    ("insect", "Насекомые", 1, [
        ("ant", "Муравей", ("insect", dict(body="#5a2a1a", shell="#3a1a0a", eye="#1a1a1a", spikes="#8a4a2a")), dict(hp=30, speed=6.0, damage=6, radius=0.7)),
        ("beetle", "Жук-носорог", ("insect", dict(body="#2a3a5a", shell="#1a2a4a", eye="#ff4a2a", spikes="#7aa8ff")), dict(hp=140, speed=3.5, damage=16, radius=0.9)),
        ("wasp", "Оса", ("insect", dict(body="#d8a020", shell="#2a2a1a", eye="#1a1a1a", spikes="#ffd040", wing=("#2a2a1a", "#c8e0f0"))),
         dict(hp=35, speed=8.0, damage=9, fly=True, fly_height=2.5, radius=0.6)),
        ("spider", "Паук", ("insect", dict(body="#2a2a2a", shell="#1a1a1a", eye="#ff2a2a", spikes="#ff4a2a")), dict(hp=60, speed=7.5, damage=11, radius=0.8)),
        ("scorpion", "Скорпион", ("insect", dict(body="#a87a3a", shell="#6a4a1a", eye="#1a1a1a", spikes="#ffa040", spit=True)), dict(hp=110, speed=4.5, damage=18, reach=8.0, ranged=True, radius=0.9)),
        ("locust", "Саранча", ("insect", dict(body="#6a8a2a", shell="#4a6a1a", eye="#ffd040", spikes="#a0c040", wing=("#4a6a1a", "#c8d8a0"))),
         dict(hp=25, speed=9.5, damage=5, fly=True, fly_height=2.0, radius=0.5)),
        ("bombardier", "Жук-бомбардир", ("insect", dict(body="#c84a1a", shell="#2a1a1a", eye="#ffd040", spikes="#ff8a2a")), dict(hp=50, speed=5.0, damage=6, radius=0.7, explode_damage=40, explode_radius=3.5)),
        ("hive_queen", "Королева роя", ("insect", dict(body="#8a2a6a", shell="#4a0a3a", eye="#ffd040", spikes="#ff60d0", wing=("#4a0a3a", "#c8a0d8"))),
         dict(hp=500, speed=3.0, damage=20, radius=1.4, summon="ant", summon_every=10, summon_n=3)),
    ]),
    ("worm", "Черви", 4, [
        ("worm_sand", "Песчаный червь", ("worm", dict(body="#c8a870", shell="#8a6a3a", eye="#ff4a2a", spikes="#f0e0c0")), dict(hp=220, speed=5.5, damage=26, burrow=True, radius=1.3)),
        ("worm_acid", "Кислотный червь", ("worm", dict(body="#7aa040", shell="#4a6a1a", eye="#d0ff40", spikes="#d0ff40")), dict(hp=200, speed=5.0, damage=20, burrow=True, radius=1.3, reach=8.0, ranged=True)),
        ("worm_giant", "Гигантский червь", ("worm", dict(body="#8a6a5a", shell="#5a3a2a", eye="#ff2a2a", spikes="#e8d8c0")), dict(hp=700, speed=4.0, damage=50, burrow=True, radius=2.0, reach=3.0)),
        ("worm_leech", "Червь-пиявка", ("worm", dict(body="#5a2a3a", shell="#3a1a2a", eye="#ff4a6a", spikes="#c84a6a")), dict(hp=180, speed=5.0, damage=16, burrow=True, radius=1.2, heal_every=4, heal_amount=30)),
        ("worm_stone", "Каменный червь", ("worm", dict(body="#8a8a86", shell="#5a5a56", eye="#ffa040", spikes="#c8c8c0")), dict(hp=500, speed=3.5, damage=34, burrow=True, radius=1.5)),
        ("worm_mother", "Червь-матка", ("worm", dict(body="#a87a6a", shell="#6a3a2a", eye="#ffd040", spikes="#ffe0a0")), dict(hp=900, speed=3.0, damage=30, burrow=True, radius=2.0, summon="worm", summon_every=20, summon_n=2)),
        ("worm_fire", "Огненный червь", ("worm", dict(body="#c84a1a", shell="#5a1a0a", eye="#ffd040", spikes="#ffa040")), dict(hp=260, speed=5.5, damage=28, burrow=True, radius=1.3, reach=10.0, ranged=True)),
        ("worm_ice", "Ледяной червь", ("worm", dict(body="#a8c8e0", shell="#5a7aa8", eye="#e0f8ff", spikes="#ffffff")), dict(hp=260, speed=5.0, damage=26, burrow=True, radius=1.3)),
    ]),
    ("ghost", "Призраки", 5, [
        ("ghost", "Призрак", H(skin="#9ab8d0", shirt="#7a9ab8", pants="#5a7a98", mat="flesh", flesh_mat="flesh", eye="#1a2a4a", ghost=True), dict(hp=60, speed=4.5, damage=12, fly=True, fly_height=0.6)),
        ("poltergeist", "Полтергейст", H(skin="#d0c8f0", shirt="#a8a0d8", pants="#8880c0", mat="flesh", flesh_mat="flesh", eye="#ff4a8a", ghost=True),
         dict(hp=50, speed=6.5, damage=6, fly=True, fly_height=1.0, steal=5, teleport_every=9)),
        ("banshee", "Банши", H(skin="#a8b8c8", shirt="#8898b0", pants="#687898", mat="flesh", flesh_mat="flesh", eye="#ff2a2a", ghost=True, head_k=1.1),
         dict(hp=70, speed=5.0, damage=18, reach=11.0, ranged=True, fly=True, fly_height=1.0)),
        ("shade", "Тень", H(skin="#3a3a4a", shirt="#2a2a3a", pants="#1a1a2a", mat="flesh", flesh_mat="flesh", eye="#b080ff", ghost=True),
         dict(hp=55, speed=6.0, damage=16, fly=True, fly_height=0.5, teleport_every=5, teleport_range=30)),
        ("spirit_guard", "Дух-хранитель", H(skin="#c8f0d8", shirt="#a0e0b8", pants="#80c098", mat="flesh", flesh_mat="flesh", eye="#ffffff", ghost=True, extras=[glow_aura("#a0ffc0")]),
         dict(hp=80, speed=4.0, damage=8, fly=True, fly_height=0.8, heal_every=4, heal_amount=20, heal_radius=10)),
        ("phantom", "Фантом", H(skin="#a8d8f8", shirt="#80b8e8", pants="#6098d8", mat="flesh", flesh_mat="flesh", eye="#ffffff", ghost=True, lean=20),
         dict(hp=40, speed=9.0, damage=10, fly=True, fly_height=1.2)),
        ("ghost_knight", "Призрак-рыцарь", H(skin="#b8d0e0", shirt="#90a8c0", pants="#7088a0", mat="flesh", flesh_mat="flesh", eye="#7ad8ff", ghost=True, bulk=1.2, extras=[helmet("#90a8c0"), weapon("club", "#a8c0d8")]),
         dict(hp=200, speed=4.0, damage=24, fly=True, fly_height=0.5, radius=1.0)),
        ("lich", "Лич", H(skin="#d8d8c8", shirt="#2a1a3a", pants="#1a0a2a", mat="flesh", flesh_mat="flesh", eye="#40ff80", ghost=True, extras=[crown("#40ff80"), weapon("staff")]),
         dict(hp=350, speed=3.5, damage=24, reach=12.0, ranged=True, fly=True, fly_height=0.6, summon="ghost", summon_every=15, summon_n=2)),
    ]),
    ("slime", "Слизни", 1, [
        ("slime_small", "Слизень", ("blob", dict(col="#5ad85a", core="#2a8a2a")), dict(hp=30, speed=3.5, damage=6, radius=0.8, scale=0.7)),
        ("slime_acid", "Кислотный слизень", ("blob", dict(col="#c8e040", core="#7a9a1a")), dict(hp=50, speed=3.0, damage=12, reach=8.0, ranged=True, radius=0.9)),
        ("slime_boom", "Взрывной слизень", ("blob", dict(col="#e05a3a", core="#ffd040")), dict(hp=40, speed=4.0, damage=5, radius=0.9, explode_damage=40, explode_radius=3.5)),
        ("slime_heal", "Лечащий слизень", ("blob", dict(col="#f08ad8", core="#ffffff")), dict(hp=60, speed=3.0, damage=5, radius=0.9, heal_every=4, heal_amount=15, heal_radius=8)),
        ("slime_big", "Большой слизень", ("blob", dict(col="#3ab8a8", core="#1a6a5a", extras=[blob_crown("#7affe8")])), dict(hp=300, speed=2.2, damage=20, radius=1.6, scale=1.8, summon="slime_small", summon_every=10, summon_n=2)),
        ("slime_ice", "Ледяной слизень", ("blob", dict(col="#a8d8f8", core="#e0f8ff")), dict(hp=60, speed=3.0, damage=10, radius=0.9)),
        ("slime_metal", "Железный слизень", ("blob", dict(col="#8c949e", core="#ff4a2a", mat="metal", extras=[blob_spikes("#c0c4cc")])), dict(hp=220, speed=2.0, damage=16, radius=1.0)),
        ("slime_jumper", "Прыгучий слизень", ("blob", dict(col="#ffb040", core="#ff6a1a")), dict(hp=40, speed=7.0, damage=8, radius=0.8)),
    ]),
    ("robot", "Роботы", 7, [
        ("robot_worker", "Робот-рабочий", H(skin="#8c949e", shirt="#d8a020", pants="#5a5f66", mat="metal", eye="#5cff8c", extras=[robot_head("#d8a020", "#5cff8c"), antenna()]), dict(hp=120, speed=4.0, damage=14)),
        ("robot_guard", "Робот-охранник", H(skin="#6a7078", shirt="#3a4a5a", pants="#2a3a4a", mat="metal", bulk=1.3, eye="#ff3b30", extras=[robot_head("#3a4a5a")]), dict(hp=260, speed=3.5, damage=22, radius=1.0)),
        ("drone", "Дрон", ("insect", dict(body="#5a5f66", shell="#3a3f47", eye="#ff3b30", spikes="#5cff8c", wing=("#3a3f47", "#c8d0d8"))),
         dict(hp=50, speed=8.0, damage=8, fly=True, fly_height=4.0, reach=10.0, ranged=True, radius=0.6)),
        ("robot_kamikaze", "Робот-камикадзе", H(s=0.8, skin="#8c949e", shirt="#c0302a", pants="#5a5f66", mat="metal", eye="#ffcc33", extras=[robot_head("#c0302a", "#ffcc33"), backpack("#3a3f47", True)]),
         dict(hp=60, speed=7.0, damage=5, explode_damage=60, explode_radius=4.0)),
        ("robot_medic", "Робот-ремонтник", H(skin="#c0c4cc", shirt="#f4f4f4", pants="#8c949e", mat="metal", eye="#5cff8c", extras=[robot_head("#f4f4f4", "#5cff8c"), antenna("#c0c4cc", "#ff3b30")]),
         dict(hp=110, speed=4.0, damage=6, heal_every=4, heal_amount=25, heal_radius=10)),
        ("robot_sniper", "Робот-снайпер", H(skin="#5a5f66", shirt="#2a2f36", pants="#1a1f26", mat="metal", eye="#ff3b30", extras=[robot_head("#2a2f36"), weapon("gun")]), dict(hp=90, speed=3.5, damage=24, reach=18.0, ranged=True)),
        ("robot_thief", "Робот-сборщик", H(s=0.8, skin="#8c949e", shirt="#2a6a9a", pants="#5a5f66", mat="metal", eye="#7ad8ff", extras=[robot_head("#2a6a9a", "#7ad8ff"), backpack("#3a3f47")],
                                         gait={"stride": 1.5, "duty": 0.45}), dict(hp=70, speed=8.0, damage=4, steal=8)),
        ("robot_factory", "Робот-фабрика", H(s=1.6, skin="#6a7078", shirt="#d8a020", pants="#3a3f47", mat="metal", bulk=1.5, eye="#ff3b30", extras=[robot_head("#d8a020"), antenna(), backpack("#3a3f47")]),
         dict(hp=700, speed=2.2, damage=30, radius=1.6, reach=2.4, summon="drone", summon_every=12, summon_n=2)),
    ]),
    ("alien", "Пришельцы", 12, [
        ("alien_grey", "Серый пришелец", H(skin="#a8b0b8", shirt="#7a8a98", pants="#5a6a78", head_k=1.5, arm_k=1.2, eye="#101010", extras=[big_eyes()]),
         dict(hp=90, speed=5.0, damage=14, teleport_every=7, teleport_range=30)),
        ("alien_warrior", "Пришелец-воин", H(s=1.2, skin="#6a9a8a", shirt="#2a4a4a", pants="#1a3a3a", head_k=1.3, arm_k=1.3, eye="#40ff80", extras=[big_eyes("#40ff80"), weapon("claws"), weapon("claws", side=-1)]),
         dict(hp=260, speed=5.5, damage=28, radius=1.0)),
        ("alien_medic", "Пришелец-лекарь", H(skin="#b8a8d8", shirt="#f4f4f4", pants="#8a7aa8", head_k=1.5, eye="#7ad8ff", extras=[big_eyes("#7ad8ff"), glow_aura("#7ad8ff")]),
         dict(hp=100, speed=4.5, damage=8, heal_every=4, heal_amount=30, heal_radius=12)),
        ("alien_flyer", "Пришелец-летун", H(skin="#7ab8a8", shirt="#3a6a6a", pants="#2a4a4a", head_k=1.4, eye="#40ff80", extras=[big_eyes("#40ff80"), bwings("#3a6a6a", "#a0f0e0", 1.6, "glass")]),
         dict(hp=120, speed=7.5, damage=16, fly=True, fly_height=4.0)),
        ("alien_abductor", "Пришелец-похититель", H(skin="#a8b0b8", shirt="#3a3a5a", pants="#2a2a4a", head_k=1.5, arm_k=1.3, eye="#101010", extras=[big_eyes(), antenna("#c0c4cc", "#b080ff")]),
         dict(hp=90, speed=6.5, damage=6, steal=8, teleport_every=8)),
        ("alien_gunner", "Пришелец-стрелок", H(skin="#8a9aa8", shirt="#2a3a4a", pants="#1a2a3a", head_k=1.4, eye="#ff4a2a", extras=[big_eyes("#ff4a2a"), weapon("gun")]),
         dict(hp=130, speed=4.5, damage=22, reach=16.0, ranged=True)),
        ("xeno", "Ксеноморф", H(s=1.2, skin="#1a1a22", shirt="#2a2a32", pants="#1a1a22", head_k=1.3, lean=26, arm_k=1.4, arm_amp=30, eye="#40ff80", extras=[horns("#3a3a42", 4), weapon("claws"), weapon("claws", side=-1)],
                                    gait={"stride": 1.8, "duty": 0.42}), dict(hp=220, speed=9.0, damage=26, radius=1.0)),
        ("alien_queen", "Матка пришельцев", H(s=2.0, skin="#2a3a32", shirt="#1a2a22", pants="#0a1a12", head_k=1.6, lean=14, arm_k=1.4, bulk=1.3, eye="#40ff80", extras=[crown("#40ff80"), horns("#3a4a42", 6, 1.5), weapon("claws")]),
         dict(hp=1800, speed=3.5, damage=55, radius=2.0, reach=3.0, summon="xeno", summon_every=16, summon_n=2)),
    ]),
]

# варианты силы: (суффикс названия, hp, урон, скорость, размер, цвет окраски, сила окраски, награда, день позже, вес)
TIERS = [
    ("", "", 1.0, 1.0, 1.0, 1.0, "#ffffff", 0.0, 1.0, 0, 1.0),
    ("_t2", "сильный", 1.8, 1.35, 1.05, 1.1, "#c03030", 0.35, 1.8, 3, 0.5),
    ("_t3", "элитный", 3.0, 1.8, 1.08, 1.2, "#7a30d0", 0.45, 3.0, 7, 0.25),
    ("_t4", "вожак", 5.0, 2.4, 1.1, 1.35, "#e0b020", 0.55, 5.0, 12, 0.08),
    ("_t5", "древний", 9.0, 3.2, 1.12, 1.55, "#202020", 0.6, 9.0, 18, 0.03),
]


def _build(spec):
    kind, kw = spec
    kw = dict(kw)
    if kind == "human":
        return humanoid(kw)
    if kind == "blob":
        return blob(kw)
    if kind == "dragon":
        return dragon(**kw)
    if kind == "insect":
        return insect(**kw)
    if kind == "worm":
        return worm_v(**kw)
    raise ValueError(kind)


def apply(models, enemies):
    """Добавить 96 моделей и ~490 монстров. Возвращает список id моделей (для детализации)."""
    made = []
    for fid, fname, day, kinds in FAMILIES:
        for ki, (kid, kname, spec, st) in enumerate(kinds):
            R, g = _build(spec)
            cat = "Монстры: " + fname
            m = AR.model(kname, R, g, cat)
            m["detail"] = "rigged" if spec[0] == "human" else "creature"
            models[kid] = m
            made.append(kid)
            boss = ki == len(kinds) - 1   # последний вид семейства — его глава
            for suf, tname, hk, dk, sk, sc, tint, tk, rk, dd, w in TIERS:
                eid = kid + suf
                base = dict(st)
                e = {
                    "name": kname + (" (" + tname + ")" if tname else ""),
                    "model": kid,
                    "family": fname,
                    "hp": round(base.pop("hp", 50) * hk),
                    "damage": round(base.pop("damage", 10) * dk, 1),
                    "speed": round(base.pop("speed", 4.0) * sk, 2),
                    "rate": base.pop("rate", 1.0),
                    "reach": base.pop("reach", 1.4),
                    "radius": round(base.pop("radius", 0.8) * sc, 2),
                    "scale": round(base.pop("scale", 1.0) * sc, 2),
                    "behavior": "nearest",
                    "reward": max(1, round((3 + day) * rk)),
                    "xp": max(1, round((2 + day * 0.5) * rk)),
                    "tint": tint, "tint_k": tk,
                    "spawn_weight": round(w * (0.25 if boss else 1.0) * (0.6 if "summon" in st else 1.0), 3),
                    "from_day": day + dd + (4 if boss else 0),
                    "spawn_leader": suf in ("_t4", "_t5") or boss,
                    "spawn_where": "both",
                    "drops": [{"item": "chitin" if spec[0] in ("insect", "worm") else "goo", "chance": min(1.0, 0.4 * rk), "min": 1, "max": max(1, round(rk))}],
                }
                e.update(base)
                if e.get("ranged"):
                    e["rate"] = 1.6
                enemies[eid] = e
    return made


def top_up(model, target=300):
    """Если деталей всё ещё меньше цели: бугорки, заклёпки и чешуйки по поверхности крупных деталей.
    Каждая новая деталь получает кость своей основы и двигается вместе с ней."""
    parts = model["parts"]
    if len(parts) >= target:
        return len(parts)
    hosts = [p for p in parts if p.get("shape") in ("sphere", "box", "cylinder", "capsule") and not p.get("anim")
             and min(p["size"]) >= 0.08 and max(p["size"]) >= 0.18 and abs(p.get("rot", [0, 0, 0])[0]) + abs(p.get("rot", [0, 0, 0])[2]) < 1]
    hosts.sort(key=lambda p: -(p["size"][0] * p["size"][1] + p["size"][1] * p["size"][2] + p["size"][0] * p["size"][2]))
    if not hosts:
        return len(parts)
    add = []
    ring = 0
    while len(parts) + len(add) < target and ring < 12:
        for h in hosts:
            if len(parts) + len(add) >= target:
                break
            sx, sy, sz = h["size"]
            px, py, pz = h["pos"]
            k = 6 + ring
            for i in range(k):
                if len(parts) + len(add) >= target:
                    break
                a = (i + ring * 0.37) / k * math.tau
                el = math.sin(ring * 1.7 + i * 0.9) * 0.6
                if h["shape"] == "box":
                    pos = (px + math.cos(a) * sx * 0.5, py + el * sy * 0.45, pz + math.sin(a) * sz * 0.5)
                else:
                    ce = math.cos(el)
                    pos = (px + math.cos(a) * sx * 0.5 * ce, py + math.sin(el) * sy * 0.5, pz + math.sin(a) * sz * 0.5 * ce)
                d = max(0.025, min(sx, sy, sz) * 0.09)
                q = {"shape": "sphere" if h.get("mat") != "metal" else "cylinder", "size": [round(d, 3), round(d * (0.6 if h.get("mat") == "metal" else 1.0), 3), round(d, 3)],
                     "pos": [round(v, 3) for v in pos], "rot": [0, 0, 0], "color": shade(h["color"], 0.82 if i % 2 else 1.15), "mat": h.get("mat", "flesh")}
                if h.get("role"):
                    q["role"] = h["role"]
                q["seg"] = 6
                add.append(q)
        ring += 1
    model["parts"] = parts + add
    return len(model["parts"])
