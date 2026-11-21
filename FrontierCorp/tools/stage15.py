# 15: исследования по этапам, объединение по технологиям, энергия составных, туман 5×5, мощность 0–100%.
# Вызывается из gen_core.py после steam_data. Всё правится в редакторе («Правила игры»).

TIER_NAMES = ["Начало", "Этап 1 · Освоение", "Этап 2 · Автоматизация", "Этап 3 · Промышленность", "Этап 4 · Энергетика",
              "Этап 5 · Химия и атом", "Этап 6 · Высокие технологии", "Этап 7 · Орбита", "Этап 8 · Экзотика", "Этап 9 · Звёзды"]


def apply(models, buildings, items, recipes, settings, world, tech):
    settings["power_constant"] = True
    settings.setdefault("zone", {}).update({"patches": True, "patch_blocks": 3, "patch_cost_k": 0.6})
    settings["power_clock"] = True
    settings["tech_ui"] = {"free": True, "tier_names": [{"name": n} for n in TIER_NAMES]}


def apply_fusion_tech(settings, tech):
    """15.2: объединять можно только после технологий. Уровень 2 (и составное из 2 зданий) — первичное, 3 — вторичное…"""
    def TN(id, name, tier, order, icon, desc, cost, requires, research=0):
        tech[id] = {"name": name, "tier": tier, "order": order, "icon": icon, "desc": desc, "cost": cost,
                    "unlocks": {}, "requires": requires, "research": research}
    TN("t_fuse1", "Первичное объединение", 1, 5, "assembler",
       "Объединение 1: два одинаковых здания рядом → одно, вдвое сильнее (уровень 2). Можно встроить одно здание в другое (составное из 2).",
       {"iron_ingot": 25, "gear": 8}, ["t_workshop"])
    TN("t_fuse2", "Вторичное объединение", 2, 7, "assembler",
       "Объединение 2: уровень 3 и составные здания из 3 частей.", {"iron_plate": 30, "gear": 20, "wire": 20}, ["t_fuse1", "t_power"], 5)
    TN("t_fuse3", "Третичное объединение", 3, 7, "assembler",
       "Объединение 3: уровень 4 и составные здания из 4 частей.", {"steel": 30, "circuit": 15, "motor": 4}, ["t_fuse2", "t_mk2"], 15)
    TN("t_fuse4", "Высшее объединение", 5, 4, "assembler",
       "Объединение 4: уровень 5 и составные здания из 5 частей.", {"steel": 60, "circuit": 30, "battery": 6}, ["t_fuse3"], 40)
    settings.setdefault("fusion", {})["techs"] = ["t_fuse1", "t_fuse2", "t_fuse3", "t_fuse4"]


def apply_deposits(world):
    """15.5: залежи, которые открывает технология, — одна в стартовой зоне и пара сразу за ней."""
    ring = {"saltpeter": (1, 2), "alunite": (0, 2), "uranium_ore": (0, 1), "oil": (0, 1), "sulfur": (1, 1), "quartz": (1, 1)}
    for d in world.get("deposits", []):
        if d.get("item") in ring:
            ns, nr = ring[d["item"]]
            d["near_start"] = max(int(d.get("near_start", 0)), ns)
            d["near_ring"] = nr
            d["ring_width"] = 12.0
