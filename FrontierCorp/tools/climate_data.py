# 14.7 Сезоны и выживание: температура по сезонам, холод и жара, одежда, обогреватели, кухня с горячей едой.
# Всё правится: «Настройки → Климат», «Настройки → Сезоны» (температура, снег, цвет травы), «Предметы» (Одежда: тепло/прохлада),
# «Здания» (Обогрев: градусов и радиус), «Рецепты» (кухня).
import math
from art_kit import P, M

STEEL, DARK, BRICK, WOOD = "#8c949e", "#2a2c31", "#9a5a42", "#8a5a34"


def kitchen_model():
    p = [P("box", (1.9, 0.9, 1.3), (0, 0.45, -0.2), BRICK, "stone"),
         P("box", (1.96, 0.1, 1.36), (0, 0.92, -0.2), "#6a6560", "stone"),
         P("box", (0.7, 0.45, 0.06), (-0.45, 0.45, 0.47), DARK, "dark"),
         P("box", (0.5, 0.25, 0.04), (-0.45, 0.45, 0.5), "#ff7a2a", "glow"),
         P("cylinder", (0.55, 0.45, 0.55), (0.4, 1.2, -0.2), STEEL, "metal", seg=12),
         P("cylinder", (0.5, 0.06, 0.5), (0.4, 1.45, -0.2), "#c9a46a", "paint", seg=12),
         P("torus", (0.6, 0.05, 0.6), (0.4, 1.42, -0.2), "#c9ced4", "metal"),
         P("cylinder", (0.3, 0.12, 0.3), (-0.45, 1.0, -0.35), DARK, "metal", seg=10),
         P("box", (0.35, 0.03, 0.12), (-0.75, 1.03, -0.35), DARK, "metal"),
         P("cylinder", (0.22, 1.6, 0.22), (-0.75, 1.75, -0.7), "#5a5550", "metal", seg=8),
         P("box", (2.0, 0.08, 0.5), (0, 1.9, -0.75), WOOD, "wood")]
    for k in range(4):
        p.append(P("cylinder", (0.12, 0.2, 0.12), (-0.6 + k * 0.4, 2.05, -0.75), ["#d9d2c0", "#b0603a", "#6a8a3a", "#d9b040"][k], "paint", seg=8))
    p.append(P("sphere", (0.3, 0.2, 0.3), (0.4, 1.62, -0.2), "#ffffff", "glow", anim="pulse"))
    return M("Кухня", p, "Станции")


def heater_model():
    p = [P("box", (1.2, 0.2, 0.8), (0, 0.1, 0), DARK, "dark"),
         P("box", (1.1, 1.2, 0.5), (0, 0.8, 0), "#c9ced4", "metal")]
    for k in range(6):
        p.append(P("box", (0.12, 1.0, 0.54), (-0.42 + k * 0.17, 0.8, 0), "#a8aeb6", "metal"))
    p.append(P("box", (0.9, 0.08, 0.04), (0, 1.25, 0.27), "#ff5a2a", "glow"))
    p.append(P("box", (0.9, 0.08, 0.04), (0, 0.4, 0.27), "#ff5a2a", "glow"))
    p.append(P("sphere", (0.1, 0.1, 0.1), (0.45, 1.3, 0.26), "#3ddc6a", "glow"))
    return M("Обогреватель", p, "Климат")


def cooler_model():
    p = [P("box", (1.1, 0.25, 1.1), (0, 0.12, 0), DARK, "dark"),
         P("cylinder", (0.18, 1.1, 0.18), (0, 0.8, 0), STEEL, "metal", seg=8),
         P("torus", (1.2, 0.1, 1.2), (0, 1.55, 0), "#c9ced4", "metal", rot=(90, 0, 0)),
         P("sphere", (0.3, 0.3, 0.3), (0, 1.55, 0), "#5a6068", "metal")]
    for k in range(4):
        a = k * 90
        p.append(P("box", (0.5, 0.2, 0.03), (0, 1.55, 0.05), "#7fd0ff", "paint", rot=(0, 0, a), anim="spin"))
    return M("Охладитель", p, "Климат")


def coat_model(col, trim):
    p = [P("box", (0.5, 0.6, 0.18), (0, 0.35, 0), col, "cloth"),
         P("box", (0.16, 0.5, 0.16), (-0.33, 0.37, 0), col, "cloth", rot=(0, 0, 12)),
         P("box", (0.16, 0.5, 0.16), (0.33, 0.37, 0), col, "cloth", rot=(0, 0, -12)),
         P("box", (0.54, 0.1, 0.22), (0, 0.66, 0), trim, "cloth"),
         P("box", (0.04, 0.5, 0.2), (0, 0.35, 0.0), trim, "cloth")]
    return M("Одежда", p, "Предметы")


def dish_model(col):
    p = [P("cylinder", (0.5, 0.08, 0.5), (0, 0.06, 0), "#e8e4dc", "paint", seg=14),
         P("cylinder", (0.38, 0.12, 0.38), (0, 0.14, 0), col, "paint", seg=12)]
    return M("Блюдо", p, "Предметы")


SEASON_CLIMATE = {
    "Весна": {"temp_day": 16, "temp_night": 4, "snow": 0.0, "tint": "#ffffff", "tint_k": 0.0},
    "Лето": {"temp_day": 37, "temp_night": 20, "snow": 0.0, "tint": "#f2e08a", "tint_k": 0.18},
    "Осень": {"temp_day": 9, "temp_night": -1, "snow": 0.0, "tint": "#d08a3a", "tint_k": 0.45},
    "Зима": {"temp_day": -10, "temp_night": -24, "snow": 0.85, "tint": "#e0e8f0", "tint_k": 0.3},
}


