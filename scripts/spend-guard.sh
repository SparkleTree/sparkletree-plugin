#!/bin/sh
# PreToolUse: ask before SparkleTree tools that spend workspace credits or change
# live campaigns. Reads the hook JSON on stdin (POSIX sh, no jq). Reads are
# never blocked; anything this script does not recognise passes through
# silently (exit 0, no output). The tool-name suffix is what matters, so the
# same script serves the plugin-scoped name and a hand-added connector.
input=$(cat | tr -d '\n')
tool=$(printf '%s' "$input" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
suffix=${tool##*__}
# ponytail: sed picks the last "action"/"mode" key in the payload; tool inputs
# here are flat so that is the tool's own field. Values are reduced to [A-Za-z0-9_].
action=$(printf '%s' "$input" | sed -n 's/.*"tool_input".*"action"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9_')
mode=$(printf '%s' "$input" | sed -n 's/.*"tool_input".*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9_')

ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

case "$suffix" in
  generate_campaign)
    ask "SparkleTree generate_campaign (mode=${mode:-start}) runs paid AI generation and spends credits from the workspace's monthly pool. Confirm the brief and the spend before running it." ;;
  render_video)
    case "$mode" in
      still) ask "SparkleTree render_video mode=still renders one frame on Remotion Lambda. It is the cheap iteration but still spends workspace credits." ;;
      *) ask "SparkleTree render_video (mode=${mode:-video}) renders on Remotion Lambda and spends workspace credits. Iterate with mode=still or quality=draft before a final render." ;;
    esac ;;
  video_commission)
    case "$action" in
      create) ask "SparkleTree video_commission action=create queues a metered film authoring session (credits, metered per workspace per day). Confirm the brief, aspect, duration and tier first." ;;
      approve) ask "SparkleTree video_commission action=approve queues the final render of the commission and spends credits again." ;;
      revise) ask "SparkleTree video_commission action=revise spends a metered revision round. Confirm the notes and that rounds remain." ;;
      cancel) ask "SparkleTree video_commission action=cancel stops a commission in progress; already spent rounds are not refunded." ;;
      *) exit 0 ;;
    esac ;;
  manage_campaigns)
    case "$action" in
      publish) ask "SparkleTree manage_campaigns action=publish makes the campaign page live on the edge and the brand page. Confirm the campaign and its visibility." ;;
      deploy) ask "SparkleTree manage_campaigns action=deploy places the campaign on a live surface or zone. Confirm the campaign and the target." ;;
      delete) ask "SparkleTree manage_campaigns action=delete removes the campaign and its variants permanently." ;;
      delete_variant) ask "SparkleTree manage_campaigns action=delete_variant removes a variant permanently; update_variant with isActive=false is the reversible alternative." ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac
