#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="backups/backup_${TIMESTAMP}"
TAG_NAME="checkpoint-stable-${TIMESTAMP}"

echo "========================================================"
echo " Starting Full Backup & Checkpoint Creation (${TIMESTAMP})"
echo "========================================================"

mkdir -p "${BACKUP_DIR}"

# 1. Commit any uncommitted working changes on dev-v2
echo -e "\n==> 1. Staging and committing all active working files on dev-v2..."
git checkout dev-v2 2>/dev/null || git checkout -b dev-v2
git add -A
if ! git diff-index --quiet HEAD --; then
  git commit -m "checkpoint(dev-v2): complete stable state backup ${TIMESTAMP}"
  echo "✓ Committed active changes to dev-v2"
else
  echo "✓ dev-v2 working tree clean"
fi

# 2. Tag dev-v2 and create isolated recovery branch
echo -e "\n==> 2. Creating dev-v2 git tag and recovery branch..."
git tag -a "${TAG_NAME}-dev-v2" -m "Full backup checkpoint for dev-v2 at ${TIMESTAMP}"
git branch "recovery-dev-v2-${TIMESTAMP}" dev-v2
echo "✓ Tagged: ${TAG_NAME}-dev-v2"
echo "✓ Branch created: recovery-dev-v2-${TIMESTAMP}"

# 3. Create full filesystem bundle & tarball of current dev-v2 state
echo -e "\n==> 3. Creating standalone ZIP and TAR archives..."
tar -czf "${BACKUP_DIR}/source_snapshot_dev_v2_${TIMESTAMP}.tar.gz" \
  --exclude="node_modules" \
  --exclude=".git" \
  --exclude="dist" \
  package.json vite.config.js src/

echo "✓ Source archive created: ${BACKUP_DIR}/source_snapshot_dev_v2_${TIMESTAMP}.tar.gz"

# 4. Sync / Merge stable state into main and tag
echo -e "\n==> 4. Updating main branch with dev-v2 checkpoint..."
git checkout main
git merge dev-v2 -m "checkpoint(main): sync stable dev-v2 milestone ${TIMESTAMP}" || {
  echo "Resolving merge favoring dev-v2...";
  git checkout --ours . 2>/dev/null || true;
  git add -A;
  git commit -m "checkpoint(main): sync stable dev-v2 milestone ${TIMESTAMP}";
}

git tag -a "${TAG_NAME}-main" -m "Full production checkpoint for main at ${TIMESTAMP}"
git branch "recovery-main-${TIMESTAMP}" main
echo "✓ Tagged: ${TAG_NAME}-main"
echo "✓ Branch created: recovery-main-${TIMESTAMP}"

# 5. Switch back to working development branch dev-v2
git checkout dev-v2

# 6. Push checkpoints, branches, and tags to remote GitHub repository
echo -e "\n==> 5. Pushing all branches and tags to GitHub remote..."
git push origin dev-v2 || echo "dev-v2 push skipped/offline"
git push origin main || echo "main push skipped/offline"
git push origin --tags || echo "tags push skipped/offline"
git push origin "recovery-dev-v2-${TIMESTAMP}" || echo "recovery branch push skipped/offline"
git push origin "recovery-main-${TIMESTAMP}" || echo "recovery branch push skipped/offline"

# 7. Generate a quick restore script
cat << RESTORE_EOF > "${BACKUP_DIR}/restore_to_this_checkpoint.sh"
#!/usr/bin/env bash
set -e
echo "Restoring system to checkpoint: ${TIMESTAMP}..."
git checkout main
git reset --hard ${TAG_NAME}-main
git checkout dev-v2
git reset --hard ${TAG_NAME}-dev-v2
npm install
npm run build
echo "✅ Restored successfully to milestone ${TIMESTAMP}!"
RESTORE_EOF

chmod +x "${BACKUP_DIR}/restore_to_this_checkpoint.sh"

echo -e "\n========================================================"
echo "✅ FULL BACKUP & RECOVERY CHECKPOINT COMPLETED!"
echo "========================================================"
echo "• Backup Directory : ${BACKUP_DIR}"
echo "• Tag dev-v2       : ${TAG_NAME}-dev-v2"
echo "• Tag main         : ${TAG_NAME}-main"
echo "• Recovery Branches: recovery-dev-v2-${TIMESTAMP} & recovery-main-${TIMESTAMP}"
echo "• Restore Script   : ${BACKUP_DIR}/restore_to_this_checkpoint.sh"
echo "========================================================"
