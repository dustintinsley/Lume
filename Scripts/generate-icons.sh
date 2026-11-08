#!/bin/bash
# Re-renders every app icon asset (iOS, macOS, tvOS) from the vector logo in
# Scripts/icons/. Writes straight into Streamen/Assets.xcassets and
# Streamen/Streamen.icon, and leaves review previews (the Top Shelf banner and
# the tvOS icon) in a temp folder it prints at the end.
#
# The repo lives in iCloud Drive, which turns delete-and-rewrite into
# "name 2.png" conflict copies; those are removed afterwards.
#
# Usage: Scripts/generate-icons.sh
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1
work="$(mktemp -d -t streamen-icons)"

swiftc -O Scripts/icons/Logo.swift Scripts/icons/main.swift -o "$work/generate"
"$work/generate" "$root/Streamen/Assets.xcassets" "$root/Streamen/Streamen.icon" "$work"

sleep 2
find Streamen/Assets.xcassets Streamen/Streamen.icon -name "* [0-9].*" -delete
echo "Previews: $work"
