#!/bin/sh
# PreToolUse for SparkleTree write tools. POSIX sh; uses jq when present and
# falls back to sed. Keys on the tool-name suffix, so the plugin-scoped name,
# a hand-added server and a claude.ai connector id all behave the same.
#
# 1. Inside the read-only plugin agents (campaign-reviewer, analytics-digest)
#    every write is denied. disallowedTools cannot name a connector's tools.
# 2. Credit spend and live changes return "ask" in prompting modes.
# 3. In auto, bypassPermissions and dontAsk modes an "ask" would silently
#    become "defer", so a credit-spending call is denied once with a reason
#    that tells the model to confirm in chat; the identical call made again
#    within 15 minutes passes. SPARKLETREE_SPEND_GUARD=prompt-only turns this
#    off; SPARKLETREE_SPEND_GUARD=off turns the whole guard off.
# 4. A second paid start while one from this session is still recent gets a
#    warning in the reason (markers written by job-watch.sh).
# Anything unrecognised passes through silently (exit 0, no output).
[ "${SPARKLETREE_SPEND_GUARD:-}" = off ] && exit 0
input=$(cat | tr -d '\n')
data=${1:-${CLAUDE_PLUGIN_DATA:-}}
[ -n "$data" ] || data="${TMPDIR:-/tmp}/sparkletree-plugin"

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
[ "${SPARKLETREE_NO_JQ:-}" = 1 ] && have_jq=0  # tests exercise the sed path
top() { # top-level string field
  if [ $have_jq = 1 ]; then printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty | tostring' 2>/dev/null
  else printf '%s' "$input" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'; fi
}
arg() { # tool_input field; without jq, the first match after "tool_input"
  if [ $have_jq = 1 ]; then printf '%s' "$input" | jq -r --arg k "$1" '.tool_input[$k] // empty | tostring' 2>/dev/null
  else printf '%s' "$input" | awk -v k="\"$1\"" '{ i = index($0, "\"tool_input\""); if (!i) exit
      s = substr($0, i); j = index(s, k); if (!j) exit
      s = substr(s, j + length(k)); sub(/^[ \t]*:[ \t]*"?/, "", s)
      if (match(s, /^[A-Za-z0-9_]+/)) print substr(s, 1, RLENGTH) }'; fi
}
clean() { tr -cd 'A-Za-z0-9_-'; }

tool=$(top tool_name); suffix=${tool##*__}
action=$(arg action | clean); mode=$(arg mode | clean); operation=$(arg operation | clean)
status=$(arg status | clean); publish=$(arg publish | clean)
agent=$(top agent_type); pmode=$(top permission_mode | clean)
session=$(top session_id | clean); [ -n "$session" ] || session=nosession

out() { # decision reason
  reason=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$reason"
  exit 0
}

case "$agent" in
  *campaign-reviewer|*analytics-digest)
    out deny "The $agent agent is read-only. Do not call $suffix; return the change as a proposed call for the parent to confirm with the user." ;;
esac

