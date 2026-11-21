"""Этап 21: квантовое измерение (поздняя игра после атома). Логика — scripts/quantum21.gd."""
import copy


def _model(models, mid, like):
    if mid not in models and like in models:
        models[mid] = copy.deepcopy(models[like])   # своя модель приходит из models20 (art20)
        models[mid]["name"] = mid


def apply(buildings, items, tech, enemies, world, settings, models):
    items["q_superposition"] = {
        "name": "Суперпозиция", "desc": "Квантовая жила, на которую ещё никто не смотрел: она одновременно всё и ничто. "
        "Подойдите и посмотрите — она выберет, чем стать.", "color": "#b98cff", "category": "Экзотика", "stack": 50,
        "price": 0, "model": "drop_crystal", "scan": 0, "exotic": True}
    items["quantum_shard"] = {
        "name": "Квантовый осколок", "desc": "Остаётся от квантовой тени. Нужен для запутанных построек и чтобы вернуть жилу в суперпозицию.",
        "color": "#d6b8ff", "category": "Экзотика", "stack": 100, "price": 900, "model": "drop_crystal", "scan": 0, "exotic": True}
    # жила без пятен на карте: её создаёт портал
    deps = world.setdefault("deposits", [])
    if not any(d.get("item") == "q_superposition" for d in deps):
        deps.append({"resource": "", "item": "q_superposition", "color": "#b98cff", "patches": 0, "size_min": 1.0, "size_max": 1.0,
                     "near_start": 0, "drops": [], "cells": 2, "hand": False, "hand_hp": 25.0, "hand_tool": "pickaxe",
                     "rocks_around": 0, "marker": "dep_magma", "miner_tier": 4})

    _model(models, "quantum_portal", "teleporter")
    buildings["quantum_portal"] = {
        "name": "Квантовый портал", "category": "special", "behavior": "decor", "model": "quantum_portal", "hp": 2500, "size": 3,
        "desc": "Открывает квантовое измерение (нужна энергия): вокруг появляются квантовые жилы — пока на жилу не смотрят, "
                "она в суперпозиции; посмотрите вблизи — схлопнется в редкое сырьё. Приходят квантовые тени: двигаются, "
                "только пока на них не смотрят. Из теней — квантовые осколки для запутанных построек.",
        "cost": {"steel": 120, "circuit": 80, "superconductor": 20, "enriched_uranium": 10, "crystal": 20},
        "params": {"quantum_portal": True, "power": 300}, "sounds": {"work": "work_reactor"}}
    _model(models, "entangled_chest", "chest_iron")
    buildings["entangled_chest"] = {
        "name": "Запутанный ящик", "category": "storage", "behavior": "storage", "model": "entangled_chest", "hp": 400, "size": 1,
        "desc": "Ставятся парой: два запутанных ящика делят одно содержимое, как бы далеко ни стояли. Положили в один — "
                "сразу можно взять из другого (и с ленты, и на ленту).",
        "cost": {"steel": 6, "quantum_shard": 2, "circuit": 10},
        "params": {"slots": 30, "entangled": True}, "sounds": {}}
    _model(models, "entangled_pole", "pole_mk3")
    pole = copy.deepcopy(buildings.get("pole_mk3", {}))
    pole.update({
        "name": "Запутанная станция энергии", "model": "entangled_pole", "hp": 400,
        "desc": "Ставятся парой: две запутанные станции — одна сеть через всю карту, без цепочки станций между ними. "
                "Каждая отдаёт до 250 энергии зданиям в радиусе 5 клеток.",
        "cost": {"steel": 10, "circuit": 8, "quantum_shard": 2}})
    pole.setdefault("params", {})
    pole["params"] = dict(pole["params"], entangled=True, upgrade_of="entangled_pole")
    buildings["entangled_pole"] = pole

    # квантовая тень: двигается, пока на неё не смотрят
    base = copy.deepcopy(enemies.get("runner_t4") or enemies.get("runner") or {})
    base.update({"name": "Квантовая тень", "hp": 260, "damage": 28.0, "speed": 11.0, "reward": 60, "xp": 20,
                 "spawn_weight": 0.0, "quantum": True, "tint": "#a070ff", "tint_k": 0.85,
                 "drops": [{"item": "quantum_shard", "chance": 1.0, "min": 1, "max": 2}]})
    enemies["q_shade"] = base

    tech["t_quantum"] = {
        "name": "Квантовое измерение", "tier": 7, "order": 3, "icon": "quantum_portal",
        "desc": "Квантовый портал: жилы в суперпозиции (схлопываются, когда на них смотрят), запутанные ящики и станции, "
                "квантовые тени.",
        "cost": {"enriched_uranium": 20, "superconductor": 30, "circuit": 150},
        "unlocks": {"buildings": ["quantum_portal", "entangled_chest", "entangled_pole"]},
        "requires": ["t_nuclear", "t_mk5"], "credits": 6000, "research": 180}

    settings["quantum"] = {
        "veins": 6, "vein_min": 14, "vein_max": 60, "vein_color": "#b98cff", "observe_dist": 16,
        "outcomes": [{"item": "void_crystal", "w": 3}, {"item": "superconductor", "w": 3}, {"item": "helium3", "w": 2},
                     {"item": "stellar_alloy", "w": 1}, {"item": "crystal", "w": 4}, {"item": "uranium_ore", "w": 3}],
        "reset_cost": {"quantum_shard": 1},
        "shade": "q_shade", "shade_every": 45.0, "shade_max": 4, "shade_night_only": False, "see_dist": 70.0, "unseen_k": 1.0}
    return 3
