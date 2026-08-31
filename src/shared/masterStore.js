// ============================================================================
// GLOBAL MASTER DATA STORE (Multi-Select Alternate Lots, Qty & Combined WA)
// ============================================================================

const STORAGE_KEY = 'CPC_MASTER_STORE_DEV_V2_MULTI_ALT_WA_V2';

export function normalizeVendorId(vendor) {
  if (!vendor) return 'haier';
  const v = vendor.toString().toLowerCase().trim();
  if (v.includes('atomberg')) return 'atomberg';
  if (v.includes('atharva')) return 'atharva';
  if (v.includes('haier')) return 'haier';
  return v;
}

export function isInvalidMaterialCode(code) {
  if (!code) return true;
  const s = String(code).toLowerCase().trim();
  return (
    s === '' ||
    s === '-' ||
    s === 'nan' ||
    s === 'null' ||
    s === 'undefined' ||
    s === 'fixed as per upload' ||
    s === 'description' ||
    s === 'uom' ||
    s === 'name of component' ||
    s === 'raw material required' ||
    s === 'mb code' ||
    !isNaN(Number(s))
  );
}

export function sanitizeMaterialName(matStr, compName = '', itemCode = '', vendor = 'haier') {
  if (!matStr || String(matStr).trim() === '' || String(matStr).trim() === 'nan') {
    matStr = '';
  } else {
    matStr = String(matStr).trim();
  }

  const isNumeric = !isNaN(Number(matStr)) && matStr !== '';
  if (isNumeric || isInvalidMaterialCode(matStr)) {
    const cUpper = (compName || '').toUpperCase();
    const vNorm = normalizeVendorId(vendor);

    if (cUpper.includes('HIPS')) {
      return vNorm === 'haier' ? 'HIPS SH303 + White MB' : 'HIPS SH303';
    } else if (cUpper.includes('PP')) {
      return vNorm === 'haier' ? 'PP B-400MN + White MB' : 'PP H110MA + Gloss White';
    } else if (cUpper.includes('ABS')) {
      return vNorm === 'haier' ? 'ABS 300- M Red' : 'ABS';
    } else if (cUpper.includes('PS')) {
      return 'HIPS SH03 + White MB';
    } else {
      return vNorm === 'haier' ? 'HIPS SH303 + White MB' : 'PP H110MA + Gloss White';
    }
  }

  return matStr;
}

export function parseMaterialString(rawMaterialStr) {
  if (!rawMaterialStr) return { baseRm: '', mbGrade: '' };
  const cleanStr = rawMaterialStr.toString().trim();
  if (cleanStr.includes('+')) {
    const parts = cleanStr.split('+').map(s => s.trim());
    return { baseRm: parts[0] || '', mbGrade: parts[1] || '' };
  }
  return { baseRm: cleanStr, mbGrade: '' };
}

// Compute Combined Weighted Average AND Total Inward Quantity
export function computeCombinedWeightedAverageWithQty(selectedCodesArray = [], approvedCode = '', approvedPrice = 0, vendor = 'haier') {
  const purchases = globalStore.purchases || [];
  const vNorm = normalizeVendorId(vendor);
  
  if (!Array.isArray(selectedCodesArray) || selectedCodesArray.length === 0) {
    return { waRate: Number(approvedPrice || 0), totalQty: 0 };
  }

  let totalQty = 0;
  let totalCost = 0;

  selectedCodesArray.forEach(code => {
    if (!code) return;
    const cClean = code.toString().toLowerCase().trim();
    const isBaseline = cClean === (approvedCode || '').toLowerCase().trim() || cClean.includes('contract baseline');

    if (!isBaseline) {
      const matching = purchases.filter(p => {
        const pGrade = (p.grade || p.itemCode || p.rawMaterial || p.supplier || '').toString().toLowerCase().trim();
        const pNorm = normalizeVendorId(p.vendor);
        const matchGrade = pGrade === cClean || pGrade.includes(cClean) || cClean.includes(pGrade);
        const matchVendor = !vendor || vNorm === 'all' || pNorm === vNorm;
        return matchGrade && matchVendor;
      });

      matching.forEach(m => {
        const qty = Number(m.qty || m.quantity || 0);
        const rate = Number(m.rate || m.netRate || m.price || 0);
        if (qty > 0 && rate > 0) {
          totalQty += qty;
          totalCost += (qty * rate);
        }
      });
    }
  });

  const waRate = totalQty > 0 ? Number((totalCost / totalQty).toFixed(2)) : Number(approvedPrice || 0);
  return { waRate, totalQty };
}

