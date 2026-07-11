#!/usr/bin/env python3
"""Export hero-watch-ultra.png from the clean 176611c cutout.

Optional minimal pass: seal interior weave holes only (see seal_weave_holes).
Default export restores the natural 176611c asset unchanged.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
BASE = Path("/tmp/hero-watch-176611c.png")
OUT = ROOT / "public/img/hero-watch-ultra.png"

STRAP_TOP_END = 0.24
STRAP_BOTTOM_START = 0.76
INNER_XA = 79
INNER_XB = 333
DARK_THRESHOLD = 44
WEAVE_PASSES = 3
SEAL_WEAVE = False


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


def seal_weave_holes(rgb: np.ndarray, alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Fill only enclosed dark holes inside the strap fabric envelope."""
    h, w = alpha.shape
    out_a = alpha.copy()
    out_r = rgb.copy()

    for y0, y1 in ((0, int(h * STRAP_TOP_END)), (int(h * STRAP_BOTTOM_START), h)):
        col_band = np.zeros((h, w), dtype=bool)
        col_band[y0:y1, INNER_XA : INNER_XB + 1] = True

        for _ in range(WEAVE_PASSES):
            fabric = (out_a > 0) & col_band
            if not fabric.any():
                break
            near = ndimage.binary_dilation(fabric, iterations=1)
            holes = (out_a == 0) & col_band & (out_r.max(axis=2) < DARK_THRESHOLD) & near
            if not holes.any():
                break
            _, (iy, ix) = ndimage.distance_transform_edt(~fabric, return_indices=True)
            hy, hx = np.where(holes)
            out_r[hy, hx] = out_r[iy[hy, hx], ix[hy, hx]]
            out_a[holes] = 255

    return out_r, out_a


def main() -> None:
    rgb, alpha = load_base_rgba()
    if SEAL_WEAVE:
        rgb, alpha = seal_weave_holes(rgb, alpha)

    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(f"saved {OUT} size={rgba.shape[1::-1]} seal={SEAL_WEAVE}")


if __name__ == "__main__":
    main()
