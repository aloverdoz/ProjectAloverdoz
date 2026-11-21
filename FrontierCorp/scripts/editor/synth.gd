class_name EdSynth
extends RefCounted
## Генератор звуков без файлов (как sfxr): выстрелы, взрывы, удары, монетки, рык монстров...
## Параметры — простой словарь, его можно сохранить вместе со звуком и потом подправить.

const RATE := 22050
const WAVES := ["square", "saw", "sine", "triangle", "noise"]
const WAVE_NAMES := ["Квадрат (8-бит)", "Пила (резкий)", "Синус (мягкий)", "Треугольник", "Шум"]

## Готовые заготовки. Каждое нажатие даёт немного другой звук.
const PRESETS := {
	"shot": {"name": "Выстрел", "wave": "noise", "freq": 900.0, "freq_end": 120.0, "attack": 0.0, "sustain": 0.02, "decay": 0.2, "noise": 0.6, "punch": 0.5, "lowpass": 0.7},
	"laser": {"name": "Лазер", "wave": "square", "freq": 1300.0, "freq_end": 260.0, "attack": 0.0, "sustain": 0.05, "decay": 0.18, "duty": 0.3},
	"boom": {"name": "Взрыв", "wave": "noise", "freq": 160.0, "freq_end": 40.0, "attack": 0.0, "sustain": 0.1, "decay": 0.9, "noise": 1.0, "punch": 0.7, "lowpass": 0.35, "volume": 0.55},
	"hit": {"name": "Удар / рубка", "wave": "noise", "freq": 220.0, "freq_end": 90.0, "attack": 0.0, "sustain": 0.01, "decay": 0.12, "noise": 0.7, "punch": 0.6, "lowpass": 0.5},
	"pickup": {"name": "Подбор / монетка", "wave": "square", "freq": 880.0, "freq_end": 880.0, "attack": 0.0, "sustain": 0.05, "decay": 0.22, "arp": 1.5, "arp_time": 0.06, "duty": 0.5},
	"jump": {"name": "Прыжок", "wave": "square", "freq": 280.0, "freq_end": 720.0, "attack": 0.0, "sustain": 0.06, "decay": 0.18, "duty": 0.4},
	"roar": {"name": "Рык монстра", "wave": "saw", "freq": 110.0, "freq_end": 70.0, "attack": 0.05, "sustain": 0.3, "decay": 0.4, "vib_depth": 0.25, "vib_speed": 9.0, "noise": 0.35, "lowpass": 0.4},
	"bite": {"name": "Укус / писк", "wave": "square", "freq": 620.0, "freq_end": 980.0, "attack": 0.0, "sustain": 0.02, "decay": 0.1, "duty": 0.25},
	"click": {"name": "Клик интерфейса", "wave": "sine", "freq": 1250.0, "freq_end": 1100.0, "attack": 0.0, "sustain": 0.0, "decay": 0.04},
	"alarm": {"name": "Тревога", "wave": "square", "freq": 620.0, "freq_end": 620.0, "attack": 0.02, "sustain": 1.0, "decay": 0.2, "vib_depth": 0.25, "vib_speed": 3.0, "duty": 0.5},
	"step": {"name": "Шаг", "wave": "noise", "freq": 300.0, "freq_end": 200.0, "attack": 0.0, "sustain": 0.01, "decay": 0.06, "noise": 1.0, "lowpass": 0.25},
	"hum": {"name": "Гул машины", "wave": "saw", "freq": 55.0, "freq_end": 55.0, "attack": 0.1, "sustain": 1.2, "decay": 0.1, "noise": 0.15, "lowpass": 0.3, "vib_depth": 0.02, "vib_speed": 6.0},
	"power_up": {"name": "Улучшение / уровень", "wave": "square", "freq": 330.0, "freq_end": 990.0, "attack": 0.0, "sustain": 0.25, "decay": 0.3, "arp": 1.26, "arp_time": 0.08, "duty": 0.5},
	"zap": {"name": "Электричество", "wave": "saw", "freq": 900.0, "freq_end": 300.0, "attack": 0.0, "sustain": 0.1, "decay": 0.2, "noise": 0.5, "vib_depth": 0.5, "vib_speed": 40.0},
	"splash": {"name": "Всплеск воды", "wave": "noise", "freq": 600.0, "freq_end": 200.0, "attack": 0.02, "sustain": 0.05, "decay": 0.4, "noise": 1.0, "lowpass": 0.45},
}

## Ползунки: ключ, подпись, мин, макс, шаг.
const SLIDERS := [
	["freq", "Высота в начале, Гц", 30.0, 3000.0, 1.0],
	["freq_end", "Высота в конце, Гц", 20.0, 3000.0, 1.0],
	["attack", "Нарастание, сек", 0.0, 1.0, 0.01],
	["sustain", "Держится, сек", 0.0, 2.0, 0.01],
	["decay", "Затухание, сек", 0.0, 2.0, 0.01],
	["punch", "Удар в начале", 0.0, 1.0, 0.05],
	["noise", "Шум", 0.0, 1.0, 0.05],
	["lowpass", "Глухость", 0.0, 1.0, 0.05],
	["vib_depth", "Дрожание (сила)", 0.0, 1.0, 0.01],
	["vib_speed", "Дрожание (скорость)", 0.0, 50.0, 0.5],
	["arp", "Скачок высоты (×)", 0.0, 3.0, 0.01],
	["arp_time", "Когда скачок, сек", 0.0, 1.0, 0.01],
	["duty", "Тембр (для квадрата)", 0.05, 0.5, 0.01],
	["volume", "Громкость", 0.1, 1.0, 0.05],
]


