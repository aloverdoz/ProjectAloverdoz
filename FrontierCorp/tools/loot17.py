# 17.10: добыча с роботов. После переделки «только роботы» (14.11) ядро монстра, клык и сырое мясо
# перестали откуда-либо браться, а ядро нужно для бура Mk5, портала, открытия «Mk5» и заказа «Ядра».
# Здесь — откуда они берутся теперь. Всё правится в редакторе: «Враги» → «Добыча», «НПС» → «Товары».

CORE_BY_TIER = {"_t3": 0.05, "_t4": 0.12, "_t5": 0.25}


def apply(enemies, items):
    for eid, e in enemies.items():
        drops = e.setdefault("drops", [])
        have = {d.get("item") for d in drops}
        base = eid
        for suf in ("_t2", "_t3", "_t4", "_t5"):
            if eid.endswith(suf):
                base = eid[: -len(suf)]
        tier = eid[len(base):]
        # ядро: громилы и охранники Мк3–Мк5, все боссы (2–4 шт)
        if "monster_core" not in have:
            if e.get("boss"):
                drops.append({"item": "monster_core", "chance": 1.0, "min": 2, "max": 4, "on": "break"})
            elif base in ("brute", "guard") and tier in CORE_BY_TIER:
                drops.append({"item": "monster_core", "chance": CORE_BY_TIER[tier], "min": 1, "max": 1})
        # клык — режущий зуб шагохода-разведчика
        if base == "runner" and "fang" not in have:
            drops.append({"item": "fang", "chance": 0.3, "min": 1, "max": 2})
    if "fang" in items:
        items["fang"]["desc"] = "Заточенный резец с шагохода-разведчика. Пригодится для оружия."
    if "monster_core" in items:
        items["monster_core"]["desc"] = "Энергоядро крупного робота: громилы или охранника Мк3–Мк5, всегда — у босса осады."
    # мясо: роботы его не носят — его привозят торговец и путник
    for nid, price in (("trader", 4), ("traveler", 5)):
        g = enemies.get(nid, {}).get("goods")
        if isinstance(g, list) and not any(x.get("item") == "raw_meat" for x in g):
            g.append({"item": "raw_meat", "n": 10, "price": price})
        b = enemies.get(nid, {}).get("buys")
        if isinstance(b, list) and "raw_meat" in b:
            b.remove("raw_meat")
