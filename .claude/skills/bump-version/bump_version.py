#!/usr/bin/env python3
"""Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION for the Skarnik app and
WordWidgetExtension targets in project.pbxproj, keeping them in sync.

Usage: bump_version.py <major|minor|patch|X.Y.Z>
Examples:
  bump_version.py patch   # 3.2.1 -> 3.2.2
  bump_version.py minor   # 3.2.1 -> 3.3.0
  bump_version.py major   # 3.2.1 -> 4.0.0
  bump_version.py 3.2.2   # explicit version
"""
import re
import sys

TARGET_NAMES = ("Skarnik", "WordWidgetExtension")
PBXPROJ_PATH = "Skarnik.xcodeproj/project.pbxproj"
COMPONENTS = ("major", "minor", "patch")


def find_target_config_ids(content: str) -> list[str]:
    """Return build-config IDs (Debug + Release) belonging to TARGET_NAMES,
    by resolving each target's XCConfigurationList entry."""
    config_ids: list[str] = []
    for target_name in TARGET_NAMES:
        list_match = re.search(
            rf'/\* Build configuration list for PBXNativeTarget "{re.escape(target_name)}" \*/ = \{{'
            r'.*?buildConfigurations = \((.*?)\);',
            content,
            re.DOTALL,
        )
        if not list_match:
            raise SystemExit(f"Could not find configuration list for target {target_name!r}")
        ids = re.findall(r"([0-9A-F]{24}) /\* (?:Debug|Release) \*/", list_match.group(1))
        if len(ids) != 2:
            raise SystemExit(f"Expected 2 configs (Debug/Release) for {target_name!r}, found {len(ids)}")
        config_ids.extend(ids)
    return config_ids


def current_marketing_version(content: str, config_ids: list[str]) -> str:
    match = re.search(
        rf"{config_ids[0]} /\* (?:Debug|Release) \*/ = \{{.*?MARKETING_VERSION = ([\d.]+);",
        content,
        re.DOTALL,
    )
    if not match:
        raise SystemExit(f"No MARKETING_VERSION in config {config_ids[0]}")
    return match.group(1)


def next_version(current: str, component: str) -> str:
    parts = current.split(".")
    if len(parts) != 3:
        raise SystemExit(f"Expected semver like 3.2.1, got {current!r}")
    major, minor, patch = (int(p) for p in parts)
    if component == "major":
        major, minor, patch = major + 1, 0, 0
    elif component == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    return f"{major}.{minor}.{patch}"


def bump(content: str, config_ids: list[str], new_marketing_version: str) -> str:
    for config_id in config_ids:
        pattern = re.compile(
            rf"({config_id} /\* (?:Debug|Release) \*/ = \{{.*?buildSettings = \{{)(.*?)(\n\t{{3}}\}};)",
            re.DOTALL,
        )
        match = pattern.search(content)
        if not match:
            raise SystemExit(f"Could not find buildSettings block for config {config_id}")

        settings = match.group(2)

        build_match = re.search(r"CURRENT_PROJECT_VERSION = (\d+);", settings)
        if not build_match:
            raise SystemExit(f"No CURRENT_PROJECT_VERSION in config {config_id}")
        new_build = str(int(build_match.group(1)) + 1)
        settings = re.sub(
            r"CURRENT_PROJECT_VERSION = \d+;",
            f"CURRENT_PROJECT_VERSION = {new_build};",
            settings,
        )

        if not re.search(r"MARKETING_VERSION = [\d.]+;", settings):
            raise SystemExit(f"No MARKETING_VERSION in config {config_id}")
        settings = re.sub(
            r"MARKETING_VERSION = [\d.]+;",
            f"MARKETING_VERSION = {new_marketing_version};",
            settings,
        )

        content = content[: match.start(2)] + settings + content[match.end(2):]
    return content


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    arg = sys.argv[1]

    with open(PBXPROJ_PATH, encoding="utf-8") as f:
        content = f.read()

    config_ids = find_target_config_ids(content)

    if arg in COMPONENTS:
        old_version = current_marketing_version(content, config_ids)
        new_marketing_version = next_version(old_version, arg)
    elif re.fullmatch(r"\d+\.\d+\.\d+", arg):
        new_marketing_version = arg
    else:
        raise SystemExit(f"Expected one of {COMPONENTS} or a semver like 3.2.2, got {arg!r}")

    content = bump(content, config_ids, new_marketing_version)

    with open(PBXPROJ_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Bumped {', '.join(TARGET_NAMES)} to MARKETING_VERSION={new_marketing_version}, "
          f"CURRENT_PROJECT_VERSION incremented by 1 ({len(config_ids)} configs updated).")


if __name__ == "__main__":
    main()
