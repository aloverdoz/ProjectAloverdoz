# Иконки достижений Steam: 256x256 JPG, цветная (открыто) и серая (закрыто).
import sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from steam_data import ACHIEVEMENTS
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SYM = {"ACH_FIRST_TOOL": "⚒", "ACH_WORKBENCH": "⚙", "ACH_FIRST_INGOTS": "⛁", "ACH_AUTOMATION": "⚡", "ACH_BELTS_100": "⇄",
       "ACH_DELIVER_500": "⬆", "ACH_FIRST_WAVE": "⚔", "ACH_WAVES_10": "♜", "ACH_VICTORY": "♛", "ACH_TRADER": "⚖",
       "ACH_RESEARCH_5": "⚛", "ACH_SCAN_20": "◈", "ACH_LEVEL_10": "✪", "ACH_RICH": "★"}
COL = {"build": (242, 163, 58), "fight": (232, 84, 70), "eco": (95, 211, 255), "top": (255, 214, 90)}
KIND = {"ACH_FIRST_TOOL": "build", "ACH_WORKBENCH": "build", "ACH_FIRST_INGOTS": "build", "ACH_AUTOMATION": "build", "ACH_BELTS_100": "build",
        "ACH_DELIVER_500": "eco", "ACH_FIRST_WAVE": "fight", "ACH_WAVES_10": "fight", "ACH_VICTORY": "top", "ACH_TRADER": "eco",
        "ACH_RESEARCH_5": "eco", "ACH_SCAN_20": "eco", "ACH_LEVEL_10": "top", "ACH_RICH": "top"}
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 400)

def hexagon(cx, cy, r, rot=math.pi / 6):
    return [(cx + r * math.cos(rot + i * math.pi / 3), cy + r * math.sin(rot + i * math.pi / 3)) for i in range(6)]

def icon(api):
    S = 1024
    c = COL[KIND[api]]
    im = Image.new("RGB", (S, S), (16, 21, 30))
    d = ImageDraw.Draw(im)
    # радиальное свечение
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse([160, 160, S - 160, S - 160], fill=tuple(int(v * 0.45) for v in c))
    im = Image.blend(im, glow.filter(ImageFilter.GaussianBlur(140)), 0.9)
    d = ImageDraw.Draw(im)
    d.polygon(hexagon(512, 512, 430), fill=(28, 36, 50))
    d.line(hexagon(512, 512, 430) + [hexagon(512, 512, 430)[0]], fill=c, width=34, joint="curve")
    d.line(hexagon(512, 512, 372) + [hexagon(512, 512, 372)[0]], fill=tuple(int(v * 0.5) for v in c), width=8, joint="curve")
    # символ
    ch = SYM[api]
    bb = d.textbbox((0, 0), ch, font=FONT)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    sc = min(1.0, 430 / max(w, h))
    lay = Image.new("L", (w + 40, h + 40), 0)
    ImageDraw.Draw(lay).text((20 - bb[0], 20 - bb[1]), ch, font=FONT, fill=255)
    lay = lay.resize((int(lay.width * sc), int(lay.height * sc)), Image.LANCZOS)
    px, py = 512 - lay.width // 2, 512 - lay.height // 2
    sh = Image.new("RGB", im.size, (0, 0, 0))
    m = Image.new("L", im.size, 0)
    m.paste(lay, (px + 10, py + 14))
    im.paste(sh, (0, 0), m.filter(ImageFilter.GaussianBlur(10)).point(lambda v: v * 0.7))
    im.paste(Image.new("RGB", lay.size, (250, 246, 236)), (px, py), lay)
    return im.resize((256, 256), Image.LANCZOS)

rows = []
for a in ACHIEVEMENTS:
    api = a[0]
    im = icon(api)
    im.save(os.path.join(OUT, api + ".jpg"), quality=95)
    g = ImageOps.grayscale(im)
    g = Image.eval(g, lambda v: int(v * 0.55))
    g.convert("RGB").save(os.path.join(OUT, api + "_locked.jpg"), quality=95)
    rows.append(a)
# сводная картинка
sheet = Image.new("RGB", (7 * 266 + 10, 4 * 266 + 10), (10, 12, 16))
for i, a in enumerate(rows):
    x, y = 10 + (i % 7) * 266, 10 + (i // 7) * 532
    sheet.paste(Image.open(os.path.join(OUT, a[0] + ".jpg")), (x, y))
    sheet.paste(Image.open(os.path.join(OUT, a[0] + "_locked.jpg")), (x, y + 266))
sheet.save(os.path.join(OUT, "_все_достижения.png"))
print("icons", len(rows))
