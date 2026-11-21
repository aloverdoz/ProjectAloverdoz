# Картинки для Steam из скриншотов игры + логотип.
# usage: art.py out_dir key_shot.png hero_shot.png [vertical_shot.png]
import sys, os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
sys.path.insert(0, os.path.dirname(__file__))
from icon import mark

OUT, KEY, HERO = sys.argv[1], sys.argv[2], sys.argv[3]
VERT = sys.argv[4] if len(sys.argv) > 4 else KEY
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
ORANGE = (255, 170, 64)
WHITE = (246, 242, 232)

def grade(im):
    im = ImageEnhance.Contrast(im).enhance(1.12)
    im = ImageEnhance.Color(im).enhance(1.15)
    return im

def cover(im, w, h, fx=0.5, fy=0.5, zoom=1.0):
    """Обрезать картинку под размер w×h без искажений; fx, fy — куда сдвинуть кадр (0..1), zoom — приблизить."""
    if zoom > 1.0:
        cw, ch = round(im.width / zoom), round(im.height / zoom)
        x = round((im.width - cw) * fx); y = round((im.height - ch) * fy)
        im = im.crop((x, y, x + cw, y + ch))
    s = max(w / im.width, h / im.height)
    r = im.resize((max(w, round(im.width * s)), max(h, round(im.height * s))), Image.LANCZOS)
    x = round((r.width - w) * fx); y = round((r.height - h) * fy)
    return r.crop((x, y, x + w, y + h))

def vignette(im, strength=0.55, bottom=0.0, left=0.0):
    w, h = im.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    # радиальная виньетка
    small = Image.new("L", (64, 64), 0)
    sd = small.load()
    for y in range(64):
        for x in range(64):
            dx, dy = (x - 31.5) / 32, (y - 31.5) / 32
            v = min(1.0, max(0.0, (math.sqrt(dx * dx + dy * dy) - 0.55) / 0.6)) * strength
            if bottom:
                v = max(v, max(0.0, (y / 63 - (1 - bottom)) / bottom) * 0.85)
            if left:
                v = max(v, max(0.0, ((1 - x / 63) - (1 - left)) / left) * 0.85)
            sd[x, y] = int(255 * v)
    m = small.resize((w, h), Image.BICUBIC)
    dark = Image.new("RGB", (w, h), (8, 10, 16))
    return Image.composite(dark, im, m)

