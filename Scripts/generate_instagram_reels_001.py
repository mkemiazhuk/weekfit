#!/usr/bin/env python3
"""Generate WeekFit Instagram Reels-001 launch film (≈18.5s, 9:16).

Lifestyle plates (AI) + real WeekFit UI composites + brand end card.
Assembled with ffmpeg: Ken Burns, type supers, crossfades, ambient bed.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "docs" / "img"
BRAND = ROOT / "web" / "public" / "brand"
DEVICE = ROOT / "web" / "public" / "mockify" / "devices" / "iPhone 16 Pro - Natural Titanium.png"
CURSOR_ASSETS = Path.home() / ".cursor" / "projects" / "Users-maxk-Dev-WeekFit" / "assets"
OUT = ROOT / "web" / "public" / "instagram" / "reels-001"
PLATES = OUT / "plates"
FRAMES = OUT / "frames"
WORK = OUT / "work"

W, H = 1080, 1920
FPS = 30
GOLD = (232, 184, 74)
WHITE = (250, 250, 252)
DARK = (8, 9, 12)
FONT = "/System/Library/Fonts/Avenir Next.ttc"
# Natural Titanium device screen quad (same family as Black Titanium mock)
FRAME_SCREEN = (41, 39, 718, 1514)


def font(size: int, weight: str = "bold") -> ImageFont.FreeTypeFont:
    index = {"heavy": 8, "bold": 0, "demi": 2, "medium": 5, "regular": 7}[weight]
    return ImageFont.truetype(FONT, size=size, index=index)


def cover(path: Path, size: tuple[int, int], focus: tuple[float, float] = (0.5, 0.45)) -> Image.Image:
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


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def framed_phone(screenshot: Path | None, phone_h: int = 1500, dark_screen: bool = False) -> Image.Image:
    frame = Image.open(DEVICE).convert("RGBA")
    scale = phone_h / frame.height
    frame = frame.resize((int(frame.width * scale), phone_h), Image.Resampling.LANCZOS)
    sl, st, sr, sb = [int(v * scale) for v in FRAME_SCREEN]
    sw, sh = sr - sl + 1, sb - st + 1

    if dark_screen or screenshot is None:
        shot = Image.new("RGBA", (sw, sh), (0, 0, 0, 255))
    else:
        raw = Image.open(screenshot).convert("RGB")
        s_scale = max(sw / raw.width, sh / raw.height)
        nw, nh = int(raw.width * s_scale), int(raw.height * s_scale)
        raw = raw.resize((nw, nh), Image.Resampling.LANCZOS)
        left = (nw - sw) // 2
        top = (nh - sh) // 2
        shot = raw.crop((left, top, left + sw, top + sh)).convert("RGBA")
    shot = rounded(shot, radius=max(28, int(44 * scale)))

    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    canvas.paste(shot, (sl, st), shot)
    canvas.alpha_composite(frame)
    return canvas


def drop_shadow(img: Image.Image, blur: int = 36, offset: tuple[int, int] = (0, 28), opacity: int = 160) -> Image.Image:
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


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    out = img.convert("RGBA")
    overlay = Image.new("RGBA", out.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for y in range(out.height):
        t = y / max(out.height - 1, 1)
        a = int(255 * strength * (0.08 + 0.55 * (t**1.6)))
        d.line([(0, y), (out.width, y)], fill=(0, 0, 0, a))
    for y in range(0, 220):
        a = int(90 * (1 - y / 220))
        d.line([(0, y), (out.width, y)], fill=(0, 0, 0, a))
    return Image.alpha_composite(out, overlay)


def draw_super(img: Image.Image, text: str, y: int | None = None, gold: bool = False) -> Image.Image:
    canvas = img.convert("RGBA")
    # Soft scrim behind type for readability
    scrim = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(scrim)
    ty = y if y is not None else int(H * 0.78)
    sd.rectangle((0, ty - 40, W, ty + 120), fill=(0, 0, 0, 90))
    canvas = Image.alpha_composite(canvas, scrim)
    draw = ImageDraw.Draw(canvas)
    f = font(54, "heavy")
    color = GOLD if gold else WHITE
    # shadow
    draw.text((66, ty + 2), text, font=f, fill=(0, 0, 0, 160))
    draw.text((64, ty), text, font=f, fill=color)
    return canvas


def ensure_plates() -> dict[str, Path]:
    PLATES.mkdir(parents=True, exist_ok=True)
    mapping = {
        "01": ("reels-001-scene-01-recognition.png", (0.5, 0.38)),
        "02": ("reels-001-scene-02-ritual.png", (0.5, 0.42)),
        "03": ("reels-001-scene-03-reach.png", (0.5, 0.48)),
    }
    out: dict[str, Path] = {}
    for key, (name, focus) in mapping.items():
        src = CURSOR_ASSETS / name
        if not src.exists():
            raise FileNotFoundError(f"Missing plate: {src}")
        dest = PLATES / f"scene-{key}.png"
        cover(src, (W, H), focus=focus).save(dest, "PNG")
        out[key] = dest
    return out


def build_static_frames(plates: dict[str, Path]) -> dict[str, Path]:
    FRAMES.mkdir(parents=True, exist_ok=True)
    frames: dict[str, Path] = {}

    # Scene 01
    f01 = vignette(cover(plates["01"], (W, H), (0.5, 0.36)))
    f01 = draw_super(f01, "You feel fine.", y=int(H * 0.80))
    p01 = FRAMES / "01_recognition.png"
    f01.convert("RGB").save(p01, "PNG")
    frames["01"] = p01

    # Scene 02
    f02 = vignette(cover(plates["02"], (W, H), (0.5, 0.42)), strength=0.62)
    f02 = draw_super(f02, "Everything says train.", y=int(H * 0.80))
    p02 = FRAMES / "02_ritual.png"
    f02.convert("RGB").save(p02, "PNG")
    frames["02"] = p02

    # Scene 03 — push toward phone in hands; darken any on-plate screen (no fake UI)
    base03 = vignette(cover(plates["03"], (W, H), (0.50, 0.55)), strength=0.45).convert("RGBA")
    # Soft black card where a phone screen would resolve — keeps AI UI out of the cut
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(veil)
    # Center-lower rounded rect approximates device face for the push-in beat
    margin_x, top, bottom = 210, int(H * 0.28), int(H * 0.92)
    vd.rounded_rectangle((margin_x, top, W - margin_x, bottom), radius=72, fill=(0, 0, 0, 210))
    base03 = Image.alpha_composite(base03, veil.filter(ImageFilter.GaussianBlur(1.2)))
    phone_dark = drop_shadow(framed_phone(None, phone_h=1320, dark_screen=True), blur=28, offset=(0, 18))
    px = (W - phone_dark.width) // 2
    py = int(H * 0.18)
    base03.alpha_composite(phone_dark, (px, py))
    f03 = draw_super(base03, "Something feels off.", y=int(H * 0.08))
    p03 = FRAMES / "03_reach.png"
    f03.convert("RGB").save(p03, "PNG")
    frames["03"] = p03

    # Scene 04 — real Recovery UI
    bg04 = Image.new("RGB", (W, H), DARK)
    # Warm residual glow
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(18, 0, -1):
        r = 280 + i * 28
        a = int(22 * (i / 18) ** 1.6)
        gd.ellipse((W // 2 - r, int(H * 0.55) - r, W // 2 + r, int(H * 0.55) + r), fill=(180, 120, 40, a))
    canvas04 = bg04.convert("RGBA")
    canvas04.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
    phone_rec = drop_shadow(framed_phone(IMG / "recovery.jpg", phone_h=1520))
    canvas04.alpha_composite(phone_rec, ((W - phone_rec.width) // 2, (H - phone_rec.height) // 2 - 20))
    f04 = draw_super(canvas04, "Your watch already knows.", y=int(H * 0.08), gold=False)
    p04 = FRAMES / "04_recovery.png"
    f04.convert("RGB").save(p04, "PNG")
    frames["04"] = p04

    # Scene 05 — real Coach UI
    canvas05 = Image.new("RGBA", (W, H), (*DARK, 255))
    phone_coach = drop_shadow(framed_phone(IMG / "coach.jpg", phone_h=1520))
    canvas05.alpha_composite(phone_coach, ((W - phone_coach.width) // 2, (H - phone_coach.height) // 2 - 20))
    f05 = draw_super(canvas05, "WeekFit explains it.", y=int(H * 0.08), gold=True)
    p05 = FRAMES / "05_decision.png"
    f05.convert("RGB").save(p05, "PNG")
    frames["05"] = p05

    # Scene 06 — end card
    end = Image.new("RGBA", (W, H), (*DARK, 255))
    mark = Image.open(BRAND / "logo-wf-mark.png").convert("RGBA")
    mark.thumbnail((168, 168), Image.Resampling.LANCZOS)
    end.alpha_composite(mark, ((W - mark.width) // 2, int(H * 0.34)))
    d = ImageDraw.Draw(end)
    word = font(42, "demi")
    label = "WEEKFIT"
    tw = d.textlength(label, font=word)
    d.text(((W - tw) / 2, int(H * 0.34) + mark.height + 36), label, font=word, fill=WHITE)
    sub = font(28, "medium")
    line = "One calm decision a day."
    lw = d.textlength(line, font=sub)
    d.text(((W - lw) / 2, int(H * 0.34) + mark.height + 100), line, font=sub, fill=GOLD)
    powered = font(22, "regular")
    ptxt = "Powered by Apple Health"
    pw = d.textlength(ptxt, font=powered)
    d.text(((W - pw) / 2, int(H * 0.78)), ptxt, font=powered, fill=(160, 164, 170))
    p06 = FRAMES / "06_endcard.png"
    end.convert("RGB").save(p06, "PNG")
    frames["06"] = p06

    return frames


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd[:8]), "..." if len(cmd) > 8 else "")
    subprocess.run(cmd, check=True)


def ken_burns_clip(image: Path, out: Path, duration: float, zoom_end: float = 1.08, fps: int = FPS) -> None:
    """Slow push-in from still."""
    frames = max(1, int(duration * fps))
    # zoompan: z grows from 1 to zoom_end
    z_expr = f"min(1+((on/{frames})*{zoom_end - 1}),{zoom_end})"
    x_expr = f"(iw-iw/zoom)/2"
    y_expr = f"(ih-ih/zoom)/2"
    vf = (
        f"scale={W * 2}:{H * 2}:force_original_aspect_ratio=increase,"
        f"crop={W * 2}:{H * 2},"
        f"zoompan=z='{z_expr}':x='{x_expr}':y='{y_expr}':d={frames}:s={W}x{H}:fps={fps},"
        f"format=yuv420p"
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-loop",
            "1",
            "-i",
            str(image),
            "-vf",
            vf,
            "-t",
            f"{duration:.3f}",
            "-r",
            str(fps),
            "-an",
            str(out),
        ]
    )


def still_clip(image: Path, out: Path, duration: float, fps: int = FPS) -> None:
    run(
        [
            "ffmpeg",
            "-y",
            "-loop",
            "1",
            "-i",
            str(image),
            "-vf",
            f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},format=yuv420p",
            "-t",
            f"{duration:.3f}",
            "-r",
            str(fps),
            "-an",
            str(out),
        ]
    )


def build_audio(out: Path, duration: float = 18.5) -> None:
    """Sparse ambient bed: low drone + soft wind-like noise + gentle chime at 7s."""
    # Generate procedural score with ffmpeg filters (no external music license needed)
    filt = (
        f"sine=f=110:d={duration},volume=0.04[a0];"
        f"sine=f=164.81:d={duration},volume=0.025[a1];"
        f"anoisesrc=color=pink:d={duration},highpass=f=400,lowpass=f=2800,volume=0.03[wind];"
        f"[a0][a1]amix=inputs=2:duration=longest,volume=0.9[pads];"
        f"[pads][wind]amix=inputs=2:duration=longest[bed];"
        # Soft confirmation at ~7.0s
        f"sine=f=880:d=0.18,afade=t=in:st=0:d=0.02,afade=t=out:st=0.08:d=0.1,volume=0.12,adelay=7000|7000[chime];"
        f"[bed][chime]amix=inputs=2:duration=first:dropout_transition=0,"
        f"afade=t=in:st=0:d=0.8,afade=t=out:st={duration - 1.2}:d=1.2"
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=r=48000:cl=stereo",
            "-filter_complex",
            filt,
            "-t",
            f"{duration:.3f}",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            str(out),
        ]
    )


def assemble(frames: dict[str, Path]) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    # Durations from storyboard
    clips = [
        ("01", frames["01"], 2.0, 1.06),
        ("02", frames["02"], 2.5, 1.07),
        ("03", frames["03"], 2.5, 1.10),
        ("04", frames["04"], 5.0, 1.04),
        ("05", frames["05"], 4.0, 1.03),
        ("06", frames["06"], 2.5, 1.02),
    ]
    paths: list[Path] = []
    for key, img, dur, zoom in clips:
        out = WORK / f"clip_{key}.mp4"
        ken_burns_clip(img, out, dur, zoom_end=zoom)
        paths.append(out)

    # Concat with short crossfades between 03→04 and 04→05; hard cut elsewhere via xfade chain
    # Simpler reliable path: concat demuxer (hard cuts) — Apple keynote punctuation
    list_file = WORK / "concat.txt"
    list_file.write_text("".join(f"file '{p.resolve()}'\n" for p in paths))
    video_only = WORK / "picture.mp4"
    run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_file),
            "-c:v",
            "libx264",
            "-preset",
            "slow",
            "-crf",
            "16",
            "-pix_fmt",
            "yuv420p",
            "-r",
            str(FPS),
            "-an",
            str(video_only),
        ]
    )

    # Soft dissolve 03→04 and 04→05 using xfade on pre-joined segments would be complex;
    # apply a gentle overall look + audio
    audio = WORK / "score.m4a"
    build_audio(audio, duration=18.5)

    final = OUT / "weekfit-reels-001.mp4"
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(video_only),
            "-i",
            str(audio),
            "-filter_complex",
            # Gentle grade: slight warmth, protect highlights
            "[0:v]eq=contrast=1.04:brightness=0.01:saturation=0.96,format=yuv420p[v]",
            "-map",
            "[v]",
            "-map",
            "1:a",
            "-c:v",
            "libx264",
            "-preset",
            "slow",
            "-crf",
            "15",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-movflags",
            "+faststart",
            str(final),
        ]
    )

    # Poster frame
    poster = OUT / "poster.jpg"
    run(
        [
            "ffmpeg",
            "-y",
            "-ss",
            "0.8",
            "-i",
            str(final),
            "-frames:v",
            "1",
            "-update",
            "1",
            "-q:v",
            "2",
            str(poster),
        ]
    )
    return final


def write_caption() -> None:
    (OUT / "caption.txt").write_text(
        """You feel fine.
Your watch already knows.

WeekFit AI turns Apple Health — sleep, HRV, resting heart rate, activity, recovery — into one calm decision.

Not another dashboard.
Confidence for when to push, and when to stop.

Link in bio.

#WeekFit #AppleHealth #AppleWatch #Recovery #HRV
""",
        encoding="utf-8",
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    print("→ Preparing plates")
    plates = ensure_plates()
    print("→ Building frames (real UI composites)")
    frames = build_static_frames(plates)
    for k, p in frames.items():
        print(f"   frame {k}: {p}")
    print("→ Assembling film")
    final = assemble(frames)
    write_caption()
    # Probe
    probe = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration,size",
            "-show_entries",
            "stream=codec_type,width,height,r_frame_rate",
            "-of",
            "default=noprint_wrappers=1",
            str(final),
        ],
        text=True,
    )
    print(probe)
    print(f"✓ Film ready: {final}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as e:
        print(f"ffmpeg failed: {e}", file=sys.stderr)
        raise SystemExit(1)
