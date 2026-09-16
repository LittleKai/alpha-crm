#!/usr/bin/env python3
"""Verify documented CRM guard symbols still exist in tracked source."""

import glob
import os
import re
import sys


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_GLOBS = [
    "lib/**/*.dart",
    "test/**/*.dart",
    "integration/zalo-bot-service/src/**/*.ts",
    "integration/zalo-bot-service/test/**/*.ts",
]
BUGS = os.path.join(ROOT, ".claude", "IMPORTANT_FIXED_BUGS.md")
ARCHIVE = os.path.join(ROOT, ".claude", "archive", "FIXED_BUGS_guarded.md")


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def parse_rows(markdown):
    rows = []
    for line in markdown.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 4 or not cells[0].isdigit():
            continue
        guard = cells[2]
        level = "OK" if guard.startswith("✅") else "PART" if guard.startswith("🔶") else "NONE"
        rows.append((int(cells[0]), cells[1], level, guard))
    return rows


def guard_names(cell):
    names = []
    for literal in re.findall(r"`([^`]+)`", cell):
        for pattern in (
            r"::(\w+[!?]?)",
            r"\((\w+[!?]?)\)",
            r"\.(\w+[!?]?)\s*\(",
            r"^(\w+[!?]?)\s*\(",
            r"\.(\w+[!?]?)$",
        ):
            match = re.search(pattern, literal)
            if match:
                names.append(match.group(1))
                break
    return names


def main():
    markdown = read(BUGS)
    rows = parse_rows(markdown)
    if not rows:
        sys.exit("Khong tim thay Bang bay trong %s" % BUGS)

    files = []
    for pattern in SOURCE_GLOBS:
        files.extend(glob.glob(os.path.join(ROOT, pattern), recursive=True))
    if not files:
        sys.exit("SOURCE_GLOBS khong khop file nao")
    blob = "\n".join(read(path) for path in sorted(set(files)))

    missing = []
    for number, name, level, cell in rows:
        if level == "NONE":
            continue
        names = guard_names(cell)
        if not names:
            missing.append((number, name, "khong tach duoc symbol"))
            continue
        for symbol in names:
            if not re.search(r"\b%s(?!\w)" % re.escape(symbol), blob):
                missing.append((number, name, symbol))

    ok_count = sum(1 for row in rows if row[2] == "OK")
    archive_count = read(ARCHIVE).count("\n### ")
    if ok_count != archive_count:
        print("LECH: %d bay OK nhung archive co %d muc" % (ok_count, archive_count))
        return 1
    for number, name, symbol in missing:
        print("THIEU bay #%d %s -> %s" % (number, name, symbol))
    if missing:
        return 1
    print("OK: %d bay, %d file nguon, moi rao chan con ton tai" % (len(rows), len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