export function computeCombinedWeightedAverage(selectedCodesArray = [], approvedCode = '', approvedPrice = 0, vendor = 'haier') {
  return computeCombinedWeightedAverageWithQty(selectedCodesArray, approvedCode, approvedPrice, vendor).waRate;
}

export function computeGradeWeightedAverage(gradeOrCode, vendor) {
  return computeCombinedWeightedAverage([gradeOrCode], '', 0, vendor);
}

function loadPersistedStore() {
  if (typeof window === 'undefined') return null;
  try {
    const saved = localStorage.getItem(STORAGE_KEY) || localStorage.getItem('CPC_MASTER_STORE_DEV_V2_MULTI_ALT_WA_V1') || localStorage.getItem('CPC_MASTER_STORE_DEV_V2_PROD_RELEASE_V5');
    if (saved) {
      const parsed = JSON.parse(saved);
      if (parsed.rmMappingsData) {
        parsed.rmMappingsData = parsed.rmMappingsData.filter(r => !isInvalidMaterialCode(r.approvedCode)).map(r => {
          let selectedAlts = r.selectedAlts;
          if (!Array.isArray(selectedAlts)) {
            selectedAlts = [r.alt1Code || r.approvedCode].filter(Boolean);
          }
          return {
            ...r,
            selectedAlts
          };
        });
      }
      return parsed;
    }
  } catch (err) {
    console.error("Error loading store:", err);
  }
  return null;
}

const defaultStore = {
  isLocked: true,
  isMatrixLocked: true,
  vendors: [
    { vendorId: 'Haier Appliances', vendorName: 'Haier Appliances' },
    { vendorId: 'Atomberg Technologies', vendorName: 'Atomberg Technologies' },
    { vendorId: 'Atharva Polymer', vendorName: 'Atharva Polymer (Haier)' }
  ],
  vendorSchedules: {
    'Haier Appliances': { periodFrom: '2026-08-01', periodTo: '2026-08-31' },
    'Atomberg Technologies': { periodFrom: '2026-08-01', periodTo: '2026-08-31' },
    'Atharva Polymer': { periodFrom: '2026-08-01', periodTo: '2026-08-31' }
  },
  rmMappingsData: [],
  baselineProducts: [],
  purchases: [],
  sales: [],
  auditLogs: []
};

const initialStore = loadPersistedStore() || defaultStore;

export let globalStore = {
  ...defaultStore,
  ...initialStore,
  isLocked: initialStore.isLocked !== undefined ? initialStore.isLocked : true,
  isMatrixLocked: initialStore.isMatrixLocked !== undefined ? initialStore.isMatrixLocked : true,
  vendors: (initialStore.vendors && initialStore.vendors.length > 0) ? initialStore.vendors : defaultStore.vendors,
  vendorSchedules: initialStore.vendorSchedules || defaultStore.vendorSchedules,
  baselineProducts: initialStore.baselineProducts || [],
  rmMappingsData: (initialStore.rmMappingsData || []).filter(r => !isInvalidMaterialCode(r.approvedCode)),
  purchases: initialStore.purchases || [],
  sales: initialStore.sales || [],
  auditLogs: initialStore.auditLogs || []
};

function persistCurrentStore() {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(globalStore));
  } catch (err) {
    console.error("Error saving store:", err);
  }
}

let listeners = [];
export function subscribeStore(fn) {
  listeners.push(fn);
  return () => { listeners = listeners.filter(cb => cb !== fn); };
}

export function notifyStore() {
  persistCurrentStore();
  listeners.forEach(fn => { try { fn(globalStore); } catch (e) { console.error(e); } });
}

export function purgeAllTestData() {
  globalStore.rmMappingsData = [];
  globalStore.baselineProducts = [];
  globalStore.purchases = [];
  globalStore.sales = [];
  globalStore.auditLogs = [];
  notifyStore();
}

