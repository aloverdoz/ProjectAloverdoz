"""1.3: собрать перевод из /home/claude/i18n (chunks ru_NN / en_NN: «id\t"json"») в tools/lang/en.json — {русский: английский}.
python3 tools/lang/merge_en.py SRC_DIR"""
import glob, json, os, sys
src = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/i18n"
def rd(pat):
    out = {}
    for f in sorted(glob.glob(os.path.join(src, pat))):
        for l in open(f, encoding="utf-8"):
            l = l.rstrip("\n")
            if l:
                i, s = l.split("\t", 1)
                out[int(i)] = json.loads(s)
    return out
ru, en = rd("chunks/ru_*.txt"), rd("en/en_*.txt")
d = {ru[i]: en[i] for i in sorted(en) if i in ru and en[i] and en[i] != ru[i]}
here = os.path.dirname(os.path.abspath(__file__))
if not os.path.isdir(src) and os.path.exists(os.path.join(here, "en.json")):
    # 1.5: исходных кусков перевода нет (новая машина) — дополняем готовый en.json, а не затираем его
    d = json.load(open(os.path.join(here, "en.json"), encoding="utf-8"))
extra = os.path.join(here, "en_extra.json")
if os.path.exists(extra):
    d.update(json.load(open(extra, encoding="utf-8")))
json.dump(d, open(os.path.join(here, "en.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
print(len(d))
