#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/scripts/package-release.sh"
README="$ROOT_DIR/README.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  grep -Eq "$pattern" "$path" || fail "$path does not contain pattern: $pattern"
}

assert_file "$RELEASE_SCRIPT"
assert_file "$README"

assert_contains "$RELEASE_SCRIPT" 'CONFIGURATION=release'
assert_contains "$RELEASE_SCRIPT" 'scripts/build-app\.sh'
assert_contains "$RELEASE_SCRIPT" 'hdiutil create'
assert_contains "$RELEASE_SCRIPT" '/Applications'
assert_contains "$RELEASE_SCRIPT" 'release-notes\.md'

assert_contains "$README" 'GitHub Releases'
assert_contains "$README" 'CodexQuotaMenubar.*\.dmg'
assert_contains "$README" 'Applications'
assert_contains "$README" 'gh release create'
assert_contains "$README" 'Release automation can be added later'

echo "PASS release packaging contract"
