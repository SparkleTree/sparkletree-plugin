#!/bin/sh
# Bump the plugin version (all three manifests plus a changelog stub) or the
# registry server version (server.json plus a changelog line). Needs jq.
#
#   scripts/bump-version.sh plugin 0.1.4
#   scripts/bump-version.sh server 1.0.3
#
# Plugin: skills, commands, agents, hooks, anything a user of the plugin sees.
# Server: only when the hosted MCP server's tools, resources, auth or endpoint
# changed; must match MCP_SERVER_VERSION in the monorepo. See README, "Versions".
set -eu
cd "$(dirname "$0")/.."
fail() { echo "bump-version: $*" >&2; exit 1; }
kind=${1:-}; new=${2:-}
[ -n "$kind" ] && [ -n "$new" ] || fail "usage: scripts/bump-version.sh plugin|server X.Y.Z"
echo "$new" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "'$new' is not X.Y.Z"

set_version() { # file current new: rewrite the single "version" line, keep formatting
  f=$1; cur=$2; to=$3
  n=$(grep -c "^  \"version\": \"$cur\",\$" "$f" || true)
  [ "$n" = 1 ] || fail "$f: expected exactly one version line for $cur, found $n"
  sed "s/^  \"version\": \"$cur\",\$/  \"version\": \"$to\",/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  echo "  $f: $cur -> $to"
}

case "$kind" in
  plugin)
    cur=$(jq -r .version .claude-plugin/plugin.json)
    [ "$(sh scripts/semver-cmp.sh "$new" "$cur")" = 1 ] || fail "plugin is at $cur; $new is not higher"
    for f in .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json; do
      [ "$(jq -r .version "$f")" = "$cur" ] || fail "$f is at $(jq -r .version "$f"), not $cur; fix by hand first"
    done
    for f in .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json; do set_version "$f" "$cur" "$new"; done
    # New section above the first existing one.
    awk -v v="$new" '!done && /^## / { print "## " v "\n\n- \n"; done = 1 } { print }' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    echo "  CHANGELOG.md: new section '## $new' with an empty bullet to fill in"
    ;;
  server)
    cur=$(jq -r .version server.json)
    [ "$(sh scripts/semver-cmp.sh "$new" "$cur")" = 1 ] || fail "server.json is at $cur; $new is not higher"
    set_version server.json "$cur" "$new"
    # Line under the current plugin section (first heading, after its blank line).
    awk -v v="$new" '{ print } !done && /^## / { getline; print; print "- Registry `server.json` " v ": "; done = 1 }' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    echo "  CHANGELOG.md: line 'Registry server.json $new:' under the current plugin section, to fill in"
    echo "  reminder: MCP_SERVER_VERSION in the monorepo (mosaic/lib/mcp/version.ts) must also read $new"
    ;;
  *) fail "first argument must be plugin or server" ;;
esac
echo "next: fill in CHANGELOG.md, then sh scripts/ci-validate.sh && sh scripts/ci-check-bump.sh"
