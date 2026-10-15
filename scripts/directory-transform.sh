#!/bin/sh
# Turns a checkout of main into the `directory` branch that Anthropic's
# directory lists. The directory branch is main with two differences:
#   - `.mcp.json` points at https://app.sparkletree.io/api/mcp/directory, the
#     connector submitted to the directory (`directory_default` in the monorepo's
#     lib/mcp/toolGates.ts): 15 tools, no AI images, no AI video commissions.
#   - Skills, agents, hooks, README, SETUP, AGENTS and evals describe only those
#     15 tools.
# Every edit names the exact text it replaces and fails when main no longer has
# it, so a wording change on main stops CI here instead of shipping half-edited
# text. A final check fails on any leftover mention.
#
# Usage: sh scripts/directory-transform.sh [dir]          transform dir (default .) in place
#        sh scripts/directory-transform.sh --check [dir]  only run the final check
# A tree that already points at the directory URL is only checked. POSIX sh,
# awk, sed and grep; no network. CI: scripts/ci-directory-branch.sh. Test:
# scripts/test-directory-transform.sh.
set -eu

URL=https://app.sparkletree.io/api/mcp
DIR_URL=$URL/directory

die() { echo "directory-transform: $*" >&2; exit 1; }
drift() { die "$1: $2 (main changed; update scripts/directory-transform.sh)"; }

# Write stdin over $1 in place, keeping its mode (hook scripts are executable).
put() { cat > "$1.dt" && settle "$1"; }
settle() { cat "$1.dt" > "$1" && rm -f "$1.dt"; }

# rep FILE OLD NEW: replace every literal OLD with NEW. OLD must occur.
rep() {
  [ -f "$1" ] || drift "$1" "file is missing"
  if OLD=$2 NEW=$3 awk '
    BEGIN { o = ENVIRON["OLD"]; n = ENVIRON["NEW"]; hit = 0 }
    { out = ""; s = $0
      while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) n; s = substr(s, i + length(o)); hit = 1 }
      print out s }
    END { exit hit ? 0 : 3 }' "$1" > "$1.dt"; then settle "$1"; else rm -f "$1.dt"; drift "$1" "text not found: $2"; fi
}

# del_lines FILE TEXT: delete every line that contains literal TEXT. One must.
del_lines() {
  [ -f "$1" ] || drift "$1" "file is missing"
  if T=$2 awk 'BEGIN { t = ENVIRON["T"]; hit = 0 } index($0, t) { hit = 1; next } { print } END { exit hit ? 0 : 3 }' "$1" > "$1.dt"
  then settle "$1"; else rm -f "$1.dt"; drift "$1" "no line contains: $2"; fi
}

# replace_line FILE PREFIX NEW: replace the one line that starts with literal PREFIX.
replace_line() {
  [ -f "$1" ] || drift "$1" "file is missing"
  if P=$2 N=$3 awk '
    BEGIN { p = ENVIRON["P"]; n = ENVIRON["N"]; hit = 0 }
    index($0, p) == 1 { print n; hit++; next } { print }
    END { exit hit == 1 ? 0 : 3 }' "$1" > "$1.dt"; then settle "$1"; else rm -f "$1.dt"; drift "$1" "not exactly one line starts with: $2"; fi
}

# del_section FILE HEADING: delete the line HEADING and everything up to the
# next "## " heading, with the blank lines before it.
del_section() {
  [ -f "$1" ] || drift "$1" "file is missing"
  if H=$2 awk '
    BEGIN { h = ENVIRON["H"]; skip = 0; hit = 0; blanks = "" }
    skip && /^## / { skip = 0; blanks = "\n" }
    skip { next }
    $0 == h { skip = 1; hit = 1; blanks = ""; next }
    /^$/ { blanks = blanks "\n"; next }
    { printf "%s", blanks; blanks = ""; print }
    END { if (!skip) printf "%s", blanks; exit hit ? 0 : 3 }' "$1" > "$1.dt"; then settle "$1"; else rm -f "$1.dt"; drift "$1" "heading not found: $2"; fi
}

# del_block FILE START END: delete from the line equal to START through the
# first line after it equal to END.
del_block() {
  [ -f "$1" ] || drift "$1" "file is missing"
  if S=$2 E=$3 awk '
    BEGIN { s = ENVIRON["S"]; e = ENVIRON["E"]; skip = 0; hit = 0 }
    skip { if ($0 == e) { skip = 0; hit = 1 } next }
    $0 == s { skip = 1; next } { print }
    END { exit hit ? 0 : 3 }' "$1" > "$1.dt"; then settle "$1"; else rm -f "$1.dt"; drift "$1" "block not found: $2 ... $3"; fi
}

# swap_url FILE...: the server URL becomes the directory URL, except on lines
# about server.json (the registry entry stays the full server).
swap_url() {
  for f in "$@"; do
    sed -e '/server\.json/!s#https://app\.sparkletree\.io/api/mcp\([^/A-Za-z0-9_-]\)#https://app.sparkletree.io/api/mcp/directory\1#g' \
        -e '/server\.json/!s#https://app\.sparkletree\.io/api/mcp$#https://app.sparkletree.io/api/mcp/directory#' "$f" | put "$f"
  done
}

