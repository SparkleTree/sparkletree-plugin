#!/bin/sh
# Did the version move when it had to, and never backwards? Runs in CI after
# ci-validate.sh; locally: sh scripts/ci-check-bump.sh [base]  (default origin/main,
# compared against the working tree). Needs git and jq.
#
# Fails when files a plugin user can notice changed without a plugin bump, or
# when the plugin or server.json version is lower than at the base. Skips with
# a note when the base commit cannot be fetched.
set -eu
cd "$(dirname "$0")/.."
fail() { echo "FAIL: $*" >&2; exit 1; }

base=${1:-}
if [ -z "$base" ]; then
  if [ -n "${CI_COMMIT_BEFORE_SHA:-}" ] && [ "$CI_COMMIT_BEFORE_SHA" != "0000000000000000000000000000000000000000" ]; then
    base=$CI_COMMIT_BEFORE_SHA          # previous tip of this branch
  else
    base=origin/main                    # first push of a new branch, or local
  fi
fi
reachable() { git rev-parse --verify -q "$1^{commit}" >/dev/null 2>&1; }
if ! reachable "$base"; then
  case "$base" in
    origin/*) git fetch -q --depth=50 origin "+refs/heads/${base#origin/}:refs/remotes/$base" 2>/dev/null || true ;;
    *) git fetch -q --depth=50 origin "$base" 2>/dev/null || true ;;
  esac
fi
reachable "$base" || { echo "skip: base $base is not reachable from this checkout"; exit 0; }
if [ "$(git rev-parse "$base")" = "$(git rev-parse HEAD)" ] && [ -z "$(git status --porcelain)" ]; then
  echo "ok: nothing changed since $base"; exit 0
fi

at_base() { git show "$base:$1" 2>/dev/null | jq -r .version 2>/dev/null || echo 0.0.0; }
plugin_base=$(at_base .claude-plugin/plugin.json); plugin_now=$(jq -r .version .claude-plugin/plugin.json)
server_base=$(at_base server.json);               server_now=$(jq -r .version server.json)

# Paths a plugin user can notice, including every shipped manifest (the Claude,
# Codex and Gemini manifests carry the connection config). Maintainer tooling
# under scripts/ is excluded.
changed=$(git diff --name-only "$base" -- skills agents hooks assets scripts \
  .mcp.json .claude-plugin .codex-plugin gemini-extension.json \
  ':(exclude)scripts/ci-*.sh' ':(exclude)scripts/bump-version.sh' ':(exclude)scripts/semver-cmp.sh' ':(exclude)scripts/build-openai-bundle.sh' ':(exclude)scripts/test-ci-check-bump.sh' ':(exclude)scripts/test-hooks.sh')
# A manifest whose only change is its version is the bump itself, not a change
# that needs one.
version_only() { # file
  case "$1" in *.json) ;; *) return 1 ;; esac
  [ -f "$1" ] || return 1
  a=$(git show "$base:$1" 2>/dev/null | jq -S 'del(.version)' 2>/dev/null) || return 1
  b=$(jq -S 'del(.version)' "$1" 2>/dev/null) || return 1
  [ -n "$a" ] && [ "$a" = "$b" ]
}
kept=""
for f in $changed; do version_only "$f" || kept="$kept$f
"; done
changed=$(printf '%s' "$kept")

cmp() { sh scripts/semver-cmp.sh "$1" "$2"; }
[ "$(cmp "$plugin_now" "$plugin_base")" != -1 ] || fail "plugin version went backwards: $plugin_base at $base, $plugin_now now"
[ "$(cmp "$server_now" "$server_base")" != -1 ] || fail "server.json version went backwards: $server_base at $base, $server_now now"
if [ -n "$changed" ] && [ "$plugin_now" = "$plugin_base" ]; then
  echo "$changed" | sed 's/^/  /' >&2
  fail "the files above changed since $base but the plugin version is still $plugin_now; run scripts/bump-version.sh plugin X.Y.Z"
fi
if [ "$server_now" != "$server_base" ] && [ "$plugin_now" = "$plugin_base" ]; then
  echo "note: server.json moved $server_base -> $server_now without a plugin bump; the skills usually follow a server change (CHANGELOG.md header)"
fi
echo "ok: plugin $plugin_base -> $plugin_now, server.json $server_base -> $server_now, base $base"
