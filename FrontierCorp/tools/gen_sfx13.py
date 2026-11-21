# 1.3: звуки «отклика»: новый уровень, задание выполнено, взмах, прыжок, приземление, снос, раскол камня,
# щелчок сетки стройки, отказ. Запуск: python3 tools/gen_sfx13.py sounds
import numpy as np, wave, sys, os
SR = 22050
out = sys.argv[1]
rng = np.random.default_rng(13)
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
def bell(f, dur, dec=1.2):
    n = secs(dur); t = np.arange(n) / SR
    return (np.sin(2*np.pi*f*t) + 0.45*np.sin(2*np.pi*f*2.01*t) + 0.2*np.sin(2*np.pi*f*3.02*t)) * env(n, 0.004, dec, 2.5)
def seq(notes, step, dur, dec=1.0):
    n = secs(step * (len(notes) - 1) + dur); x = np.zeros(n)
    for i, f in enumerate(notes):
        b = bell(f, dur, dec); s = secs(step * i); x[s:s + len(b)] += b
    return x
# новый уровень: мажорное арпеджио вверх с блеском
x = seq([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.075, 1.1, 0.8)
x += rng.uniform(-1, 1, len(x)) * 0.04 * env(len(x), 0.3, 0.6, 2) * (np.arange(len(x)) > secs(0.3))
save("levelup", x, 0.8)
# задание выполнено: два аккорда
a = seq([523.25, 659.25, 783.99], 0.0, 0.6, 0.5); b = seq([698.46, 880.0, 1046.5], 0.0, 0.9, 0.7)
x = np.zeros(secs(1.15)); x[:len(a)] += a; x[secs(0.18):secs(0.18) + len(b)] += b
save("victory", x, 0.75)
# взмах: шум с полосой, идущей вниз
n = secs(0.22); t = np.arange(n) / SR
w = rng.uniform(-1, 1, n); k = 0.05 + 0.25 * np.exp(-t * 14)
y = np.zeros(n); acc = 0.0
for i in range(n):
    acc += k[i] * (w[i] - acc); y[i] = acc
save("whoosh", (y - lp(y, 0.02)) * np.sin(np.pi * t / 0.22) ** 1.5, 0.6)
# прыжок: короткий толчок
n = secs(0.16); t = np.arange(n) / SR
x = lp(rng.uniform(-1, 1, n), 0.2) * env(n, 0.002, 0.05, 3) + np.sin(2*np.pi*(180 + 120*t/0.16)*t) * env(n, 0.002, 0.08, 3) * 0.4
save("jump", x, 0.55)
# приземление: глухой удар и шорох
n = secs(0.35); t = np.arange(n) / SR
x = np.sin(2*np.pi*(90*np.exp(-t*4))*t) * env(n, 0.001, 0.12, 3) + lp(rng.uniform(-1, 1, n), 0.12) * env(n, 0.001, 0.15, 3) * 0.6
save("land", x, 0.75)
# снос: скрежет и обвал
n = secs(0.8); t = np.arange(n) / SR
x = lp(rng.uniform(-1, 1, n), 0.08) * env(n, 0.005, 0.5, 2) + np.sign(np.sin(2*np.pi*(70+30*np.sin(2*np.pi*9*t))*t)) * env(n, 0.002, 0.25, 3) * 0.25
for k in range(6):
    s = secs(0.05 + 0.1 * k); m = secs(0.06)
    x[s:s+m] += lp(rng.uniform(-1, 1, m), 0.3) * np.exp(-np.arange(m)/SR*40) * 0.8
save("demolish", x, 0.8)
# раскол камня
n = secs(0.5); t = np.arange(n) / SR
x = lp(rng.uniform(-1, 1, n), 0.35) * env(n, 0.001, 0.08, 3) + np.sin(2*np.pi*(320*np.exp(-t*8))*t) * env(n, 0.001, 0.2, 3) * 0.6
for k in range(5):
    s = secs(0.08 + 0.06 * k + rng.uniform(0, 0.03)); m = secs(0.03)
    x[s:s+m] += rng.uniform(-1, 1, m) * np.exp(-np.arange(m)/SR*90) * 0.5
save("crack", x, 0.8)
# щелчок сетки
n = secs(0.05); t = np.arange(n) / SR
save("tick", np.sin(2*np.pi*2200*t) * env(n, 0.0005, 0.012, 3), 0.35)
# отказ
n = secs(0.25); t = np.arange(n) / SR
save("buzz", np.sign(np.sin(2*np.pi*110*t)) * 0.5 * env(n, 0.003, 0.2, 2) + np.sin(2*np.pi*117*t) * 0.3 * env(n, 0.003, 0.2, 2), 0.45)
# подбор: мягкий «бульк» (высота меняется в игре)
n = secs(0.12); t = np.arange(n) / SR
save("blip", np.sin(2*np.pi*(700 + 900*t/0.12)*t) * env(n, 0.002, 0.05, 3), 0.5)
