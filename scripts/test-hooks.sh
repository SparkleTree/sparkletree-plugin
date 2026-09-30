#!/bin/sh
# Maintainer check: feeds hook payloads through the hook scripts and compares
# the decision. Runs twice, with jq and with the sed fallback.
# Usage: sh scripts/test-hooks.sh
set -u
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
P=mcp__plugin_sparkletree_sparkletree__
C=mcp__f98fa307-a1b0-4470-b52e-b07172438e00__
decision() { sed -n 's/.*"permissionDecision":"\([a-z]*\)".*/\1/p'; }
check() { # name expected payload
  got=$(printf '%s' "$3" | sh scripts/spend-guard.sh "$tmp" | decision); [ -n "$got" ] || got=pass
  if [ "$got" = "$2" ]; then echo "ok   $1 -> $got"; else echo "FAIL $1: expected $2, got $got"; fail=1; fi
}
pl() { printf '{"session_id":"s1","permission_mode":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s,"tool_use_id":"t%s"%s}' "$1" "$2" "$3" "$$" "${4:-}"; }
run() {
  rm -rf "$tmp"/*
  check "generate start asks" ask "$(pl default ${P}generate_campaign '{"mode":"start","intent":{"objective":"increase_sales"}}')"
  check "connector id asks too" ask "$(pl default ${C}generate_campaign '{"mode":"start"}')"
  check "still asks" ask "$(pl default ${P}render_video '{"mode":"still","templateId":"kinetic-promo"}')"
  check "commission list passes" pass "$(pl default ${P}video_commission '{"action":"cancelx"}')"
  check "import_from_url asks" ask "$(pl default ${P}manage_products '{"action":"import_from_url","websiteUrl":"https://example.com"}')"
  check "product create passes" pass "$(pl default ${P}manage_products '{"action":"create","name":"Lamp"}')"
  check "update_variant passes" pass "$(pl default ${P}manage_campaigns '{"action":"update_variant","campaignId":"c","contentStructure":{"cta":{"action":"publish"}}}')"
  check "publish asks" ask "$(pl default ${P}manage_campaigns '{"action":"publish","campaignId":"c"}')"
  check "update active asks" ask "$(pl default ${P}manage_campaigns '{"action":"update","campaignId":"c","status":"active"}')"
  check "update name passes" pass "$(pl default ${P}manage_campaigns '{"action":"update","campaignId":"c","name":"x"}')"
  check "brand draft passes" pass "$(pl default ${P}manage_brand '{"action":"create_page","html":"<html></html>"}')"
  check "brand publish=true asks" ask "$(pl default ${P}manage_brand '{"action":"create_page","html":"x","publish":true}')"
  check "brand voice asks" ask "$(pl default ${P}manage_brand '{"action":"update_voice","voice":{}}')"
  check "surface asks" ask "$(pl default ${P}manage_surfaces '{"operation":"create_surface","name":"Lobby"}')"
  check "upload passes" pass "$(pl default ${P}upload_asset '{"action":"from_url","url":"https://x/y.png"}')"
  check "reviewer agent denied" deny "$(pl default ${C}manage_campaigns '{"action":"update_variant"}' ',"agent_id":"a1","agent_type":"sparkletree:campaign-reviewer"')"
  check "digest agent denied upload" deny "$(pl default ${P}upload_asset '{"action":"from_url"}' ',"agent_type":"sparkletree:analytics-digest"')"
  check "auto: spend denied once" deny "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"a":1}}')"
  check "auto: same call passes" pass "$(pl auto ${P}generate_campaign '{"mode":"start","intent":{"a":1}}')"
  check "auto: live change defers" pass "$(pl auto ${P}manage_campaigns '{"action":"publish","campaignId":"c"}')"
  # job-watch marker then duplicate warning
  printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}' ',"tool_response":{"content":[{"type":"text","text":"{\"campaignId\":\"c\"}"}]}')" | sed 's/PreToolUse/PostToolUse/' | sh scripts/job-watch.sh "$tmp"
  reason=$(printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}')" | sh scripts/spend-guard.sh "$tmp")
  case "$reason" in *"started in this session"*) echo "ok   duplicate start warned";; *) echo "FAIL duplicate start not warned: $reason"; fail=1;; esac
  rm -rf "$tmp"/jobs
  printf '%s' "$(pl default ${P}generate_campaign '{"mode":"start"}' ',"tool_response":{"content":[{"type":"text","text":"{\"error\":{\"code\":\"precondition_failed\"}}"}]}')" | sh scripts/job-watch.sh "$tmp"
  [ -f "$tmp/jobs/s1-generate_campaign" ] && { echo "FAIL error response left a job marker"; fail=1; } || echo "ok   error response leaves no marker"
  got=$(pl default ${P}generate_campaign '{"mode":"start"}' | SPARKLETREE_SPEND_GUARD=off sh scripts/spend-guard.sh "$tmp")
  [ -z "$got" ] && echo "ok   guard off -> pass" || { echo "FAIL guard off: $got"; fail=1; }
}
echo "with jq:"; run
echo "sed fallback:"; SPARKLETREE_NO_JQ=1; export SPARKLETREE_NO_JQ; run; unset SPARKLETREE_NO_JQ
out=$(SPARKLETREE_HEALTH_URL=https://app.sparkletree.io/api/health sh scripts/check-connector.sh)
case "$out" in *'"additionalContext":"SparkleTree plugin is installed'*) echo "ok   session context";; *) echo "FAIL session context: $out"; fail=1;; esac
printf '%s' "$out" | { command -v jq >/dev/null && jq -e . >/dev/null && echo "ok   session output is JSON" || { echo "FAIL session output JSON"; fail=1; }; }
exit $fail
