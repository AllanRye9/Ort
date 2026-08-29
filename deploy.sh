#!/usr/bin/env bash
set -euo pipefail

trap 'echo "Script failed at line ${LINENO}." >&2' ERR

# ============================================================
# Configuration
# ============================================================

FRONTEND_DIR="frontend"
BACKEND_DIR="backend"

PRISMA_SCHEMA="./prisma/schema.prisma"
PRISMA_HOTFIX_DIR="./prisma/hotfixes"

# ============================================================
# Validate repository state
# ============================================================

if [[ -n "$(git ls-files -u)" ]]; then
  echo "Unresolved merge conflicts detected. Resolve conflicts, stage the files, and commit before running this script." >&2
  exit 1
fi

# ============================================================
# Stash local changes if any
# ============================================================

stash_output=$(git stash 2>&1 || true)

need_apply=false

if [[ "$stash_output" != "No local changes" ]]; then
  need_apply=true
  echo "Local changes were stashed."
fi

# ============================================================
# Pull latest main
# ============================================================

echo ""
echo "========================================"
echo "Pulling latest main"
echo "========================================"

git pull --ff-only origin main

# ============================================================
# Reapply local changes
# ============================================================

if [ "$need_apply" = true ]; then
  echo ""
  echo "Reapplying stashed local changes..."

  git stash apply

  if [[ -n "$(git ls-files -u)" ]]; then
    echo "Reapplying stashed changes on top of origin/main produced merge conflicts." >&2
    echo "Resolve them manually, then re-run this script." >&2
    echo "The stash is preserved: git stash list" >&2
    exit 1
  fi
fi

# ============================================================
# Validate project structure
# ============================================================

if [ ! -d "$FRONTEND_DIR" ] || [ ! -d "$BACKEND_DIR" ]; then
  echo "Expected frontend and backend directories in repository root." >&2
  exit 1
fi

# ============================================================
# Frontend
# ============================================================

echo ""
echo "========================================"
echo "Building frontend"
echo "========================================"

pushd "$FRONTEND_DIR" > /dev/null

rm -rf node_modules package-lock.json

npm install

npm run build

popd > /dev/null

echo "Frontend build completed successfully."

# ============================================================
# Backend
# ============================================================

