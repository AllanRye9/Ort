
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

echo
echo "== Step 5: verifying the build =="
npm run build

echo
echo "== Step 6: push =="
cd ..
git push origin main

echo
echo "Done."