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
#   4. Does a truly clean reinstall of frontend/node_modules, and — unlike
#      before — actively FORCES the exact pinned Next.js version (15.5.23)
#      back into place if anything resolves to a different one, instead of
#      just printing a warning and building anyway. That's what let Next.js
#      16.3.3 silently run last time: the eslint-config-rejected and
#      middleware-deprecated errors you hit are both 16.x-only messages —
#      symptoms of the wrong major version, not separate bugs.
#   5. Verifies the build
#   6. Pushes

set -euo pipefail

echo "== Step 0: ensuring git identity is configured =="
if [ -z "$(git config user.email || true)" ]; then
  git config user.email "${GIT_AUTHOR_EMAIL:-ci@piitrade.local}"
  echo "Set user.email to $(git config user.email) (override by exporting GIT_AUTHOR_EMAIL before running)"
fi
if [ -z "$(git config user.name || true)" ]; then
  git config user.name "${GIT_AUTHOR_NAME:-Piitrade Bot}"
  echo "Set user.name to $(git config user.name) (override by exporting GIT_AUTHOR_NAME before running)"
fi

echo
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

STASHED=0
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Local changes detected — stashing them before pulling."
  git stash push -u -m "fix-repo.sh: auto-stash before pull ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  STASHED=1
else
  echo "Working tree clean — nothing to stash."
fi

if ! git pull origin main --rebase; then
  echo
  echo "Rebase hit conflicts (likely in frontend/.next/cache/*.sst — disposable build cache)."
  echo "Resolve with, e.g.:"
  echo "  git checkout --ours frontend/.next/ && git add frontend/.next/ && git rebase --continue"
  if [[ "$STASHED" -eq 1 ]]; then
    echo
    echo "NOTE: your local changes are safely stashed (not lost)."
    echo "After the rebase finishes, restore them with: git stash pop"
  fi
  exit 1
fi

if [[ "$STASHED" -eq 1 ]]; then
  echo "Restoring stashed local changes..."
  if ! git stash pop; then
    echo
    echo "Restoring the stash hit conflicts. Resolve them manually, then:"
    echo "  git add -A && git stash drop   # once you're happy with the merge"
    exit 1
  fi
  echo "Stashed changes restored."
fi

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
echo "== Step 4: pinning and installing frontend dependencies =="
cd frontend

# The version this project is meant to run. Update this constant (not the
# check logic below) if you deliberately upgrade Next.js on purpose.
EXPECTED_NEXT_VERSION="15.5.23"

