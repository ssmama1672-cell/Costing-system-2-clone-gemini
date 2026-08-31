#!/usr/bin/env bash
set -e

SNAPSHOT_FILE="COMPLETE_SYSTEM_SNAPSHOT.txt"
rm -f "${SNAPSHOT_FILE}"

echo "=================================================================" >> "${SNAPSHOT_FILE}"
echo "PRODUCT COSTING & MIS CONTROL SYSTEM - FULL SOURCE CODE & LOGIC DUMP" >> "${SNAPSHOT_FILE}"
echo "Generated on: $(date)" >> "${SNAPSHOT_FILE}"
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')" >> "${SNAPSHOT_FILE}"
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" >> "${SNAPSHOT_FILE}"
echo "=================================================================" >> "${SNAPSHOT_FILE}"

append_source() {
  local filepath="$1"
  local label="$2"
  
  echo -e "\n\n" >> "${SNAPSHOT_FILE}"
  echo "#################################################################" >> "${SNAPSHOT_FILE}"
  echo "### [${label}] --> ${filepath}" >> "${SNAPSHOT_FILE}"
  echo "#################################################################" >> "${SNAPSHOT_FILE}"
  
  if [ -f "$filepath" ]; then
    cat "$filepath" >> "${SNAPSHOT_FILE}"
  else
    echo "[FILE MISSING: ${filepath}]" >> "${SNAPSHOT_FILE}"
  fi
}

# 1. Project Configs
append_source "package.json" "CONFIG: Dependencies & Scripts"
append_source "vite.config.js" "CONFIG: Vite & Tailwind Setup"

# 2. Main Entry & Navigation Shell
append_source "src/main.jsx" "ENTRY: React Root Bootstrap"
append_source "src/App.jsx" "ROUTER: Navigation & Tab Orchestrator"

# 3. Core Shared Services & State
append_source "src/shared/masterStore.js" "STORE: Global Master Store & Persistence"
append_source "src/shared/costCalculationService.js" "ENGINE: Atomberg & Haier 38-Line Costing Engines"

# 4. Module 0: Executive Dashboard
append_source "src/modules/module0-dashboard/DashboardPage.jsx" "MODULE 0: Executive Dashboard View"

# 5. Module 1: Baseline Master & Modal Engine
append_source "src/modules/module1-baseline/BaselineMasterPage.jsx" "MODULE 1: Baseline Master & Excel Ingestion"
append_source "src/modules/module1-baseline/InlineEditModal.jsx" "MODULE 1: 38-Line Dual Column Inline Edit Modal"

# 6. Module 2: RM Price Matrix & WA Engine
append_source "src/modules/module2-rm-matrix/RMPriceMatrixPage.jsx" "MODULE 2: RM Matrix & Multi-Alternate WA Engine"

# 7. Module 3: Costing Run Engine
append_source "src/modules/module3-costing-engine/CostingRunEnginePage.jsx" "MODULE 3: Running Cost Simulation & Comparison Engine"

# 8. Module 4: MIS Variance & Gap Analysis
append_source "src/modules/module4-mis/MISVariancePage.jsx" "MODULE 4: Dynamic MIS Variance & Root Cause Gap Drilldown"

# 9. Module 5: AI Analyst & Reporting
append_source "src/modules/module5-ai-analyst/AIAnalystPage.jsx" "MODULE 5: AI Ad-Hoc Analytics & Reporting Assistant"

echo ""
echo "✅ Complete system snapshot generated: ${SNAPSHOT_FILE}"
echo "Total lines captured: $(wc -l < "${SNAPSHOT_FILE}")"
echo "Ready to copy and paste for reference."
