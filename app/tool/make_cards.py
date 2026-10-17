"""Generates the 32-card deck used by the game, plus two card backs.

Run from the app/ directory:  python3 tool/make_cards.py
Needs Pillow (pip install pillow). Writes assets/cards/<rank><suit>.png and back*.png.

The design follows what the best-selling 29 apps do on the Play Store / App Store:
big corner indexes you can read in a tight fan, classic pip layouts, and court cards that
stand out (the jack is the top card in 29). Everything is drawn here as vectors, so the
art is ours to ship. Replace the PNGs with generated art later; the names are the contract.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = "assets/cards"
FONT = "assets/fonts/Poppins-ExtraBold.ttf"
FONT_SEMI = "assets/fonts/Poppins-SemiBold.ttf"

W, H = 280, 380  # 2x the 140x190 the app lays out with; looks sharp up to ~3x DPR
SS = 4  # supersampling factor
RADIUS = 20

FACE = (255, 253, 247)
EDGE = (214, 205, 188)
RED = (200, 34, 44)
BLACK = (24, 26, 30)
GOLD = (196, 150, 58)
GOLD_LIGHT = (236, 206, 140)
TINT = {"red": (252, 238, 236), "black": (238, 240, 243)}

SUITS = {"C": "club", "D": "diamond", "H": "heart", "S": "spade"}
RANKS = {"J": "J", "9": "9", "A": "A", "T": "10", "K": "K", "Q": "Q", "8": "8", "7": "7"}


def s(v):
    """Scale a design coordinate to the supersampled canvas."""
    return int(round(v * SS))


# ----------------------------------------------------------------------------- suit shapes


def heart_points(cx, cy, size):
    pts = []
    for i in range(240):
        t = 2 * math.pi * i / 240
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * size / 34, cy - y * size / 34 - size * 0.06))
    return pts


def draw_suit(d, suit, cx, cy, size, color, flip=False):
    """Draws a suit symbol centred at (cx, cy) with the given height; flip turns it upside down."""
    sgn = -1 if flip else 1

    def P(x, y):  # x, y relative to the centre, in units of size
        return (cx + x * size, cy + sgn * y * size)

    if suit == "heart":
        pts = heart_points(0, 0, 1)
        d.polygon([P(x, y) for x, y in pts], fill=color)
    elif suit == "diamond":
        # Four quadratic edges, each bowed slightly towards the centre.
        corners = [(0, -0.5), (0.38, 0), (0, 0.5), (-0.38, 0)]
        pts = []
        for i in range(4):
            a, c = corners[i], corners[(i + 1) % 4]
            ctrl = ((a[0] + c[0]) * 0.42, (a[1] + c[1]) * 0.42)
            for k in range(30):
                t = k / 30
                x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * ctrl[0] + t * t * c[0]
                y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * ctrl[1] + t * t * c[1]
                pts.append((x, y))
        d.polygon([P(x, y) for x, y in pts], fill=color)
    elif suit == "spade":
        # Inverted heart for the blade, plus a flared stem.
        pts = [(x, -y - 0.07) for x, y in heart_points(0, 0, 0.92)]
        d.polygon([P(x, y) for x, y in pts], fill=color)
        stem = [(0, 0.05), (0.07, 0.36), (0.2, 0.5), (-0.2, 0.5), (-0.07, 0.36)]
        d.polygon([P(x, y) for x, y in stem], fill=color)
    elif suit == "club":
        r = 0.205
        for x, y in [(0, -0.27), (-0.235, 0.08), (0.235, 0.08)]:
            a, b = P(x - r, y - r), P(x + r, y + r)
            d.ellipse([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], fill=color)
        core = [(0, -0.12), (0.14, 0.06), (0, 0.16), (-0.14, 0.06)]
        d.polygon([P(x, y) for x, y in core], fill=color)
        stem = [(0, 0.04), (0.07, 0.36), (0.2, 0.5), (-0.2, 0.5), (-0.07, 0.36)]
        d.polygon([P(x, y) for x, y in stem], fill=color)


# ----------------------------------------------------------------------------- card parts


def blank_card():
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s(W) - 1, s(H) - 1], radius=s(RADIUS), fill=FACE, outline=EDGE, width=s(1.5))
    return img, d


def text_size(d, text, font):
    b = d.textbbox((0, 0), text, font=font)
    return b, b[2] - b[0], b[3] - b[1]


def draw_index(img, rank, suit, color):
    """Top-left index (big rank over suit), mirrored into the bottom-right corner."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    label = RANKS[rank]
    size = 58 if label != "10" else 50
    font = ImageFont.truetype(FONT, s(size))
    b, tw, th = text_size(d, label, font)
    cx = s(34)
    # "10" is drawn tighter so it stays inside the corner.
    if label == "10":
        f1 = font
        b1, w1, _ = text_size(d, "1", f1)
        b0, w0, _ = text_size(d, "0", f1)
        gap = -s(3)
        total = w1 + w0 + gap
        x = cx - total / 2
        d.text((x - b1[0], s(14) - b[1]), "1", font=f1, fill=color)
        d.text((x + w1 + gap - b0[0], s(14) - b[1]), "0", font=f1, fill=color)
    else:
        d.text((cx - tw / 2 - b[0], s(14) - b[1]), label, font=font, fill=color)
    draw_suit(d, SUITS[suit], cx, s(14) + th + s(26), s(34), color)
    img.alpha_composite(layer)
    img.alpha_composite(layer.rotate(180))


