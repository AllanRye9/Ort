#!/usr/bin/env bash
# Run this from the root of your actual working repo, e.g.:
#   cd /workspaces/Piitrade
#   bash fix-repo.sh
#
# Fixes, in order:
#   1. Confirms/repairs the git remote name (was "orgin" instead of "origin")
#   2. Pulls remote changes before pushing (fixes "failed to push some refs")
#   3. Stops tracking the .next/ build cache that was getting committed
#   4. Does a truly clean reinstall of frontend/node_modules so the
#      installed Next.js version matches package-lock.json (15.5.23),
#      instead of the mismatched 16.3.2 that broke the build

set -euo pipefail

echo "== Step 1: checking git remotes =="
git remote -v

if git remote get-url orgin >/dev/null 2>&1; then
  echo "Found misnamed remote 'orgin' -> renaming to 'origin'"
  git remote rename orgin origin
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "ERROR: no 'origin' remote found. Add it manually with:"
  echo "  git remote add origin https://github.com/AllanRye9/Piitrade"
  exit 1
fi

echo
echo "== Step 2: pulling remote changes before pushing =="
git fetch origin
git pull origin main --rebase || {
  echo
  echo "Rebase hit conflicts (likely in frontend/.next/cache/*.sst — disposable build cache)."
  echo "Resolve with, e.g.:"
  echo "  git checkout --ours frontend/.next/ && git add frontend/.next/ && git rebase --continue"
  exit 1
}

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
echo "== Step 4: clean reinstall of frontend dependencies =="
cd frontend
rm -rf node_modules package-lock.json.bak 2>/dev/null || true
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
