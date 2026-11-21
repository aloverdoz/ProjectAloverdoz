# 14.3 (вторая часть) Ещё события мира: кислотный дождь, мороз, засуха и зной, затмение, густой туман,
# нашествие насекомых-вредителей, падение капсулы, богатая жила, вторжения гномов, роботов и пришельцев.
# Всё правится: «Данные → События» (поля Дождь, Темнота, Туман, Снег, Градусов к воздуху, Жажда, Вредители, Капсула, Жила, Идут на базу).
import math
from art_kit import P, M


def capsule_model():
    p = [P("cylinder", (1.6, 2.4, 1.6), (0, 1.3, 0), "#c9ced4", "metal", seg=14),
         P("cone", (1.6, 1.0, 1.6), (0, 3.0, 0), "#e8ebef", "metal", seg=14),
         P("cylinder", (1.75, 0.3, 1.75), (0, 0.15, 0), "#3a3530", "dark", seg=14),
         P("box", (0.9, 1.2, 0.08), (0, 1.4, 0.8), "#2a2c31", "dark"),
         P("box", (0.7, 0.12, 0.05), (0, 1.9, 0.84), "#ffb040", "glow"),
         P("sphere", (0.25, 0.25, 0.25), (0, 3.55, 0), "#ff5a2a", "glow", anim="flicker")]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        p.append(P("box", (0.12, 1.1, 0.4), (math.cos(a) * 0.85, 0.7, math.sin(a) * 0.85), "#8c949e", "metal", rot=(0, -math.degrees(a), 12)))
    for k in range(6):
        a = k * math.pi / 3
        p.append(P("sphere", (0.5, 0.25, 0.5), (math.cos(a) * 1.3, 0.1, math.sin(a) * 1.3), "#4a3a2a", "stone"))
    return M("Упавшая капсула", p, "События")


