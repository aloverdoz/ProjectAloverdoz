# Версия 1.1.19 (08.11): все залежи видны сразу (узлы их больше не открывают); у штаба — только железо, медь и камень,
# каждой остальной залежи — по 2 сразу за стартовой зоной (развитие не упрётся в «нет нужной руды»), залежей в мире в 1,5 раза больше.
# Стартовая зона 15×15 блоков. Канал штаба — всегда 20 энергии. Вызывается из gen_core.py после v1118.

BASE = ["iron_ore", "copper_ore", "stone"]


def apply(settings, world, tech, buildings):
    old = {}
    for tid, node in tech.items():
        u = node.get("unlocks", {})
        if u.get("deposits"):
            pre = [d for d in u["deposits"] if d not in settings.get("dep118", {}).get(tid, [])]
            if pre:
                old[tid] = pre
            u.pop("deposits")
    settings["dep119_old"] = old   # старые проверки (main._legacy_115) — с прежними закрытыми залежами
    settings["dep118"] = {}
    world["start_base"] = list(BASE)
    world["start_ring"] = 2
    pold = {}
    for d in world.get("deposits", []):
        if int(d.get("patches", 0)) > 0:
            pold[d.get("item")] = d["patches"]
            d["patches"] = int(round(int(d["patches"]) * 1.5))
    settings["patches119_old"] = pold
    settings.setdefault("zone", {})["start_blocks"] = 15
    lk = settings.setdefault("hq_link115", {})
    lk["power_min"] = 20.0
    lk["power_per_cell"] = 0.0
    if "hq_link" in buildings:
        buildings["hq_link"]["desc"] = buildings["hq_link"]["desc"].replace("Энергия: клеток до штаба × 2.", "Энергия: 20.")
    if "t_coal" in tech:
        tech["t_coal"]["desc"] = "Угольный генератор и сталь. Сталь варится в Плавильне (нужна энергия) из железных слитков и угля."
    return len(old)
