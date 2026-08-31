#!/usr/bin/env bash
set -e

OUTPUT_FILE="project_context_dump.txt"

echo "Generating full project context dump into ${OUTPUT_FILE}..."
rm -f "${OUTPUT_FILE}"

write_section() {
    local header="$1"
    echo -e "\n========================================================" >> "${OUTPUT_FILE}"
    echo -e "=== ${header}" >> "${OUTPUT_FILE}"
    echo -e "========================================================\n" >> "${OUTPUT_FILE}"
}

append_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo -e "\n--- START FILE: ${file} ---" >> "${OUTPUT_FILE}"
        cat "$file" >> "${OUTPUT_FILE}"
        echo -e "\n--- END FILE: ${file} ---" >> "${OUTPUT_FILE}"
    else
        echo -e "\n[FILE NOT FOUND: ${file}]" >> "${OUTPUT_FILE}"
    fi
}

# 1. Environment and Git State
write_section "1. GIT & ENVIRONMENT STATUS"
echo "Date: $(date)" >> "${OUTPUT_FILE}"
echo -e "\nCurrent Branch & Commit:" >> "${OUTPUT_FILE}"
git branch -v >> "${OUTPUT_FILE}" 2>&1 || true
git log -n 5 --oneline >> "${OUTPUT_FILE}" 2>&1 || true
echo -e "\nGit Status:" >> "${OUTPUT_FILE}"
git status --short >> "${OUTPUT_FILE}" 2>&1 || true

# 2. Directory Structure
write_section "2. SOURCE TREE DIRECTORY LAYOUT"
if command -v tree >/dev/null 2>&1; then
    tree src >> "${OUTPUT_FILE}" 2>&1 || true
else
    find src -maxdepth 4 -not -path '*/.*' | sort >> "${OUTPUT_FILE}" 2>&1 || true
fi

# 3. Package & Config Files
write_section "3. DEPENDENCIES & PROJECT CONFIG"
append_file "package.json"
append_file "vite.config.js"
append_file ".github/workflows/supabase-keep-alive.yml"

# 4. Core Shared Stores & Costing Engines
write_section "4. CORE SHARED SERVICES & STORES"
append_file "src/shared/masterStore.js"
append_file "src/shared/costCalculationService.js"
append_file "src/shared/supabaseClient.js"

# 5. Baseline Master Module (Costing Line Engines & Modals)
write_section "5. MODULE 1: BASELINE MASTER"
append_file "src/modules/module1-baseline/InlineEditModal.jsx"
append_file "src/modules/module1-baseline/BaselineMasterPage.jsx"

# 6. RM & Matrix Module (WA Engine)
write_section "6. MODULE 2: RM MATRIX & WA ENGINE"
append_file "src/modules/module2-matrix/RmMatrixPage.jsx"

# 7. Purchases & Sales Modules
write_section "7. MODULES 3 & 4: INWARD PURCHASES & SALES DISPATCH"
append_file "src/modules/module3-purchases/PurchasesPage.jsx"
append_file "src/modules/module4-sales/SalesPage.jsx"

# 8. MIS & AI Reporting
write_section "8. MIS ENGINE & REPORTING"
append_file "src/modules/module5-mis/MisGapPage.jsx"
append_file "src/modules/module6-ai/AiAssistantPage.jsx"

echo "✅ Project context dump successfully generated: ${OUTPUT_FILE}"
echo "Summary size: $(wc -l < "${OUTPUT_FILE}") lines"
