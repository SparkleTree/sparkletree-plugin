#!/bin/sh
# SessionStart: silent when SparkleTree answers its health check, one line when
# it does not. Never blocks a session; always exits 0.
url="${SPARKLETREE_HEALTH_URL:-https://app.sparkletree.io/api/health}"
command -v curl >/dev/null 2>&1 || exit 0
curl -fsS --max-time 2 "$url" >/dev/null 2>&1 && exit 0
echo "SparkleTree did not answer a health check at session start ($url). Campaign tools may fail until it recovers. If they do, follow https://github.com/SparkleTree/sparkletree-plugin/blob/main/SETUP.md#if-something-fails or write to support@sparkletree.io."
exit 0
