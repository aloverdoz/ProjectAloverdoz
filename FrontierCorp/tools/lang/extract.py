"""1.3: сбор всех русских строк игры (данные core/*.json и строки в scripts/**/*.gd) для перевода.
python3 tools/lang/extract.py OUT.json — список уникальных строк."""
import json, os, re, sys
CYR = re.compile('[А-Яа-яЁё]')
out = set()
def walk(o, key=""):
    if isinstance(o, dict):
        if set(o.keys()) >= {"ru", "en"}:
            return
        for k, v in o.items():
            if k.endswith("_en") or k in ("en",):
                continue
            walk(v, k)
    elif isinstance(o, list):
        for v in o:
            walk(v, key)
    elif isinstance(o, str) and CYR.search(o):
        out.add(o)
for f in sorted(os.listdir("core")):
    if f.endswith(".json"):
        walk(json.load(open(os.path.join("core", f), encoding="utf-8")))
STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
for root, _, files in os.walk("scripts"):
    for fn in files:
        if not fn.endswith(".gd"):
            continue
        for line in open(os.path.join(root, fn), encoding="utf-8"):
            code = line
            # отрезать комментарий (# вне строки)
            q = False; cut = len(code)
            for i, ch in enumerate(code):
                if ch == '"' and (i == 0 or code[i-1] != '\\'):
                    q = not q
                elif ch == '#' and not q:
                    cut = i; break
            code = code[:cut]
            for m in STR.finditer(code):
                s = m.group(1)
                if CYR.search(s):
                    out.add(s.encode().decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\' in s else s)
json.dump(sorted(out), open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print(len(out), sum(len(x) for x in out))
