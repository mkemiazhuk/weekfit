#!/usr/bin/env python3
"""Export layered hero watch assets from the natural 176611c cutout.

The hero uses two PNG layers instead of trying to seal weave holes in one file:

1. hero-watch-ultra-straps.png — strap fabric with a solid alpha envelope
2. hero-watch-ultra-body.png     — titanium case, lugs, and screen on top

Strap holes keep their original thread colours; only alpha becomes opaque inside
the fabric envelope so the phone UI cannot bleed through the weave.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
BASE = Path("/tmp/hero-watch-176611c.png")
OUT_STRAPS = ROOT / "public/img/hero-watch-ultra-straps.png"
OUT_BODY = ROOT / "public/img/hero-watch-ultra-body.png"
OUT_LEGACY = ROOT / "public/img/hero-watch-ultra.png"

STRAP_TOP_END = 0.24
CASE_BOTTOM_START = 0.76
STRAP_TAIL_START = 0.87
FABRIC_ROW_MAX = 260
LUG_SIDE_LEFT = 100
LUG_SIDE_RIGHT = 330
GAP_FILL_ROWS = (0.83, 0.87)  # block the case-to-strap air gap over the phone UI


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


def build_fabric_mask(alpha: np.ndarray) -> np.ndarray:
    h, w = alpha.shape
    top_end = int(h * STRAP_TOP_END)
    case_bottom = int(h * CASE_BOTTOM_START)
    strap_tail = int(h * STRAP_TAIL_START)
    gap_y0 = int(h * GAP_FILL_ROWS[0])
    gap_y1 = int(h * GAP_FILL_ROWS[1])

    fabric = np.zeros_like(alpha, dtype=bool)

    for y in range(h):
        xs = np.where(alpha[y] > 0)[0]
        if xs.size == 0:
            continue

        if y < top_end:
            span = int(xs[-1] - xs[0] + 1)
            if span <= FABRIC_ROW_MAX:
                fabric[y, xs[0] : xs[-1] + 1] = True
            continue

        if y >= strap_tail:
            fabric[y, xs[0] : xs[-1] + 1] = True
            continue

        if y >= case_bottom:
            for part in (xs[xs < LUG_SIDE_LEFT], xs[xs > LUG_SIDE_RIGHT]):
                if part.size >= 8:
                    fabric[y, part[0] : part[-1] + 1] = True

    # Hero-only bridge across the real air gap so the phone UI does not show through.
    for y in range(gap_y0, gap_y1 + 1):
        xs = np.where(alpha[y] > 0)[0]
        if xs.size == 0:
            continue
        fabric[y, xs[0] : xs[-1] + 1] = True

    return fabric


def fill_fabric_holes(rgb: np.ndarray, alpha: np.ndarray, fabric: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    source = (alpha > 0) & fabric
    holes = fabric & (alpha == 0)
    if not holes.any() or not source.any():
        return out

    _, (iy, ix) = ndimage.distance_transform_edt(~source, return_indices=True)
    hy, hx = np.where(holes)
    out[hy, hx] = rgb[iy[hy, hx], ix[hy, hx]]
    return out


def save_rgba(rgb: np.ndarray, alpha: np.ndarray, path: Path) -> None:
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(path, optimize=False)


def main() -> None:
    rgb, alpha = load_base_rgba()
    fabric = build_fabric_mask(alpha)

    strap_rgb = fill_fabric_holes(rgb, alpha, fabric)
    strap_alpha = np.where(fabric, 255, 0).astype(np.uint8)

    body_mask = (alpha > 0) & ~fabric
    body_alpha = np.where(body_mask, alpha, 0).astype(np.uint8)
    body_rgb = rgb.copy()
    body_rgb[body_alpha == 0] = 0

    save_rgba(strap_rgb, strap_alpha, OUT_STRAPS)
    save_rgba(body_rgb, body_alpha, OUT_BODY)

    flat_alpha = np.maximum(strap_alpha, body_alpha)
    flat_rgb = np.where(strap_alpha[:, :, None] > 0, strap_rgb, body_rgb)
    save_rgba(flat_rgb, flat_alpha, OUT_LEGACY)

    print(
        "saved",
        OUT_STRAPS.name,
        OUT_BODY.name,
        OUT_LEGACY.name,
        f"fabric_px={int(fabric.sum())}",
    )


if __name__ == "__main__":
    main()
