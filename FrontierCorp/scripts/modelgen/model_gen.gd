class_name ModelGen
extends RefCounted
## 15.7: генератор моделей по описанию. Пишете по-русски (или по-английски): «огромный ржавый паук-робот
## с восемью ногами, пушкой на спине и красными глазами» — генератор:
##  1) разбирает описание: что это (насекомое, зверь, шагоход, змей, дрон, герой, здание…), сколько ног и глаз,
##     цвета, материал (металл, камень, живая кожа, кристалл), размер, детали (рога, шипы, хвост, клешни, крылья,
##     пушка, антенны, бур, трубы, баки, винты, панели);
##  2) «лепит» каждую часть тела из гладких форм (SdfMesh): панцирь с пазами между пластинами, болты, вентиляционные
##     щели, поршни в суставах, шланги, когти, светящиеся глаза; в цвета запекается тень в складках и потёртости;
##  3) сам ставит скелет (кости, ноги, суставы, хвост, челюсти, винты, колёса) — анимации ходьбы, удара,
##     дыхания, смерти берёт система скелета игры; у героя — ходьба, удар, добыча; у зданий — простой и работа
##     (вращение, поршни, свечение, дым).
## Одно и то же описание с другим «зерном» даёт другой вариант. Качество: 0 — быстро, 1 — хорошо, 2 — очень подробно.

const ARCH_NAMES := {"bug": "насекомое / паук", "beast": "зверь на 4 лапах", "walker": "шагоход на 2 ногах", "serpent": "змей / червь",
	"drone": "дрон / летун", "hero": "герой", "building": "здание / машина", "turret": "турель", "rock": "камень / кристалл"}

# ---------------------------------------------------------------- словарь описаний

const COLORS := {
	"красн": "#c8392b", "алый": "#e0362a", "бордов": "#7a1f26", "оранж": "#e07a24", "жёлт": "#e6c234", "желт": "#e6c234",
	"золот": "#d9a83a", "зелён": "#4b9a45", "зелен": "#4b9a45", "изумруд": "#1f9e6a", "салатов": "#8dc63f", "болотн": "#5b6b34",
	"голуб": "#58b3e0", "син": "#2f5fbf", "бирюз": "#2bb5a8", "фиолет": "#7d4bc0", "пурпур": "#9b2f9e", "розов": "#e07aa8",
	"бел": "#e8e8e4", "чёрн": "#222428", "черн": "#222428", "сер": "#7d8288", "коричн": "#6e4a2f", "медн": "#b8693c",
	"бронз": "#a87a3c", "стальн": "#8a929c", "серебр": "#c4cad0", "ржав": "#8e4a26", "кост": "#d8cfb4", "песочн": "#c9ad7a",
	"red": "#c8392b", "orange": "#e07a24", "yellow": "#e6c234", "gold": "#d9a83a", "green": "#4b9a45", "blue": "#2f5fbf",
	"cyan": "#58b3e0", "purple": "#7d4bc0", "pink": "#e07aa8", "white": "#e8e8e4", "black": "#222428", "grey": "#7d8288",
	"gray": "#7d8288", "brown": "#6e4a2f", "copper": "#b8693c", "bronze": "#a87a3c", "steel": "#8a929c", "silver": "#c4cad0", "rust": "#8e4a26",
}
const NUMS := {"один": 1, "одн": 1, "два": 2, "две": 2, "двух": 2, "три": 3, "трёх": 3, "трех": 3, "четыр": 4, "пят": 5, "шест": 6,
	"сем": 7, "восем": 8, "десят": 10, "дюжин": 12, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "eight": 8, "ten": 10}

const ARCH_WORDS := [
	["hero", ["герой", "инженер", "персонаж", "игрок", "hero", "player", "человек", "космонавт", "солдат"]],
	["turret", ["турел", "пушка-башн", "turret", "орудийн"]],
	["building", ["здани", "завод", "фабрик", "печь", "плавильн", "бур ", "буров", "шахт", "сборщик", "станок", "склад", "сундук",
		"генератор", "электростан", "ветряк", "турбин", "реактор", "башн", "вышк", "насос", "бак ", "цистерн", "лаборатор",
		"building", "factory", "furnace", "drill", "generator", "tower", "pump", "tank", "machine", "машин", "мастерск", "верстак"]],
	["serpent", ["змей", "змея", "червь", "черв", "сороконож", "многоножк", "угорь", "serpent", "snake", "worm"]],
	["drone", ["дрон", "летающ", "летун", "квадрокоптер", "вертолёт", "вертолет", "птиц", "оса", "муха", "стрекоз", "drone", "flying", "bird", "wasp"]],
	["bug", ["паук", "жук", "муравей", "насеком", "скорпион", "краб", "клещ", "богомол", "таракан", "spider", "beetle", "insect", "crab", "scorpion", "ant", "mantis"]],
	["walker", ["шагоход", "гуманоид", "голем", "титан", "мех ", "меха", "двуног", "walker", "mech", "golem", "titan", "robot", "робот"]],
	["beast", ["зверь", "волк", "пёс", "пес", "собак", "кошк", "тигр", "медвед", "ящер", "носорог", "кабан", "конь", "четвероног", "beast", "wolf", "dog", "lizard", "bear", "boar", "rhino"]],
	["rock", ["камень", "кристалл", "глыба", "валун", "руда", "rock", "crystal", "ore", "boulder"]],
]

const FEATURES := {
	"horns": ["рог", "horn"], "spikes": ["шип", "игл", "spike", "thorn"], "tail": ["хвост", "tail"], "stinger": ["жал", "sting"],
	"claws": ["клешн", "claw", "pincer"], "mandibles": ["жвал", "челюст", "mandible", "jaw", "пасть"], "wings": ["крыл", "wing"],
	"cannon": ["пушк", "орудие", "ствол", "пулемёт", "пулемет", "лазер", "cannon", "gun", "laser"], "rockets": ["ракет", "rocket", "missile"],
	"antennae": ["антенн", "ус", "antenna"], "armor": ["брон", "панцир", "armor", "armour", "plated"], "shield": ["щит", "shield"],
	"drill": ["бур", "сверл", "drill"], "saw": ["пила", "пилы", "saw"], "wheels": ["колёс", "колес", "wheel"], "tracks": ["гусениц", "track"],
	"rotors": ["винт", "пропеллер", "лопаст", "rotor", "propeller"], "pipes": ["труб", "шланг", "pipe", "hose"], "tanks": ["бак", "баллон", "цистерн", "tank"],
	"lights": ["лампа", "фонар", "прожектор", "light", "lamp"], "panels": ["панел", "солнечн", "panel", "solar"], "chimney": ["дымоход", "труба печ", "chimney", "дым"],
	"crystals": ["кристалл", "crystal"], "eyes_many": ["много глаз", "многоглаз", "many eyes"], "glow": ["светящ", "сияющ", "неон", "glow", "neon"],
	"fur": ["шерст", "мех", "fur"], "slime": ["слиз", "slime"], "backpack": ["рюкзак", "ранец", "backpack"], "visor": ["визор", "шлем", "visor", "helmet"],
}


## Разобрать описание. kind — подсказка («монстр», «герой», «здание»), если в тексте не сказано.
static func parse(desc: String, kind := "") -> Dictionary:
	var t := " " + desc.to_lower().replace("ё", "е") + " "
	var tk := t + " " + kind.to_lower()
	var spec := {"desc": desc, "arch": "", "legs": -1, "eyes": -1, "colors": [], "mech": true, "size": 1.0, "feat": {}, "mat": "metal", "glow": "#ffb238"}
	for aw in ARCH_WORDS:
		for w in aw[1]:
			if tk.find(w.replace("ё", "е")) >= 0:
				spec.arch = aw[0]
				break
		if spec.arch != "":
			break
	if spec.arch == "":
		spec.arch = "building" if kind.find("здан") >= 0 or kind == "building" else "bug"
	# цвета по порядку упоминания: первый — основной, второй — акцент
	var found := []
	for w in COLORS:
		var i := t.find(w.replace("ё", "е"))
		if i >= 0:
			found.append([i, COLORS[w]])
	found.sort_custom(func(a, b): return a[0] < b[0])
	for f in found:
		if not f[1] in spec.colors:
			spec.colors.append(f[1])
	# «красными глазами», «синим светом» — цвет свечения
	for w in COLORS:
		var ww: String = w.replace("ё", "е")
		for g in ["глаз", "свет", "сия", "огн", "eyes", "glow"]:
			var gi := t.find(g)
			var ci := t.find(ww)
			if gi >= 0 and ci >= 0 and absi(gi - ci) < 14:
				spec.glow = COLORS[w]
	# числа: «восемь ног», «8 лап», «три глаза»
	var re := RegEx.new()
	re.compile("(\\d+|[a-zа-я]+)[ -]*(ног|лап|ноги|лапы|legs?|глаз|eyes?)")
	for m in re.search_all(t):
		var n := _num(m.get_string(1))
		if n <= 0:
			continue
		if m.get_string(2).begins_with("глаз") or m.get_string(2).begins_with("eye"):
			spec.eyes = n
		else:
			spec.legs = n
	if t.find("шестиног") >= 0:
		spec.legs = 6
	if t.find("восьминог") >= 0:
		spec.legs = 8
	if t.find("четвероног") >= 0:
		spec.legs = 4
	if t.find("двуног") >= 0:
		spec.legs = 2
	# материал и стиль
	if _any(t, ["живой", "живая", "органич", "плоть", "кож", "организм", "organic", "flesh", "зверь", "biolog", "слиз", "шерст"]):
		spec.mech = false
		spec.mat = "flesh"
	if _any(t, ["робот", "механ", "металл", "стальн", "железн", "robot", "mech", "metal"]):
		spec.mech = true
		spec.mat = "metal"
	if _any(t, ["камен", "stone", "гранит"]):
		spec.mat = "stone"
	if _any(t, ["кристалл", "crystal", "стеклян"]):
		spec.mat = "crystal"
	if _any(t, ["ржав", "rust", "стар", "old"]):
		spec["rusty"] = true
	if _any(t, ["футурист", "sci-fi", "гладк", "футуристич", "sleek"]):
		spec["sleek"] = true
	# размер
	if _any(t, ["крошечн", "tiny"]):
		spec.size = 0.55
	elif _any(t, ["маленьк", "small", "мелк"]):
		spec.size = 0.75
	elif _any(t, ["гигантск", "колоссальн", "giant", "huge", "огромн"]):
		spec.size = 1.9
	elif _any(t, ["больш", "крупн", "big", "large"]):
		spec.size = 1.35
	for f in FEATURES:
		for w in FEATURES[f]:
			if t.find(w.replace("ё", "е")) >= 0:
				spec.feat[f] = true
				break
	if t.find("без хвост") >= 0:
		spec.feat.erase("tail")
	return spec


static func _num(s: String) -> int:
	if s.is_valid_int():
		return int(s)
	for k in NUMS:
		if s.begins_with(k):
			return NUMS[k]
	return -1


