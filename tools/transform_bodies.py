"""
Transforms body .toml description blocks:
- Removes standalone bold name at start
- Removes [b]Physikalische Eigenschaften[/b] heading
- Moves Etymologie + Entdeckung blocks to after physics text
"""
import re
from pathlib import Path

bodies_dir = Path(__file__).parent.parent / "data/almanach/source/bodies"


def transform_file(path):
    content = path.read_text(encoding="utf-8")

    desc_match = re.search(r'(description = """\\)\n(.*?)\n(""")', content, re.DOTALL)
    if not desc_match:
        return False, "no description block found"

    desc_body = desc_match.group(2)
    lines = desc_body.split("\n")

    etym_idx = None
    entd_idx = None
    phys_idx = None

    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "[b]Etymologie[/b]":
            etym_idx = i
        elif stripped == "[b]Entdeckung[/b]":
            entd_idx = i
        elif stripped == "[b]Physikalische Eigenschaften[/b]":
            phys_idx = i

    if phys_idx is None:
        return False, "no Physikalische Eigenschaften section — already transformed or different structure"

    # First line must be standalone bold name
    if not (lines[0].startswith("[b]") and lines[0].endswith("[/b]") and (len(lines) < 2 or lines[1] == "")):
        return False, f"unexpected start: {lines[0]!r}"

    # Physics text: everything after the heading
    phys_lines = lines[phys_idx + 1 :]
    while phys_lines and phys_lines[-1] == "":
        phys_lines.pop()

    # Etymologie block
    etym_block = None
    if etym_idx is not None:
        end = (entd_idx - 1) if entd_idx is not None else (phys_idx - 1)
        etym_lines = lines[etym_idx:end]
        while etym_lines and etym_lines[-1] == "":
            etym_lines.pop()
        etym_block = "\n".join(etym_lines)

    # Entdeckung block
    entd_block = None
    if entd_idx is not None:
        entd_lines = lines[entd_idx : phys_idx - 1]
        while entd_lines and entd_lines[-1] == "":
            entd_lines.pop()
        entd_block = "\n".join(entd_lines)

    # Assemble new description body
    parts = ["\n".join(phys_lines)]
    if etym_block:
        parts.append(etym_block)
    if entd_block:
        parts.append(entd_block)

    new_body = "\n\n".join(parts)

    new_content = content[: desc_match.start(2)] + new_body + content[desc_match.end(2) :]
    path.write_text(new_content, encoding="utf-8")
    return True, "transformed"


if __name__ == "__main__":
    ok = []
    skipped = []
    errors = []

    for toml_file in sorted(bodies_dir.glob("*.toml")):
        success, msg = transform_file(toml_file)
        if success:
            ok.append(toml_file.name)
        elif "already transformed" in msg or "no description" in msg:
            skipped.append((toml_file.name, msg))
        else:
            errors.append((toml_file.name, msg))

    print(f"\n✓ Transformed ({len(ok)}):")
    for name in ok:
        print(f"  {name}")

    if skipped:
        print(f"\n~ Skipped ({len(skipped)}):")
        for name, msg in skipped:
            print(f"  {name}: {msg}")

    if errors:
        print(f"\n✗ Errors ({len(errors)}):")
        for name, msg in errors:
            print(f"  {name}: {msg}")
