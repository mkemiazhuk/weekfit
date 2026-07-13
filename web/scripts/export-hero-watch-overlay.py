#!/usr/bin/env python3
"""Build hero-only watch overlay from the natural production cutout.

Reads web/public/img/hero-watch-ultra.png (unchanged natural photo mask) and
writes web/public/img/hero-watch-ultra-overlay.png where only the internal
alpha of woven strap fabric is forced opaque. RGB is never modified.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "public/img/hero-watch-ultra.png"
OUT = ROOT / "public/img/hero-watch-ultra-overlay.png"

STRAP_TOP_END = 0.24
CASE_BOTTOM_START = 0.76
TOP_STRAP_MAX_SPAN = 260
MIN_FABRIC_RUN = 8

# Narrow vertical gaps at case↔strap lugs (fractions of overlay size 434×716).
LUG_GAP_ZONES: tuple[tuple[float, float, float, float], ...] = (
    (0.132, 0.168, 0.155, 0.245),  # top-left lug
    (0.132, 0.168, 0.685, 0.775),  # top-right lug
    (0.845, 0.872, 0.155, 0.245),  # bottom-left lug
    (0.845, 0.872, 0.685, 0.775),  # bottom-right lug
)


def opaque_runs(xs: np.ndarray) -> list[tuple[int, int]]:
    if xs.size == 0:
        return []
    runs: list[tuple[int, int]] = []
    start = int(xs[0])
    prev = int(xs[0])
    for x in xs[1:]:
        x = int(x)
        if x == prev + 1:
            prev = x
        else:
            runs.append((start, prev))
            start = prev = x
    runs.append((start, prev))
    return runs


def build_fabric_envelope(alpha: np.ndarray) -> np.ndarray:
    """Per-row fabric spans in strap bands only (excludes case and air gap)."""
    h, w = alpha.shape
    top_end = int(h * STRAP_TOP_END)
    case_bottom = int(h * CASE_BOTTOM_START)
    envelope = np.zeros((h, w), dtype=bool)

    for y in range(h):
        if top_end <= y < case_bottom:
            continue

        xs = np.where(alpha[y] > 0)[0]
        if xs.size == 0:
            continue

        span = int(xs[-1] - xs[0] + 1)
        if span <= TOP_STRAP_MAX_SPAN:
            envelope[y, xs[0] : xs[-1] + 1] = True
            continue

        for run_start, run_end in opaque_runs(xs):
            if run_end - run_start + 1 >= MIN_FABRIC_RUN:
                envelope[y, run_start : run_end + 1] = True

    return envelope


def seal_lug_gaps(rgb: np.ndarray, alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Opaque black only in narrow case↔strap lug gaps (not full strap width)."""
    h, w = alpha.shape
    out_rgb = rgb.copy()
    out_alpha = alpha.copy()
    sealed = 0

    for y0f, y1f, x0f, x1f in LUG_GAP_ZONES:
        y0, y1 = int(h * y0f), max(int(h * y1f), int(h * y0f) + 1)
        x0, x1 = int(w * x0f), max(int(w * x1f), int(w * x0f) + 1)
        zone_alpha = out_alpha[y0:y1, x0:x1]
        gap = zone_alpha == 0
        sealed += int(gap.sum())
        zone_alpha[gap] = 255
        out_alpha[y0:y1, x0:x1] = zone_alpha
        zone_rgb = out_rgb[y0:y1, x0:x1]
        zone_rgb[gap] = 0
        out_rgb[y0:y1, x0:x1] = zone_rgb

    return out_rgb, out_alpha, sealed


def main() -> None:
    px = np.array(Image.open(SOURCE).convert("RGBA"))
    rgb = px[:, :, :3].copy()
    alpha = px[:, :, 3].copy()

    envelope = build_fabric_envelope(alpha)
    holes = envelope & (alpha == 0)
    sheer = envelope & (alpha > 0) & (alpha < 255)

    out_alpha = alpha.copy()
    out_alpha[holes] = 255
    out_alpha[sheer] = 255

    out_rgb, out_alpha, lug_sealed = seal_lug_gaps(rgb, out_alpha)

    rgba = np.dstack([out_rgb, out_alpha]).astype(np.uint8)
    rgba[out_alpha == 0] = 0

    changed_alpha = (out_alpha != alpha).sum()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(
        f"saved {OUT.name} holes_sealed={int(holes.sum())} "
        f"sheer_sealed={int(sheer.sum())} lug_sealed={lug_sealed} "
        f"alpha_changed={int(changed_alpha)}"
    )


if __name__ == "__main__":
    main()