def apply(models, buildings, items, recipes, settings):
    models["kitchen"] = kitchen_model()
    models["heater"] = heater_model()
    models["cooler"] = cooler_model()
    models["drop_coat"] = coat_model("#7a5236", "#d9c7a8")
    models["drop_suit"] = coat_model("#5aa8c8", "#e6f2f8")
    models["drop_dish"] = dish_model("#a85a2a")
    models["drop_salad"] = dish_model("#6aa83a")
    settings["climate"] = {"comfort_min": 8, "comfort_max": 30, "chill_rate": 0.05, "heat_rate": 0.05, "recover": 4.0,
                           "cold_damage": 3.0, "heat_damage": 2.0, "heat_thirst": 1.5, "slow_from": 60, "slow": 0.3, "hot_clothes": 0.5,
                           "temp_day": 18, "temp_night": 8, "show_temp": True}
    settings.setdefault("modules", {})["climate"] = True
    for s in settings.get("seasons", []):
        s.update(SEASON_CLIMATE.get(s.get("name", ""), {}))
    buildings["kitchen"] = {"name": "Кухня", "desc": "Готовит горячую еду: жаркое греет зимой, салат освежает летом. Подойдите и нажмите E.",
                            "category": "stations", "behavior": "station", "cost": {"log": 4, "stone": 8, "iron_plate": 2}, "model": "kitchen",
                            "hp": 200, "size": 1, "params": {"station": "kitchen", "heat": 10, "heat_radius": 3}, "sounds": {"work": "work_smelt"}}
    buildings["heater"] = {"name": "Обогреватель", "desc": "Греет героя рядом (на энергии). Зимой ставьте у рабочих мест.",
                           "category": "special", "behavior": "decor", "cost": {"iron_plate": 6, "wire": 6, "circuit": 1}, "model": "heater",
                           "hp": 200, "size": 1, "params": {"power": 12, "heat": 30, "heat_radius": 7}}
    buildings["cooler"] = {"name": "Охладитель", "desc": "Охлаждает воздух рядом (на энергии). Спасает от летней жары.",
                           "category": "special", "behavior": "decor", "cost": {"iron_plate": 6, "wire": 6, "motor": 1}, "model": "cooler",
                           "hp": 200, "size": 1, "params": {"power": 12, "heat": -18, "heat_radius": 7}}
    camp = buildings.get("campfire")
    if camp:
        camp.setdefault("params", {}).update({"heat": 25, "heat_radius": 5})
        camp["desc"] = "Греет (зимой спасает от холода) и светит ночью без электричества."
    for fid in ("furnace", "smelter"):
        if fid in buildings:
            buildings[fid].setdefault("params", {}).update({"heat": 12, "heat_radius": 3})
    clothes = {
        "warm_jacket": ("Тёплая куртка", "Одежда: +15° в холод. ПКМ — надеть.", "drop_coat", {"warmth": 15}, {"fiber": 8, "plank": 1}, 40),
        "fur_coat": ("Шуба", "Одежда: +30° в холод, но жарко летом. ПКМ — надеть.", "drop_coat", {"warmth": 30}, {"fiber": 10, "raw_meat": 4}, 90),
        "light_suit": ("Лёгкий костюм", "Одежда: −12° в жару. ПКМ — надеть.", "drop_suit", {"cooling": 12}, {"fiber": 6}, 30),
        "climate_suit": ("Климат-костюм", "Одежда: +20° в холод и −20° в жару. ПКМ — надеть.", "drop_suit", {"warmth": 20, "cooling": 20},
                         {"fiber": 6, "circuit": 2, "wire": 6}, 160),
    }
    for iid, (name, desc, model, stats, cost, price) in clothes.items():
        it = {"name": name, "desc": desc, "color": "#8a6a4a" if model == "drop_coat" else "#5aa8c8", "category": "Одежда", "stack": 1,
              "price": price, "model": model, "clothes": "body"}
        it.update(stats)
        items[iid] = it
        recipes[iid] = {"name": name, "in": cost, "out": {iid: 1}, "time": 3.0, "stations": ["workbench"] if iid != "climate_suit" else ["assembler"]}
    meals = {
        "fried_meat": ("Жареное мясо", "Горячее и сытное. Портится медленно.", "drop_meat", {"food": 35, "heal": 10, "spoil": 1800}, {"raw_meat": 1}, 2.0, 8),
        "hot_stew": ("Жаркое", "Очень сытное. Греет: +15° на 4 минуты.", "drop_dish", {"food": 70, "boost": {"stat": "warmth", "value": 15, "time": 240}},
                     {"raw_meat": 2, "mushroom": 2, "water_flask": 1}, 5.0, 25),
        "herbal_tea": ("Ягодный чай", "Утоляет жажду и греет: +8° на 3 минуты.", "drop_flask", {"water": 50, "boost": {"stat": "warmth", "value": 8, "time": 180}},
                       {"berry": 2, "water_flask": 1}, 2.5, 10),
        "fruit_salad": ("Фруктовый салат", "Освежает в жару: −12° на 4 минуты.", "drop_salad", {"food": 40, "water": 25, "boost": {"stat": "cooling", "value": 12, "time": 240}},
                        {"berry": 3, "apple": 2}, 2.5, 14),
    }
    for iid, (name, desc, model, stats, cost, t, price) in meals.items():
        it = {"name": name, "desc": desc, "color": "#c07a3a", "category": "Еда", "stack": 20, "price": price, "model": model}
        it.update(stats)
        items[iid] = it
        recipes[iid] = {"name": name, "in": cost, "out": {iid: 1}, "time": t, "stations": ["kitchen"]}
