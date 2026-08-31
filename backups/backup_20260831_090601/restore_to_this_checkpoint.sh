#!/usr/bin/env bash
set -e
echo "Restoring system to checkpoint: 20260831_090601..."
git checkout main
git reset --hard checkpoint-stable-20260831_090601-main
git checkout dev-v2
git reset --hard checkpoint-stable-20260831_090601-dev-v2
npm install
npm run build
echo "✅ Restored successfully to milestone 20260831_090601!"
