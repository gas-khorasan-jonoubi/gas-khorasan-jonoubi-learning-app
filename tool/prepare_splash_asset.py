#!/usr/bin/env python3
"""Create the optimized, bundled splash image from the approved source poster.

The original PNG is kept in the repository as the editable source of truth.
Only the generated WebP is included in the Flutter asset bundle.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


DEFAULT_SOURCE = Path("assets/approved_splash.png")
DEFAULT_OUTPUT = Path("assets/approved_splash.webp")
DEFAULT_QUALITY = 92


def prepare_splash_asset(
    source_path: Path = DEFAULT_SOURCE,
    output_path: Path = DEFAULT_OUTPUT,
    quality: int = DEFAULT_QUALITY,
) -> tuple[int, int, int, int]:
    """Convert the approved PNG to WebP and return source/output dimensions/sizes."""
    if not 1 <= quality <= 100:
        raise ValueError("WebP quality must be between 1 and 100.")
    if not source_path.is_file() or source_path.stat().st_size == 0:
        raise FileNotFoundError(f"Approved splash source is missing: {source_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    source_size = source_path.stat().st_size

    with Image.open(source_path) as source:
        source.load()
        source_size_px = source.size
        has_alpha = "A" in source.getbands()
        converted = source.convert("RGBA" if has_alpha else "RGB")
        converted.save(
            output_path,
            format="WEBP",
            quality=quality,
            method=6,
            exact=True,
        )

    with Image.open(output_path) as optimized:
        optimized.load()
        if optimized.format != "WEBP":
            raise RuntimeError("Generated splash asset is not a WebP image.")
        if optimized.size != source_size_px:
            raise RuntimeError(
                f"Splash dimensions changed: {source_size_px} -> {optimized.size}"
            )

    output_size = output_path.stat().st_size
    if output_size <= 0 or output_size >= source_size:
        raise RuntimeError(
            "Optimized splash is not smaller than the approved PNG "
            f"({output_size} >= {source_size} bytes)."
        )

    return source_size_px[0], source_size_px[1], source_size, output_size


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--quality", type=int, default=DEFAULT_QUALITY)
    args = parser.parse_args()

    try:
        width, height, source_size, output_size = prepare_splash_asset(
            args.source,
            args.output,
            args.quality,
        )
    except (OSError, ValueError, RuntimeError) as error:
        parser.error(str(error))

    saved = source_size - output_size
    reduction = saved / source_size * 100
    print(
        f"OK: {width}x{height} approved splash optimized at quality "
        f"{args.quality}: {source_size} -> {output_size} bytes "
        f"({reduction:.1f}% smaller)."
    )
    print(f"Bundled asset: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
