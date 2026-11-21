# Проход детализации для существ: чешуя, шипы по хребту, наросты, светящиеся гнойники, когти и зубы.
# Каждая деталь ставится на поверхность части тела (эллипсоид шара или капсулы) и смотрит наружу по нормали.
# Детали берут анимацию своей части тела (покачивание, дыхание), поэтому двигаются вместе с ней.
# Ноги с анимацией шага не обвешиваются: их детали вращались бы вокруг своей оси и отрывались.
import math
from art_kit import P, shade, rot_matrix, euler_yxz, _mul

BODY_MATS = ("flesh", "paint", "dark", "metal", "leg", "stone", "cloth", "leaf", "wood")
OK_ANIMS = ("", "bob", "breathe", "hover", "sway")


def _mv(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def _norm(v):
    l = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / l for c in v]


def _cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _rot_to(n, spin=0.0):
    """Поворот (градусы YXZ), при котором ось Y детали смотрит по n."""
    y = _norm(n)
    ref = [0, 0, 1] if abs(y[2]) < 0.9 else [1, 0, 0]
    x = _norm(_cross(y, ref))
    z = _cross(x, y)
    m = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    if spin:
        m = _mul(m, rot_matrix((0, spin, 0)))
    return [round(math.degrees(v), 2) for v in euler_yxz(m)]


class Body:
    def __init__(self, p):
        self.p = p
        self.R = rot_matrix(p.get("rot", [0, 0, 0]))
        self.a = [s / 2 for s in p["size"]]
        self.anim = p.get("anim", "")
        self.col = p.get("color", "#808080")

    def surf(self, theta, phi, out=0.0):
        """Точка на поверхности (theta — по длине от -1 до 1, phi — угол вокруг) и нормаль в мире."""
        a = self.a
        shape = self.p.get("shape", "sphere")
        if shape in ("cone", "cylinder"):
            # боковая поверхность: у конуса радиус сходит на нет к верху
            y = theta * a[1]
            k = (0.5 - theta * 0.5) if shape == "cone" else 1.0
            lp = [math.cos(phi) * a[0] * k, y, math.sin(phi) * a[2] * k]
            slope = (a[0] / max(1e-4, 2 * a[1])) if shape == "cone" else 0.0
            nl = _norm([math.cos(phi), slope, math.sin(phi)])
        else:
            ct = theta
            st = math.sqrt(max(0.0, 1 - ct * ct))
            u = [st * math.cos(phi), ct, st * math.sin(phi)]
            lp = [u[i] * a[i] for i in range(3)]
            nl = _norm([lp[i] / max(1e-4, a[i] * a[i]) for i in range(3)])
        nw = _norm(_mv(self.R, nl))
        w = _mv(self.R, lp)
        pos = [self.p["pos"][i] + w[i] + nw[i] * out for i in range(3)]
        return pos, nw

    def up_axis(self):
        """Какая локальная ось детали смотрит в мире вверх сильнее всего (у лежачей капсулы — не Y)."""
        best, bi = -2, 1
        for i in range(3):
            ax = [self.R[0][i], self.R[1][i], self.R[2][i]]
            if abs(ax[1]) > best:
                best, bi = abs(ax[1]), i
        return bi


def _part(shape, size, pos, n, color, mat, anim, spin=0.0, **kw):
    return P(shape, size, pos, color, mat, rot=_rot_to(n, spin), anim=anim, **kw)


def scales(b, rows, cols, size, color, mat):
    """Чешуя или пластины брони: сплюснутые полусферы, верхняя часть тела."""
    out = []
    for i in range(rows):
        th = -0.75 + 1.5 * (i + 0.5) / rows
        for j in range(cols):
            ph = 2 * math.pi * (j + (0.5 if i % 2 else 0)) / cols
            pos, n = b.surf(th, ph, 0.0)
            if n[1] < -0.2:
                continue
            out.append(_part("sphere", (size, size * 0.28, size * 0.85), pos, n, color, mat, b.anim, seg=6))
    return out


