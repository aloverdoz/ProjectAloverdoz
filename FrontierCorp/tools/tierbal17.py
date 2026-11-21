# 17.10: рост сложности по тирам.
# Каждый следующий тир: деталь требует заметно больше сырья (по всей цепочке) и дольше делается.
# Цели по сырью на 1 штуку (руда, камень, брёвна, жидкости — по всей цепочке) и время одного крафта:
#   T0 2 / 2 с, T1 5 / 4 с, T2 14 / 8 с, T3 35 / 12 с, T4 90 / 18 с, T5 220 / 26 с, T6 500 / 36 с, T7 1100 / 48 с, T8+ 2400 / 60 с.
# Рецепты, взятые из таблицы (balance17.SF), не трогаются: у них свои настоящие цифры.
# Плавка «руда → слиток» и переработка жидкостей не дорожают (это база тира), дорожает всё, что из них собирается.
# Снаряжение, еда и одежда дорожают втрое мягче. Вызывается из gen_core.py последним; всё правится в «Рецепты».
import math
import balance17

RAW_TARGET = {0: 2, 1: 5, 2: 14, 3: 35, 4: 90, 5: 220, 6: 500, 7: 1100, 8: 2400, 9: 4000}
TIME_BAND = {0: 2, 1: 4, 2: 8, 3: 12, 4: 18, 5: 26, 6: 36, 7: 48, 8: 60, 9: 80}
SKIP_PREFIX = ("shop_", "unpack_", "recycle_", "pack_", "fill_", "empty_", "smelt_", "refine_", "d17_iron_crushed", "d17_copper_crushed", "d17_tin_crushed")
RAW_CATS = ("Руда", "Сырьё", "Жидкости")
SOFT_CATS = ("Инструменты", "Оружие", "Еда", "Снаряжение", "Одежда", "Боеприпасы", "Медицина")


def _tiers(recipes, buildings, tech):
    rt, bt = {}, {}
    for t in tech.values():
        tr = int(t.get("tier", 0))
        u = t.get("unlocks", {})
        for r in u.get("recipes", []):
            rt[r] = min(rt.get(r, 99), tr)
        for b in u.get("buildings", []):
            bt[b] = min(bt.get(b, 99), tr)
    st_tier = {}
    for bid, b in buildings.items():
        st = b.get("params", {}).get("station") or (bid if b.get("behavior") == "station" else None)
        if st:
            st_tier[st] = min(st_tier.get(st, 99), bt.get(bid, 0))
    out = {}
    for rid, r in recipes.items():
        sts = [s for s in r.get("stations", []) if s != "hand"]
        s_t = min([st_tier.get(s, 0) for s in sts]) if sts else 0
        out[rid] = max(rt.get(rid, 0), s_t if s_t < 99 else 0)
    return out


def _is_raw(items, iid):
    it = items.get(iid, {})
    return it.get("category") in RAW_CATS or bool(it.get("fluid"))


def apply(recipes, items, buildings, tech):
    fixed = set(balance17.SF) | set(balance17.SIMPLER)
    rtier = _tiers(recipes, buildings, tech)
    prod = {}
    for rid, r in recipes.items():
        o = r.get("out", {})
        if len(o) == 1:
            prod.setdefault(next(iter(o)), []).append(rid)
    item_tier = {it: min(rtier[r] for r in rids) for it, rids in prod.items()}

    def costs():
        memo = {}

        def c(it, d=0):
            if _is_raw(items, it) or it not in prod or d > 30:
                return 1.0
            if it in memo:
                return memo[it]
            memo[it] = 1e9
            best = 1e9
            for rid in prod[it]:
                if rid.startswith(("shop_", "recycle_", "unpack_")):
                    continue
                r = recipes[rid]
                n = max(1, next(iter(r["out"].values())))
                s = 0.0
                for k, v in r.get("in", {}).items():
                    s += c(k, d + 1) * v / n
                best = min(best, s)
            memo[it] = best if best < 1e9 else 1.0
            return memo[it]
        return c

    changed = 0
    for tier in range(0, 10):
        cost = costs()
        for rid, r in list(recipes.items()):
            if rtier.get(rid, 0) != tier or rid in fixed or rid.startswith(SKIP_PREFIX):
                continue
            o = r.get("out", {})
            if len(o) != 1:
                continue
            oid, n = next(iter(o.items()))
            if oid not in items or _is_raw(items, oid) or items[oid].get("exotic"):
                continue
            ins = r.get("in", {})
            if not ins or any(k == "sink_coupon" for k in ins):
                continue
            soft = items[oid].get("category") in SOFT_CATS
            band = TIME_BAND.get(tier, 80) * (0.5 if soft else 1.0)
            refine = all(_is_raw(items, k) for k in ins)
            if refine:
                # плавка и переработка сырья: только время чуть растёт с тиром
                r["time"] = round(max(float(r.get("time", 1.0)), band * 0.35), 1)
                continue
            now = sum(cost(k) * v for k, v in ins.items()) / max(1, n)
            want = RAW_TARGET.get(tier, 4000) / (3.0 if soft else 1.0)
            if now < want * 0.6:
                k = min(6.0, want / max(0.1, now))
                r["in"] = {it: max(1, int(round(v * k))) for it, v in ins.items()}
                changed += 1
            r["time"] = round(max(float(r.get("time", 1.0)), band), 1)
    return changed
