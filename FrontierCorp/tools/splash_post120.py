"""Post: haze from depth, bloom, grade, vignette, title (splash) or calm centre (menu).
python3 post.py VIEW beauty.png depth.png out.png"""
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

VIEW, BEAUTY, DEPTH, OUT = sys.argv[1:5]
TCX = 0.72   # 1.3: название справа внизу — слева на картинке шестеро героев
im = Image.open(BEAUTY).convert("RGB")
W, H = im.size
S = W / 1920.0
c = np.asarray(im).astype(np.float32) / 255.0


def to_lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


if DEPTH == "synth":
    yy0 = np.mgrid[0:H, 0:W][0].astype(np.float32) / H
    dist = np.where(yy0 < 0.3, 140.0 + (0.3 - yy0) * 400, 12 + (1 - (yy0 - 0.3) / 0.7) ** 2.2 * 128)
    class _D: size = im.size
    dimg = None
if DEPTH != "synth":
  dimg = Image.open(DEPTH)
if dimg is not None:
  d = np.asarray(dimg).astype(np.float32)
  d = d / (65535.0 if d.max() > 255 else 255.0)
  if d.ndim == 3: d = d[..., 0]
  dist = to_lin(d) * 250.0
  if dimg.size != im.size:
    dist = np.asarray(Image.fromarray(dist).resize(im.size, Image.BILINEAR))

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H

# ---- aerial haze: warm near the horizon/sun side, cooler blue up high
P = {"splash": dict(h0=40, k=0.012, amt=0.3), "menu": dict(h0=30, k=0.012, amt=0.55)}[VIEW]
f = (1 - np.exp(-np.maximum(dist - P["h0"], 0) * P["k"])) * P["amt"]
haze = np.stack([np.full_like(u, 1.0), np.full_like(u, 0.80), np.full_like(u, 0.62)], -1)
haze = haze * (1 - 0.25 * v[..., None]) + np.array([-0.15, -0.02, 0.12]) * (1 - v[..., None]) * 0.5
c = c * (1 - f[..., None]) + haze * f[..., None]

