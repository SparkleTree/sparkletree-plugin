#!/bin/sh
# PreToolUse for SparkleTree write tools. POSIX sh. jq is the only parser: the
# guard never reads a decision out of the JSON by text search. Keys on the
# suffix of the top-level tool_name, so the plugin-scoped name, a hand-added
# server and a claude.ai connector id all behave the same. No query_* tool
# reaches this hook: every one is a pure read. The two actions that use a
# workspace allowance without changing campaign data (check_component,
# match_templates) are manage_campaigns actions.
#
# 1. A query_* call that reaches the script anyway (a hand-written matcher)
#    passes silently, first.
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
#    The yes is a marker file named by a SHA-256 digest of the session id, the
#    full tool_name and the canonical tool_input (jq -cS), so it fits only that
#    call on that connector in that session. It holds the refusal time and
#    counts from 2 seconds to 15 minutes after it. It is consumed with mv, so
#    when identical calls race, only one goes through.
# 5. A second paid start while one from this session is still recent gets a
#    warning in the reason (markers written by job-watch.sh).
# 6. Fail closed. Without jq, or when the input is not a JSON object with a
#    string tool_name and an object tool_input, the guard cannot tell one call
#    from another. Every call that reaches it is then denied inside the
#    read-only agents, gets "ask" in prompting modes, and goes through the
#    deny-once step otherwise (or when the mode cannot be read). The reason
#    names the problem. Without a SHA-256 tool (shasum, sha256sum, openssl)
#    the deny-once step cannot record a yes and denies every time.
# A call the guard does not recognise passes through silently (exit 0, no
# output) only on the jq path.
[ "${SPARKLETREE_SPEND_GUARD:-}" = off ] && exit 0
input=$(cat | tr -d '\n')
data=${1:-${CLAUDE_PLUGIN_DATA:-}}
[ -n "$data" ] || data="${TMPDIR:-/tmp}/sparkletree-plugin"

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
[ "${SPARKLETREE_NO_JQ:-}" = 1 ] && have_jq=0  # tests: behave as if jq were missing

# The guard only ever answers "ask" or "deny", never "allow"; each decision is
# a literal so a reader (or a directory validator) can see that without
# running it.
escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ask() { # reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(escape "$1")"
  exit 0
}
deny() { # reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(escape "$1")"
  exit 0
}

sha256() { # stdin -> lowercase hex digest, or nothing when no tool exists
  if command -v shasum >/dev/null 2>&1; then d=$(shasum -a 256 | cut -d' ' -f1)
  elif command -v sha256sum >/dev/null 2>&1; then d=$(sha256sum | cut -d' ' -f1)
  elif command -v openssl >/dev/null 2>&1; then d=$(openssl dgst -sha256 | sed 's/.*= *//')
  else cat >/dev/null; d=""; fi
  case "$d" in *[!0-9a-f]*) d="" ;; esac
  [ ${#d} = 64 ] && printf '%s' "$d"
}

# deny_once KEY REASON, for auto, bypassPermissions and dontAsk. KEY is the
# text that identifies the call; empty means it cannot be matched to a yes.
deny_once() {
  [ "${SPARKLETREE_SPEND_GUARD:-}" = prompt-only ] && exit 0
  [ -n "$1" ] || deny "$2 This call cannot be matched to an earlier yes, so the guard refuses it every time. Ask the user to install jq or to set SPARKLETREE_SPEND_GUARD=prompt-only."
  sig=$(printf '%s' "$1" | sha256)
  [ -n "$sig" ] || deny "$2 No SHA-256 tool (shasum, sha256sum or openssl) is installed, so the guard cannot record a yes and refuses this call every time. Ask the user to install one or to set SPARKLETREE_SPEND_GUARD=prompt-only."
  mkdir -p "$data/confirm" 2>/dev/null
  c="$data/confirm/$sig"; taken="$c.$$"; now=$(date +%s)
  # mv is atomic: of several identical calls racing for one yes, one wins. A
  # yes counts from 2 seconds after the refusal, so a loser's fresh marker
  # cannot let a call from the same burst through.
  if mv "$c" "$taken" 2>/dev/null; then
    then_s=$(tr -cd '0-9' < "$taken" 2>/dev/null); rm -f "$taken"
    case "$then_s" in ''|*[!0-9]*) ;; *)
      age=$((now - then_s)); [ "$age" -ge 2 ] && [ "$age" -lt 900 ] && exit 0 ;;
    esac
  fi
  printf '%s\n' "$now" > "$c" 2>/dev/null
  deny "$2 Stop, tell the user what this call does and what it costs, and ask in chat. Only after an explicit yes, make exactly the same call again within 15 minutes."
}

# Can the call be read? Anything else fails closed.
why=""
if [ $have_jq = 0 ]; then
  why="jq is not installed, so the SparkleTree spend guard cannot read this call and treats every SparkleTree write as one that needs a yes."
elif ! printf '%s' "$input" | jq -e 'type == "object" and (.tool_name | type) == "string" and (.tool_input | type) == "object"' >/dev/null 2>&1; then
  why="The SparkleTree spend guard could not read this call (not a JSON object with a string tool_name and an object tool_input), so it treats it as one that needs a yes."
fi

