#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="backups/checkpoint_${TIMESTAMP}"
ARCHIVE_NAME="cpc_costing_system_backup_${TIMESTAMP}.tar.gz"

echo "==> 1. Ensuring git working directory is clean and committed..."
git add -A
git commit -m "checkpoint: full stable system state (${TIMESTAMP}) - 38-line costing, RM matrix, MIS & styling" || echo "Working tree clean."

echo "==> 2. Creating permanent Git checkpoint tag..."
git tag -f -a "checkpoint-${TIMESTAMP}" -m "Stable checkpoint created at ${TIMESTAMP}"
git tag -f -a "checkpoint-latest" -m "Latest verified stable state"

echo "==> 3. Creating backup archive directory..."
mkdir -p "${BACKUP_DIR}"

echo "==> 4. Bundling complete project archive (excluding node_modules & build artifacts)..."
tar --exclude='./node_modules' \
    --exclude='./dist' \
    --exclude='./.git' \
    --exclude='./backups' \
    -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" .

cp "${BACKUP_DIR}/${ARCHIVE_NAME}" "./${ARCHIVE_NAME}"

echo "==> 5. Generating one-click recovery script..."
cat << 'RECOVER_EOF' > restore_checkpoint.sh
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
RECOVER_EOF

chmod +x restore_checkpoint.sh

echo "==> 6. Testing build integrity..."
npm run build

echo "-------------------------------------------------------------------"
echo "✅ FULL BACKUP & CHECKPOINT COMPLETE!"
echo "   • Git Tag:       checkpoint-${TIMESTAMP} & checkpoint-latest"
echo "   • Standalone Tar: ${ARCHIVE_NAME}"
echo "   • Recovery Tool: ./restore_checkpoint.sh"
echo "-------------------------------------------------------------------"
