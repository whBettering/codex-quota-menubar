# CodexQuotaMenubar

macOS menu bar utility for checking remaining Codex quota.

## Install From GitHub Releases

1. Open the repository's GitHub Releases page.
2. Download `CodexQuotaMenubar-<version>.dmg`.
3. Open the DMG and drag `CodexQuotaMenubar.app` to Applications.
4. Launch `CodexQuotaMenubar` from Spotlight or Applications.

The current release build is unsigned. If macOS blocks the first launch, right-click the app in Applications, choose Open, then confirm once. Later launches should work normally.

## Run From Source

```bash
swift run CodexQuotaMenubar
```

## Build App Bundle

```bash
./scripts/build-app.sh
```

The app bundle is written to `dist/CodexQuotaMenubar.app`.

## Build Release DMG

```bash
./scripts/package-release.sh
```

The release DMG is written to `dist/release/CodexQuotaMenubar-0.1.0.dmg`.

## Publish A GitHub Release

Build the DMG locally and upload it to a GitHub Release:

```bash
VERSION=0.1.0 ./scripts/package-release.sh
gh release create v0.1.0 dist/release/CodexQuotaMenubar-0.1.0.dmg \
  --title "CodexQuotaMenubar v0.1.0" \
  --notes-file dist/release/release-notes.md \
  --target main
```

Release automation can be added later once the publishing token has permission to update GitHub Actions workflow files.

## Verify

```bash
swift run CodexQuotaCoreTests
swift build
bash scripts/test-release-contract.sh
./scripts/package-release.sh
```
