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
