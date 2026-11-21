# Какой звук работы у здания по умолчанию (поле «Звуки → Работа» в редакторе можно поменять у любого здания).
SOUNDS = {
    "work_smelt": "Работа: плавка в печи", "work_drill": "Работа: бур", "work_saw": "Работа: пила",
    "work_press": "Работа: пресс", "work_crush": "Работа: дробилка", "work_assembly": "Работа: сборка, станки",
    "work_electric": "Работа: электричество, гул", "work_bubble": "Работа: химия, бульканье", "work_cook": "Работа: кухня",
    "work_loom": "Работа: ткацкий станок", "work_engine": "Работа: двигатель на топливе", "work_turbine": "Работа: турбина",
    "work_wind": "Работа: ветряк", "work_water": "Работа: вода, мельница", "work_reactor": "Работа: реактор",
    "work_pump": "Работа: насос", "work_burner": "Работа: огонь, дрова", "work_lab": "Работа: лаборатория, приборы",
}

KEYS = [  # подстрока в id здания или станции -> звук
    ("kitchen", "work_cook"), ("cook", "work_cook"), ("loom", "work_loom"), ("textile", "work_loom"),
    ("saw", "work_saw"), ("lumber", "work_saw"), ("crush", "work_crush"), ("grind", "work_crush"), ("compactor", "work_press"),
    ("press", "work_press"), ("smelt", "work_smelt"), ("furnace", "work_smelt"), ("foundry", "work_smelt"), ("kiln", "work_smelt"),
    ("chem", "work_bubble"), ("refin", "work_bubble"), ("distil", "work_bubble"), ("bio", "work_bubble"), ("mixer", "work_bubble"),
    ("purif", "work_bubble"), ("electro", "work_electric"), ("crystal", "work_electric"), ("centrifuge", "work_turbine"),
    ("research", "work_lab"), ("lab", "work_lab"), ("terminal", "work_lab"), ("medbay", "work_lab"),
    ("pump", "work_pump"), ("well", "work_pump"), ("tesla", "work_electric"), ("teleport", "work_reactor"), ("portal", "work_reactor"),
    ("drone", "work_electric"), ("truck", "work_engine"), ("rover", "work_engine"), ("recycler", "work_crush"),
    ("boiler", "work_burner"), ("beacon", "work_electric"), ("radar", "work_electric"),
]


def work_sound(bid, b):
    """Звук работы для здания bid с данными b (или "" — без звука)."""
    beh = b.get("behavior", "")
    p = b.get("params", {})
    st = str(p.get("station", ""))
    if beh in ("belt", "pipe", "pole", "wall", "foundation", "floor", "splitter", "merger", "storage", "tank", "light", "turret"):
        return ""
    if beh == "generator":
        if p.get("solar"):
            return "work_electric"
        if p.get("wind"):
            return "work_wind"
        if p.get("water") or "water" in bid or "mill" in bid:
            return "work_water"
        if any(k in bid for k in ("nuclear", "fusion", "reactor")):
            return "work_reactor"
        if any(k in bid for k in ("turbine", "gas", "hydrogen")):
            return "work_turbine"
        if any(k in bid for k in ("bio", "stove", "wood", "burner")):
            return "work_burner"
        if "geo" in bid:
            return "work_bubble"
        return "work_engine"
    if beh == "battery":
        return "work_electric"
    if beh == "miner":
        return "work_pump" if any(k in bid for k in ("pump", "well", "oil", "water")) else "work_drill"
    for k, s in KEYS:
        if k in bid or k in st:
            return s
    if beh == "crafter":
        return "work_assembly"
    if beh in ("station", "terminal", "hq"):
        return "work_lab" if beh != "station" else "work_assembly"
    return ""


def assign(buildings):
    for bid, b in buildings.items():
        s = b.setdefault("sounds", {})
        if not s.get("work"):
            w = work_sound(bid, b)
            if w:
                s["work"] = w
