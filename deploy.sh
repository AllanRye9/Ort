#!/usr/bin/env bash
# Run this from the root of your actual working repo, e.g.:
#   cd /workspaces/Piitrade
#   bash fix-repo.sh
#
# Fixes, in order:
#   0. Ensures git user.name/user.email are configured (so commits below
#      don't fail with "Please tell me who you are")
#   1. Confirms/repairs the git remote name (was "orgin" instead of "origin")
#   2. Auto-stashes any local uncommitted changes, pulls remote changes,
#      then restores the stash (fixes "cannot pull with rebase: you have
#      unstaged changes")
#   3. Stops tracking the .next/ build cache that was getting committed
#   4. Does a truly clean reinstall of frontend/node_modules so the
#      installed Next.js version matches package-lock.json (15.5.23),
#      instead of the mismatched 16.3.2 that broke the build
#   5. Verifies the build
#   6. Pushes

set -euo pipefail

# echo "== Step 0: ensuring git identity is configured =="
# if [ -z "$(git config user.email || true)" ]; then
#   git config user.email "${GIT_AUTHOR_EMAIL:-ci@piitrade.local}"
#   echo "Set user.email to $(git config user.email) (override by exporting GIT_AUTHOR_EMAIL before running)"
# fi
# if [ -z "$(git config user.name || true)" ]; then
#   git config user.name "${GIT_AUTHOR_NAME:-Piitrade Bot}"
#   echo "Set user.name to $(git config user.name) (override by exporting GIT_AUTHOR_NAME before running)"
# fi

# echo
# echo "== Step 1: checking git remotes =="
# git remote -v

# if git remote get-url orgin >/dev/null 2>&1; then
#   echo "Found misnamed remote 'orgin' -> renaming to 'origin'"
#   git remote rename orgin origin
# fi

# if ! git remote get-url origin >/dev/null 2>&1; then
#   echo "ERROR: no 'origin' remote found. Add it manually with:"
#   echo "  git remote add origin https://github.com/AllanRye9/Piitrade"
#   exit 1
# fi

# echo
# echo "== Step 2: pulling remote changes before pushing =="
# git fetch origin

# STASHED=0
# if [[ -n "$(git status --porcelain)" ]]; then
#   echo "Local changes detected — stashing them before pulling."
#   git stash push -u -m "fix-repo.sh: auto-stash before pull ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
#   STASHED=1
# else
#   echo "Working tree clean — nothing to stash."
# fi

# if ! git pull origin main --rebase; then
#   echo
#   echo "Rebase hit conflicts (likely in frontend/.next/cache/*.sst — disposable build cache)."
#   echo "Resolve with, e.g.:"
#   echo "  git checkout --ours frontend/.next/ && git add frontend/.next/ && git rebase --continue"
#   if [[ "$STASHED" -eq 1 ]]; then
#     echo
#     echo "NOTE: your local changes are safely stashed (not lost)."
#     echo "After the rebase finishes, restore them with: git stash pop"
#   fi
#   exit 1
# fi

# if [[ "$STASHED" -eq 1 ]]; then
#   echo "Restoring stashed local changes..."
#   if ! git stash pop; then
#     echo
#     echo "Restoring the stash hit conflicts. Resolve them manually, then:"
#     echo "  git add -A && git stash drop   # once you're happy with the merge"
#     exit 1
#   fi
#   echo "Stashed changes restored."
# fi

echo
echo "== Step 3: untracking .next/ build cache =="
if git ls-files --error-unmatch frontend/.next >/dev/null 2>&1; then
  git rm -r --cached frontend/.next
  git add .gitignore frontend/.gitignore
  git commit -m "Stop tracking .next build cache"
  echo "Committed removal of tracked .next cache files."
else
  echo "frontend/.next was not tracked — nothing to remove."
fi

echo
echo "== Step 3.5: committing any remaining pending changes =="
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "Apply pending fixes"
  echo "Committed pending working-tree changes."
else
  echo "Nothing pending to commit."
fi

echo
echo "== Step 4: clean reinstall of frontend dependencies =="
cd frontend
rm -rf node_modules
npm ci
INSTALLED_NEXT=$(node -p "require('./node_modules/next/package.json').version")
echo "Installed Next.js version: $INSTALLED_NEXT"
if [[ "$INSTALLED_NEXT" != 15.* ]]; then
  echo "WARNING: expected a 15.x Next.js version (lockfile pins 15.5.23),"
  echo "but got $INSTALLED_NEXT. Something outside this project (a global"
  echo "install, a shadowing PATH entry, or an npm cache issue) may be"
  echo "overriding it. Check with: which next && npm ls next"
fi

echo
echo "== Step 5: verifying the build =="
npm run build

echo
echo "== Step 6: push =="
cd ..
git push origin main

echo
echo "Done."