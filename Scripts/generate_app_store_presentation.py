#!/usr/bin/env python3
"""Generate WeekFit App Store presentation-001.

Masters: 1080×1350 editorial frames (design system V1.0).
ASC:    1290×2796 vertical reflow + sips derivatives for 6.7 / 6.5 / 6.1.

Usage:
  .venv-scripts/bin/python Scripts/generate_app_store_presentation.py
  .venv-scripts/bin/python Scripts/generate_app_store_presentation.py --format asc
  .venv-scripts/bin/python Scripts/generate_app_store_presentation.py --format all
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "docs" / "img"
BRAND = ROOT / "web" / "public" / "brand"
DEVICE = ROOT / "web" / "public" / "mockify" / "devices" / "iPhone 16 Pro - Black Titanium.png"
OUT_MASTER = ROOT / "web" / "public" / "app-store" / "presentation-001"
OUT_ASC = ROOT / "build" / "app-store-screenshots" / "presentation-001"

# Design system tokens
BG = (5, 5, 5)
WHITE = (255, 255, 255)
SECONDARY = (142, 142, 147)
GOLD = (216, 177, 90)
DIVIDER = (255, 255, 255, 20)

FONT = "/System/Library/Fonts/Avenir Next.ttc"
# Two weights only: Semibold (demi) + Regular
WEIGHT_SEMIBOLD = 2
WEIGHT_REGULAR = 7

# Device frame screen inset (device asset coords)
FRAME_SCREEN = (41, 39, 718, 1514)

TOTAL = 6


@dataclass(frozen=True)
class Slide:
    index: int
    emotion: str
    headline: str
    subtitle: str
    still: str
    show_logo: bool
    show_health_line: bool = False


SLIDES: list[Slide] = [
    Slide(
        1,
        "Confusion",
        "Too much data.\nToo little clarity.",
        "WeekFit turns Apple Health into one clear recommendation.",
        "today.jpg",
        show_logo=True,
    ),
    Slide(
        2,
        "Understanding",
        "Your day,\ninterpreted.",
        "Sleep, recovery, and load — read as one story.",
        "recovery.jpg",
        show_logo=False,
    ),
    Slide(
        3,
        "Confidence",
        "Know what\nto do next.",
        "One intelligent recommendation. Not another dashboard.",
        "coach.jpg",
        show_logo=False,
    ),
    Slide(
        4,
        "Control",
        "Plan and nutrition,\naligned.",
        "Meals and training that follow the same intent.",
        "plan.jpg",
        show_logo=False,
    ),
    Slide(
        5,
        "Trust",
        "Powered by\nApple Health.",
        "Recovery, sleep, HRV, activity, and nutrition — as one signal.",
        "activity.jpg",
        show_logo=False,
        show_health_line=True,
    ),
    Slide(
        6,
        "Habit",
        "Confidence,\nevery morning.",
        "Open WeekFit. Know your day.",
        "coach.jpg",
        show_logo=True,
    ),
]


def font(size: int, weight: int = WEIGHT_REGULAR) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, size=size, index=weight)


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


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def framed_phone(screenshot: Path, phone_h: int) -> Image.Image:
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


def soft_phone_shadow(phone: Image.Image) -> Image.Image:
    """Quiet contact shadow — no glow, no colored bloom."""
    blur = 22
    offset = (0, 14)
    opacity = 110
    shadow = Image.new(
        "RGBA",
        (phone.width + abs(offset[0]) + blur * 2, phone.height + abs(offset[1]) + blur * 2),
        (0, 0, 0, 0),
    )
    mask = phone.split()[-1]
    sh = Image.new("RGBA", phone.size, (0, 0, 0, opacity))
    sh.putalpha(mask)
    ox = blur + max(offset[0], 0)
    oy = blur + max(offset[1], 0)
    shadow.paste(sh, (ox + offset[0], oy + offset[1]), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(phone, (blur - min(offset[0], 0), blur - min(offset[1], 0)))
    return out


def gold_logo(height: int) -> Image.Image:
    mark = Image.open(BRAND / "logo-gold.png").convert("RGBA")
    # Trim transparent padding
    bbox = mark.getbbox()
    if bbox:
        mark = mark.crop(bbox)
    mark.thumbnail((height * 4, height), Image.Resampling.LANCZOS)
    # Constrain height precisely
    scale = height / mark.height
    mark = mark.resize((max(1, int(mark.width * scale)), height), Image.Resampling.LANCZOS)
    return mark


def draw_headline(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    size: int,
    max_w: int,
    gap: int,
) -> int:
    fnt = font(size, WEIGHT_SEMIBOLD)
    x, y = xy
    for raw in text.split("\n"):
        for line in wrap(draw, raw, fnt, max_w) if raw else [""]:
            draw.text((x, y), line, font=fnt, fill=WHITE)
            y += size + gap
    return y


def draw_subtitle(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    size: int,
    max_w: int,
    gap: int,
) -> int:
    fnt = font(size, WEIGHT_REGULAR)
    x, y = xy
    for line in wrap(draw, text, fnt, max_w):
        draw.text((x, y), line, font=fnt, fill=SECONDARY)
        y += size + gap
    return y


def draw_health_line(draw: ImageDraw.ImageDraw, xy: tuple[int, int], size: int) -> None:
    fnt = font(size, WEIGHT_REGULAR)
    draw.text(xy, "Works with Apple Health", font=fnt, fill=SECONDARY)


def compose_master(slide: Slide) -> Image.Image:
    """1080×1350 — text upper band, phone lower band."""
    w, h = 1080, 1350
    margin = 64
    canvas = Image.new("RGBA", (w, h), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    text_top = margin
    if slide.show_logo:
        logo = gold_logo(44)
        canvas.alpha_composite(logo, (margin, margin))
        text_top = margin + logo.height + 36
    else:
        text_top = margin + 12

    headline_size = 58
    subtitle_size = 26
    text_max_w = w - margin * 2

    y = draw_headline(draw, slide.headline, (margin, text_top), headline_size, text_max_w, gap=6)
    y += 22

    # Quiet divider
    draw.line([(margin, y), (margin + 48, y)], fill=DIVIDER, width=2)
    y += 28

    y = draw_subtitle(draw, slide.subtitle, (margin, y), subtitle_size, text_max_w, gap=8)

    if slide.show_health_line:
        y += 20
        draw_health_line(draw, (margin, y), 20)

    # Phone: ~42% of canvas height, centered horizontally, bottom-weighted
    phone_h = int(h * 0.42)
    phone = framed_phone(IMG / slide.still, phone_h=phone_h)
    shadowed = soft_phone_shadow(phone)

    # Keep phone clear of text; sit in lower zone with margin
    phone_x = (w - shadowed.width) // 2
    phone_y = h - shadowed.height - margin + 8
    # Ensure no overlap with text block
    min_phone_y = y + 48
    if phone_y < min_phone_y:
        # Shrink phone to fit remaining space
        available = h - margin - min_phone_y - 40
        if available > 200:
            phone_h = int(available * 0.92)
            phone = framed_phone(IMG / slide.still, phone_h=phone_h)
            shadowed = soft_phone_shadow(phone)
            phone_x = (w - shadowed.width) // 2
            phone_y = h - shadowed.height - margin + 8

    canvas.alpha_composite(shadowed, (phone_x, phone_y))
    return canvas.convert("RGB")


def compose_asc(slide: Slide) -> Image.Image:
    """1290×2796 — tall App Store Connect 6.7\" frame."""
    w, h = 1290, 2796
    margin = 72
    canvas = Image.new("RGBA", (w, h), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    text_top = margin + 24
    if slide.show_logo:
        logo = gold_logo(52)
        canvas.alpha_composite(logo, (margin, margin + 8))
        text_top = margin + logo.height + 48

    headline_size = 64
    subtitle_size = 28
    text_max_w = w - margin * 2

    y = draw_headline(draw, slide.headline, (margin, text_top), headline_size, text_max_w, gap=8)
    y += 28
    draw.line([(margin, y), (margin + 56, y)], fill=DIVIDER, width=2)
    y += 32
    y = draw_subtitle(draw, slide.subtitle, (margin, y), subtitle_size, text_max_w, gap=10)

    if slide.show_health_line:
        y += 24
        draw_health_line(draw, (margin, y), 22)

    # Phone ~45% of canvas height
    phone_h = int(h * 0.45)
    phone = framed_phone(IMG / slide.still, phone_h=phone_h)
    shadowed = soft_phone_shadow(phone)

    phone_x = (w - shadowed.width) // 2
    phone_y = h - shadowed.height - margin
    min_phone_y = y + 64
    if phone_y < min_phone_y:
        available = h - margin - min_phone_y - 48
        if available > 400:
            phone_h = int(available * 0.95)
            phone = framed_phone(IMG / slide.still, phone_h=phone_h)
            shadowed = soft_phone_shadow(phone)
            phone_x = (w - shadowed.width) // 2
            phone_y = h - shadowed.height - margin

    canvas.alpha_composite(shadowed, (phone_x, phone_y))
    return canvas.convert("RGB")


def write_master_readme(out: Path) -> None:
    lines = [
        "# WeekFit App Store Presentation 001",
        "",
        "Master frames **1080 × 1350** (design system V1.0).",
        "",
        "See [docs/AppStoreDesignSystem.md](../../../../docs/AppStoreDesignSystem.md).",
        "",
        "| # | File | Headline |",
        "|---|------|----------|",
    ]
    for s in SLIDES:
        headline = s.headline.replace("\n", " ")
        lines.append(f"| {s.index} | `{s.index:02d}.png` | {headline} |")
    lines += [
        "",
        "## Generate",
        "",
        "```bash",
        ".venv-scripts/bin/python Scripts/generate_app_store_presentation.py --format all",
        "```",
        "",
    ]
    (out / "README.md").write_text("\n".join(lines), encoding="utf-8")


def write_asc_upload_md(out: Path) -> None:
    lines = [
        "# WeekFit — App Store Screenshots (presentation-001)",
        "",
        "Framed marketing screenshots. Upload **01–06** in order.",
        "",
        "| # | File | Caption (EN) |",
        "|---|------|--------------|",
    ]
    for s in SLIDES:
        caption = s.headline.replace("\n", " ")
        lines.append(f"| {s.index} | `{s.index:02d}.png` | {caption} |")
    lines += [
        "",
        "## Folders",
        "",
        "- `6.7-inch/` — iPhone 6.7\" display (**1290×2796**)",
        "- `6.5-inch/` — iPhone 6.5\" display (**1284×2778**)",
        "- `6.1-inch/` — iPhone 6.1\" display (**1170×2532**)",
        "",
        "## App Store Connect",
        "",
        "1. **App Store → Screenshots**",
        "2. Upload `6.7-inch/` for **6.7\" Display**",
        "3. Upload `6.5-inch/` for **6.5\" Display**",
        "4. Upload `6.1-inch/` for **6.1\" Display**",
        "5. Same order on all sizes",
        "",
        "Story: Confusion → Understanding → Confidence → Control → Trust → Habit",
        "",
        "Source of truth: `docs/AppStoreDesignSystem.md`",
        "",
    ]
    (out / "UPLOAD.md").write_text("\n".join(lines), encoding="utf-8")


def sips_resize(src: Path, dst: Path, height: int, width: int) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-z", str(height), str(width), str(src), "--out", str(dst)],
        check=True,
        capture_output=True,
    )


