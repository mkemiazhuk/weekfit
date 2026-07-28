#!/usr/bin/env python3
"""Generate WeekFit Instagram carousel-001 — 6 slides, moodboard-matched.

Premium dark lifestyle style:
lifestyle photography, gold emphasis words, framed iPhone mockups,
floating UI cards, Apple Health badge, brand lockup close.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "docs" / "img"
BRAND = ROOT / "web" / "public" / "brand"
ASSETS = ROOT / "web" / "public" / "instagram" / "carousel-001" / "assets"
DEVICE = ROOT / "web" / "public" / "mockify" / "devices" / "iPhone 16 Pro - Black Titanium.png"
OUT = ROOT / "web" / "public" / "instagram" / "carousel-001"

W, H = 1080, 1350
TOTAL = 6
GOLD = (232, 184, 74)
GOLD_SOFT = (245, 206, 120)
WHITE = (250, 250, 252)
MUTED = (176, 180, 186)
DARK = (8, 9, 12)

FONT = "/System/Library/Fonts/Avenir Next.ttc"
FRAME_SCREEN = (41, 39, 718, 1514)


def font(size: int, weight: str = "bold") -> ImageFont.FreeTypeFont:
    index = {"heavy": 8, "bold": 0, "demi": 2, "medium": 5, "regular": 7}[weight]
    return ImageFont.truetype(FONT, size=size, index=index)


def cover_image(path: Path, size: tuple[int, int], focus: tuple[float, float] = (0.5, 0.45)) -> Image.Image:
    img = Image.open(path).convert("RGB")
    tw, th = size
    scale = max(tw / img.width, th / img.height)
    nw, nh = int(img.width * scale), int(img.height * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = int((nw - tw) * focus[0])
    top = int((nh - th) * focus[1])
    left = max(0, min(left, nw - tw))
    top = max(0, min(top, nh - th))
    return img.crop((left, top, left + tw, top + th))


def soft_glow(
    canvas: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    alpha: int = 80,
) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(10, 0, -1):
        r = int(radius * i / 10)
        a = int(alpha * (i / 10) ** 1.8)
        d.ellipse((center[0] - r, center[1] - r, center[0] + r, center[1] + r), fill=(*color, a))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(56)))


def dark_canvas(glow: tuple[int, int, int] | None = None) -> Image.Image:
    base = Image.new("RGB", (W, H), DARK).convert("RGBA")
    if glow:
        soft_glow(base, (W // 2, int(H * 0.55)), 480, glow, alpha=48)
    return base


def vignette_over(photo: Image.Image, strength: float = 0.72) -> Image.Image:
    out = photo.convert("RGBA")
    overlay = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for y in range(out.height):
        t = y / max(out.height - 1, 1)
        a = int(255 * strength * (0.12 + 0.88 * (t**1.45)))
        d.line([(0, y), (out.width, y)], fill=(0, 0, 0, a))
    for y in range(0, 200):
        a = int(120 * (1 - y / 200))
        d.line([(0, y), (out.width, y)], fill=(0, 0, 0, a))
    return Image.alpha_composite(out, overlay)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_w: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_rich_title(
    draw: ImageDraw.ImageDraw,
    lines: list[tuple[str, str]],
    xy: tuple[int, int],
    size: int = 64,
    max_w: int = 920,
    gap: int = 8,
) -> int:
    x, y = xy
    f_w = font(size, "heavy")
    f_g = font(size, "heavy")
    for white, gold in lines:
        if gold and white and draw.textlength(f"{white} {gold}", font=f_w) <= max_w:
            draw.text((x, y), white + " ", font=f_w, fill=WHITE)
            wx = x + draw.textlength(white + " ", font=f_w)
            draw.text((wx, y), gold, font=f_g, fill=GOLD)
            y += size + gap
            continue
        if white:
            for line in wrap(draw, white, f_w, max_w):
                draw.text((x, y), line, font=f_w, fill=WHITE)
                y += size + gap
        if gold:
            for line in wrap(draw, gold, f_g, max_w):
                draw.text((x, y), line, font=f_g, fill=GOLD)
                y += size + gap
    return y


def draw_body(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], max_w: int = 520, size: int = 26) -> int:
    f = font(size, "regular")
    x, y = xy
    for line in wrap(draw, text, f, max_w):
        draw.text((x, y), line, font=f, fill=MUTED)
        y += size + 7
    return y


def draw_counter(draw: ImageDraw.ImageDraw, i: int) -> None:
    f = font(22, "medium")
    label = f"{i}/{TOTAL}"
    tw = draw.textlength(label, font=f)
    draw.text((W - 56 - tw, 44), label, font=f, fill=(130, 134, 140))


def logo_lockup(height: int = 40) -> Image.Image:
    mark = Image.open(BRAND / "logo-wf-mark.png").convert("RGBA")
    mark.thumbnail((height, height), Image.Resampling.LANCZOS)
    word = font(26, "demi")
    tmp = Image.new("RGBA", (420, height + 8), (0, 0, 0, 0))
    tmp.alpha_composite(mark, (0, (tmp.height - mark.height) // 2))
    d = ImageDraw.Draw(tmp)
    d.text((mark.width + 12, (tmp.height - 26) // 2 - 1), "WEEKFIT", font=word, fill=WHITE)
    bbox = tmp.getbbox()
    return tmp.crop(bbox) if bbox else tmp


def apple_health_badge(scale: float = 1.0) -> Image.Image:
    pad_x, pad_y = int(18 * scale), int(11 * scale)
    heart_r = int(10 * scale)
    f = font(int(21 * scale), "medium")
    text = "Works with Apple Health"
    probe = ImageDraw.Draw(Image.new("RGBA", (8, 8)))
    tw = probe.textlength(text, font=f)
    bw = int(pad_x * 2 + heart_r * 2 + 10 * scale + tw)
    bh = int(pad_y * 2 + max(heart_r * 2, f.size) + 4)
    badge = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), radius=bh // 2, fill=(255, 255, 255, 235))
    hx = pad_x + heart_r
    hy = bh // 2
    d.ellipse((hx - heart_r, hy - heart_r + 1, hx, hy + 2), fill=(255, 45, 85))
    d.ellipse((hx, hy - heart_r + 1, hx + heart_r, hy + 2), fill=(255, 45, 85))
    d.polygon([(hx - heart_r, hy - 1), (hx + heart_r, hy - 1), (hx, hy + heart_r + 2)], fill=(255, 45, 85))
    d.text((pad_x + heart_r * 2 + int(10 * scale), (bh - f.size) // 2 - 1), text, font=f, fill=(20, 20, 22))
    return badge


def framed_phone(screenshot: Path, phone_h: int = 860) -> Image.Image:
    frame = Image.open(DEVICE).convert("RGBA")
    scale = phone_h / frame.height
    frame = frame.resize((int(frame.width * scale), phone_h), Image.Resampling.LANCZOS)
    sl, st, sr, sb = [int(v * scale) for v in FRAME_SCREEN]
    sw, sh = sr - sl + 1, sb - st + 1

    shot = Image.open(screenshot).convert("RGB")
    s_scale = max(sw / shot.width, sh / shot.height)
    nw, nh = int(shot.width * s_scale), int(shot.height * s_scale)
    shot = shot.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - sw) // 2
    top = (nh - sh) // 2
    shot = shot.crop((left, top, left + sw, top + sh)).convert("RGBA")
    shot = rounded(shot, radius=max(24, int(40 * scale)))

    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    canvas.paste(shot, (sl, st), shot)
    canvas.alpha_composite(frame)
    return canvas


def drop_shadow(
    img: Image.Image,
    blur: int = 26,
    offset: tuple[int, int] = (0, 18),
    opacity: int = 140,
) -> Image.Image:
    shadow = Image.new(
        "RGBA",
        (img.width + abs(offset[0]) + blur * 2, img.height + abs(offset[1]) + blur * 2),
        (0, 0, 0, 0),
    )
    mask = img.split()[-1]
    sh = Image.new("RGBA", img.size, (0, 0, 0, opacity))
    sh.putalpha(mask)
    ox = blur + max(offset[0], 0)
    oy = blur + max(offset[1], 0)
    shadow.paste(sh, (ox + offset[0], oy + offset[1]), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(img, (blur - min(offset[0], 0), blur - min(offset[1], 0)))
    return out


def glass_card(size: tuple[int, int], radius: int = 26) -> Image.Image:
    return rounded(Image.new("RGBA", size, (18, 20, 26, 228)), radius)


def icon_circle(kind: str, size: int = 52) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, size - 1, size - 1), fill=(*GOLD, 32), outline=(*GOLD, 200), width=2)
    c = size // 2
    g = GOLD
    if kind == "sleep":
        d.ellipse((c - 10, c - 12, c + 10, c + 12), outline=g, width=2)
        d.ellipse((c - 3, c - 12, c + 14, c + 12), fill=DARK + (255,))
    elif kind == "hrv":
        pts = [(9, c), (16, c), (21, c - 10), (27, c + 11), (33, c - 6), (39, c), (46, c)]
        d.line(pts, fill=g, width=2, joint="curve")
    elif kind == "activity":
        d.line([(18, 34), (30, 17), (42, 34)], fill=g, width=2)
        d.line([(30, 17), (30, 40)], fill=g, width=2)
    elif kind == "nutrition":
        d.ellipse((c - 9, c - 9, c + 9, c + 9), outline=g, width=2)
        d.line([(c, c - 13), (c, c + 13)], fill=g, width=2)
    elif kind == "coach":
        d.ellipse((c - 8, c - 10, c + 8, c + 6), outline=g, width=2)
        d.line([(c, c + 6), (c, c + 14)], fill=g, width=2)
    elif kind == "plan":
        d.rounded_rectangle((14, 14, size - 14, size - 14), radius=4, outline=g, width=2)
        d.line([(20, 22), (size - 20, 22)], fill=g, width=2)
        d.rectangle((20, 28, 28, 36), outline=g, width=1)
        d.rectangle((32, 28, 40, 36), outline=g, width=1)
    elif kind == "recovery":
        d.arc((14, 14, size - 14, size - 14), start=40, end=320, fill=g, width=2)
        d.polygon([(size - 18, 18), (size - 10, 28), (size - 26, 28)], fill=g)
    return img


def place_phone(canvas: Image.Image, phone: Image.Image, xy: tuple[int, int]) -> None:
    canvas.alpha_composite(drop_shadow(phone, blur=28, offset=(0, 20), opacity=145), xy)


# ---------- 6 moodboard slides ----------


def slide_01() -> Image.Image:
    photo = cover_image(ASSETS / "ig-bg-sunrise-cliff.png", (W, H), focus=(0.5, 0.42))
    canvas = vignette_over(photo, strength=0.80)
    draw = ImageDraw.Draw(canvas)

    canvas.alpha_composite(logo_lockup(38), (56, 48))
    draw_counter(draw, 1)

    y = draw_rich_title(draw, [("Feel", "ready.")], (56, 980), size=80, max_w=960, gap=6)
    draw.text((56, y + 10), "AI-powered recovery for better days.", font=font(28, "medium"), fill=GOLD_SOFT)

    badge = apple_health_badge(0.95)
    canvas.alpha_composite(badge, (56, H - badge.height - 52))
    return canvas.convert("RGB")


def slide_02() -> Image.Image:
    canvas = dark_canvas((35, 95, 75))
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 2)

    y = draw_rich_title(
        draw,
        [("Your body speaks.", ""), ("", "We listen.")],
        (56, 64),
        size=56,
        max_w=620,
        gap=6,
    )
    draw_body(
        draw,
        "Advanced analysis of your recovery, sleep, HRV and daily activity.",
        (56, y + 14),
        max_w=500,
        size=26,
    )

    signals = [("sleep", "Sleep"), ("hrv", "HRV"), ("activity", "Activity")]
    iy = 390
    for kind, label in signals:
        canvas.alpha_composite(icon_circle(kind, 50), (56, iy))
        draw.text((122, iy + 11), label, font=font(24, "medium"), fill=MUTED)
        iy += 74

    phone = framed_phone(IMG / "recovery.jpg", phone_h=820)
    # sit lower-right with breathing room
    place_phone(canvas, phone, (W - phone.width - 8, H - phone.height - 36))
    return canvas.convert("RGB")


def slide_03() -> Image.Image:
    canvas = dark_canvas((110, 65, 28))
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 3)

    y = draw_rich_title(
        draw,
        [("Eat for recovery.", ""), ("", "Not just calories.")],
        (56, 56),
        size=52,
        max_w=960,
        gap=6,
    )
    draw_body(draw, "Track meals easily and get personalized feedback.", (56, y + 10), max_w=720, size=26)

    phone = framed_phone(IMG / "meal-details.jpg", phone_h=720)
    place_phone(canvas, phone, ((W - phone.width) // 2 + 60, 270))

    card_w, card_h = 290, 112
    c1 = glass_card((card_w, card_h), 22)
    c2 = glass_card((card_w, card_h), 22)
    d1 = ImageDraw.Draw(c1)
    d2 = ImageDraw.Draw(c2)
    d1.text((20, 16), "Nutrition Quality", font=font(18, "medium"), fill=MUTED)
    d1.text((20, 48), "89/100", font=font(38, "heavy"), fill=WHITE)
    d2.text((20, 16), "Calories", font=font(18, "medium"), fill=MUTED)
    d2.text((20, 48), "1706 / 1676", font=font(30, "heavy"), fill=WHITE)

    canvas.alpha_composite(drop_shadow(c1, blur=14, offset=(0, 8), opacity=110), (56, H - 188))
    canvas.alpha_composite(drop_shadow(c2, blur=14, offset=(0, 8), opacity=110), (370, H - 188))
    return canvas.convert("RGB")


def slide_04() -> Image.Image:
    photo = cover_image(ASSETS / "ig-bg-bedroom-lamp.png", (W, H), focus=(0.55, 0.4))
    canvas = vignette_over(photo, strength=0.84)
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 4)

    y = draw_rich_title(
        draw,
        [("AI that knows when to push.", ""), ("And when to", "stop.")],
        (56, 64),
        size=50,
        max_w=960,
        gap=6,
    )
    draw_body(draw, "Personalized coaching based on your data.", (56, y + 10), max_w=700, size=26)

    card = glass_card((920, 340), 30)
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((28, 26, 268, 66), radius=16, fill=(120, 90, 200, 70), outline=(180, 150, 255, 150), width=1)
    d.text((46, 34), "COACH  ·  SAVE ENERGY", font=font(18, "demi"), fill=(220, 210, 255))
    d.text((28, 88), "Wind the day down.", font=font(38, "heavy"), fill=WHITE)
    d.text((28, 142), "Tomorrow needs fresh legs — sleep first.", font=font(24, "regular"), fill=MUTED)
    d.text((28, 220), "WHY", font=font(17, "demi"), fill=GOLD)
    d.text((28, 250), "Core is on the calendar tomorrow.", font=font(24, "medium"), fill=WHITE)

    canvas.alpha_composite(drop_shadow(card, blur=22, offset=(0, 14), opacity=130), (80, H - 430))
    return canvas.convert("RGB")


def slide_05() -> Image.Image:
    canvas = dark_canvas((45, 70, 120))
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 5)

    y = draw_rich_title(
        draw,
        [("One app.", ""), ("", "Every health decision.")],
        (56, 56),
        size=52,
        max_w=560,
        gap=6,
    )
    draw_body(draw, "All your health data. All in one place.", (56, y + 12), max_w=460, size=26)

    features = [
        ("recovery", "Recovery"),
        ("sleep", "Sleep"),
        ("activity", "Activity"),
        ("nutrition", "Nutrition"),
        ("coach", "Coach"),
        ("plan", "Plan"),
    ]
    fy = 340
    for kind, label in features:
        canvas.alpha_composite(icon_circle(kind, 46), (56, fy))
        draw.text((116, fy + 9), label, font=font(24, "medium"), fill=WHITE)
        fy += 66

    phone = framed_phone(IMG / "today.jpg", phone_h=820)
    place_phone(canvas, phone, (W - phone.width - 4, H - phone.height - 40))
    return canvas.convert("RGB")


def slide_06() -> Image.Image:
    canvas = dark_canvas((150, 115, 40))
    soft_glow(canvas, (W // 2, H // 2 - 60), 360, GOLD, alpha=38)
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 6)

    icon = Image.open(BRAND / "app-icon.png").convert("RGBA")
    icon = rounded(icon.resize((260, 260), Image.Resampling.LANCZOS), 60)
    icon = drop_shadow(icon, blur=34, offset=(0, 16), opacity=145)
    canvas.alpha_composite(icon, ((W - icon.width) // 2, 340))

    word = font(48, "medium")
    label = "W E E K F I T"
    tw = draw.textlength(label, font=word)
    draw.text(((W - tw) / 2, 700), label, font=word, fill=WHITE)

    sub = font(26, "medium")
    s = "Powered by Apple Health"
    sw = draw.textlength(s, font=sub)
    draw.text(((W - sw) / 2, 768), s, font=sub, fill=GOLD)

    badge = apple_health_badge(1.05)
    canvas.alpha_composite(badge, ((W - badge.width) // 2, H - badge.height - 88))
    return canvas.convert("RGB")


def write_caption(path: Path) -> None:
    path.write_text(
        """Feel ready.

WeekFit turns Apple Health signals — recovery, sleep, HRV, activity and nutrition — into one calm decision each day.

Not another dashboard.
A clear call: when to push, and when to stop.

#WeekFit #AppleHealth #recovery #HRV #trainingnutrition
""",
        encoding="utf-8",
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)

    slides = [slide_01, slide_02, slide_03, slide_04, slide_05, slide_06]
    for i, fn in enumerate(slides, start=1):
        img = fn()
        out = OUT / f"slide-{i:02d}.png"
        img.save(out, format="PNG", optimize=True)
        print(f"wrote {out.relative_to(ROOT)}")

    # Remove leftover slides from the 8-slide draft
    for stale in OUT.glob("slide-*.png"):
        n = stale.stem.split("-")[-1]
        if n.isdigit() and int(n) > TOTAL:
            stale.unlink()
            print(f"removed {stale.relative_to(ROOT)}")

    write_caption(OUT / "caption.txt")
    print(f"wrote {(OUT / 'caption.txt').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