static func _any(t: String, words: Array) -> bool:
	for w in words:
		if t.find(w) >= 0:
			return true
	return false


# ---------------------------------------------------------------- сборка

## Сгенерировать модель. Возвращает {"model": описание модели игры, "meshes": {путь: ArrayMesh}, "spec": ..., "ms": время}.
## opts: seed, quality (0..2), kind, id (имя модели — папка мешей), footprint (клеток здания), height (м), dir (куда класть меши).
static func generate(desc: String, opts := {}) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var spec := parse(desc, str(opts.get("kind", "")))
	if opts.has("arch") and str(opts.arch) != "":
		spec.arch = str(opts.arch)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 1)) * 7919 + hash(desc)
	var b := Builder.new(spec, rng, opts)
	match spec.arch:
		"bug":
			b.bug()
		"beast":
			b.beast()
		"walker":
			b.walker()
		"serpent":
			b.serpent()
		"drone":
			b.drone()
		"hero":
			b.hero()
		"turret":
			b.turret()
		"rock":
			b.rock()
		_:
			b.building()
	var q := clampi(int(opts.get("quality", 1)), 0, 2)
	var res: int = [44, 64, 88][q]
	var tri_budget: int = [900, 1800, 3200][q]
	var meshes := b.bake(res, tri_budget, bool(opts.get("threads", true)))
	var mid := str(opts.get("id", "gen_model"))
	var dir := str(opts.get("dir", "gen"))
	var model := b.model_dict(mid, dir, meshes)
	var files := {}
	for k in meshes:
		files["%s/%s/%s.res" % [dir, mid, k]] = meshes[k]
	return {"model": model, "meshes": files, "spec": spec, "ms": Time.get_ticks_msec() - t0}


## Сохранить меши на диск (папка игры или проекта) и вернуть модель.
static func save(result: Dictionary, base_dir: String) -> bool:
	var ok := true
	for rel in result.meshes:
		var full := base_dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		if ResourceSaver.save(result.meshes[rel], full, ResourceSaver.FLAG_COMPRESS) != OK:
			ok = false
	return ok


static func preview_nodes(what: String) -> Array:
	var r := generate(what if what != "test" else "огромный ржавый жук-робот с шестью ногами, клешнями, пушкой на спине и красными глазами", {"seed": 3, "quality": 1})
	print("GENSPEC ", r.spec)
	return nodes_of(r)


## Узлы для предпросмотра (без игры): каждая часть на своём месте, в позе покоя.
static func nodes_of(r: Dictionary) -> Array:
	var out := []
	var model: Dictionary = r.model
	var piv := {}
	var bones: Dictionary = model.get("bones", {})
	if not bones.is_empty():
		# герой: части в координатах своей кости — накопим смещения
		var par := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "torso",
			"arm_l": "torso", "arm_r": "torso", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r"}
		for bn in ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r", "gun"]:
			var o := ModelLib.v3(bones.get(bn, [0, 0, 0]))
			piv[bn] = o + (piv[par[bn]] if par.has(bn) else Vector3.ZERO)
	var gs := float(model.get("scale", 1.0))
	for p in model.parts:
		var rel := str(p.get("mesh", ""))
		var mesh: Mesh = r.meshes.get(rel)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = float(p.get("roughness", 0.55))
		m.metallic = float(p.get("metallic", 0.3))
		if str(p.get("mat", "")) == "glow":
			m.emission_enabled = true
			m.emission = Color.from_string(str(p.get("glow_col", "#ffb238")), Color(1, 0.7, 0.2))
			m.emission_energy_multiplier = 2.0
		mi.material_override = m
		var off: Vector3 = piv.get(str(p.get("role", "")), Vector3.ZERO)
		mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * gs), off * gs)
		mi.set_meta("aabb", Transform3D(Basis.from_scale(Vector3.ONE * gs), off * gs) * mesh.get_aabb())
		out.append(mi)
	return out


# ================================================================ строитель

