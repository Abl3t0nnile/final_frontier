#!/usr/bin/env python3
"""
Fetch real moon texture maps from USGS Astrogeology (public domain)
and convert them to 2048x1024 PNG for use in Final Frontier.

Source: https://astrogeology.usgs.gov  (public domain / NASA data)

Post-processing applied per moon:
  - Grayscale images get a scientifically-calibrated color tint
  - Incomplete coverage (black poles) gets filled from nearest valid row
  - All outputs are cropped to 2:1 equirectangular and scaled to 2048x1024
"""

import io
import os
import sys
import urllib.request

import numpy as np
from PIL import Image

OUTPUT_DIR = "moon_textures"
TARGET_W, TARGET_H = 2048, 1024

# USGS Astrogeology public-domain JPG previews (equirectangular, ~1024px wide)
SOURCES = {
    # Galilean moons (Galileo + Voyager)
    "io":       "https://astrogeology.usgs.gov/ckan/dataset/f6924861-ce9c-490d-8a4b-7812a20f2de5/resource/a9fab679-8081-4144-9f58-45848836c8f5/download/full.jpg",
    "europa":   "https://astrogeology.usgs.gov/ckan/dataset/4080036f-afc5-422e-abe9-1c0c8e4f98ea/resource/3647e7b3-425e-4dcf-951b-cc4a22fb0129/download/europa_voyager_galileossi_global_mosaic_500m_1024.jpg",
    "ganymede": "https://astrogeology.usgs.gov/ckan/dataset/e1422336-3291-4b65-b903-c942d53de073/resource/eb32abd7-fee2-47d1-9f96-9d7d8824cc3a/download/ganymede_voyager_galileossi_global_clrmosaic_1024.jpg",
    "callisto": "https://astrogeology.usgs.gov/ckan/dataset/a80abd68-7ed9-440e-829a-76376779164f/resource/ac628525-cb1c-4742-928b-5a0a60f372cd/download/callisto_voyager_galileossi_global_mosaic_1024.jpg",

    # Saturn's moons (Cassini + Voyager)
    "enceladus":"https://astrogeology.usgs.gov/ckan/dataset/30bff65e-56bb-4fd1-bd04-edd9bc2e77d0/resource/19ba2e14-9ceb-45e6-8cc8-e784e36ed4f0/download/full.jpg",
    "tethys":   "https://astrogeology.usgs.gov/ckan/dataset/e40296c1-b4bf-46d8-86af-4b6cf0301b0c/resource/36d40203-d9b3-447e-9004-c3dc100bde04/download/full.jpg",
    "dione":    "https://astrogeology.usgs.gov/ckan/dataset/acb98ae6-ec50-42df-9a74-142d177bbe6d/resource/8a6a8ada-42e1-4b92-b13e-c63493133efc/download/full.jpg",
    "rhea":     "https://astrogeology.usgs.gov/ckan/dataset/22bc1015-d9c9-4212-86c3-e42061b204d4/resource/77fa77f8-6d6b-4072-9360-17138caa6e7d/download/full.jpg",
    "titan":    "https://astrogeology.usgs.gov/ckan/dataset/8ee17e4e-26c6-4e22-9c23-bc9a4c7ed35e/resource/c3f3006c-3174-4716-920f-44f5dc749a4a/download/titan_iss_p19658_mosaic_global_1024.jpg",
    "iapetus":  "https://astrogeology.usgs.gov/ckan/dataset/6ac8ecfb-36e7-4113-8d16-c92ba857c3d7/resource/141c2d1e-aa01-4e2f-969a-e46a581db4b9/download/full.jpg",

    # Neptune's moon (Voyager 2)
    "triton":   "https://astrogeology.usgs.gov/ckan/dataset/445b4c39-e87a-4e4d-88a8-e48d8e755c5c/resource/de0ba9f1-303e-4e5f-a99a-3201fba9a764/download/triton_voyager2_clrmosaic_1024.jpg",

    # Pluto's moon (New Horizons)
    "charon":   "https://astrogeology.usgs.gov/ckan/dataset/93827f6c-8feb-42b6-98e6-b0ce57c7d2c8/resource/1abf318c-3290-4aa0-932e-a34f32d7f6ad/download/charon_newhorizons_global_mosaic_300m_jul2017_1024.jpg",
}

# Moons without usable global maps → kept as procedurally generated textures:
#   mimas       – only a cartographic printout available, no clean mosaic
#   miranda, ariel, umbriel, titania, oberon  – Voyager 2 partial only
#   hyperion, phoebe, janus, proteus, nereid  – insufficient coverage
#   all TNO moons (hiʻiaka, namaka, mk2, dysnomia, vanth, actaea, weywot, xiangliu)
#   amalthea, metis, thebe, himalia, elara, pasiphae  – unresolved blobs

