#!/bin/sh
# PreToolUse for SparkleTree write tools, plus two query_campaigns actions that
# use workspace allowances (check_component, match_templates). POSIX sh; uses
# jq when present and falls back to sed and awk. Keys on the tool-name suffix,
# so the plugin-scoped name, a hand-added server and a claude.ai connector id
# all behave the same.
#
# 1. Every other query_campaigns action passes silently, first.
# 2. Inside the read-only plugin agents (campaign-reviewer, analytics-digest)
#    every call that reaches this point is denied. disallowedTools cannot name
#    a connector's tools.
# 3. Credit spend, live changes, deletes and quota use return "ask" in
#    prompting modes. The hook cannot see whether a campaign is live, so
#    update_variant always passes; the skills confirm it in chat.
# 4. In auto, bypassPermissions and dontAsk modes an "ask" would silently
#    become "defer", so a credit-spending call is denied once with a reason
#    that tells the model to confirm in chat; the identical call made again
#    within 15 minutes passes. Other guarded calls pass without a prompt in
#    those modes. SPARKLETREE_SPEND_GUARD=prompt-only turns the deny-once off;
#    SPARKLETREE_SPEND_GUARD=off turns the whole guard off.
# 5. A second paid start while one from this session is still recent gets a
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

# Reads pass, except the two that use a workspace allowance.
if [ "$suffix" = query_campaigns ]; then
  case "$action" in check_component|match_templates) ;; *) exit 0 ;; esac
fi

out() { # decision reason
  reason=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$reason"
  exit 0
}

case "$agent" in
  *campaign-reviewer|*analytics-digest)
    out deny "The $agent agent is read-only. Do not call $suffix${action:+ action=$action}; return it as a proposed call for the parent to confirm with the user." ;;
esac

level=none; msg=""
case "$suffix" in
  generate_campaign)
    level=spend; msg="generate_campaign (mode=${mode:-start}) runs paid AI generation from the workspace's monthly credit pool; the credits for its AI images are set aside when it starts. Confirm the goal and the spend first." ;;
  render_video)
    level=spend
    case "$mode" in
      still) msg="render_video mode=still renders one frame. It is the cheap iteration but still spends workspace credits." ;;
      squid) msg="render_video mode=squid records a variant's published Squid design as video in a sandbox (20 recordings per workspace per day; not on Starter). Confirm the variant and formats." ;;
      *) msg="render_video (mode=${mode:-video}) spends workspace credits. Iterate with mode=still or quality=draft before a final render." ;;
    esac ;;
  video_commission)
    case "$action" in
      create) level=spend; msg="video_commission action=create queues a metered film commission (credits, five per workspace per day). Confirm the description, aspect, duration and tier." ;;
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
      duplicate) level=quota; msg="manage_campaigns action=duplicate copies the campaign into a new review copy and uses campaign quota." ;;
      create_share_link) level=live; msg="manage_campaigns action=create_share_link makes the campaign page private: only people with a share link can open it. The token is shown once." ;;
      revoke_share_link) level=live; msg="manage_campaigns action=revoke_share_link stops that share link working for everyone who has it." ;;
      create_component) [ "$publish" = true ] && { level=live; msg="manage_campaigns action=create_component publish=true puts a custom Squid design live as a new variant (admin)."; } ;;
      apply_template) [ "$publish" = true ] && { level=live; msg="manage_campaigns action=apply_template publish=true puts the template live as a new variant (admin). Claim slots such as price or offer stay empty until they are filled."; } ;;
      publish_component) level=live; msg="manage_campaigns action=publish_component puts a custom Squid design live as a new variant." ;;
      revert_component) level=live; msg="manage_campaigns action=revert_component pauses the variants that carry the design." ;;
      delete) level=live; msg="manage_campaigns action=delete removes the campaign and its variants permanently." ;;
      delete_variant) level=live; msg="manage_campaigns action=delete_variant removes a variant permanently; update_variant with isActive=false is the reversible alternative." ;;
    esac ;;
  manage_brand)
    case "$action" in
      create_page) [ "$publish" = true ] && { level=live; msg="manage_brand action=create_page publish=true replaces the live brand home page."; } ;;
      edit_page) [ "$publish" = true ] && { level=live; msg="manage_brand action=edit_page publish=true changes the live brand home page."; } ;;
      delete_page) level=live; msg="manage_brand action=delete_page permanently deletes a stored brand page version and its files." ;;
      delete_files) level=live; msg="manage_brand action=delete_files permanently removes files from a draft brand page version." ;;
      render_check) level=quota; msg="manage_brand action=render_check loads every page of the version in a sandbox (20 render checks per workspace per day). It changes no page." ;;
      publish_page) level=live; msg="manage_brand action=publish_page replaces the live brand home page." ;;
      revert_page) level=live; msg="manage_brand action=revert_page puts the default brand home page back live." ;;
      update_*) level=live; msg="manage_brand action=$action changes the brand every campaign, the brand page and the concierge use. Confirm the old and new values." ;;
      set_logo) level=live; msg="manage_brand action=set_logo replaces a logo that campaigns, the brand page and the concierge use. Confirm the slot and the image." ;;
    esac ;;
  query_campaigns)
    case "$action" in
      check_component) level=quota; msg="query_campaigns action=check_component runs the static checks and, where browser checks are switched on, starts a browser check of the design in a sandbox (20 design checks per workspace per day). A repeat call for the same design and slot values reads the stored check." ;;
      match_templates) level=quota; msg="query_campaigns action=match_templates may make a model call to rank the template library for this campaign's business (30 uncached matches per workspace per day; a match is kept for 7 days)." ;;
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