CURRENT_SPEC=$(node -p "
  const pkg = require('./package.json');
  (pkg.dependencies && pkg.dependencies.next) || (pkg.devDependencies && pkg.devDependencies.next) || '(not found)'
")
echo "frontend/package.json currently specifies next: \"$CURRENT_SPEC\""

rm -rf node_modules
npm ci

INSTALLED_NEXT=$(node -p "require('./node_modules/next/package.json').version" 2>/dev/null || echo "MISSING")
echo "Installed Next.js version after npm ci: $INSTALLED_NEXT"

if [[ "$INSTALLED_NEXT" != "$EXPECTED_NEXT_VERSION" ]]; then
  echo
  echo "Installed Next.js ($INSTALLED_NEXT) does not match the pinned version"
  echo "($EXPECTED_NEXT_VERSION). This is what caused last run's build to fail"
  echo "with '\"eslint\" is no longer supported in next.config.mjs' and the"
  echo "'middleware is deprecated, use proxy' warning — both are Next 16-only"
  echo "messages that go away once the correct 15.x is actually running."
  echo
  echo "Most likely cause: frontend/package.json's \"next\" entry drifted off"
  echo "the exact pin (e.g. someone ran 'npm install next@latest' here and"
  echo "committed it), or a root-level package.json with npm workspaces is"
  echo "hoisting a different 'next' from /workspaces/Piitrade/node_modules —"
  echo "running 'npm ci' from inside a workspace member folder doesn't fully"
  echo "isolate it from whatever the workspace root resolves."
  echo
  echo "Forcing the exact pinned version back into place..."
  BAD_VERSION="$INSTALLED_NEXT"
  npm install "next@${EXPECTED_NEXT_VERSION}" --save-exact

  INSTALLED_NEXT=$(node -p "require('./node_modules/next/package.json').version")
  echo "Installed Next.js version after re-pin: $INSTALLED_NEXT"

  if [[ "$INSTALLED_NEXT" != "$EXPECTED_NEXT_VERSION" ]]; then
    echo
    echo "ERROR: still not on $EXPECTED_NEXT_VERSION after forcing the exact"
    echo "version. Something outside npm's normal resolution is overriding"
    echo "it. Check:"
    echo "  which next"
    echo "  npm ls next"
    echo "  cat ../package.json | grep -A5 workspaces   # if this exists at"
    echo "                                              # the repo root, the"
    echo "                                              # fix belongs there,"
    echo "                                              # not in frontend/."
    npm ls next || true
    exit 1
  fi

  echo "Re-pinned successfully — committing the corrected package.json/package-lock.json."
  git add package.json package-lock.json
  git commit -m "Re-pin next to ${EXPECTED_NEXT_VERSION} (was resolving to ${BAD_VERSION})"
fi

echo
echo "== Step 5: verifying the build =="
echo "Available memory:"
free -h 2>/dev/null || vm_stat 2>/dev/null || echo "(could not detect — neither 'free' nor 'vm_stat' is available)"

# "Next.js build worker exited with code: null and signal: SIGTERM" almost
# always means the OS or a container/cgroup memory limit killed a build
# worker process — not a code bug. Two mitigations that don't require
# knowing the exact memory ceiling in advance:
#   - Give Node a heap ceiling a bit BELOW whatever RAM is actually
#     available. Counter-intuitively, raising --max-old-space-size doesn't
#     help an environment that's genuinely memory-constrained — it just lets
#     V8 grow further before garbage-collecting, which can make a real OOM
#     kill happen *later* but *harder*. 2048 MB is a conservative default
#     for typical 4GB CI runners / Codespaces; override by exporting
#     NODE_OPTIONS yourself first if you know your container's actual limit.
#   - Cap Next's parallel static-generation workers (see the printed
#     guidance below on failure) — this script can't safely do that
#     automatically since it would mean blindly editing
#     frontend/next.config.mjs without having seen its current contents.
if [ -z "${NODE_OPTIONS:-}" ]; then
  export NODE_OPTIONS="--max-old-space-size=2048"
  echo "NODE_OPTIONS not set — defaulting to --max-old-space-size=2048."
fi

if ! npm run build; then
  echo
  echo "Build failed. If the error above was:"
  echo "  'Next.js build worker exited with code: null and signal: SIGTERM'"
  echo "that's almost always an out-of-memory kill, not a code bug:"
  echo
  echo "  1. Add experimental.cpus = 1 to frontend/next.config.mjs, e.g.:"
  echo "       const nextConfig = {"
  echo "         experimental: { cpus: 1 },"
  echo "         // ...your existing config keys stay as they are"
  echo "       };"
  echo "     This caps Next to one build worker at a time instead of"
  echo "     spawning one per CPU core, which is usually what exhausts"
  echo "     memory on constrained containers/CI runners."
  echo "  2. If it still fails after that, try a lower heap ceiling, e.g.:"
  echo "       NODE_OPTIONS='--max-old-space-size=1536' bash fix-repo.sh"
  echo "  3. If it still fails after both, the container/runner most likely"
  echo "     needs more RAM than it currently has — check your"
  echo "     Codespace/CI machine tier against the 'Available memory' line"
  echo "     printed above."
  exit 1
fi

echo
echo "== Step 6: push =="
cd ..
git push origin main

echo
echo "Done."