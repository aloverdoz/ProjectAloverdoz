# Собирает каталог готового контента в папку catalog/: предметы, здания, растения и камни, их модели и рецепты.
# Каталог не попадает в игру сам: в редакторе «Каталог…» → «Добавить в игру» копирует объект (и всё, что ему нужно) в проект.
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

import cat_items, cat_items2, cat_build1, cat_build2, cat_plants

cat_items.build_metals(); cat_items.build_gems(); cat_items.build_electronics(); cat_items.build_chem()
cat_items2.build_all()
cat_build1.build_all()
cat_build2.build_all()
cat_plants.build_all()

core = {}
for t in ("items", "buildings", "resources", "models", "recipes"):
    core[t] = json.load(open(os.path.join(ROOT, "core", t + ".json"), encoding="utf-8"))

items = cat_items.items
models = dict(cat_items.models)
models.update(cat_build1.models)
models.update(cat_plants.models)
recipes = cat_items.recipes
buildings = cat_build1.buildings
resources = cat_plants.resources

# id не должны совпадать с основной игрой
for name, d in (("items", items), ("buildings", buildings), ("resources", resources), ("models", models), ("recipes", recipes)):
    clash = [k for k in d if k in core[name]]
    for k in clash:
        del d[k]
    if clash:
        print("skip (уже есть в игре) %s: %s" % (name, ", ".join(clash[:12]) + (" …" if len(clash) > 12 else "")))

all_items = set(items) | set(core["items"])
all_models = set(models) | set(core["models"])
missing = {}


def need(kind, ref, where):
    pool = all_items if kind == "item" else all_models
    if ref and ref not in pool:
        missing.setdefault(ref, []).append(where)


for k, v in items.items():
    need("model", v["model"], "item " + k)
for k, v in recipes.items():
    for i in list(v["in"]) + list(v["out"]):
        need("item", i, "recipe " + k)
for k, v in buildings.items():
    need("model", v["model"], "building " + k)
    for i in v["cost"]:
        need("item", i, "building " + k)
    for b in v.get("blocks", []):
        for key in ("item",):
            if key in b:
                need("item", b[key], "building block " + k)
        for key in ("in", "out"):
            for i in b.get(key, {}):
                need("item", i, "building block " + k)
    for f in v["params"].get("fuels", []):
        need("item", f, "building fuel " + k)
for k, v in resources.items():
    need("model", v["model"], "resource " + k)
    for d in v["drops"]:
        need("item", d["item"], "resource " + k)

if missing:
    print("MISSING %d:" % len(missing))
    for ref, where in sorted(missing.items()):
        print("  %s  ← %s" % (ref, ", ".join(where[:3])))
    sys.exit(1)

# ресурсам-деревьям нужен пень из основной игры
for k, v in resources.items():
    if v["stump"] and v["stump"] not in core["resources"] and v["stump"] not in resources:
        v["stump"] = ""

# звуки работы: у каждого рабочего здания свой (плавка, бур, пила…)
import work_sounds
work_sounds.assign(buildings)

# детализация: рабочие здания получают обвес до 300+ деталей (см. detail_pass.py)
import detail_pass
_done = set()
for k, v in buildings.items():
    mid = v["model"]
    if mid in models and mid not in _done:
        _done.add(mid)
        detail_pass.enrich(models[mid], v.get("behavior", ""), int(v.get("size", 1)), bool(v.get("blocks")))

import plant_pass
for _i, (k, v) in enumerate(resources.items()):
    mid = v["model"]
    if mid in models and mid not in _done:
        _done.add(mid)
        plant_pass.enrich_plant(models[mid], v.get("category", ""), _i + 1)

out = os.path.join(ROOT, "catalog")
os.makedirs(out, exist_ok=True)
for name, d in (("items", items), ("buildings", buildings), ("resources", resources), ("models", models), ("recipes", recipes)):
    with open(os.path.join(out, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=0, sort_keys=True)
parts = sum(len(m["parts"]) for m in models.values())
print("catalog: items=%d buildings=%d resources=%d models=%d recipes=%d parts=%d" % (len(items), len(buildings), len(resources), len(models), len(recipes), parts))
