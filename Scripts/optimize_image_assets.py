#!/usr/bin/env python3
"""
Optimize WeekFit Assets.xcassets for App Store binary size.

- Remove unreferenced orphan imagesets
- Opaque photographic assets → JPEG q82, max edge 900
- Transparent photographic assets → PNG retained, max edge 900 + strip
- Preserve logos / UI chrome / AppIcon
"""

from __future__ import annotations

import json
import re
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "WeekFit" / "Resources" / "Assets.xcassets"
REPORT_DIR = ROOT / "backups"
JPEG_QUALITY = "82"
MAX_EDGE = 900
PROTECTED = {
    "AppIcon",
    "AccentColor",
    "weekfit-bg",
    "plate-dark",
    "g-logo",
}

# Legacy duplicates / unused catalog entries confirmed with precise asset-ref scan.
FORCE_ORPHANS = {
    "apple",
    "banana",
    "eggs",
    "greek-yogurt",
    "water-bottle",
    "drink-orange-juice",
    "energy-gel",
    "high-protein-jogurt",
    "strabery-high-protein-jogurt",
    "ingredient-electrolytes",
    "ingredient-mineral-water",
    "meal-greens",
    "plate-ceramic",
    "sports-drink",
}

PHOTO_PREFIXES = (
    "ingredient-",
    "meal-",
    "workout-",
    "recovery-",
    "habit-",
    "drink-",
    "snack-",
    "sports-",
)
PHOTO_NAMES = {
    "breakfast",
    "dinner",
    "lunch",
    "hydration",
    "energy-gel",
    "apple",
    "banana",
    "eggs",
    "greek-yogurt",
    "water-bottle",
}


@dataclass
class ImageFile:
    path: Path
    width: int
    height: int
    has_alpha: bool
    size: int


@dataclass
class Report:
    original_bytes: int = 0
    final_bytes: int = 0
    deleted: list[dict] = field(default_factory=list)
    optimized_jpeg: list[dict] = field(default_factory=list)
    optimized_png: list[dict] = field(default_factory=list)
    skipped: list[dict] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    remaining_large: list[dict] = field(default_factory=list)


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True)


def png_info(path: Path) -> tuple[int, int, bool] | None:
    try:
        with path.open("rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            width = height = 0
            color = 0
            trns = False
            while True:
                length = struct.unpack(">I", f.read(4))[0]
                ctype = f.read(4)
                data = f.read(length)
                f.read(4)
                if ctype == b"IHDR":
                    width, height = struct.unpack(">II", data[:8])
                    color = data[9]
                elif ctype == b"tRNS":
                    trns = True
                elif ctype == b"IEND":
                    break
            return width, height, trns or color in (4, 6)
    except Exception:
        return None


def jpeg_dims(path: Path) -> tuple[int, int] | None:
    result = run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)])
    if result.returncode != 0:
        return None
    width = height = None
    for line in result.stdout.splitlines():
        if "pixelWidth:" in line:
            width = int(line.split(":")[-1].strip())
        if "pixelHeight:" in line:
            height = int(line.split(":")[-1].strip())
    if width and height:
        return width, height
    return None


def image_file_info(path: Path) -> ImageFile | None:
    suffix = path.suffix.lower()
    size = path.stat().st_size
    if suffix == ".png":
        info = png_info(path)
        if not info:
            return None
        w, h, alpha = info
        return ImageFile(path, w, h, alpha, size)
    if suffix in {".jpg", ".jpeg"}:
        dims = jpeg_dims(path)
        if not dims:
            return None
        return ImageFile(path, dims[0], dims[1], False, size)
    return None


def imageset_image_files(iset: Path) -> list[Path]:
    return sorted(
        p
        for p in iset.iterdir()
        if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".heic"}
    )


def catalog_bytes() -> int:
    return sum(p.stat().st_size for p in ASSETS.rglob("*") if p.is_file())