export function getActiveRmMapping(gradeName, vendor) {
  if (!gradeName) return { approvedCode: 'Unspecified', approvedPrice: 0, activeGrade: 'Unspecified', activeWaPrice: 0, isFound: false };
  const cleanGrade = sanitizeMaterialName(gradeName, '', '', vendor);
  const { baseRm } = parseMaterialString(cleanGrade);
  const targetCode = (baseRm || cleanGrade).toLowerCase().trim();
  const vNorm = normalizeVendorId(vendor);

  const found = (globalStore.rmMappingsData || []).find(r => 
    r.type === 'RM' && 
    normalizeVendorId(r.vendor) === vNorm && 
    (r.approvedCode.toLowerCase().trim() === targetCode || targetCode.includes(r.approvedCode.toLowerCase().trim()) || r.approvedCode.toLowerCase().trim().includes(targetCode))
  );

  if (found) {
    const selectedAlts = Array.isArray(found.selectedAlts) && found.selectedAlts.length > 0 
      ? found.selectedAlts 
      : [found.alt1Code || found.approvedCode];

    const { waRate, totalQty } = computeCombinedWeightedAverageWithQty(selectedAlts, found.approvedCode, found.approvedPrice, vendor);
    
    return { 
      approvedCode: found.approvedCode, 
      approvedPrice: Number(found.approvedPrice || 0), 
      activeGrade: selectedAlts.join(' + '), 
      activeWaPrice: Number(waRate || found.approvedPrice || 0), 
      selectedAlts,
      totalInwardQty: totalQty,
      isFound: true 
    };
  }

  const defaultRate = vNorm === 'atomberg' ? 131.00 : 154.00;
  return { approvedCode: baseRm || cleanGrade, approvedPrice: defaultRate, activeGrade: baseRm || cleanGrade, activeWaPrice: defaultRate, selectedAlts: [baseRm || cleanGrade], totalInwardQty: 0, isFound: false };
}

export function getActiveMbMapping(mbGradeName, vendor) {
  const vNorm = normalizeVendorId(vendor);
  let targetMb = (mbGradeName || '').toLowerCase().trim();
  if (!targetMb || targetMb === 'none' || !isNaN(Number(targetMb))) {
    return { approvedMbCode: 'None', approvedMbPrice: 0, activeMbGrade: 'None', activeMbWaPrice: 0, selectedAlts: [], totalInwardQty: 0, isFound: false };
  }

  const found = (globalStore.rmMappingsData || []).find(r => 
    r.type === 'MB' && 
    normalizeVendorId(r.vendor) === vNorm && 
    (r.approvedCode.toLowerCase().trim() === targetMb || targetMb.includes(r.approvedCode.toLowerCase().trim()) || r.approvedCode.toLowerCase().trim().includes(targetMb))
  );

  if (found) {
    const selectedAlts = Array.isArray(found.selectedAlts) && found.selectedAlts.length > 0 
      ? found.selectedAlts 
      : [found.alt1Code || found.approvedCode];

    const { waRate, totalQty } = computeCombinedWeightedAverageWithQty(selectedAlts, found.approvedCode, found.approvedPrice, vendor);

    return { 
      approvedMbCode: found.approvedCode, 
      approvedMbPrice: Number(found.approvedPrice || 0), 
      activeMbGrade: selectedAlts.join(' + '), 
      activeMbWaPrice: Number(waRate || found.approvedPrice || 0), 
      selectedAlts,
      totalInwardQty: totalQty,
      isFound: true 
    };
  }

  const defaultMbRate = vNorm === 'atomberg' ? 154.00 : 242.00;
  return { approvedMbCode: mbGradeName, approvedMbPrice: defaultMbRate, activeMbGrade: mbGradeName, activeMbWaPrice: defaultMbRate, selectedAlts: [mbGradeName], totalInwardQty: 0, isFound: false };
}

export function addOrUpdateVendorMaterial(item) {
  if (!globalStore.rmMappingsData) globalStore.rmMappingsData = [];
  const vNorm = normalizeVendorId(item.vendor);
  const cleanCode = sanitizeMaterialName(item.approvedCode, '', '', item.vendor);
  if (isInvalidMaterialCode(cleanCode)) return;

  const idx = globalStore.rmMappingsData.findIndex(r => 
    normalizeVendorId(r.vendor) === vNorm && 
    r.type === item.type && 
    r.approvedCode.toLowerCase().trim() === cleanCode.toLowerCase().trim()
  );

  if (idx >= 0) {
    globalStore.rmMappingsData[idx] = { 
      ...globalStore.rmMappingsData[idx], 
      ...item,
      approvedCode: cleanCode,
      selectedAlts: item.selectedAlts || globalStore.rmMappingsData[idx].selectedAlts || [cleanCode],
      vendor: item.vendor || globalStore.rmMappingsData[idx].vendor 
    };
  } else {
    globalStore.rmMappingsData.push({ 
      id: `mat-${vNorm}-${Date.now()}-${Math.random().toString(36).substr(2,4)}`, 
      ...item,
      approvedCode: cleanCode,
      selectedAlts: item.selectedAlts || [cleanCode]
    });
  }
  notifyStore();
}

