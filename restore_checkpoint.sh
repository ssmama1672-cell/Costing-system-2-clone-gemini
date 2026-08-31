#!/usr/bin/env bash
set -e

echo "==> Restoring system from latest checkpoint tag..."
git checkout checkpoint-latest

echo "==> Verifying dependencies and build..."
npm install
npm run build

echo "==> Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "✅ System restored to checkpoint-latest and running on http://localhost:5173"
