#!/usr/bin/env python3
"""
Procedural Moon Texture Generator for Final Frontier
Generates 2048x1024 equirectangular surface maps.
"""

import numpy as np
from PIL import Image
import os, sys

WIDTH = 2048
HEIGHT = 1024
OUTPUT_DIR = "moon_textures"

MOON_SURFACE_TYPES = {
    "io": "volcanic", "europa": "ice_cracked",
    "ganymede": "ice_cratered", "callisto": "ice_cratered_dark",
    "amalthea": "rocky_irregular", "metis": "rocky_irregular",
    "thebe": "rocky_irregular", "himalia": "rocky_irregular",
    "elara": "rocky_irregular", "pasiphae": "rocky_irregular",
    "mimas": "ice_cratered", "enceladus": "ice_smooth",
    "tethys": "ice_cratered", "dione": "ice_cratered",
    "rhea": "ice_cratered", "titan": "hazy_orange",
    "hyperion": "spongy", "iapetus": "two_tone",
    "phoebe": "rocky_dark", "janus": "rocky_irregular",
    "miranda": "ice_fractured", "ariel": "ice_cratered",
    "umbriel": "ice_cratered_dark", "titania": "ice_cratered",
    "oberon": "ice_cratered_dark",
    "triton": "ice_cantaloupe", "nereid": "rocky_irregular",
    "proteus": "rocky_dark",
    "charon": "ice_cratered",
    "hiʻiaka": "ice_bright_kbo", "namaka": "ice_bright_kbo",
    "mk2": "rocky_very_dark", "dysnomia": "rocky_dark",
    "vanth": "rocky_dark", "actaea": "rocky_very_dark",
    "weywot": "rocky_dark", "xiangliu": "rocky_dark",
}

# ── Noise ────────────────────────────────────────────────────────────────────

def vnoise(u, v, freq, seed=0):
    x, y = u * freq, v * freq
    xi, yi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
    xf, yf = x - xi, y - yi
    xf = xf*xf*(3-2*xf); yf = yf*yf*(3-2*yf)
    def h(ix, iy):
        n = np.int64(ix)*374761393 + np.int64(iy)*668265263 + np.int64(seed)*1274126177
        n = (n ^ (n >> 13)) * 1274126177; n = n ^ (n >> 16)
        return (n & 0x7FFFFFFF).astype(np.float64) / 0x7FFFFFFF
    a, b, c, d = h(xi,yi), h(xi+1,yi), h(xi,yi+1), h(xi+1,yi+1)
    return a*(1-xf)*(1-yf) + b*xf*(1-yf) + c*(1-xf)*yf + d*xf*yf

def fbm(u, v, oct=6, bf=4.0, lac=2.0, g=0.5, seed=0):
    t = np.zeros_like(u); a = 1.0; f = bf; ma = 0.0
    for i in range(oct):
        t += a * vnoise(u, v, f, seed+i*31); ma += a; f *= lac; a *= g
    return t / ma

def ridged(u, v, oct=5, bf=4.0, lac=2.0, g=0.5, seed=0):
    t = np.zeros_like(u); a = 1.0; f = bf
    for i in range(oct):
        n = vnoise(u, v, f, seed+i*31)
        n = 1.0 - np.abs(2*n - 1); n = n*n
        t += a * n; f *= lac; a *= g
    return t / 1.5

def craters(u, v, count=50, rmin=0.004, rmax=0.05, seed=42, ejecta=0.08):
    """
    Craters with realistic morphology: dark bowl, bright rim, ejecta blanket.
    Power-law size distribution. Returns additive brightness delta.
    """
    rng = np.random.RandomState(seed)
    result = np.zeros_like(u)
    for _ in range(count):
        # Power-law: uniform in log space → many small, few large
        r = rmin * (rmax / rmin) ** rng.uniform(0, 1)
        cx = rng.uniform(0, 1)
        cy = rng.uniform(0.05, 0.95)
        depth = rng.uniform(0.5, 1.0)

        du = np.abs(u - cx); du = np.minimum(du, 1 - du)
        d = np.sqrt(du**2 + (v - cy)**2)
        nd = d / max(r, 1e-9)

        # Bowl: dark interior with shaded walls
        bowl = nd < 1.0
        result -= bowl * (1.0 - nd**2 * 0.55) * depth * 0.42

        # Rim: very soft, slightly randomized to avoid perfect white circles
        rim = np.clip(1.0 - np.abs(nd - 1.12) / 0.28, 0, 1) ** 2.0
        result += rim * depth * 0.10

        # Ejecta blanket: gradual brightness falloff outside rim
        ej = (nd > 1.0) * np.clip((3.5 - nd) / 2.5, 0, 1) ** 2
        result += ej * depth * ejecta

    return result

