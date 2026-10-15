#!/bin/sh
# Maintainer check: feeds hook payloads through the hook scripts and compares
# the decision. Runs three times: with jq; with SPARKLETREE_NO_JQ=1; and with
# jq hidden from PATH. Without jq the spend guard fails closed, so the last two
# runs expect "ask" or a refusal where the jq run expects a silent pass. Then
# it checks the guard without a SHA-256 tool, the session hook and the
# PreToolUse matcher. Needs jq on the machine that runs it.
# Usage: sh scripts/test-hooks.sh
set -u
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
command -v jq >/dev/null 2>&1 || { echo "FAIL jq is needed to run the jq cases"; exit 1; }
SH=$(command -v sh)
P=mcp__plugin_sparkletree_sparkletree__
C=mcp__f98fa307-a1b0-4470-b52e-b07172438e00__
bs=$(printf '\134')

# A PATH directory that links the tools the hook scripts use, minus the ones named.
mkbin() { # dir tool-to-leave-out...
  d=$1; shift; mkdir -p "$d"
  for t in cat tr sed awk cut date find grep mkdir mv rm wc head jq shasum sha256sum openssl curl perl; do
    case " $* " in *" $t "*) continue ;; esac
    p=$(command -v "$t" 2>/dev/null) || continue
    case "$p" in /*) ln -s "$p" "$d/$t" ;; esac
  done
}
mkbin "$tmp/bin-nojq" jq
mkbin "$tmp/bin-nosha" shasum sha256sum openssl
mkbin "$tmp/bin-bare" jq shasum sha256sum openssl
hidepath=""
hook() { if [ -n "$hidepath" ]; then PATH=$hidepath "$SH" scripts/spend-guard.sh "$@"; else "$SH" scripts/spend-guard.sh "$@"; fi; }
watch() { if [ -n "$hidepath" ]; then PATH=$hidepath "$SH" scripts/job-watch.sh "$@"; else "$SH" scripts/job-watch.sh "$@"; fi; }

decision() { sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p'; }
check() { # name expected payload
  got=$(printf '%s' "$3" | hook "$tmp/d" | decision); [ -n "$got" ] || got=pass
  if [ "$got" = "$2" ]; then echo "ok   $1 -> $got"; else echo "FAIL $1: expected $2, got $got"; fail=1; fi
}
pl() { printf '{"session_id":"s1","permission_mode":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"tool_use_id":"t1"%s}' "$1" "$2" "$3" "${4:-}"; }
retry() { sed 's/"tool_use_id":"t1"/"tool_use_id":"t2"/'; }  # the same call made again
x() { if [ "$path" = jq ]; then echo "$1"; else echo "$2"; fi; }  # expected: jq path, fallback
# A yes counts from 2 seconds to 15 minutes after the refusal: move every marker
# back by $1 seconds, as if the user had taken that long to answer.
aged() { for f in "$tmp/d/confirm"/*; do [ -f "$f" ] && echo $(( $(date +%s) - $1 )) > "$f"; done; }

run() {
  rm -rf "$tmp/d"
  check "generate start asks" ask "$(pl default ${P}generate_campaign '{"mode":"start","intent":{"objective":"increase_sales"}}')"
  check "connector id asks too" ask "$(pl default ${C}generate_campaign '{"mode":"start"}')"
  check "still asks" ask "$(pl default ${P}render_video '{"mode":"still","templateId":"kinetic-promo"}')"
  check "commission list passes" "$(x pass ask)" "$(pl default ${P}video_commission '{"action":"cancelx"}')"
  check "import_from_url asks" ask "$(pl default ${P}manage_products '{"action":"import_from_url","websiteUrl":"https://example.com"}')"
  check "product create passes" "$(x pass ask)" "$(pl default ${P}manage_products '{"action":"create","name":"Lamp"}')"
  check "update_variant passes" "$(x pass ask)" "$(pl default ${P}manage_campaigns '{"action":"update_variant","campaignId":"c","contentStructure":{"cta":{"action":"publish"}}}')"
  check "publish asks" ask "$(pl default ${P}manage_campaigns '{"action":"publish","campaignId":"c"}')"
  check "update active asks" ask "$(pl default ${P}manage_campaigns '{"action":"update","campaignId":"c","status":"active"}')"
  check "update name passes" "$(x pass ask)" "$(pl default ${P}manage_campaigns '{"action":"update","campaignId":"c","name":"x"}')"
  check "brand draft passes" "$(x pass ask)" "$(pl default ${P}manage_brand '{"action":"create_page","html":"<html></html>"}')"
  check "brand publish=true asks" ask "$(pl default ${P}manage_brand '{"action":"create_page","html":"x","publish":true}')"
  check "brand voice asks" ask "$(pl default ${P}manage_brand '{"action":"update_voice","voice":{}}')"
  check "set_logo asks" ask "$(pl default ${P}manage_brand '{"action":"set_logo","logoAssetId":"k"}')"
  check "complete_upload passes" "$(x pass ask)" "$(pl default ${P}upload_asset '{"action":"complete_upload","uploadId":"u"}')"
  check "surface asks" ask "$(pl default ${P}manage_surfaces '{"operation":"create_surface","name":"Lobby"}')"
  check "upload passes" "$(x pass ask)" "$(pl default ${P}upload_asset '{"action":"from_url","url":"https://x/y.png"}')"
  check "edit_page draft passes" "$(x pass ask)" "$(pl default ${P}manage_brand '{"action":"edit_page","pageId":"p","edits":[{"old":"a","new":"b"}]}')"
  check "edit_page publish asks" ask "$(pl default ${P}manage_brand '{"action":"edit_page","pageId":"p","edits":[{"old":"a","new":"b"}],"publish":true}')"
  check "create_version passes" "$(x pass ask)" "$(pl default ${P}manage_brand '{"action":"create_version"}')"
  check "put_files passes" "$(x pass ask)" "$(pl default ${P}manage_brand '{"action":"put_files","pageId":"p","files":[{"path":"a.css","content":"x"}]}')"
  check "delete_files asks" ask "$(pl default ${P}manage_brand '{"action":"delete_files","pageId":"p","paths":["a.css"]}')"
  check "delete_page asks" ask "$(pl default ${C}manage_brand '{"action":"delete_page","pageId":"p"}')"
  check "render_check asks" ask "$(pl default ${P}manage_brand '{"action":"render_check","pageId":"p"}')"
  check "component draft passes" "$(x pass ask)" "$(pl default ${P}manage_campaigns '{"action":"create_component","campaignId":"c","html":"x","manifest":{"v":1}}')"
  check "component publish asks" ask "$(pl default ${P}manage_campaigns '{"action":"create_component","campaignId":"c","html":"x","publish":true}')"
  check "template draft passes" "$(x pass ask)" "$(pl default ${P}manage_campaigns '{"action":"apply_template","campaignId":"c","templateId":"001-a"}')"
  check "template publish asks" ask "$(pl default ${P}manage_campaigns '{"action":"apply_template","campaignId":"c","templateId":"001-a","publish":true}')"
  check "duplicate asks" ask "$(pl default ${P}manage_campaigns '{"action":"duplicate","campaignId":"c"}')"
  check "share link asks" ask "$(pl default ${P}manage_campaigns '{"action":"create_share_link","campaignId":"c"}')"
  check "revoke share link asks" ask "$(pl default ${P}manage_campaigns '{"action":"revoke_share_link","campaignId":"c","tokenId":"t"}')"
  check "check_component asks" ask "$(pl default ${P}manage_campaigns '{"action":"check_component","componentId":"k"}')"
  check "match_templates asks" ask "$(pl default ${C}manage_campaigns '{"action":"match_templates","campaignId":"c"}')"
  check "query check_component passes (server refuses it)" "$(x pass ask)" "$(pl default ${P}query_campaigns '{"action":"check_component","componentId":"k"}')"
  check "query list passes" "$(x pass ask)" "$(pl default ${P}query_campaigns '{"action":"list","status":"active"}')"
  check "list_templates passes" "$(x pass ask)" "$(pl default ${P}query_campaigns '{"action":"list_templates","query":"bakery"}')"
  check "get_template passes" "$(x pass ask)" "$(pl default ${P}query_campaigns '{"action":"get_template","templateId":"001-a"}')"
  check "forecast passes" "$(x pass ask)" "$(pl default ${P}query_campaigns '{"action":"forecast","campaignId":"c"}')"
  check "query without action passes" "$(x pass ask)" "$(pl default ${P}query_campaigns '{}')"
  check "reviewer agent may read" "$(x pass deny)" "$(pl default ${P}query_campaigns '{"action":"get","campaignId":"c"}' ',"agent_type":"sparkletree:campaign-reviewer"')"
  check "reviewer agent denied check" deny "$(pl default ${P}manage_campaigns '{"action":"check_component","componentId":"k"}' ',"agent_type":"sparkletree:campaign-reviewer"')"
  check "digest agent denied match" deny "$(pl default ${C}manage_campaigns '{"action":"match_templates","campaignId":"c"}' ',"agent_type":"sparkletree:analytics-digest"')"
  check "reviewer agent denied" deny "$(pl default ${C}manage_campaigns '{"action":"update_variant"}' ',"agent_id":"a1","agent_type":"sparkletree:campaign-reviewer"')"
  check "digest agent denied upload" deny "$(pl default ${P}upload_asset '{"action":"from_url"}' ',"agent_type":"sparkletree:analytics-digest"')"
  check "auto: spend denied once" deny "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"a":1}}')"
  check "auto: same call in the same burst is refused" deny "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"a":1}}' | retry)"
  aged 60
  check "auto: same call passes" pass "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"a":1}}' | retry)"
  check "auto: live change defers" "$(x pass deny)" "$(pl auto ${P}manage_campaigns '{"action":"publish","campaignId":"c"}')"
  check "auto: check_component passes" "$(x pass deny)" "$(pl bypassPermissions ${P}manage_campaigns '{"action":"check_component","componentId":"k"}')"
  check "auto: match_templates passes" "$(x pass deny)" "$(pl auto ${C}manage_campaigns '{"action":"match_templates","campaignId":"c"}')"
  check "dontAsk: render spend denied once" deny "$(pl dontAsk ${P}render_video '{"mode":"squid","campaignId":"c","variantId":"v"}')"

  # Text-search bypasses of the old sed path (Codex review, 0.2.1).
  check "escaped action name still asks" ask "$(pl default ${P}manage_campaigns "{\"action\":\"del${bs}u0065te\",\"campaignId\":\"c\"}")"
  check "nested tool_name does not make a read" ask "$(pl default ${P}manage_campaigns '{"action":"delete","campaignId":"c","context":{"tool_name":"query_campaigns"}}')"
  check "nested tool_name in reviewer agent denied" deny "$(pl default ${P}manage_campaigns '{"action":"delete","context":{"tool_name":"query_campaigns"}}' ',"agent_type":"sparkletree:campaign-reviewer"')"
  check "nested draft action before delete asks" ask "$(pl default ${P}manage_campaigns '{"options":{"action":"draft"},"action":"delete","campaignId":"c"}')"
  check "auto: nested permission_mode default denied" deny "$(pl auto ${P}generate_campaign '{"mode":"start","p":{"permission_mode":"default"}}')"
  check "auto: nested permission_mode on a live change" "$(x pass deny)" "$(pl auto ${P}manage_campaigns '{"action":"delete","campaignId":"c","p":{"permission_mode":"default"}}')"
  check "no permission_mode" "$(x ask deny)" "$(printf '{"session_id":"s1","tool_name":"%s","tool_input":{"action":"delete","campaignId":"c"}}' ${P}manage_campaigns)"
  check "unreadable input asks" ask "$(pl default ${P}manage_campaigns '{"action":"update","campaignId":"c"' | sed 's/}$//')"
  check "auto: unreadable input denied" deny "$(pl auto ${P}manage_campaigns '{"action":"update","campaignId":"c"' | sed 's/}$//')"
  check "tool_input not an object asks" ask "$(pl default ${P}manage_campaigns '"delete"')"

  # Approval markers: one yes fits one call, on one connector, in one session, once.
  rm -rf "$tmp/d/confirm"
  A='{"mode":"start","intent":{"objective":"a"}}'; B='{"mode":"start","intent":{"objective":"b"}}'
  check "auto: A denied once" deny "$(pl auto ${P}generate_campaign "$A")"
  aged 60  # from here on the yes for A is valid
  check "auto: B does not use the yes for A" deny "$(pl auto ${P}generate_campaign "$B" | retry)"
  check "auto: A on another connector does not use it" deny "$(pl auto ${C}generate_campaign "$A" | retry)"
  check "auto: A in another session does not use it" deny "$(pl auto ${P}generate_campaign "$A" | retry | sed 's/"session_id":"s1"/"session_id":"s2"/')"
  check "auto: A again passes" pass "$(pl auto ${P}generate_campaign "$A" | retry)"
  check "auto: the yes is used up" deny "$(pl auto ${P}generate_campaign "$A" | retry)"
  bad=$(ls "$tmp/d/confirm" | grep -v '^[0-9a-f]\{64\}$')
  [ -z "$bad" ] && echo "ok   markers are SHA-256 names" || { echo "FAIL marker names: $bad"; fail=1; }
  mkdir -p "$tmp/race"; rm -f "$tmp/race"/*
  p=$(pl auto ${P}generate_campaign "$A" | retry); aged 60
  for i in 1 2 3 4 5 6; do (printf '%s' "$p" | hook "$tmp/d" > "$tmp/race/$i") & done; wait
  won=0; for f in "$tmp/race"/*; do [ -s "$f" ] || won=$((won + 1)); done
  [ "$won" = 1 ] && echo "ok   six racing retries: one passes" || { echo "FAIL six racing retries: $won passed"; fail=1; }
  rm -rf "$tmp/d/confirm"
  check "auto: D denied once" deny "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"objective":"d"}}')"
  aged 901
  check "auto: D after 15 minutes is denied again" deny "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"objective":"d"}}' | retry)"
  two='{"mode":"start","tool_use_id":"x"}'
  check "auto: two tool_use_id keys, denied" deny "$(pl auto ${P}generate_campaign "$two")"
  aged 60
  check "auto: two tool_use_id keys, retry" "$(x pass deny)" "$(pl auto ${P}generate_campaign "$two" | retry)"

  # job-watch marker then duplicate warning
  printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}' ',"tool_response":{"content":[{"type":"text","text":"{\"campaignId\":\"c\"}"}]}')" | sed 's/PreToolUse/PostToolUse/' | watch "$tmp/d"
  [ -f "$tmp/d/jobs/s1-generate_campaign" ] && echo "ok   job-watch writes a marker" || { echo "FAIL job-watch wrote no marker"; fail=1; }
  if [ "$path" = jq ]; then
    reason=$(printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}')" | hook "$tmp/d")
    case "$reason" in *"started in this session"*) echo "ok   duplicate start warned";; *) echo "FAIL duplicate start not warned: $reason"; fail=1;; esac
  else
    reason=$(printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}')" | hook "$tmp/d")
    case "$reason" in *"jq is not installed"*) echo "ok   reason names the missing jq";; *) echo "FAIL reason does not name jq: $reason"; fail=1;; esac
  fi
  rm -rf "$tmp/d/jobs"
  printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}' ',"tool_response":{"content":[{"type":"text","text":"{\"error\":{\"code\":\"precondition_failed\"}}"}]}')" | watch "$tmp/d"
  [ -f "$tmp/d/jobs/s1-generate_campaign" ] && { echo "FAIL error response left a job marker"; fail=1; } || echo "ok   error response leaves no marker"
  got=$(pl default ${P}generate_campaign '{"mode":"start"}' | SPARKLETREE_SPEND_GUARD=off hook "$tmp/d")
  [ -z "$got" ] && echo "ok   guard off -> pass" || { echo "FAIL guard off: $got"; fail=1; }
  got=$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"objective":"p"}}' | SPARKLETREE_SPEND_GUARD=prompt-only hook "$tmp/d")
  [ -z "$got" ] && echo "ok   prompt-only: no refusal in auto" || { echo "FAIL prompt-only: $got"; fail=1; }
}
echo "with jq:"; path=jq; run
echo "SPARKLETREE_NO_JQ=1:"; path=nojq; SPARKLETREE_NO_JQ=1; export SPARKLETREE_NO_JQ; run; unset SPARKLETREE_NO_JQ
echo "jq hidden from PATH:"; path=nojq; hidepath=$tmp/bin-nojq; run; hidepath=""

# No SHA-256 tool: prompts still work; the refuse-once step cannot record a yes.
for hidepath in "$tmp/bin-nosha" "$tmp/bin-bare"; do
  label=$(basename "$hidepath"); rm -rf "$tmp/d"
  check "$label: generate asks" ask "$(pl default ${P}generate_campaign '{"mode":"start"}')"
  check "$label: auto denied" deny "$(pl auto ${P}generate_campaign '{"mode":"start"}')"
  check "$label: auto retry still denied" deny "$(pl auto ${P}generate_campaign '{"mode":"start"}' | retry)"
  reason=$(pl auto ${P}generate_campaign '{"mode":"start"}' | hook "$tmp/d")
  case "$reason" in *"No SHA-256 tool"*) echo "ok   $label: reason names the missing SHA-256 tool";; *) echo "FAIL $label: $reason"; fail=1;; esac
done
hidepath=""

out=$(SPARKLETREE_HEALTH_URL=https://app.sparkletree.io/api/health sh scripts/check-connector.sh)
case "$out" in *'"additionalContext":"SparkleTree plugin is installed'*) echo "ok   session context";; *) echo "FAIL session context: $out"; fail=1;; esac
if printf '%s' "$out" | jq -e . >/dev/null 2>&1; then echo "ok   session output is JSON"; else echo "FAIL session output JSON"; fail=1; fi
# The session hook never used jq: without it the output is the same.
down=http://127.0.0.1:9/api/health
out1=$(SPARKLETREE_HEALTH_URL=$down "$SH" scripts/check-connector.sh)
out2=$(SPARKLETREE_HEALTH_URL=$down PATH=$tmp/bin-nojq "$SH" scripts/check-connector.sh)
[ -n "$out1" ] && [ "$out2" = "$out1" ] && echo "ok   session output without jq is the same" || { echo "FAIL session output without jq differs: $out2"; fail=1; }
# Every tool the guard handles must reach it through the PreToolUse matcher.
m=$(sed -n 's/.*"matcher": "mcp__\.\*__(\([^)]*\))\$".*/\1/p' hooks/hooks.json | head -1)
mfail=0
for t in generate_campaign render_video video_commission manage_campaigns manage_products manage_brand manage_surfaces upload_asset; do
  case "|$m|" in *"|$t|"*) ;; *) echo "FAIL PreToolUse matcher misses $t"; mfail=1;; esac
done
# Reads never reach it: every query_* tool is a pure read.
case "$m" in *query_*) echo "FAIL PreToolUse matcher names a query_* tool: $m"; mfail=1;; esac
[ $mfail = 0 ] && echo "ok   PreToolUse matcher covers the guarded tools and no reads" || fail=1
exit $fail
