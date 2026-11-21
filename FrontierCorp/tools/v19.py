# Версия 1.1.9 (30.10): порты зданий как в Satisfactory.
#  • Один выход у каждого здания; входов — сколько разных ресурсов в самом сложном рецепте здания.
#  • Ленты подключаются только к портам; порты встроены в стену: вход — синий, выход — зелёный.
# Вызывается из gen_core.py последним.

IN_COL = "#3fa9ff"
OUT_COL = "#5cff8c"


def _port_model(name, col, inward):
    # +X — наружу от стены, начало — на стене у земли
    P = []

    def box(size, pos, color, mat="paint", rot=(0, 0, 0), **kw):
        d = {"shape": "box", "size": list(size), "pos": list(pos), "rot": list(rot), "color": color, "mat": mat}
        d.update(kw)
        P.append(d)
    # рамка проёма прижата к стене
    box((0.12, 0.92, 0.12), (0.05, 0.46, 0.66), "#2b3138", "metal", bevel=0.02)
    box((0.12, 0.92, 0.12), (0.05, 0.46, -0.66), "#2b3138", "metal", bevel=0.02)
    box((0.14, 0.14, 1.44), (0.05, 0.92, 0), "#2b3138", "metal", bevel=0.02)
    box((0.03, 0.78, 1.2), (0.0, 0.42, 0), "#07080b", "dark")
    # светящаяся полоса над проёмом — цвет порта
    box((0.05, 0.06, 1.16), (0.125, 0.92, 0), col, "glow", emission=2.0)
    # пол порта: тянется до ленты (role stretch: от стены на длину)
    box((1.0, 0.1, 1.2), (0.5, 0.05, 0), "#4a4f57", "metal", role="stretch")
    box((1.0, 0.02, 0.06), (0.5, 0.11, 0.57), col, "glow", emission=1.2, role="stretch")
    box((1.0, 0.02, 0.06), (0.5, 0.11, -0.57), col, "glow", emission=1.2, role="stretch")
    # стрелки-шевроны у стены: внутрь (вход) или наружу (выход)
    a = -35 if inward else 35   # +35: шеврон «>» смотрит наружу
    for x in (0.12, 0.3):
        box((0.26, 0.03, 0.07), (x, 0.12, 0.09), col, "glow", rot=(0, a, 0), emission=1.6)
        box((0.26, 0.03, 0.07), (x, 0.12, -0.09), col, "glow", rot=(0, -a, 0), emission=1.6)
    return {"name": name, "category": "Логистика", "parts": P}


def apply(settings, models, buildings=None):
    settings["ports18"] = {"on": True}
    # печь — простая: один вход (руда и топливо по одной ленте); рецепты из двух видов сырья — руками
    if buildings and "furnace" in buildings:
        buildings["furnace"].setdefault("params", {})["inputs"] = 1
    settings["port_in_color"] = IN_COL
    settings["port_out_color"] = OUT_COL
    # обучение: про порты — где вход, где выход
    for st in settings.get("tutorial", {}).get("steps", []):
        if st.get("title") == "Конвейер" and "синий" not in st.get("text", ""):
            st["text"] = st["text"].rstrip() + (" У зданий есть порты: [color=#5cff8c]зелёный[/color] — выход, [color=#3fa9ff]синий[/color] — вход. "
                                                "Лента подключается только к ним; входов столько, сколько разных ресурсов нужно зданию.")
    models["port_in18"] = _port_model("Порт: вход", IN_COL, True)
    models["port_out18"] = _port_model("Порт: выход", OUT_COL, False)
    return 3
