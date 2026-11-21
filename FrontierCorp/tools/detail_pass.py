# Проход детализации: «обвешивает» готовую модель здания мелкими деталями прямо по её поверхностям.
# Для каждой крупной неподвижной детали (ящик или цилиндр) на видимых гранях появляются болты, рамки панелей,
# решётки, таблички, приборы, заклёпки, бандажи и сварные швы — в системе координат самой детали,
# поэтому всё прилегает к поверхности даже у повёрнутых деталей. Плюс общие живые элементы: сигнальная
# колонна, мигающие индикаторы, вентиляторы. Детали добавляются, пока модель не наберёт нужное число частей.
# Движок склеивает неподвижные детали одного материала в одну сетку, а мелочь вдали не рисует — поэтому это не тормозит.
import math
from art_kit import P, shade, rot_matrix, euler_yxz, _mul, CHR, DARK

BOLT = "#8f959c"
LED = ("#40ff6a", "#ffb030", "#40c8ff", "#ff4040")
OK_MATS = ("paint", "metal", "dark", "concrete", "stone", "wood")

# сколько деталей нужно зданию по поведению (массовые куски — стены, ленты, трубы — остаются лёгкими)
TARGET = {"crafter": 300, "miner": 300, "generator": 300, "battery": 300, "hq": 300, "station": 300, "terminal": 300,
          "storage": 300, "tank": 300, "turret": 300, "vehicle": 300, "research": 300, "carrier": 300,
          "light": 120, "decor": 120, "splitter": 60, "merger": 60}


