#!/bin/sh
# Maintainer check for the plugin's one hook, scripts/check-connector.sh
# (SessionStart): the routing line, valid JSON, the warning when the server
# does not answer (when curl is installed), and SPARKLETREE_SESSION_CONTEXT=off.
# Needs jq; with curl it also needs network access to the health URL.
# Usage: sh scripts/test-hooks.sh
set -u
cd "$(dirname "$0")/.."
fail=0
up=https://app.sparkletree.io/api/health
down=http://127.0.0.1:9/api/health

out=$(SPARKLETREE_HEALTH_URL=$up sh scripts/check-connector.sh)
case "$out" in *'"additionalContext":"SparkleTree plugin is installed'*) echo "ok   routing line in the context";; *) echo "FAIL routing line: $out"; fail=1;; esac
case "$out" in *systemMessage*) echo "FAIL warning although the server answered: $out"; fail=1;; *) echo "ok   no warning when the server answers";; esac
printf '%s' "$out" | jq -e . >/dev/null 2>&1 && echo "ok   output is JSON" || { echo "FAIL output is not JSON: $out"; fail=1; }

# Without curl the hook skips the health check, so there is no warning to test.
if command -v curl >/dev/null 2>&1; then
  out=$(SPARKLETREE_HEALTH_URL=$down sh scripts/check-connector.sh)
  case "$out" in *'"systemMessage":"SparkleTree did not answer a health check'*) echo "ok   warning when the server does not answer";; *) echo "FAIL no warning for an unreachable server: $out"; fail=1;; esac
  printf '%s' "$out" | jq -e . >/dev/null 2>&1 && echo "ok   warning output is JSON" || { echo "FAIL warning output is not JSON: $out"; fail=1; }
else
  echo "skip warning checks: no curl here, and the hook skips the health check without it"
fi

out=$(SPARKLETREE_SESSION_CONTEXT=off SPARKLETREE_HEALTH_URL=$up sh scripts/check-connector.sh)
[ -z "$out" ] && echo "ok   SPARKLETREE_SESSION_CONTEXT=off and a healthy server: no output" || { echo "FAIL expected no output: $out"; fail=1; }

jq -e '.hooks | keys == ["SessionStart"]' hooks/hooks.json >/dev/null && echo "ok   hooks.json has only the session hook" || { echo "FAIL hooks.json has more than the session hook"; fail=1; }
exit $fail
