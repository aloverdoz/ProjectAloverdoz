"""1.4: деревья снова растут.
- Пень срубленного дерева сам становится тем же деревом через settings.tree_regrow секунд (world.gd: respawns с полем over).
- Саженцы (выпадают из деревьев при рубке): «Использовать» — посадить в свободную клетку земли перед героем.
  Ухаживать не нужно: через settings.sapling_grow секунд саженец становится деревом. Срубленный саженец возвращается в рюкзак."""

TREES = [("pine", "tree_pine", "Саженец сосны", "#2f6b3a"), ("fir", "tree_fir", "Саженец ели", "#2a5a34"),
         ("oak", "tree_oak", "Саженец дуба-яблони", "#4f8a2f"), ("birch", "tree_birch", "Саженец берёзы", "#7fb84a")]


def apply(items, resources, settings):
    settings["tree_regrow"] = 600.0
    settings["sapling_grow"] = 300.0
    n = 0
    for key, tree, name, col in TREES:
        if tree not in resources:
            continue
        sid, yid = "sapling_" + key, "young_" + key
        items[sid] = {"name": name, "desc": "Посадите в любую свободную клетку земли (кнопка «Использовать»). "
                      "Ухаживать не нужно — через несколько минут вырастет дерево.",
                      "color": col, "category": "Сырьё", "stack": 20, "price": 4, "model": "tr_sapling",
                      "plant": tree, "plant_young": yid, "keep_on_use": False, "use_sound": "build", "scan": 0}
        resources[yid] = {"name": "Молодое деревце", "model": "tr_sapling", "hp": 6, "tool": "",
                          "drops": [{"item": sid, "min": 1, "max": 1, "on": "break", "chance": 1.0}],
                          "category": "Кусты", "blocks": False, "stump": "", "respawn": 0, "scale": [0.55, 0.7], "xp": 0, "low": True}
        drops = resources[tree].setdefault("drops", [])
        if not any(d.get("item") == sid for d in drops):
            drops.append({"item": sid, "min": 1, "max": 1, "on": "break", "chance": 0.6})
        n += 1
    return n
