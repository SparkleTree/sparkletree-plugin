#!/bin/sh
# Fallback runner for hosts where `claude plugin eval` is not enabled.
# For every case, runs the prompt once through `claude -p --plugin-dir .` and
# checks that the expected skill was loaded via the Skill tool. Reads are
# harmless; writes are disallowed for the run. Usage: evals/run-smoke.sh [case ...]
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
cases=${*:-$(ls "$root/evals" | grep -v -e results -e run-smoke.sh -e README.md)}
fail=0
for c in $cases; do
  dir="$root/evals/$c"
  [ -f "$dir/prompt.md" ] || continue
  prompt=$(awk 'f{print} /^---$/{n++; if(n==2) f=1}' "$dir/prompt.md")
  skill=$(sed -n 's/.*"(sparkletree:)?\([a-z-]*\)".*/\1/p' "$dir/graders/skill-loaded.md")
  # The prompt goes in on stdin: --disallowedTools is variadic and would swallow a trailing argument.
  out=$(printf '%s' "$prompt" | claude -p --plugin-dir "$root" --output-format stream-json --verbose --max-turns 6 \
    --disallowedTools "mcp__plugin_sparkletree_sparkletree__manage_campaigns,mcp__plugin_sparkletree_sparkletree__generate_campaign,mcp__plugin_sparkletree_sparkletree__manage_products,mcp__plugin_sparkletree_sparkletree__manage_surfaces,mcp__plugin_sparkletree_sparkletree__manage_brand,mcp__plugin_sparkletree_sparkletree__render_video,mcp__plugin_sparkletree_sparkletree__video_commission" \
    2>/dev/null)
  if printf '%s' "$out" | grep -q "\"skill\":\"\(sparkletree:\)\{0,1\}$skill\""; then
    echo "PASS $c (skill $skill loaded)"
  else
    echo "FAIL $c (skill $skill not loaded)"; fail=1
  fi
done
exit $fail