# Files the plugin ships or a reviewer reads. CHANGELOG.md is history and
# server.json is the MCP registry entry for the full server; both stay as on main.
NAMES='video_commission|videoCommissions|commission|includeImages|ai images?|ai video|(^|[^a-z])films?([^a-z]|$)|seventeen|17 tools|external_default'
check() {
  cd "$1"
  bad=0
  grep -q "\"url\": \"$DIR_URL\"" .mcp.json || { echo "directory-transform: .mcp.json does not point at $DIR_URL" >&2; bad=1; }
  files=""
  for f in .mcp.json hooks agents skills evals README.md SETUP.md AGENTS.md \
           scripts/spend-guard.sh scripts/job-watch.sh scripts/check-connector.sh scripts/test-hooks.sh; do
    if [ -e "$f" ]; then files="$files $f"; fi
  done
  # shellcheck disable=SC2086
  hits=$(grep -rniE "$NAMES" $files || true)
  if [ -n "$hits" ]; then
    echo "directory-transform: these lines name tools or features the directory server does not have:" >&2
    echo "$hits" | sed 's/^/  /' >&2; bad=1
  fi
  # shellcheck disable=SC2086
  hits=$(grep -rnE 'app\.sparkletree\.io/api/mcp([^/]|$)' $files | grep -v 'server\.json' || true)
  if [ -n "$hits" ]; then
    echo "directory-transform: these lines still point at the full server $URL:" >&2
    echo "$hits" | sed 's/^/  /' >&2; bad=1
  fi
  [ $bad = 0 ] || exit 1
  echo "ok: directory tree, .mcp.json at $DIR_URL"
}

only_check=0
[ "${1:-}" = --check ] && { only_check=1; shift; }
dir=${1:-.}
[ -f "$dir/.mcp.json" ] || die "$dir has no .mcp.json; run it on the plugin root"
if [ $only_check = 1 ] || grep -q "\"url\": \"$DIR_URL\"" "$dir/.mcp.json"; then check "$dir"; exit 0; fi
cd "$dir"

