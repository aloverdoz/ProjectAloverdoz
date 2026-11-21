# Иконка игры: тёмный скруглённый квадрат, оранжевый «рубеж»-треугольник со входом, голубой огонь.
import sys
from PIL import Image, ImageDraw, ImageFilter

def mark(size, bg=True):
    S = 4 * size
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 128.0
    if bg:
        # фон с вертикальным градиентом
        grad = Image.new("RGBA", (S, S))
        gd = ImageDraw.Draw(grad)
        for y in range(S):
            t = y / S
            c = (int(0x26 + (0x14 - 0x26) * t), int(0x33 + (0x1a - 0x33) * t), int(0x46 + (0x24 - 0x46) * t), 255)
            gd.line([(0, y), (S, y)], fill=c)
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(24 * k), fill=255)
        im.paste(grad, (0, 0), m)
        ImageDraw.Draw(im).rounded_rectangle([int(2 * k), int(2 * k), S - 1 - int(2 * k), S - 1 - int(2 * k)], radius=int(22 * k), outline=(255, 170, 70, 90), width=max(1, int(1.5 * k)))
    d = ImageDraw.Draw(im)
    # мягкая тень под знаком
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(24 * k, 96 * k), (64 * k, 30 * k), (104 * k, 96 * k)], fill=(0, 0, 0, 140))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4 * k)))
    # треугольник: светлая и тёмная грани
    d.polygon([(22 * k, 92 * k), (64 * k, 24 * k), (64 * k, 92 * k)], fill=(255, 184, 77, 255))
    d.polygon([(64 * k, 24 * k), (106 * k, 92 * k), (64 * k, 92 * k)], fill=(226, 134, 36, 255))
    # вход
    d.rectangle([52 * k, 66 * k, 76 * k, 92 * k], fill=(20, 27, 38, 255))
    d.rectangle([52 * k, 66 * k, 76 * k, 69 * k], fill=(95, 211, 255, 255))
    # огонёк с ореолом
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([(64 - 14) * k, (52 - 14) * k, (64 + 14) * k, (52 + 14) * k], fill=(95, 211, 255, 150))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5 * k)))
    d = ImageDraw.Draw(im)
    d.ellipse([(64 - 7) * k, (52 - 7) * k, (64 + 7) * k, (52 + 7) * k], fill=(160, 232, 255, 255))
    d.ellipse([(64 - 3.5) * k, (52 - 3.5) * k, (64 + 3.5) * k, (52 + 3.5) * k], fill=(255, 255, 255, 255))
    # полоса земли
    d.rectangle([18 * k, 92 * k, 110 * k, 97 * k], fill=(255, 184, 77, 255))
    return im.resize((size, size), Image.LANCZOS)

if __name__ == "__main__":
    out = sys.argv[1]
    big = mark(1024)
    big.save(out + "/icon_1024.png")
    mark(512).save(out + "/icon_512.png")
    mark(256).save(out + "/icon_256.png")
    mark(184).convert("RGB").save(out + "/community_icon_184.jpg", quality=95)
    mark(32).save(out + "/icon_32.png")
    sizes = [16, 24, 32, 48, 64, 128, 256]
    imgs = [mark(s) for s in sizes]
    imgs[-1].save(out + "/game.ico", sizes=[(s, s) for s in sizes], append_images=imgs[:-1])
    mark(512, bg=False).save(out + "/mark_512.png")
