#!/usr/bin/env python3
"""Export hero-watch-ultra.png from the clean 176611c cutout.

Removes only side matte/fringe pixels next to the top strap tail.
The bottom strap band and everything below stay exactly as in 176611c.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = Path("/tmp/hero-watch-176611c.png")
OUT = ROOT / "public/img/hero-watch-ultra.png"

STRAP_TOP_END = 0.24
STRAP_BOTTOM_START = 0.76
LUG_ROW_SPAN = 280
FRINGE_MARGIN = 2


def load_base_rgba() -> tuple[np.ndarray, np.ndarray]:
    if not BASE.exists():
        with BASE.open("wb") as handle:
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(ROOT.parent),
                    "show",
                    "176611c:web/public/img/hero-watch-ultra.png",
                ],
                check=True,
                stdout=handle,
            )
    px = np.array(Image.open(BASE).convert("RGBA"))
    return px[:, :, :3].astype(np.float32), px[:, :, 3].copy()


def remove_top_strap_side_fringe(
    rgb: np.ndarray, alpha: np.ndarray
) -> tuple[np.ndarray, np.ndarray]:
    """Drop opaque pixels outside the per-row fabric span in the top strap tail."""
    h, w = alpha.shape
    top_end = int(h * STRAP_TOP_END)
    out_a = alpha.copy()
    out_r = rgb.copy()

    for y in range(top_end):
        xs = np.where(alpha[y] > 0)[0]
        if xs.size == 0:
            continue
        span = xs[-1] - xs[0] + 1
        if span > LUG_ROW_SPAN:
            continue

        lo = max(0, xs[0] + FRINGE_MARGIN)
        hi = min(w, xs[-1] - FRINGE_MARGIN + 1)
        if lo >= hi:
            continue

        fringe = np.zeros(w, dtype=bool)
        fringe[:lo] = alpha[y, :lo] > 0
        fringe[hi:] = alpha[y, hi:] > 0
        if not fringe.any():
            continue

        out_a[y, fringe] = 0
        out_r[y, fringe] = 0

    return out_r, out_a


def main() -> None:
    rgb, alpha = load_base_rgba()
    bot_start = int(alpha.shape[0] * STRAP_BOTTOM_START)
    frozen_bottom_a = alpha[bot_start:].copy()
    frozen_bottom_r = rgb[bot_start:].copy()

    rgb, alpha = remove_top_strap_side_fringe(rgb, alpha)

    alpha[bot_start:] = frozen_bottom_a
    rgb[bot_start:] = frozen_bottom_r

    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(f"saved {OUT} size={rgba.shape[1::-1]}")


if __name__ == "__main__":
    main()
