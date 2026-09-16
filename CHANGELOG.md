# Changelog

## 0.1.3 — 2026-09-16

- Anchor every onboarding page at the top of its container instead of stretching it vertically.
- Replace `NSBox` cards with content-fitting card views so multi-line rows receive their real height.
- Keep the onboarding panel at a stable preferred width across all four steps.
- Add debug-only onboarding snapshots for visual regression checks of every step.

## 0.1.2 — 2026-09-16

- Keep every onboarding label within its card by applying explicit width constraints.
- Allow long Korean and English descriptions to wrap instead of preserving an oversized intrinsic width.
- Make requirement, account, and project cards consistently fill the available content width.

## 0.1.1 — 2026-09-16

- Show the selected project's GitHub account in the macOS menu bar.
- Add a menu-bar project picker, refresh action, settings shortcut, and window restore action.
- Add a **Launch at Login** checkbox backed by macOS `SMAppService`.
- Fix the main window collapsing to a one-pixel height after launch.
- Keep the menu-bar app available when its main window is closed.

## 0.1.0 — 2026-09-16

- Add native macOS onboarding and project registration.
- Detect GitHub accounts through GitHub CLI without reading access tokens.
- Route each repository through a dedicated SSH key and host alias.
- Preserve and restore each repository's original `origin`.
- Add GitHub device-login guidance and account refresh.
- Bundle the `git-account-status` command-line helper.
- Ship an Apple Silicon DMG for macOS 14 or newer.
