"""1.3: бур 3×3 — залежь руды под ним тоже 3×3 (World.dep_fp берёт размер бура), бур встаёт ровно по центру залежи.
Остальные машины чуть крупнее в своём месте, герой чуть выше, камни и метеориты не больше клетки-двух.
Для сохранений до 1.3 бур остаётся 2×2 (size12/scale12, main._apply_sizes)."""

MINERS = []                # 1.3 (25.10): бур и залежь снова 2×2 — по просьбе игрока
MINER_SCALE = 2.7          # модель бура в месте 3×3 (по краям видно залежь)
MACHINE_K = 1.08           # прочие машины 2×2: модель чуть крупнее, в том же месте
HERO_K = 1.12              # герои: 1.25 → 1.4
RES_SCALE = {               # [мин, макс] случайного размера камней (модели ~2–3 м, клетка 2 м)
    "rock_small": [0.55, 0.85], "rock_big": [0.55, 0.8],
    "ore_iron": [0.5, 0.72], "ore_copper": [0.5, 0.7], "ore_coal": [0.5, 0.72], "ore_quartz": [0.5, 0.72], "ore_sulfur": [0.55, 0.8],
    "meteorite": [0.5, 0.68],
}


def apply(buildings, models, settings, resources):
    n = 0
    done = set()
    for bid in MINERS:
        b = buildings.get(bid)
        if not b:
            continue
        b["size12"] = int(b.get("size", 2))
        b["size"] = 3
        b.setdefault("size0", 1)
        mid = b.get("model", bid)
        m = models.get(mid)
        if m is not None and mid not in done:
            m.setdefault("scale0", 1.0)
            k = MINER_SCALE / float(m.get("scale", 2.0))
            m["scale12"] = float(m.get("scale", 2.0))
            m["scale"] = MINER_SCALE
            for em in m.get("emitters", []):
                if isinstance(em.get("pos"), list):
                    em["pos"] = [round(v * k, 3) for v in em["pos"]]
            done.add(mid)
        n += 1
    for bid, b in buildings.items():
        if bid in MINERS or int(b.get("size", 1)) != 2 or int(b.get("size0", 2)) != 1:
            continue
        mid = b.get("model", bid)
        m = models.get(mid)
        if m is None or mid in done or "scale0" not in m:
            continue
        m["scale"] = round(float(m["scale"]) * MACHINE_K, 4)
        for em in m.get("emitters", []):
            if isinstance(em.get("pos"), list):
                em["pos"] = [round(v * MACHINE_K, 3) for v in em["pos"]]
        done.add(mid)
        n += 1
    for mid, m in models.items():
        if mid.startswith("hero") and (m.get("skin") or m.get("bones") or mid == "hero"):
            m["scale"] = round(float(m.get("scale", 1.25)) * HERO_K, 4)
    for rid, sc in RES_SCALE.items():
        if rid in resources:
            resources[rid]["scale"] = sc
    settings["hero_glb_scale"] = round(1.25 * HERO_K, 3)
    return n
