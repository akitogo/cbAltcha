#!/usr/bin/env bash
# Replace the bundled ALTCHA widget with another version from npm.
#   .github/scripts/update-widget.sh 3.7.0
# Updates includes/altcha.min.js, includes/i18n/<lang>.js (every language already shipped),
# includes/LICENSE.txt, box.json "altchaWidget" and changelog.md ("Unreleased").
set -euo pipefail

version="${1:?usage: update-widget.sh <version>}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
current="$(jq -r .altchaWidget "$root/box.json")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# npm pack downloads the published tarball and checks it against the registry's integrity hash
(cd "$tmp" && npm pack "altcha@${version}" --silent >/dev/null && tar -xzf "altcha-${version}.tgz")
pkg="$tmp/package"

[ -f "$pkg/dist/main/altcha.min.js" ] || { echo "altcha@${version}: dist/main/altcha.min.js missing, layout changed" >&2; exit 1; }
# the licence file is LICENSE or LICENSE.txt depending on the release
license="$(find "$pkg" -maxdepth 1 -type f -iname 'license*' | head -1)"
[ -n "$license" ] || { echo "altcha@${version}: no LICENSE file" >&2; exit 1; }

cp "$pkg/dist/main/altcha.min.js" "$root/includes/altcha.min.js"
cp "$license" "$root/includes/LICENSE.txt"
for existing in "$root"/includes/i18n/*.js; do
  lang="$(basename "$existing")"
  [ -f "$pkg/dist/i18n/$lang" ] || { echo "altcha@${version}: dist/i18n/$lang missing" >&2; exit 1; }
  cp "$pkg/dist/i18n/$lang" "$existing"
done

jq --indent 4 --arg v "$version" '.altchaWidget = $v' "$root/box.json" > "$tmp/box.json"
mv "$tmp/box.json" "$root/box.json"

if [ "$current" != "$version" ]; then
  python3 - "$root/changelog.md" "$current" "$version" <<'PY'
import sys
path, old, new = sys.argv[1:]
entry = f"- ALTCHA widget {old} → {new} (https://github.com/altcha-org/altcha/releases/tag/v{new})"
s = open(path, encoding="utf-8").read()
head = "# Changelog\n\n"
if "## Unreleased\n" in s:
    s = s.replace("## Unreleased\n\n", f"## Unreleased\n\n{entry}\n", 1)
else:
    s = s.replace(head, f"{head}## Unreleased\n\n{entry}\n\n", 1)
open(path, "w", encoding="utf-8").write(s)
PY
fi

echo "ALTCHA widget ${current} -> ${version}"