def logo(width, stacked=False, shadow=True):
    """Логотип: знак + FRONTIER CORP на прозрачном фоне, ширина width."""
    S = 4
    fs = 200 * S
    f = ImageFont.truetype(FONT, fs)
    t1, t2 = "FRONTIER", "CORP"
    d0 = ImageDraw.Draw(Image.new("L", (1, 1)))
    b1 = d0.textbbox((0, 0), t1, font=f); b2 = d0.textbbox((0, 0), t2, font=f)
    gap = int(fs * 0.22)
    mk = mark(int(fs * 1.25), bg=False)
    if stacked:
        w = max(b1[2] - b1[0], b2[2] - b2[0]); h = (b1[3] - b1[1]) + (b2[3] - b2[1]) + gap
        mw = mk.width
        W = max(w, mw) + 40 * S; H = mk.height + h + gap + 40 * S
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        im.alpha_composite(mk, ((W - mw) // 2, 20 * S))
        y = 20 * S + mk.height + gap // 2
        d.text(((W - (b1[2] - b1[0])) // 2 - b1[0], y - b1[1]), t1, font=f, fill=WHITE + (255,))
        y += (b1[3] - b1[1]) + gap
        d.text(((W - (b2[2] - b2[0])) // 2 - b2[0], y - b2[1]), t2, font=f, fill=ORANGE + (255,))
    else:
        sp = d0.textlength(" ", font=f) * 0.9
        tw = (b1[2] - b1[0]) + sp + (b2[2] - b2[0])
        th = max(b1[3] - b1[1], b2[3] - b2[1])
        mw = int(mk.width * th / mk.height * 1.35)
        mk = mk.resize((mw, int(mk.height * mw / mk.width)), Image.LANCZOS)
        W = int(mw + gap + tw + 40 * S); H = int(max(mk.height, th) + 40 * S)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        im.alpha_composite(mk, (20 * S, (H - mk.height) // 2 - int(th * 0.05)))
        x = 20 * S + mw + gap; y = (H - th) // 2
        d.text((x - b1[0], y - b1[1]), t1, font=f, fill=WHITE + (255,))
        x += (b1[2] - b1[0]) + sp
        d.text((x - b2[0], y - b2[1]), t2, font=f, fill=ORANGE + (255,))
    if shadow:
        a = im.split()[3].filter(ImageFilter.GaussianBlur(9 * S)).point(lambda v: int(v * 0.85))
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0)); sh.putalpha(a)
        base = Image.new("RGBA", im.size, (0, 0, 0, 0))
        base.alpha_composite(sh, (0, 0)); base.alpha_composite(im)
        im = base
    bb = im.getbbox(); im = im.crop(bb)
    return im.resize((width, max(1, round(im.height * width / im.width))), Image.LANCZOS)

def place(bg, lg, x, y):
    bg = bg.convert("RGBA"); bg.alpha_composite(lg, (int(x), int(y))); return bg.convert("RGB")

os.makedirs(OUT + "/магазин", exist_ok=True); os.makedirs(OUT + "/библиотека", exist_ok=True); os.makedirs(OUT + "/события", exist_ok=True)
key = grade(Image.open(KEY).convert("RGB"))
hero = grade(Image.open(HERO).convert("RGB"))
vert = grade(Image.open(VERT).convert("RGB"))

ZOOM, FX, FY = 1.3, 0.42, 0.62

def capsule(w, h, logo_w, pos="bottom", src=key, fx=None, fy=None, stacked=False, name=None, zoom=None):
    bg = cover(src, w, h, FX if fx is None else fx, FY if fy is None else fy, ZOOM if zoom is None else zoom)
    bg = vignette(bg, 0.5, bottom=0.55 if pos == "bottom" else 0.0, left=0.6 if pos == "left" else 0.0)
    lg = logo(logo_w, stacked=stacked)
    if pos == "bottom":
        im = place(bg, lg, (w - lg.width) / 2, h - lg.height - h * 0.07)
    elif pos == "left":
        im = place(bg, lg, w * 0.05, (h - lg.height) / 2)
    else:
        im = place(bg, lg, (w - lg.width) / 2, (h - lg.height) / 2)
    im.save(name, quality=95) if name.endswith(".jpg") else im.save(name)
    return im

S = OUT + "/магазин/"
capsule(920, 430, 700, "bottom", name=S + "header_capsule_920x430.png")
capsule(462, 174, 400, "center", name=S + "small_capsule_462x174.png")
capsule(1232, 706, 860, "bottom", name=S + "main_capsule_1232x706.png")
capsule(748, 896, 600, "bottom", src=vert, stacked=True, fx=0.6, name=S + "vertical_capsule_748x896.png")
# фон страницы: спокойный, тёмный, без логотипа
pb = cover(key, 1438, 810).filter(ImageFilter.GaussianBlur(6))
pb = ImageEnhance.Brightness(pb).enhance(0.45); pb = vignette(pb, 0.8)
pb.save(S + "page_background_1438x810.png")

L = OUT + "/библиотека/"
capsule(600, 900, 480, "bottom", src=vert, stacked=True, fx=0.6, name=L + "library_capsule_600x900.png")
capsule(920, 430, 700, "bottom", name=L + "library_header_920x430.png")
hb = vignette(cover(hero, 3840, 1240), 0.35)
hb.save(L + "library_hero_3840x1240.png")
lg = logo(1280, shadow=False)
lg.save(L + "library_logo_1280w.png")
# превью: как это будет выглядеть в библиотеке Steam
prev = hb.resize((1920, 620), Image.LANCZOS).convert("RGBA")
pl = logo(640); prev.alpha_composite(pl, (60, 620 - pl.height - 50))
prev.convert("RGB").save(L + "_превью_библиотеки.jpg", quality=90)

E = OUT + "/события/"
capsule(800, 450, 620, "bottom", name=E + "event_cover_800x450.png")
capsule(1920, 622, 1100, "left", src=hero, name=E + "event_header_1920x622.png")
print("ok")
