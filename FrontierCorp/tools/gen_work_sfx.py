# Звуки работы зданий: бесшовные петли по 4 секунды, 44,1 кГц.
# Каждый звук синтезируется из шума, тонов и ударов — без чужих записей. Запуск: python3 tools/gen_work_sfx.py sounds
import numpy as np, wave, sys, os
from scipy.signal import butter, lfilter

SR = 44100
LOOP = 4.0
OUT = sys.argv[1] if len(sys.argv) > 1 else "sounds"
rng = np.random.default_rng(11)
N = int(SR * LOOP)
FADE = int(SR * 0.25)
T = np.arange(N + FADE) / SR


def noise(n=None):
    return rng.uniform(-1, 1, n or len(T))


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def lowp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highp(x, f, order=2):
    b, a = butter(order, f / (SR / 2), btype="high")
    return lfilter(b, a, x)


def brown():
    x = np.cumsum(noise())
    x -= lowp(x, 8)
    return x / (np.max(np.abs(x)) + 1e-9)


def tone(f, harm=(1.0,), wob=0.0, wf=0.5):
    ph = 2 * np.pi * np.cumsum(f * (1 + wob * np.sin(2 * np.pi * wf * T))) / SR
    return sum(a * np.sin((i + 1) * ph) for i, a in enumerate(harm))


def hits(rate, dur, f_lo, f_hi, jitter=0.0, amp_var=0.0, seed=0):
    """Ряд ударов с периодом, кратным длине петли (чтобы ритм не сбивался на стыке)."""
    r = np.random.default_rng(seed)
    out = np.zeros(len(T))
    n_hits = int(round(rate * LOOP))
    step = N / n_hits
    k = int(SR * dur)
    env = np.exp(-np.arange(k) / (SR * dur / 5))
    burst_src = bp(r.uniform(-1, 1, k * 4), f_lo, f_hi)
    for i in range(n_hits + 1):
        s = int(i * step + r.uniform(-jitter, jitter) * SR)
        if s < 0 or s >= len(T):
            continue
        b = burst_src[r.integers(0, k * 3):][:k] * env * (1 - amp_var * r.random())
        e = min(len(T), s + k)
        out[s:e] += b[:e - s]
    return out


def thumps(rate, f0, dur, seed=0):
    out = np.zeros(len(T))
    n_hits = int(round(rate * LOOP))
    step = N / n_hits
    k = int(SR * dur)
    t = np.arange(k) / SR
    th = np.sin(2 * np.pi * f0 * np.exp(-t * 6) * t) * np.exp(-t * 8 / dur)
    for i in range(n_hits + 1):
        s = int(i * step)
        e = min(len(T), s + k)
        if s < len(T):
            out[s:e] += th[:e - s]
    return out


def crackle(density, f_lo=1500, f_hi=9000, seed=0):
    r = np.random.default_rng(seed)
    x = np.zeros(len(T))
    idx = r.integers(0, len(T), int(density * LOOP))
    x[idx] = r.uniform(-1, 1, len(idx))
    return bp(x, f_lo, f_hi) * 6


