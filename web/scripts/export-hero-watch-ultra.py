#!/usr/bin/env python3
"""Export hero-watch-ultra.png from the official product photo.

Keeps the natural photo cutout (176611c): perimeter background removal only.
No strap repainting, gap fills, or layered exports.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    "/Users/maxk/.cursor/projects/Users-maxk-Dev-WeekFit/assets/"
    "image-62f44bd2-0c12-429f-b56d-f3ac7f705cbb.png"
)
EDITED = Path("/tmp/hero-watch-edited.png")
OUT = ROOT / "public/img/hero-watch-ultra.png"

CROP_OFFSET = (166, 93)
CROP_SIZE = (434, 716)
FLOOD_THRESHOLD = 40


def build_edited_source() -> None:
    subprocess.run(
        [
            "magick",
            str(SOURCE),
            "-fuzz",
            "18%",
            "-fill",
            "black",
            "-opaque",
            "#384028",
            "-fuzz",
            "25%",
            "-fill",
            "white",
            "-opaque",
            "#9eff00",
            "-fill",
            "black",
            "-draw",
            "rectangle 422,282 534,312",
            "-font",
            "Helvetica-Bold",
            "-pointsize",
            "34",
            "-fill",
            "white",
            "-gravity",
            "NorthEast",
            "-annotate",
            "+212+311",
            "07:00",
            str(EDITED),
        ],
        check=True,
    )


def key_background(img: Image.Image) -> Image.Image:
    keyed = img.convert("RGBA")
    width, height = keyed.size
    seeds: list[tuple[int, int]] = []
    for x in range(0, width, 12):
        seeds.extend([(x, 0), (x, height - 1)])
    for y in range(0, height, 12):
        seeds.extend([(0, y), (width - 1, y)])

    draw = ImageDraw.Draw(keyed)
    for seed in seeds:
        r, g, b, a = keyed.getpixel(seed)
        if a == 0 or max(r, g, b) > FLOOD_THRESHOLD:
            continue
        ImageDraw.floodfill(keyed, seed, (0, 0, 0, 0), thresh=FLOOD_THRESHOLD)

    return keyed


def main() -> None:
    build_edited_source()
    keyed = key_background(Image.open(EDITED))
    ox, oy = CROP_OFFSET
    w, h = CROP_SIZE
    cropped = keyed.crop((ox, oy, ox + w, oy + h))

    rgba = np.array(cropped)
    rgba[rgba[:, :, 3] == 0] = 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(f"saved {OUT} size={cropped.size}")


if __name__ == "__main__":
    main()
