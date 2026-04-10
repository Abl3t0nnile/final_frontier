#!/usr/bin/env python3
"""
resize_textures.py
Prüft alle Bilddateien in assets/textures/**/raw/ auf 2048x1024.
Dateien mit falscher Größe werden mit Lanczos-Interpolation skaliert
und überschrieben (Original wird als *.bak gesichert).

Verwendung:
  python3 tools/resize_textures.py           # Dry-run (nur Bericht)
  python3 tools/resize_textures.py --fix     # Tatsächlich skalieren
  python3 tools/resize_textures.py --fix --no-backup  # ohne Backup
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow nicht installiert. Bitte: pip install Pillow")
    sys.exit(1)

TARGET_W, TARGET_H = 2048, 1024
EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}

REPO_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_ROOT = REPO_ROOT / "assets" / "textures"


def check_and_resize(path: Path, fix: bool, backup: bool) -> tuple[str, str]:
    """Gibt (status, info) zurück."""
    try:
        with Image.open(path) as img:
            w, h = img.size
            if (w, h) == (TARGET_W, TARGET_H):
                return "ok", f"{w}x{h}"

            info = f"{w}x{h} → {TARGET_W}x{TARGET_H}"
            if not fix:
                return "wrong", info

            # Backup
            if backup:
                bak = path.with_suffix(path.suffix + ".bak")
                bak.write_bytes(path.read_bytes())

            # Skalieren (LANCZOS = höchste Qualität)
            resized = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)

            # Format beibehalten; JPEGs mit guter Qualität speichern
            fmt = img.format or ("JPEG" if path.suffix.lower() in {".jpg", ".jpeg"} else "PNG")
            save_kwargs: dict = {}
            if fmt == "JPEG":
                save_kwargs["quality"] = 95
                save_kwargs["subsampling"] = 0
            resized.save(path, format=fmt, **save_kwargs)
            return "fixed", info

    except Exception as e:
        return "error", str(e)


def main():
    parser = argparse.ArgumentParser(description="Texture-Größen prüfen und korrigieren")
    parser.add_argument("--fix", action="store_true", help="Dateien tatsächlich skalieren")
    parser.add_argument("--no-backup", action="store_true", help="Kein .bak-Backup anlegen")
    args = parser.parse_args()

    files = sorted(
        p for p in TEXTURE_ROOT.rglob("*")
        if p.is_file() and p.suffix.lower() in EXTENSIONS
        and not p.suffix.endswith(".bak")
    )

    if not files:
        print(f"Keine Bilddateien gefunden unter {TEXTURE_ROOT}")
        sys.exit(0)

    counts = {"ok": 0, "wrong": 0, "fixed": 0, "error": 0}

    print(f"Ziel-Auflösung: {TARGET_W}x{TARGET_H}")
    print(f"Modus: {'SKALIEREN' if args.fix else 'DRY-RUN (--fix fehlt)'}")
    print(f"{'Status':<8} {'Auflösung':<24} Datei")
    print("-" * 70)

    for path in files:
        status, info = check_and_resize(path, fix=args.fix, backup=not args.no_backup)
        counts[status] += 1
        rel = path.relative_to(REPO_ROOT)
        icon = {"ok": "✓", "wrong": "✗", "fixed": "→", "error": "!"}.get(status, "?")
        print(f"{icon} {status:<7} {info:<24} {rel}")

    print("-" * 70)
    print(f"Gesamt: {len(files)} Dateien — "
          f"{counts['ok']} OK, "
          f"{counts['wrong']} falsch (nicht geändert), "
          f"{counts['fixed']} skaliert, "
          f"{counts['error']} Fehler")

    if counts["wrong"] and not args.fix:
        print("\nHinweis: Mit --fix werden die obigen Dateien automatisch skaliert.")


if __name__ == "__main__":
    main()
