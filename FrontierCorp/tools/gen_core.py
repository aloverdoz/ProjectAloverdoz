# Генератор базового контента игры (core/*.json).
# Запуск: python3 tools/gen_core.py
# Всё, что здесь описано, потом можно менять во встроенном редакторе игры.
import json, os, math

OUT = os.path.join(os.path.dirname(__file__), "..", "core")
os.makedirs(OUT, exist_ok=True)

def P(shape, size, pos, color, mat="paint", rot=(0, 0, 0), anim="", role="", tint=True, top=None, seg=None):
    d = {"shape": shape, "size": list(size), "pos": list(pos), "rot": list(rot), "color": color, "mat": mat}
    if anim: d["anim"] = anim
    if role: d["role"] = role
    if not tint: d["tint"] = False
    if top is not None: d["top"] = top
    if seg is not None: d["seg"] = seg
    return d

def M(name, parts, cat="Разное"):
    return {"name": name, "category": cat, "parts": parts}

YEL, STEEL, DARK, CONC = "#f2a81f", "#8c949e", "#292b30", "#9e9c91"
models = {}

# ------------------------------------------------------------------ здания
models["belt"] = M("Конвейер", [
    P("box", (2.0, 0.26, 1.3), (0, 0.13, 0), "#6b7079", "belt"),
    P("box", (0.2, 0.1, 1.45), (-0.85, 0.05, 0), DARK, "dark"),
], "Логистика")
# Стык ленты со зданием: рамка-люк на стене здания и мостик до ленты.
# Ось +x смотрит от здания к ленте. Детали с ролью stretch тянутся до ленты,
# с ролью port_color красятся в цвет входа или выхода (настройки игры).
models["belt_port"] = M("Стык ленты со зданием", [
    P("box", (1.0, 0.24, 1.3), (0.5, 0.12, 0), "#5d636c", "paint", role="stretch"),
    P("box", (1.0, 0.07, 0.1), (0.5, 0.27, 0.62), DARK, "paint", role="stretch"),
    P("box", (1.0, 0.07, 0.1), (0.5, 0.27, -0.62), DARK, "paint", role="stretch"),
    P("box", (0.14, 0.66, 1.62), (0.02, 0.33, 0), "#3a3f47", "paint"),
    P("box", (0.16, 0.4, 1.2), (0.03, 0.3, 0), "#121417", "concrete", tint=False),
    P("box", (0.17, 0.08, 1.62), (0.03, 0.62, 0), "#f2a81f", "paint", role="port_color", tint=False),
], "Логистика")
models["splitter"] = M("Разделитель", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.2, 0.6, 1.2), (0, 0.6, 0), "#d68a1a", "paint"),
    P("prism", (0.5, 0.35, 0.2), (0.45, 1.0, 0), "#ffd040", "glow", rot=(-90, 0, -90)),
    P("prism", (0.5, 0.35, 0.2), (0, 1.0, 0.45), "#ffd040", "glow", rot=(-90, 0, 0)),
    P("prism", (0.5, 0.35, 0.2), (0, 1.0, -0.45), "#ffd040", "glow", rot=(90, 0, 0)),
], "Логистика")
models["merger"] = M("Соединитель", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.2, 0.6, 1.2), (0, 0.6, 0), "#2f8fd6", "paint"),
    P("prism", (0.5, 0.35, 0.2), (0.45, 1.0, 0), "#40c8ff", "glow", rot=(-90, 0, -90)),
    P("prism", (0.5, 0.35, 0.2), (-0.1, 1.0, 0.4), "#40c8ff", "glow", rot=(-90, 0, 180)),
    P("prism", (0.5, 0.35, 0.2), (-0.1, 1.0, -0.4), "#40c8ff", "glow", rot=(90, 0, 180)),
], "Логистика")
models["smart_splitter"] = M("Умный разделитель", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.2, 0.7, 1.2), (0, 0.65, 0), "#d68a1a", "paint"),
    P("box", (0.5, 0.3, 0.04), (0, 0.75, 0.62), "#7dff5a", "glow", anim="flicker_soft"),
    P("cylinder", (0.5, 0.1, 0.5), (0, 1.05, 0), "#2a2d33", "dark", seg=10),
    P("prism", (0.5, 0.35, 0.2), (0.45, 1.25, 0), "#7dff5a", "glow", rot=(-90, 0, -90)),
    P("prism", (0.5, 0.35, 0.2), (0, 1.25, 0.45), "#ffd040", "glow", rot=(-90, 0, 0)),
    P("prism", (0.5, 0.35, 0.2), (0, 1.25, -0.45), "#ffd040", "glow", rot=(90, 0, 0)),
    P("sphere", (0.14, 0.14, 0.14), (0, 1.2, 0), "#7dff5a", "glow", anim="blink"),
], "Логистика")
models["smart_merger"] = M("Умный соединитель", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.2, 0.7, 1.2), (0, 0.65, 0), "#2f8fd6", "paint"),
    P("box", (0.5, 0.3, 0.04), (0, 0.75, 0.62), "#ffd040", "glow", anim="flicker_soft"),
    P("cylinder", (0.5, 0.1, 0.5), (0, 1.05, 0), "#2a2d33", "dark", seg=10),
    P("prism", (0.5, 0.35, 0.2), (0.45, 1.25, 0), "#40c8ff", "glow", rot=(-90, 0, -90)),
    P("prism", (0.5, 0.35, 0.2), (-0.1, 1.25, 0.4), "#40c8ff", "glow", rot=(-90, 0, 180)),
    P("prism", (0.5, 0.35, 0.2), (-0.1, 1.25, -0.4), "#40c8ff", "glow", rot=(90, 0, 180)),
    P("sphere", (0.14, 0.14, 0.14), (0, 1.2, 0), "#ffd040", "glow", anim="blink"),
], "Логистика")
models["miner"] = M("Бур", [
    P("box", (1.8, 0.35, 1.8), (0, 0.175, 0), YEL),
    P("box", (1.25, 1.0, 1.25), (-0.1, 0.85, 0), DARK, "dark"),
    P("box", (0.7, 0.35, 0.7), (0.75, 0.55, 0), "#3f4247", "dark"),
    P("cylinder", (1.24, 0.3, 1.24), (-0.1, 1.5, 0), YEL, "metal", anim="spin", seg=8),
    P("cylinder", (1.0, 0.7, 1.0), (-0.1, 1.95, 0), STEEL, "metal", anim="spin", top=0.35, seg=8),
    P("box", (0.12, 0.2, 0.9), (0.53, 1.0, 0), "#ff8c1a", "glow", anim="pulse"),
    P("sphere", (0.24, 0.24, 0.24), (-0.1, 2.38, 0), "#ff4d1a", "glow", anim="blink"),
], "Добыча")
# Бур Mk2 — подробная модель-витрина: рама на салазках, вышка с решёткой, шнек, редуктор
# с шестернями, мотор с вентилятором, гидроцилиндры, пульт, лестница и жёлоб выгрузки.
def _miner_mk2():
    BL, BLD, CHR, RUB, HOS = "#2f6fc4", "#24569a", "#d5dbe2", "#1d1e21", "#e0761c"
    pr = []
    a = pr.append
    # салазки и рама
    for z in (-0.78, 0.78):
        a(P("box", (1.96, 0.1, 0.22), (0, 0.05, z), DARK, "dark"))
        a(P("box", (1.96, 0.16, 0.05), (0, 0.18, z), DARK, "dark"))
        a(P("box", (0.22, 0.1, 0.24), (1.0, 0.08, z), DARK, "dark", rot=(0, 0, 35)))
    for x in (-0.75, 0.0, 0.75):
        a(P("box", (0.12, 0.12, 1.6), (x, 0.17, 0), DARK, "dark"))
    a(P("box", (1.84, 0.12, 1.84), (0, 0.31, 0), BL, role="", seg=None))
    a(P("box", (1.86, 0.04, 0.1), (0, 0.39, 0.88), YEL))
    a(P("box", (1.86, 0.04, 0.1), (0, 0.39, -0.88), YEL))
    for i in range(7):
        a(P("box", (0.12, 0.045, 0.1), (-0.78 + i * 0.26, 0.4, 0.88), DARK, "dark", rot=(0, 45, 0)))
    # болты по краю плиты
    for x in (-0.82, -0.27, 0.27, 0.82):
        for z in (-0.82, 0.82):
            a(P("cylinder", (0.06, 0.05, 0.06), (x, 0.39, z), CHR, "metal", seg=6))
    # гидроопоры по углам
    for x in (-0.82, 0.82):
        for z in (-0.82, 0.82):
            a(P("box", (0.2, 0.08, 0.2), (x + (0.1 if x > 0 else -0.1), 0.04, z + (0.1 if z > 0 else -0.1)), RUB, "dark"))
            a(P("cylinder", (0.14, 0.3, 0.14), (x + (0.1 if x > 0 else -0.1), 0.2, z + (0.1 if z > 0 else -0.1)), CHR, "metal", seg=10))
            a(P("cylinder", (0.2, 0.22, 0.2), (x + (0.1 if x > 0 else -0.1), 0.42, z + (0.1 if z > 0 else -0.1)), YEL, seg=10))
    # скважина: кольцо обсадной трубы и шнек
    a(P("torus", (0.8, 0.3, 0.8), (-0.1, 0.42, 0), DARK, "dark", seg=20))
    a(P("cylinder", (0.66, 0.18, 0.66), (-0.1, 0.36, 0), RUB, "dark", seg=20))
    a(P("screw", (0.56, 1.5, 0.56), (-0.1, 0.65, 0), CHR, "metal", anim="spin_fast", seg=4, top=0.3))
    # вышка: четыре стойки, раскосы, верхняя площадка
    for x in (-0.62, 0.42):
        for z in (-0.52, 0.52):
            a(P("box", (0.1, 2.5, 0.1), (x, 1.62, z), BLD))
    for z in (-0.52, 0.52):
        for y in (1.0, 1.75, 2.5):
            a(P("box", (1.04, 0.06, 0.06), (-0.1, y, z), BLD))
        for k, y in enumerate((1.37, 2.12)):
            a(P("box", (1.2, 0.05, 0.05), (-0.1, y, z), BLD, rot=(0, 0, 33 if k % 2 == 0 else -33)))
    for x in (-0.62, 0.42):
        for y in (1.0, 1.75, 2.5):
            a(P("box", (0.06, 0.06, 1.04), (x, y, 0), BLD))
        a(P("box", (0.05, 0.05, 1.2), (x, 1.37, 0), BLD, rot=(33, 0, 0)))
    a(P("box", (1.3, 0.08, 1.3), (-0.1, 2.9, 0), DARK, "dark"))
    # ведущая штанга (келли) — вращается
    a(P("cylinder", (0.2, 2.3, 0.2), (-0.1, 1.55, 0), CHR, "metal", anim="spin_fast", seg=6))
    a(P("cylinder", (0.34, 0.12, 0.34), (-0.1, 1.0, 0), DARK, "dark", anim="spin_fast", seg=6))
    # редуктор с шестернями на боку (+z): большая медленно, малая быстро, навстречу
    a(P("box", (0.9, 0.62, 0.5), (-0.1, 2.15, 0.0), BL))
    a(P("box", (0.94, 0.06, 0.54), (-0.1, 2.47, 0.0), DARK, "dark"))
    a(P("box", (0.92, 0.6, 0.02), (-0.1, 2.15, 0.26), DARK, "dark"))
    a(P("gear", (0.62, 0.07, 0.62), (-0.22, 2.15, 0.31), YEL, "metal", rot=(90, 0, 0), anim="gear_slow", seg=20, top=0.82))
    a(P("gear", (0.34, 0.07, 0.34), (0.22, 2.15, 0.31), STEEL, "metal", rot=(-90, 0, 0), anim="gear_fast", seg=11, top=0.75))
    a(P("gear", (0.24, 0.07, 0.24), (0.22, 2.38, 0.38), CHR, "metal", rot=(90, 0, 0), anim="gear_fast", seg=8, top=0.72))
    a(P("cylinder", (0.07, 0.14, 0.07), (-0.22, 2.15, 0.35), CHR, "metal", rot=(90, 0, 0), seg=8))
    a(P("cylinder", (0.06, 0.14, 0.06), (0.22, 2.15, 0.35), CHR, "metal", rot=(90, 0, 0), seg=8))
    # шестерни и с другой стороны
    a(P("gear", (0.5, 0.07, 0.5), (-0.1, 2.15, -0.31), YEL, "metal", rot=(-90, 0, 0), anim="gear_slow", seg=16, top=0.8))
    # мотор сверху: корпус с рёбрами охлаждения, вентилятор, крышка
    a(P("cylinder", (0.7, 0.7, 0.7), (-0.1, 3.3, 0), BL, seg=20))
    for i in range(6):
        a(P("cylinder", (0.8, 0.035, 0.8), (-0.1, 3.02 + i * 0.11, 0), DARK, "dark", seg=20))
    a(P("cylinder", (0.74, 0.06, 0.74), (-0.1, 3.68, 0), CHR, "metal", seg=20))
    a(P("cylinder", (0.66, 0.04, 0.66), (-0.1, 3.73, 0), DARK, "dark", seg=24))
    for i in range(6):
        a(P("box", (0.3, 0.02, 0.08), (-0.1, 3.76, 0), STEEL, "metal", rot=(14, i * 30, 0), anim="spin_fan"))
    a(P("sphere", (0.1, 0.06, 0.1), (-0.1, 3.78, 0), CHR, "metal"))
    a(P("box", (0.26, 0.3, 0.2), (0.22, 3.25, 0.25), DARK, "dark"))
    a(P("box", (0.02, 0.12, 0.14), (0.355, 3.27, 0.25), "#40c8ff", "glow", anim="pulse"))
    # вал от мотора к редуктору
    a(P("cylinder", (0.12, 0.45, 0.12), (-0.1, 2.72, 0), CHR, "metal", anim="spin_fast", seg=8))
    # гидроцилиндры на раме вышки (поршни ходят)
    for z in (-0.68, 0.68):
        a(P("cylinder", (0.16, 0.9, 0.16), (0.62, 1.0, z), YEL, rot=(0, 0, 8), seg=12))
        a(P("cylinder", (0.08, 0.7, 0.08), (0.56, 1.7, z), CHR, "metal", rot=(0, 0, 8), anim="piston_small", seg=10))
        a(P("box", (0.16, 0.1, 0.12), (0.66, 0.5, z), DARK, "dark"))
        a(P("torus", (0.18, 0.18, 0.18), (0.66, 0.42, z), RUB, "dark", rot=(90, 0, 0), seg=10))
    # шланги
    a(P("torus", (0.5, 0.5, 0.12), (0.5, 1.45, 0.62), HOS, "cloth", rot=(90, 0, 0), seg=14))
    a(P("torus", (0.4, 0.4, 0.1), (0.5, 1.35, -0.62), HOS, "cloth", rot=(90, 0, 0), seg=14))
    # жёлоб выгрузки и ролики к выходу (+x)
    a(P("box", (0.75, 0.06, 0.5), (0.62, 0.62, 0), STEEL, "metal", rot=(0, 0, -16)))
    a(P("box", (0.75, 0.18, 0.04), (0.62, 0.7, 0.26), BLD, rot=(0, 0, -16)))
    a(P("box", (0.75, 0.18, 0.04), (0.62, 0.7, -0.26), BLD, rot=(0, 0, -16)))
    for i in range(4):
        a(P("cylinder", (0.07, 0.46, 0.07), (0.36 + i * 0.17, 0.72 - i * 0.05, 0), RUB, "dark", rot=(90, 0, 0), anim="spin_fast", seg=8))
    a(P("box", (0.4, 0.3, 0.6), (0.82, 0.55, 0), "#3f4247", "dark"))
    a(P("box", (0.12, 0.25, 1.0), (0.6, 1.2, 0), "#40c8ff", "glow", anim="pulse"))
    # пульт управления сзади (-x): шкаф, экран, кнопки, рычаги
    a(P("box", (0.32, 0.9, 0.62), (-0.82, 0.85, -0.4), BL))
    a(P("box", (0.02, 0.28, 0.4), (-0.99, 1.05, -0.4), "#1b2d3a", "glass"))
    a(P("box", (0.02, 0.2, 0.32), (-1.0, 1.05, -0.4), "#40ffb0", "glow", anim="flicker_soft"))
    for k, col in enumerate(("#ff3b2f", "#ffd040", "#40ff6a")):
        a(P("sphere", (0.06, 0.06, 0.06), (-0.99, 0.75, -0.58 + k * 0.1), col, "glow", anim="blink" if k == 0 else "pulse"))
    for k in range(2):
        a(P("cylinder", (0.03, 0.22, 0.03), (-1.0, 0.68, -0.25 + k * 0.08), CHR, "metal", rot=(0, 0, 20 + k * 15), seg=6))
        a(P("sphere", (0.06, 0.06, 0.06), (-1.04, 0.79, -0.25 + k * 0.08), "#ff3b2f"))
    a(P("box", (0.3, 0.06, 0.66), (-0.82, 1.32, -0.4), DARK, "dark"))
    # лестница к верхней площадке (-x, +z)
    for z in (0.32, 0.62):
        a(P("box", (0.05, 2.5, 0.05), (-0.86, 1.65, z), YEL))
    for i in range(9):
        a(P("cylinder", (0.03, 0.3, 0.03), (-0.86, 0.6 + i * 0.27, 0.47), STEEL, "metal", rot=(90, 0, 0), seg=6))
    # перила площадки
    for x in (-0.72, 0.52):
        for z in (-0.62, 0.62):
            a(P("box", (0.04, 0.45, 0.04), (x, 3.15, z), YEL))
    a(P("box", (1.28, 0.04, 0.04), (-0.1, 3.36, 0.62), YEL))
    a(P("box", (1.28, 0.04, 0.04), (-0.1, 3.36, -0.62), YEL))
    a(P("box", (0.04, 0.04, 1.28), (0.52, 3.36, 0), YEL))
    # выхлоп с колпаком и маячок
    a(P("cylinder", (0.12, 0.9, 0.12), (-0.6, 3.25, -0.45), DARK, "dark", seg=10))
    a(P("cylinder", (0.2, 0.05, 0.2), (-0.6, 3.73, -0.45), DARK, "dark", rot=(0, 0, 20), seg=10))
    a(P("cylinder", (0.12, 0.08, 0.12), (0.4, 2.98, -0.5), DARK, "dark", seg=10))
    a(P("sphere", (0.14, 0.16, 0.14), (0.4, 3.08, -0.5), "#ff8c1a", "glow", anim="blink"))
    a(P("cylinder", (0.17, 0.18, 0.17), (0.4, 3.08, -0.5), DARK, "dark", seg=6, top=1.0))
    # табличка Mk2
    a(P("box", (0.02, 0.16, 0.34), (0.43, 2.15, 0.0), "#ffffff"))
    a(P("box", (0.02, 0.06, 0.06), (0.44, 2.15, -0.08), "#2f6fc4"))
    a(P("box", (0.02, 0.06, 0.06), (0.44, 2.15, 0.06), "#2f6fc4"))
    return pr
models["miner_mk2"] = M("Бур Mk2", _miner_mk2(), "Добыча")
models["furnace"] = M("Каменная печь", [
    P("box", (1.8, 1.2, 1.8), (0, 0.6, 0), "#7d7466", "stone"),
    P("box", (1.5, 0.5, 1.5), (0, 1.45, 0), "#6b6357", "stone"),
    P("cylinder", (0.5, 0.9, 0.5), (-0.4, 2.1, -0.4), "#5a5249", "stone", seg=8),
    P("box", (0.12, 0.5, 0.7), (0.86, 0.5, 0), "#ff7310", "glow", anim="flicker"),
], "Производство")
models["smelter"] = M("Плавильня", [
    P("box", (1.9, 0.3, 1.9), (0, 0.15, 0), CONC, "concrete"),
    P("cylinder", (1.6, 1.5, 1.6), (-0.1, 1.05, 0), "#4d3329", "dark", top=0.82, seg=12),
    P("cylinder", (1.5, 0.12, 1.5), (-0.1, 1.85, 0), STEEL, "metal", seg=12),
    P("box", (0.14, 0.45, 0.7), (0.68, 0.85, 0), "#ff730d", "glow", anim="pulse"),
    P("cylinder", (0.45, 1.3, 0.45), (-0.55, 2.3, -0.5), DARK, "dark", seg=8),
    P("cylinder", (0.42, 0.1, 0.42), (-0.55, 2.98, -0.5), "#ff590d", "glow", anim="pulse", seg=8),
], "Производство")
models["assembler"] = M("Сборщик", [
    P("box", (1.9, 0.3, 1.9), (0, 0.15, 0), "#4d5461"),
    P("box", (1.55, 1.05, 1.55), (0, 0.82, 0), "#2e6bc7"),
    P("box", (1.62, 0.12, 1.62), (0, 1.4, 0), STEEL, "metal"),
    P("cylinder", (0.9, 0.22, 0.9), (0, 1.58, 0), "#c0c7d1", "metal", anim="spin", seg=6),
    P("box", (0.06, 0.14, 1.2), (0.79, 1.1, 0), "#33ff80", "glow"),
    P("box", (0.5, 0.4, 0.5), (0.8, 0.5, 0), DARK, "dark"),
], "Производство")
models["workbench"] = M("Верстак", [
    P("box", (1.8, 0.12, 1.1), (0, 0.9, 0), "#9c6b3c", "wood"),
    P("box", (0.12, 0.9, 0.12), (0.8, 0.45, 0.45), "#6e4826", "wood"),
    P("box", (0.12, 0.9, 0.12), (-0.8, 0.45, 0.45), "#6e4826", "wood"),
    P("box", (0.12, 0.9, 0.12), (0.8, 0.45, -0.45), "#6e4826", "wood"),
    P("box", (0.12, 0.9, 0.12), (-0.8, 0.45, -0.45), "#6e4826", "wood"),
    P("box", (0.5, 0.15, 0.3), (0.3, 1.03, 0.1), STEEL, "metal"),
    P("box", (0.08, 0.08, 0.5), (-0.4, 1.0, -0.1), "#5a3a1e", "wood", rot=(0, 30, 0)),
], "Станции")
models["workshop"] = M("Мастерская", [
    P("box", (1.9, 0.25, 1.9), (0, 0.125, 0), CONC, "concrete"),
    P("box", (1.7, 1.3, 1.2), (-0.1, 0.9, -0.3), "#8a5a2e", "wood"),
    P("box", (1.8, 0.1, 1.4), (-0.1, 1.6, -0.3), "#4a4f57", "metal", rot=(8, 0, 0)),
    P("box", (1.2, 0.1, 0.7), (0.1, 0.85, 0.55), STEEL, "metal"),
    P("cylinder", (0.4, 0.4, 0.4), (0.4, 1.1, 0.55), "#c0c7d1", "metal", anim="spin", seg=8),
    P("sphere", (0.18, 0.18, 0.18), (-0.6, 1.4, 0.32), "#ffcc4d", "glow", anim="pulse"),
], "Станции")
models["chest"] = M("Ящик", [
    P("box", (1.3, 0.8, 1.0), (0, 0.4, 0), "#8a5a2e", "wood"),
    P("box", (1.34, 0.1, 1.04), (0, 0.65, 0), "#4a4f57", "metal"),
    P("box", (0.2, 0.2, 0.06), (0.0, 0.5, 0.52), "#ffc433", "metal"),
], "Хранение")
models["container"] = M("Контейнер", [
    P("box", (1.9, 1.6, 1.9), (0, 0.8, 0), "#2f7d4a"),
    P("box", (1.95, 0.12, 1.95), (0, 1.62, 0), "#245f38", "metal"),
    P("box", (0.06, 1.3, 0.8), (0.96, 0.8, 0), "#245f38", "metal"),
    P("box", (0.07, 0.15, 0.4), (0.97, 1.3, 0), "#5cff8c", "glow"),
], "Хранение")
models["generator"] = M("Генератор", [
    P("box", (1.9, 0.3, 1.9), (0, 0.15, 0), CONC, "concrete"),
    P("box", (1.5, 1.0, 1.2), (-0.1, 0.8, 0), "#b33a26"),
    P("cylinder", (0.7, 0.9, 0.7), (0.4, 0.75, 0.55), STEEL, "metal", rot=(90, 0, 0), anim="spin", seg=10),
    P("cylinder", (0.35, 1.2, 0.35), (-0.6, 1.8, -0.4), DARK, "dark", seg=8),
    P("box", (0.08, 0.25, 0.5), (0.66, 0.9, -0.2), "#ffd11a", "glow", anim="pulse"),
], "Энергетика")
models["solar"] = M("Солнечная панель", [
    P("cylinder", (0.25, 1.0, 0.25), (0, 0.5, 0), STEEL, "metal", seg=8),
    P("box", (1.9, 0.08, 1.5), (0, 1.1, 0), "#1f3d80", "glass", rot=(0, 0, 25)),
    P("box", (1.95, 0.05, 1.55), (0, 1.06, 0), "#c0c7d1", "metal", rot=(0, 0, 25)),
], "Энергетика")
models["pole"] = M("Опора ЛЭП", [
    P("cylinder", (0.18, 3.6, 0.18), (0, 1.8, 0), "#7a5230", "wood", seg=6),
    P("box", (1.2, 0.1, 0.12), (0, 3.4, 0), "#7a5230", "wood"),
    P("sphere", (0.16, 0.16, 0.16), (0.5, 3.5, 0), "#66d9ff", "glow", anim="pulse"),
    P("sphere", (0.16, 0.16, 0.16), (-0.5, 3.5, 0), "#66d9ff", "glow", anim="pulse"),
], "Энергетика")
models["wind_turbine"] = M("Ветряк", [
    P("box", (1.4, 0.3, 1.4), (0, 0.15, 0), CONC, "concrete"),
    P("cylinder", (0.42, 6.6, 0.42), (0, 3.6, 0), "#e8ecef", "paint", top=0.6, seg=10),
    P("box", (0.55, 0.5, 1.2), (0, 7.0, -0.1), "#e8ecef", "paint"),
    P("box", (0.3, 0.06, 0.5), (0, 7.28, -0.4), "#e04b2a", "paint"),
    P("sphere", (0.32, 0.32, 0.38), (0, 7.0, 0.62), "#c8ced6", "metal"),
    # лопасти: две длинные планки крестом вращаются вокруг оси ступицы
    P("box", (5.2, 0.06, 0.34), (0, 7.0, 0.72), "#f4f6f8", "paint", rot=(90, 0, 0), anim="spin_wind"),
    P("box", (0.34, 0.06, 5.2), (0, 7.0, 0.72), "#f4f6f8", "paint", rot=(90, 0, 0), anim="spin_wind"),
    P("sphere", (0.12, 0.12, 0.12), (0, 7.34, -0.55), "#ff3a2a", "glow", anim="blink"),
], "Энергетика")
models["coal_generator"] = M("Угольный генератор", [
    P("box", (1.95, 0.3, 1.95), (0, 0.15, 0), CONC, "concrete"),
    P("box", (1.6, 1.2, 1.3), (-0.1, 0.9, 0.1), "#3b3f46", "metal"),
    P("box", (1.62, 0.12, 1.32), (-0.1, 1.2, 0.1), "#f2a81f", "paint"),
    P("cylinder", (0.8, 1.0, 0.8), (0.45, 0.85, 0.55), STEEL, "metal", rot=(90, 0, 0), anim="spin", seg=12),
    P("cylinder", (0.32, 1.6, 0.32), (-0.55, 2.2, -0.45), "#2a2c30", "dark", seg=8),
    P("cylinder", (0.26, 1.2, 0.26), (-0.05, 2.0, -0.5), "#2a2c30", "dark", seg=8),
    P("box", (0.5, 0.35, 0.06), (-0.2, 0.75, 0.77), "#ff6a1a", "glow", anim="flicker"),
], "Энергетика")
models["coal_generator"]["emitters"] = [{"kind": "puff", "pos": [-0.55, 3.1, -0.45], "when": "active", "rate": 0.4, "size": 1.3},
                                        {"kind": "puff", "pos": [-0.05, 2.7, -0.5], "when": "active", "rate": 0.25, "size": 1.0}]
models["battery"] = M("Аккумулятор", [
    P("box", (1.6, 1.2, 1.6), (0, 0.6, 0), "#3a3f47", "dark"),
    P("box", (1.3, 0.15, 1.3), (0, 1.27, 0), "#ffc21a", "paint"),
    P("box", (0.07, 0.8, 0.2), (0.81, 0.6, 0), "#4dff73", "glow", anim="pulse"),
], "Энергетика")
models["turret"] = M("Турель", [
    P("cylinder", (1.7, 0.45, 1.7), (0, 0.225, 0), "#383b40", "dark", top=0.9, seg=12),
    P("cylinder", (0.9, 0.7, 0.9), (0, 0.8, 0), STEEL, "metal", top=0.75, seg=12),
    P("box", (1.05, 0.6, 0.95), (0, 1.4, 0), "#d94020", role="head"),
    P("box", (1.2, 0.14, 0.14), (0.95, 1.45, 0.2), "#4d4d52", "metal", role="head"),
    P("box", (1.2, 0.14, 0.14), (0.95, 1.45, -0.2), "#4d4d52", "metal", role="head"),
    P("box", (0.08, 0.12, 0.6), (0.53, 1.55, 0), "#ffcc4d", "glow", role="head"),
], "Оборона")
models["laser_turret"] = M("Лазерная турель", [
    P("cylinder", (1.8, 0.5, 1.8), (0, 0.25, 0), "#2b2f36", "dark", seg=12),
    P("cylinder", (0.7, 1.0, 0.7), (0, 1.0, 0), "#c0c7d1", "metal", seg=12),
    P("sphere", (1.0, 0.9, 1.0), (0, 1.75, 0), "#e6ebf2", "paint", role="head"),
    P("cylinder", (0.2, 1.4, 0.2), (0.8, 1.8, 0), "#4d4d52", "metal", rot=(0, 0, 90), role="head", seg=8),
    P("sphere", (0.3, 0.3, 0.3), (0.3, 2.0, 0), "#33ccff", "glow", anim="pulse", role="head"),
], "Оборона")
models["wall_wood"] = M("Деревянная стена", [
    P("box", (2.0, 1.6, 0.5), (0, 0.8, 0), "#8a5a2e", "wood"),
    P("cylinder", (0.4, 1.9, 0.4), (0.8, 0.95, 0), "#6e4826", "wood", top=0.6, seg=6),
    P("cylinder", (0.4, 1.9, 0.4), (-0.8, 0.95, 0), "#6e4826", "wood", top=0.6, seg=6),
    P("cylinder", (0.4, 1.9, 0.4), (0, 0.95, 0), "#6e4826", "wood", top=0.6, seg=6),
], "Оборона")
models["wall"] = M("Бетонная стена", [
    P("box", (2.0, 1.8, 2.0), (0, 0.9, 0), CONC, "concrete"),
    P("box", (2.06, 0.22, 2.06), (0, 0.55, 0), "#f2bf1a"),
    P("box", (2.1, 0.2, 2.1), (0, 1.9, 0), "#4d4f54", "dark"),
], "Оборона")
models["lamp"] = M("Фонарь", [
    P("cylinder", (0.16, 2.6, 0.16), (0, 1.3, 0), DARK, "dark", seg=6),
    P("box", (0.5, 0.3, 0.5), (0, 2.7, 0), "#ffe6a6", "glow", anim="flicker_soft"),
    P("box", (0.6, 0.08, 0.6), (0, 2.88, 0), DARK, "dark"),
], "Декор")
# Фундаменты: модель высотой 1 м — в игре тянется от земли до верха.
FOUND = "#a9a698"
models["found_1x1"] = M("Фундамент 1×1", [
    P("box", (2.0, 1.0, 2.0), (0, 0.5, 0), FOUND, "concrete"),
    P("box", (2.02, 0.05, 2.02), (0, 0.975, 0), "#c4c1b4", "concrete"),
    P("box", (2.04, 0.08, 0.06), (0, 0.9, 1.0), "#f2bf1a"),
    P("box", (2.04, 0.08, 0.06), (0, 0.9, -1.0), "#f2bf1a"),
], "Фундаменты")
models["found_2x2"] = M("Фундамент 2×2", [
    P("box", (4.0, 1.0, 4.0), (0, 0.5, 0), FOUND, "concrete"),
    P("box", (4.02, 0.05, 4.02), (0, 0.975, 0), "#c4c1b4", "concrete"),
    P("box", (4.0, 0.02, 0.05), (0, 1.0, 0), "#8c897d", "concrete"),
    P("box", (0.05, 0.02, 4.0), (0, 1.0, 0), "#8c897d", "concrete"),
    P("box", (4.04, 0.08, 0.06), (0, 0.9, 2.0), "#f2bf1a"),
    P("box", (4.04, 0.08, 0.06), (0, 0.9, -2.0), "#f2bf1a"),
], "Фундаменты")
models["found_tall"] = M("Фундамент 2 м", [
    P("box", (2.0, 2.0, 2.0), (0, 1.0, 0), FOUND, "concrete"),
    P("box", (2.02, 0.05, 2.02), (0, 1.975, 0), "#c4c1b4", "concrete"),
    P("box", (2.04, 0.1, 2.04), (0, 1.0, 0), "#8c897d", "concrete"),
], "Фундаменты")
models["found_ramp"] = M("Рампа", [
    P("wedge", (2.0, 1.0, 2.0), (0, 0.5, 0), FOUND, "concrete"),
    P("box", (0.06, 1.0, 2.0), (0.97, 0.5, 0), "#8c897d", "concrete"),
], "Фундаменты")
models["found_ramp2"] = M("Пологая рампа 2×2", [
    P("wedge", (4.0, 1.0, 4.0), (0, 0.5, 0), FOUND, "concrete"),
    P("box", (0.06, 1.0, 4.0), (1.97, 0.5, 0), "#8c897d", "concrete"),
], "Фундаменты")
models["found_wall"] = M("Стена фундамента", [
    P("box", (2.0, 2.6, 0.35), (0, 1.3, 0), FOUND, "concrete"),
    P("box", (2.04, 0.12, 0.4), (0, 2.6, 0), "#8c897d", "concrete"),
    P("box", (0.5, 0.5, 0.06), (0.45, 1.6, 0.2), "#7fb6d9", "glass"),
], "Фундаменты")
models["floor"] = M("Плитка", [
    P("box", (2.0, 0.08, 2.0), (0, 0.04, 0), "#7d7f85", "concrete"),
    P("box", (1.9, 0.02, 0.06), (0, 0.085, 0), "#5c5e63", "concrete"),
], "Декор")
models["fence"] = M("Забор", [
    P("box", (2.0, 0.12, 0.08), (0, 0.8, 0), "#8a5a2e", "wood"),
    P("box", (2.0, 0.12, 0.08), (0, 0.45, 0), "#8a5a2e", "wood"),
    P("box", (0.14, 1.1, 0.14), (0.9, 0.55, 0), "#6e4826", "wood"),
    P("box", (0.14, 1.1, 0.14), (-0.9, 0.55, 0), "#6e4826", "wood"),
], "Декор")
models["gate"] = M("Ворота", [
    P("box", (0.3, 2.4, 0.5), (-0.85, 1.2, 0), CONC, "concrete"), P("box", (0.3, 2.4, 0.5), (0.85, 1.2, 0), CONC, "concrete"),
    P("box", (2.0, 0.3, 0.5), (0, 2.35, 0), YEL, "paint"),
    P("box", (1.4, 1.9, 0.12), (0, 1.0, 0), "#7a8290", "metal"),
    P("box", (1.4, 0.06, 0.14), (0, 0.4, 0), DARK, "dark"), P("box", (1.4, 0.06, 0.14), (0, 1.0, 0), DARK, "dark"), P("box", (1.4, 0.06, 0.14), (0, 1.6, 0), DARK, "dark"),
    P("sphere", (0.14, 0.14, 0.14), (0, 2.55, 0), "#7dff5a", "glow", anim="blink"),
], "Оборона")
models["flag"] = M("Флаг корпорации", [
    P("cylinder", (0.1, 4.0, 0.1), (0, 2.0, 0), STEEL, "metal", seg=6),
    P("box", (1.2, 0.7, 0.04), (0.62, 3.55, 0), "#f2a81f", "paint", anim="wave"),
], "Декор")
models["hq"] = M("Штаб", [
    P("box", (6.0, 0.4, 6.0), (0, 0.2, 0), CONC, "concrete"),
    P("box", (4.4, 2.8, 4.4), (0, 1.8, 0), "#d1d6db"),
    P("box", (4.5, 0.3, 4.5), (0, 1.2, 0), "#f28c1a"),
    P("box", (3.0, 1.6, 3.0), (0, 4.0, 0), "#383d45", "dark"),
    P("sphere", (2.3, 2.3, 2.3), (0, 4.9, 0), "#40bfff", "glow"),
    P("cylinder", (0.16, 4.0, 0.16), (1.2, 6.6, 1.2), STEEL, "metal", seg=6),
    P("sphere", (0.4, 0.4, 0.4), (1.2, 8.7, 1.2), "#ff261a", "glow", anim="blink"),
    P("box", (0.08, 0.5, 3.0), (2.23, 2.2, 0), "#4dccff", "glow"),
    P("box", (3.0, 0.5, 0.08), (0, 2.2, 2.23), "#4dccff", "glow"),
    P("box", (0.08, 0.5, 3.0), (-2.23, 2.2, 0), "#4dccff", "glow"),
    P("box", (3.0, 0.5, 0.08), (0, 2.2, -2.23), "#4dccff", "glow"),
    P("cylinder", (0.7, 3.4, 0.7), (2.6, 1.7, 2.6), STEEL, "metal", seg=10),
    P("cylinder", (0.7, 3.4, 0.7), (-2.6, 1.7, 2.6), STEEL, "metal", seg=10),
    P("cylinder", (0.7, 3.4, 0.7), (2.6, 1.7, -2.6), STEEL, "metal", seg=10),
    P("cylinder", (0.7, 3.4, 0.7), (-2.6, 1.7, -2.6), STEEL, "metal", seg=10),
    P("box", (1.6, 0.1, 1.0), (-1.4, 3.35, -1.4), "#26407f", "glass", anim="spin_slow"),
], "Здания")

# ------------------------------------------------------------------ флора и камни
def pine(name, trunk, crown, h=1.0):
    return M(name, [
        P("cylinder", (0.4, 1.8 * h, 0.4), (0, 0.9 * h, 0), trunk, "wood", top=0.55, seg=6),
        P("cone", (2.7, 2.4 * h, 2.7), (0, 2.4 * h, 0), crown, "leaf", anim="sway", seg=7),
        P("cone", (2.0, 2.0 * h, 2.0), (0, 3.5 * h, 0), crown, "leaf", anim="sway", seg=7),
    ], "Флора")
models["tree_pine"] = pine("Ель", "#543823", "#1f4d24")
models["tree_fir"] = pine("Пихта", "#4a301d", "#2b5c2e", 1.25)
models["tree_oak"] = M("Дуб", [
    P("cylinder", (0.6, 2.2, 0.6), (0, 1.1, 0), "#5c3d24", "wood", top=0.6, seg=7),
    P("sphere", (3.0, 2.4, 3.0), (0, 3.0, 0), "#3d6b29", "leaf", anim="sway", seg=8),
    P("sphere", (2.0, 1.6, 2.0), (0.7, 3.6, 0.4), "#4a7a30", "leaf", anim="sway", seg=7),
], "Флора")
models["tree_birch"] = M("Берёза", [
    P("cylinder", (0.35, 3.0, 0.35), (0, 1.5, 0), "#e6e3d8", "wood", top=0.6, seg=6),
    P("box", (0.37, 0.08, 0.37), (0, 1.2, 0), "#2e2b26", "wood"),
    P("box", (0.37, 0.08, 0.37), (0, 2.1, 0), "#2e2b26", "wood"),
    P("sphere", (2.0, 2.6, 2.0), (0, 3.6, 0), "#7aa63a", "leaf", anim="sway", seg=7),
], "Флора")
models["tree_dead"] = M("Сухое дерево", [
    P("cylinder", (0.45, 2.6, 0.45), (0, 1.3, 0), "#4a3f36", "wood", top=0.4, seg=6),
    P("cylinder", (0.18, 1.4, 0.18), (0.4, 2.3, 0), "#4a3f36", "wood", rot=(0, 0, -40), top=0.3, seg=5),
    P("cylinder", (0.16, 1.2, 0.16), (-0.35, 2.0, 0.1), "#4a3f36", "wood", rot=(20, 0, 40), top=0.3, seg=5),
], "Флора")
models["stump"] = M("Пень", [
    P("cylinder", (0.55, 0.4, 0.55), (0, 0.2, 0), "#5c3d24", "wood", seg=7),
    P("cylinder", (0.5, 0.02, 0.5), (0, 0.41, 0), "#c49a6c", "wood", seg=7),
], "Флора")
models["bush_berry"] = M("Ягодный куст", [
    P("sphere", (1.3, 0.9, 1.3), (0, 0.45, 0), "#2f5c26", "leaf", anim="sway", seg=7),
    P("sphere", (0.14, 0.14, 0.14), (0.4, 0.7, 0.3), "#e0263d", "paint"),
    P("sphere", (0.14, 0.14, 0.14), (-0.3, 0.75, 0.35), "#e0263d", "paint"),
    P("sphere", (0.14, 0.14, 0.14), (0.1, 0.85, -0.4), "#e0263d", "paint"),
], "Флора")
models["bush_fiber"] = M("Трава-волокно", [
    P("cone", (0.6, 1.0, 0.15), (0, 0.5, 0), "#8aa63a", "leaf", anim="sway", rot=(0, 0, 10)),
    P("cone", (0.6, 1.1, 0.15), (0.1, 0.55, 0.1), "#7a9633", "leaf", anim="sway", rot=(0, 60, -12)),
    P("cone", (0.6, 0.9, 0.15), (-0.1, 0.45, 0), "#9cb847", "leaf", anim="sway", rot=(0, 120, 8)),
], "Флора")
models["flowers"] = M("Цветы", [
    P("cylinder", (0.04, 0.4, 0.04), (0, 0.2, 0), "#3d6b29", "leaf", seg=4),
    P("sphere", (0.2, 0.12, 0.2), (0, 0.42, 0), "#e6d43a", "paint", anim="sway"),
    P("cylinder", (0.04, 0.35, 0.04), (0.25, 0.17, 0.1), "#3d6b29", "leaf", seg=4),
    P("sphere", (0.2, 0.12, 0.2), (0.25, 0.37, 0.1), "#d94db3", "paint", anim="sway"),
], "Флора")
models["mushroom"] = M("Гриб", [
    P("cylinder", (0.16, 0.35, 0.16), (0, 0.17, 0), "#e6dccb", "paint", seg=6),
    P("sphere", (0.5, 0.25, 0.5), (0, 0.38, 0), "#c2331f", "paint", seg=8),
], "Флора")
models["glow_shroom"] = M("Светогриб", [
    P("cylinder", (0.2, 0.5, 0.2), (0, 0.25, 0), "#cfe6ff", "paint", seg=6),
    P("sphere", (0.7, 0.35, 0.7), (0, 0.55, 0), "#33e6ff", "glow", anim="pulse", seg=8),
], "Флора")
models["cactus"] = M("Кактус", [
    P("capsule", (0.6, 2.2, 0.6), (0, 1.1, 0), "#3d7a3d", "leaf"),
    P("capsule", (0.35, 0.9, 0.35), (0.45, 1.3, 0), "#3d7a3d", "leaf", rot=(0, 0, -50)),
], "Флора")
def rock(name, col, crystal=None):
    parts = [
        P("sphere", (1.6, 1.0, 1.4), (0, 0.35, 0), col, "stone", seg=6),
        P("sphere", (0.9, 0.7, 0.9), (0.5, 0.3, 0.45), col, "stone", seg=5),
    ]
    if crystal:
        parts.append(P("prism", (0.3, 0.7, 0.3), (-0.2, 0.75, 0.1), crystal, "glow", rot=(0, 0, 15)))
        parts.append(P("prism", (0.25, 0.5, 0.25), (0.35, 0.6, -0.25), crystal, "glow", rot=(10, 40, -20)))
    return M(name, parts, "Камни и руда")
models["rock_small"] = M("Камень", [P("sphere", (0.9, 0.55, 0.8), (0, 0.2, 0), "#8c8a85", "stone", seg=6)], "Камни и руда")
models["rock_big"] = rock("Валун", "#7d7b76")
models["ore_iron"] = rock("Железная руда", "#8a5547", "#b37a66")
models["ore_copper"] = rock("Медная руда", "#8c6640", "#ff8c33")
models["ore_coal"] = rock("Уголь", "#2e2e33")
models["ore_quartz"] = rock("Кварц", "#9aa3ad", "#e6f2ff")
models["ore_sulfur"] = rock("Сера", "#8c8a52", "#f2e633")
models["crystal"] = M("Кристалл", [
    P("prism", (0.6, 1.6, 0.6), (0, 0.8, 0), "#b34dff", "glow", anim="pulse"),
    P("prism", (0.4, 1.0, 0.4), (0.4, 0.5, 0.2), "#cc66ff", "glow", rot=(0, 30, -25), anim="pulse"),
    P("prism", (0.35, 0.8, 0.35), (-0.35, 0.4, -0.15), "#9933ff", "glow", rot=(15, 0, 30), anim="pulse"),
], "Камни и руда")

# ------------------------------------------------------------------ монстры (смотрят вдоль +X)
def bug(name, body, shell, eye, spikes, scale=1.0):
    s = scale
    return M(name, [
        P("sphere", (1.5 * s, 0.77 * s, 1.1 * s), (-0.1 * s, 0.55 * s, 0), body, "flesh", anim="bob", seg=14),
        P("sphere", (1.08 * s, 0.54 * s, 0.86 * s), (-0.25 * s, 0.75 * s, 0), shell, "flesh", anim="bob", seg=12),
        P("sphere", (0.6 * s, 0.6 * s, 0.6 * s), (0.6 * s, 0.5 * s, 0), shell, "flesh", anim="bob", seg=10),
        P("box", (0.1 * s, 0.07 * s, 0.34 * s), (0.86 * s, 0.58 * s, 0), eye, "glow", anim="bob"),
        P("box", (0.1 * s, 0.07 * s, 1.9 * s), (0.3 * s, 0.3 * s, 0), "#1a0d1f", "leg", anim="legs"),
        P("box", (0.1 * s, 0.07 * s, 2.0 * s), (-0.1 * s, 0.3 * s, 0), "#1a0d1f", "leg", anim="legs"),
        P("box", (0.1 * s, 0.07 * s, 1.8 * s), (-0.5 * s, 0.3 * s, 0), "#1a0d1f", "leg", anim="legs"),
        P("prism", (0.3 * s, 0.45 * s, 0.15 * s), (-0.35 * s, 1.05 * s, 0), spikes, "glow", rot=(0, 0, 23), anim="pulse"),
        P("prism", (0.25 * s, 0.35 * s, 0.12 * s), (-0.7 * s, 0.92 * s, 0), spikes, "glow", rot=(0, 0, 34), anim="pulse"),
    ], "Монстры")
models["crawler"] = bug("Ползун", "#521f6b", "#2e0f40", "#ff2633", "#cc33ff")
models["brute"] = bug("Громила", "#661f0f", "#381209", "#ff800d", "#ff730d", 2.1)
models["spitter"] = bug("Плевун", "#1f6b3d", "#0f402a", "#ccff33", "#66ff33", 1.3)
models["runner"] = bug("Бегун", "#6b5c1f", "#40360f", "#ff3333", "#ffcc33", 0.8)

# ------------------------------------------------------------------ предметы на земле (дропы)
models["drop_box"] = M("Ящичек", [P("box", (0.45, 0.45, 0.45), (0, 0, 0), "#ffffff", "metal")], "Предметы")
models["drop_log"] = M("Бревно", [P("cylinder", (0.3, 0.9, 0.3), (0, 0, 0), "#7a5230", "wood", rot=(0, 0, 90), seg=7)], "Предметы")
models["drop_branch"] = M("Ветка", [
    P("cylinder", (0.12, 0.8, 0.12), (0, 0, 0), "#7a5230", "wood", rot=(0, 0, 80), seg=5),
    P("cylinder", (0.08, 0.35, 0.08), (0.1, 0.1, 0), "#7a5230", "wood", rot=(0, 0, 30), seg=4),
], "Предметы")
models["drop_stone"] = M("Камешек", [P("sphere", (0.45, 0.35, 0.4), (0, 0, 0), "#8c8a85", "stone", seg=6)], "Предметы")
models["drop_ore"] = M("Кусок руды", [P("sphere", (0.45, 0.38, 0.42), (0, 0, 0), "#ffffff", "stone", seg=5)], "Предметы")
models["drop_ingot"] = M("Слиток", [P("box", (0.55, 0.18, 0.28), (0, 0, 0), "#ffffff", "metal")], "Предметы")
models["drop_gear"] = M("Шестерня", [P("cylinder", (0.5, 0.12, 0.5), (0, 0, 0), "#ffffff", "metal", rot=(90, 0, 0), seg=8)], "Предметы")
models["drop_berry"] = M("Ягоды", [P("sphere", (0.3, 0.3, 0.3), (0, 0, 0), "#e0263d", "paint", seg=8)], "Предметы")
models["drop_tool"] = M("Инструмент", [
    P("box", (0.08, 0.8, 0.08), (0, 0, 0), "#7a5230", "wood"),
    P("box", (0.4, 0.15, 0.12), (0.1, 0.35, 0), "#8c949e", "metal"),
], "Предметы")

WOOD_H, MET = "#7a5230", "#b8bec7"
models["drop_axe"] = M("Топор", [
    P("box", (0.08, 0.85, 0.08), (0, 0, 0), WOOD_H, "wood", tint=False),
    P("box", (0.32, 0.26, 0.07), (0.14, 0.3, 0), "#ffffff", "metal"),
    P("prism", (0.12, 0.26, 0.07), (0.33, 0.3, 0), "#ffffff", "metal", rot=(0, 0, -90)),
], "Предметы")
models["drop_pickaxe"] = M("Кирка", [
    P("box", (0.08, 0.85, 0.08), (0, 0, 0), WOOD_H, "wood", tint=False),
    P("cylinder", (0.07, 0.75, 0.07), (0, 0.38, 0), "#ffffff", "metal", rot=(0, 0, 90), top=0.2, seg=6),
], "Предметы")
models["drop_sword"] = M("Меч", [
    P("box", (0.1, 0.7, 0.03), (0, 0.18, 0), "#ffffff", "metal"),
    P("prism", (0.1, 0.12, 0.03), (0, 0.59, 0), "#ffffff", "metal"),
    P("box", (0.3, 0.05, 0.07), (0, -0.18, 0), "#c9a227", "metal", tint=False),
    P("box", (0.06, 0.2, 0.06), (0, -0.3, 0), "#4a2e1a", "wood", tint=False),
], "Предметы")
models["drop_knife"] = M("Нож", [
    P("prism", (0.1, 0.4, 0.03), (0, 0.12, 0), "#ffffff", "metal"),
    P("box", (0.07, 0.22, 0.06), (0, -0.18, 0), "#4a2e1a", "wood", tint=False),
], "Предметы")
models["drop_gun"] = M("Бластер", [
    P("box", (0.55, 0.16, 0.12), (0.05, 0.1, 0), "#ffffff", "metal"),
    P("cylinder", (0.07, 0.3, 0.07), (0.42, 0.12, 0), "#2a2d33", "dark", rot=(0, 0, 90), tint=False, seg=8),
    P("box", (0.12, 0.28, 0.1), (-0.12, -0.08, 0), "#2a2d33", "dark", rot=(0, 0, -15), tint=False),
    P("box", (0.18, 0.04, 0.13), (0.08, 0.2, 0), "#40c8ff", "glow", tint=False),
], "Предметы")
models["drop_medkit"] = M("Аптечка", [
    P("box", (0.5, 0.36, 0.2), (0, 0, 0), "#f2f2f2", "paint", tint=False),
    P("box", (0.26, 0.08, 0.21), (0, 0, 0), "#e0263d", "paint", tint=False),
    P("box", (0.08, 0.26, 0.21), (0, 0, 0), "#e0263d", "paint", tint=False),
    P("box", (0.2, 0.06, 0.06), (0, 0.21, 0), "#555a60", "dark", tint=False),
], "Предметы")
models["drop_grenade"] = M("Граната", [
    P("sphere", (0.36, 0.42, 0.36), (0, 0, 0), "#ffffff", "metal", seg=8),
    P("cylinder", (0.14, 0.12, 0.14), (0, 0.24, 0), "#8c949e", "metal", tint=False, seg=8),
    P("torus", (0.14, 0.03, 0.14), (0.1, 0.3, 0), "#c9a227", "metal", rot=(90, 0, 0), tint=False),
], "Предметы")
models["drop_flask"] = M("Фляга", [
    P("cylinder", (0.32, 0.42, 0.32), (0, 0, 0), "#ffffff", "metal", seg=10),
    P("cylinder", (0.12, 0.12, 0.12), (0, 0.27, 0), "#2a2d33", "dark", tint=False, seg=8),
], "Предметы")
models["drop_vial"] = M("Пробирка", [
    P("cylinder", (0.16, 0.5, 0.16), (0, 0, 0), "#ffffff", "glow", seg=8),
    P("cylinder", (0.18, 0.1, 0.18), (0, 0.3, 0), "#555a60", "dark", tint=False, seg=8),
], "Предметы")
models["drop_ammo"] = M("Патроны", [
    P("box", (0.46, 0.22, 0.3), (0, -0.05, 0), "#5a6a3a", "metal", tint=False),
] + [P("cylinder", (0.07, 0.2, 0.07), (x, 0.12, 0), "#c9a227", "metal", tint=False, seg=6) for x in (-0.15, -0.05, 0.05, 0.15)], "Предметы")
models["drop_beacon"] = M("Маячок", [
    P("cylinder", (0.26, 0.3, 0.26), (0, -0.05, 0), "#3a3f47", "dark", tint=False, seg=8),
    P("sphere", (0.24, 0.24, 0.24), (0, 0.18, 0), "#ffffff", "glow", seg=8),
    P("cylinder", (0.03, 0.3, 0.03), (0.08, 0.3, 0), "#b8bec7", "metal", tint=False, seg=4),
], "Предметы")
models["drop_gift"] = M("Ящик удачи", [
    P("box", (0.42, 0.36, 0.42), (0, 0, 0), "#ffffff", "paint"),
    P("box", (0.08, 0.37, 0.43), (0, 0, 0), "#e0263d", "paint", tint=False),
    P("box", (0.43, 0.37, 0.08), (0, 0, 0), "#e0263d", "paint", tint=False),
    P("sphere", (0.14, 0.1, 0.14), (0, 0.22, 0), "#e0263d", "paint", tint=False, seg=6),
], "Предметы")
models["drop_battery"] = M("Батарея", [
    P("cylinder", (0.26, 0.5, 0.26), (0, 0, 0), "#ffffff", "metal", seg=10),
    P("cylinder", (0.1, 0.06, 0.1), (0, 0.28, 0), "#b8bec7", "metal", tint=False, seg=8),
], "Предметы")
models["drop_meat"] = M("Мясо", [
    P("sphere", (0.45, 0.25, 0.35), (0, 0, 0), "#ffffff", "flesh", seg=8),
    P("cylinder", (0.06, 0.25, 0.06), (0.25, 0, 0), "#f2ead8", "paint", rot=(0, 0, 90), tint=False, seg=5),
], "Предметы")

# ------------------------------------------------------------------ анимации
animations = {
    "spin":         {"name": "Вращение", "type": "spin", "speed": 5.0, "amount": 1.0, "always": False},
    "spin_fast":    {"name": "Быстрое вращение", "type": "spin", "speed": 10.0, "amount": 1.0, "always": False},
    "spin_slow":    {"name": "Медленное вращение", "type": "spin", "speed": 1.2, "amount": 1.0, "always": True},
    "pulse":        {"name": "Пульсация свечения", "type": "pulse", "speed": 3.0, "amount": 1.0, "always": True},
    "blink":        {"name": "Мигание", "type": "pulse", "speed": 9.0, "amount": 1.0, "always": True},
    "flicker":      {"name": "Огонь", "type": "flicker", "speed": 12.0, "amount": 1.0, "always": True},
    "flicker_soft": {"name": "Мерцание лампы", "type": "flicker", "speed": 4.0, "amount": 0.35, "always": True},
    "sway":         {"name": "Ветер", "type": "sway", "speed": 1.2, "amount": 0.05, "always": True},
    "wave":         {"name": "Флаг на ветру", "type": "wave", "speed": 4.0, "amount": 0.12, "always": True},
    "bob":          {"name": "Покачивание", "type": "bob", "speed": 7.0, "amount": 0.08, "always": False},
    "legs":         {"name": "Ноги жука", "type": "legs", "speed": 16.0, "amount": 0.18, "always": False},
    "breathe":      {"name": "Дыхание", "type": "breathe", "speed": 2.0, "amount": 0.05, "always": True},
    "swing":        {"name": "Маятник", "type": "swing", "speed": 2.0, "amount": 0.4, "always": True},
    "hover":        {"name": "Парение", "type": "bob", "speed": 2.0, "amount": 0.15, "always": True},
    "spin_drop":    {"name": "Вращение предмета", "type": "spin", "speed": 2.5, "amount": 1.0, "always": True},
    "jitter":       {"name": "Тряска", "type": "jitter", "speed": 30.0, "amount": 0.03, "always": False},
    "spin_wind":    {"name": "Лопасти ветряка", "type": "spin", "speed": 2.2, "amount": 1.0, "always": False},
    "gear_slow":    {"name": "Шестерня (большая)", "type": "spin", "speed": 2.0, "amount": 1.0, "always": False},
    "gear_fast":    {"name": "Шестерня (малая)", "type": "spin", "speed": 4.0, "amount": 1.0, "always": False},
    "spin_fan":     {"name": "Вентилятор", "type": "spin", "speed": 14.0, "amount": 1.0, "always": False},
    "piston_small": {"name": "Поршень гидроцилиндра", "type": "bob", "speed": 3.0, "amount": 0.18, "always": False},
}

# ------------------------------------------------------------------ предметы
items = {}
def I(id, name, desc, color, cat, stack=50, price=1, model="drop_box", **kw):
    d = {"name": name, "desc": desc, "color": color, "category": cat, "stack": stack, "price": price, "model": model}
    d.update(kw)
    items[id] = d
I("branch", "Ветка", "Тонкая ветка. Нужна для простых инструментов и растопки.", "#8a5a2e", "Сырьё", 50, 1, "drop_branch", fuel=4)
I("log", "Бревно", "Ствол дерева. Распилите на доски на верстаке.", "#7a5230", "Сырьё", 30, 2, "drop_log", fuel=12)
I("plank", "Доска", "Ровная доска для построек.", "#c49a6c", "Материалы", 50, 3, "drop_ingot", fuel=6)
I("fiber", "Волокно", "Жёсткая трава. Из неё плетут верёвку.", "#9cb847", "Сырьё", 50, 1, "drop_branch")
I("rope", "Верёвка", "Крепкая верёвка из волокна.", "#d9c28c", "Материалы", 50, 3)
I("berry", "Ягоды", "Съешь (ПКМ в инвентаре): +10 здоровья, утоляет голод. Портятся через 10 минут.", "#e0263d", "Еда", 30, 2, "drop_berry", heal=10, food=15, water=5, spoil=600)
I("mushroom", "Гриб", "Съедобный гриб: утоляет голод.", "#c2331f", "Еда", 30, 2, "drop_berry", heal=5, food=20, spoil=900)
I("stone", "Камень", "Обычный камень. Основа ранних построек.", "#9e9c97", "Сырьё", 50, 1, "drop_stone")
I("iron_ore", "Железная руда", "Переплавьте в печи, чтобы получить слитки.", "#9e6152", "Руда", 50, 2, "drop_ore")
I("copper_ore", "Медная руда", "Переплавьте в печи, чтобы получить медь.", "#f28c38", "Руда", 50, 2, "drop_ore")
I("coal", "Уголь", "Отличное топливо. Нужен для стали.", "#333338", "Руда", 50, 3, "drop_ore", fuel=30)
I("quartz", "Кварц", "Прозрачный минерал. Плавится в стекло.", "#e6f0ff", "Руда", 50, 4, "drop_ore")
I("sulfur", "Сера", "Жёлтый минерал для взрывчатки и батарей.", "#f2e633", "Руда", 50, 4, "drop_ore")
I("crystal", "Энергокристалл", "Редкий кристалл из глубин. Очень дорог на станции.", "#b34dff", "Руда", 20, 80, "drop_ore")
I("iron_ingot", "Железный слиток", "Базовый металл для деталей и машин.", "#c7ccd6", "Материалы", 50, 6, "drop_ingot")
I("copper_ingot", "Медный слиток", "Металл для проводов.", "#ff9e4d", "Материалы", 50, 6, "drop_ingot")
I("steel", "Сталь", "Прочный сплав железа и угля.", "#6e7887", "Материалы", 50, 15, "drop_ingot")
I("glass", "Стекло", "Для солнечных панелей и ламп.", "#b3e6ff", "Материалы", 50, 8, "drop_ingot")
I("concrete", "Бетон", "Для прочных стен и фундаментов.", "#dbd6c2", "Материалы", 50, 4, "drop_stone")
I("gear", "Шестерня", "Механическая деталь машин.", "#8c99b3", "Детали", 50, 16, "drop_gear")
I("iron_plate", "Железная пластина", "Листовой металл для корпусов.", "#a6adb8", "Детали", 50, 8, "drop_ingot")
I("wire", "Провод", "Медный провод.", "#ff731a", "Детали", 100, 5, "drop_branch")
I("circuit", "Микросхема", "Электроника для сложных машин.", "#33f273", "Детали", 50, 60, "drop_ingot")
I("motor", "Мотор", "Сердце продвинутых буров.", "#5973a6", "Детали", 20, 90, "drop_gear")
I("battery", "Батарея", "Хранит энергию.", "#ffd11a", "Детали", 20, 70, "drop_box")
I("ammo", "Патроны", "Боеприпасы для бластера героя и турелей. Турели берут их со склада штаба, герой — из инвентаря.", "#ffd933", "Оборона", 200, 3, "drop_box")
I("stone_axe", "Каменный топор", "Рубит деревья вдвое быстрее рук.", "#a6a39e", "Инструменты", 1, 10, "drop_tool", tool="axe", power=2.0, durability=120)
I("stone_pickaxe", "Каменная кирка", "Добывает камень и руду вдвое быстрее рук.", "#a6a39e", "Инструменты", 1, 10, "drop_tool", tool="pickaxe", power=2.0, durability=120)
I("iron_axe", "Железный топор", "Рубит деревья вчетверо быстрее рук.", "#c7ccd6", "Инструменты", 1, 40, "drop_tool", tool="axe", power=4.0, durability=400)
I("iron_pickaxe", "Железная кирка", "Добывает вчетверо быстрее рук.", "#c7ccd6", "Инструменты", 1, 40, "drop_tool", tool="pickaxe", power=4.0, durability=400)
I("medkit", "Аптечка", "Восстанавливает 100 здоровья.", "#ff4d4d", "Еда", 10, 40, "drop_box", heal=100)
I("rotten", "Гниль", "Испорченная еда. Годится только как топливо.", "#4d5a2e", "Еда", 50, 0, "drop_berry", fuel=2)
I("apple", "Яблоко", "Сочное яблоко с дуба-яблони: голод и немного воды.", "#e8402a", "Еда", 30, 2, "drop_berry", food=20, water=10, spoil=900)
I("water_flask", "Фляга воды", "Чистая вода. Наберите у озера (E) или сделайте на верстаке.", "#5ab4ff", "Еда", 10, 3, "drop_box", water=40)
I("jerky", "Сушёное мясо", "Сытная еда в дорогу, не портится.", "#8a4a2e", "Еда", 20, 8, "drop_box", food=45)
I("knife", "Нож", "Оружие ближнего боя: быстрые удары.", "#c0c7d1", "Оружие", 1, 15, "drop_tool", weapon="melee", damage=14, range=2.4, rate=0.35, durability=150)
I("sword", "Меч", "Тяжёлый клинок: сильный удар по монстрам.", "#d9dee6", "Оружие", 1, 60, "drop_tool", weapon="melee", damage=32, range=3.0, rate=0.55, durability=300)
I("blaster", "Бластер", "Стреляет патронами из инвентаря.", "#40c8ff", "Оружие", 1, 80, "drop_tool", weapon="gun", damage=11, range=38, rate=0.12, durability=800)
I("stim_speed", "Стимулятор бега", "+40% скорости бега на 60 секунд.", "#66ffcc", "Бустеры", 10, 30, "drop_box", boost={"stat": "move", "value": 0.4, "time": 60})
I("stim_gather", "Бодрящий настой", "+50% к скорости добычи на 90 секунд.", "#b8ff66", "Бустеры", 10, 30, "drop_box", boost={"stat": "gather", "value": 0.5, "time": 90})
I("stim_power", "Боевой стимулятор", "+50% урона на 45 секунд.", "#ff6680", "Бустеры", 10, 45, "drop_box", boost={"stat": "damage", "value": 0.5, "time": 45})
# предметы со своими действиями при использовании (on_use — те же действия, что у команд консоли)
I("grenade", "Граната", "Взрыв вокруг героя: 90 урона монстрам в радиусе 4 клеток.", "#5a6a3a", "Бой", 10, 12, "drop_box",
  on_use=[{"do": "explode", "x": "$x", "z": "$z", "v": "90", "dist": "4"}], use_sound="boom")
I("recall", "Маяк возврата", "Мгновенно переносит героя к штабу. Многоразовый.", "#40c8ff", "Разное", 1, 60, "drop_box",
  on_use=[{"do": "tp_hq"}, {"do": "notify", "text": "Вы дома"}], keep_on_use=True, use_sound="shuttle")
I("lucky_box", "Ящик удачи", "Откройте: внутри камни, а если повезёт — кристалл.", "#ffd040", "Разное", 20, 15, "drop_box",
  on_use=[{"do": "give", "item": "stone", "n": "5"}, {"do": "chance", "v": "0.3"}, {"do": "give", "item": "crystal", "n": "1"},
          {"do": "notify", "text": "Удача! Кристалл!"}], use_sound="coin")


# ---- формы предметов по типам (белые детали красятся в цвет предмета)
W_ = "#ffffff"
models["drop_ore"] = M("Кусок руды", [
    P("sphere", (0.36, 0.3, 0.34), (-0.08, 0.0, 0.0), W_, "stone", seg=5),
    P("sphere", (0.26, 0.22, 0.24), (0.15, -0.03, 0.08), W_, "stone", rot=(20, 40, 0), seg=4),
    P("sphere", (0.2, 0.18, 0.2), (0.06, -0.04, -0.15), W_, "stone", rot=(0, 70, 30), seg=4),
], "Предметы")
models["drop_crystal"] = M("Кристаллы", [
    P("cone", (0.16, 0.5, 0.16), (0, 0.05, 0), W_, "glow", seg=6),
    P("cone", (0.12, 0.36, 0.12), (0.12, -0.02, 0.05), W_, "glow", rot=(0, 0, -25), seg=6),
    P("cone", (0.11, 0.32, 0.11), (-0.11, -0.03, -0.04), W_, "glow", rot=(15, 0, 25), seg=6),
    P("sphere", (0.36, 0.12, 0.3), (0, -0.18, 0), "#5a5650", "stone", seg=5),
], "Предметы")
models["drop_ingot"] = M("Слиток", [
    P("box", (0.55, 0.14, 0.28), (0, -0.04, 0), W_, "metal"),
    P("box", (0.45, 0.08, 0.2), (0, 0.07, 0), W_, "metal"),
], "Предметы")
models["drop_plank"] = M("Доски", [
    P("box", (0.7, 0.07, 0.2), (0, -0.04, -0.06), W_, "wood"),
    P("box", (0.7, 0.07, 0.2), (0.03, 0.04, 0.06), W_, "wood", rot=(0, 8, 0)),
], "Предметы")
models["drop_rope"] = M("Моток верёвки", [
    P("torus", (0.42, 0.16, 0.42), (0, 0, 0), W_, "wood", seg=12),
    P("torus", (0.32, 0.14, 0.32), (0, 0.06, 0), W_, "wood", seg=12),
], "Предметы")
models["drop_plate"] = M("Пластина", [
    P("box", (0.55, 0.05, 0.42), (0, 0, 0), W_, "metal"),
    P("cylinder", (0.05, 0.03, 0.05), (0.22, 0.03, 0.16), "#4a4f57", "metal", seg=6),
    P("cylinder", (0.05, 0.03, 0.05), (-0.22, 0.03, 0.16), "#4a4f57", "metal", seg=6),
    P("cylinder", (0.05, 0.03, 0.05), (0.22, 0.03, -0.16), "#4a4f57", "metal", seg=6),
    P("cylinder", (0.05, 0.03, 0.05), (-0.22, 0.03, -0.16), "#4a4f57", "metal", seg=6),
], "Предметы")
models["drop_circuit"] = M("Микросхема", [
    P("box", (0.5, 0.04, 0.38), (0, 0, 0), "#1f5e35", "paint"),
    P("box", (0.16, 0.06, 0.16), (-0.08, 0.04, 0.02), "#1d1f24", "dark"),
    P("box", (0.1, 0.05, 0.08), (0.14, 0.035, -0.1), "#1d1f24", "dark"),
    P("box", (0.4, 0.012, 0.02), (0, 0.026, 0.14), W_, "glow"),
    P("box", (0.02, 0.012, 0.3), (0.18, 0.026, 0), W_, "glow"),
], "Предметы")
models["drop_wire"] = M("Катушка провода", [
    P("cylinder", (0.4, 0.04, 0.4), (0, -0.14, 0), "#6b4a2a", "wood", seg=12),
    P("cylinder", (0.4, 0.04, 0.4), (0, 0.14, 0), "#6b4a2a", "wood", seg=12),
    P("cylinder", (0.32, 0.24, 0.32), (0, 0, 0), W_, "metal", seg=12),
], "Предметы")
models["drop_motor"] = M("Мотор", [
    P("cylinder", (0.34, 0.42, 0.34), (0, 0.04, 0), W_, "paint", rot=(0, 0, 90), seg=10),
    P("cylinder", (0.06, 0.16, 0.06), (0.28, 0.04, 0), "#c7ccd6", "metal", rot=(0, 0, 90), seg=6),
    P("box", (0.4, 0.06, 0.26), (0, -0.14, 0), "#3a3f47", "dark"),
], "Предметы")
models["drop_glass"] = M("Стекло", [
    P("box", (0.5, 0.36, 0.04), (0, 0.02, 0), W_, "glass", rot=(-12, 0, 0)),
    P("box", (0.54, 0.05, 0.12), (0, -0.17, 0.03), "#5a5f68", "metal"),
], "Предметы")
models["drop_block"] = M("Блок", [P("box", (0.45, 0.3, 0.3), (0, 0, 0), W_, "concrete")], "Предметы")
models["drop_mushroom"] = M("Гриб", [
    P("cylinder", (0.1, 0.22, 0.1), (0, -0.06, 0), "#e8e0cc", "paint", seg=8),
    P("sphere", (0.32, 0.16, 0.32), (0, 0.06, 0), W_, "paint", seg=10),
], "Предметы")
models["drop_apple"] = M("Яблоко", [
    P("sphere", (0.3, 0.28, 0.3), (0, 0, 0), W_, "paint", seg=10),
    P("cylinder", (0.03, 0.1, 0.03), (0, 0.17, 0), "#5a3d26", "wood", seg=4),
    P("sphere", (0.1, 0.03, 0.06), (0.06, 0.19, 0), "#3f8a2f", "leaf", seg=5),
], "Предметы")
models["drop_fiber"] = M("Пучок волокна", [
    P("cylinder", (0.04, 0.6, 0.04), (0, 0, -0.04), W_, "leaf", rot=(0, 0, 85), seg=4),
    P("cylinder", (0.04, 0.6, 0.04), (0, 0.03, 0.03), W_, "leaf", rot=(0, 10, 80), seg=4),
    P("cylinder", (0.04, 0.6, 0.04), (0, -0.02, 0.07), W_, "leaf", rot=(0, -8, 88), seg=4),
    P("torus", (0.12, 0.08, 0.12), (0, 0, 0.02), "#7a5230", "wood", rot=(0, 0, 90), seg=8),
], "Предметы")
models["drop_fang"] = M("Клык", [P("cone", (0.14, 0.45, 0.14), (0, 0, 0), W_, "paint", rot=(0, 0, 70), seg=6)], "Предметы")
models["drop_chitin"] = M("Пластина хитина", [
    P("sphere", (0.5, 0.1, 0.38), (0, 0, 0), W_, "glass", seg=8),
    P("sphere", (0.3, 0.08, 0.24), (0.05, 0.05, 0), W_, "glass", seg=8),
], "Предметы")
models["drop_goo"] = M("Капля слизи", [
    P("sphere", (0.34, 0.24, 0.34), (0, -0.03, 0), W_, "glass", seg=10),
    P("sphere", (0.16, 0.14, 0.16), (0.04, 0.1, 0.02), W_, "glass", seg=8),
], "Предметы")
models["drop_core"] = M("Ядро", [
    P("sphere", (0.3, 0.3, 0.3), (0, 0, 0), W_, "glow", seg=10),
    P("torus", (0.44, 0.06, 0.44), (0, 0, 0), "#3a3f47", "metal", rot=(70, 0, 0), seg=14),
], "Предметы")
models["drop_geode"] = M("Жеода", [
    P("sphere", (0.4, 0.3, 0.38), (0, 0, 0), "#7a7670", "stone", seg=6),
    P("cone", (0.1, 0.22, 0.1), (0.06, 0.12, 0.02), W_, "glow", seg=5),
    P("cone", (0.08, 0.18, 0.08), (-0.06, 0.12, -0.04), W_, "glow", rot=(0, 0, 20), seg=5),
], "Предметы")
models["drop_coal"] = M("Уголь", [
    P("box", (0.3, 0.24, 0.26), (-0.06, 0, 0), W_, "stone", rot=(10, 30, 5)),
    P("box", (0.22, 0.2, 0.2), (0.14, -0.02, 0.06), W_, "stone", rot=(-15, 60, 10)),
], "Предметы")
models["drop_gear"] = M("Шестерня", [P("cylinder", (0.4, 0.1, 0.4), (0, 0, 0), W_, "metal", rot=(90, 0, 0), seg=12),
    P("cylinder", (0.12, 0.12, 0.12), (0, 0, 0), "#3a3f47", "dark", rot=(90, 0, 0), seg=8)] +
    [P("box", (0.1, 0.1, 0.1), (0.22 * math.cos(a * math.pi / 4), 0.22 * math.sin(a * math.pi / 4), 0), W_, "metal", rot=(0, 0, a * 45)) for a in range(8)], "Предметы")

# ------------------------------------------------------------------ ресурсы на карте
resources = {}
for _id, _m in {"stone_axe": "drop_axe", "iron_axe": "drop_axe", "stone_pickaxe": "drop_pickaxe", "iron_pickaxe": "drop_pickaxe",
                "sword": "drop_sword", "knife": "drop_knife", "blaster": "drop_gun", "medkit": "drop_medkit", "grenade": "drop_grenade",
                "water_flask": "drop_flask", "stim_speed": "drop_vial", "stim_gather": "drop_vial", "stim_power": "drop_vial",
                "ammo": "drop_ammo", "recall": "drop_beacon", "lucky_box": "drop_gift", "battery": "drop_battery",
                "raw_meat": "drop_meat", "jerky": "drop_meat",
                "plank": "drop_plank", "rope": "drop_rope", "iron_plate": "drop_plate", "circuit": "drop_circuit", "wire": "drop_wire",
                "motor": "drop_motor", "glass": "drop_glass", "concrete": "drop_block", "mushroom": "drop_mushroom", "apple": "drop_apple",
                "fiber": "drop_fiber", "fang": "drop_fang", "chitin": "drop_chitin", "goo": "drop_goo", "monster_core": "drop_core",
                "geode": "drop_geode", "coal": "drop_coal", "coal_hq": "drop_coal", "quartz": "drop_crystal", "crystal": "drop_crystal",
                "rotten": "drop_goo"}.items():
    if _id in items:
        items[_id]["model"] = _m

def R(id, name, model, hp, tool, drops, cat, blocks=True, stump="", respawn=0, scale=(0.8, 1.4), xp=1, low=False):
    resources[id] = {"name": name, "model": model, "hp": hp, "tool": tool, "drops": drops, "category": cat,
                     "blocks": blocks, "stump": stump, "respawn": respawn, "scale": list(scale), "xp": xp, "low": low}
def D(item, mn, mx, on="break", chance=1.0):
    return {"item": item, "min": mn, "max": mx, "on": on, "chance": chance}
R("tree_pine", "Ель", "tree_pine", 60, "axe", [D("branch", 1, 1, "hit", 0.5), D("log", 2, 4)], "Деревья", stump="stump")
R("tree_fir", "Пихта", "tree_fir", 80, "axe", [D("branch", 1, 1, "hit", 0.5), D("log", 3, 5)], "Деревья", stump="stump")
R("tree_oak", "Дуб-яблоня", "tree_oak", 90, "axe", [D("branch", 1, 2, "hit", 0.6), D("apple", 1, 1, "hit", 0.35), D("log", 3, 5), D("apple", 1, 3)], "Деревья", stump="stump")
R("tree_birch", "Берёза", "tree_birch", 50, "axe", [D("branch", 1, 1, "hit", 0.5), D("log", 2, 3)], "Деревья", stump="stump")
R("stump", "Пень", "stump", 12, "axe", [D("branch", 1, 2)], "Деревья", blocks=False, scale=(0.9, 1.1))
R("tree_dead", "Сухое дерево", "tree_dead", 30, "axe", [D("branch", 2, 4)], "Деревья")
R("bush_berry", "Ягодный куст", "bush_berry", 10, "", [D("berry", 2, 4), D("fiber", 0, 1)], "Кусты", blocks=False, respawn=180, scale=(0.8, 1.2))
R("bush_fiber", "Трава-волокно", "bush_fiber", 6, "", [D("fiber", 1, 3)], "Кусты", blocks=False, respawn=120, scale=(0.8, 1.3))
R("flowers", "Цветы", "flowers", 3, "", [D("fiber", 0, 1)], "Кусты", blocks=False, respawn=120, scale=(0.8, 1.3))
R("mushroom", "Гриб", "mushroom", 3, "", [D("mushroom", 1, 1)], "Кусты", blocks=False, respawn=240, scale=(0.8, 1.5))
R("glow_shroom", "Светогриб", "glow_shroom", 5, "", [D("mushroom", 1, 2)], "Кусты", blocks=False, respawn=240, scale=(0.8, 1.5))
R("cactus", "Кактус", "cactus", 20, "axe", [D("fiber", 2, 3)], "Кусты", scale=(0.8, 1.3), low=True)
R("rock_small", "Камень", "rock_small", 15, "", [D("stone", 1, 3)], "Камни", blocks=False, scale=(0.7, 1.3))
R("rock_big", "Валун", "rock_big", 70, "pickaxe", [D("stone", 1, 1, "hit", 0.7), D("stone", 4, 7)], "Камни", scale=(0.8, 1.5))
R("ore_iron", "Железная руда", "ore_iron", 50, "pickaxe", [D("iron_ore", 1, 1, "hit", 0.6), D("iron_ore", 2, 4)], "Руда", respawn=300, scale=(0.6, 1.0), low=True)
R("ore_copper", "Медная руда", "ore_copper", 50, "pickaxe", [D("copper_ore", 1, 1, "hit", 0.6), D("copper_ore", 2, 4)], "Руда", respawn=300, scale=(0.6, 1.0), low=True)
R("ore_coal", "Уголь", "ore_coal", 45, "pickaxe", [D("coal", 1, 1, "hit", 0.6), D("coal", 2, 4)], "Руда", respawn=300, scale=(0.6, 1.0), low=True)
R("ore_quartz", "Кварц", "ore_quartz", 60, "pickaxe", [D("quartz", 1, 1, "hit", 0.5), D("quartz", 2, 3)], "Руда", respawn=300, scale=(0.6, 1.0), low=True)
R("ore_sulfur", "Сера", "ore_sulfur", 60, "pickaxe", [D("sulfur", 1, 1, "hit", 0.5), D("sulfur", 2, 3)], "Руда", respawn=300, scale=(0.6, 1.0), low=True)
R("crystal", "Энергокристалл", "crystal", 120, "pickaxe", [D("crystal", 1, 3)], "Руда", scale=(0.8, 1.3), xp=10)

# ------------------------------------------------------------------ рецепты
recipes = {}
def C(id, name, inp, out, time, stations):
    recipes[id] = {"name": name, "in": inp, "out": out, "time": time, "stations": stations}
C("stone_axe", "Каменный топор", {"branch": 3, "stone": 2, "fiber": 2}, {"stone_axe": 1}, 2.0, ["hand", "workbench"])
C("stone_pickaxe", "Каменная кирка", {"branch": 3, "stone": 3, "fiber": 2}, {"stone_pickaxe": 1}, 2.0, ["hand", "workbench"])
C("rope", "Верёвка", {"fiber": 3}, {"rope": 1}, 1.0, ["hand", "workbench"])
C("plank", "Доски", {"log": 1}, {"plank": 3}, 1.5, ["workbench", "workshop"])
C("iron_axe", "Железный топор", {"plank": 2, "iron_ingot": 3, "rope": 1}, {"iron_axe": 1}, 3.0, ["workbench"])
C("iron_pickaxe", "Железная кирка", {"plank": 2, "iron_ingot": 4, "rope": 1}, {"iron_pickaxe": 1}, 3.0, ["workbench"])
C("medkit", "Аптечка", {"berry": 5, "fiber": 3, "glass": 1}, {"medkit": 1}, 3.0, ["workbench"])
C("knife", "Нож", {"stone": 2, "branch": 1, "fiber": 1}, {"knife": 1}, 2.0, ["hand", "workbench"])
C("sword", "Меч", {"iron_ingot": 4, "plank": 1, "rope": 1}, {"sword": 1}, 4.0, ["workbench", "workshop"])
C("blaster", "Бластер", {"iron_plate": 3, "gear": 2, "copper_ingot": 2}, {"blaster": 1}, 6.0, ["workshop"])
C("water_flask", "Фляга воды", {"plank": 1, "fiber": 2}, {"water_flask": 1}, 1.5, ["workbench"])
C("jerky", "Сушёное мясо", {"berry": 3, "mushroom": 2}, {"jerky": 1}, 4.0, ["furnace"])
C("stim_speed", "Стимулятор бега", {"berry": 4, "glass": 1}, {"stim_speed": 1}, 3.0, ["workbench"])
C("stim_gather", "Бодрящий настой", {"mushroom": 3, "glass": 1}, {"stim_gather": 1}, 3.0, ["workbench"])
C("stim_power", "Боевой стимулятор", {"crystal": 1, "glass": 1}, {"stim_power": 1}, 5.0, ["workshop"])
C("smelt_iron", "Железный слиток", {"iron_ore": 1}, {"iron_ingot": 1}, 2.0, ["furnace", "smelter"])
C("smelt_copper", "Медный слиток", {"copper_ore": 1}, {"copper_ingot": 1}, 2.0, ["furnace", "smelter"])
C("smelt_glass", "Стекло", {"quartz": 1}, {"glass": 1}, 2.5, ["furnace", "smelter"])
C("concrete", "Бетон", {"stone": 2}, {"concrete": 1}, 2.5, ["furnace", "smelter"])
C("steel", "Сталь", {"iron_ingot": 2, "coal": 1}, {"steel": 1}, 4.0, ["smelter"])
C("gear", "Шестерня", {"iron_ingot": 2}, {"gear": 1}, 2.0, ["workshop", "assembler"])
C("iron_plate", "Железная пластина", {"iron_ingot": 1}, {"iron_plate": 1}, 1.5, ["workshop", "assembler"])
C("wire", "Провод", {"copper_ingot": 1}, {"wire": 2}, 1.2, ["workshop", "assembler"])
C("circuit", "Микросхема", {"wire": 3, "iron_plate": 1, "glass": 1}, {"circuit": 1}, 4.0, ["workshop", "assembler"])
C("motor", "Мотор", {"gear": 2, "wire": 4, "steel": 1}, {"motor": 1}, 6.0, ["workshop", "assembler"])
C("battery", "Батарея", {"sulfur": 2, "copper_ingot": 2, "iron_plate": 1}, {"battery": 1}, 5.0, ["workshop", "assembler"])
C("ammo", "Патроны", {"iron_ingot": 1}, {"ammo": 6}, 1.0, ["workshop", "assembler"])
C("grenade", "Граната", {"iron_plate": 1, "sulfur": 2}, {"grenade": 2}, 2.0, ["workshop", "assembler"])
C("recall", "Маяк возврата", {"crystal": 1, "circuit": 1}, {"recall": 1}, 5.0, ["workshop"])
C("lucky_box", "Ящик удачи", {"plank": 2, "goo": 1}, {"lucky_box": 1}, 2.0, ["workbench"])

# ------------------------------------------------------------------ разделы меню строительства
categories = {
    "stations":   {"name": "Станции", "order": 0, "color": "#c49a6c"},
    "extraction": {"name": "Добыча", "order": 1, "color": "#f2a81f"},
    "production": {"name": "Производство", "order": 2, "color": "#4d8cff"},
    "energy":     {"name": "Энергетика", "order": 3, "color": "#ffd11a"},
    "logistics":  {"name": "Логистика", "order": 4, "color": "#a6adb8"},
    "special":    {"name": "Особые", "order": 8, "color": "#c070ff"},
    "storage":    {"name": "Хранение", "order": 5, "color": "#5cff8c"},
    "defense":    {"name": "Оборона", "order": 6, "color": "#ff4d33"},
    "decor":      {"name": "Декор", "order": 7, "color": "#d94db3"},
    "structure":  {"name": "Фундаменты", "order": 9, "color": "#b9b4a4"},
}

# ------------------------------------------------------------------ здания
buildings = {}
def B(id, name, desc, cat, behavior, cost, model, hp=200, size=1, **params):
    buildings[id] = {"name": name, "desc": desc, "category": cat, "behavior": behavior, "cost": cost,
                     "model": model, "hp": hp, "size": size, "params": params}
B("hq", "Штаб корпорации", "Сердце базы. Склад для всего, что приезжает по лентам. Отстреливается от монстров.", "", "hq", {}, "hq", 4000, 3, slots=60, gun_damage=12, gun_range=26, gun_rate=0.45, power=20, buildable=False)
B("workbench", "Верстак", "Ручной крафт: доски, инструменты, аптечки. Подойди и нажми E.", "stations", "station", {"log": 4, "stone": 4}, "workbench", 150, station="workbench")
B("workshop", "Мастерская", "Ручной крафт деталей: шестерни, провода, патроны. Подойди и нажми E.", "stations", "station", {"plank": 10, "stone": 10, "iron_ingot": 5}, "workshop", 250, station="workshop")
B("furnace", "Каменная печь", "Сама плавит руду, если в ней есть топливо (ветки, брёвна, уголь). Работает без электричества.", "production", "crafter", {"stone": 20}, "furnace", 300, station="furnace", speed=0.7, power=0, fuel=True)
B("smelter", "Плавильня", "Электрическая печь: быстрее, плавит сталь. Нужна энергия.", "production", "crafter", {"iron_ingot": 10, "concrete": 10, "gear": 2}, "smelter", 350, station="smelter", speed=1.5, power=8, tier=1)
B("assembler", "Сборщик", "Сам собирает детали по выбранному рецепту. Нужна энергия.", "production", "crafter", {"iron_ingot": 10, "gear": 4, "wire": 6}, "assembler", 350, station="assembler", speed=1.0, power=6, tier=1)
B("smelter_mk2", "Плавильня Mk2", "Плавит вдвое быстрее обычной плавильни, но и энергии берёт больше.", "production", "crafter", {"steel": 10, "circuit": 4, "motor": 2}, "smelter_mk2", 450, station="smelter", speed=3.0, power=18, tier=2)
B("assembler_mk2", "Сборщик Mk2", "Собирает вдвое быстрее, принимает до 6 видов сырья с любых сторон.", "production", "crafter", {"steel": 10, "circuit": 6, "motor": 2}, "assembler_mk2", 450, station="assembler", speed=2.0, power=14, tier=2, in_slots=6)
B("miner", "Бур", "Ставится на месторождение и выдаёт руду по стрелке. Нужна энергия.", "extraction", "miner", {"iron_ingot": 8, "gear": 4, "plank": 4}, "miner", 300, period=2.0, power=5, tier=1, any_ground=True)
B("miner_mk2", "Бур Mk2", "Вдвое быстрее обычного бура.", "extraction", "miner", {"steel": 6, "motor": 2, "circuit": 2}, "miner_mk2", 450, period=1.0, power=12, tier=2, any_ground=True)
B("belt", "Конвейер", "Везёт 60 предметов в минуту. Тяни мышью, чтобы проложить линию; повороты собираются сами.", "logistics", "belt", {"iron_ingot": 1}, "belt", 80, per_min=60, tier=1, any_ground=True)
B("belt_mk2", "Конвейер Mk2", "Вдвое быстрее: 120 предметов в минуту. Можно ставить прямо поверх старой ленты.", "logistics", "belt", {"iron_plate": 1, "gear": 1}, "belt_mk2", 100, per_min=120, tier=2, any_ground=True)
B("belt_mk3", "Конвейер Mk3", "Самая быстрая: 270 предметов в минуту.", "logistics", "belt", {"steel": 1, "motor": 1}, "belt_mk3", 120, per_min=270, tier=3, any_ground=True)
B("splitter", "Разделитель", "Делит поток по очереди вперёд, влево и вправо.", "logistics", "splitter", {"iron_ingot": 3, "gear": 1}, "splitter", 150)
B("merger", "Соединитель", "Собирает ленты сзади, слева и справа в одну — вперёд. Входы по очереди.", "logistics", "merger", {"iron_ingot": 3, "gear": 1}, "merger", 150)
B("smart_splitter", "Умный разделитель", "Разделитель с фильтрами: каждому выходу — свои предметы, «всё остальное» или «лишнее». Настройка — E.", "logistics", "splitter", {"iron_ingot": 4, "gear": 2, "circuit": 1}, "smart_splitter", 200, smart=True)
B("smart_merger", "Умный соединитель", "Соединитель с главным входом: он пропускается первым. Настройка — E.", "logistics", "merger", {"iron_ingot": 4, "gear": 2, "circuit": 1}, "smart_merger", 200, smart=True)
B("chest", "Ящик", "Хранит 16 стаков. Принимает предметы с лент.", "storage", "storage", {"plank": 6}, "chest", 150, slots=16)
B("container", "Контейнер", "Большое хранилище на 40 стаков.", "storage", "storage", {"iron_plate": 10, "steel": 2}, "container", 500, slots=40)
B("generator", "Генератор", "Сжигает топливо (ветки, брёвна, уголь) и даёт энергию всем машинам рядом с опорами.", "energy", "generator", {"iron_ingot": 10, "stone": 10, "gear": 2}, "generator", 300, power=40, radius=10)
B("solar", "Солнечная панель", "Даёт энергию днём, без топлива.", "energy", "generator", {"glass": 4, "iron_plate": 4, "wire": 4}, "solar", 150, power=12, solar=True, radius=6)
B("pole", "Опора ЛЭП", "Передаёт энергию: у опоры 4 разъёма, провода к зданиям и другим опорам тянутся клавишей V (новые здания рядом подключаются сами).", "energy", "pole", {"plank": 2, "wire": 2}, "pole", 100, radius=10, any_ground=True)
B("wind_turbine", "Ветряк", "Даёт энергию от ветра: чем сильнее ветер, тем больше. Топливо не нужно, но ветер то стихает, то крепчает — ставьте аккумуляторы.", "energy", "generator", {"iron_plate": 6, "gear": 4, "wire": 6}, "wind_turbine", 250, power=25, wind=True, radius=6, wire_height=6.4)
B("coal_generator", "Угольный генератор", "Мощная электростанция: жжёт уголь и даёт 75 энергии. Уголь можно подавать лентой.", "energy", "generator", {"steel": 8, "gear": 6, "wire": 8}, "coal_generator", 450, power=75, fuels=["coal"], burn_mult=1.5, radius=10, fuel_slots=2)
B("battery_block", "Аккумулятор", "Запасает лишнюю энергию на ночь.", "energy", "battery", {"battery": 4, "iron_plate": 4}, "battery", 250, capacity=2000, radius=4)
B("turret", "Турель", "Стреляет по монстрам. Берёт патроны со склада штаба.", "defense", "turret", {"iron_ingot": 8, "gear": 3}, "turret", 600, range=30, damage=14, rate=0.22, ammo="ammo", power=0)
B("laser_turret", "Лазерная турель", "Бьёт мощнее, патроны не нужны, нужна энергия.", "defense", "turret", {"steel": 6, "circuit": 4, "glass": 4}, "laser_turret", 800, range=36, damage=32, rate=0.35, ammo="", power=15)
B("wall_wood", "Деревянная стена", "Дешёвая преграда.", "defense", "wall", {"log": 2}, "wall_wood", 500)
B("wall", "Бетонная стена", "Прочная преграда для монстров.", "defense", "wall", {"concrete": 3}, "wall", 1600)
B("lamp", "Фонарь", "Освещает базу ночью.", "decor", "light", {"iron_ingot": 1, "glass": 1}, "lamp", 80, light_color="#ffe0a0", light_range=12)
B("found_1", "Фундамент 1×1", "Ровная площадка на холме или на воде. На нём можно строить, сверху можно ставить ещё ярусы.", "structure", "foundation", {"stone": 3}, "found_1x1", 1200, height=1.0)
B("found_2", "Фундамент 2×2", "Большая площадка 2×2 клетки. Ставится на землю, на воду или на другие фундаменты.", "structure", "foundation", {"stone": 10}, "found_2x2", 3000, size=2, height=1.0)
B("found_tall", "Фундамент 2 м", "Высокий ярус: поднимает площадку сразу на 2 метра.", "structure", "foundation", {"stone": 5}, "found_tall", 1600, height=2.0)
B("found_ramp", "Рампа", "Подъём на ярус выше: стрелка смотрит в сторону подъёма. На рампу нельзя ставить здания.", "structure", "foundation", {"stone": 3}, "found_ramp", 1000, height=1.0, ramp=True)
B("found_ramp2", "Пологая рампа 2×2", "Плавный подъём на ярус по двум клеткам.", "structure", "foundation", {"stone": 10}, "found_ramp2", 2400, size=2, height=1.0, ramp=True)
B("found_wall", "Стена фундамента", "Бетонная стена с окошком. Ставится на фундамент или на ровную землю, закрывает проход.", "structure", "wall", {"stone": 4}, "found_wall", 1400)
B("floor", "Плитка", "Красивый пол. По нему можно ходить.", "decor", "floor", {"stone": 2}, "floor", 100)
B("fence", "Забор", "Декоративный забор. Низкий: его можно перепрыгнуть.", "decor", "wall", {"plank": 2}, "fence", 150, low=True)
B("gate", "Ворота", "Герой проходит сквозь них, а монстры — нет: им придётся ломать.", "defense", "wall", {"iron_ingot": 6, "plank": 4}, "gate", 900, gate=True)
B("campfire", "Костёр", "Греет и светит ночью без электричества.", "decor", "light", {"log": 3, "stone": 4}, "lp_campfire", 80, light_color="#ffa040", light_range=10, power=0)
B("crates", "Ящики штабелем", "Декор для базы.", "decor", "decor", {"plank": 3}, "lp_crate", 80)
B("barrel", "Бочка", "Декор для базы. Низкая: можно перепрыгнуть.", "decor", "decor", {"iron_plate": 1}, "lp_barrel", 80, low=True)
B("sign", "Табличка", "Указатель для базы.", "decor", "decor", {"plank": 1}, "lp_sign", 60, low=True)
B("flag", "Флаг", "Флаг корпорации.", "decor", "decor", {"plank": 1, "fiber": 4}, "flag", 80)

# ------------------------------------------------------------------ здания из блоков поведения (примеры для редактора)
WHITE, RED = "#e8eaec", "#e0263d"
models["medbay"] = M("Медпункт", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), CONC, "concrete"),
    P("box", (1.4, 1.1, 1.4), (0, 0.85, 0), WHITE, "paint"),
    P("box", (0.5, 0.15, 0.15), (0, 1.0, 0.71), RED, "glow", anim="pulse"),
    P("box", (0.15, 0.5, 0.15), (0, 1.0, 0.71), RED, "glow", anim="pulse"),
    P("box", (1.5, 0.1, 1.5), (0, 1.45, 0), "#c9ccd1", "metal"),
    P("sphere", (0.3, 0.3, 0.3), (0, 1.62, 0), "#60ff90", "glow", anim="blink"),
], "Особые")
models["boost_beacon"] = M("Маяк ускорения", [
    P("cylinder", (1.2, 0.3, 1.2), (0, 0.15, 0), DARK, "dark", seg=8),
    P("cylinder", (0.3, 2.0, 0.3), (0, 1.3, 0), STEEL, "metal", seg=8),
    P("torus", (0.9, 0.12, 0.9), (0, 1.6, 0), "#40c8ff", "glow", anim="spin"),
    P("torus", (0.6, 0.1, 0.6), (0, 2.0, 0), "#40c8ff", "glow", anim="spin_fast"),
    P("sphere", (0.36, 0.36, 0.36), (0, 2.45, 0), "#a0f0ff", "glow", anim="pulse"),
], "Особые")
models["market"] = M("Торговый терминал", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.3, 1.4, 1.0), (0, 1.0, -0.2), "#2f8fd6", "paint"),
    P("box", (0.9, 0.6, 0.05), (0, 1.25, 0.31), "#ffd040", "glow", anim="flicker_soft"),
    P("box", (1.0, 0.2, 0.5), (0, 0.6, 0.5), DARK, "dark"),
    P("cylinder", (0.35, 0.08, 0.35), (0.3, 1.78, -0.2), "#ffd040", "metal", seg=12, anim="spin_slow"),
], "Особые")
models["monster_portal"] = M("Тёмный портал", [
    P("cylinder", (1.9, 0.25, 1.9), (0, 0.12, 0), "#2a2230", "dark", seg=10),
    P("torus", (1.5, 0.25, 1.5), (0, 1.2, 0), "#3a2d45", "dark", rot=(90, 0, 0)),
    P("cylinder", (1.2, 0.05, 1.2), (0, 1.2, 0), "#b040ff", "glow", rot=(90, 0, 0), anim="pulse", seg=16),
    P("cone", (0.25, 0.7, 0.25), (0.8, 0.5, 0), "#3a2d45", "dark", seg=5),
    P("cone", (0.25, 0.7, 0.25), (-0.8, 0.5, 0), "#3a2d45", "dark", seg=5),
], "Особые")
models["siren"] = M("Сирена", [
    P("box", (0.8, 0.2, 0.8), (0, 0.1, 0), DARK, "dark"),
    P("cylinder", (0.18, 1.8, 0.18), (0, 1.0, 0), STEEL, "metal", seg=6),
    P("cylinder", (0.6, 0.4, 0.6), (0, 2.0, 0), RED, "glow", anim="blink", seg=10),
    P("cone", (0.5, 0.5, 0.5), (0, 2.45, 0), DARK, "dark", seg=10),
], "Особые")
models["wood_boiler"] = M("Дровяной котёл", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), CONC, "concrete"),
    P("cylinder", (1.3, 1.2, 1.3), (0, 0.9, 0), "#7a4a2a", "metal", seg=10),
    P("box", (0.5, 0.4, 0.05), (0, 0.7, 0.64), "#ff8c1a", "glow", anim="flicker"),
    P("cylinder", (0.3, 1.2, 0.3), (0.4, 2.0, -0.3), DARK, "dark", seg=8),
    P("sphere", (0.2, 0.2, 0.2), (-0.4, 1.6, 0.3), "#40c8ff", "glow", anim="blink"),
], "Особые")
models["garden_bed"] = M("Грядка", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#6b4a2b", "wood"),
    P("box", (1.6, 0.1, 1.6), (0, 0.32, 0), "#3d2a1c", "rough"),
] + [P("sphere", (0.35, 0.4, 0.35), (x, 0.55, z), "#3c8a2e", "leaf", anim="sway") for x in (-0.45, 0.45) for z in (-0.45, 0.45)]
  + [P("sphere", (0.1, 0.1, 0.1), (x + 0.1, 0.7, z), RED, "paint") for x in (-0.45, 0.45) for z in (-0.45, 0.45)], "Особые")
models["tesla"] = M("Тесла-башня", [
    P("box", (1.6, 0.3, 1.6), (0, 0.15, 0), DARK, "dark"),
    P("cylinder", (0.6, 2.0, 0.6), (0, 1.3, 0), "#8c6a3a", "metal", top=0.6, seg=10),
    P("torus", (0.8, 0.12, 0.8), (0, 1.0, 0), "#b87333", "metal"),
    P("torus", (0.7, 0.12, 0.7), (0, 1.6, 0), "#b87333", "metal"),
    P("sphere", (0.7, 0.7, 0.7), (0, 2.6, 0), "#80c0ff", "glow", anim="pulse"),
], "Особые")
models["trap_mine"] = M("Мина-ловушка", [
    P("cylinder", (0.9, 0.18, 0.9), (0, 0.09, 0), "#4a5a3a", "metal", seg=10),
    P("cylinder", (0.3, 0.1, 0.3), (0, 0.22, 0), "#ff4d1a", "glow", anim="blink", seg=8),
], "Особые")
models["recycler"] = M("Утилизатор", [
    P("box", (1.8, 0.3, 1.8), (0, 0.15, 0), "#4a5260", "dark"),
    P("box", (1.4, 1.0, 1.4), (0, 0.8, 0), "#5a8a3a", "paint"),
    P("cylinder", (0.9, 0.3, 0.9), (0, 1.45, 0), DARK, "dark", anim="spin", seg=8),
    P("box", (0.12, 0.4, 0.9), (0.71, 0.9, 0), "#7dff5a", "glow", anim="pulse"),
], "Особые")

def BB(id, name, desc, behavior, cost, model, hp, blocks, **params):
    B(id, name, desc, "special", behavior, cost, model, hp, **params)
    buildings[id]["blocks"] = blocks

BB("medbay", "Медпункт", "Лечит героя и чинит здания рядом. Нужна энергия. (Собран из блоков — откройте в редакторе как пример.)", "decor",
   {"iron_plate": 4, "glass": 2, "medkit": 1}, "medbay", 300,
   [{"type": "heal_area", "radius": 6, "heal": 6, "repair": 10, "needs_power": True}], power=6)
BB("boost_beacon", "Маяк ускорения", "Рядом с ним герой бегает и добывает быстрее.", "decor",
   {"steel": 2, "crystal": 1, "wire": 4}, "boost_beacon", 200,
   [{"type": "buff_area", "radius": 10, "stat": "move", "value": 0.25, "needs_power": True},
    {"type": "buff_area", "radius": 10, "stat": "gather", "value": 0.3, "needs_power": True}], power=4)
BB("market", "Торговый терминал", "Продаёт всё, что в него привезут лентой или положат руками (80% цены).", "decor",
   {"iron_plate": 6, "circuit": 2}, "market", 300,
   [{"type": "sell", "items": [], "k": 0.8},
    {"type": "trigger", "event": "working", "cooldown": 1.0, "actions": [{"do": "sound", "key": "coin", "x": "$x", "z": "$z"}]}])
BB("monster_portal", "Тёмный портал", "Ночью призывает ползунов — опыт и трофеи прямо у базы. Разрушьте, и из него выпадет кристалл.", "decor",
   {"crystal": 2, "monster_core": 1}, "monster_portal", 400,
   [{"type": "spawn", "enemy": "crawler", "n": 2, "every": 40, "only_night": True},
    {"type": "trigger", "event": "night", "actions": [{"do": "notify", "text": "Тёмный портал пробудился!"}]},
    {"type": "trigger", "event": "destroyed", "actions": [{"do": "drop", "item": "crystal", "n": "2", "x": "$x", "z": "$z"}]}])
BB("siren", "Сирена", "Предупреждает, когда монстры подходят к ней или начинается волна.", "decor",
   {"iron_ingot": 2, "wire": 2}, "siren", 150,
   [{"type": "trigger", "event": "enemy_near", "radius": 12, "cooldown": 20,
     "actions": [{"do": "notify", "text": "Сирена: монстры рядом!"}, {"do": "sound", "key": "alarm", "x": "$x", "z": "$z"}]},
    {"type": "trigger", "event": "wave_start", "actions": [{"do": "sound", "key": "alarm", "x": "$x", "z": "$z"}]}])
BB("wood_boiler", "Дровяной котёл", "Маленький генератор на дровах: принимает топливо с ленты.", "decor",
   {"stone": 10, "iron_ingot": 4}, "wood_boiler", 250,
   [{"type": "power_gen", "power": 15, "radius": 6, "fuel": True}])
BB("garden_bed", "Грядка", "Сама выращивает ягоды. Поставьте ленту по стрелке — урожай поедет на склад.", "decor",
   {"plank": 4, "berry": 3}, "garden_bed", 100,
   [{"type": "produce", "item": "berry", "n": 1, "every": 20, "needs_power": False}])
BB("tesla", "Тесла-башня", "Бьёт молнией ближайшего монстра. Нужна энергия.", "decor",
   {"copper_ingot": 8, "circuit": 2, "steel": 2}, "tesla", 500,
   [{"type": "shoot", "damage": 22, "range": 18, "rate": 1.2, "color": "#80c0ff", "needs_power": True}], power=10)
BB("trap_mine", "Мина-ловушка", "Взрывается, когда монстр наступает рядом. Перезаряжается 30 секунд. Низкая — можно перепрыгнуть.", "decor",
   {"iron_plate": 1, "sulfur": 2}, "trap_mine", 60,
   [{"type": "trigger", "event": "enemy_near", "radius": 1.5, "cooldown": 30,
     "actions": [{"do": "explode", "x": "$x", "z": "$z", "v": "120", "dist": "3"}]}], low=True)
BB("recycler", "Утилизатор", "Перерабатывает трофеи с монстров в патроны: 2 хитина + 1 слизь → 5 патронов.", "decor",
   {"iron_ingot": 6, "gear": 2}, "recycler", 300,
   [{"type": "convert", "in": {"chitin": 2, "goo": 1}, "out": {"ammo": 5}, "time": 3, "needs_power": True}], power=5)

# ------------------------------------------------------------------ монстры и волны
enemies = {
    "crawler": {"name": "Ползун", "model": "crawler", "hp": 45, "speed": 6.0, "damage": 9, "rate": 0.7, "reach": 1.3, "reward": 4, "xp": 3, "behavior": "nearest", "radius": 0.8},
    "brute":   {"name": "Громила", "model": "brute", "hp": 320, "speed": 3.2, "damage": 45, "rate": 1.3, "reach": 2.2, "reward": 18, "xp": 15, "behavior": "base", "radius": 1.7},
    "spitter": {"name": "Плевун", "model": "spitter", "hp": 80, "speed": 4.0, "damage": 12, "rate": 1.5, "reach": 10.0, "reward": 8, "xp": 6, "behavior": "nearest", "radius": 1.0, "ranged": True},
    "runner":  {"name": "Бегун", "model": "runner", "hp": 25, "speed": 10.0, "damage": 6, "rate": 0.5, "reach": 1.1, "reward": 3, "xp": 2, "behavior": "player", "radius": 0.6},
}
waves = {
    "first_delay": 420, "interval": 150, "interval_min": 80, "interval_step": 8,
    "base_count": 4, "growth": 2.5, "night_mult": 1.4, "hp_growth": 0.06, "spawn_dist": 70,
    "groups": [
        {"enemy": "crawler", "weight": 10, "from_wave": 1},
        {"enemy": "runner", "weight": 4, "from_wave": 2},
        {"enemy": "spitter", "weight": 3, "from_wave": 3},
        {"enemy": "brute", "weight": 2, "from_wave": 3},
    ],
    "guards": {"enemy": "crawler", "count": 6, "boss": "brute"},
}

# ------------------------------------------------------------------ навыки и уровни
skills = {
    "gathering": {"name": "Собирательство", "desc": "+20% скорость добычи руками и инструментами", "max": 5, "bonus": {"gather": 0.2}},
    "engineering": {"name": "Инженерия", "desc": "+20% прочность зданий, авторемонт", "max": 5, "bonus": {"build_hp": 0.2, "repair": 1}},
    "mining": {"name": "Горное дело", "desc": "+25% скорость буров и печей", "max": 5, "bonus": {"machine_speed": 0.25}},
    "crafting": {"name": "Ремесло", "desc": "+25% скорость крафта", "max": 5, "bonus": {"craft_speed": 0.25}},
    "combat": {"name": "Оборона", "desc": "+25% урон турелей и героя", "max": 5, "bonus": {"damage": 0.25}},
    "athletics": {"name": "Атлетика", "desc": "+8% скорость бега, +20 здоровья", "max": 5, "bonus": {"move": 0.08, "max_hp": 20}},
    "trade": {"name": "Торговля", "desc": "+10% к цене продажи", "max": 5, "bonus": {"sell": 0.1}},
}
levels = {"base_xp": 60, "growth": 1.35, "points_per_level": 1, "max_level": 50,
          "xp": {"gather_hit": 1, "build": 4, "craft": 2, "kill": 1, "deliver": 0.1, "sell": 0.05}}

# ------------------------------------------------------------------ мир и настройки
world = {
    "size": 384, "seed": 0, "day_length": 480,
    "start_inventory": {"knife": 1},
    "start_hq": {"ammo": 60},
    "start_credits": 100,
    "deposits": [
        {"resource": "ore_iron", "item": "iron_ore", "color": "#8a4a3a", "patches": 40, "size_min": 2.5, "size_max": 5.5, "near_start": 2},
        {"resource": "ore_copper", "item": "copper_ore", "color": "#c27030", "patches": 30, "size_min": 2.5, "size_max": 5.0, "near_start": 1},
        {"resource": "ore_coal", "item": "coal", "color": "#26262b", "patches": 25, "size_min": 2.5, "size_max": 4.5, "near_start": 1},
        {"resource": "rock_big", "item": "stone", "color": "#7d7b76", "patches": 25, "size_min": 2.5, "size_max": 4.5, "near_start": 1},
        {"resource": "ore_quartz", "item": "quartz", "color": "#b8c4d1", "patches": 15, "size_min": 2.0, "size_max": 3.5, "near_start": 0},
        {"resource": "ore_sulfur", "item": "sulfur", "color": "#b3ad3d", "patches": 12, "size_min": 2.0, "size_max": 3.5, "near_start": 0},
    ],
    "deposit_rock_chance": 0.25,
    "flora": [
        {"resource": "tree_pine", "zone": "forest", "density": 0.28},
        {"resource": "tree_fir", "zone": "forest", "density": 0.10},
        {"resource": "tree_oak", "zone": "meadow", "density": 0.012},
        {"resource": "tree_birch", "zone": "forest_edge", "density": 0.08},
        {"resource": "tree_dead", "zone": "dry", "density": 0.02},
        {"resource": "bush_berry", "zone": "meadow", "density": 0.012},
        {"resource": "bush_fiber", "zone": "meadow", "density": 0.03},
        {"resource": "flowers", "zone": "meadow", "density": 0.02},
        {"resource": "mushroom", "zone": "forest", "density": 0.02},
        {"resource": "rock_small", "zone": "any", "density": 0.012},
        {"resource": "rock_big", "zone": "dry", "density": 0.01},
        {"resource": "cactus", "zone": "sand", "density": 0.04},
        {"resource": "glow_shroom", "zone": "forest", "density": 0.004},
        {"resource": "crystal", "zone": "far", "density": 0.0008},
    ],
    "lakes": 9, "rivers": 3, "sand_beaches": True,
    "nests": {"count": 7, "min_dist": 45, "max_dist": 150, "hp": 1500, "reward": 400},
    "start_clear_radius": 7,
    "map_sizes": [{"name": "Маленькая", "size": 256}, {"name": "Средняя", "size": 384}, {"name": "Большая", "size": 512},
                  {"name": "Огромная", "size": 768}, {"name": "Огромная ×2", "size": 1088}, {"name": "Огромная ×4", "size": 1536},
                  {"name": "Огромная ×8", "size": 2176}, {"name": "Огромная ×16", "size": 3072}, {"name": "Огромная ×32", "size": 4352}],
    "relief": 7.0, "relief_scale": 1.0, "hills": 0.4, "start_flat_radius": 22, "shore_flat": 6, "rocky_slopes": True,
}
settings = {
    "fov_enabled": True, "fov_angle": 120, "view_range": 60, "near_radius": 7,
    "drops_on_ground": True, "drop_glow_time": 60, "drop_lifetime": 300, "pickup_radius": 2.2,
    "hotbar_slots": 9, "hotbar_size": 56, "autosave_min": 5,
    "reach": 3.5, "strategy": False, "strategy_pan": 1.1, "face_move": True, "auto_aim": True, "aim_snap": 2.5, "aim_ring": True, "dblclick_move": True, "power_mode": "wires", "auto_wire": True, "wire_snap": 2.5, "wire_machines": True, "wire_show_targets": True, "auto_wire_radius": 8, "wire_length": 12, "wire_item": "", "wire_per_m": 10, "wire_color": "#1c1d22", "wire_width": 0.07, "fuses": True, "fuse_delay": 1.5, "wind_min": 0.2, "wind_max": 1.0, "wind_change": 1.0, "take_ready_button": True, "need_flat": True, "flat_tolerance": 0.6, "found_step": 1.0, "found_levels": 8, "climb_height": 0.7, "nodes_block_build": True, "monster_chase_time": 0.0, "monster_calm_time": 0.0, "monster_escape_dist": 16.0, "monster_escape_time": 10.0, "monster_attack_buildings": True, "monster_building_cells": 8, "ui_close_dist": 10.0, "wade": True, "minimap": True, "minimap_size": 200, "minimap_range": 220, "minimap_rotate": True, "minimap_round": True, "minimap_enemies": True, "bigmap": True, "bigmap_range": 900, "swing_raise": 2.7, "hero_gait": {"stride": 1.7, "swing": 30.0, "run_swing": 14.0, "knee": 55.0, "run_knee": 40.0, "duty": 0.6, "run_duty": 0.38, "bob": 0.05, "run_bob": 0.05, "roll": 4.0, "twist": 7.0, "lean": 4.0, "run_lean": 12.0, "turn_lean": 8.0, "arms": 32.0, "run_arms": 25.0}, "swing_hit": 0.8, "auto_inventory": True, "split_stacks": True, "trash": True, "wade_speed": 0.5, "wade_depth": 0.85, "take_all_button": True, "aim_color_res": "#ffe08a", "aim_color_enemy": "#ff5a46", "player_speed": 9.0, "player_sprint": 15.0, "player_hp": 200,
    "belt_speed": 2.0, "graphics": "high",
}
ui = {
    "accent": "#ffa040",
    "theme": {"font_scale": 1.15, "window_scale": 1.1, "corners": "cut", "radius": 10, "panel_color": "#121822", "panel_opacity": 0.95,
              "button_color": "#232b38", "frame": 1, "frame_alpha": 0.45, "header": "fill", "header_text": "#1a1206",
              "stripes": True, "bold_titles": True, "rich_tips": True},
    "panels": {
        "corp":      {"name": "Корпорация", "anchor": "tl", "pos": [16, 16], "opacity": 0.82, "visible": True, "scale": 1.0},
        "storage":   {"name": "Склад штаба", "anchor": "tl", "pos": [16, 210], "opacity": 0.82, "visible": True, "scale": 1.0},
        "minimap":   {"name": "Миникарта", "anchor": "tr", "pos": [16, 16], "opacity": 0.82, "visible": True, "scale": 1.0},
        "quests":    {"name": "Задачи", "anchor": "tr", "pos": [16, 232], "opacity": 0.82, "visible": True, "scale": 1.0},
        "hotbar":    {"name": "Быстрые слоты", "anchor": "bottom", "pos": [0, 14], "opacity": 0.9, "visible": True, "scale": 1.0},
        "info":      {"name": "Подсказка о здании", "anchor": "br", "pos": [16, 120], "opacity": 0.85, "visible": True, "scale": 1.0},
        "wave":      {"name": "Таймер волны", "anchor": "top", "pos": [0, 14], "opacity": 1.0, "visible": True, "scale": 1.0},
    },
    "windows": {
        "stats": {"title": "Статистика", "key": "F6", "anchor": "center", "pos": [0, 0], "size": [340, 0], "opacity": 0.9, "visible": False,
                  "elements": [
                      {"type": "label", "text": "Уровень: {level}   Очков навыков: {skill_points}"},
                      {"type": "bar", "bind": "xp_frac", "color": "#7fdcff", "text": "Опыт"},
                      {"type": "label", "text": "Кредиты: {credits}"},
                      {"type": "label", "text": "Убито монстров: {kills}"},
                      {"type": "label", "text": "Волн отбито: {waves}"},
                      {"type": "label", "text": "Зданий: {buildings}"},
                      {"type": "separator"},
                      {"type": "button", "text": "Открыть навыки", "action": "skills"},
                  ]},
    },
}


# ---------------------------------------------------------------- живые здания: дым, пар, пыль
models["furnace"]["emitters"] = [{"kind": "puff", "pos": [-0.4, 2.7, -0.4], "when": "active", "rate": 0.35, "size": 0.9}]
models["smelter"]["emitters"] = [{"kind": "puff", "pos": [-0.55, 3.1, -0.5], "when": "active", "rate": 0.3, "size": 1.0}]
models["generator"]["emitters"] = [{"kind": "puff", "pos": [-0.6, 2.5, -0.4], "when": "active", "rate": 0.25, "size": 1.1}]
models["assembler"]["emitters"] = [{"kind": "steam", "pos": [0.0, 1.8, 0.0], "when": "active", "rate": 1.4, "size": 0.7},
                                   {"kind": "sparks", "pos": [0.8, 1.0, 0.0], "when": "active", "rate": 2.0, "size": 0.6}]
models["assembler"]["parts"].append(P("box", (0.25, 0.5, 0.25), (-0.5, 1.75, 0.5), STEEL, "metal", anim="piston"))
# ---------------------------------------------------------------- уровни (Mk2, Mk3)
import copy as _copy
def _tier_model(src, name, recolor, extra=()):
    m = _copy.deepcopy(models[src])
    m["name"] = name
    for prt in m["parts"]:
        c = str(prt.get("color", "")).lower()
        if c in recolor:
            prt["color"] = recolor[c]
    m["parts"] += list(extra)
    return m
models["belt_mk2"] = _tier_model("belt", "Конвейер Mk2", {"#6b7079": "#4f6f9c"},
    [P("box", (0.2, 0.1, 1.45), (0.85, 0.05, 0), "#3a7bd5", "paint")])
models["belt_mk3"] = _tier_model("belt", "Конвейер Mk3", {"#6b7079": "#7a5aa6"},
    [P("box", (0.2, 0.1, 1.45), (0.85, 0.05, 0), "#b05cff", "glow")])
models["smelter_mk2"] = _tier_model("smelter", "Плавильня Mk2", {"#4d3329": "#5a5f69"},
    [P("box", (0.5, 0.18, 0.06), (0.3, 1.5, 0.79), "#3a7bd5", "paint"), P("box", (0.2, 0.18, 0.06), (0.75, 1.5, 0.79), "#ffffff", "glow")])
models["assembler_mk2"] = _tier_model("assembler", "Сборщик Mk2", {"#2e6bc7": "#7a2ec7"},
    [P("box", (0.5, 0.18, 0.06), (0.0, 1.2, 0.79), "#ffd11a", "paint")])
models["miner"]["emitters"] = [{"kind": "dust", "pos": [0.9, 0.2, 0.0], "when": "active", "rate": 0.9, "size": 0.7}]
models["miner_mk2"]["emitters"] = [{"kind": "dust", "pos": [-0.1, 0.45, 0.0], "when": "active", "rate": 1.2, "size": 0.8},
                                   {"kind": "puff", "pos": [-0.6, 3.8, -0.45], "when": "active", "rate": 0.6, "size": 0.7},
                                   {"kind": "dust", "pos": [0.95, 0.4, 0.0], "when": "active", "rate": 0.5, "size": 0.5}]
models["smelter_mk2"]["emitters"] = [{"kind": "puff", "pos": [-0.55, 3.1, -0.5], "when": "active", "rate": 0.5, "size": 1.0}]
models["assembler_mk2"]["emitters"] = [{"kind": "steam", "pos": [0.0, 1.8, 0.0], "when": "active", "rate": 2.0, "size": 0.7},
                                       {"kind": "sparks", "pos": [0.8, 1.0, 0.0], "when": "active", "rate": 3.0, "size": 0.6}]
animations["piston"] = {"name": "Поршень", "type": "bob", "speed": 4.0, "amount": 1.6}

# ---------------------------------------------------------------- мир: генератор и зацикленность
world.update({
    "map_mode": "procedural",   # procedural — новая карта каждую игру; fixed — готовая карта из файла
    "map_file": "",             # файл готовой карты в проекте (maps/имя.json)
    "wrap": True,               # мир без краёв
    "biome_scale": 1.0, "forest": 0.5, "dry": 0.5, "rocky": 0.5, "snow": 0.0,
    "lake_size": [4, 11], "river_width": [1.2, 2.2],
})
world["flora"].append({"resource": "tree_fir", "zone": "snow", "density": 0.08})
world["flora"].append({"resource": "rock_small", "zone": "snow", "density": 0.01})

# ---------------------------------------------------------------- игровые модули
settings.update({
    "modules": {"survival": False, "durability": True, "finite_ammo": True, "melee": True, "boosters": True, "professions": True},
    "hunger_rate": 0.25, "thirst_rate": 0.35, "starve_damage": 2.0,
    "difficulty": 1.0, "cheats": True, "season_look": "autumn",
})

# ---------------------------------------------------------------- звуки (имя действия -> файлы)
def S(files, vol=-8.0, pitch=0.08, positional=True, max_dist=100, cooldown=40, name=""):
    return {"name": name, "files": files if isinstance(files, list) else [files], "volume": vol, "pitch": pitch,
            "positional": positional, "max_dist": max_dist, "cooldown": cooldown}
snd = lambda n: "res://sounds/%s.wav" % n
sounds = {
    "shot": S(snd("shot"), -10, name="Выстрел героя"),
    "turret": S(snd("turret"), -13, name="Выстрел турели"),
    "boom": S(snd("boom"), -3, 0.1, max_dist=160, name="Взрыв, разрушение"),
    "thunder": S(snd("thunder"), -6, 0.15, max_dist=400, name="Гром бури за краем зоны"),
    "omen": S(snd("omen"), -4, 0.0, positional=False, name="Зловещее предупреждение перед событием"),
    "splat": S(snd("splat"), -9, name="Гибель монстра"),
    "place": S(snd("place"), -8, name="Постройка здания"),
    "coin": S(snd("coin"), -8, 0.0, False, name="Монеты, награда"),
    "repair": S(snd("repair"), -14, name="Ремонт"),
    "alarm": S(snd("alarm"), -6, 0.0, False, name="Тревога: волна"),
    "shuttle": S(snd("shuttle"), -4, 0.0, max_dist=300, name="Челнок станции"),
    "chop": S(snd("chop"), -6, 0.12, name="Удар по дереву"),
    "hit": S(snd("hit"), -8, 0.12, name="Удар по камню"),
    "pickup": S(snd("pickup"), -12, 0.1, False, cooldown=60, name="Подбор предмета"),
    "step": S(snd("step"), -20, 0.2, cooldown=120, name="Шаг"),
    "click": S(snd("click"), -14, 0.05, False, name="Клик в интерфейсе"),
    "craft": S(snd("craft"), -10, 0.0, False, name="Крафт готов"),
    "hurt": S(snd("hurt"), -8, 0.1, False, cooldown=200, name="Герою больно"),
    "bite": S(snd("bite"), -10, 0.15, name="Укус монстра"),
    "spit": S(snd("spit"), -10, 0.15, name="Плевок монстра"),
    "machine": S(snd("machine"), -16, 0.0, False, name="Гул работающих машин (петля)"),
    "fall": S(snd("fall"), -6, 0.1, name="Падение дерева"),
    "wind": S(snd("wind"), -20, 0.0, False, name="Ветер (фон)"),
    "eat": S(snd("pickup"), -10, 0.2, False, name="Еда"),
}
music = {
    "volume": -8.0, "crossfade": 3.0,
    "menu": [snd("music_night")], "day": [snd("music_day")], "night": [snd("music_night")], "wave": [snd("music_wave")],
    "ambient_day": "wind", "ambient_night": "wind",
}

# ---------------------------------------------------------------- меню настроек (можно расширять модами)
def O(key, name, typ, default, **kw):
    d = {"key": key, "name": name, "type": typ, "default": default}
    d.update(kw)
    return d
CH = lambda *pairs: [list(p) for p in pairs]
options = {"sections": [
    {"id": "controls", "name": "Управление", "items": [
        O("key_move_up", "Вперёд", "key", "W"), O("key_move_down", "Назад", "key", "S"),
        O("key_move_left", "Влево", "key", "A"), O("key_move_right", "Вправо", "key", "D"),
        O("key_sprint", "Бег", "key", "Shift"), O("key_jump", "Прыжок", "key", "Space"), O("key_interact", "Взаимодействие", "key", "E"),
        O("key_cam_left", "Повернуть камеру влево", "key", "Q"), O("key_cam_right", "Повернуть камеру вправо", "key", "Z"),
        O("key_rotate", "Повернуть здание", "key", "R"), O("key_demolish", "Разобрать", "key", "X"), O("key_wire", "Карта энергии (провода в режиме проводов)", "key", "V"), O("key_map", "Карта", "key", "M"),
        O("key_build_menu", "Меню строительства", "key", "B"), O("key_inventory", "Инвентарь", "key", "Tab"),
        O("key_craft", "Крафт", "key", "C"), O("key_skills", "Навыки", "key", "K"), O("key_trade", "Торговля", "key", "T"),
        O("key_help", "Помощь", "key", "H"), O("key_pause", "Пауза", "key", "P"), O("key_editor", "Редактор", "key", "F10"), O("key_console", "Консоль", "key", "QuoteLeft"),
        O("cam_speed", "Скорость поворота камеры", "slider", 1.0, min=0.3, max=3.0, step=0.1),
        O("cam_shake", "Тряска камеры (удары, взрывы, землетрясения)", "slider", 1.0, min=0.0, max=1.5, step=0.1),
        O("hitstop", "Замирание кадра при сильном ударе", "check", True),
        O("float_numbers", "Цифры урона и добычи над целью", "check", True),
        O("zoom_speed", "Скорость приближения", "slider", 1.0, min=0.3, max=3.0, step=0.1),
        O("strat_pan", "Стратегия: скорость камеры", "slider", 1.0, min=0.2, max=4.0, step=0.1),
        O("strat_pan_fast", "Стратегия: скорость камеры с Shift", "slider", 2.0, min=0.5, max=8.0, step=0.1),
        O("edge_scroll", "Камера следует за мышью у края", "check", False),
    ]},
    {"id": "audio", "name": "Звук", "items": [
        O("vol_master", "Общая громкость", "slider", 0.9, min=0, max=1, step=0.05),
        O("vol_music", "Музыка", "slider", 0.6, min=0, max=1, step=0.05),
        O("vol_effects", "Эффекты", "slider", 0.9, min=0, max=1, step=0.05),
        O("vol_ambient", "Фон (ветер, природа)", "slider", 0.7, min=0, max=1, step=0.05),
        O("vol_ui", "Интерфейс", "slider", 0.8, min=0, max=1, step=0.05),
    ]},
    {"id": "graphics", "name": "Графика", "items": [
        O("quality", "Пресет качества", "choice", "high", choices=CH(("low", "Низкое"), ("medium", "Среднее"), ("high", "Высокое"), ("ultra", "Ультра"), ("cinema", "Кино (качество 4K)"))),
        O("window_mode", "Режим окна", "choice", "fullscreen", choices=CH(("windowed", "Окно"), ("borderless", "Без рамки"), ("fullscreen", "Полный экран"))),
        O("resolution", "Разрешение окна", "choice", "auto", choices=CH(("auto", "Авто"), ("1280x720", "1280×720"), ("1600x900", "1600×900"), ("1920x1080", "1920×1080"), ("2560x1440", "2560×1440"), ("3840x2160", "3840×2160 (4K)"))),
        O("vsync", "Вертикальная синхронизация", "check", True),
        O("fps_limit", "Ограничение FPS", "choice", 0, choices=CH((0, "Нет"), (30, "30"), (60, "60"), (120, "120"), (144, "144"))),
        O("shadows", "Тени", "choice", "high", choices=CH(("off", "Выкл"), ("low", "Низкие"), ("high", "Высокие"), ("ultra", "Ультра"))),
        O("msaa", "Сглаживание MSAA", "choice", "4x", choices=CH(("off", "Выкл"), ("2x", "2x"), ("4x", "4x"), ("8x", "8x"))),
        O("fxaa", "Сглаживание FXAA", "check", False),
        O("ssao", "Затенение углов (SSAO)", "check", True),
        O("glow", "Свечение (bloom)", "check", True),
        O("ssil", "Отражённый свет (SSIL): цветные отсветы от земли и зданий", "check", True),
        O("dof", "Глубина резкости («миниатюра»: размытие дальнего плана)", "check", True),
        O("vignette", "Виньетка и цветокоррекция", "check", True),
        O("grass_dense", "Густая трава (пучки, дальше от героя)", "check", True),
        O("decor", "Цветы и украшения земли", "check", True),
        O("flora_less", "Меньше растительности (если игра лагает)", "check", False),
        O("render_scale", "Масштаб рендеринга (больше 1 — чётче, как 4K на обычном мониторе)", "slider", 1.0, min=0.5, max=2.0, step=0.05),
        O("detail_dist", "Дальность мелких деталей (болты, решётки), м", "slider", 90, min=30, max=300, step=10),
        O("aniso", "Чёткость текстур под углом", "choice", "4x", choices=CH(("off", "Выкл"), ("2x", "2x"), ("4x", "4x"), ("8x", "8x"), ("16x", "16x"))),
        O("soft_shadows", "Мягкие края теней", "choice", "medium", choices=CH(("off", "Выкл"), ("low", "Низкие"), ("medium", "Средние"), ("high", "Высокие"), ("ultra", "Ультра"))),
        O("lod_px", "Упрощение дальних моделей (больше — быстрее, вдали проще)", "choice", 2, choices=CH((0.5, "Почти нет"), (1, "Слабое"), (2, "Среднее"), (4, "Сильное"), (8, "Очень сильное"))),
        O("draw_distance", "Дальность прорисовки", "slider", 230, min=100, max=400, step=10),
        O("live_anim_max", "Живая анимация: сколько монстров рядом (меньше — быстрее)", "slider", 14, min=0, max=40, step=1),
        O("live_anim_dist", "Живая анимация: дальность, м", "slider", 45, min=15, max=80, step=5),
        O("auto_quality", "Автонастройка: снижать качество, если FPS падает", "check", True),
        O("auto_fps", "Автонастройка: держать FPS не ниже", "choice", 45, choices=CH((30, "30"), (45, "45"), (60, "60"))),
        O("show_fps", "Показывать FPS (F3)", "check", False),
        O("char_outline", "Обводка героя и монстров (после перезапуска)", "check", True),
    ]},
    {"id": "game", "name": "Игра", "items": [
        O("language", "Язык", "choice", "ru", choices=CH(("ru", "Русский"), ("en", "English"))),
        O("ui_scale", "Размер интерфейса", "slider", 1.0, min=0.7, max=1.6, step=0.05),
        O("fov_enabled", "Поле зрения героя", "check", True),
        O("fov_angle", "Угол обзора", "slider", 120, min=60, max=360, step=10),
        O("drops_on_ground", "Предметы падают на землю (иначе сразу в инвентарь)", "check", True),
        O("show_hints", "Подсказки", "check", True),
        O("autosave_min", "Автосохранение, минут (0 — выкл)", "slider", 5, min=0, max=30, step=1),
        O("hotbar_slots", "Ячеек в панели быстрого доступа", "slider", 9, min=4, max=12, step=1),
        O("hotbar_size", "Размер ячеек панели", "slider", 56, min=40, max=90, step=2),
        O("wheel_mode", "Колесо мыши", "choice", "hotbar", choices=CH(("hotbar", "Листает панель (с Ctrl — камера)"), ("zoom", "Приближает камеру (с Ctrl — панель)"))),
    ]},
]}

# ---------------------------------------------------------------- профессии
professions = {
    "engineer": {"name": "Инженер", "order": 0, "color": "#ffa040", "desc": "Сбалансированный выбор: без бонусов и штрафов.", "bonus": {}, "start_items": {}},
    "gatherer": {"name": "Собиратель", "order": 1, "color": "#7dd65a", "desc": "Быстрее добывает руками и инструментами, но ленты у него едут медленнее.",
                 "bonus": {"gather": 0.25, "belt_speed": -0.1}, "start_items": {"stone_axe": 1}},
    "mechanic": {"name": "Механик", "order": 2, "color": "#4d8cff", "desc": "Здания дешевле и прочнее, но бегает медленнее.",
                 "bonus": {"build_cost": -0.1, "build_hp": 0.15, "move": -0.2}, "start_items": {"plank": 10}},
    "soldier": {"name": "Солдат", "order": 3, "color": "#ff4d33", "desc": "Больше урона и здоровья, но крафт медленнее.",
                "bonus": {"damage": 0.3, "max_hp": 60, "craft_speed": -0.2}, "start_items": {"ammo": 40}},
    "trader": {"name": "Торговец", "order": 4, "color": "#ffd36b", "desc": "Продаёт дороже и начинает с деньгами, но слабее в бою.",
               "bonus": {"sell": 0.25, "damage": -0.15}, "start_credits": 300, "start_items": {}},
    "survivor": {"name": "Выживальщик", "order": 5, "color": "#c49a6c", "desc": "Медленнее голодает и быстрее лечится, но машины у него работают медленнее.",
                 "bonus": {"hunger": -0.35, "regen": 0.5, "machine_speed": -0.1}, "start_items": {"berry": 10}},
}

# ---------------------------------------------------------------- задачи (обучение)
# goal: have — иметь предмет (в рюкзаке + в штабе), build — построить здания (сумма), build_each — каждого вида,
# delivered — доставить в штаб лентами, skills — вложить очки навыков, trade — заработать на станции,
# waves — отбить волн, nests — уничтожить гнёзд, victory — победить, level — уровень героя, credits — накопить кредиты
def Q(order, text, reward, goal, n=1, item="", buildings=None, hint=""):
    return {"text": text, "order": order, "reward": reward, "goal": goal, "n": n, "item": item, "buildings": buildings or [], "hint": hint}
quests = {
    "q_logs": Q(0, "Добудьте 5 брёвен: подойдите к дереву и бейте ЛКМ", 20, "have", 5, "log"),
    "q_stone": Q(1, "Добудьте 8 камней из камней на земле", 20, "have", 8, "stone"),
    "q_axe": Q(2, "Сделайте каменный топор (C — крафт)", 30, "have", 1, "stone_axe"),
    "q_bench": Q(3, "Постройте верстак (B — строительство, раздел «Станции»)", 40, "build", 1, buildings=["workbench"]),
    "q_furnace": Q(4, "Постройте каменную печь и положите в неё руду и ветки (E по печи)", 60, "build", 1, buildings=["furnace"]),
    "q_ingots": Q(5, "Получите 10 железных слитков", 80, "have", 10, "iron_ingot"),
    "q_miner": Q(6, "Постройте генератор и бур на руде, протяните провод (V) от генератора к буру, а ленту — к печи", 120, "build_each", 1, buildings=["miner", "generator"]),
    "q_deliver": Q(7, "Доставьте лентами в штаб 30 любых предметов", 150, "delivered", 30),
    "q_turrets": Q(8, "Постройте 2 турели и положите патроны в штаб", 150, "build", 2, buildings=["turret", "laser_turret"]),
    "q_skill": Q(9, "Улучшите любой навык (K)", 60, "skills", 1),
    "q_trade": Q(10, "Продайте товары станции (T) на 300 кр", 200, "trade", 300),
    "q_waves": Q(11, "Отбейте 3 волны монстров", 300, "waves", 3),
    "q_nest": Q(12, "Уничтожьте гнездо монстров", 300, "nests", 1),
    "q_win": Q(13, "Уничтожьте все гнёзда на карте", 0, "victory", 1),
}

# ---------------------------------------------------------------- консоль: команды (своя команда = набор действий)
def CMD(desc, usage, actions, cheat=False):
    return {"desc": desc, "usage": usage, "actions": actions, "cheat": cheat}
commands = {
    "help": CMD("Список команд", "help", [{"do": "help"}]),
    "clear": CMD("Очистить консоль", "clear", [{"do": "clear"}]),
    "give": CMD("Выдать предмет", "give <предмет> [кол-во]", [{"do": "give", "item": "$1", "n": "$2|1"}], True),
    "giveall": CMD("По 50 штук всех предметов в штаб", "giveall", [{"do": "give_all", "n": "$1|50"}], True),
    "money": CMD("Добавить кредиты", "money <сумма>", [{"do": "credits", "n": "$1|1000"}], True),
    "xp": CMD("Добавить опыт", "xp <кол-во>", [{"do": "xp", "n": "$1|100"}], True),
    "god": CMD("Бессмертие вкл/выкл", "god", [{"do": "toggle", "flag": "god"}], True),
    "freebuild": CMD("Бесплатная стройка вкл/выкл", "freebuild", [{"do": "toggle", "flag": "free_build"}], True),
    "heal": CMD("Вылечить героя", "heal", [{"do": "heal"}], True),
    "tp": CMD("Телепорт в клетку", "tp <x> <z>", [{"do": "tp", "x": "$1", "z": "$2"}], True),
    "home": CMD("Телепорт к штабу", "home", [{"do": "tp_hq"}]),
    "time": CMD("Время суток (0..1, 0.5 — полдень)", "time <0..1>", [{"do": "time", "t": "$1|0.5"}], True),
    "timescale": CMD("Скорость игры", "timescale <x>", [{"do": "timescale", "x": "$1|1"}], True),
    "wave": CMD("Начать волну сейчас", "wave", [{"do": "wave"}], True),
    "nowaves": CMD("Волны вкл/выкл", "nowaves", [{"do": "toggle", "flag": "no_waves"}], True),
    "spawn": CMD("Призвать монстров рядом", "spawn <монстр> [кол-во]", [{"do": "spawn", "enemy": "$1|crawler", "n": "$2|1"}], True),
    "killall": CMD("Убить всех монстров", "killall", [{"do": "kill_all"}], True),
    "zone": CMD("Зона за бурей: zone — расширить на 1 блок даром, zone 20 — сделать 20×20", "zone [блоков]", [{"do": "zone", "n": "$1|0"}], True),
    "window": CMD("Открыть окно интерфейса: build, craft, tech, scan, trade, inventory…", "window <окно>", [{"do": "open", "window": "$1|scan"}]),
    "reveal": CMD("Поле зрения вкл/выкл", "reveal", [{"do": "toggle_pref", "key": "fov_enabled"}]),
    "cam_pitch": CMD("Наклон камеры в градусах (пусто — авто)", "cam_pitch <градусы>", [{"do": "cam", "what": "pitch", "v": "$1|0"}]),
    "cam_dist": CMD("Дальность камеры", "cam_dist <метры>", [{"do": "cam", "what": "dist", "v": "$1|34"}]),
    "cam_fov": CMD("Угол обзора камеры", "cam_fov <градусы>", [{"do": "cam", "what": "fov", "v": "$1|42"}]),
    "cam_max": CMD("Максимальное отдаление камеры", "cam_max <метры>", [{"do": "cam", "what": "max", "v": "$1|90"}]),
    "set": CMD("Изменить любую настройку игрока", "set <ключ> <значение>", [{"do": "pref", "key": "$1", "value": "$2"}]),
    "rule": CMD("Изменить правило игры (settings.json) до перезапуска", "rule <ключ> <значение>", [{"do": "setting", "key": "$1", "value": "$2"}], True),
    "quality": CMD("Пресет графики", "quality low|medium|high|ultra|cinema", [{"do": "pref", "key": "quality", "value": "$1|high"}]),
    "fps": CMD("Показать FPS", "fps", [{"do": "toggle", "flag": "show_fps"}]),
    "skillpoints": CMD("Добавить очки навыков", "skillpoints <n>", [{"do": "skill_points", "n": "$1|5"}], True),
    "day": CMD("Сделать полдень", "day", [{"do": "time", "t": "0.5"}], True),
    "night": CMD("Сделать полночь", "night", [{"do": "time", "t": "0.0"}], True),
    "starter": CMD("Набор для быстрой проверки: инструменты, материалы, кредиты", "starter",
                   [{"do": "give", "item": "iron_axe", "n": "1"}, {"do": "give", "item": "iron_pickaxe", "n": "1"},
                    {"do": "give_all", "n": "30"}, {"do": "credits", "n": "500"}, {"do": "echo", "text": "Стартовый набор выдан"}], True),
    "save": CMD("Сохранить игру", "save", [{"do": "save"}]),
    "attrpoints": CMD("Добавить очки характеристик", "attrpoints [n]", [{"do": "attr_points", "n": "$1|5"}], True),
    "kill": CMD("Герой погибает (вещи останутся в сундуке)", "kill", [{"do": "die"}], True),
    "pack": CMD("Призвать бродячую стаю рядом", "pack [расстояние]", [{"do": "spawn_pack", "dist": "$1|30"}], True),
    "echo": CMD("Вывести текст", "echo <текст>", [{"do": "echo", "text": "$*"}]),
}

# ---------------------------------------------------------------- редкие предметы и таблицы добычи (шанс выпадения)
I("iron_ore_hq", "Богатая железная руда", "Редкая чистая руда: в печи даёт 3 слитка вместо одного.", "#d07a5c", "Руда", 50, 12, "drop_ore", rarity="rare")
I("copper_ore_hq", "Богатая медная руда", "Редкая чистая руда: в печи даёт 3 слитка.", "#ffb060", "Руда", 50, 12, "drop_ore", rarity="rare")
I("coal_hq", "Антрацит", "Очень жаркий уголь: горит втрое дольше.", "#4a4a66", "Руда", 50, 10, "drop_ore", fuel=90, rarity="rare")
I("geode", "Жеода", "Каменный орех с кристаллами внутри. Расколите на верстаке.", "#9a7fd1", "Руда", 20, 30, "drop_stone", rarity="rare")
I("chitin", "Хитин", "Прочный панцирь монстра. Пойдёт на броню и инструменты.", "#6b8f3a", "Добыча с монстров", 50, 6, "drop_stone")
I("goo", "Слизь", "Липкая слизь монстра. Основа стимуляторов и лекарств.", "#8cff4d", "Добыча с монстров", 50, 4, "drop_berry")
I("fang", "Клык", "Острый клык. Пригодится для оружия.", "#f0ead6", "Добыча с монстров", 50, 8, "drop_branch")
I("monster_core", "Ядро монстра", "Светящееся ядро крупного монстра. Очень ценно.", "#ff4dd2", "Добыча с монстров", 20, 120, "drop_ore", rarity="epic")
I("raw_meat", "Сырое мясо", "Мясо монстра. Сырым есть опасно, лучше закоптить в печи.", "#c0504d", "Еда", 20, 3, "drop_berry", food=10, heal=-5, spoil=600)
items["raw_meat"]["model"] = "drop_meat"

C("smelt_iron_hq", "Слитки из богатой руды", {"iron_ore_hq": 1}, {"iron_ingot": 3}, 3.0, ["furnace", "smelter"])
C("smelt_copper_hq", "Медь из богатой руды", {"copper_ore_hq": 1}, {"copper_ingot": 3}, 3.0, ["furnace", "smelter"])
C("crack_geode", "Расколоть жеоду", {"geode": 1}, {"quartz": 2, "crystal": 1}, 3.0, ["workbench"])
C("smoke_meat", "Копчёное мясо", {"raw_meat": 2}, {"jerky": 1}, 4.0, ["furnace"])
C("bandage_goo", "Аптечка из слизи", {"goo": 4, "fiber": 2}, {"medkit": 1}, 3.0, ["workbench"])
C("fang_spear", "Меч с клыками", {"fang": 4, "iron_ingot": 2, "rope": 1}, {"sword": 1}, 4.0, ["workbench"])
C("stim_core", "Боевой стимулятор из ядра", {"monster_core": 1, "goo": 2}, {"stim_power": 3}, 5.0, ["workshop"])

# ручная добыча: у жил и камней шанс на редкое
resources["ore_iron"]["drops"] += [D("iron_ore_hq", 1, 1, "hit", 0.01), D("iron_ore_hq", 1, 1, "break", 0.05)]
resources["ore_copper"]["drops"] += [D("copper_ore_hq", 1, 1, "hit", 0.01), D("copper_ore_hq", 1, 1, "break", 0.05)]
resources["ore_coal"]["drops"] += [D("coal_hq", 1, 1, "hit", 0.02)]
resources["rock_big"]["drops"] += [D("geode", 1, 1, "break", 0.03)]
resources["rock_small"]["drops"] += [D("geode", 1, 1, "break", 0.01)]
# буры: что ещё может выпасть при каждой выработке, кроме основной руды
for dep in world["deposits"]:
    extra = {"iron_ore": [{"item": "iron_ore_hq", "chance": 0.01}], "copper_ore": [{"item": "copper_ore_hq", "chance": 0.01}],
             "coal": [{"item": "coal_hq", "chance": 0.02}], "stone": [{"item": "geode", "chance": 0.005}]}.get(dep["item"], [])
    dep["drops"] = extra
# монстры: таблицы добычи
enemies["crawler"]["drops"] = [{"item": "chitin", "chance": 0.5, "min": 1, "max": 2}, {"item": "goo", "chance": 0.3, "min": 1, "max": 1}, {"item": "raw_meat", "chance": 0.25, "min": 1, "max": 1}]
enemies["runner"]["drops"] = [{"item": "fang", "chance": 0.4, "min": 1, "max": 2}, {"item": "raw_meat", "chance": 0.3, "min": 1, "max": 1}]
enemies["spitter"]["drops"] = [{"item": "goo", "chance": 0.8, "min": 1, "max": 3}, {"item": "chitin", "chance": 0.3, "min": 1, "max": 1}]
enemies["brute"]["drops"] = [{"item": "chitin", "chance": 1.0, "min": 2, "max": 4}, {"item": "raw_meat", "chance": 0.8, "min": 1, "max": 3},
                             {"item": "monster_core", "chance": 0.08, "min": 1, "max": 1}]

# ---------------------------------------------------------------- бродячие стаи (кроме волн)
waves["roaming"] = {
    "enabled": True, "first_delay": 90, "interval": 70, "max_packs": 6, "max_monsters": 40,
    "pack_min": 3, "pack_max": 6, "spawn_min_dist": 55, "spawn_max_dist": 110, "base_safe_radius": 35,
    "aggro_radius": 18, "lose_radius": 40, "wander_speed": 0.45, "wander_radius": 14, "night_mult": 1.5,
    "groups": [
        {"enemy": "crawler", "weight": 10, "from_day": 1},
        {"enemy": "runner", "weight": 5, "from_day": 1},
        {"enemy": "spitter", "weight": 3, "from_day": 2},
        {"enemy": "brute", "weight": 1, "from_day": 3, "leader": True},
    ],
}

# ---------------------------------------------------------------- характеристики героя (очки за уровень)
attributes = {
    "strength": {"name": "Сила", "desc": "+5% урона, +4% скорости добычи", "color": "#ff7a5a", "max": 20, "order": 1, "bonus": {"damage": 0.05, "gather": 0.04}},
    "agility": {"name": "Ловкость", "desc": "+3% скорости бега, +4% скорости атаки, прыжок выше", "color": "#66e0ff", "max": 20, "order": 2, "bonus": {"move": 0.03, "attack_speed": 0.04, "jump": 0.05}},
    "endurance": {"name": "Выносливость", "desc": "Медленнее голод и жажда (−4%), +5% к восстановлению", "color": "#ffd36b", "max": 20, "order": 3, "bonus": {"hunger": -0.04, "regen": 0.05}},
    "vitality": {"name": "Живучесть", "desc": "+15 к здоровью", "color": "#7dff9a", "max": 20, "order": 4, "bonus": {"max_hp": 15}},
    "intellect": {"name": "Интеллект", "desc": "+4% скорости крафта, +3% опыта", "color": "#c18cff", "max": 20, "order": 5, "bonus": {"craft_speed": 0.04, "xp": 0.03}},
}
levels["attr_points_per_level"] = 2
levels["xp"]["kill"] = 2

# ---------------------------------------------------------------- смерть героя и прыжок
settings["death"] = {"mode": "chest", "respawn_time": 6, "keep_hotbar": False, "chest_lifetime": 0, "lose_credits": 0.0}
settings["belt_ports"] = True
settings["port_in_color"] = "#f2a81f"
settings["port_out_color"] = "#5cff8c"
settings["jump_height"] = 1.5
settings["jump_time"] = 0.55
# 1.3: прыжок с силой тяжести и походка как у человека (player.gd _animate/_update_jump)
settings["jump_gravity"] = 25.0
settings["fall_gravity_k"] = 1.5
settings["jump_crouch"] = 0.08
settings["step_down"] = 0.75
settings["hero_gait"] = {"stride": 1.0, "max_freq": 2.3, "swing": 24.0, "run_swing": 40.0, "knee": 12.0, "run_knee": 34.0,
    "swing_knee": 60.0, "run_swing_knee": 100.0, "duty": 0.62, "run_duty": 0.36, "sprint_duty": 0.25,
    "pelvis": 5.0, "run_pelvis": 8.0, "roll": 4.0, "twist": 0.6, "lean": 3.0, "run_lean": 9.0, "turn_lean": 8.0,
    "arms": 18.0, "run_arms": 38.0, "elbow": 14.0, "run_elbow": 85.0}
models["grave_chest"] = M("Сундук героя", [
    P("box", (1.0, 0.55, 0.7), (0, 0.28, 0), "#6b4a2b", "wood"),
    P("box", (1.04, 0.16, 0.74), (0, 0.6, 0), "#4a3220", "wood"),
    P("box", (0.16, 0.2, 0.06), (0, 0.45, 0.37), "#ffd36b", "metal"),
    P("box", (0.05, 1.3, 0.05), (0.42, 1.0, -0.3), "#d9d9d9", "metal"),
    P("box", (0.5, 0.3, 0.02), (0.6, 1.5, -0.3), "#ff4d4d", "glow", anim="wave"),
], "Разное")

# ------------------------------------------------------------------ библиотека готовых деталей для редактора моделей
# Деталь — маленькая модель с "library": "part". В редакторе: «+ Готовая деталь…».
def LP(name, cat, parts):
    m = M(name, parts, "Детали: " + cat)
    m["library"] = "part"
    return m

def LT(name, parts, cat="Заготовки"):
    m = M(name, parts, cat)
    m["library"] = "template"
    return m

def ring(n, r, y, make):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        out.append(make(round(math.cos(a) * r, 3), y, round(math.sin(a) * r, 3), round(-math.degrees(a), 1)))
    return out

GL = "#a8d8ff"
# техника
models["lp_pipe"] = LP("Труба прямая", "Техника", [
    P("cylinder", (0.3, 1.6, 0.3), (0, 0.15, 0), STEEL, "metal", rot=(0, 0, 90), seg=10),
    P("cylinder", (0.38, 0.12, 0.38), (0.75, 0.15, 0), DARK, "dark", rot=(0, 0, 90), seg=10),
    P("cylinder", (0.38, 0.12, 0.38), (-0.75, 0.15, 0), DARK, "dark", rot=(0, 0, 90), seg=10)])
models["lp_pipe_bend"] = LP("Труба с коленом", "Техника", [
    P("cylinder", (0.3, 1.0, 0.3), (0, 0.5, 0), STEEL, "metal", seg=10),
    P("sphere", (0.34, 0.34, 0.34), (0, 1.0, 0), STEEL, "metal"),
    P("cylinder", (0.3, 0.8, 0.3), (0.4, 1.0, 0), STEEL, "metal", rot=(0, 0, 90), seg=10),
    P("cylinder", (0.38, 0.1, 0.38), (0.8, 1.0, 0), DARK, "dark", rot=(0, 0, 90), seg=10)])
models["lp_tank"] = LP("Бак вертикальный", "Техника", [
    P("cylinder", (1.2, 1.6, 1.2), (0, 0.9, 0), "#c9ced6", "metal", seg=16),
    P("sphere", (1.2, 0.5, 1.2), (0, 1.7, 0), "#c9ced6", "metal"),
    P("cylinder", (1.26, 0.1, 1.26), (0, 0.5, 0), YEL, "paint", seg=16),
    P("cylinder", (1.26, 0.1, 1.26), (0, 1.3, 0), YEL, "paint", seg=16),
    P("box", (0.2, 0.1, 0.3), (0, 0.05, 0.45), DARK, "dark"), P("box", (0.2, 0.1, 0.3), (0, 0.05, -0.45), DARK, "dark")])
models["lp_tank_h"] = LP("Цистерна", "Техника", [
    P("capsule", (0.9, 2.2, 0.9), (0, 0.75, 0), "#d6dade", "metal", rot=(0, 0, 90)),
    P("box", (0.2, 0.3, 0.8), (-0.6, 0.15, 0), DARK, "dark"), P("box", (0.2, 0.3, 0.8), (0.6, 0.15, 0), DARK, "dark"),
    P("cylinder", (0.2, 0.2, 0.2), (0, 1.25, 0), DARK, "dark", seg=8)])
models["lp_gear"] = LP("Шестерня", "Техника", [
    P("cylinder", (0.9, 0.15, 0.9), (0, 0.6, 0), STEEL, "metal", rot=(90, 0, 0), anim="spin", seg=16),
    P("cylinder", (0.25, 0.25, 0.25), (0, 0.6, 0), DARK, "dark", rot=(90, 0, 0), seg=8)] +
    [P("box", (0.16, 0.16, 0.15), (round(math.cos(a) * 0.5, 3), round(0.6 + math.sin(a) * 0.5, 3), 0), STEEL, "metal",
       rot=(0, 0, round(math.degrees(a), 1)), anim="spin") for a in [i * math.pi / 5 for i in range(10)]])
models["lp_fan"] = LP("Вентилятор", "Техника", [
    P("torus", (1.1, 0.25, 1.1), (0, 0.6, 0), DARK, "dark", rot=(90, 0, 0)),
    P("cylinder", (0.2, 0.2, 0.2), (0, 0.6, 0.02), STEEL, "metal", rot=(90, 0, 0), seg=8)] +
    [P("box", (0.12, 0.42, 0.04), (round(math.cos(a) * 0.22, 3), round(0.6 + math.sin(a) * 0.22, 3), 0.03), STEEL, "metal",
       rot=(20, 0, round(math.degrees(a) - 90, 1)), anim="spin_fast") for a in [i * 2 * math.pi / 4 for i in range(4)]])
models["lp_blades"] = LP("Лопасти (ветряк)", "Техника", [
    P("sphere", (0.3, 0.3, 0.4), (0, 1.0, 0.1), "#e6e6e6", "paint", anim="spin_slow")] +
    [P("box", (0.16, 1.1, 0.04), (round(math.cos(a) * 0.6, 3), round(1.0 + math.sin(a) * 0.6, 3), 0.1), "#f2f2f2", "paint",
       rot=(0, 0, round(math.degrees(a) - 90, 1)), anim="spin_slow") for a in [i * 2 * math.pi / 3 for i in range(3)]])
models["lp_wheel"] = LP("Колесо", "Техника", [
    P("cylinder", (0.7, 0.28, 0.7), (0, 0.35, 0), "#25272b", "dark", rot=(90, 0, 0), seg=16),
    P("cylinder", (0.4, 0.3, 0.4), (0, 0.35, 0), STEEL, "metal", rot=(90, 0, 0), seg=10)])
models["lp_piston"] = LP("Поршень", "Техника", [
    P("cylinder", (0.4, 0.8, 0.4), (0, 0.4, 0), DARK, "dark", seg=10),
    P("cylinder", (0.18, 0.7, 0.18), (0, 0.95, 0), "#d9dde3", "metal", anim="piston", seg=8)])
models["lp_drill"] = LP("Бур-наконечник", "Техника", [
    P("cylinder", (0.6, 0.3, 0.6), (0, 0.85, 0), DARK, "dark", anim="spin_fast", seg=10),
    P("cone", (0.55, 0.8, 0.55), (0, 0.35, 0), STEEL, "metal", rot=(180, 0, 0), anim="spin_fast", seg=10)])
models["lp_panel"] = LP("Пульт с экраном", "Техника", [
    P("box", (0.8, 1.0, 0.4), (0, 0.5, 0), "#3a3f47", "dark"),
    P("box", (0.6, 0.35, 0.03), (0, 0.72, 0.21), "#40c8ff", "glow", anim="flicker_soft"),
    P("box", (0.1, 0.1, 0.03), (-0.2, 0.35, 0.21), "#7dff5a", "glow", anim="blink"),
    P("box", (0.1, 0.1, 0.03), (0.0, 0.35, 0.21), "#ffd040", "glow"),
    P("box", (0.1, 0.1, 0.03), (0.2, 0.35, 0.21), "#ff4d4d", "glow", anim="pulse")])
models["lp_antenna"] = LP("Антенна", "Техника", [
    P("cylinder", (0.06, 2.0, 0.06), (0, 1.0, 0), STEEL, "metal", seg=6),
    P("box", (0.5, 0.04, 0.04), (0, 1.6, 0), STEEL, "metal"), P("box", (0.35, 0.04, 0.04), (0, 1.8, 0), STEEL, "metal"),
    P("sphere", (0.1, 0.1, 0.1), (0, 2.05, 0), "#ff4d1a", "glow", anim="blink")])
models["lp_dish"] = LP("Тарелка-радар", "Техника", [
    P("cylinder", (0.12, 0.8, 0.12), (0, 0.4, 0), STEEL, "metal", seg=8),
    P("cylinder", (1.0, 0.25, 1.0), (0, 1.0, 0), "#e6e9ee", "paint", rot=(-60, 0, 0), top=1.6, seg=16, anim="spin_slow"),
    P("cylinder", (0.05, 0.4, 0.05), (0, 1.15, 0.15), DARK, "dark", rot=(-60, 0, 0), anim="spin_slow")])
models["lp_chimney"] = LP("Дымовая труба", "Техника", [
    P("cylinder", (0.45, 1.8, 0.45), (0, 0.9, 0), "#8a5a44", "stone", seg=10),
    P("cylinder", (0.55, 0.15, 0.55), (0, 1.8, 0), DARK, "dark", seg=10),
    P("cylinder", (0.5, 0.1, 0.5), (0, 0.9, 0), "#e04a3a", "paint", seg=10)])
models["lp_battery_cell"] = LP("Энергоячейка", "Техника", [
    P("box", (0.5, 0.9, 0.5), (0, 0.45, 0), "#2a2d33", "dark"),
    P("box", (0.06, 0.6, 0.52), (0, 0.45, 0), "#7dff5a", "glow", anim="pulse"),
    P("cylinder", (0.18, 0.1, 0.18), (0, 0.95, 0), STEEL, "metal", seg=8)])
models["lp_conveyor_roll"] = LP("Ролики", "Техника",
    [P("cylinder", (0.18, 1.0, 0.18), (i * 0.25 - 0.5, 0.2, 0), STEEL, "metal", rot=(90, 0, 0), anim="spin", seg=8) for i in range(5)] +
    [P("box", (1.3, 0.12, 0.06), (0, 0.15, 0.53), DARK, "dark"), P("box", (1.3, 0.12, 0.06), (0, 0.15, -0.53), DARK, "dark")])
# строения
models["lp_window"] = LP("Окно", "Строения", [
    P("box", (0.8, 0.8, 0.06), (0, 0.4, 0), GL, "glass"),
    P("box", (0.9, 0.08, 0.1), (0, 0.84, 0), "#e6e6e6", "paint"), P("box", (0.9, 0.08, 0.1), (0, -0.04, 0), "#e6e6e6", "paint"),
    P("box", (0.08, 0.9, 0.1), (0.44, 0.4, 0), "#e6e6e6", "paint"), P("box", (0.08, 0.9, 0.1), (-0.44, 0.4, 0), "#e6e6e6", "paint"),
    P("box", (0.04, 0.8, 0.08), (0, 0.4, 0), "#e6e6e6", "paint")])
models["lp_window_lit"] = LP("Окно светится", "Строения", [
    P("box", (0.8, 0.8, 0.05), (0, 0.4, 0), "#ffd88a", "glow", anim="flicker_soft"),
    P("box", (0.9, 0.08, 0.1), (0, 0.84, 0), DARK, "dark"), P("box", (0.9, 0.08, 0.1), (0, -0.04, 0), DARK, "dark"),
    P("box", (0.08, 0.9, 0.1), (0.44, 0.4, 0), DARK, "dark"), P("box", (0.08, 0.9, 0.1), (-0.44, 0.4, 0), DARK, "dark")])
models["lp_door"] = LP("Дверь", "Строения", [
    P("box", (0.9, 1.8, 0.08), (0, 0.9, 0), "#6b4a2b", "wood"),
    P("box", (1.04, 0.1, 0.14), (0, 1.85, 0), DARK, "dark"),
    P("box", (0.08, 1.9, 0.14), (0.5, 0.95, 0), DARK, "dark"), P("box", (0.08, 1.9, 0.14), (-0.5, 0.95, 0), DARK, "dark"),
    P("sphere", (0.08, 0.08, 0.08), (0.32, 0.9, 0.06), "#ffd36b", "metal")])
models["lp_gate"] = LP("Ворота гаража", "Строения", [
    P("box", (1.8, 1.6, 0.08), (0, 0.8, 0), "#9aa1aa", "metal")] +
    [P("box", (1.8, 0.03, 0.1), (0, 0.2 + i * 0.3, 0), "#6c727b", "metal") for i in range(5)] +
    [P("box", (1.96, 0.1, 0.16), (0, 1.65, 0), YEL, "paint")])
models["lp_roof"] = LP("Крыша двускатная", "Строения", [
    P("prism", (2.0, 0.8, 2.0), (0, 0.4, 0), "#8a3a2e", "paint")])
models["lp_roof_flat"] = LP("Плоская крыша с бортом", "Строения", [
    P("box", (2.0, 0.15, 2.0), (0, 0.075, 0), "#5a5f68", "concrete"),
    P("box", (2.0, 0.2, 0.1), (0, 0.2, 0.95), CONC, "concrete"), P("box", (2.0, 0.2, 0.1), (0, 0.2, -0.95), CONC, "concrete"),
    P("box", (0.1, 0.2, 2.0), (0.95, 0.2, 0), CONC, "concrete"), P("box", (0.1, 0.2, 2.0), (-0.95, 0.2, 0), CONC, "concrete")])
models["lp_truss"] = LP("Ферма (балка)", "Строения", [
    P("box", (2.0, 0.08, 0.08), (0, 0.04, 0.2), YEL, "metal"), P("box", (2.0, 0.08, 0.08), (0, 0.04, -0.2), YEL, "metal"),
    P("box", (2.0, 0.08, 0.08), (0, 0.44, 0.2), YEL, "metal"), P("box", (2.0, 0.08, 0.08), (0, 0.44, -0.2), YEL, "metal")] +
    [P("box", (0.06, 0.56, 0.06), (i * 0.4 - 0.8, 0.24, z), YEL, "metal", rot=(0, 0, 45 if i % 2 else -45)) for i in range(5) for z in (0.2, -0.2)])
models["lp_ladder"] = LP("Лестница", "Строения",
    [P("box", (0.06, 2.0, 0.06), (0.25, 1.0, 0), STEEL, "metal"), P("box", (0.06, 2.0, 0.06), (-0.25, 1.0, 0), STEEL, "metal")] +
    [P("box", (0.5, 0.04, 0.04), (0, 0.2 + i * 0.3, 0), STEEL, "metal") for i in range(6)])
models["lp_railing"] = LP("Перила", "Строения",
    [P("box", (2.0, 0.06, 0.06), (0, 0.9, 0), YEL, "paint"), P("box", (2.0, 0.04, 0.04), (0, 0.5, 0), YEL, "paint")] +
    [P("box", (0.06, 0.9, 0.06), (i * 0.5 - 1.0, 0.45, 0), YEL, "paint") for i in range(5)])
models["lp_crate"] = LP("Ящики штабелем", "Строения", [
    P("box", (0.6, 0.6, 0.6), (-0.3, 0.3, 0), "#a87a4a", "wood"), P("box", (0.6, 0.6, 0.6), (0.35, 0.3, 0.05), "#9a6e40", "wood", rot=(0, 12, 0)),
    P("box", (0.6, 0.6, 0.6), (0, 0.9, 0), "#b8875a", "wood", rot=(0, -8, 0))])
models["lp_barrel"] = LP("Бочка", "Строения", [
    P("cylinder", (0.55, 0.85, 0.55), (0, 0.425, 0), "#c23d2e", "paint", seg=12),
    P("cylinder", (0.58, 0.05, 0.58), (0, 0.25, 0), DARK, "dark", seg=12), P("cylinder", (0.58, 0.05, 0.58), (0, 0.6, 0), DARK, "dark", seg=12)])
models["lp_sign"] = LP("Табличка", "Строения", [
    P("box", (0.08, 1.2, 0.08), (0, 0.6, 0), STEEL, "metal"),
    P("box", (0.8, 0.45, 0.05), (0, 1.25, 0), YEL, "paint"), P("box", (0.6, 0.08, 0.06), (0, 1.25, 0.01), DARK, "dark")])
models["lp_stairs"] = LP("Ступени", "Строения",
    [P("box", (1.0, 0.2 * (i + 1), 0.3), (0, 0.1 * (i + 1), 0.45 - i * 0.3), CONC, "concrete") for i in range(4)])
# природа
models["lp_trunk"] = LP("Ствол", "Природа", [
    P("cylinder", (0.3, 1.8, 0.3), (0, 0.9, 0), "#5a3d26", "wood", top=0.7, seg=8, anim="sway")])
models["lp_branch"] = LP("Ветка", "Природа", [
    P("cylinder", (0.12, 0.9, 0.12), (0.3, 0.35, 0), "#5a3d26", "wood", rot=(0, 0, -50), top=0.6, seg=6, anim="sway"),
    P("sphere", (0.5, 0.4, 0.5), (0.65, 0.65, 0), "#3f7a2f", "leaf", anim="sway")])
models["lp_crown_round"] = LP("Крона круглая", "Природа", [
    P("sphere", (1.4, 1.2, 1.4), (0, 0.6, 0), "#3f7a2f", "leaf", anim="sway"),
    P("sphere", (0.9, 0.8, 0.9), (0.45, 0.85, 0.2), "#4f8a3a", "leaf", anim="sway"),
    P("sphere", (0.8, 0.7, 0.8), (-0.4, 0.8, -0.25), "#36702a", "leaf", anim="sway")])
models["lp_crown_pine"] = LP("Крона ёлки", "Природа", [
    P("cone", (1.5, 1.0, 1.5), (0, 0.5, 0), "#1f4d24", "leaf", seg=7, anim="sway"),
    P("cone", (1.15, 0.9, 1.15), (0, 1.15, 0), "#245a2a", "leaf", seg=7, anim="sway"),
    P("cone", (0.75, 0.8, 0.75), (0, 1.75, 0), "#2b6630", "leaf", seg=7, anim="sway")])
models["lp_leaves"] = LP("Пучок листьев", "Природа",
    [P("prism", (0.25, 0.04, 0.5), (round(math.cos(a) * 0.2, 3), 0.15, round(math.sin(a) * 0.2, 3)), "#5aa83a", "leaf",
       rot=(20, round(-math.degrees(a) + 90, 1), 0), anim="sway") for a in [i * 2 * math.pi / 6 for i in range(6)]])
models["lp_grass"] = LP("Трава", "Природа",
    [P("cone", (0.08, 0.5 + (i % 3) * 0.12, 0.08), (round(math.cos(i * 2.4) * 0.2, 3), 0.25, round(math.sin(i * 2.4) * 0.2, 3)),
       "#6fae3a", "leaf", rot=(round(math.cos(i) * 12, 1), 0, round(math.sin(i) * 12, 1)), seg=4, anim="sway") for i in range(9)])
models["lp_rock"] = LP("Камни", "Природа", [
    P("sphere", (0.9, 0.55, 0.8), (0, 0.22, 0), "#8a8a85", "stone", seg=6),
    P("sphere", (0.5, 0.35, 0.45), (0.5, 0.15, 0.3), "#7a7a76", "stone", seg=6),
    P("sphere", (0.35, 0.25, 0.3), (-0.45, 0.1, -0.3), "#999992", "stone", seg=6)])
models["lp_crystal"] = LP("Кристаллы", "Природа", [
    P("prism", (0.3, 1.0, 0.3), (0, 0.5, 0), "#b06bff", "glow", rot=(0, 0, 0)),
    P("prism", (0.22, 0.7, 0.22), (0.25, 0.3, 0.1), "#c48aff", "glow", rot=(0, 0, -25)),
    P("prism", (0.2, 0.6, 0.2), (-0.22, 0.28, -0.1), "#9a5aff", "glow", rot=(15, 0, 25))])
models["lp_mushroom"] = LP("Гриб", "Природа", [
    P("cylinder", (0.12, 0.35, 0.12), (0, 0.175, 0), "#e8e0cc", "flesh", seg=8),
    P("sphere", (0.4, 0.22, 0.4), (0, 0.38, 0), "#c23d2e", "flesh"),
    P("sphere", (0.06, 0.04, 0.06), (0.08, 0.48, 0.05), "#ffffff", "paint")])
models["lp_flower"] = LP("Цветок", "Природа",
    [P("cylinder", (0.03, 0.4, 0.03), (0, 0.2, 0), "#4f8a3a", "leaf", seg=4, anim="sway"),
     P("sphere", (0.08, 0.08, 0.08), (0, 0.42, 0), "#ffd040", "paint", anim="sway")] +
    [P("sphere", (0.1, 0.03, 0.06), (round(math.cos(a) * 0.08, 3), 0.42, round(math.sin(a) * 0.08, 3)), "#ff7ab0", "paint",
       rot=(0, round(-math.degrees(a), 1), 0), anim="sway") for a in [i * 2 * math.pi / 5 for i in range(5)]])
# существа
models["lp_eye"] = LP("Глаз", "Существа", [
    P("sphere", (0.3, 0.3, 0.3), (0, 0.15, 0), "#f2f2f2", "flesh"),
    P("sphere", (0.14, 0.14, 0.06), (0, 0.15, 0.13), "#ff3b1a", "glow", anim="blink")])
models["lp_eyes_pair"] = LP("Пара глаз", "Существа", [
    P("sphere", (0.18, 0.18, 0.12), (0.15, 0.1, 0), "#ffd040", "glow", anim="blink"),
    P("sphere", (0.18, 0.18, 0.12), (-0.15, 0.1, 0), "#ffd040", "glow", anim="blink")])
models["lp_leg"] = LP("Лапа", "Существа", [
    P("capsule", (0.16, 0.6, 0.16), (0, 0.55, 0), "#4a3a2a", "leg", rot=(0, 0, 25), anim="legs"),
    P("capsule", (0.12, 0.6, 0.12), (0.2, 0.25, 0), "#3a2d20", "leg", rot=(0, 0, -15), anim="legs")])
models["lp_spikes"] = LP("Шипы на спине", "Существа",
    [P("cone", (0.15, 0.35, 0.15), (0, 0.15, i * 0.2 - 0.4), "#e8e0cc", "flesh", rot=(-15, 0, 0), seg=6) for i in range(5)])
models["lp_horn"] = LP("Рога", "Существа", [
    P("cone", (0.12, 0.45, 0.12), (0.15, 0.2, 0), "#e8e0cc", "flesh", rot=(0, 0, -25), seg=6),
    P("cone", (0.12, 0.45, 0.12), (-0.15, 0.2, 0), "#e8e0cc", "flesh", rot=(0, 0, 25), seg=6)])
models["lp_body_bug"] = LP("Тело жука", "Существа", [
    P("sphere", (0.9, 0.55, 1.2), (0, 0.5, 0), "#5a2a6b", "flesh", anim="breathe"),
    P("sphere", (0.5, 0.4, 0.5), (0, 0.55, 0.7), "#4a2259", "flesh"),
    P("sphere", (0.1, 0.1, 0.06), (0.12, 0.62, 0.92), "#ff3b1a", "glow"),
    P("sphere", (0.1, 0.1, 0.06), (-0.12, 0.62, 0.92), "#ff3b1a", "glow")])
models["lp_tail"] = LP("Хвост", "Существа", [
    P("cone", (0.25, 0.9, 0.25), (0, 0.3, -0.4), "#4a3a2a", "flesh", rot=(-70, 0, 0), seg=8, anim="sway")])
models["lp_wings"] = LP("Крылья", "Существа", [
    P("prism", (0.9, 0.04, 0.5), (0.5, 0.3, 0), "#9fd0ff", "glass", rot=(0, 0, 15), anim="wave"),
    P("prism", (0.9, 0.04, 0.5), (-0.5, 0.3, 0), "#9fd0ff", "glass", rot=(0, 0, -15), anim="wave")])
models["lp_tentacle"] = LP("Щупальце", "Существа", [
    P("capsule", (0.18, 0.5, 0.18), (0, 0.25, 0), "#7a9a3a", "flesh", anim="sway"),
    P("capsule", (0.14, 0.45, 0.14), (0.05, 0.6, 0), "#6a8a32", "flesh", rot=(0, 0, -15), anim="sway"),
    P("capsule", (0.1, 0.4, 0.1), (0.13, 0.9, 0), "#5a7a2a", "flesh", rot=(0, 0, -30), anim="sway")])
# свет и эффекты
models["lp_lamp"] = LP("Лампа на стене", "Свет", [
    P("box", (0.15, 0.3, 0.1), (0, 0.15, 0), DARK, "dark"),
    P("sphere", (0.2, 0.2, 0.2), (0, 0.2, 0.12), "#fff2c0", "glow", anim="flicker_soft")])
models["lp_beacon"] = LP("Маячок", "Свет", [
    P("cylinder", (0.25, 0.1, 0.25), (0, 0.05, 0), DARK, "dark", seg=10),
    P("cylinder", (0.2, 0.25, 0.2), (0, 0.22, 0), "#ff7a1a", "glow", anim="blink", seg=10)])
models["lp_torch"] = LP("Факел", "Свет", [
    P("cylinder", (0.08, 0.9, 0.08), (0, 0.45, 0), "#5a3d26", "wood", seg=6),
    P("cone", (0.22, 0.35, 0.22), (0, 1.05, 0), "#ff8c1a", "glow", anim="flicker", seg=6)])
models["lp_neon"] = LP("Неоновая полоса", "Свет", [
    P("box", (1.6, 0.08, 0.06), (0, 0.04, 0), "#40c8ff", "glow", anim="pulse")])
models["lp_campfire"] = LP("Костёр", "Свет",
    [P("cylinder", (0.1, 0.7, 0.1), (round(math.cos(a) * 0.15, 3), 0.08, round(math.sin(a) * 0.15, 3)), "#5a3d26", "wood",
       rot=(0, round(-math.degrees(a), 1), 80), seg=6) for a in [i * 2 * math.pi / 5 for i in range(5)]] +
    [P("cone", (0.35, 0.6, 0.35), (0, 0.35, 0), "#ff8c1a", "glow", anim="flicker", seg=6),
     P("cone", (0.2, 0.4, 0.2), (0.05, 0.4, 0.05), "#ffd040", "glow", anim="flicker", seg=6)])

# заготовки для новой модели
models["tpl_building"] = LT("Каркас здания 2×2", [
    P("box", (1.9, 0.3, 1.9), (0, 0.15, 0), CONC, "concrete"),
    P("box", (1.5, 1.2, 1.5), (0, 0.9, 0), "#5a5f68", "dark"),
    P("box", (1.6, 0.12, 1.6), (0, 1.56, 0), YEL, "paint")])
models["tpl_creature"] = LT("Каркас монстра", [
    P("sphere", (0.9, 0.6, 1.2), (0, 0.7, 0), "#5a2a6b", "flesh", anim="breathe"),
    P("sphere", (0.5, 0.45, 0.5), (0, 0.8, 0.7), "#4a2259", "flesh"),
    P("sphere", (0.1, 0.1, 0.06), (0.12, 0.88, 0.94), "#ff3b1a", "glow"),
    P("sphere", (0.1, 0.1, 0.06), (-0.12, 0.88, 0.94), "#ff3b1a", "glow")] +
    [P("capsule", (0.12, 0.7, 0.12), (x, 0.3, z), "#3a1d45", "leg", rot=(0, 0, 25 if x > 0 else -25), anim="legs")
     for x in (0.45, -0.45) for z in (0.35, -0.1, -0.5)])
models["tpl_tree"] = LT("Каркас дерева", [
    P("cylinder", (0.3, 1.6, 0.3), (0, 0.8, 0), "#5a3d26", "wood", top=0.7, seg=8, anim="sway"),
    P("sphere", (1.4, 1.2, 1.4), (0, 2.0, 0), "#3f7a2f", "leaf", anim="sway")])
models["tpl_item"] = LT("Каркас предмета", [
    P("box", (0.4, 0.4, 0.4), (0, 0.2, 0), "#c0c4cc", "metal")])

# ------------------------------------------------------------------ главное меню и экраны
# Тексты с «@» берутся из texts.json — там переводы на разные языки.
texts = {}
def T(id, ru, en):
    texts[id] = {"ru": ru, "en": en}
    return "@" + id
menu = {
    "title": "", "subtitle": "",
    "logo": "", "bg_image": "res://ui/menu_bg.png", "window_title": "Project Aloverdoz", "splash_on": True, "splash_image": "res://ui/splash.png", "splash_time": 2.5, "bg_color_a": "#080d17", "bg_color_b": "#29170a", "bg_animated": True,
    "buttons": [
        {"id": "continue", "text": T("m_continue", "Продолжить", "Continue"), "show": True},
        {"id": "new", "text": T("m_new", "Новая игра", "New game"), "show": True},
        {"id": "load", "text": T("m_load", "Загрузить", "Load game"), "show": True},
        {"id": "net", "text": T("m_net", "Сетевая игра", "Multiplayer"), "show": True},
        {"id": "editor", "text": T("m_editor", "Редактор", "Editor"), "show": True},
        {"id": "mods", "text": T("m_mods", "Моды и дополнения", "Mods and DLC"), "show": True},
        {"id": "settings", "text": T("m_settings", "Настройки", "Settings"), "show": True},
        {"id": "help", "text": T("m_help", "Как играть", "How to play"), "show": True},
        {"id": "credits", "text": T("m_credits", "Авторы", "Credits"), "show": True},
        {"id": "quit", "text": T("m_quit", "Выход", "Quit"), "show": True},
    ],
    "pause_buttons": [
        {"id": "resume", "text": T("p_resume", "Продолжить", "Resume"), "show": True},
        {"id": "save", "text": T("p_save", "Сохранить", "Save"), "show": True},
        {"id": "load", "text": T("p_load", "Загрузить", "Load"), "show": True},
        {"id": "settings", "text": T("p_settings", "Настройки", "Settings"), "show": True},
        {"id": "help", "text": T("p_help", "Как играть", "How to play"), "show": True},
        {"id": "menu", "text": T("p_menu", "Выйти в главное меню", "Main menu"), "show": True},
        {"id": "quit", "text": T("p_quit", "Выйти из игры", "Quit game"), "show": True},
    ],
    "save_slots": 8,
    "tips": [{"text": t} for t in [
        "Ставьте ленты мышью с зажатой кнопкой — они сами поворачивают.",
        "Ящик в конце ленты собирает всё, что приехало. Из ящика вещи забирает герой или следующая лента.",
        "Буры и плавильни без электричества стоят. Генератору нужно топливо, солнечной панели — день.",
        "Гнёзда монстров рождают волны. Уничтожьте гнёзда — и волны прекратятся.",
        "Панель быстрого доступа: перетащите туда оружие, еду или здание из меню стройки.",
        "Умный разделитель можно настроить: какие предметы куда идут.",
        "Ночью монстры злее. Поставьте фонари и турели заранее.",
        "Если герой погиб, его вещи остаются в сундуке на месте гибели.",
        "Esc — пауза. Игра сохраняется сама, но лучше сохраняться и вручную.",
    ]],
    "loading_text": T("loading", "Загрузка...", "Loading..."),
    "loading_min_time": 0.8,
    "credits": "[b]Project Aloverdoz[/b]\n\n[b]Идея и дизайн[/b] — автор игры\n[b]Движок[/b] — Godot Engine 4 (godotengine.org)\n\nСпасибо, что играете!\n\n[color=#8a93a3]Этот текст меняется в редакторе: Данные → Главное меню и экраны → Авторы.[/color]",
    "help_extra": "",
    "death_title": T("death_title", "ГЕРОЙ ПОГИБ", "YOU DIED"),
    "death_text": T("death_text", "Возрождение у штаба через {t} с", "Respawn at HQ in {t} s"),
    "victory": {"mode": "nests", "value": 0},
    "victory_title": T("victory_title", "ПОБЕДА!", "VICTORY!"),
    "victory_text": T("victory_text", "Вы справились с задачей.", "You have completed the goal."),
    "defeat_title": T("defeat_title", "ПОРАЖЕНИЕ", "DEFEAT"),
    "defeat_text": T("defeat_text", "Штаб уничтожен.", "The HQ was destroyed."),
    "show_stats": True,
}
for id, ru, en in [
    ("new_game", "НОВАЯ ИГРА", "NEW GAME"), ("start", "Начать", "Start"), ("back", "Назад", "Back"),
    ("load_title", "ЗАГРУЗИТЬ ИГРУ", "LOAD GAME"), ("save_title", "СОХРАНИТЬ ИГРУ", "SAVE GAME"),
    ("slot_empty", "Пустая ячейка", "Empty slot"), ("autosave", "Автосохранение", "Autosave"),
    ("btn_load", "Загрузить", "Load"), ("btn_save", "Сохранить сюда", "Save here"), ("btn_delete", "Удалить", "Delete"),
    ("no_saves", "Сохранений пока нет.", "No saved games yet."),
    ("credits_title", "АВТОРЫ", "CREDITS"), ("help_title", "КАК ИГРАТЬ", "HOW TO PLAY"),
    ("settings_title", "НАСТРОЙКИ", "SETTINGS"), ("mods_title", "МОДЫ И ДОПОЛНЕНИЯ", "MODS AND DLC"),
    ("pause_title", "ПАУЗА", "PAUSED"), ("continue_build", "Продолжить строить", "Keep building"),
    ("to_menu", "В главное меню", "Main menu"), ("load_last", "Загрузить последнее сохранение", "Load last save"),
    ("st_time", "Время в игре", "Play time"), ("st_day", "Дней прожито", "Days survived"), ("st_waves", "Волн отбито", "Waves survived"),
    ("st_kills", "Монстров убито", "Monsters killed"), ("st_earned", "Заработано", "Earned"), ("st_buildings", "Построено зданий", "Buildings"),
    ("st_level", "Уровень героя", "Hero level"), ("version", "версия", "version"), ("tip", "Совет", "Tip"),
    ("map_size", "Размер карты", "Map size"), ("modules", "Модули", "Modules"), ("difficulty", "Сложность", "Difficulty"),
    ("profession", "Профессия", "Profession"), ("map", "Карта", "Map"), ("seed", "Зерно", "Seed"),
    ("overwrite_q", "Перезаписать это сохранение?", "Overwrite this save?"), ("delete_q", "Удалить это сохранение?", "Delete this save?"),
    ("yes", "Да", "Yes"), ("slot", "Ячейка", "Slot"), ("map_small", "Маленькая", "Small"), ("map_medium", "Средняя", "Medium"), ("map_large", "Большая", "Large"), ("map_huge", "Огромная", "Huge"), ("random_seed", "случайное", "random"), ("map_random", "Случайная (процедурная)", "Random (procedural)"), ("map_fixed", "Готовая карта игры", "Hand-made map"), ("respawn_now", "Возродиться", "Respawn"), ("no", "Нет", "No"), ("day", "день", "day"),
]:
    T(id, ru, en)

# ================================================================== КРАСИВЫЙ МИР (этап 11)
# Всё ниже — обычные данные: модели, ресурсы, предметы, палитра. Меняется в редакторе.
animations["sway_grass"] = {"name": "Трава на ветру", "type": "sway", "speed": 2.2, "amount": 0.3, "always": True}
animations["sway_bush"] = {"name": "Куст на ветру", "type": "sway", "speed": 1.6, "amount": 0.12, "always": True}

import random as _rnd
_r = _rnd.Random(7)

# ---------- деревья и камни: больше деталей и тёплые цвета
def pine2(name, trunk, greens, h=1.0):
    parts = [P("cylinder", (0.42, 2.0 * h, 0.42), (0, 1.0 * h, 0), trunk, "wood", top=0.5, seg=7)]
    tiers = [(3.0, 1.9, 1.6), (2.5, 1.7, 2.6), (1.95, 1.5, 3.5), (1.35, 1.3, 4.3), (0.7, 1.0, 5.0)]
    for i, (w, hh, y) in enumerate(tiers):
        parts.append(P("cone", (w, hh * h, w), (0, y * h, 0), greens[i % len(greens)], "leaf", anim="sway", seg=8, rot=(0, i * 23, 0)))
    return M(name, parts, "Флора")
models["tree_pine"] = pine2("Ель", "#5a3a22", ["#2d5e2a", "#336b2e", "#2a5627", "#3a7432", "#2f622c"])
models["tree_fir"] = pine2("Пихта", "#4f321d", ["#2f6634", "#3a7a3c", "#2b5e30", "#428640", "#33703a"], 1.2)
models["tree_oak"] = M("Дуб-яблоня", [
    P("cylinder", (0.75, 2.4, 0.75), (0, 1.2, 0), "#5f3f25", "wood", top=0.65, seg=8),
    P("cylinder", (0.25, 1.4, 0.25), (0.45, 2.4, 0.1), "#5f3f25", "wood", rot=(0, 0, -40), top=0.5, seg=6),
    P("cylinder", (0.22, 1.2, 0.22), (-0.4, 2.3, -0.2), "#5f3f25", "wood", rot=(15, 0, 38), top=0.5, seg=6),
    P("sphere", (2.8, 2.2, 2.8), (0, 3.3, 0), "#3f7a2c", "leaf", anim="sway", seg=10),
    P("sphere", (2.0, 1.7, 2.0), (1.1, 3.0, 0.5), "#4c8a33", "leaf", anim="sway", seg=9),
    P("sphere", (1.9, 1.6, 1.9), (-1.0, 3.1, -0.6), "#376e27", "leaf", anim="sway", seg=9),
    P("sphere", (1.7, 1.4, 1.7), (0.2, 4.2, -0.3), "#5a9a3a", "leaf", anim="sway", seg=9),
    P("sphere", (0.2, 0.2, 0.2), (1.4, 2.5, 1.0), "#d9312b", "paint", anim="sway"),
    P("sphere", (0.2, 0.2, 0.2), (-1.3, 2.6, 0.4), "#d9312b", "paint", anim="sway"),
    P("sphere", (0.2, 0.2, 0.2), (0.3, 2.4, -1.3), "#e04a26", "paint", anim="sway"),
], "Флора")
models["tree_birch"] = M("Берёза", [
    P("cylinder", (0.34, 3.4, 0.34), (0, 1.7, 0), "#ece8dc", "wood", top=0.65, seg=7),
    P("box", (0.36, 0.06, 0.2), (0.02, 0.9, 0.06), "#2e2b26", "paint"),
    P("box", (0.3, 0.05, 0.2), (-0.03, 1.7, -0.05), "#2e2b26", "paint"),
    P("box", (0.32, 0.06, 0.18), (0.03, 2.5, 0.04), "#2e2b26", "paint"),
    P("sphere", (2.0, 2.4, 2.0), (0, 3.9, 0), "#8ab83f", "leaf", anim="sway", seg=9),
    P("sphere", (1.4, 1.6, 1.4), (0.6, 3.3, 0.3), "#9cc94a", "leaf", anim="sway", seg=8),
    P("sphere", (1.3, 1.5, 1.3), (-0.5, 4.6, -0.2), "#7aa838", "leaf", anim="sway", seg=8),
], "Флора")
models["tree_dead"]["parts"][0]["color"] = "#5c4c3e"
models["rock_small"] = M("Камень", [
    P("sphere", (0.9, 0.55, 0.8), (0, 0.2, 0), "#8f8b84", "stone", seg=7),
    P("sphere", (0.45, 0.35, 0.45), (0.35, 0.12, 0.25), "#7f7b74", "stone", seg=6),
    P("sphere", (0.5, 0.12, 0.45), (-0.05, 0.42, 0.0), "#5d7d36", "leaf", seg=6),
], "Камни и руда")
models["rock_big"]["parts"] += [P("sphere", (1.1, 0.25, 0.9), (-0.1, 0.78, -0.05), "#5d7d36", "leaf", seg=7),
                                P("sphere", (0.7, 0.55, 0.6), (-0.55, 0.22, -0.4), "#86827a", "stone", seg=6)]

# ---------- украшения земли (не мешают стройке и ходьбе; правятся в «Мир и генератор карты» → «Украшения земли»)
def tuft(name, greens, h=0.6, n=6, seed_col=None):
    parts = []
    for i in range(n):
        a = i * 360 / n + _r.uniform(-15, 15)
        lean = _r.uniform(8, 22)
        hh = h * _r.uniform(0.7, 1.15)
        parts.append(P("cone", (0.09, hh, 0.035), (0, hh * 0.5, 0), greens[i % len(greens)], "leaf", anim="sway_grass",
                       rot=(lean * 0.5, a, lean), seg=3))
    if seed_col:
        for i in range(2):
            a = _r.uniform(0, 6.28)
            parts.append(P("capsule", (0.05, 0.16, 0.05), (math.cos(a) * 0.08, h * 1.05, math.sin(a) * 0.08), seed_col, "leaf", anim="sway_grass"))
    return M(name, parts, "Украшения")
models["deco_grass"] = tuft("Пучок травы", ["#4a7d2c", "#578c31", "#669a38"], 0.75)
models["deco_grass_tall"] = tuft("Высокая трава", ["#557f2c", "#668f33", "#759c3c"], 1.15, 8, "#c9b26a")
models["deco_grass_dry"] = tuft("Сухая трава", ["#b39a55", "#c4ad66", "#a68d4a"], 0.6, 7)
def flower(name, petal, center="#ffd23f", h=0.38):
    h *= 1.6
    parts = [P("cylinder", (0.03, h, 0.03), (0, h * 0.5, 0), "#4a8a2c", "leaf", anim="sway_grass", seg=4),
             P("sphere", (0.16, 0.03, 0.08), (0.06, h * 0.35, 0), "#4f932f", "leaf", anim="sway_grass", rot=(0, 0, 20)),
             P("sphere", (0.14, 0.03, 0.07), (-0.05, h * 0.55, 0.02), "#4f932f", "leaf", anim="sway_grass", rot=(0, 140, 20))]
    for i in range(5):
        a = math.radians(i * 72)
        parts.append(P("sphere", (0.16, 0.045, 0.1), (math.cos(a) * 0.09, h + 0.01, math.sin(a) * 0.09), petal, "paint",
                       anim="sway_grass", rot=(0, -i * 72, 0)))
    parts.append(P("sphere", (0.09, 0.06, 0.09), (0, h + 0.03, 0), center, "paint", anim="sway_grass"))
    return M(name, parts, "Украшения")
models["deco_flower_red"] = flower("Цветок красный", "#e8383d")
models["deco_flower_yellow"] = flower("Цветок жёлтый", "#ffd23f", "#e07b1f", 0.32)
models["deco_flower_blue"] = flower("Цветок синий", "#4f7cff", "#ffe066", 0.42)
models["deco_flower_white"] = flower("Ромашка", "#f7f4ea", "#ffc93c", 0.36)
models["deco_flower_purple"] = flower("Цветок лиловый", "#b05ce0", "#ffe066", 0.4)
models["deco_clover"] = M("Клевер", [
    P("sphere", (0.18, 0.05, 0.18), (math.cos(i * 2.1) * 0.18, 0.05, math.sin(i * 2.1) * 0.18), "#3f8a2e", "leaf", seg=6) for i in range(3)
] + [P("sphere", (0.09, 0.09, 0.09), (0.05, 0.13, 0.02), "#f2d6e6", "paint", anim="sway_grass")], "Украшения")
models["deco_fern"] = M("Папоротник", [
    P("sphere", (0.85, 0.05, 0.22), (math.cos(math.radians(i * 60)) * 0.38, 0.28, math.sin(math.radians(i * 60)) * 0.38),
      ["#3c7a32", "#46883a", "#356d2c"][i % 3], "leaf", anim="sway_bush", rot=(0, -i * 60, 28)) for i in range(6)
], "Украшения")
models["deco_pebbles"] = M("Камешки", [
    P("sphere", (0.22, 0.14, 0.2), (0.0, 0.05, 0.0), "#9a958c", "stone", seg=5),
    P("sphere", (0.16, 0.1, 0.15), (0.2, 0.04, 0.12), "#857f76", "stone", seg=5),
    P("sphere", (0.12, 0.08, 0.12), (-0.15, 0.03, 0.18), "#aba69d", "stone", seg=5),
], "Украшения")
models["deco_reeds"] = M("Камыш", [
    P("cylinder", (0.04, 1.2 * s, 0.04), (x, 0.6 * s, z), "#6b8f3a", "leaf", anim="sway_grass", seg=4)
    for (x, z, s) in [(0, 0, 1.0), (0.12, 0.05, 0.85), (-0.1, 0.08, 1.1), (0.05, -0.12, 0.9), (-0.08, -0.1, 0.75)]
] + [P("capsule", (0.07, 0.22, 0.07), (0, 1.15, 0), "#6b4226", "leaf", anim="sway_grass"),
     P("capsule", (0.07, 0.2, 0.07), (-0.1, 1.2, 0.08), "#6b4226", "leaf", anim="sway_grass")], "Украшения")
models["deco_leaves"] = M("Опавшие листья", [
    P("sphere", (0.2, 0.02, 0.13), (math.cos(i * 1.7) * 0.25, 0.02, math.sin(i * 1.7) * 0.25), c, "leaf", rot=(0, i * 47, 0))
    for i, c in enumerate(["#c46a1f", "#d9952e", "#9c4a1c", "#b8862a", "#8a5a22"])
], "Украшения")
models["deco_shroom"] = M("Грибочки", [
    P("cylinder", (0.05, 0.12, 0.05), (0, 0.06, 0), "#efe6d2", "paint", seg=5),
    P("sphere", (0.14, 0.07, 0.14), (0, 0.13, 0), "#c9772e", "paint", seg=7),
    P("cylinder", (0.04, 0.09, 0.04), (0.1, 0.045, 0.06), "#efe6d2", "paint", seg=5),
    P("sphere", (0.1, 0.05, 0.1), (0.1, 0.1, 0.06), "#b5652a", "paint", seg=7),
], "Украшения")
models["deco_snow_grass"] = tuft("Трава под снегом", ["#8fa48a", "#a3b39d"], 0.4, 5)

# ---------- то, что собирают руками (ветки, хворост, листья, лопухи)
models["fallen_branch"] = M("Упавшая ветка", [
    P("cylinder", (0.13, 1.5, 0.13), (0, 0.07, 0), "#6e4a2c", "wood", rot=(0, 20, 88), top=0.6, seg=6),
    P("cylinder", (0.07, 0.5, 0.07), (0.25, 0.15, 0.15), "#6e4a2c", "wood", rot=(40, 0, 60), top=0.5, seg=5),
    P("cylinder", (0.06, 0.4, 0.06), (-0.35, 0.12, -0.1), "#6e4a2c", "wood", rot=(-30, 0, 70), top=0.5, seg=5),
    P("sphere", (0.3, 0.08, 0.2), (0.45, 0.22, 0.28), "#5c9a3a", "leaf", rot=(0, 30, 10)),
    P("sphere", (0.26, 0.07, 0.18), (-0.5, 0.2, -0.2), "#6aa840", "leaf", rot=(0, -40, -10)),
], "Флора")
models["brushwood"] = M("Хворост", [
    P("cylinder", (0.08, 1.1, 0.08), (0, 0.08 + 0.05 * (i % 3), 0), ["#6e4a2c", "#7d5532", "#5f3f25"][i % 3], "wood",
      rot=(0, i * 31, 84 + (i % 2) * 6), seg=5) for i in range(7)
], "Флора")
models["leaf_bush"] = M("Лиственный куст", [
    P("sphere", (1.3, 0.95, 1.3), (0, 0.45, 0), "#3f7f2c", "leaf", anim="sway_bush", seg=9),
    P("sphere", (0.9, 0.75, 0.9), (0.45, 0.55, 0.3), "#4f9435", "leaf", anim="sway_bush", seg=8),
    P("sphere", (0.85, 0.7, 0.85), (-0.4, 0.5, -0.35), "#37702a", "leaf", anim="sway_bush", seg=8),
    P("sphere", (0.7, 0.6, 0.7), (0.05, 0.9, -0.05), "#5aa23c", "leaf", anim="sway_bush", seg=8),
    P("cylinder", (0.08, 0.4, 0.08), (0, 0.15, 0), "#5c3d24", "wood", seg=5),
], "Флора")
models["burdock"] = M("Лопух", [
    P("sphere", (0.95, 0.06, 0.55), (math.cos(math.radians(a)) * 0.4, 0.22 + 0.04 * (i % 2), math.sin(math.radians(a)) * 0.4),
      ["#3d7d2e", "#478a35", "#356f28"][i % 3], "leaf", anim="sway_bush", rot=(0, -a, 22)) for i, a in enumerate([0, 72, 144, 216, 288])
] + [
    P("cylinder", (0.05, 0.9, 0.05), (0, 0.45, 0), "#5c7a2c", "leaf", anim="sway_bush", seg=4),
    P("sphere", (0.16, 0.16, 0.16), (0.02, 0.92, 0), "#8a3f9c", "paint", anim="sway_bush", seg=7),
    P("sphere", (0.13, 0.13, 0.13), (-0.12, 0.84, 0.08), "#9c4fae", "paint", anim="sway_bush", seg=7),
], "Флора")
models["drop_leaves"] = M("Листья", [
    P("sphere", (0.4, 0.04, 0.25), (0, 0, 0), "#ffffff", "leaf", rot=(0, 20, 0)),
    P("sphere", (0.34, 0.04, 0.22), (0.06, 0.04, 0.05), "#ffffff", "leaf", rot=(0, -40, 8)),
    P("box", (0.36, 0.015, 0.02), (0, 0.025, 0), "#2f5c22", "leaf", rot=(0, 20, 0), tint=False),
], "Предметы")
models["drop_biomass"] = M("Биомасса", [
    P("box", (0.42, 0.3, 0.42), (0, 0, 0), "#ffffff", "leaf"),
    P("box", (0.44, 0.05, 0.44), (0, 0.08, 0), "#c4a23a", "wood", tint=False),
    P("sphere", (0.18, 0.06, 0.12), (0.08, 0.17, 0.05), "#7fbf4a", "leaf", tint=False),
], "Предметы")

def RS(id, name, model, hp, drops, cat, respawn, scale=(0.8, 1.2), blocks=False, tool="", xp=1):
    R(id, name, model, hp, tool, drops, cat, blocks=blocks, respawn=respawn, scale=scale, xp=xp)
RS("fallen_branch", "Упавшая ветка", "fallen_branch", 2, [D("branch", 1, 2), D("leaves", 0, 1)], "Кусты", 240)
RS("brushwood", "Хворост", "brushwood", 4, [D("branch", 3, 5)], "Кусты", 300)
RS("leaf_bush", "Лиственный куст", "leaf_bush", 6, [D("leaves", 2, 4), D("branch", 0, 1)], "Кусты", 200)
RS("burdock", "Лопух", "burdock", 3, [D("leaves", 2, 3), D("fiber", 0, 1)], "Кусты", 180, (0.9, 1.3))
resources["bush_berry"]["drops"].append(D("leaves", 0, 1))
resources["tree_oak"]["drops"].append(D("leaves", 1, 2, "hit", 0.3))
resources["tree_birch"]["drops"].append(D("leaves", 1, 1, "hit", 0.3))

I("leaves", "Листья", "Охапка листьев. Быстро сгорает в сжигателе биомассы; из листьев делают биомассу.", "#5c9a3a", "Сырьё", 100, 1, "drop_leaves", fuel=3)
I("biomass", "Биомасса", "Спрессованные листья, трава и ветки. Горит в сжигателе в несколько раз дольше, чем сырьё.", "#6f8f2f", "Материалы", 100, 3, "drop_biomass", fuel=30)
for _id, _f in [("fiber", 2), ("berry", 1), ("apple", 2), ("mushroom", 2)]:
    if _id in items:
        items[_id]["fuel"] = _f
C("biomass_leaves", "Биомасса из листьев", {"leaves": 4}, {"biomass": 2}, 2.0, ["hand", "workbench"])
C("biomass_fiber", "Биомасса из травы", {"fiber": 4}, {"biomass": 2}, 2.0, ["hand", "workbench"])
C("biomass_wood", "Биомасса из веток", {"branch": 3}, {"biomass": 2}, 2.0, ["hand", "workbench"])

# ---------- сжигатель биомассы
models["biomass_burner"] = M("Сжигатель биомассы", [
    P("box", (1.9, 0.25, 1.9), (0, 0.125, 0), CONC, "concrete"),
    P("box", (1.5, 1.15, 1.4), (-0.05, 0.82, 0), "#8a4f36", "stone"),
    P("box", (1.56, 0.1, 1.46), (-0.05, 1.42, 0), "#5a5f66", "metal"),
    P("box", (0.08, 0.5, 0.8), (0.72, 0.7, 0), "#1c1d20", "dark"),
    P("box", (0.06, 0.38, 0.66), (0.75, 0.7, 0), "#ff7a1a", "glow", anim="flicker"),
    P("box", (0.07, 0.04, 0.8), (0.77, 0.6, 0), "#3a3d42", "metal"),
    P("box", (0.07, 0.04, 0.8), (0.77, 0.8, 0), "#3a3d42", "metal"),
    P("cylinder", (1.0, 0.6, 1.0), (0.15, 1.75, 0.15), "#6e7680", "metal", seg=4, top=1.6),
    P("box", (0.9, 0.06, 0.9), (0.15, 2.06, 0.15), "#5c9a3a", "leaf"),
    P("cylinder", (0.38, 1.6, 0.38), (-0.5, 2.3, -0.45), "#3d3f44", "dark", seg=8),
    P("cylinder", (0.46, 0.12, 0.46), (-0.5, 3.1, -0.45), "#2a2c30", "dark", seg=8),
    P("box", (0.06, 0.25, 0.25), (-0.79, 1.05, 0.35), "#ffd11a", "glow", anim="pulse"),
], "Энергетика")
models["biomass_burner"]["emitters"] = [{"kind": "puff", "pos": [-0.5, 3.25, -0.45], "when": "active", "rate": 0.3, "size": 0.9}]
_bio_fuels = ["leaves", "fiber", "branch", "log", "plank", "biomass", "berry", "apple", "mushroom", "rotten"]
B("biomass_burner", "Сжигатель биомассы", "Простая электростанция начала игры. Жжёт листья, траву, ветки, брёвна и биомассу (с ленты — и ягоды, грибы, гниль); чем лучше топливо, тем дольше горит (время у каждого предмета — поле «Топливо, сек»). Топливо кладут руками (E) или подают лентой.",
  "energy", "generator", {"stone": 12, "log": 6, "branch": 6}, "biomass_burner", 220, power=20, radius=8, fuels=_bio_fuels, burn_mult=2.0)

# ---------- герой: модель из деталей, каждая привязана к «кости» (роль). Белые детали красятся в цвет профессии.
ARM, DK, RB, VIS, CL = "#ffffff", "#2b2f36", "#17181b", "#5ee7ff", "#3a4a5c"
models["hero"] = M("Герой", [
    # пояс
    P("box", (0.38, 0.24, 0.62), (0, 0, 0), DK, "dark"),
    P("box", (0.4, 0.07, 0.66), (0, 0.06, 0), "#5a3d24", "wood", role="hips"),
    P("box", (0.16, 0.16, 0.12), (0.12, -0.02, 0.28), "#4a3a2a", "wood", role="hips"),
    # ноги: бедро, наколенник, голень, ботинок
    P("capsule", (0.24, 0.52, 0.24), (0, -0.24, 0), CL, "paint", role="leg_l"),
    P("capsule", (0.24, 0.52, 0.24), (0, -0.24, 0), CL, "paint", role="leg_r"),
    P("sphere", (0.2, 0.16, 0.18), (0.1, -0.46, 0), ARM, "paint", role="leg_l"),
    P("sphere", (0.2, 0.16, 0.18), (0.1, -0.46, 0), ARM, "paint", role="leg_r"),
    P("box", (0.22, 0.4, 0.22), (0, -0.2, 0), ARM, "paint", role="shin_l"),
    P("box", (0.22, 0.4, 0.22), (0, -0.2, 0), ARM, "paint", role="shin_r"),
    P("box", (0.36, 0.13, 0.25), (0.06, -0.43, 0), RB, "dark", role="shin_l"),
    P("box", (0.36, 0.13, 0.25), (0.06, -0.43, 0), RB, "dark", role="shin_r"),
    # корпус: грудь, живот, рюкзак с батареей
    P("box", (0.5, 0.5, 0.72), (0.02, 0.42, 0), ARM, "paint", role="torso"),
    P("box", (0.42, 0.24, 0.6), (0, 0.1, 0), CL, "paint", role="torso"),
    P("box", (0.36, 0.56, 0.56), (-0.4, 0.4, 0), DK, "dark", role="torso"),
    P("cylinder", (0.12, 0.3, 0.12), (-0.59, 0.45, 0.14), "#ffb21a", "glow", anim="pulse", role="torso", seg=8),
    P("box", (0.1, 0.4, 0.4), (-0.6, 0.38, 0), "#3a4048", "metal", role="torso"),
    P("box", (0.06, 0.6, 0.08), (0.27, 0.42, 0.2), DK, "dark", role="torso"),
    P("box", (0.06, 0.6, 0.08), (0.27, 0.42, -0.2), DK, "dark", role="torso"),
    P("box", (0.05, 0.08, 0.2), (0.28, 0.55, 0), VIS, "glow", role="torso"),
    # голова: шлем, стекло, антенна
    P("sphere", (0.46, 0.46, 0.46), (0, 0.2, 0), ARM, "paint", role="head", seg=14),
    P("sphere", (0.24, 0.24, 0.38), (0.15, 0.2, 0), VIS, "glass", role="head", seg=12),
    P("box", (0.2, 0.1, 0.5), (-0.02, 0.0, 0), DK, "dark", role="head"),
    P("cylinder", (0.03, 0.3, 0.03), (-0.12, 0.48, 0.14), DK, "dark", role="head", seg=4),
    P("sphere", (0.07, 0.07, 0.07), (-0.12, 0.64, 0.14), "#ff4d33", "glow", anim="blink", role="head"),
    # руки: наплечник, плечо, предплечье, перчатка
    P("sphere", (0.3, 0.26, 0.3), (0, 0.02, 0), ARM, "paint", role="arm_l"),
    P("sphere", (0.3, 0.26, 0.3), (0, 0.02, 0), ARM, "paint", role="arm_r"),
    P("capsule", (0.17, 0.42, 0.17), (0, -0.22, 0), CL, "paint", role="arm_l"),
    P("capsule", (0.17, 0.42, 0.17), (0, -0.22, 0), CL, "paint", role="arm_r"),
    P("box", (0.2, 0.32, 0.2), (0, -0.16, 0), ARM, "paint", role="fore_l"),
    P("box", (0.2, 0.32, 0.2), (0, -0.16, 0), ARM, "paint", role="fore_r"),
    P("sphere", (0.18, 0.16, 0.18), (0, -0.37, 0), RB, "dark", role="fore_l"),
    P("sphere", (0.18, 0.16, 0.18), (0, -0.37, 0), RB, "dark", role="fore_r"),
    # бластер в правой руке (виден, когда выбрано огнестрельное оружие)
    P("box", (0.6, 0.14, 0.12), (0.22, 0.02, 0), DK, "dark", role="gun"),
    P("cylinder", (0.08, 0.26, 0.08), (0.58, 0.03, 0), "#55595f", "metal", rot=(0, 0, 90), role="gun", seg=8),
    P("box", (0.12, 0.2, 0.1), (0.0, -0.08, 0), DK, "dark", role="gun"),
    P("box", (0.2, 0.05, 0.13), (0.28, 0.1, 0), VIS, "glow", role="gun"),
], "Герой")
# 12.2 детализация героя: подсумки, наколенники, подошвы, пластины брони, рюкзак с баллонами, шлем с фонарём, перчатки
_hd = models["hero"]["parts"]
_hd += [
    # пояс: подсумки, кобура, пряжка
    P("box", (0.1, 0.1, 0.08), (0.17, -0.02, -0.25), "#4a3a2a", "cloth", role="hips"),
    P("box", (0.1, 0.12, 0.1), (-0.1, -0.03, 0.3), "#4a3a2a", "cloth", role="hips"),
    P("box", (0.12, 0.08, 0.1), (0.2, 0.06, 0), "#c9a227", "metal", role="hips"),
    P("box", (0.08, 0.22, 0.08), (0.02, -0.15, -0.33), RB, "dark", role="hips"),
]
for _s, _z in (("l", 1), ("r", -1)):
    _hd += [
        # бедро: карман, ремешки
        P("box", (0.08, 0.14, 0.12), (0.03, -0.2, _z * 0.11), "#2f3a48", "cloth", role="leg_" + _s),
        P("torus", (0.27, 0.15, 0.27), (0, -0.1, 0), RB, "dark", role="leg_" + _s, seg=10),
        P("torus", (0.27, 0.15, 0.27), (0, -0.34, 0), RB, "dark", role="leg_" + _s, seg=10),
        # голень: щиток, ремни, ботинок с подошвой, носком и шнуровкой
        P("box", (0.06, 0.3, 0.16), (0.12, -0.18, 0), ARM, "paint", role="shin_" + _s),
        P("box", (0.07, 0.04, 0.17), (0.13, -0.06, 0), RB, "dark", role="shin_" + _s),
        P("box", (0.38, 0.05, 0.27), (0.07, -0.5, 0), "#0e0f11", "dark", role="shin_" + _s),
        P("sphere", (0.18, 0.12, 0.24), (0.21, -0.42, 0), RB, "dark", role="shin_" + _s, seg=8),
        P("box", (0.12, 0.02, 0.1), (0.12, -0.36, 0), "#c9a227", "cloth", role="shin_" + _s),
        # плечо: двойной наплечник, нашивка
        P("sphere", (0.34, 0.14, 0.34), (0, 0.11, 0), ARM, "paint", role="arm_" + _s, seg=10),
        P("box", (0.1, 0.08, 0.02), (0.05, -0.08, _z * 0.09), "#d94020", "cloth", role="arm_" + _s),
        # предплечье: щиток, экранчик, пальцы перчатки
        P("box", (0.06, 0.24, 0.16), (0.1, -0.15, 0), DK, "dark", role="fore_" + _s),
        P("box", (0.02, 0.08, 0.1), (0.135, -0.12, 0), VIS, "glow", anim="flicker_soft", role="fore_" + _s),
        P("box", (0.06, 0.1, 0.16), (0.07, -0.45, 0), RB, "dark", role="fore_" + _s),
        P("box", (0.05, 0.08, 0.05), (0.05, -0.42, _z * 0.1), RB, "dark", role="fore_" + _s),
    ]
_hd += [
    # грудь: пластины, воротник, фонарик, полосы
    P("box", (0.06, 0.2, 0.3), (0.28, 0.3, 0), ARM, "paint", role="torso"),
    P("box", (0.07, 0.03, 0.62), (0.27, 0.18, 0), DK, "dark", role="torso"),
    P("torus", (0.44, 0.25, 0.5), (0.02, 0.68, 0), DK, "dark", role="torso", seg=12),
    P("cylinder", (0.08, 0.06, 0.08), (0.29, 0.62, -0.24), "#fff1c4", "glow", rot=(0, 0, 90), role="torso", seg=8),
    P("box", (0.05, 0.14, 0.12), (0.27, 0.62, -0.24), DK, "dark", role="torso"),
    P("box", (0.04, 0.05, 0.05), (0.28, 0.32, 0.22), "#ff3b2f", "glow", anim="blink", role="torso"),
    # рюкзак: два баллона, лямки, антенна, кирка сбоку
    P("cylinder", (0.16, 0.5, 0.16), (-0.6, 0.42, 0.2), "#c0c4cc", "metal", role="torso", seg=10),
    P("cylinder", (0.16, 0.5, 0.16), (-0.6, 0.42, -0.2), "#c0c4cc", "metal", role="torso", seg=10),
    P("sphere", (0.16, 0.1, 0.16), (-0.6, 0.68, 0.2), "#c0c4cc", "metal", role="torso", seg=8),
    P("sphere", (0.16, 0.1, 0.16), (-0.6, 0.68, -0.2), "#c0c4cc", "metal", role="torso", seg=8),
    P("box", (0.5, 0.06, 0.06), (-0.05, 0.62, 0.3), RB, "dark", role="torso", rot=(0, 0, 10)),
    P("box", (0.5, 0.06, 0.06), (-0.05, 0.62, -0.3), RB, "dark", role="torso", rot=(0, 0, 10)),
    P("cylinder", (0.02, 0.5, 0.02), (-0.5, 0.95, -0.2), DK, "dark", role="torso", seg=4),
    P("sphere", (0.05, 0.05, 0.05), (-0.5, 1.2, -0.2), "#40ff6a", "glow", anim="blink", role="torso"),
    P("box", (0.04, 0.5, 0.04), (-0.45, 0.4, 0.33), "#7a5230", "wood", role="torso", rot=(15, 0, 0)),
    P("box", (0.2, 0.06, 0.05), (-0.45, 0.64, 0.36), "#9aa3ad", "metal", role="torso", rot=(15, 0, 0)),
    # шлем: ушные блоки, обод визора, фонарь, гребень
    P("cylinder", (0.16, 0.06, 0.16), (0, 0.2, 0.23), DK, "dark", rot=(90, 0, 0), role="head", seg=10),
    P("cylinder", (0.16, 0.06, 0.16), (0, 0.2, -0.23), DK, "dark", rot=(90, 0, 0), role="head", seg=10),
    P("torus", (0.28, 0.12, 0.4), (0.19, 0.2, 0), DK, "dark", rot=(0, 0, 90), role="head", seg=12),
    P("box", (0.08, 0.06, 0.08), (0.12, 0.42, -0.12), DK, "dark", role="head"),
    P("cylinder", (0.05, 0.04, 0.05), (0.17, 0.42, -0.12), "#fff1c4", "glow", rot=(0, 0, 90), role="head", seg=8),
    P("box", (0.3, 0.05, 0.06), (-0.02, 0.44, 0), ARM, "paint", role="head"),
]
models["hero"]["bones"] = {
    "hips": [0, 0.95, 0], "leg_l": [0, -0.05, 0.17], "leg_r": [0, -0.05, -0.17], "shin_l": [0, -0.47, 0], "shin_r": [0, -0.47, 0],
    "torso": [0, 0.1, 0], "head": [0.02, 0.72, 0], "arm_l": [0, 0.58, 0.45], "arm_r": [0, 0.58, -0.45],
    "fore_l": [0, -0.42, 0], "fore_r": [0, -0.42, 0], "hand_r": [0, -0.38, 0], "gun": [0, 0, 0], "muzzle": [0.7, 0.02, 0],
}
# детали без роли — к поясу
for _p in models["hero"]["parts"]:
    _p.setdefault("role", "hips")
models["hero"]["scale"] = 1.25
settings["hero_model"] = "hero"
settings["surface_detail"] = 1.0

# ---------- иконки профессий (модели; иконка рисуется из модели, можно заменить своей картинкой)
def badge(name, col, parts):
    return M(name, [P("cylinder", (1.2, 0.14, 1.2), (0, 0, 0), col, "paint", rot=(90, 0, 0), seg=20),
                    P("torus", (1.2, 0.1, 1.2), (0, 0, 0.0), "#2a2d33", "dark", rot=(90, 0, 0))] + parts, "Иконки")
models["prof_engineer"] = badge("Значок: инженер", "#ffa040", [
    P("box", (0.16, 0.75, 0.1), (0, -0.05, 0.12), "#d9dde3", "metal", rot=(0, 0, 40)),
    P("torus", (0.38, 0.12, 0.38), (0.22, 0.27, 0.12), "#d9dde3", "metal", rot=(90, 0, 0)),
    P("cylinder", (0.42, 0.12, 0.42), (-0.2, -0.25, 0.14), "#5a5f66", "metal", rot=(90, 0, 0), seg=8)])
models["prof_gatherer"] = badge("Значок: собиратель", "#7dd65a", [
    P("box", (0.08, 0.8, 0.08), (0.08, -0.05, 0.12), "#7a5230", "wood", rot=(0, 0, -25)),
    P("prism", (0.3, 0.26, 0.08), (0.2, 0.3, 0.12), "#d9dde3", "metal", rot=(0, 0, 65)),
    P("sphere", (0.36, 0.06, 0.2), (-0.22, -0.12, 0.16), "#3f8a2e", "leaf", rot=(90, 0, 35))])
models["prof_mechanic"] = badge("Значок: механик", "#4d8cff", [
    P("cylinder", (0.62, 0.12, 0.62), (0, 0, 0.12), "#d9dde3", "metal", rot=(90, 0, 0), seg=8),
    P("cylinder", (0.26, 0.14, 0.26), (0, 0, 0.13), "#2a2d33", "dark", rot=(90, 0, 0), seg=10)] +
    [P("box", (0.12, 0.16, 0.12), (math.cos(math.radians(a)) * 0.35, math.sin(math.radians(a)) * 0.35, 0.12), "#d9dde3", "metal", rot=(0, 0, a)) for a in range(0, 360, 45)])
models["prof_soldier"] = badge("Значок: солдат", "#ff4d33", [
    P("box", (0.5, 0.6, 0.08), (0, 0.02, 0.12), "#d9dde3", "metal"),
    P("prism", (0.5, 0.25, 0.08), (0, -0.4, 0.12), "#d9dde3", "metal", rot=(0, 0, 180)),
    P("box", (0.08, 0.5, 0.09), (0, 0.0, 0.14), "#c9a227", "metal"),
    P("box", (0.36, 0.08, 0.09), (0, 0.1, 0.14), "#c9a227", "metal")])
models["prof_trader"] = badge("Значок: торговец", "#ffd36b", [
    P("cylinder", (0.5, 0.1, 0.5), (0, -0.2 + i * 0.13, 0.12), "#e8b730", "metal", seg=14) for i in range(3)] + [
    P("cylinder", (0.5, 0.1, 0.5), (0.05, 0.22, 0.14), "#f5cf4a", "metal", rot=(70, 0, 0), seg=14)])
models["prof_survivor"] = badge("Значок: выживальщик", "#c49a6c", [
    P("cylinder", (0.1, 0.6, 0.1), (0, -0.25, 0.12), "#6e4a2c", "wood", rot=(0, 0, 70), seg=5),
    P("cylinder", (0.1, 0.6, 0.1), (0, -0.25, 0.12), "#7d5532", "wood", rot=(0, 0, -70), seg=5),
    P("cone", (0.36, 0.5, 0.2), (0, 0.05, 0.14), "#ff8a1a", "glow", anim="flicker"),
    P("cone", (0.2, 0.32, 0.12), (0, 0.02, 0.18), "#ffe066", "glow", anim="flicker")])
for _pid in professions:
    professions[_pid]["icon_model"] = "prof_" + _pid
    professions[_pid]["icon"] = ""

# ---------- внешний вид мира: палитра земли, воды, травы и свет (Данные → Мир и генератор карты → Внешний вид)
world["look"] = {
    "grass_a": "#3a6b26", "grass_b": "#5f8a31", "grass_dry": "#9a944a", "clover": "#2f5f28",
    "dirt": "#7a5434", "mud": "#4a3524", "sand": "#d9c48a", "rock": "#8a857c", "snow": "#eef3f8",
    "blade_base": "#2c5220", "blade_tip": "#86ad45",
    "water_deep": "#0f4a6e", "water_shallow": "#2f9cb0", "foam": "#e8f6ff",
    "mountain": "#857a6c", "mountain_grass": "#55762f",
    "sun_color": "#fff1d6", "sky_top": "#3f7fd9", "sky_horizon": "#b8d8f0",
    "exposure": 0.95, "saturation": 1.1, "contrast": 1.06, "fog": 0.0007, "ambient": 0.7,
    "detail": 1.0, "grass_density": 1.0,
}
world["decor"] = [
    {"model": "deco_flower_red", "zone": "meadow", "density": 0.05, "scale": [1.2, 1.8]},
    {"model": "deco_flower_yellow", "zone": "meadow", "density": 0.07, "scale": [1.2, 1.8]},
    {"model": "deco_flower_white", "zone": "meadow", "density": 0.07, "scale": [1.2, 1.8]},
    {"model": "deco_flower_blue", "zone": "forest_edge", "density": 0.07, "scale": [1.2, 1.8]},
    {"model": "deco_flower_purple", "zone": "forest_edge", "density": 0.05, "scale": [1.2, 1.8]},
    {"model": "deco_grass", "zone": "meadow", "density": 0.22, "scale": [0.8, 1.3]},
    {"model": "deco_grass_tall", "zone": "meadow", "density": 0.05, "scale": [0.8, 1.2]},
    {"model": "deco_clover", "zone": "meadow", "density": 0.05, "scale": [0.8, 1.4]},
    {"model": "deco_grass", "zone": "forest_edge", "density": 0.18, "scale": [0.8, 1.2]},
    {"model": "deco_fern", "zone": "forest", "density": 0.12, "scale": [0.7, 1.3]},
    {"model": "deco_leaves", "zone": "forest", "density": 0.1, "scale": [0.8, 1.4]},
    {"model": "deco_shroom", "zone": "forest", "density": 0.03, "scale": [0.8, 1.3]},
    {"model": "deco_grass_dry", "zone": "dry", "density": 0.2, "scale": [0.8, 1.3]},
    {"model": "deco_pebbles", "zone": "dry", "density": 0.05, "scale": [0.8, 1.5]},
    {"model": "deco_pebbles", "zone": "sand", "density": 0.03, "scale": [0.8, 1.5]},
    {"model": "deco_grass_dry", "zone": "sand", "density": 0.04, "scale": [0.6, 1.0]},
    {"model": "deco_reeds", "zone": "shore", "density": 0.3, "scale": [0.8, 1.3]},
    {"model": "deco_snow_grass", "zone": "snow", "density": 0.05, "scale": [0.8, 1.2]},
]
world["flora"] += [
    {"resource": "fallen_branch", "zone": "forest", "density": 0.025},
    {"resource": "fallen_branch", "zone": "forest_edge", "density": 0.02},
    {"resource": "fallen_branch", "zone": "meadow", "density": 0.004},
    {"resource": "brushwood", "zone": "forest", "density": 0.012},
    {"resource": "brushwood", "zone": "dry", "density": 0.008},
    {"resource": "leaf_bush", "zone": "forest_edge", "density": 0.03},
    {"resource": "leaf_bush", "zone": "meadow", "density": 0.008},
    {"resource": "burdock", "zone": "forest_edge", "density": 0.02},
    {"resource": "burdock", "zone": "meadow", "density": 0.008},
]
# вокруг штаба — немного веток и кустов, чтобы было что собрать в первую минуту
world["start_gatherables"] = {"fallen_branch": 6, "leaf_bush": 4, "burdock": 3, "brushwood": 2}

# ------------------------------------------------------------------ 8.4 нефть и жидкости
# Жидкость — обычный предмет с галочкой «Жидкость» (fluid): её качают насосы, она течёт по трубам,
# копится в баках и машинах. На ленты и в рюкзак жидкость не попадает — для этого её наливают в канистры.
PIPE_Y = 0.45
OIL, FUELC, WATERC = "#1a1418", "#e0a020", "#3a8fe0"
animations["pump_nod"] = {"name": "Балансир качалки", "type": "swing", "speed": 2.2, "amount": 0.28, "always": False}
animations["pump_rod"] = {"name": "Шток качалки", "type": "bob", "speed": 2.2, "amount": 0.32, "always": False}
animations["crank"] = {"name": "Кривошип", "type": "spin", "speed": 2.2, "amount": 1.0, "always": False}

I("water", "Вода", "Чистая вода. Насос качает её из озера или реки, дальше она течёт по трубам.", WATERC, "Жидкости", 100, 1, "drop_fluid", fluid=True)
I("oil", "Нефть", "Сырая нефть из нефтяного пятна. Нефтяной насос качает её в трубы, нефтезавод перерабатывает.", OIL, "Жидкости", 100, 3, "drop_fluid", fluid=True)
I("fuel", "Топливо", "Жидкое топливо из нефти. Его жжёт топливный генератор.", FUELC, "Жидкости", 100, 6, "drop_fluid", fluid=True, fuel=20)
I("plastic", "Пластик", "Лёгкий прочный материал из нефти.", "#e8e4dc", "Материалы", 50, 12, "drop_ingot")
I("rubber", "Резина", "Упругая резина из нефти и воды.", "#2c2c30", "Материалы", 50, 10, "drop_ingot")
I("canister", "Пустая канистра", "Тара для жидкостей. В упаковщике её наполняют нефтью, топливом или водой — тогда жидкость можно возить лентами и носить с собой.", "#c43a2a", "Жидкости в таре", 50, 4, "drop_canister")
I("canister_oil", "Канистра нефти", "Нефть в канистре: едет по лентам. В упаковщике её можно вылить обратно в трубы.", "#3a2f33", "Жидкости в таре", 20, 10, "drop_canister")
I("canister_fuel", "Канистра топлива", "Топливо в канистре: жгут в генераторах и топливном генераторе, можно везти лентой.", FUELC, "Жидкости в таре", 20, 18, "drop_canister", fuel=60)
I("canister_water", "Канистра воды", "Можно выпить (ПКМ в инвентаре): утоляет жажду.", WATERC, "Жидкости в таре", 20, 4, "drop_canister", water=60)

world["deposits"].append({"resource": "", "item": "oil", "color": "#141018", "patches": 10, "size_min": 1.8, "size_max": 3.2, "near_start": 0, "drops": []})

C("canister", "Пустая канистра", {"iron_plate": 2}, {"canister": 2}, 2.0, ["workshop", "assembler"])
C("refine_fuel", "Топливо", {"oil": 3}, {"fuel": 2}, 3.0, ["refinery"])
C("refine_plastic", "Пластик", {"oil": 3}, {"plastic": 2}, 4.0, ["refinery"])
C("refine_rubber", "Резина", {"oil": 2, "water": 2}, {"rubber": 2}, 4.0, ["refinery"])
C("circuit_plastic", "Микросхема из пластика", {"wire": 2, "plastic": 1}, {"circuit": 1}, 3.0, ["workshop", "assembler"])
for fl, nm in [("oil", "нефти"), ("fuel", "топлива"), ("water", "воды")]:
    C("pack_" + fl, "Налить канистру " + nm, {fl: 4, "canister": 1}, {"canister_" + fl: 1}, 1.5, ["packager"])
    C("unpack_" + fl, "Вылить канистру " + nm, {"canister_" + fl: 1}, {fl: 4, "canister": 1}, 1.5, ["packager"])

categories["fluids"] = {"name": "Жидкости", "order": 10, "color": "#3a8fe0"}

B("water_pump", "Водяной насос", "Ставится на воду (озеро или реку) и качает 60 единиц воды в минуту в трубы рядом.", "fluids", "miner",
  {"iron_plate": 6, "gear": 4, "wire": 2}, "water_pump", 300, period=1.0, power=4, any_ground=True, on_water=True,
  water_item="water", extracts="fluid", pipes=True)
B("oil_pump", "Нефтяной насос", "Качалка: ставится на нефтяное пятно (чёрное на земле и на карте) и качает 60 единиц нефти в минуту в трубы рядом.", "fluids", "miner",
  {"steel": 6, "motor": 2, "iron_plate": 6}, "oil_pump", 450, size=2, period=1.0, power=15, any_ground=True, extracts="fluid", pipes=True)
B("pipe", "Труба", "Ведёт жидкость: до 300 единиц в минуту. Тяни мышью, чтобы проложить линию. Трубы сами соединяются друг с другом, с насосами, баками и машинами рядом. В одной сети труб — только одна жидкость.", "fluids", "pipe",
  {"iron_plate": 1}, "pipe", 80, pipe_per_min=300, pipe_capacity=5, tier=1, any_ground=True, arm_model="pipe_arm")
B("pipe_mk2", "Труба Mk2", "Толстая труба: до 600 единиц в минуту. Ставится прямо поверх старой.", "fluids", "pipe",
  {"steel": 1, "rubber": 1}, "pipe_mk2", 100, pipe_per_min=600, pipe_capacity=10, tier=2, any_ground=True, arm_model="pipe_arm_mk2")
B("tank", "Бак", "Запасает до 400 единиц жидкости. Подключите его трубой: он сам наполняется и отдаёт жидкость в сеть.", "fluids", "tank",
  {"iron_plate": 10, "steel": 4}, "tank", 500, size=2, pipe_capacity=400)
B("refinery", "Нефтезавод", "Перерабатывает нефть в топливо, пластик и резину. Жидкости подаются и забираются трубами, пластик и резина выходят на ленту.", "fluids", "crafter",
  {"steel": 10, "motor": 2, "circuit": 4}, "refinery", 500, size=2, station="refinery", speed=1.0, power=20, pipes=True, in_slots=3, out_slots=2)
B("packager", "Упаковщик", "Наливает жидкость из труб в канистры и выливает канистры обратно в трубы. Канистры едут по лентам как обычные предметы.", "fluids", "crafter",
  {"iron_plate": 8, "gear": 4, "circuit": 2}, "packager", 350, station="packager", speed=1.0, power=6, pipes=True)
B("fuel_generator", "Топливный генератор", "Жжёт топливо из труб (или канистры топлива с ленты) и даёт 150 энергии.", "energy", "generator",
  {"steel": 10, "motor": 2, "rubber": 4}, "fuel_generator", 500, size=2, power=150, fuels=["fuel", "canister_fuel"], burn_mult=1.0,
  radius=10, fuel_slots=2, pipes=True)

PIPE_C, PIPE2_C, FLANGE = "#7d8a99", "#d9822b", "#4a525c"
def pipe_hub(name, col, r):
    return M(name, [
        P("box", (0.5, 0.05, 0.5), (0, 0.025, 0), DARK, "dark"),
        P("cylinder", (0.12, PIPE_Y, 0.12), (0, PIPE_Y * 0.5, 0), FLANGE, "metal", seg=6),
        P("sphere", (r * 1.35, r * 1.35, r * 1.35), (0, PIPE_Y, 0), col, "metal", seg=12),
        P("cylinder", (r * 1.5, 0.07, r * 1.5), (0, PIPE_Y + r * 0.62, 0), FLANGE, "metal", seg=10),
        P("cylinder", (r * 0.8, 0.06, r * 0.8), (0, PIPE_Y + r * 0.7, 0), "#ffffff", "glow", role="fluid_color", tint=False, seg=10),
    ], "Жидкости")
def pipe_arm(name, col, r):
    # отрезок от центра клетки до соседа: длина 1 вдоль X, растягивается (роль «stretch»)
    return M(name, [
        P("cylinder", (r, 1.0, r), (0.5, PIPE_Y, 0), col, "metal", rot=(0, 0, 90), role="stretch", seg=10),
        P("cylinder", (r * 1.25, 0.06, r * 1.25), (0.5, PIPE_Y, 0), FLANGE, "metal", rot=(0, 0, 90), role="stretch", seg=10),
    ], "Жидкости")
models["pipe"] = pipe_hub("Труба (узел)", PIPE_C, 0.32)
models["pipe_mk2"] = pipe_hub("Труба Mk2 (узел)", PIPE2_C, 0.42)
models["pipe_arm"] = pipe_arm("Труба (отрезок)", PIPE_C, 0.32)
models["pipe_arm_mk2"] = pipe_arm("Труба Mk2 (отрезок)", PIPE2_C, 0.42)

models["drop_fluid"] = M("Капля", [
    P("sphere", (0.36, 0.36, 0.36), (0, -0.05, 0), W_, "glass", seg=10),
    P("cone", (0.25, 0.28, 0.25), (0, 0.2, 0), W_, "glass", seg=10),
], "Предметы")
models["drop_canister"] = M("Канистра", [
    P("box", (0.36, 0.5, 0.18), (0, 0, 0), W_, "paint"),
    P("box", (0.26, 0.06, 0.2), (0, 0.12, 0), "#222428", "dark", tint=False),
    P("cylinder", (0.08, 0.1, 0.08), (0.1, 0.3, 0), "#e8e8e8", "metal", tint=False, seg=6),
    P("box", (0.16, 0.05, 0.05), (-0.06, 0.29, 0), "#222428", "dark", tint=False),
], "Предметы")

# водяной насос — плавучая станция на поплавках
models["water_pump"] = M("Водяной насос", [
    P("cylinder", (0.45, 1.7, 0.45), (0, 0.05, 0.6), "#e8e2d0", "paint", rot=(0, 0, 90), seg=10),
    P("cylinder", (0.45, 1.7, 0.45), (0, 0.05, -0.6), "#e8e2d0", "paint", rot=(0, 0, 90), seg=10),
    P("box", (1.7, 0.12, 1.6), (0, 0.33, 0), "#5d636c", "metal"),
    P("box", (1.7, 0.04, 0.08), (0, 0.41, 0.78), YEL, "paint"),
    P("box", (1.7, 0.04, 0.08), (0, 0.41, -0.78), YEL, "paint"),
    P("cylinder", (0.3, 1.2, 0.3), (-0.45, -0.2, 0), STEEL, "metal", seg=10),
    P("cylinder", (0.42, 0.25, 0.42), (-0.45, -0.75, 0), DARK, "dark", seg=12),
    P("gear", (0.36, 0.05, 0.36), (-0.45, -0.88, 0), STEEL, "metal", anim="spin_fast", seg=6, top=0.6),
    P("box", (0.75, 0.55, 0.6), (-0.3, 0.68, 0), "#2f6fb0", "paint"),
    P("cylinder", (0.5, 0.75, 0.5), (0.3, 0.68, 0), "#3b3f46", "metal", rot=(0, 0, 90), seg=12),
    P("cylinder", (0.4, 0.06, 0.4), (0.68, 0.68, 0), STEEL, "metal", rot=(0, 0, 90), anim="spin_fan", seg=8),
] + [P("box", (0.6, 0.03, 0.04), (0.3, 0.68 + dy, 0.26), "#2a2c30", "dark") for dy in (-0.12, 0, 0.12)] + [
    P("cylinder", (0.26, 0.6, 0.26), (-0.3, 1.2, 0), PIPE_C, "metal", seg=10),
    P("cylinder", (0.32, 0.06, 0.32), (-0.3, 1.0, 0), FLANGE, "metal", seg=10),
    P("torus", (0.3, 0.06, 0.3), (-0.3, 1.45, 0.2), "#d93a2a", "metal", rot=(90, 0, 0), anim="gear_slow"),
    P("cylinder", (0.26, 1.0, 0.26), (-0.3, PIPE_Y + 0.05, 0.0), PIPE_C, "metal", rot=(90, 0, 0), seg=10),
    P("box", (0.05, 0.6, 0.05), (0.8, 0.7, 0.75), STEEL, "metal"),
    P("box", (0.05, 0.6, 0.05), (0.8, 0.7, -0.75), STEEL, "metal"),
    P("box", (0.05, 0.05, 1.5), (0.8, 1.0, 0), YEL, "paint"),
    P("sphere", (0.14, 0.14, 0.14), (-0.3, 1.58, 0), "#40c8ff", "glow", anim="blink"),
], "Жидкости")
models["water_pump"]["emitters"] = [{"kind": "steam", "pos": [-0.45, -0.2, 0.45], "when": "active", "rate": 0.5, "size": 0.6}]

# нефтяная качалка 2×2: балансир качается, шток ходит, кривошипы крутятся
def _oil_pump():
    p = []
    a = p.append
    a(P("box", (3.6, 0.25, 2.6), (0, 0.125, 0), CONC, "concrete"))
    a(P("box", (3.62, 0.06, 0.12), (0, 0.27, 1.25), YEL, "paint"))
    a(P("box", (3.62, 0.06, 0.12), (0, 0.27, -1.25), YEL, "paint"))
    a(P("box", (2.8, 0.18, 0.5), (-0.2, 0.34, 0), "#3b3f46", "metal"))
    # стойка (A-рама)
    for z in (0.42, -0.42):
        a(P("box", (0.16, 2.3, 0.16), (0.1, 1.35, z * 0.62), "#d9822b", "paint", rot=(-12 if z > 0 else 12, 0, 0)))
        a(P("box", (0.12, 2.0, 0.12), (-0.35, 1.2, z * 0.7), "#d9822b", "paint", rot=(-10 if z > 0 else 10, 0, -14)))
    a(P("box", (0.5, 0.08, 0.5), (0.05, 0.42, 0), "#2a2c30", "dark"))
    a(P("cylinder", (0.26, 0.5, 0.26), (0.1, 2.45, 0), STEEL, "metal", rot=(90, 0, 0), seg=10))
    # балансир с «головой»
    a(P("box", (3.3, 0.32, 0.26), (0.25, 2.62, 0), "#2f6fb0", "paint", anim="pump_nod"))
    a(P("box", (3.3, 0.06, 0.3), (0.25, 2.8, 0), "#d9822b", "paint", anim="pump_nod"))
    a(P("box", (0.6, 0.9, 0.3), (1.72, 2.42, 0), "#2f6fb0", "paint", anim="pump_nod"))
    # шток и устье скважины
    a(P("cylinder", (0.05, 1.6, 0.05), (1.95, 1.55, 0), "#e8e8e8", "metal", anim="pump_rod", seg=6))
    a(P("cylinder", (0.12, 0.08, 0.12), (1.95, 2.0, 0), DARK, "dark", anim="pump_rod", seg=8))
    a(P("cylinder", (0.42, 0.5, 0.42), (1.95, 0.5, 0), "#3b3f46", "metal", seg=12))
    a(P("cylinder", (0.3, 0.3, 0.3), (1.95, 0.9, 0), STEEL, "metal", seg=10))
    a(P("cylinder", (0.18, 0.2, 0.18), (1.95, 1.1, 0), "#d93a2a", "paint", seg=8))
    a(P("cylinder", (0.18, 0.8, 0.18), (1.95, PIPE_Y + 0.05, 0.4), PIPE_C, "metal", rot=(90, 0, 0), seg=8))
    a(P("torus", (0.28, 0.05, 0.28), (1.95, 0.75, 0.24), "#d93a2a", "metal", rot=(90, 0, 0)))
    a(P("cylinder", (0.12, 0.35, 0.12), (1.95, 0.75, 0.15), STEEL, "metal", rot=(90, 0, 0), seg=6))
    # редуктор, кривошипы с противовесами, шатуны
    a(P("box", (0.7, 0.7, 0.6), (-1.15, 0.78, 0), "#3b3f46", "metal"))
    a(P("box", (0.72, 0.06, 0.62), (-1.15, 1.12, 0), YEL, "paint"))
    for z in (0.42, -0.42):
        a(P("gear", (1.1, 0.12, 1.1), (-1.15, 0.95, z), "#2a2c30", "dark", rot=(90, 0, 0), anim="crank", seg=3, top=0.45))
        a(P("box", (0.1, 1.55, 0.1), (-1.15, 1.85, z * 1.15), STEEL, "metal"))
        a(P("cylinder", (0.16, 0.12, 0.16), (-1.15, 0.95, z * 1.28), DARK, "dark", rot=(90, 0, 0), seg=8))
    a(P("cylinder", (0.12, 1.2, 0.12), (-1.15, 0.95, 0), STEEL, "metal", rot=(90, 0, 0), anim="crank", seg=8))
    # мотор с ремнём
    a(P("cylinder", (0.5, 0.7, 0.5), (-1.55, 0.62, 0.9), "#2f6fb0", "paint", rot=(0, 0, 90), seg=12))
    for k in range(5):
        a(P("box", (0.6, 0.02, 0.04), (-1.55, 0.42 + k * 0.1, 1.16), "#1f2226", "dark"))
    a(P("cylinder", (0.36, 0.08, 0.36), (-1.15, 0.62, 0.9), STEEL, "metal", rot=(0, 0, 90), anim="spin_fan", seg=10))
    a(P("box", (0.06, 0.06, 0.9), (-1.35, 0.78, 0.6), "#1f2226", "dark"))
    # пульт, ограждение, лестница, маячок
    a(P("box", (0.4, 0.7, 0.25), (-1.55, 0.6, -0.95), "#5d636c", "metal"))
    a(P("box", (0.28, 0.2, 0.03), (-1.55, 0.78, -0.82), "#4dff73", "glow", anim="flicker_soft"))
    for x in (-1.7, -0.6, 0.5, 1.6):
        a(P("box", (0.05, 0.8, 0.05), (x, 0.65, 1.2), YEL, "paint"))
        a(P("box", (0.05, 0.8, 0.05), (x, 0.65, -1.2), YEL, "paint"))
    a(P("box", (3.3, 0.05, 0.05), (-0.05, 1.05, 1.2), YEL, "paint"))
    a(P("box", (3.3, 0.05, 0.05), (-0.05, 1.05, -1.2), YEL, "paint"))
    for k in range(6):
        a(P("box", (0.32, 0.03, 0.05), (0.42, 0.55 + k * 0.33, -0.3), STEEL, "metal"))
    a(P("sphere", (0.16, 0.16, 0.16), (0.1, 2.98, 0), "#ff8c1a", "glow", anim="blink"))
    a(P("box", (0.5, 0.25, 0.03), (-1.15, 0.85, 0.31), "#e8eaec", "paint"))
    return p
models["oil_pump"] = M("Нефтяная качалка", _oil_pump(), "Жидкости")
models["oil_pump"]["emitters"] = [{"kind": "smoke", "pos": [-1.55, 1.1, 0.9], "when": "active", "rate": 0.15, "size": 0.4}]

# бак 2×2
def _tank():
    p = []
    a = p.append
    a(P("cylinder", (3.5, 0.2, 3.5), (0, 0.1, 0), CONC, "concrete", seg=20))
    a(P("cylinder", (3.1, 2.6, 3.1), (0, 1.5, 0), "#c9ccd1", "metal", seg=24))
    for y in (0.5, 1.3, 2.1, 2.75):
        a(P("torus", (3.18, 0.06, 3.18), (0, y, 0), "#8c949e", "metal"))
    a(P("cone", (3.15, 0.5, 3.15), (0, 3.05, 0), "#a9b0b8", "metal", seg=24))
    a(P("cylinder", (0.3, 0.3, 0.3), (0, 3.4, 0), "#5d636c", "metal", seg=8))
    a(P("box", (0.1, 2.4, 0.3), (1.58, 1.5, 0), "#ffffff", "glow", role="fluid_color", tint=False))
    a(P("box", (0.14, 2.5, 0.36), (1.56, 1.5, 0), "#2a2c30", "dark"))
    for k in range(9):
        a(P("box", (0.05, 0.03, 0.4), (-1.6, 0.4 + k * 0.3, 0.6), STEEL, "metal"))
    a(P("box", (0.05, 2.9, 0.05), (-1.6, 1.6, 0.4), STEEL, "metal"))
    a(P("box", (0.05, 2.9, 0.05), (-1.6, 1.6, 0.8), STEEL, "metal"))
    for ang in range(0, 360, 45):
        import math
        x, z = math.cos(math.radians(ang)) * 1.3, math.sin(math.radians(ang)) * 1.3
        a(P("box", (0.05, 0.5, 0.05), (x, 3.1, z), YEL, "paint"))
    a(P("torus", (2.65, 0.05, 2.65), (0, 3.35, 0), YEL, "paint"))
    for side in (0, 1, 2, 3):
        dx, dz = [(1, 0), (0, 1), (-1, 0), (0, -1)][side]
        a(P("cylinder", (0.32, 0.5, 0.32), (dx * 1.7, PIPE_Y, dz * 1.7), PIPE_C, "metal", rot=(90, 0, 0) if dz else (0, 0, 90), seg=10))
    a(P("box", (0.6, 0.3, 0.03), (0, 1.6, 1.56), "#2f6fb0", "paint"))
    return p
models["tank"] = M("Бак", _tank(), "Жидкости")

# нефтезавод 2×2: две ректификационные колонны, печь, факел
def _refinery():
    p = []
    a = p.append
    a(P("box", (3.8, 0.25, 3.8), (0, 0.125, 0), CONC, "concrete"))
    a(P("box", (3.82, 0.06, 0.12), (0, 0.27, 1.85), YEL, "paint"))
    a(P("box", (3.82, 0.06, 0.12), (0, 0.27, -1.85), YEL, "paint"))
    for x, h, r in ((-0.9, 4.2, 0.8), (0.1, 3.4, 0.62)):
        a(P("cylinder", (r, h, r), (x, 0.25 + h / 2, -0.9), "#d6d9de", "metal", seg=16))
        for k in range(int(h / 0.7)):
            a(P("torus", (r + 0.12, 0.05, r + 0.12), (x, 0.6 + k * 0.7, -0.9), "#8c949e", "metal"))
        a(P("sphere", (r, r * 0.6, r), (x, 0.25 + h, -0.9), "#c0c4ca", "metal", seg=14))
        a(P("box", (r + 0.5, 0.05, r + 0.5), (x, 0.25 + h * 0.6, -0.9), "#5d636c", "metal"))
    # печь подогрева
    a(P("box", (1.3, 1.4, 1.1), (0.9, 0.95, 0.85), "#8a4a3a", "paint"))
    a(P("box", (0.8, 0.4, 0.05), (0.9, 0.7, 1.41), "#ff6a1a", "glow", anim="flicker"))
    a(P("cylinder", (0.35, 1.6, 0.35), (1.3, 2.4, 0.6), "#2a2c30", "dark", seg=8))
    # трубная эстакада
    for z in (0.1, 0.35):
        a(P("cylinder", (0.18, 3.0, 0.18), (0, 1.9, z), PIPE_C, "metal", rot=(0, 0, 90), seg=8))
    a(P("cylinder", (0.18, 1.6, 0.18), (-0.9, 1.1, -0.1), PIPE2_C, "metal", rot=(90, 0, 0), seg=8))
    for x in (-1.4, 0, 1.4):
        a(P("box", (0.1, 1.9, 0.1), (x, 1.0, 0.22), "#3b3f46", "metal"))
    a(P("box", (3.0, 0.08, 0.5), (0, 1.75, 0.22), "#3b3f46", "metal"))
    # сферические ёмкости
    a(P("sphere", (0.9, 0.9, 0.9), (-1.2, 0.8, 1.0), "#e8e2d0", "paint", seg=14))
    a(P("sphere", (0.7, 0.7, 0.7), (-0.35, 0.7, 1.2), "#e8e2d0", "paint", seg=14))
    for x in (-1.5, -0.9, -0.5, -0.2):
        a(P("box", (0.06, 0.4, 0.06), (x, 0.4, 1.1), STEEL, "metal"))
    # факел
    a(P("cylinder", (0.12, 3.6, 0.12), (1.6, 2.05, -1.5), "#3b3f46", "metal", seg=6))
    a(P("cone", (0.25, 0.4, 0.25), (1.6, 4.0, -1.5), "#2a2c30", "dark", seg=8))
    a(P("cone", (0.25, 0.5, 0.25), (1.6, 4.4, -1.5), "#ff8c1a", "glow", anim="flicker", seg=8))
    # лестница, вентиль, пульт, насосы
    for k in range(10):
        a(P("box", (0.05, 0.03, 0.4), (-1.75, 0.5 + k * 0.35, -0.9), STEEL, "metal"))
    a(P("box", (0.05, 3.6, 0.05), (-1.75, 2.0, -1.1), STEEL, "metal"))
    a(P("box", (0.05, 3.6, 0.05), (-1.75, 2.0, -0.7), STEEL, "metal"))
    a(P("torus", (0.35, 0.06, 0.35), (0.1, 1.3, -0.25), "#d93a2a", "metal", rot=(90, 0, 0), anim="gear_slow"))
    a(P("box", (0.5, 0.8, 0.3), (1.5, 0.65, -0.3), "#5d636c", "metal"))
    a(P("box", (0.36, 0.25, 0.03), (1.5, 0.85, -0.14), "#4dff73", "glow", anim="flicker_soft"))
    a(P("cylinder", (0.35, 0.6, 0.35), (0.6, 0.55, -0.1), "#2f6fb0", "paint", rot=(0, 0, 90), seg=10))
    a(P("cylinder", (0.3, 0.06, 0.3), (0.95, 0.55, -0.1), STEEL, "metal", rot=(0, 0, 90), anim="spin_fan", seg=8))
    a(P("sphere", (0.16, 0.16, 0.16), (-0.9, 4.75, -0.9), "#ff3b2a", "glow", anim="blink"))
    return p
models["refinery"] = M("Нефтезавод", _refinery(), "Жидкости")
models["refinery"]["emitters"] = [{"kind": "smoke", "pos": [1.6, 4.7, -1.5], "when": "active", "rate": 0.5, "size": 0.8},
                                  {"kind": "steam", "pos": [1.3, 3.3, 0.6], "when": "active", "rate": 0.4, "size": 0.9}]

models["packager"] = M("Упаковщик", [
    P("box", (1.9, 0.25, 1.9), (0, 0.125, 0), CONC, "concrete"),
    P("box", (1.5, 1.2, 1.3), (0, 0.85, -0.1), "#2f6fb0", "paint"),
    P("box", (1.52, 0.08, 1.32), (0, 1.48, -0.1), YEL, "paint"),
    P("box", (0.9, 0.5, 0.04), (0, 0.95, 0.56), "#9fd8ff", "glass"),
    P("box", (1.6, 0.12, 0.5), (0, 0.4, 0.7), "#3b3f46", "belt"),
] + [P("box", (0.22, 0.3, 0.12), (x, 0.62, 0.7), "#c43a2a", "paint") for x in (-0.5, 0, 0.5)] + [
    P("cylinder", (0.08, 0.4, 0.08), (0, 1.3, 0.62), STEEL, "metal", anim="piston_small", seg=6),
    P("cylinder", (0.5, 0.9, 0.5), (-0.5, 2.0, -0.4), "#c9ccd1", "metal", seg=12),
    P("cylinder", (0.5, 0.9, 0.5), (0.25, 2.0, -0.4), "#c9ccd1", "metal", seg=12),
    P("box", (0.08, 0.7, 0.2), (-0.26, 2.0, -0.15), "#ffffff", "glow", role="fluid_color", tint=False),
    P("sphere", (0.12, 0.12, 0.12), (0.6, 1.62, 0.3), "#4dff73", "glow", anim="blink"),
], "Жидкости")

# топливный генератор 2×2: двигатель, маховик, баки, выхлоп
def _fuel_gen():
    p = []
    a = p.append
    a(P("box", (3.8, 0.25, 3.8), (0, 0.125, 0), CONC, "concrete"))
    a(P("box", (2.6, 1.3, 1.6), (-0.2, 0.9, 0.2), "#3b3f46", "metal"))
    a(P("box", (2.62, 0.1, 1.62), (-0.2, 1.5, 0.2), "#d93a2a", "paint"))
    for x in (-1.1, -0.6, -0.1, 0.4):
        a(P("box", (0.35, 0.5, 0.6), (x, 1.8, 0.2), "#5d636c", "metal"))
        a(P("cylinder", (0.12, 0.4, 0.12), (x, 2.2, 0.2), DARK, "dark", anim="piston_small", seg=6))
    a(P("cylinder", (1.3, 0.25, 1.3), (1.35, 1.0, 0.2), STEEL, "metal", rot=(0, 0, 90), anim="spin", seg=16))
    a(P("box", (0.5, 0.1, 0.1), (1.35, 1.0, 0.2), "#d93a2a", "paint", rot=(0, 0, 0), anim="spin"))
    a(P("cylinder", (0.9, 2.4, 0.9), (0, 0.85, -1.3), "#e0a020", "paint", rot=(0, 0, 90), seg=14))
    a(P("box", (0.3, 0.6, 0.3), (-0.9, 0.6, -1.3), "#2a2c30", "dark"))
    a(P("box", (0.3, 0.6, 0.3), (0.9, 0.6, -1.3), "#2a2c30", "dark"))
    a(P("box", (0.08, 0.5, 1.6), (-1.55, 1.0, 0.2), "#1f2226", "dark"))
    for k in range(6):
        a(P("box", (0.04, 0.5, 0.05), (-1.6, 1.0, -0.4 + k * 0.24), STEEL, "metal"))
    for x, h in ((-0.9, 1.9), (-0.4, 1.7)):
        a(P("cylinder", (0.26, h, 0.26), (x, 1.5 + h / 2, 1.2), "#2a2c30", "dark", seg=8))
        a(P("cylinder", (0.32, 0.08, 0.32), (x, 1.5 + h, 1.2), "#5d636c", "metal", seg=8))
    a(P("box", (0.6, 0.35, 0.03), (0.5, 1.0, 1.01), "#ffd040", "glow", anim="flicker_soft"))
    a(P("box", (0.5, 0.8, 0.3), (1.5, 0.65, -0.5), "#5d636c", "metal"))
    a(P("box", (0.36, 0.25, 0.03), (1.5, 0.85, -0.34), "#4dff73", "glow", anim="flicker_soft"))
    a(P("cylinder", (0.2, 1.4, 0.2), (0, PIPE_Y + 0.1, -0.3), PIPE_C, "metal", rot=(0, 0, 90), seg=8))
    a(P("sphere", (0.16, 0.16, 0.16), (-0.9, 3.5, 1.2), "#ff3b2a", "glow", anim="blink"))
    return p
models["fuel_generator"] = M("Топливный генератор", _fuel_gen(), "Энергетика")
models["fuel_generator"]["emitters"] = [{"kind": "smoke", "pos": [-0.9, 3.5, 1.2], "when": "active", "rate": 0.5, "size": 0.8},
                                        {"kind": "smoke", "pos": [-0.4, 3.3, 1.2], "when": "active", "rate": 0.4, "size": 0.7}]

settings["fluid_tick"] = 0.2
settings["pipe_fill_buffer"] = 2.0

# ------------------------------------------------------------------ 8.5 дерево открытий и задания станции
# Узел дерева: ступень (tier), порядок, значок, условия (requires — другие узлы, contract — задание станции, day — день),
# цена (cost — предметы, сдаются частями; credits; research — очки исследований) и что открывает (unlocks).
# Всё, что упомянуто в «Открывает», закрыто до открытия узла; остальное открыто сразу.
tech = {}
def TN(id, name, tier, order, icon, desc, cost, unlocks, requires=(), credits=0, research=0, contract="", day=0, start=False):
    d = {"name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost,
         "unlocks": {k: list(v) for k, v in unlocks.items()}, "requires": list(requires)}
    if credits: d["credits"] = credits
    if research: d["research"] = research
    if contract: d["contract"] = contract
    if day: d["day"] = day
    if start: d["start"] = True
    tech[id] = d
TN("t_start", "Высадка", 0, 0, "workbench", "То, что есть с самого начала: верстак, печь, ленты, ящики, деревянные стены и терминал открытий.",
   {}, {"buildings": ["workbench", "furnace", "belt", "chest", "wall_wood", "campfire", "tech_terminal", "floor", "fence", "crates", "sign", "flag"]}, start=True)
TN("t_mining", "Добыча", 1, 0, "miner", "Бур на месторождении, генератор и опоры ЛЭП — первый автоматический завод.",
   {"iron_ingot": 10, "plank": 10}, {"buildings": ["miner", "generator", "pole"]})
TN("t_workshop", "Мастерская", 1, 1, "workshop", "Ручной крафт деталей: шестерни, провода, пластины, патроны.",
   {"plank": 15, "stone": 15, "iron_ingot": 5}, {"buildings": ["workshop"], "recipes": ["blaster", "recall"]})
TN("t_logistics", "Логистика", 1, 2, "splitter", "Разделители, соединители и большой контейнер.",
   {"iron_ingot": 15, "gear": 4}, {"buildings": ["splitter", "merger", "container"]}, requires=["t_workshop"])
TN("t_defense", "Оборона", 1, 3, "turret", "Турели, бетонные стены и ворота.",
   {"iron_ingot": 20, "stone": 30}, {"buildings": ["turret", "wall", "gate", "lamp"]})
TN("t_found", "Фундаменты", 1, 4, "found_2", "Площадки, ярусы и рампы для стройки на холмах и на воде.",
   {"stone": 40}, {"buildings": ["found_1", "found_2", "found_tall", "found_ramp", "found_ramp2", "found_wall"]})
TN("t_power", "Электричество", 2, 0, "smelter", "Плавильня, сборщик, солнечные панели и аккумуляторы.",
   {"iron_ingot": 40, "wire": 20, "gear": 10}, {"buildings": ["smelter", "assembler", "solar", "battery_block"]}, requires=["t_mining", "t_workshop"])
TN("t_coal", "Уголь и сталь", 2, 1, "coal_generator", "Угольный генератор и выплавка стали.",
   {"coal": 30, "iron_ingot": 40}, {"buildings": ["coal_generator"], "recipes": ["steel"]}, requires=["t_power"])
TN("t_wind", "Энергия ветра", 2, 2, "wind_turbine", "Ветряк: энергия без топлива, но ветер то стихает, то крепчает.",
   {"iron_plate": 20, "gear": 15, "wire": 15}, {"buildings": ["wind_turbine"]}, requires=["t_power"])
TN("t_chem", "Химия", 2, 3, "sulfur", "На карте появляются залежи серы. Батареи и гранаты.",
   {"quartz": 15, "coal": 20}, {"deposits": ["sulfur"], "recipes": ["battery", "grenade"]}, requires=["t_power"], credits=200)
TN("t_mk2", "Улучшенные машины", 3, 0, "miner_mk2", "Бур, плавильня и сборщик Mk2, лента Mk2. Ставятся прямо поверх старых.",
   {"steel": 30, "circuit": 10, "motor": 4}, {"buildings": ["miner_mk2", "smelter_mk2", "assembler_mk2", "belt_mk2"]},
   requires=["t_coal"], research=10)
TN("t_smart", "Умная логистика", 3, 1, "smart_splitter", "Разделители с фильтрами и соединители с главным входом.",
   {"circuit": 10, "iron_plate": 20}, {"buildings": ["smart_splitter", "smart_merger"]}, requires=["t_logistics", "t_power"])
TN("t_oil", "Нефть", 3, 2, "oil_pump", "На карте появляются нефтяные пятна. Качалки, трубы, баки, нефтезавод, упаковщик и топливный генератор.",
   {"steel": 40, "motor": 8, "circuit": 10}, {"deposits": ["oil"], "buildings": ["oil_pump", "water_pump", "pipe", "tank", "refinery", "packager", "fuel_generator"]},
   requires=["t_mk2"], contract="c_steel", research=20)
TN("t_laser", "Лазеры", 3, 3, "laser_turret", "Лазерная турель: бьёт сильнее и не тратит патроны.",
   {"crystal": 3, "circuit": 15, "glass": 10}, {"buildings": ["laser_turret"]}, requires=["t_defense", "t_power"], day=3, research=10)
TN("t_mk3", "Скоростные ленты и трубы", 4, 0, "belt_mk3", "Лента Mk3 (270 в минуту) и труба Mk2 (600 в минуту).",
   {"steel": 40, "motor": 10, "plastic": 20}, {"buildings": ["belt_mk3", "pipe_mk2"]}, requires=["t_oil"], research=30)
TN("t_special", "Особые здания", 4, 1, "medbay", "Медпункт, маяк ускорения, торговый терминал и другие здания из блоков поведения.",
   {"circuit": 10, "steel": 10, "glass": 10}, {"buildings": [b for b in buildings if buildings[b]["category"] == "special"]}, requires=["t_power"], credits=500)

contracts = {}
def CT(id, order, name, text, goal, n, reward, research=0, item="", blds=(), requires=(), day=0):
    d = {"order": order, "name": name, "text": text, "goal": goal, "n": n, "reward": reward, "requires": list(requires)}
    if research: d["research"] = research
    if item: d["item"] = item
    if blds: d["buildings"] = list(blds)
    if day: d["day"] = day
    contracts[id] = d
CT("c_planks", 0, "Доски для жилого модуля", "Станции нужны доски для ремонта жилого модуля. Сдайте 30 досок.", "deliver", 30, 120, 5, item="plank")
CT("c_iron", 1, "Железо на обшивку", "Сдайте 50 железных слитков: станция латает обшивку после метеоритов.", "deliver", 50, 300, 10, item="iron_ingot", requires=["t_mining"])
CT("c_miners", 2, "Покажите завод", "Постройте 4 бура — станции нужна уверенность, что база будет добывать руду.", "build", 4, 200, 5, blds=["miner", "miner_mk2", "miner_mk3", "miner_mk4", "miner_mk5"], requires=["t_mining"])
CT("c_hold", 3, "Продержитесь", "Отбейте 3 волны монстров после получения задания.", "survive", 3, 400, 10, requires=["t_defense"])
CT("c_steel", 4, "Сталь для орбиты", "Сдайте 40 стали — после этого станция разрешит бурить нефть.", "deliver", 40, 600, 20, item="steel", requires=["t_coal"])
CT("c_circuits", 5, "Электроника", "Сдайте 30 микросхем для навигации челноков.", "deliver", 30, 800, 20, item="circuit", requires=["t_power"])
CT("c_plastic", 7, "Пластик для модулей", "Сдайте 100 пластика: станция строит новый жилой модуль.", "deliver", 100, 1500, 40, item="plastic", requires=["t_oil"])
CT("c_hold2", 8, "Оборона рубежа", "Отбейте 5 волн монстров после получения задания.", "survive", 5, 1500, 40, requires=["t_mk3"])
CT("c_heavy", 9, "Тяжёлая добыча", "Постройте 6 буров Mk3 или лучше.", "build", 6, 2000, 50, blds=["miner_mk3", "miner_mk4", "miner_mk5"], requires=["t_mk3"])
CT("c_cores", 10, "Ядра монстров", "Сдайте 10 ядер монстров — учёные станции изучают их энергию.", "deliver", 10, 3000, 80, item="monster_core", requires=["t_mk4"])
CT("c_fuel", 6, "Топливо для челноков", "Сдайте 20 канистр топлива.", "deliver", 20, 1200, 30, item="canister_fuel", requires=["t_oil"])

B("tech_terminal", "Терминал открытий", "Сюда сдают ресурсы на новые здания и рецепты (E — дерево открытий, J — откуда угодно). Принимает ресурсы и с ленты — для узла со звёздочкой ★.",
  "stations", "terminal", {"plank": 6, "stone": 6}, "tech_terminal", 300)
models["tech_terminal"] = M("Терминал открытий", [
    P("box", (1.9, 0.25, 1.9), (0, 0.125, 0), CONC, "concrete"),
    P("box", (1.2, 1.3, 0.9), (0, 0.9, -0.3), "#3b3f46", "metal"),
    P("box", (1.0, 0.7, 0.05), (0, 1.15, 0.16), "#40c8ff", "glow", anim="flicker_soft"),
    P("box", (1.22, 0.1, 0.92), (0, 1.6, -0.3), YEL, "paint"),
    P("box", (1.4, 0.35, 0.5), (0, 0.45, 0.55), "#5d636c", "metal"),
    P("box", (0.9, 0.05, 0.4), (0, 0.65, 0.55), "#121417", "dark"),
    P("cylinder", (0.08, 1.2, 0.08), (0.45, 2.2, -0.5), STEEL, "metal", seg=6),
    P("cone", (0.5, 0.3, 0.5), (0.45, 2.85, -0.5), "#c9ccd1", "metal", rot=(180, 0, 0), seg=12),
    P("sphere", (0.12, 0.12, 0.12), (0.45, 2.75, -0.5), "#ff8c1a", "glow", anim="blink"),
    P("torus", (0.6, 0.05, 0.6), (-0.35, 1.85, -0.3), "#40c8ff", "glow", anim="spin_slow"),
], "Станции")

quests["q_tech"] = Q(6, "Откройте «Добычу» в дереве открытий (J): сдайте слитки и доски", 80, "tech", 1,
                     hint="J — дерево открытий. Кнопка «Сдать» берёт ресурсы со склада штаба и из рюкзака")
for _qid, _q in quests.items():
    if _qid != "q_tech" and int(_q.get("order", 0)) >= 6:
        _q["order"] = int(_q["order"]) + 1
settings["tech_tree"] = True
options["sections"][0]["items"].append(O("key_tech", "Дерево открытий", "key", "J"))
options["sections"][0]["items"].append(O("key_records", "Рекорды и мастерство", "key", "F"))

# тексты окон игры (торговля, задачи, панель) — можно переименовать и перевести в «Тексты и языки»
for _id, _ru, _en in [
    ("trade_title", "ТОРГОВАЯ СТАНЦИЯ «ОРБИТА-7»", "TRADE STATION «ORBIT-7»"),
    ("trade_head", "Кредиты: [color=#ffd36b]{credits}[/color]. Станция забирает товар сначала со склада штаба, потом из рюкзака, и присылает челнок.",
     "Credits: [color=#ffd36b]{credits}[/color]. The station takes goods from HQ storage first, then from your backpack, and sends a shuttle."),
    ("tr_item", "Товар", "Item"), ("tr_have", "Есть", "Have"), ("tr_price", "Цена за шт.", "Price each"),
    ("tr_sell", "Продать", "Sell"), ("tr_buy", "Купить", "Buy"), ("tr_all", "всё", "all"),
    ("tr_sell1_tip", "Продать 1 шт. за {p} кр", "Sell 1 for {p} cr"), ("tr_sell_all_tip", "Продать все {n} шт. за {p} кр", "Sell all {n} for {p} cr"),
    ("tr_buy10", "10 за {p}", "10 for {p}"), ("tr_buy_tip", "Купить 10 шт. Челнок привезёт их в штаб.", "Buy 10. The shuttle delivers them to HQ."),
    ("tr_no_money", "Не хватает {n} кр", "Need {n} more cr"),
    ("in_hq", "В штабе", "In HQ"), ("in_bag", "В рюкзаке", "In backpack"),
    ("quest_done", "Задача выполнена!", "Task complete!"), ("quests_all_done", "Все задачи выполнены!", "All tasks complete!"),
    ("need", "Нужно", "Need"), ("load_build", "Строим мир...", "Building the world..."),
    ("load_shaders", "Готовим материалы...", "Preparing materials..."), ("load_world", "Почти готово...", "Almost ready..."), ("hot_build", "здание", "building"), ("durability", "прочность", "durability"),
]:
    T(_id, _ru, _en)


# ---------------------------------------------------------------- 12.1 пять уровней буров, лент и труб (подробные модели — tools/art_tiers.py)
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_tiers
models.update(art_tiers.all_models())
# 12.2 монстры с настоящим шагом (tools/art_creatures.py)
import art_creatures
animations.update(art_creatures.ANIMS)
models.update(art_creatures.all_models())
# монстры со скелетом: игра сама двигает кости (tools/art_rigged.py)
import art_rigged
models.update(art_rigged.all_models())
# 12.2 подробные здания (tools/art_buildings.py)
import art_buildings
models.update(art_buildings.all_models(models))
# 12.2 подробная природа (tools/art_world.py)
import art_world
models.update(art_world.all_models())
# 12.2 подробные предметы и оружие (tools/art_items.py)
import art_items
models.update(art_items.all_models())
B("miner_mk3", "Бур Mk3", "Тяжёлая установка с коронкой и турбиной охлаждения: втрое быстрее обычного бура. Ставится прямо поверх старого.", "extraction", "miner",
  {"steel": 12, "motor": 4, "circuit": 4, "concrete": 6}, "miner_mk3", 600, period=0.6, power=20, tier=3, any_ground=True)
B("miner_mk4", "Бур Mk4", "Плазменный бур: кольца-излучатели плавят породу. Впятеро быстрее обычного.", "extraction", "miner",
  {"steel": 20, "motor": 6, "circuit": 8, "battery": 4, "plastic": 10}, "miner_mk4", 750, period=0.4, power=32, tier=4, any_ground=True)
B("miner_mk5", "Бур Mk5", "Квантовый экстрактор: кристаллическое ядро вытягивает руду прямо из недр. В восемь раз быстрее обычного.", "extraction", "miner",
  {"steel": 30, "circuit": 12, "battery": 8, "crystal": 10, "monster_core": 2}, "miner_mk5", 900, period=0.25, power=50, tier=5, any_ground=True)
B("belt_mk4", "Конвейер Mk4", "Тяжёлая лента: 480 предметов в минуту. Ставится прямо поверх старой.", "logistics", "belt",
  {"steel": 1, "plastic": 1}, "belt_mk4", 140, per_min=480, tier=4, any_ground=True)
B("belt_mk5", "Конвейер Mk5", "Самая быстрая лента: 780 предметов в минуту.", "logistics", "belt",
  {"steel": 1, "plastic": 1, "circuit": 1}, "belt_mk5", 160, per_min=780, tier=5, any_ground=True)
B("pipe_mk3", "Труба Mk3", "Усиленная труба: до 900 единиц в минуту. Ставится прямо поверх старой.", "fluids", "pipe",
  {"steel": 2, "rubber": 1}, "pipe_mk3", 120, pipe_per_min=900, pipe_capacity=15, tier=3, any_ground=True, arm_model="pipe_arm_mk3")
B("pipe_mk4", "Труба Mk4", "Магистральная труба: до 1200 единиц в минуту.", "fluids", "pipe",
  {"steel": 2, "plastic": 1, "rubber": 1}, "pipe_mk4", 140, pipe_per_min=1200, pipe_capacity=20, tier=4, any_ground=True, arm_model="pipe_arm_mk4")
B("pipe_mk5", "Труба Mk5", "Труба с силовым полем: до 1800 единиц в минуту.", "fluids", "pipe",
  {"steel": 3, "plastic": 2, "crystal": 1}, "pipe_mk5", 160, pipe_per_min=1800, pipe_capacity=30, tier=5, any_ground=True, arm_model="pipe_arm_mk5")
tech["t_mk3"]["unlocks"]["buildings"] = ["belt_mk3", "pipe_mk2", "miner_mk3", "pipe_mk3"]
tech["t_mk3"]["desc"] = "Бур Mk3, лента Mk3 (270 в минуту), трубы Mk2 и Mk3 (600 и 900 в минуту)."
TN("t_mk4", "Тяжёлая техника", 5, 0, "miner_mk4", "Плазменный бур Mk4, лента Mk4 (480 в минуту) и труба Mk4 (1200 в минуту).",
   {"steel": 80, "circuit": 30, "battery": 10, "plastic": 40}, {"buildings": ["miner_mk4", "belt_mk4", "pipe_mk4"]}, requires=["t_mk3"], credits=1500, research=60)
TN("t_mk5", "Квантовые технологии", 6, 0, "miner_mk5", "Квантовый бур Mk5, лента Mk5 (780 в минуту) и труба Mk5 (1800 в минуту).",
   {"steel": 150, "circuit": 60, "crystal": 40, "monster_core": 10}, {"buildings": ["miner_mk5", "belt_mk5", "pipe_mk5"]}, requires=["t_mk4"], credits=4000, research=150)

# ---------------------------------------------------------------- 8.6: события мира, загрязнение, лаборатория
settings["modules"]["events"] = True
settings["modules"]["pollution"] = True
settings.update({"pollution_k": 0.004, "pollution_cap": 300})
models["meteorite"] = M("Метеорит", [
    P("sphere", (1.9, 1.2, 1.7), (0, 0.45, 0), "#3a3330", "stone", seg=9),
    P("sphere", (1.0, 0.8, 1.1), (0.7, 0.35, 0.4), "#2c2624", "stone", rot=(0, 30, 10), seg=8),
    P("sphere", (0.8, 0.6, 0.7), (-0.75, 0.3, -0.5), "#4a403a", "stone", rot=(10, 60, 0), seg=8),
    P("box", (0.9, 0.08, 0.12), (0.1, 1.0, 0.1), "#ff6a1a", "glow", rot=(0, 25, 8), anim="pulse"),
    P("box", (0.12, 0.08, 0.8), (-0.3, 0.92, -0.1), "#ff8c2a", "glow", rot=(0, 10, 0), anim="pulse"),
    P("box", (0.5, 0.08, 0.1), (0.6, 0.7, 0.55), "#ff6a1a", "glow", rot=(0, -40, 20), anim="pulse"),
    P("prism", (0.3, 0.5, 0.3), (0.2, 1.05, -0.35), "#b34dff", "glow", rot=(10, 0, 20), anim="pulse"),
], "Камни и руда")
R("meteorite", "Метеорит", "meteorite", 160, "pickaxe",
  [D("iron_ore", 3, 6), D("stone", 2, 4), D("crystal", 1, 1, "break", 0.35), D("iron_ore_hq", 1, 1, "break", 0.25)],
  "Руда", scale=(0.9, 1.3), xp=8)
models["research_lab"] = M("Лаборатория", [
    P("box", (1.8, 0.2, 1.8), (0, 0.1, 0), DARK, "dark"),
    P("box", (1.6, 1.1, 1.4), (0, 0.75, -0.1), "#d8dde4", "paint"),
    P("box", (1.62, 0.12, 1.42), (0, 1.36, -0.1), "#3d7bd9", "paint"),
    P("box", (0.9, 0.5, 0.05), (0, 0.85, 0.62), "#1a2a3a", "glass"),
    P("box", (0.8, 0.4, 0.04), (0, 0.85, 0.645), "#4de1ff", "glow", anim="pulse"),
    P("cylinder", (0.35, 0.7, 0.35), (-0.5, 1.75, 0.2), "#bfe9ff", "glass"),
    P("cylinder", (0.25, 0.4, 0.25), (-0.5, 1.65, 0.2), "#7dff5a", "glow", anim="pulse"),
    P("cylinder", (0.35, 0.7, 0.35), (0.5, 1.75, 0.2), "#bfe9ff", "glass"),
    P("cylinder", (0.25, 0.5, 0.25), (0.5, 1.68, 0.2), "#c070ff", "glow", anim="pulse"),
    P("cylinder", (0.08, 0.6, 0.08), (0, 1.7, -0.5), STEEL, "metal"),
    P("cylinder", (0.6, 0.06, 0.6), (0, 2.0, -0.5), STEEL, "metal", anim="spin"),
    P("box", (0.5, 0.06, 0.08), (0.22, 2.05, -0.5), "#4de1ff", "glow", anim="spin"),
], "Особые")
BB("research_lab", "Лаборатория", "Изучает образцы с монстров и даёт очки исследований для дерева открытий. Слизь и хитин — понемногу, ядро монстра — много. Нужна энергия.", "decor",
   {"iron_plate": 8, "glass": 6, "circuit": 4}, "research_lab", 300,
   [{"type": "research", "in": {"goo": 2, "chitin": 1}, "points": 4, "time": 20.0, "needs_power": True},
    {"type": "research", "in": {"monster_core": 1}, "points": 25, "time": 40.0, "needs_power": True}], power=8, pollution=0)
tech["t_special"]["unlocks"]["buildings"].append("research_lab")
# редкие здания: пока подземелья выключены — обычные исследования (с подземельями — только по чертежу из сундука)
TN("t_plasma", "Плазма", 4, 3, "plasma_turret", "Плазменная турель: очень сильная, на энергии, молния бьёт ещё двоих.",
   {"steel": 60, "circuit": 30, "crystal": 15}, {"buildings": ["plasma_turret"]}, requires=["t_laser", "t_mk2"], research=40)
TN("t_teleport", "Телепортация", 5, 1, "teleporter", "Телепорт: поставьте два и больше — в окне «Перенестись».",
   {"steel": 50, "circuit": 30, "crystal": 15}, {"buildings": ["teleporter"]}, requires=["t_transport"], research=60)
TN("t_antimatter", "Антиматерия", 6, 1, "antimatter_gen", "Генератор антиматерии: 400 энергии без топлива.",
   {"steel": 120, "circuit": 50, "crystal": 40, "battery": 20}, {"buildings": ["antimatter_gen"]}, requires=["t_mk4"], research=120)
commands["event"] = CMD("Начать событие мира", "event <id>", [{"do": "event", "key": "$1"}], True)
commands["npc"] = CMD("Привести НПС к базе", "npc <вид> [сколько]", [{"do": "npc", "enemy": "$1|trader", "n": "$2|1"}], True)
commands["order"] = CMD("Выставить заказ", "order <sell|buy> <предмет> <кол-во> <цена>", [{"do": "order", "key": "$1|sell", "item": "$2", "n": "$3|10", "v": "$4|100"}], True)
commands["season"] = CMD("Перейти к сезону", "season <Зима|4>", [{"do": "season", "key": "$1|1"}], True)
commands["scout"] = CMD("Запустить дрона-разведчика туда, куда смотрит камера", "scout [метров]", [{"do": "scout", "dist": "$1|0"}], True)
commands["reveal"] = CMD("Открыть карту (туман войны)", "reveal [радиус, пусто — вся карта]", [{"do": "reveal", "dist": "$1|"}], True)
commands["unlock_rare"] = CMD("Изучить редкий чертёж", "unlock_rare <здание>", [{"do": "unlock_rare", "key": "$1"}], True)
commands["research"] = CMD("Добавить очки исследований", "research <кол-во>", [{"do": "research", "n": "$1|50"}], True)

# ---------------------------------------------------------------- 8.6: машина, дроны, грузовики, клавиши
def wheels(xs, zs, r=0.42, w=0.3, y=None):
    out = []
    for x in xs:
        for z in zs:
            yy = r if y is None else y
            out.append(P("cylinder", (r * 2, w, r * 2), (x, yy, z), "#1c1d20", "rough", rot=(90, 0, 0), seg=16))
            out.append(P("cylinder", (r * 1.1, w + 0.02, r * 1.1), (x, yy, z), "#9aa3ad", "metal", rot=(90, 0, 0), seg=10))
    return out
models["rover"] = M("Вездеход", wheels((-0.95, 0.95), (-0.78, 0.78)) + [
    P("box", (2.6, 0.35, 1.3), (0, 0.62, 0), DARK, "dark"),
    P("box", (2.5, 0.5, 1.45), (0, 0.98, 0), YEL, "paint"),
    P("box", (1.1, 0.55, 1.3), (-0.2, 1.48, 0), YEL, "paint"),
    P("box", (0.06, 0.45, 1.2), (0.36, 1.48, 0), "#1b2d3a", "glass", rot=(0, 0, -20)),
    P("box", (1.0, 0.06, 1.2), (-0.25, 1.77, 0), DARK, "dark"),
    P("box", (0.9, 0.3, 1.36), (0.85, 1.25, 0), "#3a3d44", "metal"),
    P("box", (0.08, 0.16, 0.3), (1.29, 1.0, 0.45), "#fff4c2", "glow"),
    P("box", (0.08, 0.16, 0.3), (1.29, 1.0, -0.45), "#fff4c2", "glow"),
    P("box", (0.06, 0.12, 0.25), (-1.27, 1.0, 0.5), "#ff3a2a", "glow"),
    P("box", (0.06, 0.12, 0.25), (-1.27, 1.0, -0.5), "#ff3a2a", "glow"),
    P("cylinder", (0.05, 0.9, 0.05), (-1.0, 1.9, 0.55), STEEL, "metal"),
    P("box", (0.6, 0.28, 0.5), (-0.95, 1.3, 0), "#5a4630", "wood"),
], "Транспорт")
models["drone_carrier"] = M("Дрон-перевозчик", [
    P("box", (0.8, 0.25, 0.8), (0, 0.6, 0), "#d8dde4", "paint"),
    P("sphere", (0.5, 0.3, 0.5), (0, 0.8, 0), "#3d7bd9", "glass"),
    P("box", (1.6, 0.06, 0.08), (0, 0.65, 0), DARK, "dark", rot=(0, 45, 0)),
    P("box", (1.6, 0.06, 0.08), (0, 0.65, 0), DARK, "dark", rot=(0, -45, 0)),
] + [P("cylinder", (0.55, 0.02, 0.55), (0.56 * dx, 0.72, 0.56 * dz), "#9aa3ad", "metal", anim="spin", seg=12) for dx in (-1, 1) for dz in (-1, 1)] + [
    P("box", (0.6, 0.4, 0.6), (0, 0.25, 0), "#a8742a", "wood"),
    P("box", (0.08, 0.06, 0.08), (0.42, 0.58, 0), "#7dff5a", "glow", anim="pulse"),
], "Транспорт")
models["truck_carrier"] = M("Грузовик-перевозчик", wheels((-0.9, 0.2, 0.95), (-0.7, 0.7), r=0.36) + [
    P("box", (2.6, 0.25, 1.2), (0, 0.5, 0), DARK, "dark"),
    P("box", (0.8, 0.8, 1.25), (0.85, 1.0, 0), "#3d7bd9", "paint"),
    P("box", (0.05, 0.4, 1.0), (1.26, 1.15, 0), "#1b2d3a", "glass"),
    P("box", (1.6, 0.9, 1.3), (-0.45, 1.08, 0), "#c0c4cc", "metal"),
    P("box", (1.62, 0.1, 1.32), (-0.45, 1.55, 0), YEL, "paint"),
    P("box", (0.06, 0.12, 0.25), (1.27, 0.75, 0.45), "#fff4c2", "glow"),
    P("box", (0.06, 0.12, 0.25), (1.27, 0.75, -0.45), "#fff4c2", "glow"),
], "Транспорт")
def port_model(name, col, pad):
    return M(name, [
        P("box", (1.9, 0.25, 1.9), (0, 0.12, 0), CONC, "concrete"),
        P("box", (1.5, 0.05, 1.5), (0, 0.27, 0), pad, "paint"),
        P("box", (1.1, 0.04, 0.12), (0, 0.3, 0), "#f2f2f2", "paint"),
        P("box", (0.12, 0.04, 1.1), (0, 0.3, 0), "#f2f2f2", "paint"),
        P("box", (0.5, 1.0, 0.5), (-0.65, 0.75, -0.65), col, "paint"),
        P("cylinder", (0.06, 1.2, 0.06), (0.75, 0.85, 0.75), STEEL, "metal"),
        P("sphere", (0.18, 0.18, 0.18), (0.75, 1.5, 0.75), "#ff8c1a", "glow", anim="pulse"),
        P("box", (0.4, 0.3, 0.05), (-0.65, 0.95, -0.38), "#4de1ff", "glow"),
    ], "Транспорт")
models["drone_port"] = port_model("Площадка дронов (отправка)", "#3d7bd9", "#2a5a9a")
models["drone_dock"] = port_model("Площадка дронов (приём)", "#3dd97b", "#2a9a5a")
models["truck_station"] = port_model("Грузовая станция (отправка)", YEL, "#6b5a2a")
models["truck_depot"] = port_model("Грузовая станция (приём)", "#d9603d", "#7a3a2a")
B("rover", "Вездеход", "Машина: подойдите и нажмите E — сесть, E ещё раз — выйти. Едет в 2,5 раза быстрее бега.", "special", "vehicle",
  {"iron_plate": 20, "motor": 4, "rubber": 4} if "rubber" in items else {"iron_plate": 20, "motor": 4, "gear": 8}, "rover", 400, speed=2.5, pollution=0)
def CARRIER(mode, ground):
    return {"type": "carrier", "mode": mode, "channel": "A", "n": 10 if not ground else 30, "every": 8.0 if not ground else 20.0,
            "range": 80.0 if not ground else 160.0, "speed": 14.0 if not ground else 8.0,
            "model": "truck_carrier" if ground else "drone_carrier", "ground": ground, "needs_power": not ground}
BB("drone_port", "Площадка дронов: отправка", "Принимает предметы с ленты и отправляет дроном (по 10) на ближайшую площадку приёма того же канала. Нужна энергия.", "decor",
   {"iron_plate": 10, "circuit": 4, "motor": 2}, "drone_port", 250, [CARRIER("send", False)], power=6, pollution=0)
BB("drone_dock", "Площадка дронов: приём", "Сюда прилетают дроны; груз выходит на ленту.", "decor",
   {"iron_plate": 10, "circuit": 2}, "drone_dock", 250, [CARRIER("receive", False)], pollution=0)
BB("truck_station", "Грузовая станция: отправка", "Копит предметы с ленты и раз в 20 секунд отправляет грузовик (по 30) на станцию приёма того же канала.", "decor",
   {"iron_plate": 16, "motor": 2, "gear": 6}, "truck_station", 300, [CARRIER("send", True)], pollution=1)
BB("truck_depot", "Грузовая станция: приём", "Сюда приезжают грузовики; груз выходит на ленту.", "decor",
   {"iron_plate": 12, "gear": 4}, "truck_depot", 300, [CARRIER("receive", True)], pollution=0)
# 14.5 дроны по маршруту: «отвезти груз со склада А на склад Б» по меткам зданий
models["drone_hub"] = port_model("Станция дронов (маршруты)", "#4a9cff", "#2a4f8a")
BB("drone_hub", "Станция дронов: маршруты", "Дроны возят груз по шагам маршрута: «со склада с меткой А на склад с меткой Б». Метка ставится в окне склада или машины. Шаги правятся в редакторе (блок «Дроны по маршруту»). Нужна энергия.", "decor",
   {"iron_plate": 14, "circuit": 6, "motor": 3}, "drone_hub", 260,
   [{"type": "route", "steps": [{"item": "", "n": 10, "from_tag": "A", "to_tag": "B", "keep": 0}], "every": 6.0, "range": 120.0, "speed": 16.0,
     "model": "drone_carrier", "ground": False, "needs_power": True}], power=8, pollution=0)
TN("t_transport", "Транспорт", 4, 2, "rover", "Вездеход, дроны и грузовики: перевозка предметов между частями базы без лент.",
   {"iron_plate": 40, "motor": 10, "circuit": 10}, {"buildings": ["rover", "drone_port", "drone_dock", "truck_station", "truck_depot", "drone_hub"]}, requires=["t_power"], research=15)
for b in ("rover", "drone_port", "drone_dock", "truck_station", "truck_depot", "drone_hub"):
    if b in tech["t_special"]["unlocks"]["buildings"]:
        tech["t_special"]["unlocks"]["buildings"].remove(b)
options["sections"][0]["items"].append(O("key_blueprint", "Чертёж (копировать здания)", "key", "G"))
options["sections"][0]["items"].append(O("key_photo", "Фоторежим (F12 — снимок)", "key", "F9"))
options["sections"][0]["items"].append(O("key_top_view", "Камера сверху", "key", "Y"))
options["sections"][0]["items"].append(O("key_flow_map", "Карта потоков (где стоит производство)", "key", "L"))
options["sections"][0]["items"].append(O("key_scan", "Сканер ресурсов", "key", "I"))
options["sections"][0]["items"].append(O("key_constructor", "Конструктор модов (свои здания и предметы)", "key", "N"))

events = {}
def EV(id, name, kind, text, chance, min_day, duration, power, end_text="", color="#ffb050", actions=()):
    events[id] = {"name": name, "kind": kind, "text": text, "end_text": end_text, "color": color, "chance": chance,
                  "min_day": min_day, "duration": duration, "power": power, "actions": list(actions)}
EV("meteor_shower", "Метеоритный дождь", "meteor", "Метеоритный дождь! Рядом падают камни с рудой и кристаллами.", 0.075, 2, 30, 6,   # 1.3: вчетверо реже
   color="#ff8c3a")
EV("storm", "Буря", "storm", "Надвигается буря: темно, идти тяжело, солнечные панели слабеют, а ветряки крутятся вовсю.", 0.25, 2, 150, 1.0,
   end_text="Буря утихла.", color="#9fb4c8")
EV("invasion", "Нашествие", "invasion", "Нашествие! Монстров в этой волне вдвое больше.", 0.12, 4, 10, 2.0, color="#ff5a4a")
EV("supply_drop", "Посылка со станции", "custom", "Станция сбросила посылку рядом с вами.", 0.2, 2, 5, 1.0, color="#7dff9a",
   actions=[{"do": "drop", "item": "iron_plate", "n": "15", "x": "$x", "z": "$z"}, {"do": "drop", "item": "circuit", "n": "4", "x": "$x", "z": "$z"},
            {"do": "chance", "v": "0.4"}, {"do": "drop", "item": "medkit", "n": "2", "x": "$x", "z": "$z"}])
# 14.1 живая экономика: события меняют цены, пока идут
events["storm"]["prices"] = [{"item": "", "category": "Материалы", "mult": 1.25}, {"item": "", "category": "Детали", "mult": 1.15}]
events["invasion"]["prices"] = [{"item": "ammo", "category": "", "mult": 1.6}, {"item": "", "category": "Оружие", "mult": 1.3}, {"item": "medkit", "category": "", "mult": 1.4},
                                {"item": "", "category": "Добыча с монстров", "mult": 0.7}]
events["meteor_shower"]["prices"] = [{"item": "crystal", "category": "", "mult": 0.75}, {"item": "", "category": "Руда", "mult": 0.85}]
for _e in events.values():
    _e.setdefault("prices", [])

# ---------------------------------------------------------------- этап 9: НПС (жители и гости), группы и репутация
SKIN = ["#e8b48a", "#c68c5a", "#8a5a3a", "#f0c8a0"]
def human(name, shirt, pants, skin, hat=None, extra=()):
    R, g = art_rigged.human(name, shirt, pants, skin, hat or (), extra)
    return art_rigged.model(name, R, g, "НПС")
models["npc_trader"] = human("Торговец", "#3d7bd9", "#4a3a2a", SKIN[0], hat=[
    P("cylinder", (0.6, 0.04, 0.6), (0, 2.0, 0), "#7a5a2a", "cloth", seg=14),
    P("cylinder", (0.34, 0.22, 0.34), (0, 2.1, 0), "#7a5a2a", "cloth", seg=12),
    P("torus", (0.36, 0.06, 0.36), (0, 2.03, 0), "#c9a227", "cloth", seg=12)],
    extra=[("b:torso", P("box", (0.3, 0.6, 0.46), (-0.32, 1.25, 0), "#8a6a3a", "cloth")),
           ("b:torso", P("box", (0.12, 0.2, 0.3), (-0.5, 1.3, 0), "#c9a227", "metal")),
           ("b:torso", P("cylinder", (0.12, 0.5, 0.12), (-0.32, 1.64, 0.14), "#d8c8a0", "cloth", rot=(90, 0, 0), seg=8)),
           ("b:torso", P("box", (0.32, 0.04, 0.04), (-0.17, 1.55, 0.2), "#4a3a2a", "cloth")),
           ("b:torso", P("box", (0.32, 0.04, 0.04), (-0.17, 1.55, -0.2), "#4a3a2a", "cloth"))])
models["npc_traveler"] = human("Путник", "#5a7a3a", "#3a3a40", SKIN[1], hat=[
    P("sphere", (0.4, 0.22, 0.38), (0, 2.0, 0), "#4a5a2a", "cloth", seg=10)],
    extra=[("b:torso", P("box", (0.24, 0.5, 0.4), (-0.3, 1.3, 0), "#6a4a2a", "cloth")),
           ("b:torso", P("cylinder", (0.2, 0.36, 0.2), (-0.3, 1.62, 0), "#3a5a8a", "cloth", rot=(90, 0, 0), seg=10)),
           ("b:forer", P("cylinder", (0.05, 1.9, 0.05), (0.12, 0.95, 0.4), "#6a4a2a", "wood", seg=6))])
models["npc_bandit"] = human("Бандит", "#3a3a3a", "#2a2a30", SKIN[2], hat=[
    P("box", (0.38, 0.12, 0.38), (0.0, 1.8, 0), "#b03030", "cloth"),
    P("box", (0.08, 0.1, 0.1), (-0.2, 1.8, 0.12), "#b03030", "cloth")],
    extra=[("b:forer", P("box", (0.7, 0.08, 0.08), (0.3, 0.9, 0.36), "#2a2a2a", "metal")),
           ("b:forer", P("box", (0.12, 0.16, 0.06), (0.12, 0.84, 0.36), "#5a3a2a", "wood")),
           ("b:torso", P("box", (0.36, 0.3, 0.56), (0.02, 1.36, 0), "#4a3a2a", "cloth")),
           ("b:torso", P("box", (0.06, 0.5, 0.06), (0.19, 1.3, 0.12), "#8a6a2a", "cloth", rot=(40, 0, 0)))])
models["npc_infiltrator"] = human("Странник в капюшоне", "#5a4a6a", "#3a3040", SKIN[3], hat=[
    P("sphere", (0.44, 0.46, 0.42), (-0.02, 1.88, 0), "#4a3a5a", "cloth", seg=12),
    P("box", (0.06, 0.04, 0.2), (0.21, 1.88, 0), "#ff4ad0", "glow", anim="pulse")],
    extra=[("b:torso", P("box", (0.32, 0.9, 0.6), (-0.06, 1.05, 0), "#4a3a5a", "cloth"))])

factions = {
    "settlers": {"name": "Поселенцы", "color": "#5ac85a", "desc": "Мирные путники и фермеры. Любят торговлю и подарки.", "start_rep": 10, "order": 0},
    "merchants": {"name": "Гильдия торговцев", "color": "#3d7bd9", "desc": "Караваны торговцев. Чем лучше отношение — тем ниже цены.", "start_rep": 0, "order": 1},
    "raiders": {"name": "Налётчики", "color": "#d94a3a", "desc": "Бандиты. Грабят склады и нападают на героя. Чем хуже отношение — тем чаще налёты.", "start_rep": -20, "order": 2},
    "shadows": {"name": "Тени", "color": "#a05ad9", "desc": "Втираются в доверие: днём торгуют, ночью вредят.", "start_rep": 0, "order": 3},
}
def NPC(id, name, model, behavior, faction, hp, speed, greeting, goods=(), buys=(), stay=120, rep_kill=0, damage=0, drops=(), lines=()):
    enemies[id] = {"name": name, "model": model, "hp": hp, "speed": speed, "damage": damage, "rate": 0.9, "reach": 1.2, "reward": 0, "xp": 3,
                   "behavior": behavior, "radius": 0.5, "drops": list(drops), "faction": faction, "greeting": greeting,
                   "goods": [{"item": g[0], "n": g[1], "price": g[2]} for g in goods], "buys": list(buys), "stay": stay, "rep_kill": rep_kill,
                   "lines": "\n".join(lines)}
NPC("trader", "Торговец", "npc_trader", "trader", "merchants", 120, 4.0, "Привет, колонист! Посмотри мой товар.",
    goods=[("iron_plate", 20, 6), ("circuit", 5, 30), ("medkit", 3, 25), ("seeds_wheat" if "seeds_wheat" in items else "berry", 10, 3), ("crystal", 1, 120)],
    buys=["log", "plank", "raw_meat", "chitin", "goo"], stay=150, rep_kill=-30,
    lines=["Дороги нынче опасные.", "Слышал, налётчики шастают у реки.", "Хорошая у тебя база!"])
NPC("traveler", "Путник", "npc_traveler", "traveler", "settlers", 80, 3.0, "Доброго дня! Иду своей дорогой.", stay=40, rep_kill=-20,
    goods=[("berry", 6, 2), ("bandage" if "bandage" in items else "medkit", 2, 15)], buys=["raw_meat", "berry"],
    lines=["Красиво тут у вас.", "Монстры ночью злые, береги себя."])
NPC("bandit", "Налётчик", "npc_bandit", "bandit", "raiders", 90, 6.5, "Отдавай добро!", damage=9, rep_kill=5,
    drops=[{"item": "iron_plate", "chance": 0.5, "min": 1, "max": 4}, {"item": "ammo", "chance": 0.4, "min": 3, "max": 8}] if "ammo" in items else [{"item": "iron_plate", "chance": 0.5, "min": 1, "max": 4}])
NPC("infiltrator", "Странник в капюшоне", "npc_infiltrator", "infiltrator", "shadows", 100, 4.5, "Здравствуй... Не найдётся места переночевать?",
    goods=[("glass", 10, 5), ("wire", 20, 3)], buys=["plank", "stone"], stay=300, rep_kill=-5,
    lines=["Хорошие у тебя ящики... крепкие?", "Ночью тут тихо, правда?"])
for id in ("trader", "traveler", "bandit", "infiltrator"):
    for g in enemies[id]["goods"]:
        assert g["item"] in items, g
EV("trader_visit", "Караван торговцев", "visit", "К базе идут торговцы! Подойдите и нажмите E, чтобы торговать.", 0.35, 2, 200, 2, color="#6bb8ff")
events["trader_visit"]["npc"] = "trader"
EV("travelers", "Путники", "visit", "Мимо базы идут путники.", 0.3, 1, 60, 3, color="#9be07a")
events["travelers"]["npc"] = "traveler"
EV("bandit_raid", "Налёт бандитов", "visit", "Налётчики идут грабить склады! Турели к бою.", 0.18, 3, 30, 4, color="#ff5a4a")
events["bandit_raid"]["npc"] = "bandit"
EV("stranger", "Странник", "visit", "К базе подошёл странник в капюшоне.", 0.15, 4, 30, 1, color="#c08aff")
events["stranger"]["npc"] = "infiltrator"
settings["modules"]["npcs"] = True
# 14.7 фото- и видеорежим
settings["photo_filters"] = [
    {"name": "Обычный"},
    {"name": "Кино", "saturation": 1.1, "contrast": 1.18, "brightness": 0.97, "dark": "#0f1a24", "light": "#fff1dc"},
    {"name": "Чёрно-белый", "saturation": 0.0, "contrast": 1.25},
    {"name": "Сепия", "saturation": 0.0, "contrast": 1.1, "dark": "#2a1a0c", "light": "#f5e2c0"},
    {"name": "Тёплый", "saturation": 1.1, "dark": "#1a0e06", "light": "#ffe8c8"},
    {"name": "Холодный", "saturation": 0.95, "dark": "#06101e", "light": "#dceeff"},
    {"name": "Яркий", "saturation": 1.5, "contrast": 1.1},
    {"name": "Ночное видение", "saturation": 0.0, "contrast": 1.3, "brightness": 1.3, "dark": "#001a04", "light": "#a8ffb0"},
]
settings["video_fps"] = 30
settings["video_quality"] = 0.85
settings["video_max_width"] = 1920
settings["modules"]["orders"] = True
settings.update({"anim_dist": 60, "anim_max": 40, "npc_max": 12, "sleep_dist": 160, "rep_trade": 1, "rep_gift_per": 10,
                 "order_check": 20, "order_spread": 0.12, "order_max_ratio": 1.6, "order_life": 600, "market_recover": 0.08, "market_sell_drop": 0.004,
                 "blueprint_max": 16, "net_sync_every": 3.0, "net_chat_time": 20.0, "flow_range": 120.0, "flow_ok": "#3ddc6a", "flow_stuck": "#ff3b30", "flow_starve": "#ffd23a", "flow_nopower": "#b06bff", "flow_fluid": "#46b8ff", "flow_empty": "#80868f", "flow_show_empty": False, "econ_abundance": True, "econ_abundance_top": 5, "econ_abundance_drop": 0.3, "econ_abundance_min": 50,
                 "seasons": [
                     {"name": "Весна", "days": 5, "prices": [{"item": "", "category": "Еда", "mult": 0.85}, {"item": "", "category": "Сырьё", "mult": 1.15}]},
                     {"name": "Лето", "days": 5, "prices": [{"item": "water_flask", "category": "", "mult": 1.4}, {"item": "", "category": "Жидкости в таре", "mult": 1.25}, {"item": "", "category": "Еда", "mult": 0.9}]},
                     {"name": "Осень", "days": 5, "prices": [{"item": "", "category": "Еда", "mult": 1.2}, {"item": "", "category": "Материалы", "mult": 1.1}]},
                     {"name": "Зима", "days": 5, "prices": [{"item": "", "category": "Еда", "mult": 1.4}, {"item": "coal", "category": "", "mult": 1.5}, {"item": "fuel", "category": "", "mult": 1.3}, {"item": "", "category": "Сырьё", "mult": 1.2}]},
                 ]})

# 14.3 события мира: солнечный выброс, «Рёв матери», «Дрожь земли», землетрясение; бункер и щит-купол
import world_events
world_events.apply(models, buildings, events, enemies)
import explore
explore.apply(models, buildings, items, recipes, settings, tech)
import fortify
fortify.apply(models, buildings, settings)
import dungeon_data
dungeon_data.apply(models, buildings, items, settings)
import npc_memory
npc_memory.apply(enemies, settings)
import climate_data
climate_data.apply(models, buildings, items, recipes, settings)
import world_events2
world_events2.apply(models, buildings, items, events, enemies)
for _t in tech.values():
    if "laser_turret" in _t.get("unlocks", {}).get("buildings", []):
        _t["unlocks"]["buildings"] += ["tesla_coil", "steel_wall"]
        break

# звуки работы зданий (tools/gen_work_sfx.py синтезирует файлы)
import work_sounds
for _sid, _nm in work_sounds.SOUNDS.items():
    sounds[_sid] = S(snd(_sid), -12, 0.04, max_dist=40, name=_nm)
work_sounds.assign(buildings)

import detail_pass
# 14.4 около 500 монстров: 12 семейств × 8 видов × 5 вариантов силы (tools/art_families.py)
import art_families
_fam_models = art_families.apply(models, enemies)
# 14.5 правила поведения блоками: примеры у некоторых видов (у всех вариантов силы). Правятся в «Монстры и НПС → Правила»
def _R(cond, then, n=None, **kw):
    r = {"if": cond, "then": then, "stop": True}
    if n is not None:
        r["n"] = n
    r.update(kw)
    return r
MOB_RULES = {
    "zombie_screamer": [_R("hit", "call_allies", value=20, cooldown=8), _R("hit", "say", text="Ааааа!", cooldown=15)],
    "gnome": [_R("hp_below", "flee", 0.35), _R("always", "normal")],
    "gnome_miner": [_R("player_far", "attack_building", 20), _R("always", "normal")],
    "troll": [_R("hp_below", "heal_self", 0.3, value=60, cooldown=20), _R("always", "normal")],
    "troll_berserk": [_R("hp_below", "speed", 0.5, value=1.8, cooldown=6), _R("always", "attack_player")],
    "giant_chief": [_R("timer", "say", 1, text="Я раздавлю вашу базу!", cooldown=999), _R("always", "attack_base")],
    "witch_blink": [_R("hit", "teleport", cooldown=6), _R("always", "normal")],
    "ghost": [_R("day", "wander"), _R("night", "attack_player")],
    "alien_grey": [_R("allies_near", "attack_player", 3), _R("alone", "flee"), _R("always", "normal")],
    "robot_guard": [_R("sees_player", "attack_player", 15), _R("always", "go_home")],
    "slime_heal": [_R("hp_below", "summon", 0.5, value=2, enemy="slime_small", cooldown=15), _R("always", "normal")],
    "hive_queen": [_R("hit", "summon", value=3, enemy="ant", cooldown=10), _R("always", "normal")],
}
# 14.7 осады с боссом: гиганты-боссы на основе видов из семейств (модель та же, втрое крупнее)
def BOSS(id, src, name, scale, hp, dmg, speed, reach, radius, reward, rules, **kw):
    e = json.loads(json.dumps(enemies[src]))
    e.update({"name": name, "scale": scale, "hp": hp, "damage": dmg, "speed": speed, "reach": reach, "radius": radius,
              "reward": reward, "xp": reward // 10, "boss": True, "behavior": "base", "spawn_weight": 0, "rules": rules,
              "drops": [{"item": "crystal", "chance": 1.0, "min": 6, "max": 12, "on": "break"}, {"item": "circuit", "chance": 1.0, "min": 8, "max": 16, "on": "break"}]})
    e.pop("tint", None); e.pop("tint_k", None)
    e.update(kw)
    enemies[id] = e
BOSS("boss_titan", "giant_chief", "Титан", 3.2, 6000, 90, 3.0, 3.6, 2.6, 900,
     [_R("hp_below", "summon", 0.5, value=3, enemy="giant", cooldown=30), _R("hp_below", "speed", 0.25, value=1.5, cooldown=8),
      _R("timer", "say", 2, text="Я сотру вашу базу в пыль!", cooldown=9999), _R("always", "attack_base")])
BOSS("boss_dragon", "dragon_mother", "Пламенный дракон", 2.6, 4500, 60, 4.5, 14.0, 2.2, 1000,
     [_R("hp_below", "teleport", 0.6, cooldown=20), _R("sees_player", "attack_player", 25), _R("always", "attack_base")],
     fly=True, fly_height=6.0, ranged=True)
BOSS("boss_worm", "worm_mother", "Червь-пожиратель", 2.8, 5500, 80, 3.6, 3.2, 2.4, 950,
     [_R("hit", "call_allies", value=30, cooldown=15), _R("always", "attack_base")], burrow=True)
BOSS("boss_hive", "hive_queen", "Королева роя", 3.0, 4000, 50, 3.0, 3.0, 2.4, 850,
     [_R("hit", "summon", value=4, enemy="ant", cooldown=12), _R("hp_below", "heal_self", 0.3, value=800, cooldown=40), _R("always", "attack_base")])
BOSS("boss_lich", "lich", "Король-лич", 2.6, 4200, 70, 3.4, 3.0, 1.8, 1100,
     [_R("hit", "teleport", cooldown=10), _R("hp_below", "summon", 0.7, value=3, enemy="ghost", cooldown=20), _R("always", "attack_base")])
waves["sieges"] = {"enabled": True, "first_day": 5, "every_days": 5, "spawn_dist": 90.0, "escort": 10, "escort_growth": 3, "hp_growth": 0.25,
                   "reward": 1500, "bosses": [{"enemy": "boss_titan", "weight": 1.0, "from_day": 5}, {"enemy": "boss_hive", "weight": 1.0, "from_day": 5},
                                              {"enemy": "boss_worm", "weight": 1.0, "from_day": 10}, {"enemy": "boss_dragon", "weight": 1.0, "from_day": 15},
                                              {"enemy": "boss_lich", "weight": 1.0, "from_day": 20}]}
for _eid, _e in enemies.items():
    _base = _eid
    for _suf in ("_t2", "_t3", "_t4", "_t5"):
        if _eid.endswith(_suf):
            _base = _eid[: -len(_suf)]
    if _base in MOB_RULES and _e.get("family"):
        _e["rules"] = [dict(r) for r in MOB_RULES[_base]]
# детализация существ: чешуя, шипы, наросты (tools/creature_pass.py); человекоподобные — панели и заклёпки
import creature_pass
_cdone = set()
for _i, (_eid, _e) in enumerate(enemies.items()):
    _mid = _e.get("model", _eid)
    if _mid in models and _mid not in _cdone:
        _cdone.add(_mid)
        if models[_mid].pop("detail", "creature") == "rigged":
            detail_pass.enrich_rigged(models[_mid], 300)
        else:
            creature_pass.enrich_creature(models[_mid], 300, _i + 1)
for _mid in _fam_models:
    art_families.top_up(models[_mid], 300)

# растения, камни, руда: листья, кора, корни, сколы, лишайник, кристаллы (tools/plant_pass.py)
import plant_pass
_pdone = set()
for _i, (_rid, _r) in enumerate(resources.items()):
    _mid = _r.get("model", _rid)
    if _mid in models and _mid not in _pdone:
        _pdone.add(_mid)
        plant_pass.enrich_plant(models[_mid], _r.get("category", ""), _i + 1)

# герой и люди-НПС: панели брони, болты, канты на каждой кости
for _mid in ["hero"] + [_e.get("model", _eid) for _eid, _e in enemies.items() if str(_e.get("behavior", "")) in ("trader", "traveler", "bandit", "infiltrator")]:
    if _mid in models:
        detail_pass.enrich_rigged(models[_mid], 300)

# детализация: рабочие здания — до 300+ деталей (tools/detail_pass.py); мелочь вдали не рисуется
import detail_pass
settings.update({"detail_size": 0.2, "mesh_lod": True, "lod_min_tris": 300, "flora_shadow_dist": 70.0})
_done = set()
for _bid, _b in buildings.items():
    _mid = _b.get("model", _bid)
    if _mid in models and _mid not in _done:
        _done.add(_mid)
        detail_pass.enrich(models[_mid], _b.get("behavior", ""), int(_b.get("size", 1)), bool(_b.get("blocks")) or any(k in _b.get("params", {}) for k in ("shelter_radius", "shield_radius", "radar_radius")))

# 13.10: стиль «механика фабрики» — герой-робот, механические враги, палитра и мультяшный свет (tools/mech_style.py)
import mech_style
mech_style.apply(models, enemies, settings)
# 13.10 (2): все монстры — роботы, гнёзд нет (tools/robots.py)
import robots
_old = robots.apply(models, enemies, waves, events, items, settings, world, quests, menu)
_refs = json.dumps([items, resources, recipes, buildings, enemies, waves, world, settings, events, tech, quests, menu], ensure_ascii=False)
import rework
rework.apply(models, buildings, items, resources, recipes, settings, world, tech, sounds, quests); rework.apply_omens(events, waves); rework.apply_umbrella(models, items, recipes); rework.apply_bag(settings); rework.apply_tutorial(settings); rework.apply_fusion(settings); rework.apply_drones(models, buildings, tech, settings)
import atom
atom.apply_atom(models, buildings, items, recipes, settings, world, tech)
import endgame
endgame.apply_endgame(models, buildings, items, recipes, settings, tech)
import steam_data
steam_data.apply(settings)
import stage15
stage15.apply(models, buildings, items, recipes, settings, world, tech)
stage15.apply_fusion_tech(settings, tech)
stage15.apply_deposits(world)
import stage16
stage16.apply(models, buildings, items, recipes, settings, tech, sounds, options)
import loot17
loot17.apply(enemies, items)
import doc17
doc17.apply(models, buildings, items, resources, recipes, settings, world, tech, enemies)
import balance17
balance17.apply(buildings, recipes, items, settings)
import flora17
flora17.apply(models, world)
import mine17
mine17.apply(models, buildings, items, recipes, settings, world, tech)
import tierbal17
print("tierbal17: recipes scaled", tierbal17.apply(recipes, items, buildings, tech))
balance17._reprice(items, recipes)
import stage18
stage18.apply(models, buildings, tech, waves, menu, quests, settings)
import stage19
stage19.apply(models, buildings, tech, world, items, settings, options)
import stations21
print("stations21:", stations21.apply(buildings, tech, settings, models))
import quantum21
print("quantum21:", quantum21.apply(buildings, items, tech, enemies, world, settings, models))
import art20
print("art20: models", art20.apply(models))
import sizes21
print("sizes21: grown", sizes21.apply(buildings, models, settings))
import sizes13
# 1.3: звуки отклика (tools/gen_sfx13.py)
sounds["levelup"] = S(snd("levelup"), -4, 0.0, positional=False, name="Новый уровень")
sounds["victory"] = S(snd("victory"), -5, 0.0, positional=False, name="Задание выполнено")
sounds["whoosh"] = S(snd("whoosh"), -9, 0.12, name="Взмах (промах)")
sounds["jump"] = S(snd("jump"), -12, 0.1, name="Прыжок")
sounds["land"] = S(snd("land"), -9, 0.1, name="Приземление")
sounds["demolish"] = S(snd("demolish"), -7, 0.08, name="Снос здания")
sounds["crack"] = S(snd("crack"), -7, 0.1, name="Камень раскололся")
sounds["tick"] = S(snd("tick"), -16, 0.05, positional=False, cooldown=30, name="Щелчок сетки стройки")
sounds["buzz"] = S(snd("buzz"), -12, 0.0, positional=False, cooldown=150, name="Нельзя")
sounds["blip"] = S(snd("blip"), -10, 0.0, positional=False, cooldown=25, name="Подбор (серия)")
print("sizes13:", sizes13.apply(buildings, models, settings, resources))
import menu13
print("menu13:", menu13.apply(options, menu))
import story13
print("story13:", story13.apply(settings, menu, texts, options))
import canopy13
print("canopy13:", canopy13.apply(models, settings))
# 1.3 «Натиск»: галочка при создании мира или сервера (enemies._update_rush)
waves["rush"] = {"enabled": False, "start_min": 30.0, "every_min": 1.0, "base_count": 5, "count_growth": 2.0, "hp_growth": 0.08,
                 "dmg_growth": 0.04, "max_count": 120, "max_alive": 300}
# 1.3: демо-версия (пресет «Демо» с признаком demo или ключ --demo): открыты только этапы дерева до max_tier
settings["demo"] = {"enabled": False, "max_tier": 3, "text": "Ожидайте релиз!"}
# 1.3: перевод {русский текст: английский}. Моды добавляют свой lang.json ({"en": {...}}) или поля name_en/desc_en.
import look14
print("look14:", look14.apply(models, world, items))
import trees14
print("trees14:", trees14.apply(items, resources, settings))
import v15
print("v15:", v15.apply(settings, quests, waves, options))
import v17
print("v17:", v17.apply(settings, world, items, quests))
import v18
print("v18:", v18.apply(settings, world, items, quests, buildings, tech, models))
import v19
print("v19:", v19.apply(settings, models, buildings))
import v111
print("v111:", v111.apply(settings, models, buildings, items))
import v1112
print("v1112:", v1112.apply(settings, buildings, recipes, items))
print("v1114:", v1112.apply_1114(settings, skills))
import v1115
print("v1115:", v1115.apply(settings, buildings, tech, commands, recipes, quests))
# 1.1.15 (дуэль r10, A-1/A-5): отходы АЭС — не бесплатное сырьё. Переработка и «гелий из отходов» больше не печатают
# кредиты и купоны: у отходов есть цена (а сжигать их в Утилизаторе нельзя), гелий из отходов — 1 штука за цикл.
if "nuclear_waste" in items:
    items["nuclear_waste"]["price"] = 1400
    items["nuclear_waste"]["no_sink"] = True
if "helium_from_waste" in recipes:
    recipes["helium_from_waste"]["out"] = {"helium3": 1}
if "recycle_waste" in recipes:
    recipes["recycle_waste"]["out"] = {"enriched_uranium": 3}   # A-5 r10: ТВЭЛ → отход → уран → купоны → ТВЭЛ больше не замкнут
# A-1 r10: гелий-3 в Утилизаторе дешевле ТВЭЛа (15 купонов), иначе 1 гелий → 4 ТВЭЛа → 4 отхода → 4 гелия
if "helium3" in items:
    items["helium3"]["sink"] = 1200
import v1118
print("v1118:", v1118.apply(settings, world, tech, recipes, buildings, quests))
import v1119
print("v1119:", v1119.apply(settings, world, tech, buildings))
import v1120
print("v1120:", v1120.apply(settings))
import subprocess
subprocess.run([_sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lang", "merge_en.py")], check=False)
lang = {"en": json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "lang", "en.json"), encoding="utf-8"))}
_used = {str(o.get("model", "")) for d in (items, resources, buildings, enemies) for o in d.values() if isinstance(o, dict)}
for _mid in _old:
    if _mid not in _used:
        del models[_mid]

# 1.1.15: «Сердце» — каждое даёт место под 10 зданий (штаб — под 20). Разрушено — рушит 10 ближайших зданий,
# среди них могут быть другие сердца (цепная реакция). Сердца ставятся не ближе 2 клеток друг от друга.
HEART = "#17121c"   # 1.1.16: обсидиан с красными прожилками (розовое не к стилю игры)
VEIN = "#ff1e2e"
_veins = []
for _z in (0.236, -0.236):
    for (_x, _y, _h, _r) in [(0.02, 1.48, 0.62, 8), (-0.16, 1.74, 0.34, 42), (0.19, 1.7, 0.32, -38), (-0.13, 1.3, 0.24, -32),
                             (0.15, 1.33, 0.22, 28), (-0.31, 1.95, 0.26, 72), (0.3, 1.97, 0.26, -68), (0.06, 1.1, 0.14, -12)]:
        _veins.append(P("box", (0.045, _h, 0.035), (_x, _y, _z), VEIN, "glow", rot=(0, 0, _r), anim="pulse", role="heart", tint=False))
models["heart"] = M("Сердце", [
    P("cylinder", (1.3, 0.35, 1.3), (0, 0.175, 0), DARK, "dark", seg=10),
    P("cylinder", (0.9, 0.5, 0.9), (0, 0.6, 0), "#211a26", "glass", seg=10),
    P("cylinder", (0.92, 0.03, 0.92), (0, 0.86, 0), "#9a0c18", "glow", anim="pulse", tint=False),
    P("sphere", (0.74, 0.74, 0.5), (-0.27, 1.82, 0), HEART, "glass", role="heart", tint=False),
    P("sphere", (0.74, 0.74, 0.5), (0.27, 1.82, 0), HEART, "glass", role="heart", tint=False),
    P("box", (0.64, 0.64, 0.46), (0, 1.5, 0), HEART, "glass", rot=(0, 0, 45), role="heart", tint=False),
] + _veins, "Особые")
buildings["heart"] = {"name": "Сердце", "desc": "Каждое сердце даёт место ещё под 10 зданий (штаб — под 50), само места не занимает. Ленты, стены, полы, опоры, трубы и украшения не считаются. "
    "Если сердце разрушат, рухнут 10 ближайших к нему зданий — и если среди них другое сердце, оно тоже рухнет и потянет свои 10. Ставится не ближе 2 клеток к другому сердцу.",
    "category": "special", "behavior": "heart", "cost": {"stone": 20, "log": 10, "fiber": 5}, "model": "heart", "hp": 260, "size": 1,
    "params": {"slots": 10}, "sounds": {}}
settings["heart_limit"] = {"enabled": True, "hq": 50, "heart": 10, "gap": 2, "chain_n": 10, "chain_delay": 0.12}

def dump(name, obj):
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)

for name, obj in [("models", models), ("animations", animations), ("items", items), ("resources", resources),
                  ("recipes", recipes), ("categories", categories), ("buildings", buildings), ("enemies", enemies),
                  ("waves", waves), ("skills", skills), ("levels", levels), ("world", world), ("settings", settings), ("ui", ui), ("sounds", sounds), ("music", music), ("options", options), ("professions", professions), ("commands", commands), ("attributes", attributes), ("menu", menu), ("texts", texts), ("quests", quests), ("tech", tech), ("contracts", contracts), ("events", events), ("factions", factions), ("lang", lang)]:
    dump(name, obj)
print("models", len(models), "items", len(items), "resources", len(resources), "recipes", len(recipes), "buildings", len(buildings))