if [ -n "$why" ]; then
  # Every value of a key anywhere in the text. Used only where an extra,
  # nested value can make the answer stricter, never looser.
  vals() {
    printf '%s' "$input" | awk -v k="$1" '{ s = $0; re = "\"" k "\"[ \t]*:[ \t]*\"[^\"]*\""
      while (match(s, re)) { m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^[^:]*:[ \t]*"/, "", m); sub(/"$/, "", m); print m } }'
  }
  for a in $(vals agent_type | tr -cd 'A-Za-z0-9_:\n-'); do
    case "$a" in *campaign-reviewer|*analytics-digest)
      deny "SparkleTree: $why This runs inside a read-only agent, so the call is refused. Return it as a proposed call for the parent to confirm with the user." ;;
    esac
  done
  # A prompt only when every permission_mode in the text is a prompting mode.
  prompting=0
  for m in $(vals permission_mode | tr -cd 'A-Za-z0-9_\n-'); do
    case "$m" in default|acceptEdits|plan) prompting=1 ;; *) prompting=0; break ;; esac
  done
  [ $prompting = 1 ] && ask "SparkleTree: $why Install jq to let reads and drafts through without a prompt."
  # A retry differs only in tool_use_id: blank it when it occurs once. When it
  # occurs more than once the call cannot be keyed.
  key=""
  if [ "$(vals tool_use_id | wc -l | tr -d ' ')" -le 1 ]; then
    key=$(printf '%s' "$input" | awk '{ sub(/"tool_use_id"[ \t]*:[ \t]*"[^"]*"/, "\"tool_use_id\":\"\""); print }')
  fi
  deny_once "$key" "SparkleTree: $why This session may run without permission prompts, so no prompt can appear."
fi

fields=$(printf '%s' "$input" | jq -r '[.tool_name, .agent_type, .permission_mode, .session_id,
    (.tool_input | .action, .mode, .operation, .status, .publish)]
  | map(if . == null then "" else tostring | gsub("[^A-Za-z0-9_:-]"; "") end) | join("|")' 2>/dev/null)
IFS='|' read -r tool agent pmode session action mode operation status publish <<EOF
$fields
EOF
suffix=${tool##*__}
session=$(printf '%s' "$session" | tr -cd 'A-Za-z0-9_-'); [ -n "$session" ] || session=nosession

# Reads pass.
case "$suffix" in query_*) exit 0 ;; esac

case "$agent" in
  *campaign-reviewer|*analytics-digest)
    deny "The $agent agent is read-only. Do not call $suffix${action:+ action=$action}; return it as a proposed call for the parent to confirm with the user." ;;
esac

level=none; msg=""
case "$suffix" in
  generate_campaign)
    level=spend; msg="generate_campaign (mode=${mode:-start}) runs paid AI generation from the workspace's monthly credit pool; the credits for its AI images are set aside when it starts. Confirm the goal and the spend first." ;;
  render_video)
    level=spend
    case "$mode" in
      still) msg="render_video mode=still renders one frame. It is the cheap iteration but counts against the daily render limit." ;;
      squid) msg="render_video mode=squid records a variant's published Squid design as video in a sandbox (20 recordings per workspace per day; not on Starter). Confirm the variant and formats." ;;
      *) msg="render_video (mode=${mode:-video}) starts a render that counts against the workspace daily render limit. Iterate with mode=still or quality=draft before a final render." ;;
    esac ;;
  video_commission)
    case "$action" in
      create) level=spend; msg="video_commission action=create queues a film commission (five per workspace per day, limited revision rounds). Confirm the description, aspect, duration and tier." ;;
      approve) level=spend; msg="video_commission action=approve queues the final render of the film." ;;
      revise) level=spend; msg="video_commission action=revise uses one of the limited revision rounds. Confirm the notes and that rounds remain." ;;
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
      check_component) level=quota; msg="manage_campaigns action=check_component runs the static checks and, where browser checks are switched on, starts a browser check of the design in a sandbox (20 design checks per workspace per day). It changes no campaign data. A repeat call for the same design and slot values reads the stored check." ;;
      match_templates) level=quota; msg="manage_campaigns action=match_templates may make a model call to rank the template library for this campaign's business (30 uncached matches per workspace per day; a match is kept for 7 days). It changes no campaign data." ;;
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
  manage_surfaces)
    level=live; msg="manage_surfaces operation=${operation:-?} creates a surface or zone (editor role, surface quota)." ;;
esac
[ "$level" = none ] && exit 0

# A recent paid start from this session (job-watch.sh writes the marker).
case "$suffix" in generate_campaign|render_video|video_commission)
  m="$data/jobs/$session-$suffix"
  if [ -f "$m" ] && [ "$action" != approve ] && [ "$action" != revise ] && [ "$action" != cancel ]; then
    then_s=$(tr -cd '0-9' < "$m" 2>/dev/null); now_s=$(date +%s)
    case "$then_s" in ''|*[!0-9]*) ;; *)
      mins=$(( (now_s - then_s) / 60 ))
      [ "$mins" -lt 30 ] && msg="$msg A $suffix job started in this session $mins min ago. If it is still running, poll it instead: starting again is a second paid job." ;;
    esac
  fi ;;
esac

case "$pmode" in
  auto|bypassPermissions|dontAsk)
    [ "$level" = spend ] || exit 0
    deny_once "$(printf '%s' "$input" | jq -cS '{s: (.session_id // ""), t: .tool_name, i: .tool_input}' 2>/dev/null)" \
      "SparkleTree: $msg This session runs in $pmode mode, so no permission prompt can appear." ;;
esac
ask "SparkleTree: $msg"