def apply(models, buildings, items, events, enemies):
    models["supply_capsule"] = capsule_model()
    buildings["supply_capsule"] = {"name": "Упавшая капсула", "desc": "Упала со станции. Внутри добыча — заберите всё.", "category": "",
                                   "behavior": "storage", "cost": {}, "model": "supply_capsule", "hp": 1500, "size": 1,
                                   "params": {"slots": 12, "wild": True}}
    ins = [k for k in ("locust", "ant", "beetle", "wasp") if k in enemies]
    gn = [k for k in ("gnome", "gnome_miner", "gnome_bomber", "gnome_archer") if k in enemies]
    rb = [k for k in ("robot_worker", "robot_guard", "drone", "robot_kamikaze") if k in enemies]
    al = [k for k in ("alien_grey", "alien_warrior", "alien_flyer", "alien_gunner") if k in enemies]
    E = lambda **kw: dict({"actions": [], "prices": [], "end_text": ""}, **kw)
    events["acid_rain"] = E(name="Кислотный дождь", kind="weather", color="#9cff6a", chance=0.07, min_day=3, duration=120, power=1.0,
                            text="Кислотный дождь! Снаружи жжёт кожу, здания ржавеют. Укройтесь под навесом штаба, у бункера или под щитом.",
                            end_text="Кислотный дождь кончился.", rain=1.0, rain_color="#b8ff7a", outdoor_dps=2.5, building_dmg=0.1,
                            sky_color="#7aa040", sky_power=0.35, prices=[{"item": "medkit", "category": "", "mult": 1.3}])
    events["frost"] = E(name="Лютый мороз", kind="weather", color="#9fd0ff", chance=0.06, min_day=4, duration=200, power=1.0,
                        text="Ударил лютый мороз (−28°)! Тёплая одежда, костёр, обогреватель, горячая еда.",
                        end_text="Мороз отступил.", temp_add=-28, snow=0.9, sky_color="#bcd8ff", sky_power=0.3,
                        prices=[{"item": "coal", "category": "", "mult": 1.6}, {"item": "fur_coat", "category": "", "mult": 1.5}])
    events["heatwave"] = E(name="Засуха и зной", kind="weather", color="#ffb060", chance=0.06, min_day=3, duration=240, power=1.0,
                           text="Засуха и зной (+16°)! Пить хочется вдвое чаще. Лёгкий костюм, охладитель, салат.",
                           end_text="Жара спала.", temp_add=16, thirst_add=1.0, sky_color="#ffc070", sky_power=0.25,
                           prices=[{"item": "water_flask", "category": "", "mult": 1.8}, {"item": "", "category": "Жидкости в таре", "mult": 1.4}])
    events["eclipse"] = E(name="Затмение", kind="weather", color="#c07aff", chance=0.05, min_day=5, duration=150, power=1.0,
                          text="Затмение! Днём темно, как ночью: солнечные панели не работают, монстры злее.",
                          end_text="Солнце вернулось.", dark=0.9, sky_color="#402060", sky_power=0.3)
    events["dense_fog"] = E(name="Густой туман", kind="weather", color="#d0d6dc", chance=0.08, min_day=2, duration=180, power=1.0,
                            text="Густой туман: видно вдвое ближе, монстры подкрадываются незаметно.", end_text="Туман рассеялся.", fog=1.0)
    events["locusts"] = E(name="Нашествие саранчи", kind="pests", color="#d0c040", chance=0.06, min_day=4, duration=120, power=14,
                          text="Саранча и жуки летят к складам с едой! Защитите запасы.", end_text="Вредители улетели.",
                          monsters=ins or ["crawler"], spawn_dist=45, sky_color="#a09030", sky_power=0.15,
                          prices=[{"item": "", "category": "Еда", "mult": 1.5}])
    events["capsule_crash"] = E(name="Падение капсулы", kind="capsule", color="#ffb040", chance=0.1, min_day=2, duration=10, power=2,
                                text="С неба упала капсула со станции! Она отмечена на карте. Рядом может быть охрана.",
                                capsule="supply_capsule", spawn_dist=40, monsters=rb[:2] or ["crawler"],
                                loot=[{"item": "circuit", "chance": 1.0, "min": 4, "max": 10}, {"item": "steel", "chance": 0.8, "min": 8, "max": 16},
                                      {"item": "crystal", "chance": 0.5, "min": 2, "max": 5}, {"item": "medkit", "chance": 0.6, "min": 1, "max": 3},
                                      {"item": "ammo", "chance": 0.7, "min": 20, "max": 60}])
    events["rich_vein"] = E(name="Богатая жила", kind="vein", color="#40e0a0", chance=0.08, min_day=2, duration=5, power=14,
                            text="Разведка нашла богатую жилу рядом! Она отмечена на карте.", spawn_dist=30,
                            resources=["ore_iron", "ore_copper", "ore_quartz", "ore_sulfur", "ore_coal"])
    events["gnome_raid"] = E(name="Набег гномов", kind="horde", color="#e0a040", chance=0.05, min_day=5, duration=120, power=12, go_base=True,
                             text="Набег гномов! Они идут к штабу.", end_text="", monsters=gn or ["crawler"], spawn_dist=55)
    events["robot_invasion"] = E(name="Вторжение роботов", kind="horde", color="#70b0ff", chance=0.04, min_day=8, duration=150, power=14, go_base=True,
                                 text="Вторжение роботов! Колонна машин идёт на базу.", monsters=rb or ["brute"], spawn_dist=60,
                                 prices=[{"item": "circuit", "category": "", "mult": 0.8}])
    events["alien_landing"] = E(name="Высадка пришельцев", kind="horde", color="#80ff80", chance=0.04, min_day=12, duration=150, power=16, go_base=True,
                                text="Высадка пришельцев! Корабль сбросил отряд — они идут к штабу.", monsters=al or ["brute"], spawn_dist=60,
                                sky_color="#30a060", sky_power=0.2)