def _mv(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def _h(*a):
    """Детерминированный «случай» для выбора вида обвеса (чтобы сборка всегда давала одно и то же)."""
    s = 0
    for x in a:
        s = (s * 131 + int(round(x * 1000))) & 0xFFFFFF
    return (s * 2654435761 >> 8) % 1000 / 1000.0


class Host:
    """Деталь-основа: её положение, поворот и размер; всё ставится в её собственных осях."""

    def __init__(self, p):
        self.p = p
        self.pos = p["pos"]
        self.rot = p.get("rot", [0, 0, 0])
        self.R = rot_matrix(self.rot)
        self.size = p["size"]
        self.col = p.get("color", "#808080")
        self.mat = p.get("mat", "paint")

    def world(self, lp):
        w = _mv(self.R, lp)
        return [self.pos[i] + w[i] for i in range(3)]

    def part(self, shape, size, lp, color, mat="paint", axis=(0, 0, 0), **kw):
        """Деталь в осях основы: lp — положение, axis — свой доп. поворот (например, болт осью к грани)."""
        R = _mul(self.R, rot_matrix(axis)) if any(axis) else self.R
        rot = [math.degrees(v) for v in euler_yxz(R)] if any(axis) else self.rot
        return P(shape, size, self.world(lp), color, mat, rot=rot, **kw)


def _aabb(p):
    """Грубые границы детали в мире (по 8 углам)."""
    R = rot_matrix(p.get("rot", [0, 0, 0]))
    sx, sy, sz = p["size"]
    lo, hi = [1e9] * 3, [-1e9] * 3
    for dx in (-0.5, 0.5):
        for dy in (-0.5, 0.5):
            for dz in (-0.5, 0.5):
                w = _mv(R, [dx * sx, dy * sy, dz * sz])
                for i in range(3):
                    v = p["pos"][i] + w[i]
                    lo[i] = min(lo[i], v)
                    hi[i] = max(hi[i], v)
    return lo, hi


class Ctx:
    def __init__(self, parts, half):
        self.half = half
        self.boxes = [(_aabb(p), id(p)) for p in parts if p.get("shape") in ("box", "cylinder", "sphere", "capsule") and max(p["size"]) > 0.25]

    def covered(self, w, own):
        """Точка спрятана внутри другой крупной детали или вне клетки/под землёй — туда не ставим."""
        if w[1] < 0.03 or abs(w[0]) > self.half + 0.02 or abs(w[2]) > self.half + 0.02:
            return True
        for (lo, hi), pid in self.boxes:
            if pid == own:
                continue
            if all(lo[i] + 0.01 < w[i] < hi[i] - 0.01 for i in range(3)):
                return True
        return False


# ------------------------------------------------------------------ обвес граней ящика
# грань: (ось нормали, знак) -> (ось «ширины» u, ось «высоты» v)
FACES = [(0, 1, 2, 1), (0, -1, 2, 1), (2, 1, 0, 1), (2, -1, 0, 1), (1, 1, 0, 2)]
AXIS_ROT = {0: (0, 0, 90), 1: (0, 0, 0), 2: (90, 0, 0)}


def _lp(n, s, u, v, d, du, dv):
    """Точка на грани: d — отступ по нормали, du/dv — по осям грани."""
    p = [0.0, 0.0, 0.0]
    p[n] = s * d
    p[u] += du
    p[v] += dv
    return p


def _sz(n, u, v, sn, su, sv):
    s = [0.0, 0.0, 0.0]
    s[n], s[u], s[v] = sn, su, sv
    return s


def box_face_kit(h, ctx, face, level):
    """Грань ящика делится на панели ~0,55 м: у каждой рамка, болты и своя «начинка» (решётка, прибор, табличка, лампы)."""
    n, s, u, v = face
    S = h.size
    W, H, D = S[u], S[v], S[n] / 2
    out = []
    if ctx.covered(h.world(_lp(n, s, u, v, D + 0.03, 0, 0)), id(h.p)):
        return out
    wood = h.mat == "wood"
    frame = shade(h.col, 0.62)
    bolt_c = DARK if wood else BOLT
    for du in (-1, 1):
        for dv in (-1, 1):
            lp = _lp(n, s, u, v, D + 0.008, du * (W / 2 - 0.05), dv * (H / 2 - 0.05))
            if not ctx.covered(h.world(lp), id(h.p)):
                out.append(h.part("cylinder", (0.045, 0.022, 0.045), lp, bolt_c, "metal", axis=AXIS_ROT[n], seg=6))
    if W < 0.42 or H < 0.42:
        return out
    if wood:
        rows = max(2, min(8, int(H / 0.16)))
        for i in range(1, rows):
            out.append(h.part("box", _sz(n, u, v, 0.012, W - 0.04, 0.012), _lp(n, s, u, v, D + 0.002, 0, -H / 2 + i * H / rows), shade(h.col, 0.55), "wood"))
            for du in (-1, 1):
                out.append(h.part("sphere", (0.022, 0.022, 0.022), _lp(n, s, u, v, D + 0.003, du * (W / 2 - 0.06), -H / 2 + (i - 0.5) * H / rows), DARK, "metal", seg=6))
        return out
    nu = max(1, min(4, round(W / 0.55)))
    nv = max(1, min(4, round(H / 0.55)))
    cw, ch = (W - 0.08) / nu, (H - 0.08) / nv
    fw = 0.02
    for i in range(nu):
        for j in range(nv):
            cu = -W / 2 + 0.04 + cw * (i + 0.5)
            cv = -H / 2 + 0.04 + ch * (j + 0.5)
            if ctx.covered(h.world(_lp(n, s, u, v, D + 0.03, cu, cv)), id(h.p)):
                continue
            pw, ph = cw - 0.05, ch - 0.05
            for dv in (-1, 1):
                out.append(h.part("box", _sz(n, u, v, 0.014, pw, fw), _lp(n, s, u, v, D + 0.005, cu, cv + dv * ph / 2), frame, h.mat))
            for du in (-1, 1):
                out.append(h.part("box", _sz(n, u, v, 0.014, fw, ph - fw), _lp(n, s, u, v, D + 0.005, cu + du * pw / 2, cv), frame, h.mat))
            if pw >= 0.28 and ph >= 0.28:
                for du in (-1, 1):
                    for dv in (-1, 1):
                        out.append(h.part("sphere", (0.026, 0.026, 0.026), _lp(n, s, u, v, D + 0.006, cu + du * (pw / 2 - 0.035), cv + dv * (ph / 2 - 0.035)), bolt_c, "metal", seg=6))
            out += _panel_fill(h, n, s, u, v, D, cu, cv, pw, ph, _h(h.pos[0], h.pos[1], h.pos[2], n, s, i, j), ctx, level)
    return out


def _panel_fill(h, n, s, u, v, D, cu, cv, pw, ph, k, ctx, level):
    """Начинка одной панели."""
    out = []
    if pw < 0.26 or ph < 0.26:
        return out
    if n == 1:
        if k < 0.3 and h.world([0, h.size[1] / 2, 0])[1] > 0.6 and pw > 0.36 and ph > 0.36:
            return _roof_fan(h, ctx, n, s, u, v, D, cu, cv)
        if k < 0.6:
            out.append(h.part("box", (pw * 0.6, 0.025, ph * 0.6), _lp(n, s, u, v, D + 0.012, cu, cv), shade(h.col, 0.8), h.mat))
            out.append(h.part("box", (0.16, 0.03, 0.025), _lp(n, s, u, v, D + 0.035, cu, cv), CHR, "metal"))
        return out
    if k < 0.22:
        slats = max(3, min(6, int(ph * 0.6 / 0.05)))
        out.append(h.part("box", _sz(n, u, v, 0.02, pw * 0.7, ph * 0.6), _lp(n, s, u, v, D + 0.006, cu, cv), "#1b1c1f", "dark"))
        for i in range(slats):
            out.append(h.part("box", _sz(n, u, v, 0.03, pw * 0.66, 0.014), _lp(n, s, u, v, D + 0.018, cu, cv - ph * 0.25 + i * ph * 0.5 / max(1, slats - 1)), shade(h.col, 0.75), "metal"))
    elif k < 0.38:
        r = min(pw, ph) * 0.5
        out.append(h.part("cylinder", (r, 0.03, r), _lp(n, s, u, v, D + 0.015, cu, cv), "#1d1e21", "dark", axis=AXIS_ROT[n], seg=16))
        out.append(h.part("cylinder", (r * 0.8, 0.035, r * 0.8), _lp(n, s, u, v, D + 0.02, cu, cv), "#e9e4d0", "paint", axis=AXIS_ROT[n], seg=16, tint=False))
        out.append(h.part("box", _sz(n, u, v, 0.012, 0.012, r * 0.35), _lp(n, s, u, v, D + 0.04, cu, cv + r * 0.12), "#c02020", "paint", anim="jitter", tint=False))
    elif k < 0.52:
        cnt = max(2, min(6, int(pw / 0.07)))
        out.append(h.part("box", _sz(n, u, v, 0.014, pw * 0.8, 0.07), _lp(n, s, u, v, D + 0.006, cu, cv), "#141518", "dark"))
        for i in range(cnt):
            out.append(h.part("sphere", (0.032, 0.032, 0.032), _lp(n, s, u, v, D + 0.016, cu - pw * 0.35 + i * pw * 0.7 / max(1, cnt - 1), cv), LED[i % 4], "glow", anim="blink" if i % 2 else "pulse", tint=False))
    elif k < 0.66:
        out.append(h.part("box", _sz(n, u, v, 0.014, min(0.34, pw * 0.8), 0.1), _lp(n, s, u, v, D + 0.007, cu, cv + ph * 0.15), "#e6e4dc", "paint", tint=False))
        out.append(h.part("box", _sz(n, u, v, 0.016, min(0.26, pw * 0.6), 0.03), _lp(n, s, u, v, D + 0.011, cu, cv + ph * 0.15), "#2a2c30", "dark"))
        out.append(h.part("box", _sz(n, u, v, 0.014, min(0.3, pw * 0.7), 0.05), _lp(n, s, u, v, D + 0.007, cu, cv - ph * 0.2), "#f2b21f", "paint", tint=False))
    elif k < 0.78:
        # ручка-скоба и петли (дверца обслуживания)
        out.append(h.part("box", _sz(n, u, v, 0.03, 0.025, ph * 0.35), _lp(n, s, u, v, D + 0.03, cu + pw * 0.3, cv), CHR, "metal"))
        for dv in (-1, 1):
            out.append(h.part("box", _sz(n, u, v, 0.03, 0.02, 0.02), _lp(n, s, u, v, D + 0.018, cu + pw * 0.3, cv + dv * ph * 0.17), CHR, "metal"))
            out.append(h.part("cylinder", (0.03, 0.08, 0.03), _lp(n, s, u, v, D + 0.012, cu - pw * 0.45, cv + dv * ph * 0.3), DARK, "metal", seg=8))
    return out


def _roof_fan(h, ctx, n, s, u, v, D, du, dv):
    """Вентилятор на крыше: кожух, решётка и крутящиеся лопасти."""
    out = []
    base = _lp(n, s, u, v, D, du, dv)
    if ctx.covered(h.world([base[0], base[1] + 0.12, base[2]]), id(h.p)):
        return out
    out.append(h.part("cylinder", (0.3, 0.1, 0.3), _lp(n, s, u, v, D + 0.05, du, dv), shade(h.col, 0.7), "metal", seg=16))
    out.append(h.part("torus", (0.32, 0.06, 0.32), _lp(n, s, u, v, D + 0.1, du, dv), DARK, "dark", seg=16))
    out.append(h.part("cylinder", (0.06, 0.06, 0.06), _lp(n, s, u, v, D + 0.11, du, dv), CHR, "metal", seg=8, anim="spin"))
    for k in range(5):
        out.append(P("box", (0.24, 0.012, 0.05), h.world(_lp(n, s, u, v, D + 0.105, du, dv)), "#3a3d42", "metal", rot=[h.rot[0], h.rot[1] + k * 72, h.rot[2]], anim="spin"))
    for k in range(2):
        out.append(h.part("box", (0.3, 0.012, 0.012), _lp(n, s, u, v, D + 0.125, du, dv), DARK, "dark", axis=(0, 90 * k, 0)))
    return out


# ------------------------------------------------------------------ обвес цилиндров
def cyl_kit(h, ctx, level):
    out = []
    d = min(h.size[0], h.size[2])
    L = h.size[1]
    r = d / 2
    top = float(h.p.get("top", 1) or 1)
    bolt_c = DARK if h.mat == "wood" else BOLT
    # кольцо болтов по торцам
    nb = max(6, min(20, int(math.pi * d / 0.11)))
    for end in (1, -1):
        if end == 1 and top < 0.95:
            continue
        cap = [0, end * (L / 2 + 0.01), 0]
        if ctx.covered(h.world([0, end * (L / 2 + 0.03), 0]), id(h.p)):
            continue
        for i in range(nb):
            a = i * 2 * math.pi / nb
            out.append(h.part("cylinder", (0.04, 0.025, 0.04), [math.cos(a) * r * 0.82, cap[1], math.sin(a) * r * 0.82], bolt_c, "metal", seg=6))
    # бандажи и шов
    if L >= 0.5 and top >= 0.95:
        bands = 2 if L < 1.2 else 3
        for i in range(bands):
            y = -L / 2 + (i + 1) * L / (bands + 1)
            lp = [r + 0.01, y, 0]
            if ctx.covered(h.world(lp), id(h.p)):
                continue
            out.append(h.part("torus", (d + 0.07, 0.07, d + 0.07), [0, y, 0], shade(h.col, 0.6), "metal", seg=max(12, nb)))
            if level >= 2:
                for j in range(4):
                    a = j * math.pi / 2 + 0.4
                    out.append(h.part("sphere", (0.03, 0.03, 0.03), [math.cos(a) * (r + 0.035), y, math.sin(a) * (r + 0.035)], bolt_c, "metal", seg=6))
        if d >= 0.4:
            # рёбра жёсткости по окружности
            for j in range(8):
                a = j * math.pi / 4 + 0.2
                lp = [math.cos(a) * (r + 0.006), 0, math.sin(a) * (r + 0.006)]
                if not ctx.covered(h.world(lp), id(h.p)):
                    out.append(h.part("box", (0.02, L * 0.8, 0.045), lp, shade(h.col, 0.7), "metal", axis=(0, -math.degrees(a), 0)))
        if d >= 0.8 and L >= 1.0:
            out += _big_tank(h, ctx, r, L, bolt_c)
        seam = [r + 0.004, 0, 0]
        if not ctx.covered(h.world(seam), id(h.p)):
            out.append(h.part("box", (0.02, L * 0.92, 0.03), seam, shade(h.col, 0.8), h.mat))
    elif L >= 1.5:
        # высокая сужающаяся мачта: фланцы секций с кольцом болтов, люк внизу
        secs = int(L / 0.9)
        for i in range(1, secs + 1):
            y = -L / 2 + i * L / (secs + 1)
            rr = r * (1.0 - (1.0 - top) * (y + L / 2) / L)
            out.append(h.part("torus", (2 * rr + 0.08, 0.08, 2 * rr + 0.08), [0, y, 0], shade(h.col, 0.7), "metal", seg=16))
            for j in range(10):
                a = j * math.pi / 5
                out.append(h.part("sphere", (0.03, 0.03, 0.03), [math.cos(a) * (rr + 0.04), y + 0.03, math.sin(a) * (rr + 0.04)], bolt_c, "metal", seg=6))
        out.append(h.part("box", (0.04, 0.5, 0.26), [r * 0.97, -L / 2 + 0.4, 0], shade(h.col, 0.7), h.mat))
        out.append(h.part("box", (0.05, 0.12, 0.03), [r * 0.97 + 0.03, -L / 2 + 0.4, 0.07], CHR, "metal"))
    return out


def solar_cells(h):
    """Солнечная панель: сетка ячеек (тонкие серебристые линии) и рамка — двигается вместе с панелью."""
    sx, sy, sz = h.size
    an = h.p.get("anim", "")
    out = []
    nu, nv = max(2, min(8, round(sx / 0.16))), max(2, min(6, round(sz / 0.16)))
    for i in range(1, nu):
        out.append(h.part("box", (0.01, 0.006, sz * 0.96), [-sx / 2 + i * sx / nu, sy / 2 + 0.002, 0], "#c8ccd2", "metal", anim=an))
    for j in range(1, nv):
        out.append(h.part("box", (sx * 0.96, 0.006, 0.01), [0, sy / 2 + 0.002, -sz / 2 + j * sz / nv], "#c8ccd2", "metal", anim=an))
    for e in (-1, 1):
        out.append(h.part("box", (sx + 0.02, 0.02, 0.02), [0, 0, e * sz / 2], "#9aa2ac", "metal", anim=an))
        out.append(h.part("box", (0.02, 0.02, sz + 0.02), [e * sx / 2, 0, 0], "#9aa2ac", "metal", anim=an))
    return out


def _big_tank(h, ctx, r, L, bolt_c):
    """Большая ёмкость: заклёпочные швы, люк на болтах, смотровая трубка уровня и лестница."""
    out = []
    for a in (0.3, 2.4, 4.4):
        lp = [math.cos(a) * (r + 0.01), 0, math.sin(a) * (r + 0.01)]
        if ctx.covered(h.world(lp), id(h.p)):
            continue
        cnt = int(L * 0.85 / 0.1)
        for i in range(cnt):
            out.append(h.part("sphere", (0.026, 0.026, 0.026), [lp[0], -L * 0.42 + i * 0.1, lp[2]], bolt_c, "metal", seg=6))
    # люк
    a = 2.36
    c, s_ = math.cos(a), math.sin(a)
    y = -L / 2 + 0.45
    if not ctx.covered(h.world([c * (r + 0.05), y, s_ * (r + 0.05)]), id(h.p)):
        ax = (0, -math.degrees(a), 90)
        out.append(h.part("cylinder", (0.42, 0.05, 0.42), [c * (r + 0.02), y, s_ * (r + 0.02)], shade(h.col, 0.8), h.mat, axis=ax, seg=16))
        out.append(h.part("cylinder", (0.34, 0.06, 0.34), [c * (r + 0.04), y, s_ * (r + 0.04)], shade(h.col, 0.65), "metal", axis=ax, seg=16))
        for j in range(12):
            b = j * math.pi / 6
            # точка на окружности люка в плоскости, касательной к стенке
            tx, ty = math.cos(b) * 0.18, math.sin(b) * 0.18
            out.append(h.part("sphere", (0.03, 0.03, 0.03), [c * (r + 0.05) - s_ * tx, y + ty, s_ * (r + 0.05) + c * tx], bolt_c, "metal", seg=6))
        out.append(h.part("box", (0.04, 0.04, 0.2), [c * (r + 0.09), y, s_ * (r + 0.09)], CHR, "metal", axis=(0, -math.degrees(a) + 90, 0)))
    # смотровая трубка уровня
    a = 0.9
    c, s_ = math.cos(a), math.sin(a)
    if not ctx.covered(h.world([c * (r + 0.08), 0, s_ * (r + 0.08)]), id(h.p)):
        out.append(h.part("cylinder", (0.06, L * 0.6, 0.06), [c * (r + 0.08), 0, s_ * (r + 0.08)], "#40c8ff", "glow", anim="pulse", seg=8, tint=False))
        for e in (-1, 1):
            out.append(h.part("box", (0.12, 0.05, 0.05), [c * (r + 0.04), e * L * 0.31, s_ * (r + 0.04)], CHR, "metal", axis=(0, -math.degrees(a), 0)))
            out.append(h.part("torus", (0.1, 0.1, 0.1), [c * (r + 0.08), e * L * 0.31, s_ * (r + 0.08)], "#c02020", "paint", seg=10, tint=False))
    # лестница
    a = 4.0
    c, s_ = math.cos(a), math.sin(a)
    if not ctx.covered(h.world([c * (r + 0.12), 0, s_ * (r + 0.12)]), id(h.p)):
        tx, tz = -s_, c
        for e in (-1, 1):
            out.append(h.part("box", (0.03, L * 0.9, 0.03), [c * (r + 0.14) + tx * e * 0.13, 0.02, s_ * (r + 0.14) + tz * e * 0.13], "#f2b21f", "paint", tint=False))
        for i in range(int(L * 0.9 / 0.25)):
            out.append(h.part("box", (0.022, 0.022, 0.26), [c * (r + 0.14), -L * 0.43 + i * 0.25, s_ * (r + 0.14)], CHR, "metal", axis=(0, -math.degrees(a), 0)))
    return out


# ------------------------------------------------------------------ живые элементы всей постройки
def signal_tower(x, z, y0=0.0):
    a = [P("cylinder", (0.05, 0.6, 0.05), (x, y0 + 0.3, z), DARK, "dark", seg=8),
         P("cylinder", (0.12, 0.04, 0.12), (x, y0 + 0.02, z), DARK, "dark", seg=10)]
    for i, (c, an) in enumerate((("#40ff6a", "pulse"), ("#ffb030", "blink"), ("#ff4040", "blink"))):
        a.append(P("cylinder", (0.09, 0.08, 0.09), (x, y0 + 0.64 + i * 0.085, z), c, "glow", anim=an, seg=10, tint=False))
    a.append(P("cylinder", (0.1, 0.02, 0.1), (x, y0 + 0.9, z), DARK, "dark", seg=10))
    return a


# ------------------------------------------------------------------ вещи вокруг здания (на свободной земле)
WOODC, WOODD = "#a8743f", "#6e4a28"


def p_crates(x, z, k):
    a = []
    for i, (dx, dz, y, sz) in enumerate(((-0.06, 0.0, 0.0, 0.3), (0.1, 0.05, 0.0, 0.24), (-0.02, 0.0, 0.3, 0.22))):
        cx, cz, h = x + dx, z + dz, sz
        a.append(P("box", (sz, h, sz), (cx, y + h / 2, cz), WOODC, "wood"))
        for e in (-1, 1):
            a.append(P("box", (sz + 0.01, 0.03, 0.03), (cx, y + h / 2 + e * (h / 2 - 0.02), cz + sz / 2), WOODD, "wood"))
            a.append(P("box", (0.03, 0.03, sz + 0.01), (cx + sz / 2, y + h / 2 + e * (h / 2 - 0.02), cz), WOODD, "wood"))
        a.append(P("box", (0.03, h * 1.1, 0.012), (cx, y + h / 2, cz + sz / 2 + 0.006), WOODD, "wood", rot=(0, 0, 40)))
    return a


def p_barrels(x, z, k):
    a = []
    cols = ("#c03020", "#2f5fa8", "#3d8a3d", "#d8a020")
    for i, (dx, dz) in enumerate(((-0.1, -0.08), (0.1, -0.06), (0.0, 0.1))):
        c = cols[int(k * 4 + i) % 4]
        cx, cz = x + dx, z + dz
        a.append(P("cylinder", (0.18, 0.38, 0.18), (cx, 0.19, cz), c, "paint", seg=14))
        for y in (0.08, 0.3):
            a.append(P("torus", (0.19, 0.04, 0.19), (cx, y, cz), shade(c, 0.6), "metal", seg=14))
        a.append(P("cylinder", (0.16, 0.012, 0.16), (cx, 0.385, cz), shade(c, 0.8), "metal", seg=14))
        a.append(P("cylinder", (0.035, 0.02, 0.035), (cx + 0.04, 0.395, cz), CHR, "metal", seg=6))
    return a


def p_gas_rack(x, z, k):
    a = [P("box", (0.42, 0.04, 0.16), (x, 0.02, z), DARK, "dark"), P("box", (0.42, 0.03, 0.03), (x, 0.42, z - 0.07), DARK, "dark")]
    for e in (-1, 1):
        a.append(P("box", (0.03, 0.44, 0.03), (x + e * 0.2, 0.22, z - 0.07), DARK, "dark"))
    for i in range(3):
        cx = x - 0.13 + i * 0.13
        c = ("#3d8a3d", "#2f5fa8", "#d0d4d8")[i]
        a.append(P("cylinder", (0.11, 0.48, 0.11), (cx, 0.28, z), c, "paint", seg=12))
        a.append(P("sphere", (0.11, 0.08, 0.11), (cx, 0.52, z), c, "paint", seg=12))
        a.append(P("cylinder", (0.03, 0.06, 0.03), (cx, 0.58, z), CHR, "metal", seg=6))
        a.append(P("torus", (0.06, 0.06, 0.06), (cx, 0.61, z), DARK, "dark", seg=8))
    return a


def p_console(x, z, k):
    a = [P("box", (0.12, 0.6, 0.12), (x, 0.3, z), DARK, "dark"), P("box", (0.26, 0.04, 0.26), (x, 0.02, z), DARK, "dark"),
         P("box", (0.34, 0.05, 0.24), (x, 0.64, z), "#3a3d42", "metal", rot=(-25, 0, 0)),
         P("box", (0.2, 0.012, 0.1), (x, 0.672, z - 0.03), "#40c8ff", "glow", rot=(-25, 0, 0), anim="flicker_soft", tint=False)]
    for i in range(6):
        a.append(P("cylinder", (0.03, 0.02, 0.03), (x - 0.12 + (i % 3) * 0.05 + (0.17 if i >= 3 else 0) * 0, 0.67 + 0.0, z + 0.07 - (i // 3) * 0.04), LED[i % 4], "glow", rot=(-25, 0, 0), seg=8,
                   anim="blink" if i % 2 else "", tint=False))
    a.append(P("cylinder", (0.05, 0.03, 0.05), (x + 0.11, 0.68, z + 0.06), "#c02020", "paint", rot=(-25, 0, 0), seg=10, tint=False))
    return a


def p_extinguisher(x, z, k):
    return [P("box", (0.16, 0.5, 0.04), (x, 0.25, z - 0.06), "#c02020", "paint", tint=False),
            P("cylinder", (0.1, 0.32, 0.1), (x, 0.3, z), "#d42a20", "paint", seg=12, tint=False),
            P("sphere", (0.1, 0.07, 0.1), (x, 0.46, z), "#d42a20", "paint", seg=12, tint=False),
            P("box", (0.08, 0.03, 0.02), (x, 0.51, z), DARK, "dark"),
            P("cylinder", (0.015, 0.2, 0.015), (x + 0.06, 0.4, z), DARK, "dark", rot=(0, 0, 20), seg=6),
            P("box", (0.12, 0.02, 0.04), (x, 0.12, z), CHR, "metal")]


def p_spool(x, z, k):
    a = []
    for e in (-1, 1):
        a.append(P("cylinder", (0.4, 0.03, 0.4), (x, 0.2, z + e * 0.12), WOODC, "wood", rot=(90, 0, 0), seg=16))
    a.append(P("cylinder", (0.14, 0.24, 0.14), (x, 0.2, z), WOODD, "wood", rot=(90, 0, 0), seg=10))
    for i in range(3):
        a.append(P("torus", (0.28 - i * 0.02, 0.07, 0.28 - i * 0.02), (x, 0.2, z - 0.07 + i * 0.07), "#1d1e21", "dark", rot=(90, 0, 0), seg=16))
    a.append(P("box", (0.6, 0.03, 0.04), (x + 0.3, 0.015, z), "#1d1e21", "dark"))
    return a


def p_flood(x, z, k):
    return [P("cylinder", (0.16, 0.04, 0.16), (x, 0.02, z), DARK, "dark", seg=10),
            P("cylinder", (0.04, 0.9, 0.04), (x, 0.47, z), DARK, "dark", seg=8),
            P("box", (0.22, 0.14, 0.1), (x, 0.95, z), "#3a3d42", "metal", rot=(30, 0, 0)),
            P("box", (0.18, 0.1, 0.012), (x, 0.95, z + 0.05), "#fff1c4", "glow", rot=(30, 0, 0), anim="flicker_soft", tint=False),
            P("box", (0.03, 0.12, 0.03), (x, 0.88, z - 0.03), DARK, "dark")]


def p_toolbox(x, z, k):
    return [P("box", (0.3, 0.14, 0.16), (x, 0.07, z), "#c02020", "paint", tint=False),
            P("box", (0.31, 0.04, 0.17), (x, 0.16, z), "#a01a18", "paint", tint=False),
            P("box", (0.14, 0.03, 0.02), (x, 0.2, z), DARK, "dark"),
            P("box", (0.03, 0.04, 0.012), (x - 0.1, 0.13, z + 0.085), CHR, "metal"),
            P("box", (0.03, 0.04, 0.012), (x + 0.1, 0.13, z + 0.085), CHR, "metal"),
            P("box", (0.2, 0.02, 0.03), (x + 0.05, 0.01, z + 0.15), CHR, "metal", rot=(0, 30, 0))]


def p_junction(x, z, k):
    a = [P("box", (0.08, 0.7, 0.08), (x, 0.35, z), DARK, "dark"), P("box", (0.3, 0.36, 0.14), (x, 0.55, z + 0.08), "#7a8088", "metal"),
         P("box", (0.26, 0.32, 0.015), (x, 0.55, z + 0.155), "#8a9098", "metal"),
         P("box", (0.1, 0.1, 0.012), (x, 0.62, z + 0.165), "#f2b21f", "paint", tint=False),
         P("sphere", (0.035, 0.035, 0.035), (x + 0.09, 0.68, z + 0.165), "#40ff6a", "glow", anim="pulse", tint=False)]
    for i in range(3):
        a.append(P("cylinder", (0.035, 0.4, 0.035), (x - 0.08 + i * 0.08, 0.2, z + 0.1), "#1d1e21", "dark", seg=6))
    return a


def p_sacks(x, z, k):
    a = []
    for i in range(5):
        a.append(P("box", (0.5, 0.025, 0.07), (x, 0.03, z - 0.2 + i * 0.1), WOODC, "wood"))
    for e in (-1, 0, 1):
        a.append(P("box", (0.06, 0.04, 0.5), (x + e * 0.2, 0.0 + 0.02, z), WOODD, "wood"))
    for i, (dx, dz, y) in enumerate(((-0.12, -0.1, 0.12), (0.12, -0.1, 0.12), (0.0, 0.12, 0.12), (0.0, -0.02, 0.26))):
        a.append(P("capsule", (0.2, 0.3, 0.16), (x + dx, y, z + dz), "#c8b48a", "cloth", rot=(0, 0, 90)))
        a.append(P("torus", (0.06, 0.04, 0.06), (x + dx + 0.15, y, z + dz), "#8a6a40", "cloth", rot=(0, 0, 90), seg=8))
    return a


PROPS_IND = [(p_barrels, 0.28), (p_crates, 0.24), (p_gas_rack, 0.24), (p_console, 0.18), (p_spool, 0.26), (p_flood, 0.13),
             (p_junction, 0.17), (p_toolbox, 0.18), (p_extinguisher, 0.12)]
PROPS_WOOD = [(p_crates, 0.24), (p_sacks, 0.3), (p_barrels, 0.28), (p_spool, 0.26), (p_toolbox, 0.18)]


class Ground:
    """Где у здания свободная земля: сетка 0,1 м; занято всё, что стоит ниже 0,9 м."""

    def __init__(self, parts, half):
        self.half = half
        self.rects = []
        self.floors = []   # низкие широкие плиты (фундамент): на них можно ставить вещи
        for p in parts:
            lo, hi = _aabb(p)
            if hi[1] <= 0.36 and (hi[0] - lo[0]) * (hi[2] - lo[2]) > 0.5:
                self.floors.append((lo[0], lo[2], hi[0], hi[2], hi[1]))
            elif lo[1] < 0.9 + 0.36 and hi[1] > 0.06:
                self.rects.append((lo[0], lo[2], hi[0], hi[2]))

    def floor_y(self, x, z, r):
        y = 0.0
        for x0, z0, x1, z1, top in self.floors:
            if x0 <= x - r and x + r <= x1 and z0 <= z - r and z + r <= z1:
                y = max(y, top)
        return y

    def free(self, x, z, r):
        if abs(x) + r > self.half - 0.03 or abs(z) + r > self.half - 0.03:
            return False
        for x0, z0, x1, z1 in self.rects:
            if x + r > x0 and x - r < x1 and z + r > z0 and z - r < z1:
                return False
        return True

    def take(self, x, z, r):
        self.rects.append((x - r, z - r, x + r, z + r))


def edge_runs(parts, half, need):
    """Трубы и кабель-каналы вдоль свободных краёв площадки: фланцы, опоры, хомуты."""
    g = Ground(parts, half)
    out = []
    off = half - 0.1
    for side in range(4):
        if len(out) >= need:
            break
        # точки вдоль стороны
        ts = [-off + i * 0.05 for i in range(int(2 * off / 0.05) + 1)]
        def at(t):
            return (t, off) if side == 0 else (t, -off) if side == 1 else (off, t) if side == 2 else (-off, t)
        run = []
        runs = []
        for t in ts:
            x, z = at(t)
            if g.free(x, z, 0.05) and not (side >= 2 and abs(t) < 0.3):
                run.append(t)
            else:
                if len(run) >= 12:
                    runs.append((run[0], run[-1]))
                run = []
        if len(run) >= 12:
            runs.append((run[0], run[-1]))
        for t0, t1 in runs:
            L = t1 - t0
            (x0, z0), (x1, z1) = at(t0), at(t1)
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            along_x = side < 2
            y0 = g.floor_y(cx, cz, 0.0)
            y = y0 + 0.16
            col = ("#c03020", "#2f5fa8", "#d8a020", "#8c949e")[side]
            out.append(P("cylinder", (0.07, L, 0.07), (cx, y, cz), col, "metal", rot=(0, 0, 90) if along_x else (90, 0, 0), seg=10))
            n = max(2, int(L / 0.35))
            for i in range(n + 1):
                t = t0 + i * L / n
                x, z = at(t)
                out.append(P("cylinder", (0.11, 0.03, 0.11), (x, y, z), DARK, "dark", rot=(0, 0, 90) if along_x else (90, 0, 0), seg=10))
                out.append(P("box", (0.03, 0.14, 0.03), (x, y0 + 0.07, z), DARK, "dark"))
                out.append(P("box", (0.12, 0.02, 0.06) if not along_x else (0.06, 0.02, 0.12), (x, y0 + 0.01, z), DARK, "dark"))
            out.append(P("torus", (0.12, 0.14, 0.12), (cx, y + 0.1, cz), "#c02020", "paint", seg=10, tint=False))
            out.append(P("cylinder", (0.025, 0.08, 0.025), (cx, y + 0.05, cz), CHR, "metal", seg=6))
            for k in range(3):
                lx = x0 + (x1 - x0) * (0.2 + 0.3 * k)
                lz = z0 + (z1 - z0) * (0.2 + 0.3 * k)
                out.append(P("box", (0.04, 0.02, 0.04), (lx, y + 0.045, lz), "#f2b21f", "paint", tint=False))
    return out


def perimeter_rail(parts, half, need):
    """Ограждение по краю площадки (стойки, два поручня, жёлтые полосы); проёмы у входа и выхода лент."""
    g = Ground(parts, half)
    out = []
    e = half - 0.06
    for side in range(4):
        pts = []
        t = -e
        while t <= e + 1e-6:
            x, z = (t, e) if side == 0 else (t, -e) if side == 1 else (e, t) if side == 2 else (-e, t)
            ok = g.free(x, z, 0.02) and not (side >= 2 and abs(t) < 0.35)
            pts.append((t, x, z, ok))
            t += 0.25
        seg = []
        for t, x, z, ok in pts + [(0, 0, 0, False)]:
            if ok:
                seg.append((t, x, z))
                continue
            if len(seg) >= 2:
                y0 = g.floor_y(seg[0][1], seg[0][2], 0.0)
                for _, x, z in seg:
                    out.append(P("box", (0.035, 0.5, 0.035), (x, y0 + 0.25, z), "#f2b21f", "paint", tint=False))
                (t0, xa, za), (t1, xb, zb) = seg[0], seg[-1]
                cx, cz, L = (xa + xb) / 2, (za + zb) / 2, abs(t1 - t0)
                along_x = side < 2
                for y in (0.3, 0.5):
                    out.append(P("box", (L, 0.03, 0.03) if along_x else (0.03, 0.03, L), (cx, y0 + y, cz), "#f2b21f", "paint", tint=False))
                out.append(P("box", (L, 0.06, 0.012) if along_x else (0.012, 0.06, L), (cx, y0 + 0.04, cz), DARK, "dark"))
            seg = []
        if len(out) >= need:
            break
    return out


def place_props(parts, half, need, wood):
    """Расставить вещи на свободной земле вокруг здания, пока не наберём need деталей (или пока есть место)."""
    g = Ground(parts, half)
    lib = PROPS_WOOD if wood else PROPS_IND
    out = []
    step = 0.1
    pts = []
    n = int(2 * half / step)
    for i in range(n + 1):
        for j in range(n + 1):
            x, z = -half + i * step, -half + j * step
            # не загораживаем вход и выход лент (середины сторон по X)
            if abs(z) < 0.3 and abs(x) > half - 0.5:
                continue
            pts.append((x, z))
    pts.sort(key=lambda q: -max(abs(q[0]), abs(q[1])) + _h(q[0], q[1]) * 0.05)
    k = 0
    for x, z in pts:
        if len(out) >= need:
            break
        for t in range(len(lib)):
            fn, r = lib[(k + t) % len(lib)]
            if g.free(x, z, r):
                y0 = g.floor_y(x, z, r)
                for q in fn(x, z, _h(x, z)):
                    q["pos"][1] = round(q["pos"][1] + y0, 3)
                    out.append(q)
                g.take(x, z, r)
                k += 1
                break
    return out


# анимации, которые считаются по вершинам одинаково для всей модели: детали на такой части двигаются вместе с ней
HOST_ANIMS = ("sway", "bob")


def ground_rivets(half, n_side):
    a = []
    for i in range(n_side):
        t = -half + 0.08 + i * (2 * half - 0.16) / max(1, n_side - 1)
        for x, z in ((t, half - 0.04), (t, -half + 0.04), (half - 0.04, t), (-half + 0.04, t)):
            a.append(P("cylinder", (0.04, 0.02, 0.04), (x, 0.03, z), BOLT, "metal", seg=6))
    return a


def anchor_bolts(half, n):
    """Анкерные болты (шайба + гайка) по периметру площадки чуть внутри края."""
    a = []
    k = max(1, (n + 1) // 2)
    per = max(2, (k + 3) // 4)
    for side in range(4):
        for i in range(per):
            if len(a) >= n:
                return a
            t = -half + 0.2 + i * (2 * half - 0.4) / max(1, per - 1)
            x, z = ((t, half - 0.12), (t, -half + 0.12), (half - 0.12, t), (-half + 0.12, t))[side]
            a.append(P("cylinder", (0.07, 0.012, 0.07), (x, 0.012, z), "#5a5e66", "metal", seg=8))
            a.append(P("cylinder", (0.04, 0.04, 0.04), (x, 0.035, z), BOLT, "metal", seg=6))
    return a[:n]


def enrich(model, behavior, size=1, functional=False):
    """Добавить детали модели здания до цели по его поведению. functional — у здания есть блоки поведения
    (лаборатория, медпункт, площадка дронов): такое здание тоже рабочее, ему 300. Возвращает новое число деталей."""
    parts = model.get("parts", [])
    target = TARGET.get(behavior, 0)
    if functional:
        target = max(target, 300)
    if target == 0 or len(parts) >= target or model.get("glb"):
        return len(parts)
    half = float(size)
    ctx = Ctx(parts, half)
    hosts = []
    for p in parts:
        sx, sy, sz = p["size"]
        if p.get("shape") == "box" and p.get("mat") == "glass" and not p.get("role") and sy < 0.08 and sx * sz > 0.1:
            hosts.append(("cells", Host(p), sx * sz))
            continue
        # башня турели («head») тоже обвешивается — детали получают ту же роль и поворачиваются вместе с ней
        if (p.get("anim") and p.get("anim") not in HOST_ANIMS) or (p.get("role") and p.get("role") != "head") or p.get("mat", "paint") not in OK_MATS:
            continue
        sx, sy, sz = p["size"]
        head = p.get("role") == "head"
        mn = 0.2 if head else 0.3
        if p.get("shape") == "box" and max(sx, sy, sz) >= mn and sorted((sx, sy, sz))[1] >= mn * 0.7:
            hosts.append(("box", Host(p), sx * sy + sy * sz + sx * sz))
        elif p.get("shape") == "cylinder" and min(sx, sz) >= mn * 0.6 and sy >= 0.12:
            hosts.append(("cyl", Host(p), math.pi * min(sx, sz) * sy))
        elif p.get("shape") == "box" and sy >= 0.8 and max(sx, sz) <= 0.16 and min(sx, sz) >= 0.05:
            hosts.append(("rod", Host(p), sy * 0.1))
    hosts.sort(key=lambda t: -t[2])
    add = []
    # 1) живые элементы, если здание рабочее
    if target >= 300:
        add += signal_tower(-half + 0.14, half - 0.14)
    # 2) обвес деталей, от крупных к мелким; второй круг — гуще
    for level in (1, 2, 3):
        for kind, h, _ in hosts:
            if len(parts) + len(add) >= target:
                break
            n0 = len(add)
            _kit(add, kind, h, ctx, level)
            for d in add[n0:]:
                if h.p.get("role") == "head":
                    d["role"] = "head"
                if h.p.get("anim") in HOST_ANIMS:
                    d["anim"] = h.p["anim"]
            continue
            if kind == "box":
                for face in FACES:
                    add += box_face_kit(h, ctx, face, level) if level == 1 else _edge_rivets(h, ctx, face) if level == 2 else _edge_rivets_h(h, ctx, face)
            elif kind == "cells" and level == 1:
                add += solar_cells(h)
            elif kind == "cyl" and level == 1:
                add += cyl_kit(h, ctx, 2)
            elif kind == "cyl" and level == 3:
                add += _cyl_rings(h, ctx)
    # 3) если всё ещё мало — бочки, ящики, баллоны, пульты, прожекторы на свободной земле вокруг
    left = target - len(parts) - len(add)
    if left > 0 and target >= 300:
        wood = sum(1 for p in parts if p.get("mat") == "wood") > len(parts) * 0.3
        add += place_props(parts + add, half, left, wood)
    left = target - len(parts) - len(add)
    if left > 0 and target >= 300:
        add += edge_runs(parts + add, half, left)
    left = target - len(parts) - len(add)
    if left > 0 and target >= 300:
        add += perimeter_rail(parts + add, half, left)
    # 4) последний запас — один ряд заклёпок по краю плиты
    if len(parts) + len(add) < target and target >= 300:
        add += ground_rivets(half, 8)
    # если и этого мало — анкерные болты с шайбами по краю площадки, сколько не хватает
    left = target - len(parts) - len(add)
    if left > 0 and target >= 300:
        add += anchor_bolts(half, min(left, 32))
    model["parts"] = parts + add
    return len(model["parts"])


def _kit(add, kind, h, ctx, level):
    if kind == "box":
        for face in FACES:
            add += box_face_kit(h, ctx, face, level) if level == 1 else _edge_rivets(h, ctx, face) if level == 2 else _edge_rivets_h(h, ctx, face)
    elif kind == "cells" and level == 1:
        add += solar_cells(h)
    elif kind == "cyl" and level == 1:
        # лестницы, рёбра и люки рассчитаны на стоячий бак; у лежачего цилиндра (ствол) — только кольца и швы
        if abs(h.R[1][1]) > 0.95:
            add += cyl_kit(h, ctx, 2)
    elif kind == "rod" and level == 1:
        add += _rod_kit(h)
    elif kind == "cyl" and level == 2:
        add += _cyl_panels(h, ctx)
    elif kind == "cyl" and level == 3:
        add += _cyl_rings(h, ctx)


def _rod_kit(h):
    """Тонкая стойка: хомуты через равные промежутки и светящаяся жила вдоль."""
    sx, sy, sz = h.size
    out = []
    n = max(3, min(10, int(sy / 0.16)))
    for i in range(n):
        y = -sy / 2 + (i + 0.5) * sy / n
        out.append(h.part("box", (sx + 0.025, 0.03, sz + 0.025), [0, y, 0], shade(h.col, 0.7), "metal"))
    out.append(h.part("box", (0.018, sy * 0.85, 0.018), [sx / 2 + 0.01, 0, 0], "#5ecbff", "glow"))
    return out


def _cyl_panels(h, ctx):
    """Второй круг для цилиндров: швы панелей по боковой стенке, огоньки между ними и болты по верхнему торцу."""
    d = min(h.size[0], h.size[2])
    L = h.size[1]
    top = float(h.p.get("top", 1) or 1)
    if top < 0.95 or d < 0.5:
        return []
    r = d / 2
    out = []
    n = max(6, min(20, int(math.pi * d / 0.32)))
    for i in range(n):
        a = (i + 0.5) * 2 * math.pi / n
        lp = [math.cos(a) * (r + 0.006), 0, math.sin(a) * (r + 0.006)]
        if ctx.covered(h.world(lp), id(h.p)):
            continue
        out.append(h.part("box", (0.025, L * 0.8, 0.025), lp, shade(h.col, 0.6), "dark"))
        if i % 2 == 0 and L >= 0.2:
            a2 = a + math.pi / n
            lp2 = [math.cos(a2) * (r + 0.008), L * 0.3, math.sin(a2) * (r + 0.008)]
            out.append(h.part("box", (0.03, 0.03, 0.03), lp2, ("#40ff8a", "#ffb030", "#5ecbff")[i % 3], "glow", anim="blink" if i % 4 == 0 else ""))
    nb = max(8, min(24, int(math.pi * d / 0.12)))
    for i in range(nb):
        a = i * 2 * math.pi / nb
        lp = [math.cos(a) * (r - 0.05), L / 2 + 0.008, math.sin(a) * (r - 0.05)]
        if not ctx.covered(h.world(lp), id(h.p)):
            out.append(h.part("cylinder", (0.035, 0.016, 0.035), lp, BOLT, "metal", seg=6))
    return out


def _edge_rivets(h, ctx, face):
    """Второй круг: ряды заклёпок по вертикальным кромкам граней."""
    n, s, u, v = face
    if n == 1:
        return []
    S = h.size
    W, H, D = S[u], S[v], S[n] / 2
    if H < 0.35 or ctx.covered(h.world(_lp(n, s, u, v, D + 0.03, 0, 0)), id(h.p)):
        return []
    out = []
    cnt = max(3, int((H - 0.2) / 0.09))
    for du in (-1, 1):
        for i in range(cnt):
            out.append(h.part("sphere", (0.024, 0.024, 0.024), _lp(n, s, u, v, D + 0.004, du * (W / 2 - 0.035), -H / 2 + 0.1 + i * (H - 0.2) / max(1, cnt - 1)),
                              DARK if h.mat == "wood" else BOLT, "metal", seg=6))
    return out


def _edge_rivets_h(h, ctx, face):
    """Третий круг: ряды заклёпок по верхней и нижней кромке боковых граней."""
    n, s, u, v = face
    if n == 1:
        return []
    S = h.size
    W, H, D = S[u], S[v], S[n] / 2
    if W < 0.35 or H < 0.25 or ctx.covered(h.world(_lp(n, s, u, v, D + 0.03, 0, 0)), id(h.p)):
        return []
    out = []
    cnt = max(3, int((W - 0.2) / 0.09))
    for dv in (-1, 1):
        for i in range(cnt):
            lp = _lp(n, s, u, v, D + 0.004, -W / 2 + 0.1 + i * (W - 0.2) / max(1, cnt - 1), dv * (H / 2 - 0.03))
            if not ctx.covered(h.world(lp), id(h.p)):
                out.append(h.part("sphere", (0.022, 0.022, 0.022), lp, DARK if h.mat == "wood" else BOLT, "metal", seg=6))
    return out


def _cyl_rings(h, ctx):
    """Третий круг для цилиндров: кольца заклёпок у торцов по боковой стенке."""
    d = min(h.size[0], h.size[2])
    L = h.size[1]
    top = float(h.p.get("top", 1) or 1)
    if top < 0.95 or L < 0.3:
        return []
    r = d / 2
    out = []
    nb = max(8, min(24, int(math.pi * d / 0.09)))
    for y in (-L / 2 + 0.05, L / 2 - 0.05):
        for i in range(nb):
            a = i * 2 * math.pi / nb
            lp = [math.cos(a) * (r + 0.004), y, math.sin(a) * (r + 0.004)]
            if not ctx.covered(h.world(lp), id(h.p)):
                out.append(h.part("sphere", (0.022, 0.022, 0.022), lp, BOLT, "metal", seg=6))
    return out


def enrich_rigged(model, target=300):
    """Герой и НПС с костями (role у деталей): обвес панелями, болтами и заклёпками на их ящиках и цилиндрах.
    Каждая новая деталь получает кость своей основы, поэтому двигается вместе с рукой, ногой или головой."""
    parts = model.get("parts", [])
    if len(parts) >= target:
        return len(parts)
    ctx = Ctx(parts, 99.0)
    hosts = []
    for p in parts:
        if p.get("anim", "") not in ("", "bob", "hover") or p.get("mat", "paint") not in OK_MATS + ("cloth", "flesh"):
            continue
        sx, sy, sz = p["size"]
        if p.get("shape") == "box" and max(sx, sy, sz) >= 0.12 and sorted((sx, sy, sz))[1] >= 0.08:
            hosts.append(("box", Host(p), sx * sy + sy * sz + sx * sz))
        elif p.get("shape") == "cylinder" and min(sx, sz) >= 0.1:
            hosts.append(("cyl", Host(p), math.pi * min(sx, sz) * sy))
    hosts.sort(key=lambda t: -t[2])
    add = []
    for level in (1, 2, 3):
        for kind, h, _ in hosts:
            if len(parts) + len(add) >= target:
                break
            new = []
            if kind == "box":
                for face in FACES:
                    new += _small_face_kit(h, ctx, face) if level == 1 else _edge_rivets(h, ctx, face) if level == 2 else _edge_rivets_h(h, ctx, face)
            elif level == 1:
                new += _cyl_rings(h, ctx)
            role = h.p.get("role", "")
            an = h.p.get("anim", "")
            for d in new:
                if role:
                    d["role"] = role
                if an and not d.get("anim"):
                    d["anim"] = an
            add += new
    model["parts"] = parts + add
    return len(model["parts"])


def _small_face_kit(h, ctx, face):
    """Мелкий обвес для брони и одежды: болты по углам, кант, иногда огонёк."""
    n, s, u, v = face
    S = h.size
    W, H, D = S[u], S[v], S[n] / 2
    if W < 0.08 or H < 0.08 or ctx.covered(h.world(_lp(n, s, u, v, D + 0.02, 0, 0)), id(h.p)):
        return []
    out = []
    b = min(0.03, min(W, H) * 0.18)
    for du in (-1, 1):
        for dv in (-1, 1):
            out.append(h.part("sphere", (b, b, b), _lp(n, s, u, v, D + 0.003, du * (W / 2 - b), dv * (H / 2 - b)), BOLT, "metal", seg=6))
    if W >= 0.14 and H >= 0.14:
        out.append(h.part("box", _sz(n, u, v, 0.01, W * 0.8, 0.012), _lp(n, s, u, v, D + 0.004, 0, H * 0.3), shade(h.col, 0.6), h.mat))
        out.append(h.part("box", _sz(n, u, v, 0.01, W * 0.8, 0.012), _lp(n, s, u, v, D + 0.004, 0, -H * 0.3), shade(h.col, 0.6), h.mat))
        if _h(h.pos[0], h.pos[1], n, s) < 0.25:
            out.append(h.part("box", _sz(n, u, v, 0.012, W * 0.3, 0.02), _lp(n, s, u, v, D + 0.006, 0, 0), "#40c8ff", "glow", anim="pulse", tint=False))
    return out
