"""Этап 20: модели из Blender (tools/import20.gd пишет models20/<id>/model.json).
Заменяет детали моделей на готовые меши с текстурой, остальное (частицы, риг, категория) не трогает."""
import json, os


def _bone(n):
    # импорт GLB в Godot меняет «:» в именах узлов на «_» — возвращаем игровое «b:кость»
    return "b:" + n[2:] if isinstance(n, str) and n.startswith("b_") else n

def _bones_deep(v):
    if isinstance(v, dict):
        return {k: _bones_deep(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_bones_deep(x) for x in v]
    return _bone(v)


ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def apply(models):
    base = os.path.join(ROOT, "models20")
    n = 0
    if not os.path.isdir(base):
        return n
    for mid in sorted(os.listdir(base)):
        p = os.path.join(base, mid, "model.json")
        if not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        m = models.setdefault(mid, {"name": mid, "category": "Модели"})
        # полотно ленты (бегущий шейдер) и окошко цвета жидкости остаются прежними деталями движка
        keep = [q for q in m.get("parts", []) if q.get("mat") == "belt" or q.get("role") == "fluid_color"]
        parts = data["parts"]
        for q in parts:
            # листва, травинки и лепестки — одна плоскость: рисуем с обеих сторон
            if str(q.get("anim", "")).startswith("sway"):
                q["two_sided"] = True
        m["parts"] = keep + parts
        for k in ("glb", "glb_pos", "glb_raw", "scale"):
            m.pop(k, None)
        for k, v in data.get("extra", {}).items():
            m[k] = v
        for q in m["parts"]:
            if "role" in q:
                q["role"] = _bone(q["role"])
        if "rig" in m:
            m["rig"] = _bones_deep(m["rig"])
        n += 1
    return n
