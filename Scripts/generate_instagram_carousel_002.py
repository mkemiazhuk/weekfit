#!/usr/bin/env python3
"""Generate WeekFit Instagram carousel-002 — 3 slides on calories.

How we calculate calories, how movement raises the budget,
and how eating spends it — matching carousel-001 brand style.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "docs" / "img"
BRAND = ROOT / "web" / "public" / "brand"
DEVICE = ROOT / "web" / "public" / "mockify" / "devices" / "iPhone 16 Pro - Black Titanium.png"
OUT = ROOT / "web" / "public" / "instagram" / "carousel-002"

W, H = 1080, 1350
TOTAL = 3
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
    if kind == "body":
        d.ellipse((c - 7, c - 14, c + 7, c - 2), outline=g, width=2)
        d.arc((c - 12, c - 2, c + 12, c + 16), start=200, end=340, fill=g, width=2)
    elif kind == "activity":
        d.line([(18, 34), (30, 17), (42, 34)], fill=g, width=2)
        d.line([(30, 17), (30, 40)], fill=g, width=2)
    elif kind == "nutrition":
        d.ellipse((c - 9, c - 9, c + 9, c + 9), outline=g, width=2)
        d.line([(c, c - 13), (c, c + 13)], fill=g, width=2)
    elif kind == "goal":
        d.ellipse((14, 14, size - 14, size - 14), outline=g, width=2)
        d.ellipse((c - 4, c - 4, c + 4, c + 4), fill=g)
    elif kind == "plus":
        d.line([(c, 16), (c, size - 16)], fill=g, width=2)
        d.line([(16, c), (size - 16, c)], fill=g, width=2)
    return img


def place_phone(canvas: Image.Image, phone: Image.Image, xy: tuple[int, int]) -> None:
    canvas.alpha_composite(drop_shadow(phone, blur=28, offset=(0, 20), opacity=145), xy)


def formula_row(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    y: int,
    kind: str,
    label: str,
    detail: str,
) -> int:
    canvas.alpha_composite(icon_circle(kind, 52), (56, y))
    draw.text((128, y + 2), label, font=font(26, "demi"), fill=WHITE)
    draw.text((128, y + 36), detail, font=font(22, "regular"), fill=MUTED)
    return y + 88


# ---------- 3 calorie slides ----------


def slide_01() -> Image.Image:
    """How we calculate — BMR + movement + goal."""
    canvas = dark_canvas((150, 115, 40))
    draw = ImageDraw.Draw(canvas)
    canvas.alpha_composite(logo_lockup(38), (56, 48))
    draw_counter(draw, 1)

    y = draw_rich_title(
        draw,
        [("Calories aren't fixed.", ""), ("", "They're calculated.")],
        (56, 140),
        size=52,
        max_w=960,
        gap=6,
    )
    draw_body(
        draw,
        "WeekFit builds today's fuel from your body, then your day.",
        (56, y + 16),
        max_w=900,
        size=28,
    )

    y = 420
    y = formula_row(canvas, draw, y, "body", "Start with BMR", "Weight, height, age, sex — calories at rest")
    y = formula_row(canvas, draw, y, "activity", "Add today's movement", "Active energy from Apple Health")
    y = formula_row(canvas, draw, y, "goal", "Shape to your goal", "Cut, maintain, or gain — not one number forever")

    badge = apple_health_badge(0.95)
    canvas.alpha_composite(badge, (56, H - badge.height - 52))
    return canvas.convert("RGB")


def slide_02() -> Image.Image:
    """How you move raises the eat budget."""
    canvas = dark_canvas((35, 95, 75))
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 2)

    y = draw_rich_title(
        draw,
        [("How you move", ""), ("", "raises the budget.")],
        (56, 56),
        size=50,
        max_w=560,
        gap=6,
    )
    draw_body(
        draw,
        "More activity → more room to eat. Training days and easy days get different fuel.",
        (56, y + 14),
        max_w=500,
        size=26,
    )

    # Activity credit cards stacked left
    cards = [
        ("Rest day", "Base only", "1,420 kcal"),
        ("Active day", "+ activity credit", "1,780 kcal"),
        ("Hard session", "Budget grows", "2,050 kcal"),
    ]
    cy = 390
    for title, sub, value in cards:
        card = glass_card((460, 110), 22)
        d = ImageDraw.Draw(card)
        d.text((22, 18), title, font=font(20, "medium"), fill=MUTED)
        d.text((22, 48), value, font=font(34, "heavy"), fill=WHITE)
        d.text((22, 88), sub, font=font(18, "regular"), fill=GOLD_SOFT)
        canvas.alpha_composite(drop_shadow(card, blur=12, offset=(0, 8), opacity=100), (56, cy))
        cy += 128

    phone = framed_phone(IMG / "activity.jpg", phone_h=780)
    place_phone(canvas, phone, (W - phone.width - 4, H - phone.height - 48))
    return canvas.convert("RGB")


def slide_03() -> Image.Image:
    """How you eat spends the budget."""
    canvas = dark_canvas((110, 65, 28))
    draw = ImageDraw.Draw(canvas)
    draw_counter(draw, 3)

    y = draw_rich_title(
        draw,
        [("How you eat", ""), ("", "spends it.")],
        (56, 56),
        size=52,
        max_w=960,
        gap=6,
    )
    draw_body(
        draw,
        "Logged meals fill today's budget. Left means room left. Over means you went past it.",
        (56, y + 12),
        max_w=920,
        size=26,
    )

    # Budget strip
    strip = glass_card((968, 150), 26)
    ds = ImageDraw.Draw(strip)
    ds.text((28, 24), "Today's fuel", font=font(20, "medium"), fill=MUTED)
    ds.text((28, 58), "1,706  /  1,676 kcal", font=font(40, "heavy"), fill=WHITE)
    ds.text((28, 112), "Over  30 kcal  ·  shaped by how you moved", font=font(22, "regular"), fill=GOLD_SOFT)
    canvas.alpha_composite(drop_shadow(strip, blur=16, offset=(0, 10), opacity=120), (56, 340))

    phone = framed_phone(IMG / "nutrition.jpg", phone_h=680)
    place_phone(canvas, phone, ((W - phone.width) // 2 + 40, 520))

    # Bottom line
    draw.text(
        (56, H - 78),
        "Move more. Eat for the day you actually had.",
        font=font(24, "medium"),
        fill=GOLD,
    )
    return canvas.convert("RGB")


def write_caption(path: Path) -> None:
    path.write_text(
        """Calories aren't fixed. They're calculated.

WeekFit starts with your BMR — energy at rest from weight, height, age and sex.
Then today's movement from Apple Health raises the budget.
Meals spend that fuel. Left means room left. Over means you went past it.

Training days and easy days get different numbers — so nutrition matches how you actually moved.

#WeekFit #AppleHealth #calories #nutrition #trainingnutrition #TDEE
""",
        encoding="utf-8",
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    slides = [slide_01, slide_02, slide_03]
    for i, fn in enumerate(slides, start=1):
        img = fn()
        out = OUT / f"slide-{i:02d}.png"
        img.save(out, format="PNG", optimize=True)
        print(f"wrote {out.relative_to(ROOT)}")

    for stale in OUT.glob("slide-*.png"):
        n = stale.stem.split("-")[-1]
        if n.isdigit() and int(n) > TOTAL:
            stale.unlink()
            print(f"removed {stale.relative_to(ROOT)}")

    write_caption(OUT / "caption.txt")
    print(f"wrote {(OUT / 'caption.txt').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
