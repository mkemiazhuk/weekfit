#!/usr/bin/env python3
"""Export hero-watch-ultra.png — natural 176611c look, opaque weave holes only."""

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
DARK_THRESHOLD = 44
WEAVE_PASSES = 10


def load_base_rgba() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
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
    rgb = px[:, :, :3].astype(np.float32)
    alpha = px[:, :, 3].copy()
    return rgb, alpha, alpha.copy()


def strap_columns(alpha: np.ndarray, y0: int, y1: int) -> tuple[int, int] | None:
    cols = np.where((alpha[y0:y1] > 0).any(axis=0))[0]
    if cols.size == 0:
        return None
    return int(cols[0]), int(cols[-1])


def seal_weave_holes(
    rgb: np.ndarray,
    alpha: np.ndarray,
    original_alpha: np.ndarray,
    y0: int,
    y1: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Fill transparent weave holes without changing existing opaque pixels."""
    h, w = alpha.shape
    out_a = alpha.copy()
    out_r = rgb.copy()

    bounds = strap_columns(original_alpha, y0, y1)
    if bounds is None:
        return out_r, out_a

    xa, xb = bounds
    col_band = np.zeros((h, w), dtype=bool)
    col_band[y0:y1, xa : xb + 1] = True

    gap_rows = np.zeros(y1 - y0, dtype=bool)
    for i, y in enumerate(range(y0, y1)):
        if original_alpha[y, xa : xb + 1].sum() == 0:
            gap_rows[i] = True

    for _ in range(WEAVE_PASSES):
        fabric = (out_a > 0) & col_band
        if not fabric.any():
            break

        near = ndimage.binary_dilation(fabric, iterations=2)
        dark = out_r.max(axis=2) < DARK_THRESHOLD
        holes = (out_a == 0) & col_band & dark & near

        for i, y in enumerate(range(y0, y1)):
            if gap_rows[i]:
                holes[y, xa : xb + 1] = False

        if not holes.any():
            break

        _, (iy, ix) = ndimage.distance_transform_edt(~fabric, return_indices=True)
        hy, hx = np.where(holes)
        out_r[hy, hx] = out_r[iy[hy, hx], ix[hy, hx]]
        out_a[holes] = 255

    for i, y in enumerate(range(y0, y1)):
        if gap_rows[i]:
            out_a[y, xa : xb + 1] = original_alpha[y, xa : xb + 1]
            out_r[y, xa : xb + 1] = rgb[y, xa : xb + 1]

    return out_r, out_a


def main() -> None:
    rgb, alpha, original_alpha = load_base_rgba()
    h = alpha.shape[0]
    top_end = int(h * STRAP_TOP_END)
    bottom_start = int(h * STRAP_BOTTOM_START)

    rgb, alpha = seal_weave_holes(rgb, alpha, original_alpha, 0, top_end)
    rgb, alpha = seal_weave_holes(rgb, alpha, original_alpha, bottom_start, h)

    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(f"saved {OUT} size={rgba.shape[1::-1]}")


if __name__ == "__main__":
    main()