def lineae(u, v, count=30, seed=99, width_scale=1.0, band_profile=2):
    """
    band_profile=2 → Gaussian (thin lines)
    band_profile=1 → exponential (broad bands, more geological)
    """
    rng = np.random.RandomState(seed)
    res = np.zeros_like(u)
    for _ in range(count):
        x0, y0 = rng.uniform(0,1), rng.uniform(0.05,0.95)
        ang = rng.uniform(0, np.pi)
        ln = rng.uniform(0.08, 0.5); w = rng.uniform(0.003, 0.010) * width_scale
        inten = rng.uniform(0.3, 0.8)
        dx, dy = np.cos(ang), np.sin(ang)
        pu = u-x0; pu -= np.round(pu); pv = v-y0
        along = pu*dx + pv*dy; perp = np.abs(-pu*dy + pv*dx)
        cross = np.exp(-(perp/w)**band_profile)
        res += cross * np.exp(-(along/(ln/2))**4) * inten
    return np.clip(res, 0, 1)

def make_uv():
    u = np.linspace(0,1,WIDTH,endpoint=False)
    v = np.linspace(0,1,HEIGHT,endpoint=False)
    return np.meshgrid(u, v)

def P(r,g,b):
    return (np.clip(np.stack([r,g,b],axis=-1),0,1)*255).astype(np.uint8)

def autolevels(arr, lo=0.01, hi=0.99):
    """Stretch contrast so the full tonal range is used."""
    lo_v = np.percentile(arr, lo*100)
    hi_v = np.percentile(arr, hi*100)
    return np.clip((arr - lo_v) / max(hi_v - lo_v, 1e-9), 0, 1)

# ── Generators ───────────────────────────────────────────────────────────────

def gen_volcanic(u, v, s):
    """Io: multi-colored sulphur volcanic surface with calderas and lava flows."""
    base = fbm(u, v, 7, bf=4, seed=s)
    fine = fbm(u, v, 8, bf=16, seed=s+5)
    region_r = fbm(u, v, 4, bf=2, seed=s+11)   # red sulphur patches
    region_w = fbm(u, v, 4, bf=2, seed=s+12)   # white SO2 frost
    lava_n   = fbm(u, v, 5, bf=8, seed=s+30)

    # Calderas: dark circular depressions
    rng = np.random.RandomState(s+20)
    caldera = np.zeros_like(u)
    for _ in range(14):
        cx, cy = rng.uniform(0,1), rng.uniform(0.1,0.9)
        r = rng.uniform(0.012, 0.055)
        du = np.abs(u-cx); du = np.minimum(du, 1-du)
        d = np.sqrt(du**2 + (v-cy)**2) / max(r, 1e-9)
        caldera += np.clip(1 - d, 0, 1)**2 * rng.uniform(0.5, 1.0)
    caldera = np.clip(caldera, 0, 1)

    # Dark lava flow patches
    lava_flows = np.clip((lava_n - 0.62) * 9, 0, 1)

    # Base yellow sulphur
    r_ch = 0.72 + 0.20*base + 0.06*fine
    g_ch = 0.55 + 0.18*base + 0.05*fine
    b_ch = 0.06 + 0.04*base

    # Red/orange sulphur patches
    red = np.clip((region_r - 0.50) * 3.5, 0, 1)
    r_ch += red * 0.20; g_ch -= red * 0.14; b_ch -= red * 0.02

    # White SO2 frost deposits
    white = np.clip((region_w - 0.55) * 4.5, 0, 1)
    r_ch += white * (0.92 - r_ch) * 0.75
    g_ch += white * (0.92 - g_ch) * 0.75
    b_ch += white * (0.82 - b_ch) * 0.75

    # Calderas: very dark
    r_ch -= caldera * 0.52; g_ch -= caldera * 0.46; b_ch -= caldera * 0.38

    # Lava flows: dark grey-brown
    r_ch -= lava_flows * 0.38; g_ch -= lava_flows * 0.34; b_ch -= lava_flows * 0.28

    return P(r_ch, g_ch, b_ch)

