#!/bin/bash
# One-time developer setup for Streamen. Installs the git hooks from lefthook.yml plus the
# lint/format tools — all vendored as SPM plugins in Package.swift, so only the Swift
# toolchain that ships with Xcode is required (no Homebrew/Mint). Safe to re-run.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"

# Always the main checkout, even when run from a worktree: every worktree shares
# its .git/hooks, and `lefthook install` hardcodes the path it ran from, so a
# worktree's install dangles (and the hooks fall back to slow paths) once that
# worktree is deleted.
cd "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"

# Lefthook gets its own build dir; the generated .git/hooks stub hardcodes this path.
# --disable-sandbox: installing hooks writes to .git/, which the plugin sandbox blocks.
swift package --build-path .build/lefthook --disable-sandbox lefthook install

# Lint/format tools use a separate build dir so they never contend with Lefthook's
# SPM lock while a hook runs. SwiftLint is a prebuilt binary; SwiftFormat builds from
# source once (~20s) and is cached — warm it now so the first commit isn't slow.
# Worktrees run these same binaries (Scripts/lint-tool.sh).
echo "Preparing SwiftFormat/SwiftLint (first run builds SwiftFormat once)…"
"$HERE/lint-tool.sh" swiftformat --version >/dev/null || true

echo "✅ Dev environment ready. Git hooks run automatically on commit."