if [ -f "$BACKEND_DIR/package.json" ]; then

  echo ""
  echo "========================================"
  echo "Building backend"
  echo "========================================"

  pushd "$BACKEND_DIR" > /dev/null

  rm -rf node_modules package-lock.json

  npm install

  # ==========================================================
  # Prisma
  # ==========================================================
  #
  # Prisma is optional.
  #
  # We only run Prisma commands when the local Prisma CLI
  # actually exists in node_modules.
  #
  # This prevents npx from attempting to download Prisma and
  # allows the deployment to continue without Prisma.
  # ==========================================================

  PRISMA_AVAILABLE=false

  if [ -x "./node_modules/.bin/prisma" ]; then
    PRISMA_AVAILABLE=true
    echo "Prisma CLI found."
  else
    echo ""
    echo "Prisma CLI not found."
    echo "Skipping Prisma client generation and database operations."
  fi

  # ==========================================================
  # Generate Prisma client
  # ==========================================================

  if [ "$PRISMA_AVAILABLE" = true ]; then

    echo ""
    echo "Generating Prisma client..."

    ./node_modules/.bin/prisma generate

    echo "Prisma client generated successfully."

  fi

  # ==========================================================
  # Build backend before touching the database
  # ==========================================================

  echo ""
  echo "Building backend..."

  npm run build

  echo "Backend build completed successfully."

  # ==========================================================
  # Database URL
  # ==========================================================

  if [ "$PRISMA_AVAILABLE" = true ]; then

    if [ -n "${DATABASE_PRIVATE_URL:-}" ]; then
      echo "Using DATABASE_PRIVATE_URL for database operations."
      export DATABASE_URL="${DATABASE_PRIVATE_URL}"
    fi

    # ========================================================
    # Database migrations + hotfixes
    # ========================================================

    if [ -n "${DATABASE_URL:-}" ]; then

      echo ""
      echo "========================================"
      echo "Database deployment"
      echo "========================================"

      # ======================================================
      # Prisma migrations
      # ======================================================
      #
      # Prisma automatically discovers every migration under:
      #
      #   prisma/migrations/
      #
      # No migration filenames need to be listed here.
      # ======================================================

      echo ""
      echo "Running Prisma migrations..."

      DEPLOY_OUTPUT=$(
        ./node_modules/.bin/prisma migrate deploy 2>&1
      ) && DEPLOY_OK=1 || DEPLOY_OK=0

      echo "$DEPLOY_OUTPUT"

      # ======================================================
      # Failed migration recovery
      # ======================================================

      if [ "$DEPLOY_OK" = "0" ]; then

        echo ""
        echo "========================================"
        echo "Prisma migration failure detected"
        echo "========================================"

        echo "Attempting to identify failed migrations..."

        # Prisma normally reports failures in a format similar to:
        #
        # The `20260829094500_example` migration started at ...
        # failed
        #
        # Extract the migration name between backticks.

        FAILED_MIGRATIONS=$(
          echo "$DEPLOY_OUTPUT" |
            sed -n 's/.*`\([^`]*\)` migration.*failed.*/\1/p' |
            sort -u
        )

        if [ -n "$FAILED_MIGRATIONS" ]; then

          echo ""
          echo "Failed migration(s) detected:"

          while IFS= read -r migration; do
            [ -z "$migration" ] && continue
            echo "  - $migration"
          done <<< "$FAILED_MIGRATIONS"

          echo ""

          # Resolve every failed migration dynamically.
          while IFS= read -r migration; do

            [ -z "$migration" ] && continue

            echo "Marking migration '$migration' as rolled back..."

            ./node_modules/.bin/prisma migrate resolve \
              --rolled-back "$migration" || true

          done <<< "$FAILED_MIGRATIONS"

          echo ""
          echo "Retrying Prisma migrations..."

          ./node_modules/.bin/prisma migrate deploy

        else

          echo ""
          echo "Prisma migrate deploy failed, but no failed migration name could be parsed." >&2
          echo "The database deployment has been stopped." >&2

          exit 1

        fi

      else

        echo ""
        echo "Prisma migrations completed successfully."

      fi

      # ========================================================
      # Dynamic SQL hotfix discovery
      # ========================================================
      #
      # Every .sql file directly inside prisma/hotfixes is
      # automatically executed.
      #
      # No filenames need to be hardcoded in this script.
      #
      # Files are sorted alphabetically so execution is
      # deterministic.
      #
      # Recommended naming:
      #
      #   001_ensure_listing_inventory_columns.sql
      #   002_ensure_coupon_used_count.sql
      #   003_ensure_site_stat_table.sql
      #
      # Existing filenames without numeric prefixes also work.
      # ========================================================

      echo ""
      echo "========================================"
      echo "Database compatibility hotfixes"
      echo "========================================"

      if [ -d "$PRISMA_HOTFIX_DIR" ]; then

        # Use null-delimited output so filenames containing spaces
        # are handled safely.
        mapfile -d '' HOTFIXES < <(
          find "$PRISMA_HOTFIX_DIR" \
            -maxdepth 1 \
            -type f \
            -name '*.sql' \
            -print0 |
            sort -z
        )

        if [ "${#HOTFIXES[@]}" -eq 0 ]; then

          echo "No SQL hotfixes found in $PRISMA_HOTFIX_DIR."

        else

          echo "Found ${#HOTFIXES[@]} SQL hotfix(es)."

          HOTFIX_FAILURES=0

          for hotfix in "${HOTFIXES[@]}"; do

            echo ""
            echo "----------------------------------------"
            echo "Applying hotfix:"
            echo "$hotfix"
            echo "----------------------------------------"

            if ./node_modules/.bin/prisma db execute \
              --file "$hotfix" \
              --schema "$PRISMA_SCHEMA"; then

              echo "Hotfix completed successfully:"
              echo "$hotfix"

            else

              HOTFIX_FAILURES=$((HOTFIX_FAILURES + 1))

              echo ""
              echo "WARNING: Hotfix failed:"
              echo "$hotfix"
              echo "Continuing with remaining hotfixes..."

            fi

          done

          echo ""
          echo "----------------------------------------"
          echo "Hotfix summary"
          echo "----------------------------------------"
          echo "Hotfixes found:    ${#HOTFIXES[@]}"
          echo "Hotfixes failed:   $HOTFIX_FAILURES"
          echo "----------------------------------------"

        fi

      else

        echo "No hotfix directory found at:"
        echo "$PRISMA_HOTFIX_DIR"
        echo "Skipping database hotfixes."

      fi

      echo ""
      echo "Database deployment completed."

    else

      echo ""
      echo "No DATABASE_URL set."
      echo "Skipping Prisma migrations and database hotfixes."

    fi

  else

    echo ""
    echo "Prisma is not installed."
    echo "Skipping Prisma client generation, migrations, and hotfixes."

  fi

  popd > /dev/null

else

  echo ""
  echo "Warning: backend/package.json not found."
  echo "Skipping backend build and database deployment."

fi

# ============================================================
# Commit generated/build changes
# ============================================================

echo ""
echo "========================================"
echo "Checking for changes"
echo "========================================"

git add .

if git diff --cached --quiet; then

  echo "Build completed, but there are no changes to commit."
  exit 0

fi

# ============================================================
# Commit
# ============================================================

echo ""
echo "Committing changes..."

git commit -m "$(TZ=Asia/Dubai date +'')"

# ============================================================
# Push
# ============================================================

echo ""
echo "Pushing to origin/main..."

git push origin main

echo ""
echo "========================================"
echo "Deployment completed successfully"
echo "========================================"

echo "Done!"