PIP_LAYOUTS = {
    # (column, row) in a 0..1 pip box; rows below 0.5 are drawn upside down.
    "7": [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
    "8": [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0.5, 0.75), (0, 1), (1, 1)],
    "9": [(0, 0), (1, 0), (0, 1 / 3), (1, 1 / 3), (0.5, 0.5), (0, 2 / 3), (1, 2 / 3), (0, 1), (1, 1)],
    "T": [(0, 0), (1, 0), (0.5, 1 / 6), (0, 1 / 3), (1, 1 / 3), (0, 2 / 3), (1, 2 / 3), (0.5, 5 / 6), (0, 1), (1, 1)],
}


def draw_pips(img, rank, suit, color):
    d = ImageDraw.Draw(img)
    x0, x1, y0, y1 = s(86), s(194), s(74), s(306)
    size = s(50)
    for cx, cy in PIP_LAYOUTS[rank]:
        x = x0 + (x1 - x0) * cx
        y = y0 + (y1 - y0) * cy
        draw_suit(d, SUITS[suit], x, y, size, color, flip=cy > 0.5)


def draw_ace(img, suit, color):
    d = ImageDraw.Draw(img)
    cx, cy = s(W / 2), s(H / 2)
    # Gold rings behind the big pip.
    for r, w, c in [(s(78), s(2.2), GOLD), (s(70), s(1), GOLD_LIGHT)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=int(w))
    draw_suit(d, SUITS[suit], cx, cy + s(4), s(104), color)


def crown(d, cx, cy, w, h, kind, color, accent):
    """A small crown / cap above the court letter. kind: K, Q or J."""
    if kind == "K":
        pts = [(-0.5, 0.5), (-0.5, -0.1), (-0.25, 0.18), (0, -0.5), (0.25, 0.18), (0.5, -0.1), (0.5, 0.5)]
    elif kind == "Q":
        pts = [(-0.5, 0.5), (-0.42, -0.2), (-0.21, 0.12), (0, -0.35), (0.21, 0.12), (0.42, -0.2), (0.5, 0.5)]
    else:  # jack: the top card in 29 gets a star crest instead of a crown
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            rad = 0.62 if i % 2 == 0 else 0.26
            pts.append((rad * math.cos(ang) * h / w, rad * math.sin(ang) + 0.05))
        d.polygon([(cx + x * w, cy + y * h) for x, y in pts], fill=color)
        d.ellipse([cx - 0.09 * h, cy - 0.04 * h, cx + 0.09 * h, cy + 0.14 * h], fill=accent)
        return
    d.polygon([(cx + x * w, cy + y * h) for x, y in pts], fill=color)
    d.rectangle([cx - 0.5 * w, cy + 0.32 * h, cx + 0.5 * w, cy + 0.5 * h], fill=accent)
    tips = [(-0.5, -0.1), (0, -0.5), (0.5, -0.1)] if kind == "K" else [(-0.42, -0.2), (0, -0.35), (0.42, -0.2)]
    r = 0.11 * h
    for x, y in tips:
        px, py = cx + x * w, cy + y * h
        d.ellipse([px - r, py - r, px + r, py + r], fill=accent)