class Builder:
	extends RefCounted
	var spec: Dictionary
	var rng: RandomNumberGenerator
	var opts: Dictionary
	var segs := {}            # кость -> SdfMesh
	var glow := {}            # кость -> SdfMesh (светящиеся детали отдельно: свой материал)
	var seg_mat := {}         # кость -> {mat, metallic, roughness, anim}
	var bones: Array = []     # [{name, parent, pivot}]
	var rig := {}
	var hero_bones := {}      # у героя — свои кости
	var parts_extra: Array = []
	var name := ""
	var category := "Сгенерированные"
	var col_main: Color
	var col_acc: Color
	var col_dark: Color
	var col_metal: Color
	var col_glow: Color
	var rough := 0.0
	var k := 1.0              # общий масштаб
	var mech := true

	func _init(s: Dictionary, r: RandomNumberGenerator, o: Dictionary) -> void:
		spec = s
		rng = r
		opts = o
		mech = bool(spec.get("mech", true))
		k = float(spec.get("size", 1.0))
		var cs: Array = spec.get("colors", [])
		var pal_main := [Color("#c8392b"), Color("#e07a24"), Color("#4b9a45"), Color("#2f5fbf"), Color("#7d4bc0"), Color("#d9a83a"), Color("#2bb5a8"), Color("#8a929c")]
		col_main = Color(cs[0]) if cs.size() > 0 else pal_main[rng.randi() % pal_main.size()]
		col_acc = Color(cs[1]) if cs.size() > 1 else col_main.lerp(Color("#e6c234") if col_main.get_luminance() < 0.5 else Color("#222428"), 0.55)
		col_dark = Color("#24262b").lerp(col_main, 0.12)
		col_metal = Color("#8a929c")
		if spec.get("rusty", false):
			col_metal = Color("#7a5a44")
			col_main = col_main.lerp(Color("#8e4a26"), 0.35)
		col_glow = Color(str(spec.get("glow", "#ffb238")))
		match str(spec.get("mat", "metal")):
			"stone":
				rough = 0.025
				col_metal = Color("#6d6a66")
			"flesh":
				rough = 0.008
			"crystal":
				rough = 0.0

	# ---------- кости и формы

	func bone(name_: String, parent: String, pivot: Vector3) -> void:
		bones.append({"name": name_, "parent": parent, "pivot": [pivot.x, pivot.y, pivot.z]})

	func S(b: String) -> SdfMesh:
		if not segs.has(b):
			var s := SdfMesh.new()
			s.noise.seed = rng.randi()
			if spec.get("rusty", false):
				s.wear = 0.5
				s.dirt = 0.45
			if not mech:
				s.wear = 0.15
				s.dirt = 0.4
			segs[b] = s
		return segs[b]

	func G(b: String) -> SdfMesh:
		if not glow.has(b):
			var s := SdfMesh.new()
			s.ao_k = 0.0
			s.wear = 0.0
			s.dirt = 0.0
			glow[b] = s
		return glow[b]

	func r(a: float, b: float) -> float:
		return rng.randf_range(a, b)

	# ---------- детали

	## Болты в ряд от a до b.
	func bolts(s: SdfMesh, a: Vector3, b: Vector3, n: int, rad: float) -> void:
		for i in n:
			var p := a.lerp(b, (i + 0.5) / float(n))
			s.sphere(p, rad, col_metal.lightened(0.15), 0.004)

	## Паз (шов между пластинами): тонкий вырез.
	func groove(s: SdfMesh, p: Vector3, half: Vector3, rot := Vector3.ZERO) -> void:
		s.box(p, half, minf(half.x, minf(half.y, half.z)) * 0.5, col_dark, rot, 0.006, SdfMesh.OP_SUB)

	## Вентиляционные щели.
	func vents(s: SdfMesh, p: Vector3, n: int, along: Vector3, slot: Vector3, rot := Vector3.ZERO) -> void:
		for i in n:
			var q := p + along * (i - (n - 1) * 0.5)
			s.box(q, slot, slot.y * 0.5, col_dark, rot, 0.005, SdfMesh.OP_SUB)

	## Поршень между a и b (гидроцилиндр с блестящим штоком).
	func piston(s: SdfMesh, a: Vector3, b: Vector3, rad: float) -> void:
		var m := a.lerp(b, 0.55)
		s.capsule(a, m, rad, rad, col_dark, 0.01)
		s.capsule(m, b, rad * 0.55, rad * 0.55, col_metal.lightened(0.25), 0.008)
		s.torus(m, rad * 1.02, rad * 0.25, col_metal, _rot_to(b - a), 0.006)

	## Шланг по точкам.
	func hose(s: SdfMesh, pts: Array, rad: float, col: Color) -> void:
		for i in pts.size() - 1:
			s.capsule(pts[i], pts[i + 1], rad, rad, col, rad * 0.8)

	## Углы Эйлера (град), поворачивающие ось Y вдоль dir.
	func _rot_to(dir: Vector3) -> Vector3:
		var d := dir.normalized()
		if d.length() < 0.01:
			return Vector3.ZERO
		var q := Quaternion(Vector3.UP, d) if absf(d.dot(Vector3.UP)) < 0.999 else Quaternion.IDENTITY
		var e := Basis(q).get_euler()
		return e * (180.0 / PI)

	## Глаз: тёмная впадина, светящаяся линза, ободок.
	func eye(b: String, p: Vector3, rad: float, out_dir: Vector3) -> void:
		var s := S(b)
		s.sphere(p, rad * 1.25, col_dark, 0.01)
		s.torus(p + out_dir * rad * 0.35, rad * 1.05, rad * 0.22, col_metal, _rot_to(out_dir), 0.005)
		G(b).sphere(p + out_dir * rad * 0.3, rad * 0.85, col_glow, 0.0)

	## Панцирь: эллипсоид с пазами между пластинами, сверху килем; у механики — болты по краю.
	func shell(b: String, c: Vector3, rad: Vector3, col: Color, plates: int, blend_k := 0.06) -> void:
		var s := S(b)
		s.ellipsoid(c, rad, col, Vector3.ZERO, blend_k, SdfMesh.OP_ADD, rough)
		for i in range(1, plates):
			var x := c.x - rad.x + 2.0 * rad.x * i / float(plates)
			groove(s, Vector3(x, c.y + rad.y * 0.4, c.z), Vector3(0.012 * k, rad.y * 0.8, rad.z * 1.1))
		if mech:
			# киль и полосы акцентного цвета
			s.box(c + Vector3(0, rad.y * 0.92, 0), Vector3(rad.x * 0.8, rad.y * 0.12, rad.z * 0.12), rad.y * 0.08, col_acc, Vector3.ZERO, 0.03)
			bolts(s, c + Vector3(-rad.x * 0.7, rad.y * 0.55, rad.z * 0.62), c + Vector3(rad.x * 0.7, rad.y * 0.55, rad.z * 0.62), 5, 0.022 * k)
			bolts(s, c + Vector3(-rad.x * 0.7, rad.y * 0.55, -rad.z * 0.62), c + Vector3(rad.x * 0.7, rad.y * 0.55, -rad.z * 0.62), 5, 0.022 * k)
		if spec.feat.has("spikes"):
			for i in plates + 1:
				var x2 := c.x - rad.x * 0.8 + 1.6 * rad.x * i / float(plates)
				s.capsule(Vector3(x2, c.y + rad.y * 0.85, c.z), Vector3(x2 - 0.08 * k, c.y + rad.y * 1.55, c.z), 0.05 * k, 0.004, col_acc.darkened(0.2), 0.03)

	## Нога из двух звеньев: бедро → колено → ступня. Кости hipN/kneeN.
	func leg(i: int, hip: Vector3, knee: Vector3, foot: Vector3, thick: float, parent: String) -> Array:
		var hb := "b:hip%d" % i
		var kb := "b:knee%d" % i
		bone(hb, parent, hip)
		bone(kb, hb, knee)
		var s1 := S(hb)
		var s2 := S(kb)
		if mech:
			s1.sphere(hip, thick * 1.35, col_metal, 0.01)
			s1.capsule(hip, knee, thick * 1.05, thick * 0.85, col_main, 0.02)
			s1.box(hip.lerp(knee, 0.5), Vector3(thick * 0.5, thick * 1.1, (knee - hip).length() * 0.32), thick * 0.3, col_acc, _rot_from_z(knee - hip), 0.02)
			piston(s1, hip.lerp(knee, 0.15) + Vector3(0, -thick, 0), hip.lerp(knee, 0.85) + Vector3(0, -thick * 0.8, 0), thick * 0.35)
			s2.sphere(knee, thick * 1.15, col_metal, 0.01)
			s2.capsule(knee, foot.lerp(knee, 0.18), thick * 0.85, thick * 0.55, col_main, 0.02)
			s2.capsule(foot.lerp(knee, 0.2), foot, thick * 0.5, thick * 0.18, col_dark, 0.015)
			s2.torus(knee.lerp(foot, 0.45), thick * 0.62, thick * 0.12, col_metal, _rot_to(foot - knee), 0.005)
		else:
			s1.ellipsoid(hip.lerp(knee, 0.45), Vector3(thick * 1.25, thick * 1.25, thick * 1.25), col_main, Vector3.ZERO, thick * 0.8, SdfMesh.OP_ADD, rough)
			s1.capsule(hip, knee, thick * 1.1, thick * 0.8, col_main, thick * 0.6, SdfMesh.OP_ADD, rough)
			s2.capsule(knee, foot, thick * 0.8, thick * 0.25, col_main.darkened(0.15), thick * 0.5, SdfMesh.OP_ADD, rough)
			s2.capsule(foot.lerp(knee, 0.12), foot + (foot - knee).normalized() * thick * 0.6, thick * 0.3, 0.004, col_dark, 0.01)
		return [hb, kb]

	## Углы, поворачивающие ось Z вдоль dir (для ящиков, вытянутых по Z).
	func _rot_from_z(dir: Vector3) -> Vector3:
		var d := dir.normalized()
		if d.length() < 0.01:
			return Vector3.ZERO
		var q := Quaternion(Vector3.BACK, d) if absf(d.dot(Vector3.BACK)) < 0.999 else Quaternion.IDENTITY
		return Basis(q).get_euler() * (180.0 / PI)

	## Пушка: башенка, ствол с дульным тормозом, короб.
	func cannon(b: String, base: Vector3, len_: float, rad: float) -> void:
		var s := S(b)
		s.cylinder(base, rad * 2.2, rad * 0.7, rad * 0.3, col_metal, Vector3.ZERO, 0.02)
		s.box(base + Vector3(0, rad * 1.6, 0), Vector3(rad * 2.1, rad * 1.2, rad * 1.6), rad * 0.45, col_main, Vector3.ZERO, 0.02)
		groove(s, base + Vector3(0, rad * 2.75, 0), Vector3(rad * 1.8, 0.01 * k, rad * 1.7))
		var a := base + Vector3(rad * 1.6, rad * 1.7, 0)
		var e := a + Vector3(len_, 0, 0)
		s.cylinder(a.lerp(e, 0.5), rad * 0.45, len_ * 0.5, rad * 0.1, col_dark, Vector3(0, 0, 90), 0.01)
		s.cylinder(e, rad * 0.7, rad * 0.45, rad * 0.15, col_metal, Vector3(0, 0, 90), 0.01)
		s.cylinder(e + Vector3(rad * 0.2, 0, 0), rad * 0.3, rad * 0.7, 0.0, col_dark, Vector3(0, 0, 90), 0.005, SdfMesh.OP_SUB)
		vents(s, e, 3, Vector3(0, 0, 0), Vector3(rad * 0.12, rad * 0.75, rad * 0.75))
		G(b).sphere(base + Vector3(-rad * 1.3, rad * 1.9, rad * 1.62), rad * 0.18, col_glow)

	# ================================================= архетипы

	## Насекомое / паук / жук / краб / скорпион.
	func bug() -> void:
		name = "Сгенерированное существо"
		var n := int(spec.get("legs", -1))
		if n <= 0:
			n = 8 if spec.desc.to_lower().find("паук") >= 0 or spec.desc.to_lower().find("spider") >= 0 else 6
		n = clampi(n - n % 2, 2, 12)
		var pairs := n / 2
		var L := 0.62 * k * r(0.9, 1.15)
		var H := 0.62 * k
		var Wd := 0.42 * k * r(0.9, 1.15)
		bone("b:body", "", Vector3(0, H, 0))
		# грудь и брюшко
		shell("b:body", Vector3(-L * 0.1, H + 0.04 * k, 0), Vector3(L * 0.75, 0.3 * k, Wd), col_main, 4 if mech else 3)
		var sb := S("b:body")
		sb.ellipsoid(Vector3(-L * 0.95, H + 0.1 * k, 0), Vector3(L * 0.55, 0.34 * k, Wd * 0.95), col_main.darkened(0.08), Vector3(0, 0, -8), 0.1 * k, SdfMesh.OP_ADD, rough)
		sb.ellipsoid(Vector3(-L * 0.1, H - 0.14 * k, 0), Vector3(L * 0.7, 0.13 * k, Wd * 0.8), col_dark, Vector3.ZERO, 0.06 * k)
		if mech:
			vents(sb, Vector3(-L * 0.95, H + 0.36 * k, 0), 4, Vector3(0.09 * k, 0, 0), Vector3(0.02 * k, 0.05 * k, Wd * 0.45))
			hose(sb, [Vector3(-L * 0.6, H + 0.2 * k, Wd * 0.9), Vector3(-L * 0.2, H + 0.05 * k, Wd * 1.05), Vector3(L * 0.3, H + 0.12 * k, Wd * 0.85)], 0.03 * k, col_dark)
			hose(sb, [Vector3(-L * 0.6, H + 0.2 * k, -Wd * 0.9), Vector3(-L * 0.2, H + 0.05 * k, -Wd * 1.05), Vector3(L * 0.3, H + 0.12 * k, -Wd * 0.85)], 0.03 * k, col_dark)
		# голова
		var hp := Vector3(L * 0.82, H + 0.02 * k, 0)
		bone("b:head", "b:body", hp)
		var sh := S("b:head")
		if mech:
			sh.box(hp + Vector3(0.1 * k, 0, 0), Vector3(0.2 * k, 0.15 * k, 0.19 * k), 0.07 * k, col_main, Vector3(0, 0, -6), 0.04)
			groove(sh, hp + Vector3(0.12 * k, 0.12 * k, 0), Vector3(0.18 * k, 0.012 * k, 0.21 * k))
		else:
			sh.ellipsoid(hp + Vector3(0.1 * k, 0, 0), Vector3(0.22 * k, 0.17 * k, 0.2 * k), col_main.darkened(0.1), Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough)
		var eyes := int(spec.get("eyes", -1))
		if eyes <= 0:
			eyes = 6 if spec.feat.has("eyes_many") else 2
		for i in eyes:
			var row := i / 2
			var side := 1.0 if i % 2 == 0 else -1.0
			eye("b:head", hp + Vector3(0.25 * k - row * 0.05 * k, 0.07 * k + row * 0.045 * k, side * (0.08 + row * 0.025) * k), 0.038 * k / (1.0 + row * 0.25), Vector3(1, 0.2, side * 0.5).normalized())
		# жвалы или клешни
		var jaws := []
		if spec.feat.has("mandibles") or not spec.feat.has("claws"):
			for side in [-1.0, 1.0]:
				var jb := "b:jaw%s" % ("l" if side < 0 else "r")
				var jp := hp + Vector3(0.24 * k, -0.08 * k, side * 0.09 * k)
				bone(jb, "b:head", jp)
				var sj := S(jb)
				sj.capsule(jp, jp + Vector3(0.18 * k, -0.02 * k, side * 0.02 * k), 0.035 * k, 0.025 * k, col_metal if mech else col_dark, 0.02)
				sj.capsule(jp + Vector3(0.18 * k, -0.02 * k, side * 0.02 * k), jp + Vector3(0.26 * k, -0.04 * k, -side * 0.05 * k), 0.025 * k, 0.004, col_dark, 0.015)
				jaws.append({"bone": jb, "open": 18.0 * side * -1.0, "axis": "y"})
		if spec.feat.has("claws"):
			for side in [-1.0, 1.0]:
				var cb := "b:claw%s" % ("l" if side < 0 else "r")
				var cp := Vector3(L * 0.65, H - 0.02 * k, side * Wd * 0.9)
				bone(cb, "b:body", cp)
				var sc := S(cb)
				var el := cp + Vector3(0.28 * k, 0.05 * k, side * 0.22 * k)
				var tip := el + Vector3(0.3 * k, -0.02 * k, -side * 0.05 * k)
				sc.capsule(cp, el, 0.06 * k, 0.05 * k, col_main, 0.02)
				sc.sphere(el, 0.065 * k, col_metal, 0.01)
				sc.ellipsoid(el.lerp(tip, 0.4), Vector3(0.16 * k, 0.09 * k, 0.07 * k), col_main, Vector3(0, -side * 10, 0), 0.04)
				sc.capsule(el.lerp(tip, 0.6) + Vector3(0, 0.03 * k, 0), tip + Vector3(0, 0.03 * k, 0), 0.04 * k, 0.006, col_acc, 0.015)
				sc.capsule(el.lerp(tip, 0.6) - Vector3(0, 0.03 * k, 0), tip + Vector3(-0.04 * k, -0.04 * k, 0), 0.035 * k, 0.006, col_acc, 0.015)
				jaws.append({"bone": cb, "open": 14.0 * side, "axis": "y"})
		# ноги — по бокам, фазы через одну (как у насекомых)
		var legs := []
		for pi in pairs:
			var fx := L * 0.45 - pi * (L * 1.0 / maxf(1.0, pairs - 1.0)) if pairs > 1 else 0.0
			for side in [-1.0, 1.0]:
				var i := pi * 2 + (0 if side < 0 else 1)
				var hip := Vector3(fx, H - 0.04 * k, side * Wd * 0.85)
				var knee := hip + Vector3(fx * 0.25, 0.3 * k, side * 0.42 * k)
				var foot := Vector3(fx * 1.35, 0.0, side * (Wd + 0.72 * k))
				var bn := leg(i, hip, knee, foot, 0.045 * k * (1.3 if spec.feat.has("armor") else 1.0), "b:body")
				legs.append({"hip": bn[0], "knee": bn[1], "phase": 0.0 if (pi + (0 if side < 0 else 1)) % 2 == 0 else 0.5, "side": side, "style": "y"})
		# хвост со жалом
		var chains := []
		if spec.feat.has("tail") or spec.feat.has("stinger") or spec.desc.to_lower().find("скорпион") >= 0:
			var prev := "b:body"
			var p0 := Vector3(-L * 1.4, H + 0.12 * k, 0)
			var names := []
			for i in 5:
				var tb := "b:tail%d" % i
				bone(tb, prev, p0)
				var p1 := p0 + Vector3(-0.08 * k, 0.16 * k, 0).rotated(Vector3.BACK, -0.45 * i)
				S(tb).capsule(p0, p1, (0.09 - i * 0.012) * k, (0.08 - i * 0.012) * k, col_main, 0.02)
				if mech:
					S(tb).torus(p0, (0.085 - i * 0.012) * k, 0.012 * k, col_metal, _rot_to(p1 - p0), 0.004)
				names.append(tb)
				prev = tb
				p0 = p1
			S(prev).capsule(p0, p0 + Vector3(0.18 * k, 0.04 * k, 0), 0.05 * k, 0.003, col_acc, 0.02)
			G(prev).sphere(p0 + Vector3(0.05 * k, 0, 0), 0.03 * k, col_glow)
			chains.append({"bones": names, "axis": "z", "amp": 9.0, "speed": 2.5, "lag": 0.7})
		if spec.feat.has("cannon") or spec.feat.has("rockets"):
			bone("b:gun", "b:body", Vector3(-L * 0.2, H + 0.3 * k, 0))
			cannon("b:gun", Vector3(-L * 0.2, H + 0.3 * k, 0), 0.45 * k, 0.08 * k)
		if spec.feat.has("antennae"):
			for side in [-1.0, 1.0]:
				S("b:head").capsule(hp + Vector3(0.18 * k, 0.12 * k, side * 0.07 * k), hp + Vector3(0.45 * k, 0.4 * k, side * 0.25 * k), 0.014 * k, 0.006 * k, col_dark, 0.01)
				G("b:head").sphere(hp + Vector3(0.45 * k, 0.4 * k, side * 0.25 * k), 0.022 * k, col_glow)
		if spec.feat.has("wings"):
			_wings("b:body", Vector3(-L * 0.2, H + 0.3 * k, 0), 0.8 * k)
		rig = {"bones": bones, "legs": legs, "jaws": jaws, "chains": chains, "head": "b:head", "body": "b:body", "breath": [] if mech else ["b:body"],
			"gait": {"stride": 0.9 * k, "swing": 22.0, "lift": 26.0, "knee": 20.0, "duty": 0.55, "bob": 0.03, "roll": 3.0, "lean": 4.0}}

	func _wings(b: String, at: Vector3, span: float) -> void:
		for side in [-1.0, 1.0]:
			var wb := "b:wing%s" % ("l" if side < 0 else "r")
			bone(wb, b, at + Vector3(0, 0, side * 0.1 * k))
			var s := S(wb)
			var tip := at + Vector3(-span * 0.4, span * 0.15, side * span)
			s.capsule(at + Vector3(0, 0, side * 0.1 * k), tip, 0.025 * k, 0.01 * k, col_dark, 0.01)
			s.ellipsoid(at.lerp(tip, 0.55) + Vector3(-0.1 * k, 0, 0), Vector3(span * 0.32, 0.012 * k, span * 0.5), col_acc.lerp(Color(0.8, 0.9, 1.0), 0.4), Vector3(0, side * 20, side * 8), 0.02)
		rig.get_or_add("chains", [])

	## Зверь на 4 лапах (волк, ящер, кабан; механический — «пёс-робот»).
	func beast() -> void:
		name = "Сгенерированный зверь"
		var H := 0.75 * k
		var L := 0.7 * k
		var Wd := 0.28 * k
		bone("b:body", "", Vector3(0, H, 0))
		var sb := S("b:body")
		if mech:
			sb.box(Vector3(0, H + 0.05 * k, 0), Vector3(L * 0.75, 0.2 * k, Wd), 0.1 * k, col_main, Vector3(0, 0, 3), 0.06)
			sb.box(Vector3(L * 0.35, H + 0.12 * k, 0), Vector3(L * 0.35, 0.22 * k, Wd * 1.1), 0.1 * k, col_main, Vector3.ZERO, 0.08)
			groove(sb, Vector3(0, H + 0.26 * k, 0), Vector3(L * 0.9, 0.012 * k, 0.015 * k))
			for side in [-1.0, 1.0]:
				vents(sb, Vector3(-L * 0.2, H + 0.08 * k, side * Wd), 4, Vector3(0.08 * k, 0, 0), Vector3(0.018 * k, 0.07 * k, 0.03 * k))
				bolts(sb, Vector3(-L * 0.6, H + 0.2 * k, side * Wd * 0.95), Vector3(L * 0.6, H + 0.22 * k, side * Wd * 0.95), 7, 0.018 * k)
			sb.box(Vector3(-L * 0.1, H + 0.27 * k, 0), Vector3(L * 0.45, 0.04 * k, Wd * 0.5), 0.03 * k, col_acc, Vector3.ZERO, 0.02)
		else:
			sb.ellipsoid(Vector3(-L * 0.25, H, 0), Vector3(L * 0.55, 0.26 * k, Wd), col_main, Vector3(0, 0, 4), 0.15 * k, SdfMesh.OP_ADD, rough)
			sb.ellipsoid(Vector3(L * 0.35, H + 0.06 * k, 0), Vector3(L * 0.45, 0.31 * k, Wd * 1.15), col_main, Vector3(0, 0, -6), 0.15 * k, SdfMesh.OP_ADD, rough)
			sb.ellipsoid(Vector3(0, H - 0.12 * k, 0), Vector3(L * 0.7, 0.14 * k, Wd * 0.8), col_main.lightened(0.15), Vector3.ZERO, 0.1 * k, SdfMesh.OP_ADD, rough)
		if spec.feat.has("spikes") or spec.feat.has("armor"):
			for i in 6:
				var x := L * 0.55 - i * L * 0.22
				sb.capsule(Vector3(x, H + 0.22 * k, 0), Vector3(x - 0.1 * k, H + 0.42 * k, 0), 0.05 * k, 0.005, col_acc.darkened(0.2), 0.03)
		# шея и голова
		var hp := Vector3(L * 0.85, H + 0.22 * k, 0)
		bone("b:head", "b:body", hp)
		var sh := S("b:head")
		if mech:
			sh.box(hp + Vector3(0.12 * k, 0.02 * k, 0), Vector3(0.18 * k, 0.12 * k, 0.13 * k), 0.06 * k, col_main, Vector3(0, 0, -10), 0.04)
			sh.box(hp + Vector3(0.32 * k, -0.04 * k, 0), Vector3(0.13 * k, 0.07 * k, 0.09 * k), 0.04 * k, col_dark, Vector3(0, 0, -14), 0.03)
			G("b:head").box(hp + Vector3(0.24 * k, 0.07 * k, 0), Vector3(0.03 * k, 0.025 * k, 0.12 * k), 0.012 * k, col_glow, Vector3(0, 0, -10), 0.0)
		else:
			sh.ellipsoid(hp + Vector3(0.12 * k, 0.03 * k, 0), Vector3(0.2 * k, 0.15 * k, 0.14 * k), col_main, Vector3.ZERO, 0.08 * k, SdfMesh.OP_ADD, rough)
			sh.capsule(hp + Vector3(0.2 * k, -0.02 * k, 0), hp + Vector3(0.42 * k, -0.07 * k, 0), 0.1 * k, 0.065 * k, col_main.lightened(0.1), 0.06 * k, SdfMesh.OP_ADD, rough)
			for side in [-1.0, 1.0]:
				eye("b:head", hp + Vector3(0.24 * k, 0.09 * k, side * 0.09 * k), 0.028 * k, Vector3(0.7, 0.2, side * 0.6).normalized())
				sh.capsule(hp + Vector3(0.05 * k, 0.12 * k, side * 0.08 * k), hp + Vector3(-0.02 * k, 0.28 * k, side * 0.12 * k), 0.04 * k, 0.008, col_main.darkened(0.2), 0.02)
		var jb := "b:jaw"
		bone(jb, "b:head", hp + Vector3(0.22 * k, -0.08 * k, 0))
		S(jb).box(hp + Vector3(0.36 * k, -0.11 * k, 0), Vector3(0.14 * k, 0.03 * k, 0.07 * k), 0.025 * k, col_dark, Vector3(0, 0, -6), 0.02)
		if spec.feat.has("horns"):
			for side in [-1.0, 1.0]:
				sh.capsule(hp + Vector3(0.1 * k, 0.12 * k, side * 0.08 * k), hp + Vector3(-0.1 * k, 0.38 * k, side * 0.2 * k), 0.045 * k, 0.006, col_acc.lightened(0.3), 0.02)
		# лапы под телом (ось шага Z)
		var legs := []
		var i := 0
		for fx in [L * 0.55, -L * 0.6]:
			for side in [-1.0, 1.0]:
				var hip := Vector3(fx, H - 0.05 * k, side * Wd * 0.8)
				var knee := Vector3(fx + (-0.06 if fx > 0 else 0.1) * k, H * 0.5, side * Wd * 0.9)
				var foot := Vector3(fx + 0.02 * k, 0.0, side * Wd * 0.9)
				var bn := leg(i, hip, knee, foot, 0.06 * k, "b:body")
				S(bn[1]).box(foot + Vector3(0.05 * k, 0.03 * k, 0), Vector3(0.09 * k, 0.03 * k, 0.06 * k), 0.025 * k, col_dark, Vector3.ZERO, 0.02)
				var ph: float = [0.0, 0.5, 0.75, 0.25][i]
				legs.append({"hip": bn[0], "knee": bn[1], "phase": ph, "side": side, "style": "z"})
				i += 1
		var chains := []
		if not spec.feat.has("tail") and mech:
			pass
		else:
			var prev := "b:body"
			var p0 := Vector3(-L * 0.78, H + 0.1 * k, 0)
			var names := []
			for ti in 4:
				var tb := "b:tail%d" % ti
				bone(tb, prev, p0)
				var p1 := p0 + Vector3(-0.17 * k, 0.03 * k - ti * 0.04 * k, 0)
				S(tb).capsule(p0, p1, (0.07 - ti * 0.014) * k, (0.06 - ti * 0.014) * k, col_main, 0.03, SdfMesh.OP_ADD, rough)
				names.append(tb)
				prev = tb
				p0 = p1
			chains.append({"bones": names, "axis": "y", "amp": 14.0, "speed": 3.0, "lag": 0.6, "follow": true})
		if spec.feat.has("cannon"):
			bone("b:gun", "b:body", Vector3(0, H + 0.3 * k, 0))
			cannon("b:gun", Vector3(0, H + 0.3 * k, 0), 0.4 * k, 0.07 * k)
		rig = {"bones": bones, "legs": legs, "jaws": [{"bone": jb, "open": -22.0, "axis": "z"}], "chains": chains, "head": "b:head", "body": "b:body",
			"breath": [] if mech else ["b:body"], "gait": {"stride": 1.3 * k, "swing": 28.0, "lift": 20.0, "knee": 38.0, "duty": 0.6, "bob": 0.05, "roll": 4.0, "lean": 6.0}}

	## Шагоход на двух ногах (голем, мех-робот).
	func walker() -> void:
		name = "Сгенерированный шагоход"
		var H := 1.0 * k
		bone("b:body", "", Vector3(0, H, 0))
		var sb := S("b:body")
		sb.box(Vector3(0, H + 0.25 * k, 0), Vector3(0.32 * k, 0.3 * k, 0.4 * k), 0.12 * k, col_main, Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough)
		sb.box(Vector3(0.05 * k, H + 0.05 * k, 0), Vector3(0.24 * k, 0.12 * k, 0.28 * k), 0.08 * k, col_dark, Vector3.ZERO, 0.05)
		sb.box(Vector3(0.3 * k, H + 0.3 * k, 0), Vector3(0.06 * k, 0.18 * k, 0.28 * k), 0.04 * k, col_acc, Vector3(0, 0, -8), 0.03)
		groove(sb, Vector3(0.1 * k, H + 0.45 * k, 0), Vector3(0.35 * k, 0.012 * k, 0.42 * k))
		vents(sb, Vector3(-0.32 * k, H + 0.3 * k, 0), 4, Vector3(0, 0, 0.09 * k), Vector3(0.03 * k, 0.12 * k, 0.025 * k))
		bolts(sb, Vector3(0.3 * k, H + 0.5 * k, -0.35 * k), Vector3(0.3 * k, H + 0.5 * k, 0.35 * k), 6, 0.02 * k)
		var hp := Vector3(0.1 * k, H + 0.6 * k, 0)
		bone("b:head", "b:body", hp)
		var sh := S("b:head")
		sh.box(hp + Vector3(0.04 * k, 0.08 * k, 0), Vector3(0.15 * k, 0.1 * k, 0.14 * k), 0.06 * k, col_main.lightened(0.1), Vector3.ZERO, 0.03)
		G("b:head").box(hp + Vector3(0.18 * k, 0.1 * k, 0), Vector3(0.02 * k, 0.025 * k, 0.11 * k), 0.01 * k, col_glow, Vector3.ZERO, 0.0)
		if spec.feat.has("antennae"):
			sh.capsule(hp + Vector3(-0.05 * k, 0.15 * k, 0.1 * k), hp + Vector3(-0.1 * k, 0.45 * k, 0.12 * k), 0.012 * k, 0.006 * k, col_dark, 0.01)
		var legs := []
		for side in [-1.0, 1.0]:
			var i := 0 if side < 0 else 1
			var hip := Vector3(-0.02 * k, H - 0.05 * k, side * 0.24 * k)
			var knee := Vector3(0.12 * k, H * 0.52, side * 0.27 * k)
			var foot := Vector3(-0.02 * k, 0.04 * k, side * 0.27 * k)
			var bn := leg(i, hip, knee, foot, 0.08 * k, "b:body")
			S(bn[1]).box(foot + Vector3(0.06 * k, 0.0, 0), Vector3(0.16 * k, 0.045 * k, 0.1 * k), 0.035 * k, col_dark, Vector3.ZERO, 0.02)
			legs.append({"hip": bn[0], "knee": bn[1], "phase": 0.0 if side < 0 else 0.5, "side": side, "style": "z"})
		var arms := []
		for side in [-1.0, 1.0]:
			var ab := "b:arm%s" % ("l" if side < 0 else "r")
			var sp := Vector3(0, H + 0.4 * k, side * 0.48 * k)
			bone(ab, "b:body", sp)
			var sa := S(ab)
			sa.sphere(sp, 0.13 * k, col_acc, 0.02)
			sa.box(sp + Vector3(0, 0.02 * k, side * 0.02 * k), Vector3(0.14 * k, 0.1 * k, 0.12 * k), 0.05 * k, col_main, Vector3.ZERO, 0.02)
			var el := sp + Vector3(0.02 * k, -0.38 * k, side * 0.04 * k)
			sa.capsule(sp, el, 0.07 * k, 0.06 * k, col_dark, 0.02)
			var hand := el + Vector3(0.12 * k, -0.32 * k, 0)
			if spec.feat.has("cannon") and side > 0:
				sa.cylinder(el.lerp(hand, 0.5), 0.09 * k, 0.24 * k, 0.03 * k, col_main, Vector3(0, 0, 20), 0.02)
				sa.cylinder(hand, 0.05 * k, 0.12 * k, 0.0, col_dark, Vector3(0, 0, 20), 0.01)
				G(ab).sphere(hand + Vector3(0.03 * k, -0.08 * k, 0), 0.03 * k, col_glow)
			else:
				sa.capsule(el, hand, 0.08 * k, 0.07 * k, col_main, 0.02)
				sa.box(hand + Vector3(0.02 * k, -0.06 * k, 0), Vector3(0.07 * k, 0.08 * k, 0.07 * k), 0.03 * k, col_dark, Vector3.ZERO, 0.02)
			piston(sa, sp + Vector3(-0.08 * k, -0.08 * k, 0), el + Vector3(-0.08 * k, 0, 0), 0.025 * k)
			arms.append({"bone": ab, "phase": 0.5 if side < 0 else 0.0, "amp": 20.0})
		if spec.feat.has("rockets") or spec.feat.has("backpack"):
			sb.box(Vector3(-0.42 * k, H + 0.35 * k, 0), Vector3(0.12 * k, 0.22 * k, 0.26 * k), 0.05 * k, col_dark, Vector3.ZERO, 0.03)
			for j in 3:
				sb.cylinder(Vector3(-0.42 * k, H + 0.62 * k, (j - 1) * 0.12 * k), 0.045 * k, 0.07 * k, 0.015 * k, col_acc, Vector3.ZERO, 0.01)
		rig = {"bones": bones, "legs": legs, "arms": arms, "jaws": [], "chains": [], "head": "b:head", "body": "b:body", "breath": [],
			"gait": {"stride": 1.5 * k, "swing": 30.0, "lift": 20.0, "knee": 45.0, "duty": 0.6, "bob": 0.07, "roll": 5.0, "lean": 5.0}}

	## Змей / червь / многоножка: цепь сегментов.
	func serpent() -> void:
		name = "Сгенерированный змей"
		var n := 8
		var rad := 0.22 * k
		bone("b:body", "", Vector3(0, rad, 0))
		var prev := "b:body"
		var names := []
		var p := Vector3(0, rad, 0)
		S("b:body").ellipsoid(p + Vector3(0.15 * k, 0.02 * k, 0), Vector3(rad * 1.5, rad * 1.1, rad * 1.2), col_main, Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough)
		var hp := p + Vector3(0.3 * k, 0.04 * k, 0)
		bone("b:head", "b:body", hp)
		var sh := S("b:head")
		sh.ellipsoid(hp + Vector3(0.12 * k, 0, 0), Vector3(rad * 1.2, rad * 0.9, rad * 1.0), col_main.darkened(0.1), Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough)
		for side in [-1.0, 1.0]:
			eye("b:head", hp + Vector3(0.24 * k, 0.08 * k, side * 0.1 * k), 0.03 * k, Vector3(0.6, 0.3, side * 0.7).normalized())
		if mech or spec.feat.has("drill"):
			sh.cylinder(hp + Vector3(0.38 * k, 0, 0), rad * 0.7, 0.08 * k, 0.02 * k, col_metal, Vector3(0, 0, 90), 0.02)
			for i in 6:
				sh.capsule(hp + Vector3(0.42 * k, 0, 0) + Vector3(0, rad * 0.55, 0).rotated(Vector3.RIGHT, i * TAU / 6.0), hp + Vector3(0.62 * k, 0, 0), 0.03 * k, 0.004, col_metal.lightened(0.2), 0.01)
		for i in n:
			var sb := "b:seg%d" % i
			bone(sb, prev, p)
			var q := p + Vector3(-0.3 * k, 0, 0)
			var rr := rad * (1.0 - i * 0.07)
			var s := S(sb)
			s.ellipsoid(p.lerp(q, 0.5), Vector3(0.19 * k, rr, rr * 1.05), col_main if i % 2 == 0 else col_main.darkened(0.12), Vector3.ZERO, 0.04, SdfMesh.OP_ADD, rough)
			if mech:
				s.torus(p.lerp(q, 0.5), rr * 0.95, 0.025 * k, col_metal, Vector3(0, 0, 90), 0.01)
				s.box(p.lerp(q, 0.5) + Vector3(0, rr * 0.9, 0), Vector3(0.1 * k, 0.03 * k, rr * 0.4), 0.02 * k, col_acc, Vector3.ZERO, 0.02)
			if spec.feat.has("spikes"):
				s.capsule(p.lerp(q, 0.5) + Vector3(0, rr * 0.8, 0), p.lerp(q, 0.5) + Vector3(-0.06 * k, rr * 1.6, 0), 0.035 * k, 0.004, col_acc, 0.02)
			if spec.desc.to_lower().find("сороконож") >= 0 or spec.desc.to_lower().find("многоножк") >= 0 or spec.get("legs", -1) > 0:
				for side in [-1.0, 1.0]:
					var lp := p.lerp(q, 0.5) + Vector3(0, -rr * 0.5, side * rr * 0.8)
					s.capsule(lp, lp + Vector3(0.05 * k, -rr * 0.5, side * 0.2 * k), 0.025 * k, 0.008, col_dark, 0.01)
			names.append(sb)
			prev = sb
			p = q
		rig = {"bones": bones, "legs": [], "jaws": [], "chains": [{"bones": names, "axis": "y", "amp": 16.0, "speed": 4.0, "lag": 0.9, "follow": true}],
			"head": "b:head", "body": "b:body", "breath": [], "gait": {"stride": 1.0 * k, "bob": 0.02, "roll": 2.0, "lean": 0.0}}

	## Дрон / летун: корпус, винты (кости-роторы) или крылья, парение.
	func drone() -> void:
		name = "Сгенерированный дрон"
		var H := 1.4 * k
		bone("b:body", "", Vector3(0, H, 0))
		var sb := S("b:body")
		var bird: bool = spec.feat.has("wings") or not mech
		if bird:
			sb.ellipsoid(Vector3(0, H, 0), Vector3(0.32 * k, 0.15 * k, 0.15 * k), col_main, Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough)
			bone("b:head", "b:body", Vector3(0.3 * k, H + 0.05 * k, 0))
			S("b:head").sphere(Vector3(0.36 * k, H + 0.06 * k, 0), 0.1 * k, col_main, 0.03)
			S("b:head").capsule(Vector3(0.42 * k, H + 0.05 * k, 0), Vector3(0.56 * k, H + 0.02 * k, 0), 0.04 * k, 0.004, col_acc, 0.02)
			for side in [-1.0, 1.0]:
				eye("b:head", Vector3(0.42 * k, H + 0.1 * k, side * 0.06 * k), 0.02 * k, Vector3(0.5, 0.2, side * 0.8).normalized())
			_wings("b:body", Vector3(0.02 * k, H + 0.08 * k, 0), 0.75 * k)
			rig = {"bones": bones, "legs": [], "jaws": [], "head": "b:head", "body": "b:body", "breath": [],
				"chains": [{"bones": ["b:wingl"], "axis": "x", "amp": 28.0, "speed": 9.0, "sync": true, "sign": 1.0}, {"bones": ["b:wingr"], "axis": "x", "amp": 28.0, "speed": 9.0, "sync": true, "sign": -1.0}],
				"hover": {"speed": 2.0, "amp": 0.12}, "gait": {"stride": 2.0, "lean": 10.0}}
			return
		sb.box(Vector3(0, H, 0), Vector3(0.28 * k, 0.09 * k, 0.28 * k), 0.08 * k, col_main, Vector3.ZERO, 0.04)
		sb.sphere(Vector3(0, H - 0.07 * k, 0), 0.16 * k, col_dark, 0.04)
		groove(sb, Vector3(0, H + 0.08 * k, 0), Vector3(0.3 * k, 0.01 * k, 0.012 * k))
		groove(sb, Vector3(0, H + 0.08 * k, 0), Vector3(0.012 * k, 0.01 * k, 0.3 * k))
		G("b:body").sphere(Vector3(0.12 * k, H - 0.1 * k, 0), 0.06 * k, col_glow)
		var rotors := []
		var i := 0
		for a in [45.0, 135.0, 225.0, 315.0]:
			var d := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
			var tip := Vector3(0, H + 0.03 * k, 0) + d * 0.48 * k
			sb.capsule(Vector3(0, H, 0) + d * 0.2 * k, tip, 0.035 * k, 0.03 * k, col_dark, 0.02)
			sb.cylinder(tip, 0.07 * k, 0.05 * k, 0.02 * k, col_metal, Vector3.ZERO, 0.01)
			sb.torus(tip + Vector3(0, 0.06 * k, 0), 0.22 * k, 0.018 * k, col_acc, Vector3.ZERO, 0.0)
			var rb := "b:rotor%d" % i
			bone(rb, "b:body", tip + Vector3(0, 0.07 * k, 0))
			var sr := S(rb)
			sr.box(tip + Vector3(0, 0.07 * k, 0), Vector3(0.2 * k, 0.006 * k, 0.025 * k), 0.004 * k, col_dark, Vector3(0, 0, 0), 0.0)
			sr.box(tip + Vector3(0, 0.07 * k, 0), Vector3(0.025 * k, 0.006 * k, 0.2 * k), 0.004 * k, col_dark, Vector3(0, 0, 0), 0.0)
			sr.cylinder(tip + Vector3(0, 0.08 * k, 0), 0.03 * k, 0.02 * k, 0.01 * k, col_metal, Vector3.ZERO, 0.01)
			rotors.append({"bone": rb, "axis": "y", "speed": 30.0 if i % 2 == 0 else -30.0})
			i += 1
		if spec.feat.has("cannon"):
			bone("b:gun", "b:body", Vector3(0, H - 0.15 * k, 0))
			cannon("b:gun", Vector3(0, H - 0.25 * k, 0), 0.3 * k, 0.05 * k)
		rig = {"bones": bones, "legs": [], "jaws": [], "chains": [], "head": "", "body": "b:body", "breath": [], "rotors": rotors, "hover": {"speed": 2.2, "amp": 0.1}, "gait": {"stride": 2.0, "lean": 8.0}}

	## Герой: кости героя (ходьба, удар, добыча — из player.gd), детали в координатах костей.
	func hero() -> void:
		name = "Сгенерированный герой"
		hero_bones = {"hips": [0, 0.95, 0], "leg_l": [0, -0.05, 0.16], "leg_r": [0, -0.05, -0.16], "shin_l": [0, -0.45, 0], "shin_r": [0, -0.45, 0],
			"torso": [0, 0.1, 0], "head": [0.02, 0.62, 0], "arm_l": [0, 0.5, 0.36], "arm_r": [0, 0.5, -0.36], "fore_l": [0, -0.36, 0], "fore_r": [0, -0.36, 0],
			"hand_r": [0, -0.32, 0], "gun": [0, 0, 0], "muzzle": [0.56, 0.02, 0]}
		var hs := 1.0
		# таз
		var s := S("hips")
		s.box(Vector3(0, 0, 0), Vector3(0.13, 0.08, 0.2), 0.05, col_dark, Vector3.ZERO, 0.03)
		s.box(Vector3(0.02, 0.04, 0), Vector3(0.12, 0.04, 0.21), 0.03, col_main, Vector3.ZERO, 0.02)
		bolts(s, Vector3(0.12, 0.03, -0.15), Vector3(0.12, 0.03, 0.15), 4, 0.012)
		# ноги
		for side in ["l", "r"]:
			var z := 1.0 if side == "l" else -1.0
			var sl := S("leg_" + side)
			sl.sphere(Vector3(0, 0, 0), 0.08, col_metal, 0.01)
			sl.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.4, 0), 0.085, 0.07, col_main, 0.02)
			sl.box(Vector3(0.05, -0.2, 0), Vector3(0.04, 0.13, 0.065), 0.025, col_acc, Vector3.ZERO, 0.015)
			piston(sl, Vector3(-0.06, -0.05, 0.0), Vector3(-0.05, -0.38, 0), 0.018)
			var ss := S("shin_" + side)
			ss.sphere(Vector3(0, 0, 0), 0.075, col_metal, 0.01)
			ss.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.36, 0), 0.07, 0.055, col_main, 0.02)
			ss.box(Vector3(0.06, -0.15, 0), Vector3(0.03, 0.12, 0.06), 0.02, col_main.lightened(0.1), Vector3(0, 0, -4), 0.02)
			ss.box(Vector3(0.05, -0.43, 0), Vector3(0.14, 0.045, 0.075), 0.03, col_dark, Vector3.ZERO, 0.02)
			groove(ss, Vector3(0.05, -0.4, 0), Vector3(0.15, 0.006, 0.08))
		# торс
		var st := S("torso")
		st.box(Vector3(0, 0.3, 0), Vector3(0.17, 0.22, 0.27), 0.1, col_main, Vector3.ZERO, 0.05)
		st.box(Vector3(0.0, 0.08, 0), Vector3(0.13, 0.1, 0.2), 0.06, col_dark, Vector3.ZERO, 0.04)
		st.box(Vector3(0.14, 0.32, 0), Vector3(0.05, 0.15, 0.18), 0.05, col_acc, Vector3(0, 0, -6), 0.03)
		groove(st, Vector3(0.15, 0.22, 0), Vector3(0.08, 0.006, 0.2))
		groove(st, Vector3(0.15, 0.4, 0), Vector3(0.08, 0.006, 0.2))
		G("torso").sphere(Vector3(0.2, 0.32, 0), 0.035, col_glow)
		vents(st, Vector3(0.17, 0.12, 0), 3, Vector3(0, 0, 0.06), Vector3(0.03, 0.035, 0.02))
		# ранец
		st.box(Vector3(-0.22, 0.3, 0), Vector3(0.08, 0.18, 0.2), 0.05, col_dark, Vector3.ZERO, 0.03)
		st.cylinder(Vector3(-0.27, 0.32, 0.12), 0.05, 0.14, 0.02, col_metal, Vector3.ZERO, 0.01)
		st.cylinder(Vector3(-0.27, 0.32, -0.12), 0.05, 0.14, 0.02, col_metal, Vector3.ZERO, 0.01)
		hose(st, [Vector3(-0.25, 0.47, 0.1), Vector3(-0.1, 0.55, 0.15), Vector3(0.05, 0.5, 0.18)], 0.016, col_dark)
		# голова: шлем с визором
		var sh := S("head")
		sh.sphere(Vector3(0, 0.12, 0), 0.15, col_main.lightened(0.05), 0.03)
		sh.box(Vector3(0.0, 0.03, 0), Vector3(0.12, 0.05, 0.12), 0.04, col_dark, Vector3.ZERO, 0.04)
		sh.box(Vector3(0.11, 0.13, 0), Vector3(0.06, 0.06, 0.12), 0.05, col_dark, Vector3.ZERO, 0.0, SdfMesh.OP_SUB)
		G("head").box(Vector3(0.1, 0.13, 0), Vector3(0.03, 0.045, 0.11), 0.03, col_glow, Vector3.ZERO, 0.0)
		sh.capsule(Vector3(-0.05, 0.24, 0.1), Vector3(-0.1, 0.42, 0.12), 0.01, 0.006, col_dark, 0.008)
		G("head").sphere(Vector3(-0.1, 0.43, 0.12), 0.018, col_glow)
		# руки
		for side in ["l", "r"]:
			var z := 1.0 if side == "l" else -1.0
			var sa := S("arm_" + side)
			sa.sphere(Vector3(0, 0, 0), 0.1, col_acc, 0.02)
			sa.box(Vector3(0, 0.03, z * 0.02), Vector3(0.11, 0.07, 0.1), 0.04, col_main, Vector3.ZERO, 0.02)
			sa.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.33, 0), 0.06, 0.05, col_dark, 0.02)
			var sf := S("fore_" + side)
			sf.sphere(Vector3(0, 0, 0), 0.06, col_metal, 0.01)
			sf.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.28, 0), 0.065, 0.055, col_main, 0.02)
			sf.box(Vector3(0.03, -0.15, 0), Vector3(0.05, 0.1, 0.06), 0.025, col_acc.darkened(0.1), Vector3.ZERO, 0.015)
			if side == "l":
				sf.box(Vector3(0.02, -0.34, 0), Vector3(0.05, 0.05, 0.045), 0.02, col_dark, Vector3.ZERO, 0.015)
		S("hand_r").box(Vector3(0.02, -0.02, 0), Vector3(0.05, 0.05, 0.045), 0.02, col_dark, Vector3.ZERO, 0.015)

	## Турель: основание, поворотная башня (роль head — поворачивает игра), стволы.
	func turret() -> void:
		name = "Сгенерированная турель"
		var fp := int(opts.get("footprint", 1))
		var R := fp * 2.0 * 0.42
		var sb := S("base")
		sb.cylinder(Vector3(0, 0.15, 0), R, 0.15, 0.05, col_dark, Vector3.ZERO, 0.03)
		sb.cylinder(Vector3(0, 0.38, 0), R * 0.75, 0.12, 0.04, col_main, Vector3.ZERO, 0.04)
		bolts(sb, Vector3(-R * 0.9, 0.31, 0), Vector3(R * 0.9, 0.31, 0), 8, 0.03)
		for i in 8:
			var a := i * TAU / 8.0
			sb.box(Vector3(cos(a) * R * 0.95, 0.15, sin(a) * R * 0.95), Vector3(0.08, 0.12, 0.08), 0.03, col_acc, Vector3(0, -rad_to_deg(a), 0), 0.02)
		var sh := S("head")
		sh.box(Vector3(0, 0.75, 0), Vector3(R * 0.5, 0.25, R * 0.42), 0.12, col_main, Vector3.ZERO, 0.05)
		groove(sh, Vector3(0, 0.88, 0), Vector3(R * 0.55, 0.01, R * 0.45))
		vents(sh, Vector3(-R * 0.48, 0.75, 0), 4, Vector3(0, 0, 0.12), Vector3(0.04, 0.12, 0.03))
		var nb := 2 if spec.feat.has("rockets") else (2 if fp > 1 else 1)
		for j in nb:
			var z := (j - (nb - 1) * 0.5) * 0.24
			sh.cylinder(Vector3(R * 0.5 + 0.45, 0.78, z), 0.06, 0.45, 0.02, col_dark, Vector3(0, 0, 90), 0.02)
			sh.cylinder(Vector3(R * 0.5 + 0.9, 0.78, z), 0.09, 0.07, 0.02, col_metal, Vector3(0, 0, 90), 0.01)
			sh.cylinder(Vector3(R * 0.5 + 0.95, 0.78, z), 0.04, 0.1, 0.0, col_dark, Vector3(0, 0, 90), 0.005, SdfMesh.OP_SUB)
		G("head").box(Vector3(R * 0.5, 0.92, 0), Vector3(0.03, 0.03, R * 0.25), 0.015, col_glow, Vector3.ZERO, 0.0)
		seg_mat["head"] = {"role": "head"}

	## Камень / кристалл / руда.
	func rock() -> void:
		name = "Сгенерированный камень"
		var s := S("base")
		var main := col_main if spec.colors.size() > 0 else Color("#7d7b76")
		for i in 6:
			var p := Vector3(r(-0.35, 0.35), r(0.2, 0.45), r(-0.35, 0.35)) * k
			s.ellipsoid(p, Vector3(r(0.25, 0.45), r(0.2, 0.35), r(0.25, 0.4)) * k, main.darkened(r(0, 0.2)), Vector3(r(-20, 20), r(0, 180), r(-20, 20)), 0.12 * k, SdfMesh.OP_ADD, 0.04 * k)
		s.box(Vector3(0, -0.5, 0), Vector3(2, 0.5, 2), 0.0, main, Vector3.ZERO, 0.1, SdfMesh.OP_SUB)
		if spec.feat.has("crystals") or spec.mat == "crystal":
			var g := G("base")
			for i in 5:
				var a := r(0, TAU)
				var base := Vector3(cos(a) * 0.25, 0.35, sin(a) * 0.25) * k
				var tip := base + Vector3(cos(a) * 0.2, r(0.35, 0.6), sin(a) * 0.2) * k
				g.capsule(base, tip, 0.08 * k, 0.01 * k, col_glow, 0.0)

	# ================================================= здания

	func building() -> void:
		name = "Сгенерированное здание"
		var d: String = spec.desc.to_lower()
		var fp := int(opts.get("footprint", 2))
		var W := fp * 2.0 * 0.46
		var Hh := float(opts.get("height", 0.0))
		var kind := "machine"
		if _has(d, ["печ", "плавил", "furnace", "smelt"]):
			kind = "furnace"
		elif _has(d, ["бур", "шахт", "drill", "miner", "добыв"]):
			kind = "drill"
		elif _has(d, ["ветр", "турбин", "wind"]):
			kind = "turbine"
		elif _has(d, ["бак", "цистерн", "резервуар", "tank"]):
			kind = "tank"
		elif _has(d, ["склад", "сундук", "ящик", "storage", "chest", "контейнер"]):
			kind = "storage"
		elif _has(d, ["генератор", "электростан", "реактор", "generator", "reactor"]):
			kind = "generator"
		elif _has(d, ["башн", "вышк", "радар", "антенн", "tower", "radar"]):
			kind = "tower"
		if Hh <= 0.0:
			Hh = {"furnace": 1.6, "drill": 2.6, "turbine": 4.5, "tank": 2.0, "storage": 1.1, "generator": 1.8, "tower": 4.0}.get(kind, 1.8) * maxf(1.0, fp * 0.6)
		var sb := S("base")
		# фундамент-платформа: плиты с пазами, болты, жёлтые полосы по краю
		sb.box(Vector3(0, 0.08, 0), Vector3(W, 0.08, W), 0.04, col_dark, Vector3.ZERO, 0.02)
		sb.box(Vector3(0, 0.17, 0), Vector3(W * 0.95, 0.03, W * 0.95), 0.02, col_metal.darkened(0.2), Vector3.ZERO, 0.01)
		groove(sb, Vector3(0, 0.2, 0), Vector3(W * 0.97, 0.012, 0.012))
		groove(sb, Vector3(0, 0.2, 0), Vector3(0.012, 0.012, W * 0.97))
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				sb.cylinder(Vector3(cx * W * 0.85, 0.2, cz * W * 0.85), 0.05, 0.03, 0.01, col_metal, Vector3.ZERO, 0.005)
		match kind:
			"furnace":
				sb.box(Vector3(0, 0.2 + Hh * 0.35, 0), Vector3(W * 0.7, Hh * 0.35, W * 0.65), 0.12, col_main, Vector3.ZERO, 0.05, SdfMesh.OP_ADD, rough * 0.5)
				sb.box(Vector3(W * 0.62, 0.2 + Hh * 0.25, 0), Vector3(0.12, Hh * 0.2, W * 0.32), 0.06, col_dark, Vector3.ZERO, 0.03, SdfMesh.OP_SUB)
				G("base").box(Vector3(W * 0.55, 0.2 + Hh * 0.22, 0), Vector3(0.05, Hh * 0.14, W * 0.26), 0.04, Color("#ff7a20"), Vector3.ZERO, 0.0)
				seg_mat["base_glow"] = {"anim": "flicker"}
				for i in 4:
					sb.box(Vector3(-W * 0.3 + i * W * 0.2, 0.2 + Hh * 0.72, 0), Vector3(0.04, 0.02, W * 0.66), 0.01, col_metal, Vector3.ZERO, 0.01)
				sb.cylinder(Vector3(-W * 0.35, 0.2 + Hh * 0.95, -W * 0.3), 0.16, Hh * 0.4, 0.03, col_dark, Vector3.ZERO, 0.03)
				sb.cylinder(Vector3(-W * 0.35, 0.2 + Hh * 1.33, -W * 0.3), 0.2, 0.04, 0.02, col_metal, Vector3.ZERO, 0.01)
				sb.cylinder(Vector3(-W * 0.35, 0.2 + Hh * 1.36, -W * 0.3), 0.11, 0.2, 0.0, col_dark, Vector3.ZERO, 0.0, SdfMesh.OP_SUB)
				parts_extra.append({"fx": "smoke", "pos": [-W * 0.35, 0.2 + Hh * 1.4, -W * 0.3]})
			"drill":
				for cx in [-1.0, 1.0]:
					for cz in [-1.0, 1.0]:
						var a := Vector3(cx * W * 0.7, 0.2, cz * W * 0.7)
						var top := Vector3(cx * W * 0.25, Hh, cz * W * 0.25)
						sb.capsule(a, top, 0.07, 0.05, col_main, 0.02)
						sb.capsule(a.lerp(top, 0.33), Vector3(-cx * W * 0.45, 0.2 + Hh * 0.35, cz * W * 0.45), 0.03, 0.03, col_main.darkened(0.2), 0.01)
				sb.box(Vector3(0, Hh, 0), Vector3(W * 0.35, 0.14, W * 0.35), 0.05, col_acc, Vector3.ZERO, 0.03)
				sb.box(Vector3(W * 0.45, 0.2 + 0.4, 0), Vector3(0.25, 0.35, W * 0.3), 0.08, col_main, Vector3.ZERO, 0.03)
				vents(sb, Vector3(W * 0.7, 0.6, 0), 4, Vector3(0, 0, 0.1), Vector3(0.02, 0.18, 0.03))
				var sd := S("drill")
				sd.cylinder(Vector3(0, Hh * 0.55, 0), 0.08, Hh * 0.45, 0.02, col_metal.lightened(0.2), Vector3.ZERO, 0.01)
				for i in 10:
					var y := 0.3 + i * Hh * 0.08
					sd.torus(Vector3(0, y, 0), 0.14, 0.03, col_metal, Vector3(8 * (1 if i % 2 == 0 else -1), i * 36.0, 0), 0.01)
				seg_mat["drill"] = {"anim": "spin_fast", "pivot": [0, 0, 0]}
				var sm := S("motor")
				sm.cylinder(Vector3(0, Hh + 0.3, 0), 0.24, 0.18, 0.05, col_dark, Vector3.ZERO, 0.03)
				vents(sm, Vector3(0, Hh + 0.3, 0.24), 4, Vector3(0, 0.07, 0), Vector3(0.12, 0.015, 0.03))
				G("base").sphere(Vector3(W * 0.71, 0.85, W * 0.2), 0.04, col_glow)
			"turbine":
				sb.cylinder(Vector3(0, 0.2 + Hh * 0.45, 0), 0.16, Hh * 0.45, 0.03, col_metal.lightened(0.15), Vector3.ZERO, 0.03)
				sb.cylinder(Vector3(0, 0.25, 0), 0.32, 0.08, 0.03, col_dark, Vector3.ZERO, 0.03)
				sb.box(Vector3(0, 0.2 + Hh * 0.92, 0), Vector3(0.38, 0.17, 0.17), 0.1, col_main, Vector3.ZERO, 0.04)
				var sr := S("rotor")
				var hub := Vector3(0.42, 0.2 + Hh * 0.92, 0)
				sr.sphere(hub, 0.12, col_acc, 0.02)
				for i in 3:
					var a := i * TAU / 3.0
					var dir := Vector3(0, cos(a), sin(a))
					sr.ellipsoid(hub + dir * Hh * 0.22, Vector3(0.03, Hh * 0.22, 0.09), Color("#e8e8e4"), Vector3(rad_to_deg(a), 0, 12), 0.03)
				seg_mat["rotor"] = {"anim": "spin_wind", "spin_axis": [1, 0, 0], "center": [hub.x, hub.y, hub.z]}
			"tank":
				sb.cylinder(Vector3(0, 0.2 + Hh * 0.5, 0), W * 0.72, Hh * 0.45, 0.25, col_main, Vector3.ZERO, 0.05)
				for i in 3:
					sb.torus(Vector3(0, 0.3 + Hh * (0.18 + i * 0.3), 0), W * 0.72, 0.03, col_metal, Vector3.ZERO, 0.01)
				sb.capsule(Vector3(W * 0.7, 0.3, W * 0.4), Vector3(W * 0.7, 0.2 + Hh * 0.9, W * 0.4), 0.025, 0.025, col_metal, 0.01)
				G("base").box(Vector3(W * 0.72, 0.2 + Hh * 0.5, 0), Vector3(0.02, Hh * 0.3, 0.05), 0.01, col_glow, Vector3.ZERO, 0.0)
			"storage":
				sb.box(Vector3(0, 0.2 + Hh * 0.5, 0), Vector3(W * 0.8, Hh * 0.5, W * 0.7), 0.08, col_main, Vector3.ZERO, 0.03, SdfMesh.OP_ADD, rough * 0.5)
				for i in 5:
					sb.box(Vector3(W * 0.8, 0.2 + Hh * 0.5, -W * 0.5 + i * W * 0.25), Vector3(0.02, Hh * 0.42, 0.025), 0.01, col_main.darkened(0.25), Vector3.ZERO, 0.01)
				sb.box(Vector3(0, 0.2 + Hh, 0), Vector3(W * 0.82, 0.04, W * 0.72), 0.02, col_acc, Vector3.ZERO, 0.01)
				bolts(sb, Vector3(W * 0.82, 0.2 + Hh * 0.95, -W * 0.6), Vector3(W * 0.82, 0.2 + Hh * 0.95, W * 0.6), 6, 0.025)
			"tower":
				for cx in [-1.0, 1.0]:
					for cz in [-1.0, 1.0]:
						sb.capsule(Vector3(cx * W * 0.6, 0.2, cz * W * 0.6), Vector3(cx * W * 0.15, Hh, cz * W * 0.15), 0.06, 0.04, col_main, 0.02)
				for i in 4:
					var y := 0.2 + Hh * (0.2 + i * 0.2)
					var w2 := lerpf(W * 0.6, W * 0.15, (y - 0.2) / Hh)
					sb.box(Vector3(0, y, 0), Vector3(w2, 0.025, w2), 0.01, col_main.darkened(0.15), Vector3.ZERO, 0.01)
				var sr2 := S("rotor")
				sr2.cylinder(Vector3(0, Hh + 0.15, 0), 0.12, 0.12, 0.03, col_dark, Vector3.ZERO, 0.02)
				sr2.ellipsoid(Vector3(0.25, Hh + 0.4, 0), Vector3(0.08, 0.35, 0.5), col_metal.lightened(0.2), Vector3(0, 0, 25), 0.03)
				seg_mat["rotor"] = {"anim": "spin_slow", "center": [0, Hh, 0]}
				G("base").sphere(Vector3(0, Hh + 0.32, 0), 0.06, Color("#ff3030"))
				seg_mat["base_glow"] = {"anim": "blink"}
			_:
				# машина: корпус с панелями, баки, трубы, вентилятор
				sb.box(Vector3(-W * 0.1, 0.2 + Hh * 0.45, 0), Vector3(W * 0.6, Hh * 0.45, W * 0.6), 0.1, col_main, Vector3.ZERO, 0.04, SdfMesh.OP_ADD, rough * 0.5)
				groove(sb, Vector3(-W * 0.1, 0.2 + Hh * 0.6, 0), Vector3(W * 0.62, 0.012, W * 0.62))
				sb.box(Vector3(W * 0.5, 0.2 + Hh * 0.3, 0), Vector3(0.05, Hh * 0.22, W * 0.35), 0.03, col_dark, Vector3.ZERO, 0.02, SdfMesh.OP_SUB)
				G("base").box(Vector3(W * 0.48, 0.2 + Hh * 0.3, 0), Vector3(0.02, Hh * 0.1, W * 0.2), 0.02, col_glow, Vector3.ZERO, 0.0)
				seg_mat["base_glow"] = {"anim": "pulse"}
				for side in [-1.0, 1.0]:
					sb.cylinder(Vector3(-W * 0.35, 0.2 + Hh * 1.05, side * W * 0.3), 0.18, 0.25, 0.08, col_metal, Vector3(90, 0, 0), 0.02)
				hose(sb, [Vector3(W * 0.3, 0.2 + Hh * 0.9, W * 0.45), Vector3(W * 0.6, 0.2 + Hh * 0.7, W * 0.55), Vector3(W * 0.75, 0.25, W * 0.55)], 0.04, col_dark)
				var sf := S("fan")
				var fc := Vector3(W * 0.15, 0.2 + Hh * 0.93, 0)
				sf.torus(fc, 0.24, 0.03, col_dark, Vector3.ZERO, 0.0)
				for i in 5:
					var a := i * TAU / 5.0
					sf.box(fc + Vector3(cos(a) * 0.11, 0, sin(a) * 0.11), Vector3(0.1, 0.008, 0.04), 0.005, col_metal, Vector3(10, -rad_to_deg(a), 0), 0.0)
				seg_mat["fan"] = {"anim": "spin_fan", "center": [fc.x, fc.y, fc.z]}
		if spec.feat.has("pipes"):
			hose(sb, [Vector3(-W * 0.8, 0.25, -W * 0.8), Vector3(-W * 0.8, 0.2 + Hh * 0.6, -W * 0.8), Vector3(-W * 0.2, 0.2 + Hh * 0.75, -W * 0.6)], 0.05, col_metal)
		if spec.feat.has("panels"):
			sb.box(Vector3(0, 0.2 + Hh + 0.08, 0), Vector3(W * 0.5, 0.025, W * 0.45), 0.01, Color("#1d2b4f"), Vector3(0, 0, 18), 0.0)
		if spec.feat.has("lights"):
			G("base").sphere(Vector3(W * 0.7, 0.2 + Hh * 0.8, W * 0.6), 0.06, Color("#fff2c0"))

	func _has(d: String, words: Array) -> bool:
		for w in words:
			if d.find(w) >= 0:
				return true
		return false

	# ================================================= выпечка

	## Построить меши всех частей (в несколько потоков). Возвращает {имя_части: ArrayMesh}.
	func bake(res: int, tris: int, threads := true) -> Dictionary:
		var jobs := []
		for b in segs:
			jobs.append([b, segs[b], false])
		for b in glow:
			jobs.append([b + "_glow", glow[b], true])
		var results := []
		results.resize(jobs.size())
		var total := 0
		for j in jobs:
			total += (j[1] as SdfMesh).count()
		var task := func(i: int):
			var s: SdfMesh = jobs[i][1]
			# доля бюджета треугольников — по числу фигур в части
			var share := float(s.count()) / maxf(1.0, total)
			var rr := res if not jobs[i][2] else maxi(24, res / 2)
			results[i] = s.build(rr, maxi(120, int(tris * 4.0 * share)))
		if threads and jobs.size() > 1:
			var tid := WorkerThreadPool.add_group_task(task, jobs.size(), -1, true, "modelgen")
			WorkerThreadPool.wait_for_group_task_completion(tid)
		else:
			for i in jobs.size():
				task.call(i)
		var out := {}
		for i in jobs.size():
			if results[i] != null:
				var nm: String = jobs[i][0]
				var sm: Dictionary = seg_mat.get(nm, {})
				out[nm] = _recenter(results[i], sm) if sm.has("center") else results[i]
		return out

	## Вращающаяся часть (винт, вентилятор): переносим меш так, чтобы ось вращения шла через его начало
	## по локальной оси Y — так её крутит анимация «spin». Деталь потом ставится в центр с поворотом spin_rot().
	static func spin_rot(sm: Dictionary) -> Vector3:
		var ax := ModelLib.v3(sm.get("spin_axis", [0, 1, 0]), Vector3.UP).normalized()
		if ax.is_equal_approx(Vector3.UP):
			return Vector3.ZERO
		if ax.is_equal_approx(Vector3.RIGHT):
			return Vector3(0, 0, -90)
		if ax.is_equal_approx(Vector3.BACK) or ax.is_equal_approx(Vector3.FORWARD):
			return Vector3(90, 0, 0)
		return Basis(Quaternion(Vector3.UP, ax)).get_euler() * (180.0 / PI)

	func _recenter(mesh: ArrayMesh, sm: Dictionary) -> ArrayMesh:
		var c := ModelLib.v3(sm.center)
		var inv := Basis.from_euler(spin_rot(sm) * (PI / 180.0)).inverse()
		var out := ArrayMesh.new()
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in vs.size():
				vs[i] = inv * (vs[i] - c)
			arr[Mesh.ARRAY_VERTEX] = vs
			if arr[Mesh.ARRAY_NORMAL] != null:
				var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in ns.size():
					ns[i] = inv * ns[i]
				arr[Mesh.ARRAY_NORMAL] = ns
			arr[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return out

	func model_dict(mid: String, dir: String, meshes: Dictionary) -> Dictionary:
		var parts := []
		var is_hero := not hero_bones.is_empty()
		var hero_piv := {}
		if is_hero:
			var par := {"leg_l": "hips", "leg_r": "hips", "shin_l": "leg_l", "shin_r": "leg_r", "torso": "hips", "head": "torso",
				"arm_l": "torso", "arm_r": "torso", "fore_l": "arm_l", "fore_r": "arm_r", "hand_r": "fore_r", "gun": "hand_r"}
			for bn in ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r", "gun"]:
				hero_piv[bn] = ModelLib.v3(hero_bones.get(bn, [0, 0, 0])) + (hero_piv[par[bn]] if par.has(bn) else Vector3.ZERO)
		for key in meshes:
			var g: bool = key.ends_with("_glow")
			var b: String = key.trim_suffix("_glow")
			var sm: Dictionary = seg_mat.get(key if g else b, {})
			var p := {"shape": "mesh", "mesh": "%s/%s/%s.res" % [dir, mid, key], "pos": [0, 0, 0], "size": [1, 1, 1], "color": "#ffffff",
				"mat": "glow" if g else ("paint" if not mech else "metal"), "tint": not g, "gen": true}
			if g:
				p["emission"] = 2.2
			else:
				p["metallic"] = 0.45 if mech else 0.05
				p["roughness"] = 0.45 if mech else 0.75
			if str(sm.get("anim", "")) != "":
				p["anim"] = sm.anim
			if sm.has("center"):
				p["pos"] = sm.center
				var r := spin_rot(sm)
				p["rot"] = [r.x, r.y, r.z]
			if hero_bones.is_empty() and not bones.is_empty():
				p["role"] = b
			elif is_hero:
				p["role"] = b
			elif sm.has("role") or b == "head":
				p["role"] = "head"
			parts.append(p)
		var m := {"name": name, "category": category, "parts": parts, "gen": {"desc": spec.desc, "seed": int(opts.get("seed", 1)), "quality": int(opts.get("quality", 1)), "arch": spec.arch}}
		if is_hero:
			m["bones"] = hero_bones
			m["scale"] = 1.25
		elif not rig.is_empty():
			m["rig"] = rig
			m["toon"] = true
		if not parts_extra.is_empty():
			m["fx"] = parts_extra
		return m
