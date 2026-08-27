cd frontend && rm package-lock.json node_module && npm install 
npm run build && cd ../backend && rm package-lock.json node_module && npm install && npm build ; cd ..
git add .; git commit -m"$(TZ='Asia/Dubai' date +'%Y-%m-%d %H:%M:%S')" && git push