def gen_ice_cracked(u, v, s):
    """Europa: smooth bright ice crossed by dark reddish-brown sulphur lineae."""
    base = fbm(u, v, 7, bf=5, seed=s)
    fine = fbm(u, v, 9, bf=24, seed=s+5)
    micro = fbm(u, v, 6, bf=48, seed=s+8)

    # Europa lineae: broad geological bands (double-ridge style), not thin lines
    li  = lineae(u, v, 16, s+1, width_scale=3.5, band_profile=1)
    li2 = lineae(u, v,  8, s+2, width_scale=1.2, band_profile=1)
    cr  = craters(u, v, 12, 0.003, 0.022, s+2, ejecta=0.03)

    # Bright icy base
    br = 0.62 + 0.18*base + 0.10*fine + 0.05*micro + cr

    # Lineae are dark reddish-brown (sulphur salt contamination)
    # Subtract more from G and B than R to produce a warm-dark hue
    r_ch = br - li*0.28 - li2*0.14
    g_ch = br - li*0.36 - li2*0.18
    b_ch = br - li*0.42 - li2*0.22

    # Slight equatorial warm tint
    warm = np.clip((0.5 - np.abs(v - 0.5)) * 2.5, 0, 1) * 0.03
    r_ch += warm

    return P(r_ch, g_ch, b_ch)

def gen_ice_cratered(u, v, s):
    """Generic heavily-cratered icy surface (Ganymede, Rhea, Tethys, Dione…)."""
    base = fbm(u, v, 7, bf=5, seed=s)
    fine = fbm(u, v, 9, bf=22, seed=s+4)
    micro = fbm(u, v, 7, bf=55, seed=s+9)
    gr   = ridged(u, v, 5, bf=14, seed=s+8)

    # Three crater scales: large basins, medium, small pits
    cr_l = craters(u, v, 25, 0.016, 0.075, s+2, ejecta=0.14)
    cr_m = craters(u, v, 80, 0.005, 0.018, s+3, ejecta=0.07)
    cr_s = craters(u, v, 220, 0.002, 0.006, s+4, ejecta=0.03)

    br = 0.38 + 0.20*base + 0.14*fine + 0.10*micro + gr*0.08
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.22 + br * 0.65

    return P(br+0.02, br, br+0.04)

def gen_ice_cratered_dark(u, v, s):
    """Callisto / Umbriel: dark dusty ice, saturated with craters."""
    base = fbm(u, v, 7, bf=5, seed=s)
    fine = fbm(u, v, 8, bf=18, seed=s+3)
    micro = fbm(u, v, 6, bf=48, seed=s+8)

    cr_l = craters(u, v, 40, 0.012, 0.07, s+2, ejecta=0.16)
    cr_m = craters(u, v, 110, 0.004, 0.015, s+3, ejecta=0.08)
    cr_s = craters(u, v, 280, 0.001, 0.005, s+4, ejecta=0.03)

    br = 0.12 + 0.15*base + 0.09*fine + 0.10*micro
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.04 + br * 0.32

    return P(br+0.03, br+0.01, br)

def gen_ice_smooth(u, v, s):
    """Enceladus: very bright young ice with tiger-stripe fractures at south pole."""
    base = fbm(u, v, 6, bf=4, seed=s)
    fine = fbm(u, v, 9, bf=30, seed=s+6)
    micro = fbm(u, v, 7, bf=60, seed=s+9)

    cr = craters(u, v, 12, 0.002, 0.015, s+2, ejecta=0.04)

    br = 0.72 + 0.12*base + 0.09*fine + 0.04*micro + cr

    # Tiger stripes: 4-5 bold parallel dark fractures concentrated at south pole
    sp = np.clip((v - 0.55) * 6, 0, 1) ** 1.2
    stripes = lineae(u, v, 5, s+10, width_scale=4.5)
    br -= stripes * sp * 0.65

    # Subtle bluish-white tint; stripes have slight reddish tinge
    r_ch = br - stripes*sp*0.10 - 0.02
    g_ch = br - stripes*sp*0.05
    b_ch = br + 0.06

    return P(r_ch, g_ch, b_ch)

def gen_hazy_orange(u, v, s):
    """Titan: thick hazy orange atmosphere with subtle dune bands."""
    base = fbm(u, v, 6, bf=3, seed=s)
    wx   = fbm(u, v, 4, bf=2, seed=s+1) * 0.18
    sw   = fbm(u, v+wx, 6, bf=4, seed=s+2)
    fine = fbm(u, v, 7, bf=12, seed=s+6)
    bands = np.sin(v*10 + base*2.5) * 0.06
    dune  = np.clip((sw - 0.45)*4, 0, 1) * np.clip(1 - np.abs(v-0.5)*3, 0, 1)

    r = 0.52 + 0.20*base + 0.10*sw + bands - dune*0.15
    g = 0.32 + 0.13*base + 0.06*sw + bands*0.4 + fine*0.03
    b = 0.10 + 0.05*base + 0.02*sw
    return P(r, g, b)

