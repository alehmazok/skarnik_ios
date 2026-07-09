---
name: bump-version
description: Bumps the app's MARKETING_VERSION (semver) and CURRENT_PROJECT_VERSION (build number) in Skarnik.xcodeproj/project.pbxproj, keeping the Skarnik app target and WordWidgetExtension target in sync. Use when asked to bump/increment the app version, release version, or build number.
---

# Bump app version

Skarnik and its widget extension (`WordWidgetExtension`) must always ship with the
**same** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. `SkarnikTests` has its own
independent version (currently `1.0`/`1`) — never touch it.

## Steps

1. Read current values:
   ```bash
   grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" Skarnik.xcodeproj/project.pbxproj
   ```
   Confirm which config blocks belong to `Skarnik` and `WordWidgetExtension` (not
   `SkarnikTests`) by checking the `XCConfigurationList` section maps build-config IDs to
   `PBXNativeTarget` names — don't assume line order.

2. Decide the bump kind: `patch` (default, e.g. `3.2.1` → `3.2.2`), `minor`
   (`3.2.1` → `3.3.0`), or `major` (`3.2.1` → `4.0.0`). `CURRENT_PROJECT_VERSION`
   (build number) always increments by exactly 1, regardless of which component bumped.

3. Run the bundled script — either a component keyword or an explicit version:
   ```bash
   python3 .claude/skills/bump-version/bump_version.py patch     # or minor / major
   python3 .claude/skills/bump-version/bump_version.py 3.2.2     # explicit version
   ```

4. Verify both targets updated together:
   ```bash
   grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" Skarnik.xcodeproj/project.pbxproj
   ```
   `SkarnikTests` block (`1.0` / `1`) must be unchanged.

5. Report old → new version/build to the user. Do not commit unless asked.
