"""Regenerates the app icons from the palette in lib/ui/theme.dart.

Run from the app/ directory:  python3 tool/make_icons.py
Needs Pillow (pip install pillow).
"""

from PIL import Image, ImageDraw, ImageFont
import math, os

FONT = "assets/fonts/Poppins-ExtraBold.ttf"
FELT_HI, FELT_LO = (27, 107, 71), (7, 36, 25)
GOLD_HI, GOLD_LO = (248, 220, 151), (198, 150, 55)

def base(size, pad_ratio=0.0, rounded=True):
    """Felt square with a radial wash; pad_ratio shrinks the art for maskable icons."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = s / 2
    maxr = math.hypot(cx, cy)
    for i in range(int(maxr), 0, -2):
        t = i / maxr
        col = tuple(int(FELT_HI[c] + (FELT_LO[c] - FELT_HI[c]) * t) for c in range(3))
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=col + (255,))
    if rounded:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
        img.putalpha(mask)
    else:
        flat = Image.new("RGBA", (s, s), FELT_LO + (255,))
        flat.paste(img, (0, 0), img)
        img = flat

    art = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ad = ImageDraw.Draw(art)
    scale = 1 - pad_ratio
    # Gold "29" with a vertical gradient, plus a thin ring.
    f = ImageFont.truetype(FONT, int(s * 0.42 * scale))
    text = "29"
    bbox = ad.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx, ty = (s - tw) / 2 - bbox[0], (s - th) / 2 - bbox[1]
    ad.text((tx, ty), text, font=f, fill=(255, 255, 255, 255))
    grad = Image.new("RGBA", (s, s))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / s
        gd.line([(0, y), (s, y)], fill=tuple(int(GOLD_HI[c] + (GOLD_LO[c] - GOLD_HI[c]) * t) for c in range(3)) + (255,))
    grad.putalpha(art.getchannel("A"))

    ring = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    r = s * 0.455 * scale
    ImageDraw.Draw(ring).ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD_LO + (150,), width=max(2, int(s * 0.012)))

    img = Image.alpha_composite(img, ring)
    img = Image.alpha_composite(img, grad)
    return img.resize((size, size), Image.LANCZOS)

out = {
  "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": (48, 0.0, True),
  "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": (72, 0.0, True),
  "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": (96, 0.0, True),
  "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": (144, 0.0, True),
  "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": (192, 0.0, True),
  "web/favicon.png": (32, 0.0, True),
  "web/icons/Icon-192.png": (192, 0.0, True),
  "web/icons/Icon-512.png": (512, 0.0, True),
  "web/icons/Icon-maskable-192.png": (192, 0.30, False),
  "web/icons/Icon-maskable-512.png": (512, 0.30, False),
}
ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for name in os.listdir(ios):
    if not name.endswith(".png"):
        continue
    px = Image.open(os.path.join(ios, name)).size[0]
    out[f"{ios}/{name}"] = (px, 0.0, False)

for path, (size, pad, rounded) in out.items():
    img = base(size, pad, rounded)
    if path.startswith("ios/"):
        img = img.convert("RGB")
    img.save(path)
print("wrote", len(out), "icons")
