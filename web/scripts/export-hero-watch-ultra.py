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
STRAP_ALPHA_DILATE = 6


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


def densify_strap_support(
    support: np.ndarray,
) -> tuple[np.ndarray, tuple[int, int] | None]:
    """Fill sparse scanlines in the bottom strap without widening the top band."""
    h, _ = support.shape
    out = support.copy()
    y0 = int(h * STRAP_BOTTOM_START)
    band = out[y0:]
    cutoff = int(len(band) * 0.45)
    dense_rows = [
        i for i, row in enumerate(band) if i >= cutoff and row.sum() > 150
    ]
    if not dense_rows:
        return out, None

    xa = min(int(np.where(band[i])[0][0]) for i in dense_rows)
    xb = max(int(np.where(band[i])[0][-1]) for i in dense_rows)
    envelope = np.zeros(band.shape[1], dtype=bool)
    envelope[xa : xb + 1] = True
    target = int(envelope.sum() * 0.65)

    for i, row in enumerate(band):
        if i < cutoff:
            continue
        if row.any() and row.sum() < target:
            band[i] = envelope

    out[y0:] = band
    return out, (xa, xb)


def strap_support(alpha: np.ndarray) -> np.ndarray:
    """Strap band mask wide enough to cover weave holes in the base alpha."""
    h, _ = alpha.shape
    product = alpha > 0
    support = np.zeros_like(product, dtype=bool)

    for y0, y1 in (
        (0, int(h * STRAP_TOP_END)),
        (int(h * STRAP_BOTTOM_START), h),
    ):
        support[y0:y1] = ndimage.binary_dilation(
            product[y0:y1], iterations=STRAP_ALPHA_DILATE
        )

    return densify_strap_support(support)[0]


def fill_strap_holes(rgb: np.ndarray, support: np.ndarray) -> np.ndarray:
    max_c = rgb.max(axis=2)
    fabric = (max_c > FABRIC_THRESHOLD) & support
    holes = support & ~fabric
    if not holes.any():
        return rgb

    _, (iy, ix) = ndimage.distance_transform_edt(~fabric, return_indices=True)
    out = rgb.copy()
    hy, hx = np.where(holes)
    out[hy, hx] = rgb[iy[hy, hx], ix[hy, hx]]
    return out


def seal_strap_alpha(alpha: np.ndarray, support: np.ndarray) -> np.ndarray:
    out = alpha.copy()
    out[support] = 255
    return out


def main() -> None:
    run_magick_edits()
    alpha = load_base_alpha()
    rgb = crop_edited_rgb()

    if rgb.shape[:2] != alpha.shape:
        raise RuntimeError(
            f"edited crop {rgb.shape[:2]} does not match base alpha {alpha.shape}"
        )

    support = strap_support(alpha)
    h = alpha.shape[0]
    y0 = int(h * STRAP_BOTTOM_START)
    cutoff = int((h - y0) * 0.45)

    fill_mask = support.copy()
    fill_mask[y0 : y0 + cutoff] &= alpha[y0 : y0 + cutoff] > 0

    support_alpha = np.zeros_like(support)
    support_alpha[: int(h * STRAP_TOP_END)] = support[: int(h * STRAP_TOP_END)]
    support_alpha[y0 + cutoff :] = support[y0 + cutoff :]

    rgb = fill_strap_holes(rgb, fill_mask)
    alpha = seal_strap_alpha(alpha, support_alpha)
    rgb = fill_strap_holes(rgb, support_alpha)
    max_c = rgb.max(axis=2)

    rgba = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    rgba[alpha == 0] = 0

    holes = int((support_alpha & (alpha == 0)).sum())
    dark_opaque = int((fill_mask & (alpha > 0) & (max_c < FABRIC_THRESHOLD)).sum())
    if holes:
        raise RuntimeError(f"strap support still has {holes} transparent pixels")
    if dark_opaque:
        raise RuntimeError(f"strap support still has {dark_opaque} dark opaque pixels")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(OUT, optimize=False)

    h, w = alpha.shape
    print(f"saved {OUT} size=({w}, {h})")
    px = rgba
    for y in (int(h * 0.1), int(h * 0.9), h // 2):
        opaque = [x for x in range(w) if px[y, x, 3] > 250]
        if opaque:
            print(
                f"y={y} opaque span={min(opaque)}-{max(opaque)} count={len(opaque)}"
            )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