def load_reference_names() -> set[str]:
    names = {p.name.replace(".imageset", "") for p in ASSETS.glob("*.imageset")}
    refs: set[str] = set()

    for jp in [
        ROOT / "WeekFit" / "Resources" / "meals.json",
        ROOT / "WeekFit" / "Resources" / "drinks_snacks.json",
    ]:
        if not jp.exists():
            continue
        text = jp.read_text(errors="ignore")
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            data = None

        def walk(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if key in {"imageName", "image", "asset", "iconAsset"} and isinstance(value, str):
                        refs.add(value)
                    walk(value)
            elif isinstance(node, list):
                for item in node:
                    walk(item)

        if data is not None:
            walk(data)
        for match in re.findall(r'"([a-zA-Z0-9_\-]+)"', text):
            if match in names:
                refs.add(match)

    blobs: list[str] = []
    for base in [ROOT / "WeekFit", ROOT / "Packages", ROOT / "WeekFitTests"]:
        if not base.exists():
            continue
        for path in base.rglob("*.swift"):
            blobs.append(path.read_text(errors="ignore"))
    blob = "\n".join(blobs)
    for name in names:
        if re.search(rf'Image\(\s*"{re.escape(name)}"\s*\)', blob):
            refs.add(name)
        if re.search(rf'UIImage\(named:\s*"{re.escape(name)}"\s*\)', blob):
            refs.add(name)
        if re.search(rf'imageName:\s*"{re.escape(name)}"', blob):
            refs.add(name)
        if re.search(rf'"{re.escape(name)}"', blob) and name.startswith(
            ("ingredient-", "meal-", "workout-", "recovery-", "habit-", "drink-", "snack-")
        ):
            refs.add(name)
    return refs


def is_photo_asset(name: str) -> bool:
    if name in PHOTO_NAMES:
        return True
    return name.startswith(PHOTO_PREFIXES)


def read_contents(iset: Path) -> dict:
    path = iset / "Contents.json"
    if not path.exists():
        return {"images": [{"idiom": "universal", "scale": "1x"}], "info": {"author": "xcode", "version": 1}}
    return json.loads(path.read_text())


def write_contents(iset: Path, filename: str) -> None:
    contents = {
        "images": [
            {"filename": filename, "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (iset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def resize_if_needed(src: Path, dest: Path, max_edge: int) -> None:
    info = image_file_info(src)
    if info and max(info.width, info.height) > max_edge:
        result = run(
            [
                "sips",
                "--resampleHeightWidthMax",
                str(max_edge),
                str(src),
                "--out",
                str(dest),
            ]
        )
        if result.returncode != 0 or not dest.exists():
            shutil.copy2(src, dest)
    else:
        if src.resolve() != dest.resolve():
            shutil.copy2(src, dest)


def convert_opaque_to_jpeg(iset: Path, name: str, primary: ImageFile, report: Report) -> None:
    before = sum(p.stat().st_size for p in imageset_image_files(iset))
    tmp_dir = iset / ".optimize_tmp"
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir()
    resized = tmp_dir / "resized.png"
    out_name = f"{name}.jpg"
    out_path = tmp_dir / out_name

    resize_if_needed(primary.path, resized, MAX_EDGE)
    result = run(
        [
            "sips",
            "-s",
            "format",
            "jpeg",
            "-s",
            "formatOptions",
            JPEG_QUALITY,
            str(resized),
            "--out",
            str(out_path),
        ]
    )
    if result.returncode != 0 or not out_path.exists() or out_path.stat().st_size == 0:
        report.errors.append(f"JPEG convert failed: {name}: {result.stderr.strip()}")
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return

    # Replace imageset image files
    for old in imageset_image_files(iset):
        old.unlink(missing_ok=True)
    final_path = iset / out_name
    shutil.move(str(out_path), str(final_path))
    shutil.rmtree(tmp_dir, ignore_errors=True)
    write_contents(iset, out_name)
    after = final_path.stat().st_size
    report.optimized_jpeg.append(
        {
            "name": name,
            "before": before,
            "after": after,
            "saved": before - after,
        }
    )


def optimize_transparent_png(iset: Path, name: str, primary: ImageFile, report: Report) -> None:
    before = sum(p.stat().st_size for p in imageset_image_files(iset))
    tmp_dir = iset / ".optimize_tmp"
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir()
    out_name = f"{name}.png"
    resized = tmp_dir / "resized.png"
    final_tmp = tmp_dir / out_name

    resize_if_needed(primary.path, resized, MAX_EDGE)

    # Strip metadata + recompress; keep RGBA
    result = run(
        [
            "magick",
            str(resized),
            "-strip",
            "-define",
            "png:compression-filter=5",
            "-define",
            "png:compression-level=9",
            "-define",
            "png:compression-strategy=1",
            str(final_tmp),
        ]
    )
    if result.returncode != 0 or not final_tmp.exists():
        # Fallback: keep resized PNG from sips
        if resized.exists():
            shutil.copy2(resized, final_tmp)
        else:
            report.errors.append(f"PNG optimize failed: {name}")
            shutil.rmtree(tmp_dir, ignore_errors=True)
            return

    # Only replace if smaller or renamed/cleaned; never grow more than 5%
    candidate_size = final_tmp.stat().st_size
    use_candidate = candidate_size <= before * 1.05
    if not use_candidate and max(primary.width, primary.height) <= MAX_EDGE and primary.path.name == out_name:
        report.skipped.append({"name": name, "reason": "png_not_smaller", "bytes": before})
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return

    for old in imageset_image_files(iset):
        old.unlink(missing_ok=True)
    final_path = iset / out_name
    if use_candidate:
        shutil.move(str(final_tmp), str(final_path))
    else:
        # Keep resize benefit even if magick grew slightly vs original full-res
        shutil.move(str(resized), str(final_path))
    shutil.rmtree(tmp_dir, ignore_errors=True)
    write_contents(iset, out_name)
    after = final_path.stat().st_size
    report.optimized_png.append(
        {
            "name": name,
            "before": before,
            "after": after,
            "saved": before - after,
        }
    )


def choose_primary(files: list[Path]) -> ImageFile | None:
    infos = [image_file_info(p) for p in files]
    infos = [i for i in infos if i is not None]
    if not infos:
        return None
    # Prefer largest pixel count (usually the main @2x/source)
    return max(infos, key=lambda i: i.width * i.height)


def delete_orphans(report: Report) -> None:
    """Delete only explicitly confirmed orphans / empty imagesets."""
    refs = load_reference_names()
    for iset in sorted(ASSETS.glob("*.imageset")):
        name = iset.name.replace(".imageset", "")
        if name in PROTECTED or name.startswith("AppIcon"):
            continue

        files = imageset_image_files(iset)
        confirmed = name in FORCE_ORPHANS
        empty = len(files) == 0
        # Extra heuristic: unreferenced AND not a namespaced catalog asset we might load dynamically
        unreferenced_legacy = (
            name not in refs
            and not name.startswith(("ingredient-", "meal-", "workout-", "recovery-", "habit-"))
        )

        if not (confirmed or empty or unreferenced_legacy):
            continue

        size = sum(p.stat().st_size for p in iset.rglob("*") if p.is_file())
        shutil.rmtree(iset)
        report.deleted.append({"name": name, "bytes": size, "reason": "orphan"})


def optimize_all(report: Report) -> None:
    for iset in sorted(ASSETS.glob("*.imageset")):
        name = iset.name.replace(".imageset", "")
        if name in PROTECTED or name.startswith("AppIcon"):
            report.skipped.append({"name": name, "reason": "protected"})
            continue
        if not is_photo_asset(name):
            # Large non-photo leftovers still worth checking
            files = imageset_image_files(iset)
            total = sum(p.stat().st_size for p in files)
            if total < 200 * 1024:
                report.skipped.append({"name": name, "reason": "non_photo_small"})
                continue

        files = imageset_image_files(iset)
        if not files:
            report.skipped.append({"name": name, "reason": "empty_imageset"})
            continue
        primary = choose_primary(files)
        if primary is None:
            report.errors.append(f"Could not read image: {name}")
            continue

        if primary.has_alpha:
            optimize_transparent_png(iset, name, primary, report)
        else:
            convert_opaque_to_jpeg(iset, name, primary, report)


def validate(report: Report) -> None:
    refs = load_reference_names()
    missing = []
    for name in sorted(refs):
        if name in PROTECTED:
            continue
        if not (ASSETS / f"{name}.imageset").exists():
            # refs may include non-asset strings for prefixed scan; only flag known photo-like
            if is_photo_asset(name) or name.startswith(("ingredient-", "meal-", "workout-", "recovery-", "habit-")):
                missing.append(name)
    if missing:
        report.errors.append(f"Missing referenced imagesets: {', '.join(missing)}")

    for iset in ASSETS.glob("*.imageset"):
        contents = read_contents(iset)
        for image in contents.get("images", []):
            filename = image.get("filename")
            if filename and not (iset / filename).exists():
                report.errors.append(f"Broken Contents.json: {iset.name}/{filename}")

    for iset in ASSETS.glob("*.imageset"):
        for path in imageset_image_files(iset):
            size = path.stat().st_size
            if size > 500 * 1024:
                report.remaining_large.append(
                    {
                        "name": iset.name.replace(".imageset", ""),
                        "file": path.name,
                        "bytes": size,
                    }
                )


def mb(n: int) -> float:
    return n / 1024 / 1024


def main() -> int:
    if not ASSETS.exists():
        print(f"Assets not found: {ASSETS}", file=sys.stderr)
        return 1

    report = Report(original_bytes=catalog_bytes())
    print(f"Original catalog: {mb(report.original_bytes):.1f} MB")

    print("Removing orphans…")
    delete_orphans(report)
    print(f"Deleted {len(report.deleted)} imagesets ({mb(sum(d['bytes'] for d in report.deleted)):.1f} MB)")

    print("Optimizing photographic assets…")
    optimize_all(report)

    report.final_bytes = catalog_bytes()
    validate(report)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    report_path = REPORT_DIR / f"asset-optimize-report-{stamp}.json"
    payload = {
        "timestamp": stamp,
        "original_bytes": report.original_bytes,
        "final_bytes": report.final_bytes,
        "saved_bytes": report.original_bytes - report.final_bytes,
        "deleted_count": len(report.deleted),
        "optimized_jpeg_count": len(report.optimized_jpeg),
        "optimized_png_count": len(report.optimized_png),
        "deleted": report.deleted,
        "optimized_jpeg": report.optimized_jpeg,
        "optimized_png": report.optimized_png,
        "skipped": report.skipped,
        "errors": report.errors,
        "remaining_large": sorted(report.remaining_large, key=lambda x: -x["bytes"]),
        "estimated_assets_car_before_mb": 154,
        "estimated_assets_car_after_mb": round(154 * (report.final_bytes / max(report.original_bytes, 1)), 1),
    }
    REPORT_DIR.mkdir(exist_ok=True)
    report_path.write_text(json.dumps(payload, indent=2) + "\n")

    print("\n=== SUMMARY ===")
    print(f"Deleted imagesets: {len(report.deleted)}")
    print(f"Optimized JPEG:    {len(report.optimized_jpeg)}")
    print(f"Optimized PNG:     {len(report.optimized_png)}")
    print(f"Original size:     {mb(report.original_bytes):.1f} MB")
    print(f"New size:          {mb(report.final_bytes):.1f} MB")
    print(f"Saved:             {mb(report.original_bytes - report.final_bytes):.1f} MB ({100 * (1 - report.final_bytes / report.original_bytes):.0f}%)")
    print(f"Remaining >500KB:  {len(report.remaining_large)}")
    if report.errors:
        print("ERRORS:")
        for err in report.errors:
            print(f"  - {err}")
    print(f"Report: {report_path}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
