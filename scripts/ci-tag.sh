#!/bin/sh
# Tag CI_COMMIT_SHA through the GitLab API: sh scripts/ci-tag.sh <tag> <message>.
# Idempotent: an existing tag is left alone. Needs the GITLAB_TAG_TOKEN CI
# variable (project access token, role Maintainer, scope write_repository,
# protected + masked); without it the script says so and exits 0 so the
# pipeline still passes. Needs curl.
set -eu
tag=${1:?tag}; msg=${2:-$1}
if [ -z "${GITLAB_TAG_TOKEN:-}" ]; then echo "GITLAB_TAG_TOKEN is not set; not tagging $tag"; exit 0; fi
api="$CI_API_V4_URL/projects/$CI_PROJECT_ID/repository/tags"
code=$(curl -sS --retry 3 -o /dev/null -w '%{http_code}' -H "PRIVATE-TOKEN: $GITLAB_TAG_TOKEN" "$api/$tag")
case "$code" in
  200) echo "tag $tag already exists"; exit 0 ;;
  404) ;;
  *) echo "looking up tag $tag returned HTTP $code" >&2; exit 1 ;;
esac
curl -fsS --retry 3 -o /dev/null -H "PRIVATE-TOKEN: $GITLAB_TAG_TOKEN" \
  --data-urlencode "tag_name=$tag" --data-urlencode "ref=$CI_COMMIT_SHA" --data-urlencode "message=$msg" "$api"
echo "tagged $tag at $CI_COMMIT_SHA"
