#!/usr/bin/env python3
"""Remove solid backgrounds from opaque PNG assets in Assets.xcassets."""

from __future__ import annotations

import os
import re
import subprocess
import sys

ASSETS = os.path.join(os.path.dirname(__file__), "..", "WeekFit", "Resources", "Assets.xcassets")
SKIP_SUBSTRINGS = ("AppIcon", "weekfit-bg")


def parse_rgb(pixel: str) -> tuple[float, float, float] | None:
    match = re.search(r"(?:rgb|srgb)\(([^)]+)\)", pixel)
    if not match:
        return None

    parts = [float(value.strip().rstrip("%")) for value in match.group(1).split(",")]
    if len(parts) != 3:
        return None

    if any(part > 1.0 for part in parts):
        parts = [part / 255.0 for part in parts]

    return parts[0], parts[1], parts[2]


def luminance(rgb: tuple[float, float, float]) -> float:
    red, green, blue = rgb
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def has_alpha(path: str) -> bool:
    alpha = subprocess.check_output(["magick", "identify", "-format", "%A", path], text=True).strip()
    return alpha == "Blend"


def corner_pixel(path: str) -> str:
    return subprocess.check_output(["magick", path, "-format", "%[pixel:p{0,0}]", "info:"], text=True).strip()


def remove_background(path: str) -> str:
    if any(skip in path for skip in SKIP_SUBSTRINGS):
        return "skip"

    if has_alpha(path):
        return "already"

    pixel = corner_pixel(path)
    rgb = parse_rgb(pixel)
    if rgb is None:
        return f"fail-parse:{pixel}"

    lum = luminance(rgb)
    tmp = f"{path}.tmp.png"

    if lum < 0.08:
        command = ["magick", path, "-fuzz", "10%", "-transparent", "black", tmp]
    elif lum > 0.90:
        command = ["magick", path, "-fuzz", "8%", "-transparent", "white", tmp]
    else:
        color = f"rgb({int(rgb[0] * 255)},{int(rgb[1] * 255)},{int(rgb[2] * 255)})"
        command = ["magick", path, "-fuzz", "14%", "-transparent", color, tmp]

    subprocess.check_call(command)
    os.replace(tmp, path)
    return f"fixed:{pixel}"


def main() -> int:
    assets_root = os.path.abspath(ASSETS)
    changed = 0

    for root, _, files in os.walk(assets_root):
        if any(skip in root for skip in SKIP_SUBSTRINGS):
            continue

        for filename in files:
            if not filename.endswith(".png"):
                continue

            path = os.path.join(root, filename)
            if has_alpha(path):
                continue

            status = remove_background(path)
            rel = path.replace(f"{assets_root}/", "")
            print(f"{status}\t{rel}")
            changed += 1

    print(f"Processed {changed} opaque asset(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
