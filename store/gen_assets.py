#!/usr/bin/env python3
"""Generate Nufat Games store assets: icon 512/1024, adaptive foreground, feature graphic."""
import random, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
ICON_DIR = os.path.join(OUT, '..', 'assets', 'icon')
CY, PK, PU, YL, GR = (34, 211, 238), (255, 61, 129), (168, 85, 247), (250, 204, 21), (74, 222, 128)
BG1, BG2, DARK = (8, 10, 30), (22, 12, 52), (20, 18, 56, 255)
S = 3  # supersample


def font(size, bold=True):
    for p in (['/system/fonts/DroidSans-Bold.ttf', '/system/fonts/Roboto-Bold.ttf'] if bold
              else ['/system/fonts/DroidSans.ttf', '/system/fonts/Roboto-Regular.ttf']):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def bg(w, h, seed=7):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):  # vertical+diagonal-ish gradient by rows
        t = y / h
        d.line([0, y, w, y], fill=tuple(int(BG1[i] + (BG2[i] - BG1[i]) * t) for i in range(3)))
    r = random.Random(seed)
    for _ in range(int(w * h / 9000)):
        x, y, s = r.randrange(w), r.randrange(h), r.choice([1, 1, 2])
        d.ellipse([x, y, x + s, y + s], fill=(190, 200, 255))
    return img


def glow(base, draw_fn, color, blur):
    layer = Image.new('RGBA', base.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer), color + (255,))
    g = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(g)
    base.alpha_composite(g)


def gamepad(size, scale=1.0):
    """Transparent RGBA size x size with a neon gamepad centered."""
    W = size * S
    L = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    c = W / 2
    k = W / 1024 * scale

    def body(d, col, sk=0.0):
        d.rounded_rectangle([c - 330 * k + sk, c - 170 * k + sk, c + 330 * k - sk, c + 90 * k - sk],
                            radius=max(130 * k - sk, 1), fill=col)
        d.ellipse([c - 400 * k + sk, c - 60 * k + sk, c - 150 * k - sk, c + 260 * k - sk], fill=col)
        d.ellipse([c + 150 * k + sk, c - 60 * k + sk, c + 400 * k - sk, c + 260 * k - sk], fill=col)

    glow(L, lambda d, col: body(d, col), PU, 26 * k)
    body(ImageDraw.Draw(L), CY + (255,))
    body(ImageDraw.Draw(L), DARK, 14 * k)

    d = ImageDraw.Draw(L)
    px_, py_ = c - 215 * k, c - 40 * k  # d-pad
    a, b = 38 * k, 112 * k
    d.rounded_rectangle([px_ - a, py_ - b, px_ + a, py_ + b], radius=14 * k, fill=CY + (255,))
    d.rounded_rectangle([px_ - b, py_ - a, px_ + b, py_ + a], radius=14 * k, fill=CY + (255,))
    d.ellipse([px_ - 26 * k, py_ - 26 * k, px_ + 26 * k, py_ + 26 * k], fill=DARK)
    bx, by, r, off = c + 215 * k, c - 40 * k, 40 * k, 78 * k  # buttons
    for dx, dy, col in [(0, -off, YL), (off, 0, PK), (0, off, GR), (-off, 0, PU)]:
        glow(L, lambda dd, cc, dx=dx, dy=dy: dd.ellipse([bx + dx - r, by + dy - r, bx + dx + r, by + dy + r], fill=cc), col, 10 * k)
    d = ImageDraw.Draw(L)
    for dx, dy, col in [(0, -off, YL), (off, 0, PK), (0, off, GR), (-off, 0, PU)]:
        d.ellipse([bx + dx - r, by + dy - r, bx + dx + r, by + dy + r], fill=col + (255,))
    for dx in (-60, 60):  # start/select
        d.rounded_rectangle([c + dx * k - 38 * k, c - 110 * k, c + dx * k + 38 * k, c - 90 * k], radius=10 * k, fill=(120, 130, 200, 255))
    return L.resize((size, size), Image.LANCZOS)


def make_icon(size=1024):
    img = bg(size, size).convert('RGBA')
    halo = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([size * .12, size * .12, size * .88, size * .88], fill=PU + (90,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * .08)))
    img.alpha_composite(gamepad(size, 1.0))
    return img.convert('RGB')


def make_feature():
    W, H = 1024, 500
    img = bg(W, H, seed=21).convert('RGBA')
    g = ImageDraw.Draw(img)
    for x in range(0, W, 48):
        g.line([x, 0, x, H], fill=(60, 70, 140, 255), width=1)
    img = Image.blend(img, bg(W, H, seed=21).convert('RGBA'), 0.85)
    halo = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([-30, 70, 400, 480], fill=PU + (110,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(40)))
    img.alpha_composite(gamepad(400, 1.0), (-15, 50))
    d = ImageDraw.Draw(img)
    d.text((400, 96), 'Nufat Games', font=font(78), fill=(255, 255, 255))
    d.text((402, 190), 'Arcade neon 60 FPS + 20 game cloud', font=font(27, False), fill=(150, 225, 255))
    d.text((402, 232), 'Main cepat, ringan, tanpa akun. Game baru muncul', font=font(21, False), fill=(190, 195, 230))
    d.text((402, 260), 'otomatis tanpa update aplikasi.', font=font(21, False), fill=(190, 195, 230))
    x = 402
    for label, col in [('ARCADE', CY), ('PUZZLE', PU), ('QUIZ', YL), ('SKOR LOKAL', PK)]:
        f = font(17)
        w = int(d.textlength(label, font=f)) + 28
        d.rounded_rectangle([x, 332, x + w, 368], radius=18, outline=col, width=2)
        d.text((x + 14, 340), label, font=f, fill=col)
        x += w + 12
    return img.convert('RGB')


if __name__ == '__main__':
    os.makedirs(os.path.join(OUT, 'playstore'), exist_ok=True)
    ic = make_icon(1024)
    ic.save(os.path.join(ICON_DIR, 'app_icon.png'))
    gamepad(1024, 0.62).save(os.path.join(ICON_DIR, 'app_icon_foreground.png'))  # adaptive safe zone
    ic.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'playstore', 'icon_512.png'))
    make_feature().save(os.path.join(OUT, 'playstore', 'feature_graphic_1024x500.png'))
    print('ok')