export function updateRmMappingRow(rowId, updatedFields) {
  if (!globalStore.rmMappingsData) globalStore.rmMappingsData = [];
  const idx = globalStore.rmMappingsData.findIndex(r => r.id === rowId);
  if (idx >= 0) {
    globalStore.rmMappingsData[idx] = { ...globalStore.rmMappingsData[idx], ...updatedFields };
    notifyStore();
  }
}

export function deleteVendorMaterial(id, vendor) {
  const target = (globalStore.rmMappingsData || []).find(r => r.id === id);
  const matCode = target?.approvedCode || id;
  globalStore.rmMappingsData = (globalStore.rmMappingsData || []).filter(r => r.id !== id);

  addAuditLog({
    partCode: 'RM_MATRIX',
    componentName: `Deleted Material Grade: ${matCode}`,
    vendor: vendor || target?.vendor || 'ALL',
    modifications: `Removed ${matCode} from matrix registry`,
    costImpact: 'Matrix Updated',
    reason: 'Manual Material Deletion'
  });

  notifyStore();
}

export function getProductsUsingMaterial(matCode, vendor) {
  if (!matCode) return [];
  const vNorm = normalizeVendorId(vendor);
  const codeClean = matCode.toLowerCase().trim();

  return (globalStore.baselineProducts || []).filter(p => {
    const matchVendor = vendor === 'ALL' || normalizeVendorId(p.vendor) === vNorm;
    if (!matchVendor) return false;

    const { baseRm, mbGrade } = parseMaterialString(p.approvedRm || p.baseRm);
    const rmMatch = (baseRm || '').toLowerCase().trim() === codeClean || (p.baseRm || '').toLowerCase().trim() === codeClean;
    const mbMatch = (mbGrade || '').toLowerCase().trim() === codeClean || (p.approvedMb || '').toLowerCase().trim() === codeClean;

    return rmMatch || mbMatch;
  });
}

export function saveVendorPeriodSchedule({ vendor, periodFrom, periodTo }) {
  if (!globalStore.vendorSchedules) globalStore.vendorSchedules = {};
  const vNorm = normalizeVendorId(vendor);

  globalStore.vendorSchedules[vendor] = {
    periodFrom,
    periodTo,
    savedAt: new Date().toISOString()
  };

  (globalStore.rmMappingsData || []).forEach(r => {
    if (normalizeVendorId(r.vendor) === vNorm) {
      r.periodFrom = periodFrom;
      r.periodTo = periodTo;
    }
  });

  const vendorMaterials = (globalStore.rmMappingsData || []).filter(r => 
    normalizeVendorId(r.vendor) === vNorm
  );

  (globalStore.baselineProducts || []).forEach(prod => {
    if (normalizeVendorId(prod.vendor) === vNorm) {
      const cleanRm = sanitizeMaterialName(prod.approvedRm || prod.baseRm, prod.componentName, prod.itemCode, prod.vendor);
      const { baseRm, mbGrade } = parseMaterialString(cleanRm);
      const matchedRm = vendorMaterials.find(m => m.type === 'RM' && m.approvedCode.toLowerCase().trim() === (baseRm || '').toLowerCase().trim());
      const matchedMb = vendorMaterials.find(m => m.type === 'MB' && m.approvedCode.toLowerCase().trim() === (mbGrade || '').toLowerCase().trim());

      if (matchedRm) {
        const selectedAlts = matchedRm.selectedAlts || [matchedRm.approvedCode];
        const waPrice = computeCombinedWeightedAverage(selectedAlts, matchedRm.approvedCode, matchedRm.approvedPrice, vendor);
        prod.approvedRmPrice = Number(matchedRm.approvedPrice || prod.approvedRmPrice || 0);
        prod.activeRmWaPrice = Number(waPrice || matchedRm.approvedPrice);
      }
      if (matchedMb) {
        const selectedAlts = matchedMb.selectedAlts || [matchedMb.approvedCode];
        const waPrice = computeCombinedWeightedAverage(selectedAlts, matchedMb.approvedCode, matchedMb.approvedPrice, vendor);
        prod.approvedMbPrice = Number(matchedMb.approvedPrice || prod.approvedMbPrice || 0);
        prod.activeMbWaPrice = Number(waPrice || matchedMb.approvedPrice);
      }
    }
  });

  addAuditLog({
    partCode: 'RM_MATRIX',
    componentName: `Saved Matrix Schedule for ${vendor}`,
    vendor: vendor,
    modifications: `Period: ${periodFrom} to ${periodTo} • ${vendorMaterials.length} Materials Saved`,
    costImpact: 'Matrix Synced',
    reason: 'Save for Vendor + Period'
  });

  notifyStore();
  return { success: true, count: vendorMaterials.length };
}

