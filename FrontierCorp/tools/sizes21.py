"""Этап 21: здания крупнее героя. Машины занимают 2×2, крупные — 3×3 и 4×4; модель не пересобирается,
а увеличивается вместе с местом на карте (поле модели «scale»). Ленты, трубы, стены, станции энергии,
турели, сундуки и мелкий декор остаются прежними. Старый размер хранится в size0/scale0 (для старых проверок)."""

GROW = {
    # 1 → 2
    2: ["furnace", "smelter", "assembler", "smelter_mk2", "assembler_mk2", "packager", "centrifuge", "foundry",
        "constructor", "coke_oven", "crusher", "mixer", "arc_furnace", "clean_room", "crystal_cutter", "sawmill",
        "stone_cutter", "miner", "miner_mk2", "miner_mk3", "miner_mk4", "miner_mk5", "water_pump",
        "generator", "coal_generator", "biomass_burner", "wind_turbine", "battery_block",
        "container", "warehouse", "decon_station", "workshop", "kitchen", "tech_terminal",
        "research_lab", "drone_port", "recycler", "market", "builder_bay", "builder_bay_mk2", "drone_hub",
        "truck_depot", "truck_station", "repair_tower", "medbay", "wood_boiler"],
    # 2 → 3
    3: ["refinery", "chem_plant", "exotic_forge", "quantum_assembler", "manufacturer", "blast_furnace", "synthesizer",
        "fuel_generator", "geothermal", "resonance_reactor", "oil_pump", "gas_extractor", "magma_tap",
        "shield_dome", "radar_tower", "teleporter", "outpost"],
    # 3 → 4
    4: ["nuclear_reactor", "hq"],
}


def apply(buildings, models, settings):
    n = 0
    done_models = {}
    for new, ids in GROW.items():
        for bid in ids:
            b = buildings.get(bid)
            if not b:
                continue
            old = int(b.get("size", 1))
            if old >= new:
                continue
            k = new / old
            b["size0"] = old
            b["size"] = new
            mid = b.get("model", bid)
            m = models.get(mid)
            if m is not None and mid not in done_models:
                m["scale0"] = float(m.get("scale", 1.0))
                m["scale"] = round(float(m.get("scale", 1.0)) * k, 4)
                done_models[mid] = k
                # источники частиц и подписи стоят в координатах модели — двигаем вместе с ней
                for em in m.get("emitters", []):
                    if isinstance(em.get("pos"), list):
                        em["pos0"] = list(em["pos"])
                        em["pos"] = [round(v * k, 3) for v in em["pos"]]
                    if "size" in em:
                        em["size0"] = em["size"]
                        em["size"] = round(float(em["size"]) * k, 3)
            # радиусы, привязанные к зданию (свет, жар), растут вместе с ним
            pr = b.setdefault("params", {})
            if "wire_height" in pr:
                pr["wire_height"] = round(float(pr["wire_height"]) * k, 2)
            n += 1
    settings["big_buildings"] = True
    return n
