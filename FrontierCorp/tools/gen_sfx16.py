# 16: звуки подколов (подушка, гудок, хлопушка, салют, кирпич). Запуск: python3 tools/gen_sfx16.py sounds
import numpy as np, wave, sys, os
SR = 22050
out = sys.argv[1]
rng = np.random.default_rng(16)
def env(n, a, d, curve=3.0):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t * curve / max(d, 1e-4))
def lp(x, k):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc); y[i] = acc
    return y
def save(name, x, vol=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
def secs(s): return int(SR * s)
# подушка: низкое дребезжание с дрожащей частотой
n = secs(0.9); t = np.arange(n) / SR
f = 85 + 25 * np.sin(2*np.pi*7*t) + 30 * np.exp(-t*3) + rng.normal(0, 6, n).cumsum() / 200
ph = 2*np.pi*np.cumsum(f) / SR
x = (np.sign(np.sin(ph)) * 0.6 + np.sin(ph*2) * 0.3) * (1 + 0.5*np.sin(2*np.pi*31*t)) * env(n, 0.03, 0.7, 1.5)
save("fart", lp(x, 0.18), 0.8)
# гудок: два тона
n = secs(1.1); t = np.arange(n) / SR
x = (np.sign(np.sin(2*np.pi*311*t)) + np.sign(np.sin(2*np.pi*392*t))) * np.minimum(1, t/0.02) * np.minimum(1, (1.1-t)/0.08)
save("horn", lp(x, 0.3), 0.7)
# хлопушка
n = secs(0.3); t = np.arange(n) / SR
x = rng.uniform(-1, 1, n) * env(n, 0.001, 0.05, 4) + np.sin(2*np.pi*(900*np.exp(-t*20))*t) * env(n, 0.001, 0.1, 3) * 0.5
save("pop", x, 0.7)
# салют: свист вверх и треск
n = secs(1.8); t = np.arange(n) / SR
wh = np.sin(2*np.pi*np.cumsum(900 + 1400*t/0.8)/SR) * (t < 0.8) * 0.3
cr = rng.uniform(-1, 1, n) * (t > 0.85) * env(n, 0.001, 0.9, 2) * (rng.uniform(0, 1, n) > 0.6)
bang = lp(rng.uniform(-1, 1, n), 0.1) * (t > 0.8) * np.exp(-(t-0.8)*5) * 2
save("firework", wh + cr + bang, 0.85)
# кирпич: глухой удар
n = secs(0.35); t = np.arange(n) / SR
x = np.sin(2*np.pi*(140*np.exp(-t*6))*t) * env(n, 0.001, 0.15, 3) + lp(rng.uniform(-1, 1, n), 0.25) * env(n, 0.001, 0.04, 4)
save("bonk", x, 0.8)
