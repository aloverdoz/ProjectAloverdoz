import numpy as np, wave, sys, os
SR = 22050
out = sys.argv[1]
rng = np.random.default_rng(7)

def env(n, a, d, curve=3.0):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t * curve / max(d, 1e-4))
    return e

def lp(x, k):
    # простой однополюсный фильтр
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc); y[i] = acc
    return y

def save(name, x, vol=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

def noise(n): return rng.uniform(-1, 1, n)
def secs(s): return int(SR * s)

# выстрел героя
n = secs(0.18); t = np.arange(n) / SR
x = noise(n) * env(n, 0.001, 0.05, 4) + np.sin(2*np.pi*(180 - 600*t)*t) * env(n, 0.001, 0.08, 4) * 0.8
save("shot", lp(x, 0.35), 0.7)
# турель
n = secs(0.14); t = np.arange(n) / SR
x = noise(n) * env(n, 0.001, 0.04, 4) * 0.8 + np.sign(np.sin(2*np.pi*110*t)) * env(n, 0.001, 0.05, 4) * 0.5
save("turret", lp(x, 0.25), 0.6)
# взрыв
n = secs(1.4); t = np.arange(n) / SR
x = lp(noise(n), 0.08) * env(n, 0.005, 0.6, 3) * 3 + np.sin(2*np.pi*(55 - 20*t)*t) * env(n, 0.002, 0.5, 3)
save("boom", x, 0.95)
# гибель монстра (хлюп)
n = secs(0.35); t = np.arange(n) / SR
x = np.sin(2*np.pi*(320 * np.exp(-t*9))*t) * env(n, 0.003, 0.2, 3) + lp(noise(n), 0.2) * env(n, 0.001, 0.1, 3) * 0.6
save("splat", x, 0.6)
# постройка (лязг)
n = secs(0.3); t = np.arange(n) / SR
x = (np.sin(2*np.pi*620*t) + 0.6*np.sin(2*np.pi*1310*t) + 0.4*np.sin(2*np.pi*2090*t)) * env(n, 0.001, 0.12, 4) + noise(n) * env(n, 0.001, 0.02, 4) * 0.5
save("place", x, 0.45)
# монета
n = secs(0.45); t = np.arange(n) / SR
f = np.where(t < 0.08, 988, 1319)
x = np.sin(2*np.pi*f*t) * env(n, 0.002, 0.35, 3) + 0.3*np.sin(4*np.pi*f*t) * env(n, 0.002, 0.2, 3)
save("coin", x, 0.4)
# ремонт (искры)
n = secs(0.2); t = np.arange(n) / SR
x = noise(n) * (0.5 + 0.5*np.sign(np.sin(2*np.pi*60*t))) * env(n, 0.001, 0.12, 3)
x = x - lp(x, 0.3)
save("repair", x, 0.35)
# тревога
n = secs(1.6); t = np.arange(n) / SR
f = 440 + 220 * (np.sin(2*np.pi*1.25*t) > 0)
x = np.sign(np.sin(2*np.pi*f*t)) * 0.5 + np.sin(2*np.pi*f*t)
x *= np.minimum(1, t / 0.02) * np.minimum(1, (1.6 - t) / 0.2)
save("alarm", lp(x, 0.3), 0.45)
# челнок
n = secs(4.0); t = np.arange(n) / SR
x = lp(noise(n), 0.05) * 2 + np.sin(2*np.pi*(70 + 30*np.sin(t))*t) * 0.4
x *= np.minimum(1, t / 1.0) * np.minimum(1, (4.0 - t) / 1.5)
save("shuttle", x, 0.7)
# фоновый ветер (зацикленный)
n = secs(8.0); t = np.arange(n) / SR
w = lp(noise(n), 0.02) * (0.6 + 0.4*np.sin(2*np.pi*t/8.0)) + lp(noise(n), 0.006) * 2
fade = secs(0.5)
w[:fade] = w[:fade] * np.linspace(0, 1, fade) + w[-fade:] * np.linspace(1, 0, fade)
w = w[:n - fade]
save("wind", w, 0.5)

# удар топором по дереву
n = secs(0.25); t = np.arange(n) / SR
x = lp(noise(n), 0.25) * env(n, 0.001, 0.05, 4) + np.sin(2*np.pi*(240 - 200*t)*t) * env(n, 0.001, 0.12, 4) * 0.9 + np.sin(2*np.pi*480*t) * env(n, 0.001, 0.06, 4) * 0.3
save("chop", x, 0.6)
# удар по камню
n = secs(0.22); t = np.arange(n) / SR
x = (np.sin(2*np.pi*1800*t) * 0.4 + np.sin(2*np.pi*2650*t) * 0.3) * env(n, 0.001, 0.06, 4) + noise(n) * env(n, 0.001, 0.03, 4)
save("hit", x - lp(x, 0.1), 0.5)
# подбор предмета
n = secs(0.16); t = np.arange(n) / SR
f = 700 + 900 * t / 0.16
x = np.sin(2*np.pi*np.cumsum(f)/SR) * env(n, 0.003, 0.12, 3)
save("pickup", x, 0.35)
# шаг
n = secs(0.09); t = np.arange(n) / SR
x = lp(noise(n), 0.12) * env(n, 0.002, 0.04, 4)
save("step", x, 0.25)
# клик интерфейса
n = secs(0.05); t = np.arange(n) / SR
x = np.sin(2*np.pi*1500*t) * env(n, 0.001, 0.02, 4)
save("click", x, 0.25)
# крафт готов
n = secs(0.5); t = np.arange(n) / SR
x = sum(np.sin(2*np.pi*f*t) * env(n, 0.002 + i*0.06, 0.3, 3) * (t > i*0.06) for i, f in enumerate([523, 659, 784]))
save("craft", x, 0.35)
# герою больно
n = secs(0.25); t = np.arange(n) / SR
x = np.sign(np.sin(2*np.pi*(180 - 120*t)*t)) * env(n, 0.002, 0.15, 3) * 0.5 + lp(noise(n), 0.2) * env(n, 0.001, 0.08, 3)
save("hurt", lp(x, 0.3), 0.5)
# укус монстра
n = secs(0.2); t = np.arange(n) / SR
x = lp(noise(n), 0.15) * env(n, 0.004, 0.08, 3) + np.sin(2*np.pi*(140 + 80*np.sin(60*t))*t) * env(n, 0.002, 0.12, 3)
save("bite", x, 0.5)
# плевок
n = secs(0.3); t = np.arange(n) / SR
x = lp(noise(n), 0.3) * env(n, 0.01, 0.15, 3) * (1 + np.sin(2*np.pi*30*t))
save("spit", x, 0.45)
# гул машины (петля)
n = secs(2.0); t = np.arange(n) / SR
x = np.sin(2*np.pi*55*t) * 0.5 + np.sign(np.sin(2*np.pi*110*t)) * 0.08 + lp(noise(n), 0.05) * 0.4
save("machine", lp(x, 0.2), 0.4)
# падение дерева
n = secs(1.0); t = np.arange(n) / SR
x = lp(noise(n), 0.04) * env(n, 0.3, 0.5, 3) * 2 + np.sin(2*np.pi*(60 - 20*t)*t) * env(n, 0.6, 0.3, 3) * (t > 0.6)
save("fall", x, 0.7)
# --- музыка: простые спокойные петли (синтез)
def note(f, dur, kind="pad"):
    n = secs(dur); t = np.arange(n) / SR
    if kind == "pad":
        x = sum(np.sin(2*np.pi*f*m*t + np.sin(2*np.pi*0.3*t)*0.3) / m for m in (1, 2, 3))
        e = np.minimum(1, t / 0.8) * np.minimum(1, (dur - t) / 1.2)
    elif kind == "pluck":
        x = np.sin(2*np.pi*f*t) + 0.3*np.sin(4*np.pi*f*t)
        e = env(n, 0.003, 0.9, 3)
    else:
        x = np.sign(np.sin(2*np.pi*f*t)) * 0.4 + np.sin(2*np.pi*f*t)
        e = env(n, 0.005, 0.25, 3)
    return x * e
def mtof(m): return 440 * 2 ** ((m - 69) / 12)
def track(name, chords, bpm, mode):
    beat = 60 / bpm
    total = secs(len(chords) * 4 * beat)
    out = np.zeros(total + secs(3))
    for ci, ch in enumerate(chords):
        start = secs(ci * 4 * beat)
        for m in ch:
            x = note(mtof(m), 4 * beat + 1.0, "pad") * 0.18
            out[start:start + len(x)] += x
        if mode in ("day", "night"):
            for k in range(8):
                m = ch[(k * (3 if mode == "day" else 2)) % len(ch)] + 12
                x = note(mtof(m), 1.2, "pluck") * (0.16 if mode == "day" else 0.1)
                s2 = start + secs(k * beat / 2)
                out[s2:s2 + len(x)] += x[:len(out) - s2]
        else:
            for k in range(8):
                s2 = start + secs(k * beat / 2)
                kick = np.sin(2*np.pi*(90*np.exp(-np.arange(secs(0.3))/SR*18))*np.arange(secs(0.3))/SR) * env(secs(0.3), 0.001, 0.2, 3)
                if k % 2 == 0:
                    out[s2:s2 + len(kick)] += kick * 0.6
                else:
                    hat = noise(secs(0.06)) * env(secs(0.06), 0.001, 0.03, 4) * 0.15
                    out[s2:s2 + len(hat)] += hat
                b = note(mtof(ch[0] - 12), beat / 2, "bass") * 0.25
                out[s2:s2 + len(b)] += b
    tail = out[total:]
    out = out[:total]
    out[:len(tail)] += tail
    save(name, lp(out, 0.4), 0.6)
track("music_day", [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]] * 2, 72, "day")
track("music_night", [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59]] * 2, 56, "night")
track("music_wave", [[52, 55, 59], [52, 55, 59], [48, 52, 55], [50, 54, 57]] * 2, 132, "wave")
print("ok")
