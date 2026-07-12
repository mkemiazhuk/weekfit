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
STRAP_TAIL_START = 0.87
TOP_STRAP_MAX_SPAN = 260
LUG_SIDE_LEFT = 100
LUG_SIDE_RIGHT = 330


def build_fabric_envelope(alpha: np.ndarray) -> np.ndarray:
    """Per-row fabric spans in strap bands only (excludes case and air gap)."""
    h, w = alpha.shape
    top_end = int(h * STRAP_TOP_END)
    case_bottom = int(h * CASE_BOTTOM_START)
    strap_tail = int(h * STRAP_TAIL_START)
    envelope = np.zeros((h, w), dtype=bool)

    for y in range(h):
        if top_end <= y < case_bottom:
            continue

        xs = np.where(alpha[y] > 0)[0]
        if xs.size == 0:
            continue

        if y < top_end:
            span = int(xs[-1] - xs[0] + 1)
            if span <= TOP_STRAP_MAX_SPAN:
                envelope[y, xs[0] : xs[-1] + 1] = True
            continue

        if y >= strap_tail:
            envelope[y, xs[0] : xs[-1] + 1] = True
            continue

        for part in (xs[xs < LUG_SIDE_LEFT], xs[xs > LUG_SIDE_RIGHT]):
            if part.size >= 8:
                envelope[y, part[0] : part[-1] + 1] = True

    return envelope


def main() -> None:
    px = np.array(Image.open(SOURCE).convert("RGBA"))
    rgb = px[:, :, :3].copy()
    alpha = px[:, :, 3].copy()

    envelope = build_fabric_envelope(alpha)
    holes = envelope & (alpha == 0)

    out_alpha = alpha.copy()
    out_alpha[holes] = 255

    rgba = np.dstack([rgb, out_alpha]).astype(np.uint8)
    rgba[out_alpha == 0] = 0

    changed_alpha = (out_alpha != alpha).sum()
    changed_rgb = np.any(rgb != px[:, :, :3], axis=2).sum()
    if changed_rgb:
        raise RuntimeError("RGB was modified unexpectedly")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(
        f"saved {OUT.name} holes_sealed={int(holes.sum())} "
        f"alpha_changed={int(changed_alpha)} rgb_changed={int(changed_rgb)}"
    )


if __name__ == "__main__":
    main()