level=none; msg=""
case "$suffix" in
  generate_campaign)
    level=spend; msg="generate_campaign (mode=${mode:-start}) runs paid AI generation from the workspace's monthly credit pool. Confirm the brief and the spend first." ;;
  render_video)
    level=spend
    case "$mode" in
      still) msg="render_video mode=still renders one frame. It is the cheap iteration but still spends workspace credits." ;;
      squid) msg="render_video mode=squid records a Squid design as video (workspace credits, 20 per day). Confirm the variant and formats." ;;
      *) msg="render_video (mode=${mode:-video}) spends workspace credits. Iterate with mode=still or quality=draft before a final render." ;;
    esac ;;
  video_commission)
    case "$action" in
      create) level=spend; msg="video_commission action=create queues a metered film commission (credits, five per workspace per day). Confirm the brief, aspect, duration and tier." ;;
      approve) level=spend; msg="video_commission action=approve queues the final render and spends credits again." ;;
      revise) level=spend; msg="video_commission action=revise spends a metered revision round. Confirm the notes and that rounds remain." ;;
      cancel) level=live; msg="video_commission action=cancel stops a commission; spent rounds are not refunded." ;;
    esac ;;
  manage_products)
    case "$action" in
      import_from_url) level=spend; msg="manage_products action=import_from_url fetches the page and runs paid inference. Confirm the URL." ;;
      delete) level=live; msg="manage_products action=delete removes the product permanently; campaigns that use it lose it." ;;
    esac ;;
  manage_campaigns)
    case "$action" in
      generate_playbook) level=spend; msg="manage_campaigns action=generate_playbook runs paid inference to rewrite the campaign's playbook." ;;
      publish) level=live; msg="manage_campaigns action=publish makes the campaign page live on the edge and the brand page. Confirm the campaign and its visibility." ;;
      deploy) level=live; msg="manage_campaigns action=deploy places the campaign on a live surface or zone. Confirm the campaign and the target." ;;
      update_deployment) level=live; msg="manage_campaigns action=update_deployment changes what a live surface shows." ;;
      update) [ "$status" = active ] && { level=live; msg="manage_campaigns action=update status=active starts the campaign (and may publish its page)."; } ;;
      publish_component) level=live; msg="manage_campaigns action=publish_component puts a custom Squid design live as a new variant." ;;
      revert_component) level=live; msg="manage_campaigns action=revert_component pauses the variants that carry the design." ;;
      delete) level=live; msg="manage_campaigns action=delete removes the campaign and its variants permanently." ;;
      delete_variant) level=live; msg="manage_campaigns action=delete_variant removes a variant permanently; update_variant with isActive=false is the reversible alternative." ;;
    esac ;;
  manage_brand)
    case "$action" in
      create_page) [ "$publish" = true ] && { level=live; msg="manage_brand action=create_page publish=true replaces the live brand home page."; } ;;
      publish_page) level=live; msg="manage_brand action=publish_page replaces the live brand home page." ;;
      revert_page) level=live; msg="manage_brand action=revert_page puts the default brand home page back live." ;;
      update_*) level=live; msg="manage_brand action=$action changes the brand every campaign, the brand page and the concierge use. Confirm the old and new values." ;;
    esac ;;
  manage_surfaces)
    level=live; msg="manage_surfaces operation=${operation:-?} creates a surface or zone (editor role, surface quota)." ;;
esac
[ "$level" = none ] && exit 0

# A recent paid start from this session (job-watch.sh writes the marker).
case "$suffix" in generate_campaign|render_video|video_commission)
  m="$data/jobs/$session-$suffix"
  if [ -f "$m" ] && [ "$action" != approve ] && [ "$action" != revise ] && [ "$action" != cancel ]; then
    then_s=$(cat "$m" 2>/dev/null | clean); now_s=$(date +%s)
    case "$then_s" in ''|*[!0-9]*) ;; *)
      mins=$(( (now_s - then_s) / 60 ))
      [ "$mins" -lt 30 ] && msg="$msg A $suffix job started in this session $mins min ago. If it is still running, poll it instead: starting again is a second paid job." ;;
    esac
  fi ;;
esac

case "$pmode" in
  auto|bypassPermissions|dontAsk)
    [ "$level" = spend ] || exit 0
    [ "${SPARKLETREE_SPEND_GUARD:-}" = prompt-only ] && exit 0
    if [ $have_jq = 1 ]; then sig=$(printf '%s' "$input" | jq -c '.tool_input' 2>/dev/null | cksum | cut -d' ' -f1)
    else sig="$action$mode"; fi
    mkdir -p "$data/confirm" 2>/dev/null
    c="$data/confirm/$session-$suffix-$sig"
    if [ -f "$c" ] && [ -n "$(find "$c" -mmin -15 2>/dev/null)" ]; then rm -f "$c"; exit 0; fi
    : > "$c" 2>/dev/null
    out deny "SparkleTree: $msg This session runs in $pmode mode, so no permission prompt can appear. Stop, tell the user what this call does and what it costs, and ask in chat. Only after an explicit yes, make exactly the same call again within 15 minutes." ;;
esac
out ask "SparkleTree: $msg"
