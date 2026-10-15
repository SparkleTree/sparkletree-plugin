#!/bin/sh
# Maintainer check for scripts/ci-check-bump.sh: copies this checkout into a
# scratch git repository, commits it as the base, then makes one change at a
# time and checks whether the bump check passes or fails.
# Usage: sh scripts/test-ci-check-bump.sh. Needs git, tar and jq.
set -u
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
mkdir "$tmp/r"
git ls-files -co --exclude-standard | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done | tar -cf - -T - | tar -xf - -C "$tmp/r"
cd "$tmp/r"
git init -q . && git add -A && git -c user.name=test -c user.email=test@example.invalid commit -qm base || { echo "FAIL could not make the scratch repository"; exit 1; }
base=$(git rev-parse HEAD)
v=$(jq -r .version .claude-plugin/plugin.json)
next=$(echo "$v" | awk -F. '{ print $1 "." $2 "." $3 + 1 }')

# edit FILE SED-SCRIPT: change a file in place.
edit() { sed "$2" "$1" > "$1.t" && mv "$1.t" "$1"; }
case_() { # name expected(pass|fail) commands...
  name=$1; want=$2; shift 2
  git checkout -q -- . && git clean -qfd
  "$@" >/dev/null 2>&1 || { echo "FAIL $name: setup failed"; fail=1; return; }
  if CI_COMMIT_BRANCH='' CI_COMMIT_BEFORE_SHA='' sh scripts/ci-check-bump.sh "$base" >"$tmp/out" 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then echo "ok   $name -> $got"; else echo "FAIL $name: expected $want, got $got"; sed 's/^/     /' "$tmp/out"; fail=1; fi
}
gemini_url() { edit gemini-extension.json 's#api/mcp"#api/mcp/other"#'; }
both() { gemini_url && sh scripts/bump-version.sh plugin "$next"; }

case_ "nothing changed" pass true
case_ "gemini connection changed without a bump" fail gemini_url
case_ ".mcp.json changed without a bump" fail edit .mcp.json 's#api/mcp"#api/mcp/other"#'
case_ "codex manifest changed without a bump" fail edit .codex-plugin/plugin.json 's#"Productivity"#"Business"#'
case_ "claude manifest changed without a bump" fail edit .claude-plugin/plugin.json 's#"signage"#"screens"#'
case_ "marketplace changed without a bump" fail edit .claude-plugin/marketplace.json 's#"marketing"#"business"#'
case_ "a skill changed without a bump" fail edit skills/status/SKILL.md '$s/$/ /'
case_ "only gemini's version changed" pass edit gemini-extension.json "s#\"version\": \"$v\"#\"version\": \"$next\"#"
case_ "the bump itself" pass sh scripts/bump-version.sh plugin "$next"
case_ "gemini connection changed with a bump" pass both
case_ "maintainer tooling changed" pass edit scripts/ci-validate.sh '$s/$/ /'
exit $fail