def gen_spongy(u, v, s):
    """Hyperion: extremely porous/spongy surface with deep pits."""
    base = fbm(u, v, 7, bf=5, seed=s)
    fine = fbm(u, v, 9, bf=24, seed=s+3)

    cr_l = craters(u, v, 60, 0.006, 0.032, s+1, ejecta=0.04)
    cr_s = craters(u, v, 250, 0.001, 0.006, s+5, ejecta=0.02)

    br = 0.22 + 0.18*base + 0.12*fine + cr_l + cr_s
    br = autolevels(br)
    br = 0.08 + br * 0.42

    return P(br+0.04, br+0.02, br-0.02)

def gen_two_tone(u, v, s):
    """Iapetus: bright trailing hemisphere, pitch-dark leading hemisphere."""
    base = fbm(u, v, 7, bf=5, seed=s)
    fine = fbm(u, v, 8, bf=16, seed=s+4)
    bnd  = fbm(u, v, 4, bf=3, seed=s+7)

    cr_l = craters(u, v, 25, 0.012, 0.065, s+2, ejecta=0.12)
    cr_m = craters(u, v, 70, 0.004, 0.014, s+3, ejecta=0.07)
    cr_s = craters(u, v, 180, 0.001, 0.006, s+8, ejecta=0.03)

    dark_mask = np.clip(1.2 - np.abs(u - 0.5)*3.5 + bnd*0.35, 0, 1)**2
    bright_br = 0.55 + 0.20*base + 0.10*fine
    dark_br   = 0.04 + 0.06*base + 0.03*fine
    br = bright_br*(1-dark_mask) + dark_br*dark_mask
    br += cr_l + cr_m + cr_s

    r = np.clip(br + 0.04*(1-dark_mask), 0, 1)
    g = np.clip(br, 0, 1)
    b = np.clip(br - 0.01, 0, 1)
    return P(r, g, b)

def gen_ice_fractured(u, v, s):
    """Miranda: chaotic patchwork of old and young terrain with deep canyons."""
    base = fbm(u, v, 7, bf=6, seed=s)
    rg   = ridged(u, v, 6, bf=10, seed=s+3)
    fine = fbm(u, v, 8, bf=22, seed=s+6)
    micro = fbm(u, v, 6, bf=50, seed=s+9)

    cr = craters(u, v, 40, 0.003, 0.04, s+2, ejecta=0.08)
    li = lineae(u, v, 40, s+5, width_scale=2.0)

    # Corona regions: concentric ridged terrain
    rng = np.random.RandomState(s+15)
    corona = np.zeros_like(u)
    for _ in range(3):
        cx, cy = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
        du = np.abs(u-cx); du = np.minimum(du, 1-du)
        d = np.sqrt(du**2 + (v-cy)**2)
        corona += np.abs(np.sin(d*40)) * np.exp(-d*5) * 0.30

    br = 0.38 + 0.20*base + 0.20*rg + 0.08*fine + 0.04*micro + corona
    br += cr - li*0.28
    br = autolevels(br)
    br = 0.18 + br * 0.62

    return P(br, br+0.02, br+0.07)

def gen_ice_cantaloupe(u, v, s):
    """Triton: cantaloupe terrain with nitrogen frost cap."""
    base = fbm(u, v, 6, bf=5, seed=s)
    cell = ridged(u, v, 6, bf=12, seed=s+1)
    fine = fbm(u, v, 8, bf=20, seed=s+4)
    micro = fbm(u, v, 6, bf=48, seed=s+7)

    cr = craters(u, v, 20, 0.005, 0.04, s+2, ejecta=0.06)

    br = 0.42 + 0.20*base + 0.22*cell + 0.08*fine + 0.04*micro + cr
    br = autolevels(br)

    # Nitrogen frost cap toward one pole
    frost = np.clip((v - 0.50)*4, 0, 1)**2
    br_f  = br*(1-frost) + (0.76 + 0.10*fine)*frost

    r_ch = br_f + frost*0.14
    g_ch = br_f - frost*0.02
    b_ch = br_f + frost*0.08

    return P(r_ch*0.82, g_ch*0.88, b_ch)

