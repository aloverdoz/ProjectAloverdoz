# 16: сетевая игра по комнатам, свои базы, права на чужие постройки, торговля между игроками, продажа энергии,
# отключаемые волны и монстры, «подколы». Вызывается из gen_core.py после stage15. Всё правится в редакторе.
import sys
gc = sys.modules["__main__"]
P, M, B, I, C, O = gc.P, gc.M, gc.B, gc.I, gc.C, gc.O
STEEL = "#8f99a6"
WOOD = "#8a5a2e"


def apply(models, buildings, items, recipes, settings, tech, sounds, options):
    mods = settings.setdefault("modules", {})
    mods.setdefault("waves", True)
    mods.setdefault("monsters", True)
    # правила комнаты по умолчанию (меню «Сетевая игра» → «Создать комнату» их показывает и меняет)
    settings["coop"] = {
        "max_players": 8, "start": "together", "access": "put", "wallets": "own", "trade": True, "pranks": True,
        "start_credits": 150, "near_dist": 34, "far_dist": 120, "join_timeout": 12,
        "kit": {"plank": 30, "stone": 30, "log": 10, "iron_ingot": 10, "berry": 10},
        "splat_time": 4.0, "paint_color": "#ff5fc8", "flag_radius": 14, "vote_time": 30,
        "upnp": True, "lan_list": True,
        "phrases": ["Сюда!", "Помогите!", "Спасибо!", "Осторожно, монстры!", "Нужно железо", "Продам дёшево", "Меняю камень на железо", "Ха-ха!"],
        "emotes": {"hi": "Привет!", "lol": "Ха-ха-ха!", "yay": "Ура!", "grr": "Грр!", "sad": "Эх...", "dance": "Танцую!", "wow": "Ого!", "no": "Не-а"},
    }

    models["player_market"] = M("Рынок игрока", [
        P("box", (5.8, 0.3, 5.8), (0, 0.15, 0), "#6f747c", "concrete"),
        P("box", (1.6, 1.2, 1.2), (-1.9, 0.9, -1.9), WOOD, "wood"),
        P("box", (1.6, 1.2, 1.2), (1.9, 0.9, -1.9), WOOD, "wood"),
        P("box", (1.6, 1.2, 1.2), (-1.9, 0.9, 1.9), WOOD, "wood"),
        P("box", (1.6, 1.2, 1.2), (1.9, 0.9, 1.9), WOOD, "wood"),
        P("cylinder", (0.12, 3.2, 0.12), (-2.6, 1.9, -2.6), STEEL, "metal", seg=6),
        P("cylinder", (0.12, 3.2, 0.12), (2.6, 1.9, -2.6), STEEL, "metal", seg=6),
        P("cylinder", (0.12, 3.2, 0.12), (-2.6, 1.9, 2.6), STEEL, "metal", seg=6),
        P("cylinder", (0.12, 3.2, 0.12), (2.6, 1.9, 2.6), STEEL, "metal", seg=6),
        P("box", (5.8, 0.12, 2.9), (0, 3.55, -1.45), "#d94a3a", "paint", rot=(-10, 0, 0)),
        P("box", (5.8, 0.12, 2.9), (0, 3.55, 1.45), "#f2f2f2", "paint", rot=(10, 0, 0)),
        P("box", (1.4, 0.9, 0.9), (0, 0.75, 0), "#3c4048", "dark"),
        P("box", (0.9, 0.5, 0.06), (0, 1.5, 0.46), "#ffd23f", "glow", anim="pulse"),
    ], "Торговля")
    models["outpost"] = M("Аванпост", [
        P("box", (3.8, 0.3, 3.8), (0, 0.15, 0), "#6f747c", "concrete"),
        P("box", (3.0, 1.8, 3.0), (0, 1.2, 0), "#c9ced4"),
        P("box", (3.1, 0.2, 3.1), (0, 1.0, 0), "#3f8fd9"),
        P("box", (2.0, 0.6, 2.0), (0, 2.4, 0), "#383d45", "dark"),
        P("cylinder", (0.08, 1.6, 0.08), (1.1, 3.4, 1.1), STEEL, "metal", seg=6),
        P("box", (0.8, 0.45, 0.04), (1.52, 3.95, 1.1), "#3f8fd9", "paint", anim="wave"),
        P("box", (0.9, 0.12, 0.06), (0, 1.8, 1.52), "#7fe0ff", "glow", anim="pulse"),
    ], "Хранение")
    models["power_sell"] = M("Продажа энергии", [
        P("box", (1.6, 0.25, 1.6), (0, 0.12, 0), "#6f747c", "concrete"),
        P("box", (1.0, 1.6, 0.8), (0, 1.0, 0), "#e0b23a"),
        P("box", (0.7, 0.4, 0.05), (0, 1.3, 0.42), "#5cff8c", "glow", anim="pulse"),
        P("cylinder", (0.1, 1.4, 0.1), (0, 2.4, 0), STEEL, "metal", seg=6),
        P("box", (0.9, 0.08, 0.08), (0, 3.0, 0), STEEL, "metal"),
    ], "Энергия")
    models["power_buy"] = M("Покупка энергии", [
        P("box", (1.6, 0.25, 1.6), (0, 0.12, 0), "#6f747c", "concrete"),
        P("box", (1.0, 1.6, 0.8), (0, 1.0, 0), "#3a8fe0"),
        P("box", (0.7, 0.4, 0.05), (0, 1.3, 0.42), "#ffd23f", "glow", anim="pulse"),
        P("cylinder", (0.1, 1.4, 0.1), (0, 2.4, 0), STEEL, "metal", seg=6),
        P("box", (0.9, 0.08, 0.08), (0, 3.0, 0), STEEL, "metal"),
    ], "Энергия")
    models["gnome"] = M("Садовый гном", [
        P("cylinder", (0.42, 0.5, 0.42), (0, 0.25, 0), "#3a7bd5", seg=10),
        P("sphere", (0.36, 0.36, 0.36), (0, 0.66, 0), "#f2c9a0", seg=10),
        P("sphere", (0.3, 0.26, 0.2), (0, 0.55, 0.12), "#f2f2f2", seg=8),
        P("cone", (0.38, 0.55, 0.38), (0, 1.05, 0), "#e0263d", seg=10),
        P("sphere", (0.08, 0.08, 0.08), (0, 0.68, 0.18), "#e07a5a", seg=6),
    ], "Декор")
    models["drop_snowball"] = M("Снежок", [P("sphere", (0.3, 0.3, 0.3), (0, 0.15, 0), "#f4f8ff", "paint", seg=8)], "Предметы")
    models["drop_tomato"] = M("Помидор", [
        P("sphere", (0.32, 0.28, 0.32), (0, 0.14, 0), "#e0262d", "paint", seg=8),
        P("cylinder", (0.06, 0.08, 0.06), (0, 0.3, 0), "#3a9a3a", seg=5)], "Предметы")
    models["drop_paint"] = M("Баллончик краски", [
        P("cylinder", (0.18, 0.42, 0.18), (0, 0.21, 0), "#ff5fc8", "metal", seg=8),
        P("cylinder", (0.08, 0.08, 0.08), (0, 0.46, 0), "#f2f2f2", seg=6)], "Предметы")
    models["drop_cushion"] = M("Подушка-пердушка", [
        P("sphere", (0.5, 0.14, 0.5), (0, 0.07, 0), "#d94a8a", "paint", seg=10),
        P("cylinder", (0.06, 0.1, 0.06), (0.26, 0.07, 0), "#d94a8a", seg=5, rot=(0, 0, 90))], "Предметы")
    models["drop_firework"] = M("Салют", [
        P("cylinder", (0.14, 0.6, 0.14), (0, 0.3, 0), "#e0263d", "paint", seg=8),
        P("cone", (0.16, 0.2, 0.16), (0, 0.7, 0), "#ffd23f", seg=8)], "Предметы")
    models["drop_confetti"] = M("Хлопушка", [
        P("cone", (0.22, 0.5, 0.22), (0, 0.25, 0), "#7a4ae0", "paint", seg=8, rot=(180, 0, 0)),
        P("sphere", (0.1, 0.1, 0.1), (0, 0.55, 0), "#ffd23f", "glow", seg=6)], "Предметы")
    models["drop_surprise"] = M("Сюрприз", [
        P("box", (0.4, 0.4, 0.4), (0, 0.2, 0), "#e0263d", "paint"),
        P("box", (0.42, 0.08, 0.1), (0, 0.4, 0), "#ffd23f", "paint"),
        P("box", (0.1, 0.08, 0.42), (0, 0.4, 0), "#ffd23f", "paint")], "Предметы")

    B("player_market", "Рынок игрока", "Ваша лавка для других игроков: привезите товар лентами (входы с любой стороны) или положите руками, "
      "назначьте цены — другие купят за свои кредиты, деньги придут вам. Можно и скупать: «Куплю» с ценой.",
      "logistics", "storage", {"plank": 20, "iron_ingot": 10}, "player_market", 400, 3, slots=48, player_market=True)
    B("outpost", "Аванпост", "Склад вашей базы в сетевой игре со своими базами: стройка берёт материалы отсюда и из рюкзака. "
      "Принимает предметы с лент.", "storage", "storage", {"plank": 20, "stone": 20}, "outpost", 1200, 2, slots=40, outpost=True)
    B("power_sell", "Продажа энергии", "Подключите к своей сети: отсюда другие игроки покупают энергию (кВт) по вашей цене.",
      "energy", "pole", {"iron_ingot": 6, "wire": 6}, "power_sell", 200, radius=8, power_trade="sell")
    B("power_buy", "Покупка энергии", "Подключите к своей сети и выберите продавца: энергия от его «Продажи энергии» придёт в вашу сеть, "
      "кредиты уйдут ему.", "energy", "pole", {"iron_ingot": 6, "wire": 6}, "power_buy", 200, radius=8, power_trade="buy")
    B("gnome", "Садовый гном", "Подкиньте на чужую базу — хозяин увидит, кто это был.", "decor", "decor", {"stone": 2, "plank": 1}, "gnome", 40, low=True)
    for bid in ("player_market", "outpost", "power_sell", "power_buy", "gnome"):
        buildings[bid]["tags"] = ["coop"]

    I("snowball", "Снежок", "Бросьте (ПКМ в инвентаре или с панели): попадёт в того, на кого смотрите.", "#f4f8ff", "Подколы", 20, 0, "drop_snowball", prank="snowball")
    I("tomato", "Тухлый помидор", "Бросьте в другого игрока — залепит ему экран на пару секунд.", "#e0262d", "Подколы", 20, 1, "drop_tomato", prank="tomato")
    I("paint_can", "Розовая краска", "Распылите на здание перед собой: оно станет в розовых пятнах, пока хозяин не отмоет.", "#ff5fc8", "Подколы", 10, 2, "drop_paint", prank="paint")
    I("cushion", "Подушка-пердушка", "Положите под ноги — кто наступит, тот… ну вы поняли. Её не видно.", "#d94a8a", "Подколы", 10, 2, "drop_cushion", prank="cushion")
    I("firework", "Салют", "Запускает салют над вами — видно всем.", "#e0263d", "Подколы", 20, 2, "drop_firework", prank="firework")
    I("confetti", "Хлопушка", "Конфетти над вами.", "#7a4ae0", "Подколы", 20, 1, "drop_confetti", prank="confetti")
    I("surprise", "Сюрприз", "Положите в чужой ящик: кто достанет — получит «Бу!» и узнает, от кого.", "#e0263d", "Подколы", 10, 2, "drop_surprise")
    C("snowball", "Снежок", {"stone": 1}, {"snowball": 4}, 0.5, ["hand", "workbench"])
    C("tomato", "Тухлый помидор", {"berry": 2}, {"tomato": 2}, 0.5, ["hand", "workbench"])
    C("paint_can", "Розовая краска", {"iron_ingot": 1, "berry": 3}, {"paint_can": 2}, 1.0, ["workbench"])
    C("cushion", "Подушка-пердушка", {"fiber": 4, "berry": 1}, {"cushion": 1}, 1.0, ["hand", "workbench"])
    C("firework", "Салют", {"coal": 1, "plank": 1}, {"firework": 3}, 1.0, ["workbench"])
    C("confetti", "Хлопушка", {"fiber": 2, "plank": 1}, {"confetti": 3}, 0.6, ["hand", "workbench"])
    C("surprise", "Сюрприз", {"plank": 2, "fiber": 2}, {"surprise": 1}, 0.8, ["hand", "workbench"])
    st = tech["t_start"]["unlocks"].setdefault("buildings", [])
    for bid in ("player_market", "outpost", "gnome"):
        if bid not in st:
            st.append(bid)
    pw = tech["t_mining"]["unlocks"].setdefault("buildings", [])
    for bid in ("power_sell", "power_buy"):
        if bid not in pw:
            pw.append(bid)

    snd = lambda n: "res://sounds/%s.wav" % n
    sounds["fart"] = gc.S(snd("fart"), -4, 0.15, name="Подушка-пердушка")
    sounds["horn"] = gc.S(snd("horn"), -3, 0.05, max_dist=220, name="Гудок игрока")
    sounds["pop"] = gc.S(snd("pop"), -6, 0.15, name="Хлопушка, сюрприз")
    sounds["firework"] = gc.S(snd("firework"), -4, 0.1, max_dist=300, name="Салют")
    sounds["bonk"] = gc.S(snd("bonk"), -5, 0.1, name="Кирпич, снежок")

    ctl = options["sections"][0]["items"]
    if not any(o["key"] == "key_fun" for o in ctl):
        ctl.append(O("key_fun", "Фишки и подколы", "key", "U"))
        ctl.append(O("key_ping", "Метка на земле (для всех)", "key", "O"))
