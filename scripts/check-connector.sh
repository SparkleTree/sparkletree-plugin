#!/bin/sh
# SessionStart (startup, clear, compact). Adds one routing line to the model's
# context so SparkleTree requests reach the right skill even when the skill
# listing has dropped this plugin's descriptions to fit its budget, and warns
# when SparkleTree fails its health check. Never blocks; always exits 0.
# SPARKLETREE_SESSION_CONTEXT=off keeps the routing line out of the context.
url="${SPARKLETREE_HEALTH_URL:-https://app.sparkletree.io/api/health}"
route="SparkleTree plugin is installed. Before calling any SparkleTree tool, load the skill sparkletree:sparkletree (workspace, read before write, confirm before spend). Task skills: launch-campaign (new campaign), products (products, photos, file uploads), brand (brand book, voice, brand page and site), squid-design (custom Squid look, templates, design checks, design video), review-variants, analytics (results, reports), status, video, surfaces-and-embed (embed, SDK, screens, QR), adapt (copy changes on a schedule), agency-workspaces, troubleshoot-connection."
[ "${SPARKLETREE_SESSION_CONTEXT:-}" = off ] && route=""
warn=""
if command -v curl >/dev/null 2>&1 && ! curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
  warn="SparkleTree did not answer a health check at session start ($url). Campaign tools may fail until it recovers; see https://gitlab.com/sparkletree/sparkletree-plugin/-/blob/main/SETUP.md#if-something-fails or write to support@sparkletree.io."
fi
[ -z "$route" ] && [ -z "$warn" ] && exit 0
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ctx=$(esc "$route${route:+${warn:+ }}$warn")
if [ -n "$warn" ]; then
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(esc "$warn")" "$ctx"
else
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$ctx"
fi
exit 0
