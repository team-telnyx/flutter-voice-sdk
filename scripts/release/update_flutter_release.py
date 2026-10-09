#!/usr/bin/env python3
"""Release helpers for the Flutter Voice SDK telnyx_webrtc package."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
from dataclasses import dataclass
from pathlib import Path

SEMVER_RE = re.compile(
    r"^v?(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?P<prerelease>-[0-9A-Za-z.-]+)?(?P<build>\+[0-9A-Za-z.-]+)?$"
)
PACKAGE = Path("packages/telnyx_webrtc")


@dataclass(frozen=True)
class Version:
    raw: str
    major: int
    minor: int
    patch: int
    prerelease: str
    build: str

    @property
    def normalized(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}{self.prerelease}{self.build}"

    @property
    def tag(self) -> str:
        return f"v{self.normalized}"

    @property
    def is_prerelease(self) -> bool:
        return bool(self.prerelease)

    @property
    def sort_key(self) -> tuple:
        # Stable releases sort after prereleases for the same major/minor/patch.
        pre_key: tuple[int, tuple] = (1, ()) if not self.prerelease else (0, _prerelease_key(self.prerelease[1:]))
        return (self.major, self.minor, self.patch, pre_key, self.build)


def _prerelease_key(value: str) -> tuple:
    parts = []
    for part in value.split("."):
        if part.isdigit():
            parts.append((0, int(part)))
        else:
            parts.append((1, part))
    return tuple(parts)


def parse_version(value: str) -> Version:
    match = SEMVER_RE.match(value.strip())
    if not match:
        raise SystemExit(f"Invalid version: {value!r}; expected semver like 4.5.0 or 4.5.0-beta.1")
    return Version(
        raw=value,
        major=int(match.group("major")),
        minor=int(match.group("minor")),
        patch=int(match.group("patch")),
        prerelease=match.group("prerelease") or "",
        build=match.group("build") or "",
    )


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Expected exactly one {label} match, found {count}")
    return new_text


def package_root(root: Path) -> Path:
    return root / PACKAGE


def read_pubspec_version(root: Path) -> str:
    text = (package_root(root) / "pubspec.yaml").read_text()
    match = re.search(r"^version:\s*(\S+)\s*$", text, flags=re.MULTILINE)
    if not match:
        raise SystemExit("Could not find pubspec.yaml version")
    return parse_version(match.group(1)).normalized


def read_version_utils_version(root: Path) -> str:
    text = (package_root(root) / "lib/utils/version_utils.dart").read_text()
    match = re.search(r"static const String _sdkVersion = '([^']+)';", text)
    if not match:
        raise SystemExit("Could not find VersionUtils._sdkVersion")
    return parse_version(match.group(1)).normalized


def changelog_has_version(root: Path, version: str) -> bool:
    text = (package_root(root) / "CHANGELOG.md").read_text()
    return re.search(rf"^## \[{re.escape(version)}\]", text, flags=re.MULTILINE) is not None


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
    body = changelog_body.strip() or "### Enhancement\n- Release maintenance update."
    section = f"{heading}\n{body}\n\n"

    text = path.read_text()
    existing = re.search(rf"^## \[{re.escape(version)}\].*?(?=^## \[|\Z)", text, flags=re.MULTILINE | re.DOTALL)
    if existing:
        text = text[: existing.start()] + section + text[existing.end():].lstrip("\n")
    else:
        text = section + text.lstrip("\n")
    path.write_text(text)


def classify_pr(title: str, labels: str) -> str:
    haystack = f"{title} {labels}".lower()
    if "breaking" in haystack:
        return "Breaking"
    if any(token in haystack for token in ("bug", "fix", "hotfix", "patch")):
        return "Bug Fixing"
    return "Enhancement"


def format_changelog(pr_data: Path, previous_tag: str, output: Path, extra_notes: str = "") -> None:
    sections: dict[str, list[str]] = {"Breaking": [], "Bug Fixing": [], "Enhancement": []}
    seen: set[str] = set()
    if pr_data.exists():
        for raw in pr_data.read_text().splitlines():
            if not raw.strip():
                continue
            number, title, labels = (raw.split("\t") + ["", "", ""])[:3]
            if number in seen:
                continue
            seen.add(number)
            bucket = classify_pr(title, labels)
            sections.setdefault(bucket, []).append(f"- PR #{number}: {title}")

    lines: list[str] = []
    if extra_notes.strip():
        lines.extend([extra_notes.strip(), ""])
    for heading in ("Breaking", "Bug Fixing", "Enhancement"):
        items = sections.get(heading) or []
        if items:
            lines.append(f"### {heading}")
            lines.extend(items)
            lines.append("")
    if not any(sections.values()):
        lines.extend(["### Enhancement", f"- Release changes since {previous_tag or 'repository start'}.", ""])
    output.write_text("\n".join(lines).rstrip() + "\n")


def extract_changelog_section(root: Path, version: str, output: Path) -> None:
    changelog = (package_root(root) / "CHANGELOG.md").read_text()
    heading = f"## [{version}]"
    start = changelog.find(heading)
    if start == -1:
        raise SystemExit(f"Missing changelog section for {version}")
    next_start = changelog.find("\n## [", start + 1)
    section = changelog[start: next_start if next_start != -1 else len(changelog)].strip()
    output.write_text(section + "\n")


def previous_tag(version: Version, tags_file: Path) -> str:
    candidates: list[tuple[Version, str]] = []
    current_key = version.sort_key
    for raw in tags_file.read_text().splitlines():
        try:
            parsed = parse_version(raw)
        except SystemExit:
            continue
        # For stable releases, ignore prerelease tags so v4.5.0-beta.1 does not become
        # the baseline for v4.5.0 or v4.6.0 changelogs.
        if not version.is_prerelease and parsed.is_prerelease:
            continue
        if parsed.sort_key < current_key:
            candidates.append((parsed, raw.strip()))
    if not candidates:
        return ""
    return max(candidates, key=lambda item: item[0].sort_key)[1]


def write_github_output(path: str | None, pairs: dict[str, str]) -> None:
    if not path:
        for key, value in pairs.items():
            print(f"{key}={value}")
        return
    with open(path, "a", encoding="utf-8") as handle:
        for key, value in pairs.items():
            handle.write(f"{key}={value}\n")


def cmd_normalize(args: argparse.Namespace) -> None:
    version = parse_version(args.version)
    write_github_output(args.github_output, {
        "version": version.normalized,
        "tag": version.tag,
        "is_prerelease": str(version.is_prerelease).lower(),
    })


def cmd_previous_tag(args: argparse.Namespace) -> None:
    print(previous_tag(parse_version(args.version), args.tags_file))


def cmd_format_changelog(args: argparse.Namespace) -> None:
    format_changelog(args.pr_data, args.previous_tag, args.output, os.environ.get(args.extra_notes_env, ""))


def cmd_update(args: argparse.Namespace) -> None:
    version = parse_version(args.version).normalized
    pkg = package_root(args.root)
    changelog_body = args.changelog.read_text()
    update_pubspec(pkg / "pubspec.yaml", version)
    update_version_utils(pkg / "lib/utils/version_utils.dart", version)
    update_changelog(pkg / "CHANGELOG.md", version, changelog_body)


def cmd_validate(args: argparse.Namespace) -> None:
    version = parse_version(args.version).normalized
    pubspec_version = read_pubspec_version(args.root)
    utils_version = read_version_utils_version(args.root)
    if pubspec_version != version:
        raise SystemExit(f"pubspec.yaml version is {pubspec_version} but workflow input is {version}")
    if utils_version != version:
        raise SystemExit(f"version_utils.dart version is {utils_version} but workflow input is {version}")
    if not changelog_has_version(args.root, version):
        raise SystemExit(f"CHANGELOG.md does not contain a top-level section for {version}")


def cmd_release_notes(args: argparse.Namespace) -> None:
    version = parse_version(args.version).normalized
    extract_changelog_section(args.root, version, args.output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    normalize = sub.add_parser("normalize")
    normalize.add_argument("--version", required=True)
    normalize.add_argument("--github-output")
    normalize.set_defaults(func=cmd_normalize)

    prev = sub.add_parser("previous-tag")
    prev.add_argument("--version", required=True)
    prev.add_argument("--tags-file", required=True, type=Path)
    prev.set_defaults(func=cmd_previous_tag)

    fmt = sub.add_parser("format-changelog")
    fmt.add_argument("--pr-data", required=True, type=Path)
    fmt.add_argument("--previous-tag", default="")
    fmt.add_argument("--output", required=True, type=Path)
    fmt.add_argument("--extra-notes-env", default="EXTRA_NOTES")
    fmt.set_defaults(func=cmd_format_changelog)

    update = sub.add_parser("update")
    update.add_argument("--version", required=True)
    update.add_argument("--changelog", required=True, type=Path)
    update.add_argument("--root", type=Path, default=Path.cwd())
    update.set_defaults(func=cmd_update)

    validate = sub.add_parser("validate")
    validate.add_argument("--version", required=True)
    validate.add_argument("--root", type=Path, default=Path.cwd())
    validate.set_defaults(func=cmd_validate)

    notes = sub.add_parser("release-notes")
    notes.add_argument("--version", required=True)
    notes.add_argument("--output", required=True, type=Path)
    notes.add_argument("--root", type=Path, default=Path.cwd())
    notes.set_defaults(func=cmd_release_notes)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
