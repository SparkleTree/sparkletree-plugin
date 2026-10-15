#!/bin/sh
# Rebuild the `directory` branch from the main commit CI is running on:
# sh scripts/ci-directory-branch.sh. The tree is main after
# scripts/directory-transform.sh; it must pass ci-validate.sh, test-hooks.sh
# and the four `claude plugin validate --strict` runs before it is pushed.
#
# The new commit's parents are the previous directory tip and the main commit,
# so the branch only ever moves forward. A GitLab push mirror with "Keep
# divergent refs" on would skip a rewritten branch and leave GitHub stale. The
# push is still a lease on the tip we read, so a concurrent run fails instead of
# overwriting. Nothing is pushed when the tree has not changed.
#
# Pushes with the job's own token through origin, like scripts/ci-tag.sh: needs
# Settings > CI/CD > Job token permissions > "Allow Git push requests to the
# repository". GitLab starts no pipeline for a job-token push, which is why the
# checks run here. Needs git, jq, tar and the claude CLI.
set -eu
cd "$(dirname "$0")/.."
src=${CI_COMMIT_SHA:-$(git rev-parse HEAD)}
command -v claude >/dev/null || { echo "the claude CLI is needed to validate the directory tree" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
gitdir=$(git rev-parse --absolute-git-dir)

prev=""
if [ -n "$(git ls-remote --heads origin refs/heads/directory)" ]; then
  git fetch -q --depth=1 origin "+refs/heads/directory:refs/ci/directory-prev"
  prev=$(git rev-parse refs/ci/directory-prev)
fi

mkdir "$tmp/tree"
git archive "$src" | tar -xf - -C "$tmp/tree"
sh scripts/directory-transform.sh "$tmp/tree"
(cd "$tmp/tree" && sh scripts/ci-validate.sh && sh scripts/test-hooks.sh &&
  for t in . .claude-plugin/plugin.json skills agents; do claude plugin validate --strict "$t" || exit 1; done) || { echo "the transformed tree fails its checks; directory not updated" >&2; exit 1; }

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

git push -q --force-with-lease="refs/heads/directory:$prev" origin "$commit:refs/heads/directory" ||
  { echo "pushing directory was refused; turn on Settings > CI/CD > Job token permissions > Allow Git push requests to the repository" >&2; exit 1; }
echo "directory -> $commit (main $src${prev:+, previous $prev})"
