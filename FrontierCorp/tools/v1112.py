# Версия 1.1.12 (30.10): ремонт и восстановление зданий за половину цены, держать ПКМ 15 секунд;
# развалины видны всегда и пропадают, если на их месте поставить здание.
# Вызывается из gen_core.py последним.


import math


def fix_slots(buildings, recipes, items):
    """Ячеек сырья у машины — чтобы влез запас на 2 крафта (не меньше 20 штук) каждого сырья самого большого рецепта.
    Раньше, например, у экзотической кузницы было 5 ячеек, а «Квантовое ядро» требует 8 — лента забивала машину
    одним сырьём, и рецепт не запускался никогда."""
    n = 0
    for k, d in buildings.items():
        if d.get("behavior") != "crafter":
            continue
        p = d.setdefault("params", {})
        st = p.get("station", k)
        need = 0
        for r in recipes.values():
            if st not in r.get("stations", []):
                continue
            need = max(need, sum(math.ceil(max(20, v * 2) / items.get(i, {}).get("stack", 50)) for i, v in r["in"].items()))
        if need > int(p.get("in_slots", 4)):
            p["in_slots"] = need
            n += 1
    return n


def apply(settings, buildings=None, recipes=None, items=None):
    settings["repair111"] = {"cost_k": 0.5, "time": 5.0}   # 1.1.17: 5 с (было 15)
    b = settings.setdefault("builders", {})
    b["ruins_when"] = "always"
    # 1.1.14: мир сетевой комнаты сохраняется раз в минуту (было 2 мин; на выделенном сервере 5)
    settings.setdefault("coop", {})["autosave_min"] = 1.0
    n = 2
    if buildings is not None:
        n += fix_slots(buildings, recipes, items)
    return n


def apply_1114(settings, skills):
    """1.1.14: авторемонт от «Инженерии» — бесплатный и медленный: % прочности в минуту по уровню навыка."""
    settings["auto_repair114"] = {"pct_per_min": [10, 20, 30, 40, 50]}   # 1.1.17: +10%/мин за уровень (было 2–6)
    sk = skills.get("engineering")
    if sk is not None:
        sk["desc"] = "+20% прочность зданий, авторемонт +10%/мин"
    return 2