static func defaults() -> Dictionary:
	return {"wave": "square", "freq": 440.0, "freq_end": 440.0, "attack": 0.0, "sustain": 0.1, "decay": 0.2, "punch": 0.0,
		"noise": 0.0, "lowpass": 0.0, "vib_depth": 0.0, "vib_speed": 0.0, "arp": 0.0, "arp_time": 0.0, "duty": 0.5, "volume": 0.7}


## Заготовка со случайными небольшими отличиями.
static func preset(id: String, vary := 0.15) -> Dictionary:
	var p := defaults()
	p.merge(PRESETS.get(id, {}), true)
	p.erase("name")
	return mutate(p, vary)


static func mutate(p: Dictionary, vary: float) -> Dictionary:
	var o := p.duplicate()
	if vary <= 0.0:
		return o
	for k in ["freq", "freq_end", "sustain", "decay", "vib_speed"]:
		o[k] = maxf(0.0, float(o[k]) * (1.0 + randf_range(-vary, vary) * 1.5))
	for k in ["noise", "lowpass", "punch", "vib_depth"]:
		if float(o[k]) > 0.0:
			o[k] = clampf(float(o[k]) + randf_range(-vary, vary) * 0.5, 0.0, 1.0)
	o["freq"] = clampf(float(o.freq), 20.0, 4000.0)
	o["freq_end"] = clampf(float(o.freq_end), 20.0, 4000.0)
	return o


static func length(p: Dictionary) -> float:
	return maxf(0.02, float(p.get("attack", 0)) + float(p.get("sustain", 0)) + float(p.get("decay", 0)))


## Сгенерировать звук. Возвращает 16-битный моно WAV.
static func make(p: Dictionary) -> AudioStreamWAV:
	var n := int(length(p) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var wave := str(p.get("wave", "square"))
	var f0 := float(p.get("freq", 440))
	var f1 := float(p.get("freq_end", f0))
	var at := float(p.get("attack", 0))
	var su := float(p.get("sustain", 0))
	var de := float(p.get("decay", 0.2))
	var punch := float(p.get("punch", 0))
	var nz := float(p.get("noise", 0))
	var lp := float(p.get("lowpass", 0))
	var vd := float(p.get("vib_depth", 0))
	var vs := float(p.get("vib_speed", 0))
	var arp := float(p.get("arp", 0))
	var arp_t := float(p.get("arp_time", 0))
	var duty := clampf(float(p.get("duty", 0.5)), 0.02, 0.98)
	var vol := float(p.get("volume", 0.7))
	var total := length(p)
	var phase := 0.0
	var filt := 0.0
	var k_lp := 1.0 - clampf(lp, 0.0, 0.97)
	var noise_v := 0.0
	var noise_phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(p))
	for i in n:
		var t := float(i) / RATE
		var u := t / total
		# высота: плавный переход от начала к концу (по экспоненте — звучит естественнее)
		var f := f0 * pow(f1 / f0, u) if f0 > 0.0 and f1 > 0.0 else f0
		if arp > 0.0 and t >= arp_t:
			f *= arp
		if vd > 0.0:
			f *= 1.0 + sin(TAU * vs * t) * vd * 0.5
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < duty else -1.0
			"saw":
				s = phase * 2.0 - 1.0
			"sine":
				s = sin(TAU * phase)
			"triangle":
				s = 1.0 - absf(phase * 4.0 - 2.0)
			"noise":
				s = 0.0
		# шум меняется с частотой тона — так «шумные» звуки тоже имеют высоту
		noise_phase += f / RATE * 8.0
		if noise_phase >= 1.0:
			noise_phase = fmod(noise_phase, 1.0)
			noise_v = rng.randf_range(-1.0, 1.0)
		if wave == "noise":
			s = noise_v
		elif nz > 0.0:
			s = lerpf(s, noise_v, nz)
		# огибающая
		var env := 1.0
		if t < at:
			env = t / maxf(0.0001, at)
		elif t < at + su:
			env = 1.0 + punch * (1.0 - (t - at) / maxf(0.0001, su))
		else:
			env = (1.0 - (t - at - su) / maxf(0.0001, de)) * (1.0 if su > 0.0 else 1.0 + punch)
		env = clampf(env, 0.0, 2.0)
		s *= env
		filt += (s - filt) * k_lp
		var v := clampf(filt * vol, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Короткая выборка для рисования волны.
static func peaks(w: AudioStreamWAV, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var n := w.data.size() / 2
	if n == 0:
		return out
	var step := maxi(1, n / count)
	for c in count:
		var m := 0.0
		var a := c * step
		for i in range(a, mini(n, a + step), maxi(1, step / 32)):
			m = maxf(m, absf(w.data.decode_s16(i * 2) / 32000.0))
		out[c] = m
	return out
