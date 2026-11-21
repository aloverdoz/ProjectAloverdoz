"""1.3: живой фон главного меню (scripts/menu_scene.gd) — пункт в настройках графики и флаг меню."""


def apply(options, menu):
    for sec in options.get("sections", []):
        if sec.get("id") == "graphics" and not any(it.get("key") == "menu_live" for it in sec["items"]):
            sec["items"].append({"key": "menu_live", "name": "Живой фон главного меню (3D-база вместо картинки)",
                                 "type": "check", "default": True})
        if sec.get("id") == "game":
            # 1.1.20 A18-5: «база второго игрока» так и не заработала — пункт убран (второй игрок всегда на общей базе)
            sec["items"] = [it for it in sec["items"] if it.get("key") != "split_base"]
    menu.setdefault("bg_live", True)
    # 1.3: кнопка «Герой» (выбор модели игрока) — после «Новая игра»
    bt = menu.get("buttons", [])
    if bt and not any(b.get("id") == "hero" for b in bt):
        at = next((i + 1 for i, b in enumerate(bt) if b.get("id") == "new"), len(bt))
        bt.insert(at, {"id": "hero", "text": "", "show": True})
    return 1