def bubbles(density, f_lo=200, f_hi=900, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros(len(T))
    for _ in range(int(density * LOOP)):
        f = r.uniform(f_lo, f_hi)
        k = int(SR * r.uniform(0.03, 0.09))
        t = np.arange(k) / SR
        b = np.sin(2 * np.pi * f * (1 + t * 12) * t) * np.sin(np.pi * t / t[-1])
        s = r.integers(0, len(T) - k)
        out[s:s + k] += b * r.uniform(0.3, 1.0)
    return out


def norm(x):
    return x / (np.max(np.abs(x)) + 1e-9)


def save(name, x, vol=0.8):
    x = norm(x)
    # бесшовная петля: хвост плавно накладывается на начало
    fi = np.linspace(0, 1, FADE)
    y = x[:N].copy()
    y[:FADE] = x[:FADE] * fi + x[N:N + FADE] * (1 - fi)
    y = norm(y) * vol
    data = (y * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())


lfo = lambda f, d=0.5: 1 - d + d * (0.5 + 0.5 * np.sin(2 * np.pi * f * T))

# печь и плавка: гул пламени, треск, бульканье металла
save("work_smelt", lowp(brown(), 400) * 1.2 * lfo(0.5, 0.3) + crackle(60, seed=1) * 0.25 + lowp(bubbles(10, 60, 180, seed=2), 600) * 0.6 + tone(50, (1, 0.4)) * 0.15)
# бур: мотор, удары перфоратора, скрежет породы
save("work_drill", tone(92, (1, 0.7, 0.5, 0.35, 0.2), 0.01, 3) * 0.35 + hits(8, 0.06, 300, 2500, seed=3) * 0.8 + bp(noise(), 800, 3500) * lfo(4, 0.6) * 0.35 + lowp(brown(), 120) * 0.5)
# лесопилка: визг пилы, распил, стук
save("work_saw", tone(1950, (1, 0.3), 0.02, 2) * 0.12 * lfo(0.5, 0.8) + bp(noise(), 2500, 7000) * lfo(0.5, 0.9) * 0.5 + tone(120, (1, 0.5, 0.3)) * 0.2 + hits(1, 0.12, 150, 900, seed=4) * 0.6)
# пресс: удар раз в секунду, лязг, шипение гидравлики
save("work_press", thumps(1, 70, 0.4) * 1.0 + hits(1, 0.15, 1500, 5000, seed=5) * 0.4 + bp(noise(), 1500, 6000) * np.clip(np.sin(2 * np.pi * 1 * T - 1.5), 0, 1) ** 2 * 0.12 + tone(60, (1, 0.5)) * 0.1)
# дробилка: грохот камней, мотор
save("work_crush", hits(28, 0.05, 200, 3000, jitter=0.05, amp_var=0.7, seed=6) * 0.7 + lowp(brown(), 200) * 0.8 + tone(75, (1, 0.6, 0.3), 0.02, 1) * 0.25)
# сборщик: сервоприводы, щелчки, пневматика
save("work_assembly", tone(420, (1, 0.4), 0.25, 0.5) * 0.12 * lfo(1, 0.9) + hits(4, 0.02, 1000, 5000, seed=7) * 0.5 + bp(noise(), 1500, 7000) * np.clip(np.sin(2 * np.pi * 0.5 * T), 0, 1) ** 6 * 0.2 + tone(100, (1, 0.3)) * 0.12)
# электричество: гул 100 Гц, искры
save("work_electric", tone(100, (1, 0.6, 0.4, 0.3, 0.2, 0.15)) * 0.4 + crackle(25, 3000, 12000, seed=8) * 0.2 + tone(1000, (1,)) * 0.02 * lfo(3, 1))
# химия: бульканье, насос
save("work_bubble", bubbles(40, 150, 700, seed=9) * 0.6 + tone(55, (1, 0.5)) * 0.25 * lfo(0.5, 0.3) + lowp(noise(), 600) * 0.1)
# кухня: шкворчание и кипение
save("work_cook", highp(crackle(800, 2000, 12000, seed=10), 2500) * 0.4 + bp(noise(), 3000, 9000) * 0.12 + bubbles(12, 100, 300, seed=11) * 0.4)
# ткацкий станок: челнок стучит, жужжит
save("work_loom", hits(3, 0.07, 400, 1800, seed=12) * 0.9 + hits(3, 0.05, 800, 3000, seed=13) * 0.3 * 0 + tone(140, (1, 0.4), 0.05, 3) * 0.15)
# генератор на топливе: вспышки цилиндров, выхлоп
eng = np.sin(2 * np.pi * 25 * T)
save("work_engine", lowp(np.clip(eng, 0, 1) ** 8 * noise() + np.clip(eng, 0.7, 1) * 0.6, 900) * 1.0 + tone(25, (1, 0.8, 0.5, 0.4, 0.3)) * 0.3 + lowp(brown(), 300) * 0.3)
# газовая турбина: свист и рёв
save("work_turbine", tone(1180, (1, 0.25), 0.003, 0.25) * 0.15 + bp(noise(), 300, 4000) * 0.4 + lowp(brown(), 150) * 0.5)
# ветряк: «вжух» лопастей и редуктор
save("work_wind", bp(noise(), 200, 1200) * np.clip(np.sin(2 * np.pi * 1.5 * T), 0, 1) ** 3 * 0.7 + tone(60, (1, 0.3)) * 0.12 + lowp(noise(), 300) * 0.15)
# водяное колесо: вода и скрип дерева
save("work_water", bp(noise(), 400, 3000) * lfo(0.75, 0.4) * 0.5 + bubbles(30, 300, 1200, seed=14) * 0.3 + hits(0.75, 0.25, 250, 600, seed=15) * 0.3)
# реактор: глубокий гул, переливы, тиканье
save("work_reactor", tone(40, (1, 0.7, 0.3)) * 0.5 * lfo(0.25, 0.3) + tone(660, (1, 0.5), 0.02, 0.25) * 0.05 + crackle(20, 4000, 12000, seed=16) * 0.15 + lowp(brown(), 80) * 0.4)
# насос: ход поршня, всасывание
save("work_pump", lowp(noise(), 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.5 * T)) ** 2 * 0.6 + thumps(1.5, 55, 0.25) * 0.5 + tone(80, (1, 0.4)) * 0.15)
# печь на дровах и биотопливе: треск костра
save("work_burner", crackle(220, 800, 7000, seed=17) * 0.5 + lowp(brown(), 300) * 0.8 * lfo(0.5, 0.4))
# лаборатория: писк приборов и гул компьютеров
beep = np.sin(2 * np.pi * 1760 * T) * (np.sin(2 * np.pi * 2 * T) > 0.92)
save("work_lab", beep * 0.15 + tone(120, (1, 0.3)) * 0.15 + bp(noise(), 2000, 6000) * 0.04 + tone(880, (1,)) * (np.sin(2 * np.pi * 0.5 * T + 1) > 0.97) * 0.12)
print("work sounds ok")