def generate_masters() -> None:
    OUT_MASTER.mkdir(parents=True, exist_ok=True)
    for slide in SLIDES:
        path = OUT_MASTER / f"{slide.index:02d}.png"
        compose_master(slide).save(path, "PNG", optimize=True)
        print(f"  ✓ master {path.relative_to(ROOT)}")
    write_master_readme(OUT_MASTER)


def generate_asc() -> None:
    out_67 = OUT_ASC / "6.7-inch"
    out_65 = OUT_ASC / "6.5-inch"
    out_61 = OUT_ASC / "6.1-inch"
    out_src = OUT_ASC / "source"
    for d in (out_67, out_65, out_61, out_src):
        d.mkdir(parents=True, exist_ok=True)

    for slide in SLIDES:
        name = f"{slide.index:02d}.png"
        src = out_src / name
        compose_asc(slide).save(src, "PNG", optimize=True)
        # 6.7" is native composition size
        (out_67 / name).write_bytes(src.read_bytes())
        sips_resize(src, out_65 / name, 2778, 1284)
        sips_resize(src, out_61 / name, 2532, 1170)
        print(f"  ✓ asc {name} (6.7 / 6.5 / 6.1)")

    write_asc_upload_md(OUT_ASC)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate WeekFit App Store presentation frames")
    parser.add_argument(
        "--format",
        choices=("master", "asc", "all"),
        default="all",
        help="master=1080×1350, asc=ASC sizes, all=both (default)",
    )
    args = parser.parse_args()

    missing = [s.still for s in SLIDES if not (IMG / s.still).exists()]
    if missing:
        print(f"Missing UI stills: {missing}", file=sys.stderr)
        return 1
    if not DEVICE.exists():
        print(f"Missing device frame: {DEVICE}", file=sys.stderr)
        return 1

    if args.format in ("master", "all"):
        print("→ Masters 1080×1350")
        generate_masters()
    if args.format in ("asc", "all"):
        print("→ App Store Connect sizes")
        generate_asc()

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
