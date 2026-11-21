import numpy as np, sys
from PIL import Image
b = sys.argv[1].rstrip("/") + "/"
V = np.fromfile(b + "v.bin", "<f4").reshape(-1, 3); B = np.fromfile(b + "b.bin", "<i4").reshape(-1, 4)
pal = np.array([[150,150,150],[255,0,0],[0,0,255],[255,150,150],[150,150,255],[0,170,0],[230,180,0],[180,0,180],[0,190,190],[255,100,255],[100,230,255],[0,0,0]], np.uint8)
img = np.full((560, 640, 3), 255, np.uint8)
def put(ox, a, bb):
    px = (ox + a * 260).astype(int); py = (545 - bb * 260).astype(int)
    ok = (px >= 0) & (px < 640) & (py >= 0) & (py < 560)
    img[py[ok], px[ok]] = pal[B[ok, 0]]
put(170, V[:, 2], V[:, 1]); put(480, V[:, 0], V[:, 1])
Image.fromarray(img).save(sys.argv[2])
