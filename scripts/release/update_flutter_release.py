#!/usr/bin/env python3
"""Update Flutter Voice SDK release files for telnyx_webrtc."""

from __future__ import annotations

import argparse
import datetime as dt
import re
from pathlib import Path

SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[+-][0-9A-Za-z.-]+)?$")


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Expected exactly one {label} match, found {count}")
    return new_text


def update_pubspec(path: Path, version: str) -> None:
    text = path.read_text()
    text = replace_once(text, r"^version:\s*.+$", f"version: {version}", "pubspec version")
    path.write_text(text)


def update_version_utils(path: Path, version: str) -> None:
    text = path.read_text()
    text = replace_once(
        text,
        r"static const String _sdkVersion = '[^']+';",
        f"static const String _sdkVersion = '{version}';",
        "VersionUtils SDK version",
    )
    path.write_text(text)


def update_changelog(path: Path, version: str, changelog_body: str) -> None:
    today = dt.date.today().isoformat()
    heading = f"## [{version}](https://pub.dev/packages/telnyx_webrtc/versions/{version}) ({today})"
    body = changelog_body.strip() or f"- Release telnyx_webrtc {version}."
    section = f"{heading}\n{body}\n\n"

    text = path.read_text()
    existing = re.search(rf"^## \[{re.escape(version)}\].*?(?=^## \[|\Z)", text, flags=re.MULTILINE | re.DOTALL)
    if existing:
        text = text[: existing.start()] + section + text[existing.end():].lstrip("\n")
    else:
        text = section + text.lstrip("\n")
    path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Release version, for example 4.5.0")
    parser.add_argument("--changelog", required=True, type=Path, help="Markdown changelog body to insert")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Repository root")
    args = parser.parse_args()

    version = args.version.removeprefix("v")
    if not SEMVER_RE.match(version):
        raise SystemExit(f"Invalid version: {args.version}")

    root = args.root
    package = root / "packages" / "telnyx_webrtc"
    changelog_body = args.changelog.read_text()

    update_pubspec(package / "pubspec.yaml", version)
    update_version_utils(package / "lib" / "utils" / "version_utils.dart", version)
    update_changelog(package / "CHANGELOG.md", version, changelog_body)


if __name__ == "__main__":
    main()
