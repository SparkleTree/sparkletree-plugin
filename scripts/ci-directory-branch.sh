#!/bin/sh
# Rebuild the `directory` branch from the main commit CI is running on:
# sh scripts/ci-directory-branch.sh. The tree is main after
# scripts/directory-transform.sh; it must pass ci-validate.sh and
# test-hooks.sh before it is pushed.
#
# The new commit's parents are the previous directory tip and the main commit,
# so the branch only ever moves forward. A GitLab push mirror with "Keep
# divergent refs" on would skip a rewritten branch and leave GitHub stale. The
# push is still a lease on the tip we read, so a concurrent run fails instead of
# overwriting. Nothing is pushed when the tree has not changed.
#
# Pushes with the GITLAB_TAG_TOKEN CI variable (the same project access token
# scripts/ci-tag.sh uses: Maintainer, write_repository, protected + masked).
# Without it the script says so and exits 0. Needs git, jq and tar.
set -eu
cd "$(dirname "$0")/.."
if [ -z "${GITLAB_TAG_TOKEN:-}" ]; then echo "GITLAB_TAG_TOKEN is not set; not updating the directory branch"; exit 0; fi
src=${CI_COMMIT_SHA:-$(git rev-parse HEAD)}
url="${CI_SERVER_URL:?}/${CI_PROJECT_PATH:?}.git"
auth="Authorization: Basic $(printf 'oauth2:%s' "$GITLAB_TAG_TOKEN" | base64 | tr -d '\n')"
export GIT_TERMINAL_PROMPT=0

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
gitdir=$(git rev-parse --absolute-git-dir)

prev=""
if [ -n "$(git -c "http.extraHeader=$auth" ls-remote --heads "$url" refs/heads/directory)" ]; then
  git -c "http.extraHeader=$auth" fetch -q --depth=1 "$url" "+refs/heads/directory:refs/ci/directory-prev"
  prev=$(git rev-parse refs/ci/directory-prev)
fi

mkdir "$tmp/tree"
git archive "$src" | tar -xf - -C "$tmp/tree"
sh scripts/directory-transform.sh "$tmp/tree"
(cd "$tmp/tree" && sh scripts/ci-validate.sh && sh scripts/test-hooks.sh) || { echo "the transformed tree fails its checks; directory not updated" >&2; exit 1; }

tree=$(cd "$tmp/tree" && GIT_DIR=$gitdir GIT_WORK_TREE=$tmp/tree GIT_INDEX_FILE=$tmp/index git add -A -f . && GIT_DIR=$gitdir GIT_INDEX_FILE=$tmp/index git write-tree)
if [ -n "$prev" ] && [ "$(git rev-parse "$prev^{tree}")" = "$tree" ]; then
  echo "directory already matches main $src"; exit 0
fi

GIT_AUTHOR_NAME=$(git log -1 --format=%an "$src"); GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$src")
GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME; GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
subject=$(git log -1 --format=%s "$src")
commit=$(printf 'directory: %s\n\nGenerated from main %s by scripts/directory-transform.sh.\n' "$subject" "$src" |
  git commit-tree "$tree" ${prev:+-p "$prev"} -p "$src")

git -c "http.extraHeader=$auth" push -q --force-with-lease="refs/heads/directory:$prev" "$url" "$commit:refs/heads/directory"
echo "directory -> $commit (main $src${prev:+, previous $prev})"