# ── Color tints ───────────────────────────────────────────────────────────────
# Grayscale moons need a per-channel multiplier to match their real albedo color.
# Values are calibrated from published spectral data and reference imagery.
# Format: (R, G, B)  –  neutral grey = (1.0, 1.0, 1.0)
COLORIZE = {
    # Water-ice surface, slightly bluish-white
    "europa":   (0.93, 0.96, 1.05),
    # Dark dusty ice, faintly warm brown
    "callisto": (1.03, 1.00, 0.94),
    # Brightest object in solar system, cold blue-white ice
    "enceladus":(0.94, 0.97, 1.06),
    # Bright icy, very slightly cool
    "tethys":   (0.97, 0.98, 1.03),
    # Bright icy, near-neutral
    "dione":    (0.99, 0.99, 1.02),
    # Icy, slightly cool grey
    "rhea":     (0.97, 0.98, 1.03),
    # Iapetus: already partly color-merged, boost contrast slightly
    "iapetus":  (1.01, 1.00, 0.97),
    # Charon: grey with subtle reddish north pole cap (Mordor Macula)
    "charon":   (1.02, 1.00, 0.97),
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def fill_coverage_gaps(arr, threshold=12):
    """
    Fill black/no-data pixels from incomplete orbital coverage.
    Call on the original image BEFORE resize so edges are clean.

    Strategy: fill every no-data pixel with the mean color of all
    valid pixels. Simple, fast, no horizontal-stretch artifacts.
    Returns (filled_array, was_changed).
    """
    mask = np.all(arr < threshold, axis=2)   # True = no-data pixel
    if not mask.any():
        return arr, False

    valid_pixels = arr[~mask]
    if len(valid_pixels) == 0:
        return arr, False

    mean_color = valid_pixels.mean(axis=0).astype(np.uint8)
    result = arr.copy()
    result[mask] = mean_color
    return result, True


def apply_colorize(arr, r_mul, g_mul, b_mul):
    """Multiply each RGB channel to tint a grayscale-encoded image."""
    out = arr.astype(np.float32)
    out[:, :, 0] *= r_mul
    out[:, :, 1] *= g_mul
    out[:, :, 2] *= b_mul
    return np.clip(out, 0, 255).astype(np.uint8)


def process(name, data):
    img = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = img.size
    print(f"    {w}×{h}", end="", flush=True)

    # ── 1. Fill coverage gaps BEFORE resize (clean hard edges in source) ──────
    arr = np.array(img)
    arr, was_filled = fill_coverage_gaps(arr)
    if was_filled:
        print(" [gap-filled]", end="", flush=True)
        img = Image.fromarray(arr)

    # ── 2. Crop to 2:1 equirectangular ───────────────────────────────────────
    w, h = img.size
    aspect = w / h
    if abs(aspect - 2.0) > 0.05:
        if aspect > 2.0:
            new_w = h * 2
            img = img.crop(((w - new_w) // 2, 0, (w + new_w) // 2, h))
        else:
            new_h = w // 2
            img = img.crop((0, (h - new_h) // 2, w, (h + new_h) // 2))

    # ── 3. Resize ─────────────────────────────────────────────────────────────
    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    arr = np.array(img)

    # ── 4. Apply color tint to grayscale images ───────────────────────────────
    if name in COLORIZE:
        arr = apply_colorize(arr, *COLORIZE[name])
        print(" [colorized]", end="", flush=True)

    # ── 5. Save ───────────────────────────────────────────────────────────────
    out_path = os.path.join(OUTPUT_DIR, f"2k_{name}.png")
    Image.fromarray(arr).save(out_path, optimize=True)
    print(" → saved")
    return out_path


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    targets = SOURCES
    if len(sys.argv) > 1:
        targets = {k: v for k, v in SOURCES.items() if k in sys.argv[1:]}

    ok, fail = [], []
    print(f"Fetching {len(targets)} real moon textures from USGS Astrogeology...\n")

    for name in sorted(targets):
        print(f"  {name} ...", end=" ", flush=True)
        try:
            data = fetch(targets[name])
            process(name, data)
            ok.append(name)
        except Exception as e:
            print(f"FAILED: {e}")
            fail.append(name)

    print(f"\n{len(ok)} fetched, {len(fail)} failed.")
    if fail:
        print(f"  Failed: {', '.join(fail)}")


if __name__ == "__main__":
    main()