export function getVendorBaselineData(vendorId) {
  const prods = globalStore.baselineProducts || [];
  if (!vendorId || vendorId === 'ALL') return prods;
  const vNorm = normalizeVendorId(vendorId);
  return prods.filter(p => normalizeVendorId(p.vendor) === vNorm);
}

export function updateBaselineParameters({ itemId, updatedItem, reason }) {
  const prod = (globalStore.baselineProducts || []).find(p => p.id === itemId || p.itemCode === itemId);
  if (!prod) return;
  Object.assign(prod, updatedItem);
  addAuditLog({
    partCode: prod.itemCode,
    componentName: prod.componentName,
    vendor: prod.vendor,
    modifications: 'Adjusted parameters in modal',
    costImpact: `₹${(prod.approvedCost || 0).toFixed(2)}`,
    reason: reason || 'Manual Spec Adjustment'
  });
  notifyStore();
}

export function addStagedProductsToBaseline(stagedList, vendor) {
  stagedList.forEach(staged => {
    const cleanRm = sanitizeMaterialName(staged.approvedRm || staged.baseRm, staged.componentName, staged.itemCode, vendor);
    const idx = globalStore.baselineProducts.findIndex(p => p.itemCode === staged.itemCode && normalizeVendorId(p.vendor) === normalizeVendorId(vendor));
    if (idx >= 0) {
      globalStore.baselineProducts[idx] = { ...globalStore.baselineProducts[idx], ...staged, approvedRm: cleanRm, vendor: vendor || staged.vendor };
    } else {
      globalStore.baselineProducts.push({ ...staged, approvedRm: cleanRm, id: `prod-${Date.now()}-${Math.random().toString(36).substr(2,4)}`, vendor: vendor || staged.vendor });
    }
  });
  notifyStore();
}

export function deleteProductFromBaseline(itemId, vendor) {
  const vNorm = normalizeVendorId(vendor);
  globalStore.baselineProducts = (globalStore.baselineProducts || []).filter(p => !( (p.id === itemId || p.itemCode === itemId) && (vendor === 'ALL' || normalizeVendorId(p.vendor) === vNorm) ));
  addAuditLog({
    partCode: itemId,
    componentName: `Deleted Product ${itemId}`,
    vendor: vendor || 'ALL',
    modifications: 'Deleted product from baseline master',
    costImpact: '0.00',
    reason: 'Manual deletion'
  });
  notifyStore();
}

export function clearVendorBaselineProducts(vendorName) {
  const vNorm = normalizeVendorId(vendorName);
  globalStore.baselineProducts = (globalStore.baselineProducts || []).filter(p => normalizeVendorId(p.vendor) !== vNorm);
  addAuditLog({
    partCode: 'BASELINE_PURGE',
    componentName: `Purged Baseline Products for ${vendorName}`,
    vendor: vendorName,
    modifications: 'Cleared baseline table',
    costImpact: '0 Parts',
    reason: 'Manual Baseline Purge'
  });
  notifyStore();
}

export function addAuditLog(entry) {
  globalStore.auditLogs = globalStore.auditLogs || [];
  globalStore.auditLogs.unshift({
    timestamp: new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }),
    ...entry
  });
}

export function toggleGlobalLock() { 
  globalStore.isLocked = !globalStore.isLocked; 
  notifyStore(); 
}

export function toggleMatrixLock() { 
  globalStore.isMatrixLocked = !globalStore.isMatrixLocked; 
  notifyStore(); 
}

export function addDayWisePurchase(rec) { (globalStore.purchases = globalStore.purchases || []).unshift(rec); notifyStore(); return { success: true }; }
export function addDayWiseSales(rec) { (globalStore.sales = globalStore.sales || []).unshift(rec); notifyStore(); return { success: true }; }
export function onboardVendorWithBlueprint() { notifyStore(); }
