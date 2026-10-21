#!/bin/sh
# Manifest and layout checks for the SparkleTree plugin. Runs in CI on every
# push and works locally: sh scripts/ci-validate.sh. Needs jq and sh.
set -eu
fail() { echo "FAIL: $*" >&2; exit 1; }

for f in server.json .claude-plugin/plugin.json .codex-plugin/plugin.json .claude-plugin/marketplace.json .mcp.json gemini-extension.json; do
  jq -e . "$f" >/dev/null 2>&1 || fail "$f is not valid JSON"
done

claude_v=$(jq -r .version .claude-plugin/plugin.json)
codex_v=$(jq -r .version .codex-plugin/plugin.json)
gemini_v=$(jq -r .version gemini-extension.json)
server_v=$(jq -r .version server.json)
# The three plugin manifests are one version; server.json tracks the hosted
# server and is allowed to differ (README.md, "Versions").
[ "$claude_v" = "$codex_v" ] || fail "plugin versions differ: .claude-plugin $claude_v vs .codex-plugin $codex_v"
[ "$claude_v" = "$gemini_v" ] || fail "plugin versions differ: .claude-plugin $claude_v vs gemini-extension.json $gemini_v"
echo "$claude_v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "plugin version '$claude_v' is not semver"
echo "$server_v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "server.json version '$server_v' is not semver"

[ "$(jq -r .name server.json)" = "io.sparkletree/sparkletree" ] || fail "server.json name must be io.sparkletree/sparkletree"
[ "$(jq -r '.remotes[0].url' server.json)" = "https://app.sparkletree.io/api/mcp" ] || fail "server.json remote must be https://app.sparkletree.io/api/mcp"
# One server for every client, Anthropic's directory listing included.
mcp_url=https://app.sparkletree.io/api/mcp
[ "$(jq -r '.sparkletree.url' .mcp.json)" = "$mcp_url" ] || fail ".mcp.json must point at $mcp_url"
[ "$(jq -r '.mcpServers.sparkletree.httpUrl' gemini-extension.json)" = "$mcp_url" ] || fail "gemini-extension.json must point at $mcp_url"
[ "$(jq -r '.repository.url' server.json)" = "https://gitlab.com/sparkletree/sparkletree-plugin" ] || fail "server.json repository must be the GitLab plugin repo"

grep -q "^## $claude_v\$" CHANGELOG.md || fail "CHANGELOG.md has no '## $claude_v' section for the plugin version"
grep -Eq '(server\.json`? |registry )'"$server_v"'([^0-9]|$)' CHANGELOG.md || fail "CHANGELOG.md never mentions registry version $server_v (write 'registry $server_v' or '\`server.json\` $server_v' in the entry that moved it)"

# The claude.ai / desktop marketplace importer walks the whole tree and rejects
# any plugin.json that is not at the root .claude-plugin/ (plugin 0.1.1 lesson).
nested=$(git ls-files | grep '/\.claude-plugin/plugin\.json$' || true)  # a leading slash: any folder but the root
[ -z "$nested" ] || fail "nested plugin manifest(s) would break marketplace sync: $nested"
[ ! -e openai ] || fail "generated openai/ bundle must not be committed"
[ ! -e key.pem ] || fail "key.pem must not be committed"

# Every skill has a frontmatter name matching its directory.
for d in skills/*/; do
  n=$(basename "$d")
  [ -f "$d/SKILL.md" ] || fail "skills/$n has no SKILL.md"
  head -20 "$d/SKILL.md" | grep -q "^name: $n\$" || fail "skills/$n/SKILL.md frontmatter name is not '$n'"
  head -20 "$d/SKILL.md" | grep -q '^description: .*[<>]' && fail "skills/$n description contains angle brackets (claude.ai importer flags them as XML)"
done

# Every script must parse as POSIX sh. Each is named by its fixed path: a shell
# pointed at a path in a variable is what Anthropic's directory validator holds
# as able to run the icon. (sh -n checks only its first file, hence one line
# each.) A new script fails the count until it gets its own line.
for_sh_n=8
set -- scripts/*.sh
[ $# = $for_sh_n ] || fail "scripts/ holds $# scripts but ci-validate.sh checks $for_sh_n; add a sh -n line for the new one"
sh -n scripts/bump-version.sh        || fail "scripts/bump-version.sh does not parse"
sh -n scripts/check-connector.sh     || fail "scripts/check-connector.sh does not parse"
sh -n scripts/ci-check-bump.sh       || fail "scripts/ci-check-bump.sh does not parse"
sh -n scripts/ci-tag.sh              || fail "scripts/ci-tag.sh does not parse"
sh -n scripts/ci-validate.sh         || fail "scripts/ci-validate.sh does not parse"
sh -n scripts/semver-cmp.sh          || fail "scripts/semver-cmp.sh does not parse"
sh -n scripts/test-ci-check-bump.sh  || fail "scripts/test-ci-check-bump.sh does not parse"
sh -n scripts/test-hooks.sh          || fail "scripts/test-hooks.sh does not parse"

echo "ok: plugin $claude_v, server.json $server_v"
