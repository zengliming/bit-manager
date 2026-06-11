"""
生成不使用字母的移动端 icon 候选稿。

候选:
  01_abstract_flow: 数据卡片 + 流动节点
  02_crystal_modules: 晶体模块 + 节点
  03_pulse_network: 网络内核 + 四向连接
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(r"D:\code\flutter\bit-manager")
OUT = ROOT / "assets" / "icon" / "candidates"
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 1024


def gradient_bg(c1, c2, c3=None):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pix = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            sx = x / (SIZE - 1)
            sy = y / (SIZE - 1)
            t = sx * 0.65 + sy * 0.35
            if c3 and t > 0.55:
                tt = (t - 0.55) / 0.45
                a, b = c2, c3
            else:
                tt = min(t / 0.55, 1) if c3 else t
                a, b = c1, c2
            pix[x, y] = tuple(int(a[i] * (1 - tt) + b[i] * tt) for i in range(3)) + (255,)

    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=230, fill=255)
    img.putalpha(mask)
    return img


def add_noise(img, opacity=18):
    noise = Image.new("RGBA", img.size, (0, 0, 0, 0))
    p = noise.load()
    for y in range(0, SIZE, 4):
        for x in range(0, SIZE, 4):
            v = ((x * 37 + y * 17) % 53) - 26
            if v > 15:
                p[x, y] = (255, 255, 255, opacity)
    return Image.alpha_composite(img, noise)


def save(img, name):
    img.save(OUT / name)
    preview = img.copy()
    preview.thumbnail((256, 256))
    preview.save(OUT / name.replace(".png", "_256.png"))


def variant_flow():
    img = add_noise(gradient_bg((73, 79, 235), (5, 182, 212), (16, 185, 129)))

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    cards = [
        ((246, 270, 778, 445), 56, (255, 255, 255, 54)),
        ((214, 426, 810, 601), 56, (255, 255, 255, 72)),
        ((270, 582, 754, 754), 56, (255, 255, 255, 48)),
    ]
    for box, radius, _ in cards:
        x1, y1, x2, y2 = box
        sd.rounded_rectangle((x1 + 18, y1 + 24, x2 + 18, y2 + 24), radius=radius, fill=(9, 24, 70, 72))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    img = Image.alpha_composite(img, shadow)

    d = ImageDraw.Draw(img)
    for box, radius, fill in cards:
        d.rounded_rectangle(box, radius=radius, fill=fill, outline=(255, 255, 255, 88), width=3)
        x1, y1, x2, _ = box
        for j in range(3):
            yy = y1 + 48 + j * 38
            d.rounded_rectangle((x1 + 230, yy, x2 - 56 - j * 28, yy + 13), radius=7, fill=(255, 255, 255, 82))

    arc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arc)
    ad.arc((214, 216, 810, 810), start=220, end=52, fill=(255, 255, 255, 188), width=26)
    ad.arc((255, 255, 769, 769), start=38, end=205, fill=(255, 255, 255, 82), width=15)
    for x, y, r, alpha in [(286, 676, 34, 232), (738, 344, 34, 232), (514, 512, 42, 210)]:
        ad.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, alpha))
        ad.ellipse((x - r + 12, y - r + 12, x + r - 12, y + r - 12), fill=(39, 118, 235, 80))
    img = Image.alpha_composite(img, arc)
    save(img, "01_abstract_flow.png")


def variant_crystal():
    img = add_noise(gradient_bg((24, 36, 124), (88, 80, 236), (6, 182, 212)))

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    points = [(512, 178), (785, 336), (785, 654), (512, 846), (239, 654), (239, 336)]
    sd.polygon([(x + 20, y + 30) for x, y in points], fill=(0, 0, 0, 72))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, shadow)

    d = ImageDraw.Draw(img)
    d.polygon(points, fill=(255, 255, 255, 62), outline=(255, 255, 255, 116))
    facets = [
        [(512, 178), (785, 336), (512, 484)],
        [(785, 336), (785, 654), (512, 484)],
        [(785, 654), (512, 846), (512, 484)],
        [(512, 846), (239, 654), (512, 484)],
        [(239, 654), (239, 336), (512, 484)],
        [(239, 336), (512, 178), (512, 484)],
    ]
    fills = [
        (255, 255, 255, 70),
        (255, 255, 255, 46),
        (255, 255, 255, 58),
        (255, 255, 255, 36),
        (255, 255, 255, 64),
        (255, 255, 255, 42),
    ]
    for facet, fill in zip(facets, fills):
        d.polygon(facet, fill=fill)
        d.line(facet + [facet[0]], fill=(255, 255, 255, 72), width=4)
    for x, y in [(512, 178), (785, 336), (785, 654), (512, 846), (239, 654), (239, 336), (512, 484)]:
        d.ellipse((x - 18, y - 18, x + 18, y + 18), fill=(255, 255, 255, 210))
    save(img, "02_crystal_modules.png")


def variant_pulse():
    img = add_noise(gradient_bg((15, 23, 42), (79, 70, 229), (8, 145, 178)))

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, alpha in [(310, 24), (240, 34), (175, 44)]:
        gd.ellipse((512 - r, 512 - r, 512 + r, 512 + r), fill=(45, 212, 191, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, glow)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle((326, 326, 698, 698), radius=118, fill=(255, 255, 255, 42), outline=(255, 255, 255, 116), width=5)
    d.rounded_rectangle((392, 392, 632, 632), radius=82, fill=(255, 255, 255, 86), outline=(255, 255, 255, 135), width=4)
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        x1 = 512 + math.cos(rad) * 180
        y1 = 512 + math.sin(rad) * 180
        x2 = 512 + math.cos(rad) * 300
        y2 = 512 + math.sin(rad) * 300
        d.line((x1, y1, x2, y2), fill=(255, 255, 255, 130), width=18)
        d.ellipse((x2 - 40, y2 - 40, x2 + 40, y2 + 40), fill=(255, 255, 255, 212))
        d.ellipse((x2 - 22, y2 - 22, x2 + 22, y2 + 22), fill=(20, 184, 166, 110))
    d.ellipse((460, 460, 564, 564), fill=(255, 255, 255, 224))
    save(img, "03_pulse_network.png")


variant_flow()
variant_crystal()
variant_pulse()

print("已生成候选 icon:")
for path in sorted(OUT.glob("*.png")):
    print(path)
