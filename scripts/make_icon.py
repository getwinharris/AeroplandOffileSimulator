#!/usr/bin/env python3
"""Generate a cute App Store icon (1024x1024) with no external assets — pure PIL."""
import os
try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("pip install pillow, then re-run")

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# sky rounded square
d.rounded_rectangle([0, 0, S, S], radius=230, fill=(56, 150, 255, 255))
# sun
d.ellipse([680, 90, 930, 340], fill=(255, 214, 64, 255))
# cloud puffs
for x, y, r in [(180, 700, 90), (300, 660, 120), (430, 700, 90), (700, 780, 80), (810, 740, 100)]:
    d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 235))
# plane body (simple cute jet seen front-ish): red fuselage ellipse
d.ellipse([312, 312, 712, 712], fill=(232, 64, 64, 255))
# wings
d.polygon([(120, 560), (380, 480), (380, 600)], fill=(255, 210, 63, 255))
d.polygon([(904, 560), (644, 480), (644, 600)], fill=(255, 210, 63, 255))
# cockpit
d.ellipse([442, 380, 582, 520], fill=(165, 230, 255, 255))
# smiley eyes
d.ellipse([450, 560, 500, 610], fill=(20, 20, 20, 255))
d.ellipse([524, 560, 574, 610], fill=(20, 20, 20, 255))
d.ellipse([468, 568, 484, 584], fill=(255, 255, 255, 255))
d.ellipse([542, 568, 558, 584], fill=(255, 255, 255, 255))
out = os.path.join(os.path.dirname(__file__), "..", "AppStore", "Icon-1024.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print("wrote", out)
