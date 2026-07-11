#!/usr/bin/env python3
"""Export hero-watch-ultra.png from the official product photo."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(
    "/Users/maxk/.cursor/projects/Users-maxk-Dev-WeekFit/assets/"
    "image-bab0672d-dd08-4494-989e-ca67596f4c83.png"
)
EDITED = Path("/tmp/hero-watch-edited.png")
BASE_ALPHA = Path("/tmp/hero-watch-176611c.png")
OUT = ROOT / "public/img/hero-watch-ultra.png"

FABRIC_THRESHOLD = 22
STRAP_TOP_END = 0.24
STRAP_BOTTOM_START = 0.76


def run_magick_edits() -> None:
    cmd = [
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
    ]
    subprocess.run(cmd, check=True)


def load_base_alpha() -> np.ndarray:
    if not BASE_ALPHA.exists():
        with BASE_ALPHA.open("wb") as handle:
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
    base = np.array(Image.open(BASE_ALPHA).convert("RGBA"))
    return base[:, :, 3]


def crop_edited_rgb() -> np.ndarray:
    rgb = np.array(Image.open(EDITED).convert("RGB"), dtype=np.float32)
    max_c = rgb.max(axis=2)
    dark = max_c < 44

    seeds = np.zeros_like(dark, dtype=bool)
    seeds[0, :] = dark[0, :]
    seeds[-1, :] = dark[-1, :]
    seeds[:, 0] |= dark[:, 0]
    seeds[:, -1] |= dark[:, -1]
    bg = ndimage.binary_propagation(seeds, mask=dark)

    alpha = np.where(bg, 0, 255).astype(np.uint8)
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    cropped = np.array(Image.fromarray(rgba, mode="RGBA").crop(Image.fromarray(rgba).getbbox()))
    return cropped[:, :, :3].astype(np.float32)


def fabric_pixels(rgb: np.ndarray) -> np.ndarray:
    max_c = rgb.max(axis=2)
    blue = rgb[:, :, 2]
    red = rgb[:, :, 0]
    return (max_c > FABRIC_THRESHOLD) & (blue > red + 2)


def fill_strap_holes(rgb: np.ndarray, support: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    seeds = fabric_pixels(out) | (
        (out.max(axis=2) > FABRIC_THRESHOLD) & ndimage.binary_dilation(support, iterations=12)
    )

    for _ in range(4):
        holes = support & ~seeds
        if not holes.any():
            break
        _, (iy, ix) = ndimage.distance_transform_edt(~seeds, return_indices=True)
        hy, hx = np.where(holes)
        out[hy, hx] = out[iy[hy, hx], ix[hy, hx]]
        seeds = (out.max(axis=2) > FABRIC_THRESHOLD) & (support | seeds)

    dark = support & (out.max(axis=2) < FABRIC_THRESHOLD)
    if dark.any():
        h, _, _ = out.shape
        hy, hx = np.where(dark)
        for y, x in zip(hy, hx):
            for ny in range(y - 1, max(y - 12, -1), -1):
                if support[ny, x] and out[ny, x].max() > FABRIC_THRESHOLD:
                    out[y, x] = out[ny, x]
                    break
            else:
                for ny in range(y + 1, min(y + 12, h)):
                    if support[ny, x] and out[ny, x].max() > FABRIC_THRESHOLD:
                        out[y, x] = out[ny, x]
                        break

    return out


def strap_column_bounds(fabric_band: np.ndarray) -> tuple[int, int] | None:
    cols = np.where(fabric_band.any(axis=0))[0]
    if cols.size == 0:
        return None
    return int(cols[0]), int(cols[-1])


def solidify_strap_band(
    rgb: np.ndarray,
    alpha: np.ndarray,
    y0: int,
    y1: int,
    *,
    row_start: int = 0,
) -> tuple[np.ndarray, np.ndarray, slice]:
    """Make every row of the strap cross-section fully opaque."""
    band_fabric = fabric_pixels(rgb[y0:y1])
    bounds = strap_column_bounds(band_fabric)
    if bounds is None:
        return rgb, alpha, slice(y0, y0)

    xa, xb = bounds
    out_rgb = rgb.copy()
    out_alpha = alpha.copy()
    support = np.zeros_like(alpha, dtype=bool)

    close_kernel = np.ones((3, 11), dtype=bool)
    closed = ndimage.binary_closing(band_fabric, structure=close_kernel, iterations=1)
    closed = ndimage.binary_dilation(closed, iterations=2)

    fabric_rows = np.where(closed.any(axis=1))[0]
    if fabric_rows.size == 0:
        return rgb, alpha, slice(y0, y0)

    row_first = max(int(fabric_rows[0]), row_start)
    row_last = int(fabric_rows[-1])
    for i in range(row_first, row_last + 1):
        y = y0 + i
        support[y, xa : xb + 1] = True

    out_rgb = fill_strap_holes(out_rgb, support)
    out_alpha[support] = 255
    out_rgb = fill_strap_holes(out_rgb, support)
    return out_rgb, out_alpha, slice(y0 + row_first, y0 + row_last + 1)


def main() -> None:
    run_magick_edits()
    alpha = load_base_alpha()
    rgb = crop_edited_rgb()

    if rgb.shape[:2] != alpha.shape:
        raise RuntimeError(
            f"edited crop {rgb.shape[:2]} does not match base alpha {alpha.shape}"
        )

    h = alpha.shape[0]
    top_end = int(h * STRAP_TOP_END)
    bottom_start = int(h * STRAP_BOTTOM_START)

    rgb, alpha, top_rows = solidify_strap_band(rgb, alpha, 0, top_end)
    bottom_cutoff = int((h - bottom_start) * 0.45)
    rgb, alpha, bottom_rows = solidify_strap_band(
        rgb, alpha, bottom_start, h, row_start=bottom_cutoff
    )

    max_c = rgb.max(axis=2)
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0

    for name, rows, y0, y1 in (
        ("top", top_rows, 0, top_end),
        ("bottom", bottom_rows, bottom_start, h),
    ):
        band_fabric = fabric_pixels(rgb[y0:y1])
        bounds = strap_column_bounds(band_fabric)
        if bounds is None:
            continue
        xa, xb = bounds
        sub_alpha = alpha[rows, xa : xb + 1]
        holes = int((sub_alpha == 0).sum())
        print(f"{name} envelope {xa}-{xb} transparent={holes}")
        if holes:
            raise RuntimeError(f"{name} strap still has transparent pixels")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)
    print(f"saved {OUT} size={rgba.shape[1::-1]}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
