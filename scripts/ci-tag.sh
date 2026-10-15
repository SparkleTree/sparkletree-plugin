#!/bin/sh
# Tag CI_COMMIT_SHA and push the tag with the job's own token:
# sh scripts/ci-tag.sh <tag> <message>. Idempotent: an existing tag is left
# alone. The runner's origin already carries CI_JOB_TOKEN; the push needs
# Settings > CI/CD > Job token permissions > "Allow Git push requests to the
# repository" on this project, and fails the job when it is off. Needs git.
set -eu
tag=${1:?tag}; msg=${2:-$1}
if [ -n "$(git ls-remote --tags origin "refs/tags/$tag")" ]; then echo "tag $tag already exists"; exit 0; fi
git -c user.name="${GITLAB_USER_NAME:-GitLab CI}" -c user.email="${GITLAB_USER_EMAIL:-noreply@gitlab.com}" \
  tag -f -a -m "$msg" "$tag" "$CI_COMMIT_SHA"
git push -q origin "refs/tags/$tag" ||
  { echo "pushing $tag was refused; turn on Settings > CI/CD > Job token permissions > Allow Git push requests to the repository" >&2; exit 1; }
echo "tagged $tag at $CI_COMMIT_SHA"
