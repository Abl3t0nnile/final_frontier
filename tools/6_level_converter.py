#!/usr/bin/env python3
"""
Converts an equirectangular texture to a quantized grayscale image.
Uses histogram equalization to spread values evenly across all levels.

Usage:
    python texture_prepare.py input.jpg output.png
    python texture_prepare.py input.jpg output.png --levels 6
    python texture_prepare.py input.jpg output.png --levels 4 --no-equalize
"""

import argparse
import numpy as np
from PIL import Image, ImageOps


def quantize(image: Image.Image, num_levels: int, equalize: bool) -> Image.Image:
    gray = image.convert("L")
    if equalize:
        gray = ImageOps.equalize(gray)
    arr = np.array(gray, dtype=np.float64)
    levels = np.linspace(0, 255, num_levels).astype(np.float64)
    indices = np.abs(arr[:, :, None] - levels[None, None, :]).argmin(axis=2)
    result = levels[indices].astype(np.uint8)
    return Image.fromarray(result, "L")


def main():
    parser = argparse.ArgumentParser(description="Prepare planet texture for 1-bit shader")
    parser.add_argument("input", help="Input texture (any format)")
    parser.add_argument("output", help="Output path (.png)")
    parser.add_argument("--levels", type=int, default=16, help="Number of gray levels (default: 6)")
    parser.add_argument("--no-equalize", action="store_true", help="Skip histogram equalization")
    args = parser.parse_args()

    img = Image.open(args.input)
    result = quantize(img, args.levels, not args.no_equalize)
    result.save(args.output)

    unique = np.unique(np.array(result))
    print(f"{args.input} -> {result.size[0]}x{result.size[1]}, {len(unique)} levels: {unique.tolist()}")


if __name__ == "__main__":
    main()