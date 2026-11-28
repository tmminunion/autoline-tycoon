#!/usr/bin/env python3
"""Process a raw square icon PNG/JPG into full-bleed app_icon, adaptive foreground, and Play Store 512px icon."""
import sys, os
from PIL import Image, ImageDraw

if len(sys.argv) < 2:
    print("Usage: python3 store/apply_icon.py <source_image>")
    sys.exit(1)

src_path = sys.argv[1]
src = Image.open(src_path).convert("RGBA")
w, h = src.size

# Flood-fill outer black corners outside the neon squircle border
fg_src = src.copy()
for pt in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
    ImageDraw.floodfill(fg_src, pt, (0, 0, 0, 0), thresh=45)

# 1. Adaptive foreground (1024x1024 RGBA, centered at 76% safe zone)
fg_canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
fg_scaled = fg_src.resize((780, 780), Image.Resampling.LANCZOS)
fg_canvas.paste(fg_scaled, ((1024 - 780) // 2, (1024 - 780) // 2), fg_scaled)
fg_canvas.save("assets/icon/app_icon_foreground.png", optimize=True)

# 2. Full-bleed square icon (replace transparent outer corners with matching royal-blue gradient)
grad = Image.new("RGBA", (w, h))
gpx = grad.load()
for y in range(h):
    t = y / max(1, h - 1)
    rr = int(16 * (1 - t) + 9 * t)
    gg = int(26 * (1 - t) + 18 * t)
    bb = int(228 * (1 - t) + 158 * t)
    for x in range(w):
        gpx[x, y] = (rr, gg, bb, 255)

fb = Image.alpha_composite(grad, fg_src).convert("RGB")
fb.resize((1024, 1024), Image.Resampling.LANCZOS).save("assets/icon/app_icon.png", optimize=True)
fb.resize((512, 512), Image.Resampling.LANCZOS).save("store/playstore/icon_512.png", optimize=True)
print("OK: generated assets/icon/app_icon.png, app_icon_foreground.png, and store/playstore/icon_512.png")