def draw_court(img, rank, suit, color):
    tone = "red" if suit in ("H", "D") else "black"
    d = ImageDraw.Draw(img)
    l, t, r, b = s(62), s(48), s(W - 62), s(H - 48)
    d.rounded_rectangle([l, t, r, b], radius=s(12), fill=TINT[tone])

    # Fine diagonal hatch inside the panel for texture.
    hatch = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hatch)
    step = s(9)
    for x in range(l - (b - t), r, step):
        hd.line([(x, b), (x + (b - t), t)], fill=color + (16,), width=s(1))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([l, t, r, b], radius=s(12), fill=255)
    img.paste(hatch, (0, 0), Image.composite(hatch, Image.new("RGBA", img.size), mask).getchannel("A"))

    d = ImageDraw.Draw(img)
    # Gold double frame.
    d.rounded_rectangle([l, t, r, b], radius=s(12), outline=GOLD, width=s(2.4))
    d.rounded_rectangle([l + s(5), t + s(5), r - s(5), b - s(5)], radius=s(9), outline=GOLD_LIGHT, width=s(1))

    # Top half: crown, big letter, suit. Then mirror it, like a real court card.
    half = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(half)
    cx = s(W / 2)
    crown(hd, cx, s(84), s(64), s(34), rank, GOLD, color)
    font = ImageFont.truetype(FONT, s(86))
    bb, tw, th = text_size(hd, rank, font)
    hd.text((cx - tw / 2 - bb[0], s(104) - bb[1]), rank, font=font, fill=color)
    draw_suit(hd, SUITS[suit], s(W / 2 + 52), s(116), s(26), color)
    clip = Image.new("L", img.size, 0)
    ImageDraw.Draw(clip).rectangle([0, 0, s(W), s(H / 2)], fill=255)
    top = Image.composite(half, Image.new("RGBA", img.size, (0, 0, 0, 0)), clip)
    img.alpha_composite(top)
    img.alpha_composite(top.rotate(180))

    # Diagonal divider through the middle, as on printed courts.
    d = ImageDraw.Draw(img)
    d.line([(l + s(10), s(H / 2) + s(16)), (r - s(10), s(H / 2) - s(16))], fill=GOLD, width=s(2))


def finish(img):
    return img.resize((W, H), Image.LANCZOS)


def make_face(rank, suit):
    color = RED if suit in ("H", "D") else BLACK
    img, _ = blank_card()
    if rank in PIP_LAYOUTS:
        draw_pips(img, rank, suit, color)
    elif rank == "A":
        draw_ace(img, suit, color)
    else:
        draw_court(img, rank, suit, color)
    draw_index(img, rank, suit, color)
    return finish(img)


def make_back(base_hi, base_lo, accent):
    img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s(W) - 1, s(H) - 1], radius=s(RADIUS), fill=255)

    grad = Image.new("RGBA", img.size)
    gd = ImageDraw.Draw(grad)
    cx, cy = s(W / 2), s(H / 2)
    maxr = math.hypot(cx, cy)
    for i in range(int(maxr), 0, -4):
        t = i / maxr
        c = tuple(int(base_hi[k] + (base_lo[k] - base_hi[k]) * t) for k in range(3))
        gd.ellipse([cx - i, cy - i, cx + i, cy + i], fill=c + (255,))

    d = ImageDraw.Draw(grad)
    # White margin, like a printed back.
    inset = s(12)
    frame = Image.new("RGBA", img.size, (255, 253, 247, 255))
    fmask = Image.new("L", img.size, 255)
    ImageDraw.Draw(fmask).rounded_rectangle([inset, inset, s(W) - inset, s(H) - inset], radius=s(10), fill=0)
    grad.paste(frame, (0, 0), fmask)

    # Gold lattice inside the frame.
    lattice = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lattice)
    step = s(22)
    for k in range(-s(H), s(W) + s(H), step):
        ld.line([(k, 0), (k + s(H), s(H))], fill=accent + (70,), width=s(1.2))
        ld.line([(k, s(H)), (k + s(H), 0)], fill=accent + (70,), width=s(1.2))
    inner = Image.new("L", img.size, 0)
    ImageDraw.Draw(inner).rounded_rectangle([inset + s(6), inset + s(6), s(W) - inset - s(6), s(H) - inset - s(6)], radius=s(8), fill=255)
    grad.alpha_composite(Image.composite(lattice, Image.new("RGBA", img.size, (0, 0, 0, 0)), inner))
    d = ImageDraw.Draw(grad)
    d.rounded_rectangle([inset + s(6), inset + s(6), s(W) - inset - s(6), s(H) - inset - s(6)], radius=s(8), outline=accent, width=s(2))

    # Centre medallion with the wordmark.
    r = s(52)
    d.ellipse([cx - r - s(6), cy - r - s(6), cx + r + s(6), cy + r + s(6)], fill=base_lo + (255,))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=base_hi + (255,), outline=accent, width=s(3))
    font = ImageFont.truetype(FONT, s(50))
    bb, tw, th = text_size(d, "29", font)
    d.text((cx - tw / 2 - bb[0], cy - th / 2 - bb[1]), "29", font=font, fill=accent)

    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([0, 0, s(W) - 1, s(H) - 1], radius=s(RADIUS), outline=EDGE, width=s(1.5))
    return finish(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    for suit in SUITS:
        for rank in RANKS:
            make_face(rank, suit).save(f"{OUT}/{rank}{suit}.png", optimize=True)
    make_back((24, 104, 70), (8, 46, 31), GOLD_LIGHT).save(f"{OUT}/back.png", optimize=True)
    make_back((150, 32, 44), (70, 12, 20), GOLD_LIGHT).save(f"{OUT}/back_red.png", optimize=True)
    print("wrote", len(SUITS) * len(RANKS) + 2, "cards to", OUT)


if __name__ == "__main__":
    main()