def ridge(b, count, length, color, mat="dark"):
    """Шипы вдоль хребта (по верху тела)."""
    out = []
    for i in range(count):
        th = -0.8 + 1.6 * (i + 0.5) / count
        best = None
        for k in range(12):
            pos, n = b.surf(th, k * math.pi / 6)
            if best is None or pos[1] > best[0][1]:
                best = (pos, n)
        pos, n = best
        L = length * (0.6 + 0.4 * math.sin(math.pi * (i + 0.5) / count))
        tip = [pos[i2] + n[i2] * L * 0.45 for i2 in range(3)]
        out.append(_part("cone", (L * 0.32, L, L * 0.32), tip, n, color, mat, b.anim, seg=6))
    return out


def pustules(b, count, color, seed):
    out = []
    for i in range(count):
        th = math.sin(seed * 3.1 + i * 2.3) * 0.7
        ph = seed + i * 2.399
        pos, n = b.surf(th, ph)
        s = 0.05 + 0.03 * ((i * 7 + seed) % 3)
        out.append(_part("sphere", (s, s * 0.7, s), pos, n, color, "glow", "pulse" if b.anim in ("", "bob", "hover") else b.anim, seg=8, tint=False))
        out.append(_part("torus", (s * 1.5, s * 0.6, s * 1.5), pos, n, shade(b.col, 0.6), "flesh", b.anim, seg=8))
    return out


def bands(b, count, color, mat):
    """Кольцевые складки или сегменты панциря поперёк тела."""
    out = []
    ax = b.up_axis()
    # ось длины — самая длинная из двух «горизонтальных»
    for i in range(count):
        th = -0.7 + 1.4 * (i + 0.5) / count
        for k in range(10):
            pos, n = b.surf(th, k * math.pi / 5)
            if n[1] < -0.3:
                continue
            out.append(_part("box", (0.07, 0.025, 0.05), pos, n, color, mat, b.anim, spin=0))
    return out


def enrich_creature(model, target=300, seed=1):
    parts = model.get("parts", [])
    if len(parts) >= target or model.get("glb"):
        return len(parts)
    bodies = []
    for p in parts:
        if (p.get("role") and not str(p.get("role")).startswith("b:")) or p.get("anim", "") not in OK_ANIMS or p.get("mat", "paint") not in BODY_MATS:
            continue
        if p.get("shape") not in ("sphere", "capsule") or max(p["size"]) < 0.18:
            continue
        a = p["size"]
        bodies.append((a[0] * a[1] + a[1] * a[2] + a[0] * a[2], Body(p)))
    bodies.sort(key=lambda t: -t[0])
    add = []
    for k, (area, b) in enumerate(bodies):
        if len(parts) + len(add) >= target:
            break
        big = max(b.a) * 2
        n0 = len(add)
        dark = shade(b.col, 0.8)
        light = shade(b.col, 1.12)
        cloth = b.p.get("mat") == "cloth"
        if cloth:
            # одежда: швы-строчки и пуговицы/заклёпки
            add += bands(b, 3 if big > 0.4 else 2, shade(b.col, 0.7), "cloth")
            _bone(add, n0, b)
            continue
        r = max(3, min(7, int(big / 0.12)))
        c = max(8, min(18, int(big / 0.06)))
        add += scales(b, r, c, max(0.05, min(0.14, big / 7)), dark if k % 2 == 0 else light, b.p.get("mat", "flesh"))
        if k < 3:
            add += ridge(b, max(4, min(10, int(big / 0.1))), min(0.35, big * 0.35), shade(b.col, 0.4), "dark")
        add += pustules(b, 3 if big > 0.4 else 1, "#b6ff4a" if k % 2 == 0 else "#ffb030", seed + k)
        if big > 0.35:
            add += bands(b, 3, shade(b.col, 0.5), "dark")
        _bone(add, n0, b)
    # не добрали — ещё наросты на крупных частях тела
    k = 0
    while bodies and len(parts) + len(add) < target and k < 40:
        b = bodies[k % len(bodies)][1]
        n0 = len(add)
        add += pustules(b, 1, "#b6ff4a" if k % 2 == 0 else "#ffb030", seed + 50 + k)
        _bone(add, n0, b)
        k += 1
    model["parts"] = parts + add
    return len(model["parts"])


def _bone(add, n0, b):
    """Детали обвеса привязываются к кости своей части тела (у монстров со скелетом)."""
    role = b.p.get("role", "")
    if role:
        for d in add[n0:]:
            d["role"] = role
