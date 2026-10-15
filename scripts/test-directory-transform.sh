#!/bin/sh
# Maintainer check for scripts/directory-transform.sh: runs it on a copy of this
# checkout (tracked and new files) and checks the result. On the directory
# branch itself it only runs the transform's own check.
# Usage: sh scripts/test-directory-transform.sh. Needs git, tar and jq.
set -u
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
copy() { mkdir -p "$2"; (cd "$1" && find . -type f ! -path './.git/*' | tar -cf - -T -) | tar -xf - -C "$2"; }
T=scripts/directory-transform.sh

if grep -q '"url": "https://app.sparkletree.io/api/mcp/directory"' .mcp.json; then
  if sh $T --check .; then ok "this is the directory tree and it passes the check"; else bad "directory tree check"; fi
  exit $fail
fi

mkdir "$tmp/orig"
git ls-files -co --exclude-standard | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done | tar -cf - -T - | tar -xf - -C "$tmp/orig"
copy "$tmp/orig" "$tmp/a"

if sh $T "$tmp/a" >"$tmp/out" 2>&1; then ok "transform runs on this tree"; else cat "$tmp/out"; bad "transform failed"; exit 1; fi

u=$(jq -r .sparkletree.url "$tmp/a/.mcp.json")
[ "$u" = https://app.sparkletree.io/api/mcp/directory ] && ok ".mcp.json -> $u" || bad ".mcp.json url is $u"

# Only these files may differ from main, and no file may appear or disappear.
allowed='.mcp.json AGENTS.md README.md SETUP.md agents/analytics-digest.md agents/campaign-reviewer.md
evals/run-smoke.sh hooks/hooks.json scripts/ci-validate.sh scripts/job-watch.sh scripts/spend-guard.sh
scripts/test-hooks.sh skills/adapt/SKILL.md skills/agency-workspaces/SKILL.md skills/launch-campaign/SKILL.md
skills/launch-campaign/references/plan.md skills/setup/SKILL.md skills/sparkletree/SKILL.md
skills/sparkletree/references/glossary.md skills/sparkletree/references/tools.md
skills/troubleshoot-connection/SKILL.md skills/video/SKILL.md'
diff -rq "$tmp/orig" "$tmp/a" > "$tmp/diff"
grep -v '^Files .* differ$' "$tmp/diff" > "$tmp/extra" && { cat "$tmp/extra"; bad "files appeared or disappeared"; }
changed=$(sed -n "s#^Files $tmp/orig/\(.*\) and .* differ\$#\1#p" "$tmp/diff")
for f in $changed; do
  case " $(echo $allowed) " in *" $f "*) ;; *) bad "unexpected change to $f";; esac
done
[ -n "$changed" ] && ok "$(echo "$changed" | wc -l | tr -d ' ') files changed, all expected"

for s in scripts/spend-guard.sh scripts/job-watch.sh scripts/check-connector.sh; do
  if [ -x "$tmp/orig/$s" ] && [ ! -x "$tmp/a/$s" ]; then bad "$s lost its executable bit"; fi
done
ok "hook scripts keep their mode"

if (cd "$tmp/a" && sh scripts/ci-validate.sh) >"$tmp/out" 2>&1; then ok "ci-validate.sh passes on the directory tree"; else cat "$tmp/out"; bad "ci-validate.sh on the directory tree"; fi
if (cd "$tmp/a" && sh scripts/test-hooks.sh) >"$tmp/out" 2>&1; then ok "test-hooks.sh passes on the directory tree"; else grep FAIL "$tmp/out"; bad "test-hooks.sh on the directory tree"; fi
grep -q 'video_commission' "$tmp/a/scripts/spend-guard.sh" && bad "spend-guard.sh still handles video_commission"
sh -n "$tmp/a/scripts/spend-guard.sh" && sh -n "$tmp/a/scripts/job-watch.sh" && ok "hook scripts parse"
jq -e . "$tmp/a/hooks/hooks.json" >/dev/null && ok "hooks.json is JSON"

copy "$tmp/a" "$tmp/b"
sh $T "$tmp/b" >/dev/null 2>&1 && diff -r "$tmp/a" "$tmp/b" >/dev/null && ok "a second run changes nothing" || bad "second run"

copy "$tmp/a" "$tmp/c"
echo 'Commission a film with video_commission.' >> "$tmp/c/skills/video/SKILL.md"
sh $T --check "$tmp/c" >/dev/null 2>&1 && bad "check missed a leftover video_commission" || ok "check catches a leftover mention"
copy "$tmp/a" "$tmp/c2"
sed 's#api/mcp/directory`#api/mcp`#' "$tmp/a/skills/setup/SKILL.md" > "$tmp/c2/skills/setup/SKILL.md"
sh $T --check "$tmp/c2" >/dev/null 2>&1 && bad "check missed the full server URL" || ok "check catches the full server URL"

copy "$tmp/orig" "$tmp/d"
sed 's/^## Commissioning a film$/## Films/' "$tmp/orig/skills/video/SKILL.md" > "$tmp/d/skills/video/SKILL.md"
if sh $T "$tmp/d" >"$tmp/out" 2>&1; then bad "transform passed although main's text changed"
else grep -q 'main changed' "$tmp/out" && ok "a wording change on main stops the transform" || { cat "$tmp/out"; bad "drift message"; }; fi

exit $fail