# Server URL.
rep .mcp.json "\"url\": \"$URL\"" "\"url\": \"$DIR_URL\""
rep scripts/ci-validate.sh "mcp_url=$URL" "mcp_url=$DIR_URL"
swap_url README.md SETUP.md skills/*/SKILL.md skills/*/references/*.md agents/*.md

# Hooks: the guard and job watch no longer match video_commission.
rep hooks/hooks.json 'render_video|video_commission|manage_campaigns' 'render_video|manage_campaigns'
rep hooks/hooks.json '(generate_campaign|render_video|video_commission)$' '(generate_campaign|render_video)$'
rep scripts/spend-guard.sh "; the credits for its AI images are set aside when it starts. Confirm" ". Confirm"
del_block scripts/spend-guard.sh '  video_commission)' '    esac ;;'
rep scripts/spend-guard.sh 'case "$suffix" in generate_campaign|render_video|video_commission)' 'case "$suffix" in generate_campaign|render_video)'
rep scripts/job-watch.sh '(generate_campaign, render_video, video_commission create)' '(generate_campaign, render_video)'
del_lines scripts/job-watch.sh '  video_commission) printf'
del_lines scripts/test-hooks.sh 'check "commission list passes"'
rep scripts/test-hooks.sh 'for t in generate_campaign render_video video_commission manage_campaigns' 'for t in generate_campaign render_video manage_campaigns'

# Agents and evals: nothing to disallow that the server does not have.
for f in agents/campaign-reviewer.md agents/analytics-digest.md; do
  rep "$f" ', mcp__plugin_sparkletree_sparkletree__video_commission' ''
  rep "$f" ', mcp__sparkletree__video_commission' ''
done
rep evals/run-smoke.sh ',mcp__plugin_sparkletree_sparkletree__video_commission' ''

# Orientation skill and its references.
f=skills/sparkletree/SKILL.md
rep "$f" '| A video from a campaign or template, or a commissioned film |' '| A video from a campaign or template |'
rep "$f" ', `query_video_commissions`, `query_assets`' ', `query_assets`'
rep "$f" '`generate_campaign` (both modes; the credits for its AI images are set aside when it starts)' '`generate_campaign` (both modes)'
rep "$f" ', `video_commission` create, approve and revise (five a day, limited revision rounds)' ''
rep "$f" '`generate_campaign`, `render_video`, `video_commission` and product imports' '`generate_campaign`, `render_video` and product imports'
rep "$f" ', `query_video_commissions` `action: get`' ''
replace_line "$f" 'The bare URL serves the `external_default` profile' "The plugin connects to \`$DIR_URL\`, which serves the \`directory_default\` profile (the 15 tools in \`references/tools.md\`) and ignores \`?profile=\` call codes. Profiles change visibility, not permission."
rep "$f" 'the 17 default tools' 'the 15 tools'
f=skills/sparkletree/references/tools.md
rep "$f" 'Seventeen tools on the bare URL (`external_default`).' "Fifteen tools at \`$DIR_URL\` (\`directory_default\`). It generates no images or video with AI: \`generate_campaign\` writes copy and layout and uses images the workspace already holds."
rep "$f" " The credits for the campaign's AI images are set aside when the call is accepted, in both modes; when the workspace has too few, nothing starts and the answer is \`precondition_failed\` with \`details.imageCount\`, \`creditsNeeded\`, \`creditsRemaining\` and a remedy (generate with \`options.includeImages: false\`, retry later, or ask the workspace admin). Over campaign quota" ' Out of credits or over campaign quota'
del_lines "$f" '| `query_video_commissions` |'
del_lines "$f" '| `video_commission` |'
del_lines "$f" '"includeImages": true,'
rep skills/sparkletree/references/glossary.md "monthly pool for AI generation and AI images. Video renders and film commissions are not paid in credits" 'monthly pool for AI generation. Video renders are not paid in credits'

# Task skills.
f=skills/video/SKILL.md
rep "$f" ', check for an existing render first, or commission a bespoke brand film with video_commission. Use for video, render, clip, reel, film, or a video' ', or check for an existing render first. Use for video, render, clip, reel, or a video'
rep "$f" 'Two tools, two price classes. `render_video`' '`render_video`'
rep "$f" ' `video_commission` queues an agent-authored brand film with proofs and revision rounds; five per workspace per day, each with a fixed number of revision rounds; it is the expensive path. Default to `render_video`; offer a commission only when the user asks for a bespoke film.' ''
del_section "$f" '## Commissioning a film'
rep skills/adapt/SKILL.md '`render_video`, `video_commission`, ' '`render_video`, '
f=skills/launch-campaign/SKILL.md
rep "$f" "from the workspace's credit pool, including credits for each AI image (set aside when generation starts), plus" "from the workspace's credit pool, plus"
rep "$f" " The credits for the campaign's AI images are set aside when the call is accepted. If the workspace has too few, nothing starts and the answer is \`precondition_failed\` naming the images, the credits needed and the credits left: tell the user and offer to generate without images (\`options.includeImages: false\`), to wait for credits to renew, or to ask the workspace admin." " If the workspace is out of credits or over its campaign quota, nothing starts and the answer is \`precondition_failed\` with a remedy: tell the user and offer to wait for credits to renew or to ask the workspace admin."
rep skills/launch-campaign/references/plan.md ' with three AI images (credits from the workspace pool, the image credits set aside at the start)' ' (credits from the workspace pool)'
replace_line skills/agency-workspaces/SKILL.md 'The bare URL serves `external_default`.' "The plugin's URL serves \`directory_default\`, the same 15 tools for every connection, and ignores \`?profile=\` and \`?call_code=\`. Profiles change which tools are visible, never what the user may do. Discover the live list with \`get_platform_info\` \`topic: \"tool_profiles\"\`."
del_lines skills/troubleshoot-connection/SKILL.md '| Tools present but the profile looks wrong |'

# README (the listing), SETUP, AGENTS.
f=README.md
rep "$f" '17 tools: read tools for campaigns, products, stored files, surfaces, brand, analytics, video and commissions,' '15 tools: read tools for campaigns, products, stored files, surfaces, brand, analytics and video,'
rep "$f" 'Reads are marked read-only. |' "Reads are marked read-only. This is SparkleTree's directory connector: it generates no images or video with AI. |"
rep "$f" 'video and commissioned films;' 'video renders from templates;'
rep "$f" '`generate_campaign`, `render_video` or `video_commission` `create`' '`generate_campaign` or `render_video`'
rep "$f" '`render_video`, `video_commission` create, approve and revise, ' '`render_video`, '
rep "$f" '; `video_commission` `cancel`)' ')'
rep "$f" ', and the credits for each AI image are set aside when the call is accepted; with too few credits nothing starts.' '; with too few credits nothing starts.'
rep "$f" ' `video_commission` allows five commissions per workspace per day, and each commission has a fixed number of revision rounds.' ''
rep SETUP.md ', including credits for each AI image, set aside when it starts; publishing is free.' '; publishing is free.'
f=AGENTS.md
rep "$f" 'render_video|video_commission|manage_campaigns' 'render_video|manage_campaigns'
rep "$f" '(PostToolUse on `generate_campaign`, `render_video`, `video_commission`)' '(PostToolUse on `generate_campaign`, `render_video`)'
rep "$f" "it runs at \`$URL\` and is owned by" "this branch connects to it at \`$DIR_URL\`; it is owned by"
rep "$f" 'The skills are written for the 17-tool `external_default` surface.' 'On this branch the skills describe the 15-tool `directory_default` surface.'
awk 'NR == 1 { print; print ""; print "> This is the generated `directory` branch, the version listed in Anthropic'"'"'s directory. CI rebuilds it from `main` on every push (`scripts/ci-directory-branch.sh`, `scripts/directory-transform.sh`). Do not edit it; change `main` or the transform."; next } { print }' "$f" | put "$f"

check .
