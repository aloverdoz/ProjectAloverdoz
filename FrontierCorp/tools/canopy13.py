"""1.3: навес у штаба — укрытие от кислотного дождя, выброса и прочих бурь (factory._update_canopy, events._collect_shelters).
Модель из простых форм: тёмные стойки, оранжевая крыша корпорации со светящейся кромкой, лампа, скамейка и кадка с кустом.
Локальные оси: +X — от стены штаба наружу, начало — у стены на земле."""

DARK = "#2b3138"
STEEL = "#8a949e"
ORANGE = "#e8742a"
GLOW = "#ffd27a"
WOOD = "#9a6a3e"


def P(shape, size, pos, color, mat="paint", rot=(0, 0, 0), **kw):
    d = {"shape": shape, "size": list(size), "pos": list(pos), "rot": list(rot), "color": color, "mat": mat}
    d.update(kw)
    return d


def model():
    parts = []
    # пол — бетонная плита с тонкой оранжевой разметкой по краю
    parts.append(P("box", (3.9, 0.16, 4.0), (1.95, 0.08, 0), "#6f747a", "paint", surface="concrete", bevel=0.02))
    parts.append(P("box", (0.08, 0.17, 4.0), (3.86, 0.085, 0), ORANGE, "paint"))
    # стойки с опорными пластинами и кронштейнами
    for z in (-1.8, 1.8):
        parts.append(P("box", (0.36, 0.05, 0.36), (3.2, 0.1, z), DARK, "dark", bevel=0.02))
        parts.append(P("cylinder", (0.16, 2.55, 0.16), (3.2, 1.37, z), DARK, "metal"))
        parts.append(P("box", (0.9, 0.1, 0.1), (2.8, 2.45, z), DARK, "metal", rot=(0, 0, 32)))
    # балка у стены и наружная балка
    parts.append(P("box", (0.2, 0.22, 4.3), (0.12, 3.0, 0), DARK, "metal", bevel=0.02))
    parts.append(P("box", (0.18, 0.2, 4.3), (3.2, 2.66, 0), DARK, "metal", bevel=0.02))
    # поперечные рёбра
    for z in (-1.4, 0.0, 1.4):
        parts.append(P("box", (3.3, 0.08, 0.08), (1.66, 2.88, z), STEEL, "metal", rot=(0, 0, -6)))
    # крыша — чуть наклонённая оранжевая панель с ламелями, светящаяся кромка
    parts.append(P("box", (3.7, 0.1, 4.5), (1.8, 3.02, 0), ORANGE, "paint", rot=(0, 0, -6), bevel=0.03))
    for i in range(5):
        parts.append(P("box", (3.6, 0.05, 0.12), (1.8, 3.1 - 0.0, -1.8 + i * 0.9), "#c55f1f", "paint", rot=(0, 0, -6)))
    parts.append(P("box", (0.06, 0.06, 4.5), (3.64, 2.83, 0), GLOW, "glow"))
    # тёплая лампа под крышей
    parts.append(P("cylinder", (0.04, 0.3, 0.04), (1.8, 2.72, 0), DARK, "metal"))
    parts.append(P("cylinder", (0.42, 0.12, 0.42), (1.8, 2.56, 0), DARK, "metal", top=0.6))
    parts.append(P("sphere", (0.22, 0.16, 0.22), (1.8, 2.48, 0), GLOW, "glow"))
    # скамейка вдоль стены
    parts.append(P("box", (0.5, 0.07, 2.2), (0.55, 0.48, -0.6), WOOD, "paint", surface="wood", bevel=0.015))
    parts.append(P("box", (0.07, 0.45, 2.2), (0.32, 0.78, -0.6), WOOD, "paint", surface="wood", bevel=0.015))
    for z in (-1.55, 0.35):
        parts.append(P("box", (0.45, 0.44, 0.07), (0.55, 0.22, z), DARK, "metal"))
    # кадка с кустом у стойки
    parts.append(P("cylinder", (0.55, 0.45, 0.55), (2.6, 0.3, 1.45), "#3c4047", "dark", top=1.15))
    parts.append(P("sphere", (0.75, 0.6, 0.75), (2.6, 0.8, 1.45), "#4f8a3a", "paint", surface="leaf"))
    parts.append(P("sphere", (0.45, 0.4, 0.45), (2.4, 1.05, 1.3), "#62a446", "paint", surface="leaf"))
    # табличка корпорации на стойке
    parts.append(P("box", (0.05, 0.36, 0.7), (3.32, 1.7, -1.8), "#1d2228", "dark"))
    parts.append(P("box", (0.03, 0.08, 0.56), (3.36, 1.78, -1.8), GLOW, "glow"))
    parts.append(P("box", (0.03, 0.05, 0.36), (3.36, 1.62, -1.8), ORANGE, "paint"))
    return {"name": "Навес у штаба", "category": "Декор", "parts": parts}


def apply(models, settings):
    models["hq_canopy"] = model()
    settings.setdefault("hq_canopy", True)
    settings.setdefault("hq_canopy_radius", 2.1)
    return len(models["hq_canopy"]["parts"])