def gen_rocky_irregular(u, v, s):
    """Small irregular rocky moonlets."""
    base = fbm(u, v, 8, bf=8, lac=2.2, seed=s)
    fine = fbm(u, v, 9, bf=30, seed=s+3)
    micro = fbm(u, v, 7, bf=65, seed=s+7)

    cr_l = craters(u, v, 20, 0.010, 0.055, s+1, ejecta=0.12)
    cr_m = craters(u, v, 60, 0.004, 0.013, s+2, ejecta=0.07)
    cr_s = craters(u, v, 200, 0.001, 0.005, s+5, ejecta=0.03)

    br = 0.18 + 0.18*base + 0.12*fine + 0.05*micro
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.08 + br * 0.34

    return P(br+0.04, br+0.02, br-0.01)

def gen_rocky_dark(u, v, s):
    base = fbm(u, v, 7, bf=6, seed=s)
    fine = fbm(u, v, 9, bf=22, seed=s+4)
    micro = fbm(u, v, 6, bf=50, seed=s+7)

    cr_l = craters(u, v, 25, 0.009, 0.055, s+2, ejecta=0.11)
    cr_m = craters(u, v, 75, 0.003, 0.011, s+3, ejecta=0.06)
    cr_s = craters(u, v, 220, 0.001, 0.004, s+6, ejecta=0.02)

    br = 0.10 + 0.14*base + 0.08*fine + 0.04*micro
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.03 + br * 0.24

    return P(br+0.03, br+0.01, br)

def gen_rocky_very_dark(u, v, s):
    base = fbm(u, v, 7, bf=6, seed=s)
    fine = fbm(u, v, 8, bf=18, seed=s+3)
    micro = fbm(u, v, 6, bf=46, seed=s+6)

    cr_l = craters(u, v, 10, 0.008, 0.042, s+2, ejecta=0.13)
    cr_m = craters(u, v, 40, 0.003, 0.010, s+3, ejecta=0.07)
    cr_s = craters(u, v, 160, 0.001, 0.004, s+6, ejecta=0.03)

    br = 0.04 + 0.07*base + 0.04*fine + 0.02*micro
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.01 + br * 0.13

    return P(br+0.02, br+0.01, br)

def gen_ice_bright_kbo(u, v, s):
    base = fbm(u, v, 6, bf=5, seed=s)
    fine = fbm(u, v, 8, bf=20, seed=s+4)
    micro = fbm(u, v, 6, bf=46, seed=s+6)

    cr_l = craters(u, v, 15, 0.009, 0.055, s+2, ejecta=0.13)
    cr_m = craters(u, v, 50, 0.003, 0.011, s+3, ejecta=0.08)
    cr_s = craters(u, v, 160, 0.001, 0.005, s+6, ejecta=0.04)

    br = 0.52 + 0.22*base + 0.10*fine + 0.05*micro
    br += cr_l + cr_m + cr_s
    br = autolevels(br)
    br = 0.32 + br * 0.56

    return P(br, br+0.02, br+0.07)

GENERATORS = {
    "volcanic":gen_volcanic, "ice_cracked":gen_ice_cracked,
    "ice_cratered":gen_ice_cratered, "ice_cratered_dark":gen_ice_cratered_dark,
    "ice_smooth":gen_ice_smooth, "hazy_orange":gen_hazy_orange,
    "spongy":gen_spongy, "two_tone":gen_two_tone,
    "ice_fractured":gen_ice_fractured, "ice_cantaloupe":gen_ice_cantaloupe,
    "rocky_irregular":gen_rocky_irregular, "rocky_dark":gen_rocky_dark,
    "rocky_very_dark":gen_rocky_very_dark, "ice_bright_kbo":gen_ice_bright_kbo,
}

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    already_have = {"moon"}
    targets = {k:v for k,v in MOON_SURFACE_TYPES.items() if k not in already_have}
    if len(sys.argv) > 1:
        targets = {k:v for k,v in targets.items() if k in sys.argv[1:]}
    print(f"Generating {len(targets)} moon textures at {WIDTH}x{HEIGHT}...")
    U, V = make_uv()
    for mid in sorted(targets.keys()):
        stype = targets[mid]; seed = hash(mid) & 0xFFFFFF
        print(f"  {mid} [{stype}]...", end=" ", flush=True)
        img = Image.fromarray(GENERATORS[stype](U, V, seed), "RGB")
        img.save(os.path.join(OUTPUT_DIR, f"2k_{mid}.png"), optimize=True)
        print("done.")
    print(f"\nDone! {len(targets)} textures in ./{OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
