# Версия 1.1.11 (30.10): у печей отдельный вход для топлива, админ-панель.
#  • Печь: два входа (раньше один); с 1.1.12 в любой вход можно подавать и руду, и топливо. Топливо, положенное руками, идёт в топку.
# Вызывается из gen_core.py последним.
import v19

FUEL_COL = "#ff9a2e"


def apply(settings, models, buildings, items=None):
    n = 0
    # резонансный реактор не мог сжечь огранённый резонит: у предмета не было теплоты сгорания
    if items and "cut_resonite" in items:
        items["cut_resonite"]["fuel"] = 1500
        items["cut_resonite"]["special_fuel"] = True
        n += 1
    models["port_fuel111"] = v19._port_model("Порт: топливо", FUEL_COL, True)
    settings["port_fuel_color"] = FUEL_COL
    n += 1
    if "furnace" in buildings:
        buildings["furnace"]["desc"] = ("Сама плавит руду, если в ней есть топливо (ветки, брёвна, уголь). Работает без электричества. "
                                         "Два входа: в любой можно подавать и руду, и топливо — печь разберёт сама.")
        n += 1
    for st in settings.get("tutorial", {}).get("steps", []):
        if st.get("title") == "Конвейер" and "что угодно" not in st.get("text", ""):
            st["text"] = st["text"].replace("Лента подключается только к ним;",
                                            "Лента подключается только к ним, в любой вход можно подавать что угодно;")
            n += 1
        if st.get("title") == "Конвейер" and "два разъёма выхода" in st.get("hint", ""):
            st["hint"] = "Выход у здания один. Нужно поделить поток — поставьте разделитель."
            n += 1
        if st.get("title") == "Печь" and "руду, и топливо" not in st.get("hint", ""):
            st["hint"] = st.get("hint", "") + " У печи два входа: в любой можно подавать и руду, и топливо."
            n += 1
    return n
