# Steam: достижения и настройки (settings.steam). Вызывается из gen_core.py.
# Ключи api должны совпадать с теми, что заведены в Steamworks → «Статистика и достижения».

ACHIEVEMENTS = [
    # api, имя RU, имя EN, описание RU, описание EN, goal, n, item, buildings
    ("ACH_FIRST_TOOL", "Первый инструмент", "First Tool", "Сделайте каменный топор", "Craft a stone axe", "have", 1, "stone_axe", []),
    ("ACH_WORKBENCH", "Мастерская открыта", "Open for Business", "Поставьте верстак", "Build a workbench", "build", 1, "", ["workbench"]),
    ("ACH_FIRST_INGOTS", "Горячий металл", "Hot Metal", "Получите 10 железных слитков", "Have 10 iron ingots", "have", 10, "iron_ingot", []),
    ("ACH_AUTOMATION", "Автоматизация", "Automation", "Постройте бур и генератор", "Build a drill and a generator", "build_each", 1, "", ["miner", "generator"]),
    ("ACH_BELTS_100", "Конвейерный магнат", "Conveyor Tycoon", "Проложите 100 лент", "Lay 100 conveyor belts", "build", 100, "", ["belt", "belt_mk2", "belt_mk3", "belt_mk4", "belt_mk5"]),
    ("ACH_DELIVER_500", "План выполнен", "Quota Met", "Доставьте в штаб 500 предметов", "Deliver 500 items to HQ", "delivered", 500, "", []),
    ("ACH_FIRST_WAVE", "Первая кровь", "First Blood", "Отбейте первую волну роботов", "Survive the first robot wave", "waves", 1, "", []),
    ("ACH_WAVES_10", "Крепость", "Fortress", "Отбейте 10 волн", "Survive 10 waves", "waves", 10, "", []),
    ("ACH_VICTORY", "Рубеж удержан", "Frontier Held", "Отбейте 20 волн", "Survive 20 waves", "waves", 20, "", []),
    ("ACH_TRADER", "Торговый партнёр", "Trade Partner", "Заработайте 5000 кр на торговле со станцией", "Earn 5,000 credits trading with the station", "trade", 5000, "", []),
    ("ACH_RESEARCH_5", "Учёный", "Scientist", "Откройте 5 узлов дерева открытий", "Unlock 5 tech tree nodes", "tech", 5, "", []),
    ("ACH_SCAN_20", "Исследователь", "Explorer", "Изучите сканером 20 предметов", "Research 20 items with the scanner", "scan", 20, "", []),
    ("ACH_LEVEL_10", "Ветеран", "Veteran", "Достигните 10-го уровня", "Reach level 10", "level", 10, "", []),
    ("ACH_RICH", "Корпорация", "Corporation", "Накопите 20 000 кр", "Hold 20,000 credits", "credits", 20000, "", []),
]


def apply(settings):
    settings["steam"] = {
        "enabled": True,
        "app_id": 0,
        "restart_if_needed": False,
        "pause_on_overlay": True,
        "achievements": [
            {"api": a, "name": nr, "name_en": ne, "desc": dr, "desc_en": de, "goal": g, "n": n, "item": it, "buildings": bl}
            for a, nr, ne, dr, de, g, n, it, bl in ACHIEVEMENTS
        ],
    }
