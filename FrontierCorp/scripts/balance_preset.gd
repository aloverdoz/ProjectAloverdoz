extends RefCounted

const FILE := "balance.frontier.json"
const TABLES := ["items", "buildings", "recipes", "tech", "contracts", "settings", "world", "levels"]

static func capture(data: Dictionary) -> Dictionary:
	var tables := {}
	for table in TABLES:
		tables[table] = data[table].duplicate(true)
	return {"schema": 1, "tables": tables}


static func quantities(value, items: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if not items.has(key) or typeof(value[key]) not in [TYPE_FLOAT, TYPE_INT] or float(value[key]) < 0:
			return false
	return true


static func issue(preset) -> String:
	if not preset is Dictionary or preset.get("schema") != 1 or not preset.get("tables") is Dictionary:
		return "Неподдерживаемая версия или структура пресета"
	var tables: Dictionary = preset.tables
	for table in TABLES:
		if not tables.get(table) is Dictionary or tables[table].is_empty():
			return "Отсутствует таблица " + table
	for table in ["items", "buildings", "recipes", "tech", "contracts"]:
		for id in tables[table]:
			if not tables[table][id] is Dictionary:
				return "%s/%s ожидает объект" % [table, id]
	for id in tables.buildings:
		var b: Dictionary = tables.buildings[id]
		if not quantities(b.get("cost", {}), tables.items) or not b.get("params", {}) is Dictionary:
			return "Ошибка параметров или стоимости постройки " + id
	for id in tables.recipes:
		var r: Dictionary = tables.recipes[id]
		if not quantities(r.get("in", {}), tables.items) or not quantities(r.get("out", {}), tables.items) or float(r.get("time", 1)) <= 0:
			return "Ошибка ингредиентов, результата или времени рецепта " + id
	for id in tables.tech:
		var n: Dictionary = tables.tech[id]
		if not quantities(n.get("cost", {}), tables.items) or not n.get("requires", []) is Array or not n.get("unlocks", {}) is Dictionary:
			return "Ошибка исследования " + id
		for parent in n.get("requires", []):
			if not tables.tech.has(parent):
				return "Неизвестная зависимость исследования " + str(parent)
		for section in ["recipes", "buildings"]:
			for entry in n.get("unlocks", {}).get(section, []):
				if not tables[section].has(entry):
					return "%s ссылается на отсутствующий объект %s" % [id, entry]
	var capacities = tables.settings.get("cargo_capacities")
	if not capacities is Array or capacities.size() != 5 or capacities.any(func(n): return typeof(n) not in [TYPE_FLOAT, TYPE_INT] or n < 1 or n != floor(n)):
		return "Укажите пять целых положительных вместимостей грузовых дронов"
	return ""


static func write_text(path: String, content: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(content)
	f.flush()
	return f.get_error()


static func deploy(directory: String, preset: Dictionary) -> String:
	var problem := issue(preset)
	if problem != "":
		return problem
	var dir := DirAccess.open(directory)
	if dir == null:
		return "Папка недоступна"
	if not dir.file_exists("project.godot") and not dir.file_exists("FrontierCorp.exe") and not dir.file_exists("Game.exe"):
		return "Выберите папку проекта Godot или игры Frontier Corp"
	var temp := FILE + ".tmp-" + str(Time.get_ticks_usec())
	var path := directory.path_join(temp)
	if write_text(path, JSON.stringify(preset, "\t")) != OK:
		return "Ошибка записи пресета"
	if issue(JSON.parse_string(FileAccess.get_file_as_string(path))) != "":
		dir.remove(temp)
		return "Проверка записанных данных не прошла"
	var backup := ""
	if dir.file_exists(FILE):
		backup = FILE + "." + str(Time.get_unix_time_from_system()).replace(".", "-") + ".bak"
		if dir.copy(directory.path_join(FILE), directory.path_join(backup)) != OK:
			dir.remove(temp)
			return "Не удалось создать резервную копию"
	if dir.rename(temp, FILE) != OK:
		dir.remove(temp)
		return "Не удалось применить пресет"
	return ""


static func prompt(preset: Dictionary) -> String:
	var sections := PackedStringArray(["Frontier Corp · настройки баланса", "Версия схемы 1", "Предложи изменения для указанного ниже баланса. Укажи изменённые значения, связанные рецепты и влияние на прогрессию."])
	for table in TABLES:
		sections.append("%s\n%s" % [DB.TYPE_NAMES.get(table, table), JSON.stringify(preset.tables[table], "\t")])
	return "\n\n".join(sections)