# ---- grade: gentle S-curve, warm highlights / teal shadows, a touch more saturation
lum = (c * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
c = lum + (c - lum) * 1.12
c = np.clip(c, 0, 1)
c = c + (np.array([0.05, 0.02, -0.04]) * lum + np.array([-0.012, 0.0, 0.02]) * (1 - lum))
c = np.clip(c, 0, 1)
c = c * c * (3 - 2 * c) * 0.35 + c * 0.65    # contrast
c = np.clip(c * 1.06, 0, 1)

# ---- bloom from bright areas (muzzle flashes, explosions, lamps, sky)
lum = (c * np.array([0.2126, 0.7152, 0.0722])).sum(-1)
br = np.clip((lum - 0.72) / 0.28, 0, 1)[..., None] * c
bimg = Image.fromarray((br * 255).astype(np.uint8))
bloom = np.zeros_like(c)
for r, w in ((4, 0.5), (12, 0.45), (32, 0.4), (80, 0.3)):
    bloom += np.asarray(bimg.filter(ImageFilter.GaussianBlur(r * S))).astype(np.float32) / 255.0 * w
c = 1 - (1 - c) * (1 - np.clip(bloom, 0, 1))   # screen

# ---- warm light leak from the sun side (left) + vignette
leak = np.exp(-(((u + 0.05) / 0.55) ** 2 + ((v - 0.15) / 0.5) ** 2))
c = 1 - (1 - c) * (1 - leak[..., None] * np.array([0.22, 0.12, 0.04]))
vig = 1 - 0.42 * np.clip(((u - 0.5) / 0.75) ** 2 + ((v - 0.48) / 0.7) ** 2, 0, 1) ** 1.3
c = c * vig[..., None]

if VIEW == "menu":
    # calm, darker centre where the title + 300 px button column (and the page panel) sit
    m = np.exp(-(((u - 0.48) / 0.36) ** 2 + ((v - 0.52) / 0.55) ** 2))
    c = c * (1 - 0.5 * m[..., None])
    lum = (c * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    c = c * (1 - 0.35 * m[..., None]) + lum * 0.35 * m[..., None]   # desaturate the middle a bit
    c = c * 0.9 + np.array([0.0, 0.004, 0.012]) * 0.9

if VIEW == "splash":
    # dark band behind the title so it reads on any background
    band = np.exp(-((v - 0.8) / 0.15) ** 2) * (0.25 + 0.75 * np.exp(-((u - TCX) / 0.32) ** 2))
    c = c * (1 - 0.55 * band[..., None])

out = Image.fromarray((np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8))

if VIEW == "splash":
    BLACK = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
    SEMI = "/usr/share/fonts/opentype/inter/InterDisplay-SemiBold.otf"
    title, sub = "PROJECT ALOVERDOZ", ""   # 1.3: только название игры

    def tracked(draw, text, font, track):
        widths = [draw.textlength(ch, font=font) for ch in text]
        return sum(widths) + track * (len(text) - 1), widths

    def draw_tracked(draw, x, y, text, font, track, widths, **kw):
        for ch, w in zip(text, widths):
            draw.text((x, y), ch, font=font, **kw); x += w + track

    tf = ImageFont.truetype(BLACK, int(84 * S))
    sf = ImageFont.truetype(SEMI, int(28 * S))
    tmp = ImageDraw.Draw(out)
    t_track, s_track = 5 * S, 16 * S
    tw, twid = tracked(tmp, title, tf, t_track)
    sw, swid = tracked(tmp, sub, sf, s_track)
    asc, desc = tf.getmetrics()
    bb = tf.getbbox("PROJECT")
    cap_top, cap_h = bb[1], bb[3] - bb[1]
    tx, ty = TCX * W - tw / 2, 820 * S - cap_top - cap_h / 2   # cap-height centred at y=742
    # soft shadow + warm glow layers
    lay = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(lay)
    draw_tracked(ld, tx, ty, title, tf, t_track, twid, fill=255)
    shadow = lay.filter(ImageFilter.GaussianBlur(14 * S)).point(lambda p: int(p * 0.85))
    sh_off = Image.new("L", (W, H), 0); sh_off.paste(shadow, (int(0 * S), int(10 * S)))
    out = Image.composite(Image.new("RGB", (W, H), (8, 6, 10)), out, sh_off)
    glow = lay.filter(ImageFilter.GaussianBlur(40 * S)).point(lambda p: int(p * 0.45))
    out = Image.composite(Image.new("RGB", (W, H), (255, 150, 60)), out, glow)
    # hard 3D-ish extrusion (dark) then the face with a vertical gradient
    ext = Image.new("L", (W, H), 0); ed = ImageDraw.Draw(ext)
    for k in range(1, int(7 * S) + 1):
        draw_tracked(ed, tx + k * 0.35, ty + k, title, tf, t_track, twid, fill=255)
    out = Image.composite(Image.new("RGB", (W, H), (40, 22, 12)), out, ext)
    grad = np.zeros((H, W, 3), np.float32)
    top, bot = ty + cap_top, ty + cap_top + cap_h
    g = np.clip((yy - top) / max(1, bot - top), 0, 1)[..., None]
    grad[:] = np.array([255, 246, 226]) * (1 - g) + np.array([255, 196, 120]) * g
    face = Image.fromarray(grad.astype(np.uint8))
    out = Image.composite(face, out, lay)
    # divider line with fading ends + diamond, then the subtitle
    ly = int(880 * S)
    line = Image.new("L", (W, H), 0); dl = ImageDraw.Draw(line)
    lx0, lx1 = TCX * W - tw * 0.48, TCX * W + tw * 0.48
    dl.rectangle([lx0, ly, lx1, ly + max(1, int(2 * S))], fill=255)
    ramp = np.clip(1 - np.abs(u - TCX) / (tw * 0.48 / W), 0, 1) ** 0.6
    line = Image.fromarray((np.asarray(line) * ramp).astype(np.uint8))
    out = Image.composite(Image.new("RGB", (W, H), (255, 170, 70)), out, line)
    if sub:
        sx, sy = TCX * W - sw / 2, ly + 22 * S
        sl = Image.new("L", (W, H), 0); sd = ImageDraw.Draw(sl)
        draw_tracked(sd, sx, sy, sub, sf, s_track, swid, fill=255)
        out = Image.composite(Image.new("RGB", (W, H), (10, 6, 4)), out,
                              sl.filter(ImageFilter.GaussianBlur(6 * S)).point(lambda p: int(p * 0.8)))
        out = Image.composite(Image.new("RGB", (W, H), (255, 176, 72)), out, sl)
        # small diamonds flanking the subtitle
        dd = ImageDraw.Draw(out)
        bbs = sf.getbbox("F"); mid_y = sy + (bbs[1] + bbs[3]) / 2
        for cx in (sx - 34 * S, sx + sw + 34 * S):
            r = 6 * S
            dd.polygon([(cx, mid_y - r), (cx + r, mid_y), (cx, mid_y + r), (cx - r, mid_y)], fill=(255, 176, 72))

out.save(OUT)
print("POST", OUT, out.size)
