#!/usr/bin/env bash
set -e

echo "==> 1. Updating masterStore.js to support RM usage lookup & clean invalid codes..."
cat << 'STORE_EOF' > src/shared/masterStore.js
// ============================================================================
// GLOBAL MASTER DATA STORE (Strictly Isolated & Vendor-Scoped with Usage Tracking)
// ============================================================================

const STORAGE_KEY = 'CPC_MASTER_STORE_DEV_V2_PROD_RELEASE_V4';

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

function loadPersistedStore() {
  if (typeof window === 'undefined') return null;
  try {
    const saved = localStorage.getItem(STORAGE_KEY) || localStorage.getItem('CPC_MASTER_STORE_DEV_V2_PROD_RELEASE_V3') || localStorage.getItem('CPC_MASTER_STORE_DEV_V2_PROD_RELEASE');
    if (saved) {
      const parsed = JSON.parse(saved);
      // Clean invalid RM / MB noise
      if (parsed.rmMappingsData) {
        parsed.rmMappingsData = parsed.rmMappingsData.filter(r => !isInvalidMaterialCode(r.approvedCode));
      }
      if (parsed.baselineProducts) {
        parsed.baselineProducts = parsed.baselineProducts.map(p => {
          const cleanRm = sanitizeMaterialName(p.approvedRm || p.baseRm, p.componentName, p.itemCode, p.vendor);
          const { baseRm, mbGrade } = parseMaterialString(cleanRm);
          return {
            ...p,
            approvedRm: cleanRm,
            baseRm: baseRm || cleanRm,
            approvedMb: p.approvedMb && !isInvalidMaterialCode(p.approvedMb) ? p.approvedMb : (mbGrade || 'White MB')
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

export function computeGradeWeightedAverage(gradeOrCode, vendor) {
  const purchases = globalStore.purchases || [];
  if (!gradeOrCode) return 0;
  const gClean = gradeOrCode.toString().toLowerCase().trim();
  const vNorm = normalizeVendorId(vendor);

  const matching = purchases.filter(p => {
    const pGrade = (p.grade || p.itemCode || p.rawMaterial || p.supplier || '').toString().toLowerCase().trim();
    const pNorm = normalizeVendorId(p.vendor);
    const matchGrade = pGrade === gClean || pGrade.includes(gClean) || gClean.includes(pGrade);
    const matchVendor = !vendor || vNorm === 'all' || pNorm === vNorm;
    return matchGrade && matchVendor;
  });

  let totalQty = 0;
  let totalCost = 0;
  matching.forEach(m => {
    const qty = Number(m.qty || m.quantity || 0);
    const rate = Number(m.rate || m.netRate || m.price || 0);
    if (qty > 0 && rate > 0) {
      totalQty += qty;
      totalCost += (qty * rate);
    }
  });

  if (totalQty > 0) {
    return Number((totalCost / totalQty).toFixed(2));
  }
  return 0;
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
    const activeKey = found.activeAlt || 'alt1';
    const waPrice = Number(found[`${activeKey}Price`] !== undefined ? found[`${activeKey}Price`] : (found.alt1Price || found.approvedPrice || 0));
    return { 
      approvedCode: found.approvedCode, 
      approvedPrice: Number(found.approvedPrice || 0), 
      activeGrade: found[`${activeKey}Code`] || found.approvedCode, 
      activeWaPrice: Number(waPrice || 0), 
      isFound: true 
    };
  }

  const defaultRate = vNorm === 'atomberg' ? 131.00 : 154.00;
  return { approvedCode: baseRm || cleanGrade, approvedPrice: defaultRate, activeGrade: baseRm || cleanGrade, activeWaPrice: defaultRate, isFound: false };
}

export function getActiveMbMapping(mbGradeName, vendor) {
  const vNorm = normalizeVendorId(vendor);
  let targetMb = (mbGradeName || '').toLowerCase().trim();
  if (!targetMb || targetMb === 'none' || !isNaN(Number(targetMb))) {
    return { approvedMbCode: 'None', approvedMbPrice: 0, activeMbGrade: 'None', activeMbWaPrice: 0, isFound: false };
  }

  const found = (globalStore.rmMappingsData || []).find(r => 
    r.type === 'MB' && 
    normalizeVendorId(r.vendor) === vNorm && 
    (r.approvedCode.toLowerCase().trim() === targetMb || targetMb.includes(r.approvedCode.toLowerCase().trim()) || r.approvedCode.toLowerCase().trim().includes(targetMb))
  );

  if (found) {
    const activeKey = found.activeAlt || 'alt1';
    const waPrice = Number(found[`${activeKey}Price`] !== undefined ? found[`${activeKey}Price`] : (found.alt1Price || found.approvedPrice || 0));
    return { 
      approvedMbCode: found.approvedCode, 
      approvedMbPrice: Number(found.approvedPrice || 0), 
      activeMbGrade: found[`${activeKey}Code`] || found.approvedCode, 
      activeMbWaPrice: Number(waPrice || 0), 
      isFound: true 
    };
  }

  const defaultMbRate = vNorm === 'atomberg' ? 154.00 : 242.00;
  return { approvedMbCode: mbGradeName, approvedMbPrice: defaultMbRate, activeMbGrade: mbGradeName, activeMbWaPrice: defaultMbRate, isFound: false };
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
      vendor: item.vendor || globalStore.rmMappingsData[idx].vendor 
    };
  } else {
    globalStore.rmMappingsData.push({ 
      id: `mat-${vNorm}-${Date.now()}-${Math.random().toString(36).substr(2,4)}`, 
      ...item,
      approvedCode: cleanCode 
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

// Find all products using this specific RM or MB code
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
        const activeKey = matchedRm.activeAlt || 'alt1';
        prod.approvedRmPrice = Number(matchedRm.approvedPrice || prod.approvedRmPrice || 0);
        prod.activeRmWaPrice = Number(matchedRm[`${activeKey}Price`] !== undefined ? matchedRm[`${activeKey}Price`] : matchedRm.approvedPrice);
      }
      if (matchedMb) {
        const activeKey = matchedMb.activeAlt || 'alt1';
        prod.approvedMbPrice = Number(matchedMb.approvedPrice || prod.approvedMbPrice || 0);
        prod.activeMbWaPrice = Number(matchedMb[`${activeKey}Price`] !== undefined ? matchedMb[`${activeKey}Price`] : matchedMb.approvedPrice);
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
STORE_EOF

echo "==> 2. Updating RMPriceMatrixPage.jsx with Delete Action and Linked Product Inspector..."
cat << 'RM_PAGE_EOF' > src/modules/module2-rm-matrix/RMPriceMatrixPage.jsx
import React, { useState, useEffect } from 'react';
import { 
  Lock, 
  Unlock, 
  Upload, 
  Download, 
  Save, 
  Plus, 
  Trash2, 
  Eye, 
  CheckCircle2, 
  Database,
  Layers,
  ShoppingBag,
  TrendingUp,
  History,
  X,
  Package
} from 'lucide-react';
import * as XLSX from 'xlsx';
import { 
  globalStore, 
  subscribeStore, 
  updateRmMappingRow, 
  deleteVendorMaterial, 
  getProductsUsingMaterial, 
  addDayWisePurchase, 
  addDayWiseSales, 
  toggleGlobalLock, 
  toggleMatrixLock, 
  saveVendorPeriodSchedule, 
  addOrUpdateVendorMaterial, 
  computeGradeWeightedAverage,
  normalizeVendorId,
  isInvalidMaterialCode
} from '../../shared/masterStore';

export default function RMPriceMatrixPage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [activeTab, setActiveTab] = useState('matrix');
  const [selectedVendor, setSelectedVendor] = useState('Haier Appliances');
  const [periodFrom, setPeriodFrom] = useState('2026-08-01');
  const [periodTo, setPeriodTo] = useState('2026-08-31');
  const [showAddModal, setShowAddModal] = useState(false);
  const [saveSuccessMsg, setSaveSuccessMsg] = useState('');
  const [viewingUsageMat, setViewingUsageMat] = useState(null);

  const [isGlobalLocked, setIsGlobalLocked] = useState(true);
  const [isMatrixLocked, setIsMatrixLocked] = useState(true);

  const [newMaterial, setNewMaterial] = useState({
    type: 'RM',
    approvedCode: '',
    approvedPrice: '',
    alt1Code: '',
    alt1Price: ''
  });

  const [purchaseForm, setPurchaseForm] = useState({
    date: '2026-08-15',
    supplierName: '',
    invoiceNo: '',
    itemCode: '',
    grade: '',
    qty: '',
    rate: ''
  });

  const [salesForm, setSalesForm] = useState({
    date: '2026-08-15',
    vendor: 'Haier Appliances',
    itemCode: '',
    invoiceNo: '',
    componentName: '',
    qty: '',
    sellingPrice: ''
  });

  useEffect(() => {
    const unsub = subscribeStore(() => {
      setStoreState({ ...globalStore });
      if (globalStore.isLocked !== undefined) setIsGlobalLocked(globalStore.isLocked);
      if (globalStore.isMatrixLocked !== undefined) setIsMatrixLocked(globalStore.isMatrixLocked);
    });
    return () => unsub();
  }, []);

  const vendors = storeState.vendors || [
    { vendorId: 'Haier Appliances', vendorName: 'Haier Appliances' },
    { vendorId: 'Atomberg Technologies', vendorName: 'Atomberg Technologies' },
    { vendorId: 'Atharva Polymer', vendorName: 'Atharva Polymer (Haier)' }
  ];

  const currentVendorNorm = normalizeVendorId(selectedVendor);

  // Filter out any noisy/invalid codes and scope strictly by vendor
  const vendorMaterials = (storeState.rmMappingsData || []).filter(r => 
    !isInvalidMaterialCode(r.approvedCode) && 
    (selectedVendor === 'ALL' || normalizeVendorId(r.vendor) === currentVendorNorm)
  );

  const purchases = (storeState.purchases || []).filter(p => 
    selectedVendor === 'ALL' || normalizeVendorId(p.vendor) === currentVendorNorm
  );

  const sales = (storeState.sales || []).filter(s => 
    selectedVendor === 'ALL' || normalizeVendorId(s.vendor) === currentVendorNorm
  );

  const auditLogs = (storeState.auditLogs || []).filter(l => 
    l.partCode === 'RM_MATRIX' || 
    selectedVendor === 'ALL' ||
    normalizeVendorId(l.vendor) === currentVendorNorm
  );

  const purchaseOptionsMap = new Map();
  purchases.forEach(p => {
    const gradeName = (p.grade || p.itemCode || '').trim();
    if (!gradeName) return;
    if (!purchaseOptionsMap.has(gradeName)) {
      const wa = computeGradeWeightedAverage(gradeName, selectedVendor);
      purchaseOptionsMap.set(gradeName, {
        label: `${gradeName} (Inward WA: ₹${wa.toFixed(2)})`,
        code: gradeName,
        price: wa
      });
    }
  });
  const allPurchasedGradeOptions = Array.from(purchaseOptionsMap.values());

  const handleToggleGlobalLock = () => {
    const next = !isGlobalLocked;
    setIsGlobalLocked(next);
    toggleGlobalLock();
  };

  const handleToggleMatrixLock = () => {
    const next = !isMatrixLocked;
    setIsMatrixLocked(next);
    toggleMatrixLock();
  };

  const isRowDisabled = isGlobalLocked || isMatrixLocked;

  const handleSelectActiveAlt = (rowId, altKey) => {
    if (isRowDisabled) return;
    updateRmMappingRow(rowId, { activeAlt: altKey });
  };

  const handleApprovedPriceChange = (rowId, val) => {
    if (isRowDisabled) return;
    updateRmMappingRow(rowId, { approvedPrice: parseFloat(val) || 0 });
  };

  const handleAltSelectChange = (rowId, altIndex, selectedOptionCode, currentApprovedCode, currentApprovedPrice) => {
    if (isRowDisabled) return;
    const codeField = `alt${altIndex}Code`;
    const priceField = `alt${altIndex}Price`;

    if (!selectedOptionCode || selectedOptionCode === currentApprovedCode) {
      updateRmMappingRow(rowId, { 
        [codeField]: currentApprovedCode,
        [priceField]: Number(currentApprovedPrice || 0)
      });
    } else {
      const wa = computeGradeWeightedAverage(selectedOptionCode, selectedVendor);
      updateRmMappingRow(rowId, { 
        [codeField]: selectedOptionCode,
        [priceField]: wa > 0 ? wa : Number(currentApprovedPrice || 0)
      });
    }
  };

  const handleDeleteMaterial = (m) => {
    const usingProds = getProductsUsingMaterial(m.approvedCode, selectedVendor);
    const confirmMsg = usingProds.length > 0 
      ? `Warning: ${usingProds.length} product(s) currently use "${m.approvedCode}". Are you sure you want to delete this material?`
      : `Are you sure you want to delete "${m.approvedCode}" from the RM matrix?`;
    
    if (window.confirm(confirmMsg)) {
      deleteVendorMaterial(m.id, selectedVendor);
      setSaveSuccessMsg(`✓ Deleted material "${m.approvedCode}"`);
      setTimeout(() => setSaveSuccessMsg(''), 3000);
    }
  };

  const handleSaveVendorPeriod = () => {
    const res = saveVendorPeriodSchedule({ vendor: selectedVendor, periodFrom, periodTo });
    setSaveSuccessMsg(`✓ Successfully saved & locked ${res.count} materials for ${selectedVendor} (${periodFrom} to ${periodTo})`);
    setTimeout(() => setSaveSuccessMsg(''), 4000);
  };

  const handleDownloadPurchaseTemplate = () => {
    const templateData = [
      {
        "Date (YYYY-MM-DD)": "2026-08-15",
        "Supplier Name": "Reliance Polymers",
        "Invoice Number": "INV-2026-001",
        "Item Code": currentVendorNorm === 'atomberg' ? "PP-H110MA" : "HIPS-SH303",
        "Grade Description": currentVendorNorm === 'atomberg' ? "PP H110MA" : "HIPS SH303 Natural",
        "Quantity (Kg)": 5000,
        "Purchase Rate (₹/Kg)": currentVendorNorm === 'atomberg' ? 131.00 : 154.00,
        "Vendor": selectedVendor
      }
    ];
    const ws = XLSX.utils.json_to_sheet(templateData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Purchase_Template");
    XLSX.writeFile(wb, `Purchase_Inward_Template_${selectedVendor.replace(/\s+/g, '_')}.xlsx`);
  };

  const handleDownloadSalesTemplate = () => {
    const templateData = [
      {
        "Dispatch Date (YYYY-MM-DD)": "2026-08-15",
        "Vendor": selectedVendor,
        "Item Code": currentVendorNorm === 'atomberg' ? "A101701" : "0060235291A",
        "Invoice Number": "SALE-2026-101",
        "Component Name": currentVendorNorm === 'atomberg' ? "Aris Top Canopy- Gloss White" : "FRZ DUCT-FRONT COVER-HIPS-TM-250/280L",
        "Dispatch Qty (Nos)": 1200,
        "Selling Price (₹/Pc)": currentVendorNorm === 'atomberg' ? 32.00 : 85.00
      }
    ];
    const ws = XLSX.utils.json_to_sheet(templateData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Sales_Template");
    XLSX.writeFile(wb, `DayWise_Sales_Template_${selectedVendor.replace(/\s+/g, '_')}.xlsx`);
  };

  const handlePurchaseBulkUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (evt) => {
      const bstr = evt.target.result;
      const wb = XLSX.read(bstr, { type: 'binary' });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const data = XLSX.utils.sheet_to_json(ws);
      data.forEach(d => {
        addDayWisePurchase({
          date: d["Date (YYYY-MM-DD)"] || d.Date || d.date || '2026-08-15',
          supplier: d["Supplier Name"] || d.Supplier || d.supplier || '',
          invoiceNo: d["Invoice Number"] || d.Invoice || d.invoiceNo || '',
          itemCode: d["Item Code"] || d.itemCode || '',
          grade: d["Grade Description"] || d.Grade || d.grade || '',
          qty: parseFloat(d["Quantity (Kg)"] || d.Quantity || d.qty || 0),
          rate: parseFloat(d["Purchase Rate (₹/Kg)"] || d.Rate || d.rate || 0),
          vendor: selectedVendor
        });
      });
      alert(`Imported ${data.length} purchase inward records for ${selectedVendor}!`);
    };
    reader.readAsBinaryString(file);
  };

  const handleSalesBulkUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (evt) => {
      const bstr = evt.target.result;
      const wb = XLSX.read(bstr, { type: 'binary' });
      const ws = wb.Sheets[wb.SheetNames[0]];
      const data = XLSX.utils.sheet_to_json(ws);
      data.forEach(d => {
        addDayWiseSales({
          date: d["Dispatch Date (YYYY-MM-DD)"] || d.Date || d.date || '2026-08-15',
          vendor: selectedVendor,
          itemCode: d["Item Code"] || d.itemCode || '',
          invoiceNo: d["Invoice Number"] || d.Invoice || d.invoiceNo || '',
          componentName: d["Component Name"] || d.componentName || '',
          qty: parseFloat(d["Dispatch Qty (Nos)"] || d.Quantity || d.qty || 0),
          rate: parseFloat(d["Selling Price (₹/Pc)"] || d.Rate || d.sellingPrice || 0),
          amount: parseFloat(d["Dispatch Qty (Nos)"] || d.qty || 0) * parseFloat(d["Selling Price (₹/Pc)"] || d.sellingPrice || 0)
        });
      });
      alert(`Imported ${data.length} sales dispatch records for ${selectedVendor}!`);
    };
    reader.readAsBinaryString(file);
  };

  const handleAddPurchase = (e) => {
    e.preventDefault();
    if (!purchaseForm.qty || !purchaseForm.rate) return;
    addDayWisePurchase({
      ...purchaseForm,
      qty: parseFloat(purchaseForm.qty),
      rate: parseFloat(purchaseForm.rate),
      vendor: selectedVendor
    });
    setPurchaseForm({ date: '2026-08-15', supplierName: '', invoiceNo: '', itemCode: '', grade: '', qty: '', rate: '' });
  };

  const handleAddSales = (e) => {
    e.preventDefault();
    if (!salesForm.qty || !salesForm.sellingPrice) return;
    addDayWiseSales({
      ...salesForm,
      qty: parseFloat(salesForm.qty),
      rate: parseFloat(salesForm.sellingPrice),
      amount: parseFloat(salesForm.qty) * parseFloat(salesForm.sellingPrice),
      vendor: selectedVendor
    });
    setSalesForm({ date: '2026-08-15', vendor: selectedVendor, itemCode: '', invoiceNo: '', componentName: '', qty: '', sellingPrice: '' });
  };

  const handleCreateNewMaterial = (e) => {
    e.preventDefault();
    if (!newMaterial.approvedCode || !newMaterial.approvedPrice) return;
    addOrUpdateVendorMaterial({
      vendor: selectedVendor,
      type: newMaterial.type,
      approvedCode: newMaterial.approvedCode.trim(),
      approvedPrice: parseFloat(newMaterial.approvedPrice) || 0,
      alt1Code: newMaterial.alt1Code || newMaterial.approvedCode.trim(),
      alt1Price: parseFloat(newMaterial.alt1Price || newMaterial.approvedPrice) || 0,
      activeAlt: 'alt1',
      periodFrom,
      periodTo
    });
    setNewMaterial({ type: 'RM', approvedCode: '', approvedPrice: '', alt1Code: '', alt1Price: '' });
    setShowAddModal(false);
  };

  // Products using selected material for modal popup
  const activeUsageProducts = viewingUsageMat ? getProductsUsingMaterial(viewingUsageMat.approvedCode, selectedVendor) : [];

  return (
    <div className="space-y-4 text-xs font-sans">
      {/* Top Banner */}
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex flex-wrap justify-between items-center gap-3">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-blue-600 rounded-xl">
            <Database className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-sm font-bold">2. RM Mapping & Inward Registry</h1>
              <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] px-2 py-0.5 rounded-full font-bold">
                Vendor: {selectedVendor}
              </span>
            </div>
            <p className="text-[11px] text-slate-300">Synchronized RM & MB Baseline to Purchase Weighted Average Mapping with Linked Part Tracking</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowAddModal(true)}
            className="px-3.5 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-xs text-xs"
          >
            <Plus className="w-4 h-4" /> + Add Vendor RM / MB
          </button>

          <button
            onClick={handleToggleGlobalLock}
            className={`px-4 py-2 rounded-xl font-bold flex items-center gap-2 cursor-pointer shadow-sm transition text-xs ${
              isGlobalLocked 
                ? 'bg-rose-600 hover:bg-rose-700 text-white' 
                : 'bg-emerald-600 hover:bg-emerald-700 text-white'
            }`}
          >
            {isGlobalLocked ? <Lock className="w-4 h-4" /> : <Unlock className="w-4 h-4" />}
            {isGlobalLocked ? 'Page Locked (Protected)' : 'Page Unlocked (Editing Active)'}
          </button>
        </div>
      </div>

      {/* Save Success Banner */}
      {saveSuccessMsg && (
        <div className="p-3 bg-emerald-50 border border-emerald-300 text-emerald-900 rounded-xl font-bold flex items-center gap-2 shadow-xs text-xs">
          <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          <span>{saveSuccessMsg}</span>
        </div>
      )}

      {/* Tabs Navigation */}
      <div className="bg-white p-2 rounded-2xl border border-slate-200 shadow-xs flex flex-wrap gap-2">
        <button
          onClick={() => setActiveTab('matrix')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'matrix' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Layers className="w-4 h-4" /> RM Price Matrix ({vendorMaterials.length})
        </button>
        <button
          onClick={() => setActiveTab('purchases')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'purchases' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <ShoppingBag className="w-4 h-4" /> Day-wise Purchases ({purchases.length})
        </button>
        <button
          onClick={() => setActiveTab('sales')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'sales' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <TrendingUp className="w-4 h-4" /> Day-wise Sales ({sales.length})
        </button>
        <button
          onClick={() => setActiveTab('changelog')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'changelog' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <History className="w-4 h-4" /> Baseline & RM Change Log ({auditLogs.length})
        </button>
      </div>

      {/* Filter Row with Level 2 Matrix Rates Lock & Save for Vendor + Period */}
      <div className="bg-white p-3 rounded-2xl border border-slate-200 shadow-xs flex flex-wrap justify-between items-center gap-3">
        <div className="flex items-center gap-2">
          <span className="font-bold text-slate-600">FILTER: Vendor:</span>
          <select
            value={selectedVendor}
            onChange={e => setSelectedVendor(e.target.value)}
            className="px-3 py-1.5 rounded-xl bg-slate-100 text-slate-900 border border-slate-300 font-bold text-xs"
          >
            {vendors.map(v => (
              <option key={v.vendorId} value={v.vendorId}>{v.vendorName}</option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-slate-500 font-bold">Period: From</span>
          <input 
            type="date" 
            value={periodFrom} 
            onChange={e => setPeriodFrom(e.target.value)} 
            className="px-2 py-1 rounded-xl bg-slate-100 border border-slate-300 text-xs font-mono" 
          />
          <span className="text-slate-500">To</span>
          <input 
            type="date" 
            value={periodTo} 
            onChange={e => setPeriodTo(e.target.value)} 
            className="px-2 py-1 rounded-xl bg-slate-100 border border-slate-300 text-xs font-mono" 
          />

          <button
            onClick={handleToggleMatrixLock}
            className={`px-3 py-1.5 rounded-xl font-bold text-[11px] flex items-center gap-1.5 cursor-pointer transition ${
              isMatrixLocked 
                ? 'bg-rose-50 text-rose-800 border border-rose-300 hover:bg-rose-100' 
                : 'bg-emerald-50 text-emerald-800 border border-emerald-300 hover:bg-emerald-100'
            }`}
          >
            {isMatrixLocked ? <Lock className="w-3.5 h-3.5 text-rose-600" /> : <Unlock className="w-3.5 h-3.5 text-emerald-600" />}
            {isMatrixLocked ? 'Matrix Rates Locked (Level 2)' : 'Matrix Rates Editable (Level 2)'}
          </button>

          <button 
            onClick={handleSaveVendorPeriod}
            className="px-4 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 shadow-sm text-xs cursor-pointer transition active:scale-95"
          >
            <Save className="w-3.5 h-3.5" /> Save for Vendor + period
          </button>
        </div>
      </div>

      {/* TAB 1: RM PRICE MATRIX WITH DELETE & PRODUCT USAGE BADGE */}
      {activeTab === 'matrix' && (
        <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-900 text-white uppercase font-bold text-[10px]">
                <tr>
                  <th className="py-3 px-4">APPROVED RM/MB CODE & USAGE</th>
                  <th className="py-3 px-4 text-center">APPROVED PRICE (₹/KG)</th>
                  <th className="py-3 px-4">ALTERNATE RM-1</th>
                  <th className="py-3 px-4 text-center">PRICE (WA)</th>
                  <th className="py-3 px-4">ALTERNATE RM-2</th>
                  <th className="py-3 px-4 text-center">PRICE (WA)</th>
                  <th className="py-3 px-4">ALTERNATE RM-3</th>
                  <th className="py-3 px-4 text-center">PRICE (WA)</th>
                  <th className="py-3 px-3 text-center">ACTION</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {vendorMaterials.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-12 text-center text-slate-400 font-medium">
                      No material codes mapped specifically for {selectedVendor}. Upload a baseline sheet in <b>1. Baseline Master</b> to auto-register grades.
                    </td>
                  </tr>
                ) : (
                  vendorMaterials.map(m => {
                    const activeAlt = m.activeAlt || 'alt1';
                    const usingProds = getProductsUsingMaterial(m.approvedCode, selectedVendor);

                    return (
                      <tr key={m.id} className="hover:bg-slate-50 transition">
                        {/* 1. Approved RM/MB Code + Usage Inspector */}
                        <td className="py-3 px-4">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2">
                              <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                m.type === 'MB' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'
                              }`}>
                                {m.type === 'MB' ? 'MASTERBATCH' : 'RM CODE'}
                              </span>
                              <span className="font-bold text-slate-900">{m.approvedCode}</span>
                            </div>
                            
                            {/* Product Usage Badge */}
                            <div>
                              <button
                                onClick={() => setViewingUsageMat(m)}
                                className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold cursor-pointer transition ${
                                  usingProds.length > 0 
                                    ? 'bg-emerald-50 text-emerald-800 border border-emerald-200 hover:bg-emerald-100' 
                                    : 'bg-slate-100 text-slate-500 border border-slate-200 hover:bg-slate-200'
                                }`}
                              >
                                <Package className="w-3 h-3" />
                                {usingProds.length > 0 ? `Used in ${usingProds.length} Part(s)` : '0 Parts Linked (Unused)'}
                              </button>
                            </div>
                          </div>
                        </td>

                        {/* 2. Approved Price */}
                        <td className="py-3 px-4 text-center">
                          <div className="inline-flex items-center bg-amber-50/80 border border-amber-300 rounded-lg px-2 py-1 shadow-2xs">
                            <span className="text-amber-900 font-bold mr-1">₹</span>
                            <input
                              type="number"
                              step="0.01"
                              disabled={isRowDisabled}
                              value={m.approvedPrice || ''}
                              onChange={(e) => handleApprovedPriceChange(m.id, e.target.value)}
                              className={`w-16 bg-transparent font-bold text-amber-950 text-center outline-hidden ${
                                isRowDisabled ? 'cursor-not-allowed opacity-80' : 'cursor-text'
                              }`}
                            />
                          </div>
                        </td>

                        {/* 3. Alternate RM-1 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt1Code || m.approvedCode}
                              onChange={(e) => handleAltSelectChange(m.id, 1, e.target.value, m.approvedCode, m.approvedPrice)}
                              className={`w-full px-2 py-1 rounded-lg border border-slate-300 font-medium text-xs bg-white ${
                                isRowDisabled ? 'bg-slate-100 cursor-not-allowed' : ''
                              }`}
                            >
                              <option value={m.approvedCode}>{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code}>{opt.label}</option>
                              ))}
                            </select>
                            <div className="flex items-center gap-2">
                              <label className="flex items-center gap-1 cursor-pointer">
                                <input
                                  type="radio"
                                  name={`active-${m.id}`}
                                  checked={activeAlt === 'alt1'}
                                  onChange={() => handleSelectActiveAlt(m.id, 'alt1')}
                                  disabled={isRowDisabled}
                                  className="text-blue-600 focus:ring-blue-500"
                                />
                                <span className="text-[10px] text-slate-600 font-medium">Set Active</span>
                              </label>
                              {activeAlt === 'alt1' && (
                                <span className="px-1.5 py-0.2 bg-blue-600 text-white rounded text-[9px] font-black uppercase tracking-wider">
                                  ACTIVE
                                </span>
                              )}
                            </div>
                          </div>
                        </td>

                        {/* 4. Price (WA) 1 */}
                        <td className="py-3 px-4 text-center">
                          <span className="font-mono font-bold text-blue-700 text-xs">
                            ₹{Number(m.alt1Price !== undefined ? m.alt1Price : m.approvedPrice || 0).toFixed(2)}
                          </span>
                        </td>

                        {/* 5. Alternate RM-2 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt2Code || ''}
                              onChange={(e) => handleAltSelectChange(m.id, 2, e.target.value, m.approvedCode, m.approvedPrice)}
                              className={`w-full px-2 py-1 rounded-lg border border-slate-300 font-medium text-xs bg-white ${
                                isRowDisabled ? 'bg-slate-100 cursor-not-allowed' : ''
                              }`}
                            >
                              <option value="">Select Alternate Lot 2</option>
                              <option value={m.approvedCode}>{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code}>{opt.label}</option>
                              ))}
                            </select>
                            <div className="flex items-center gap-2">
                              <label className="flex items-center gap-1 cursor-pointer">
                                <input
                                  type="radio"
                                  name={`active-${m.id}`}
                                  checked={activeAlt === 'alt2'}
                                  onChange={() => handleSelectActiveAlt(m.id, 'alt2')}
                                  disabled={isRowDisabled || !m.alt2Code}
                                  className="text-blue-600 focus:ring-blue-500"
                                />
                                <span className="text-[10px] text-slate-600 font-medium">Set Active</span>
                              </label>
                              <span className={`px-1.5 py-0.2 rounded text-[9px] font-black uppercase tracking-wider ${
                                activeAlt === 'alt2' ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-400'
                              }`}>
                                {activeAlt === 'alt2' ? 'ACTIVE' : 'STANDBY'}
                              </span>
                            </div>
                          </div>
                        </td>

                        {/* 6. Price (WA) 2 */}
                        <td className="py-3 px-4 text-center">
                          <span className="font-mono text-slate-600 text-xs">
                            ₹{Number(m.alt2Price || 0).toFixed(2)}
                          </span>
                        </td>

                        {/* 7. Alternate RM-3 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt3Code || ''}
                              onChange={(e) => handleAltSelectChange(m.id, 3, e.target.value, m.approvedCode, m.approvedPrice)}
                              className={`w-full px-2 py-1 rounded-lg border border-slate-300 font-medium text-xs bg-white ${
                                isRowDisabled ? 'bg-slate-100 cursor-not-allowed' : ''
                              }`}
                            >
                              <option value="">Select Alternate Lot 3</option>
                              <option value={m.approvedCode}>{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code}>{opt.label}</option>
                              ))}
                            </select>
                            <div className="flex items-center gap-2">
                              <label className="flex items-center gap-1 cursor-pointer">
                                <input
                                  type="radio"
                                  name={`active-${m.id}`}
                                  checked={activeAlt === 'alt3'}
                                  onChange={() => handleSelectActiveAlt(m.id, 'alt3')}
                                  disabled={isRowDisabled || !m.alt3Code}
                                  className="text-blue-600 focus:ring-blue-500"
                                />
                                <span className="text-[10px] text-slate-600 font-medium">Set Active</span>
                              </label>
                              <span className={`px-1.5 py-0.2 rounded text-[9px] font-black uppercase tracking-wider ${
                                activeAlt === 'alt3' ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-400'
                              }`}>
                                {activeAlt === 'alt3' ? 'ACTIVE' : 'STANDBY'}
                              </span>
                            </div>
                          </div>
                        </td>

                        {/* 8. Price (WA) 3 */}
                        <td className="py-3 px-4 text-center">
                          <span className="font-mono text-slate-600 text-xs">
                            ₹{Number(m.alt3Price || 0).toFixed(2)}
                          </span>
                        </td>

                        {/* 9. Delete Action Button */}
                        <td className="py-3 px-3 text-center">
                          <button
                            onClick={() => handleDeleteMaterial(m)}
                            disabled={isGlobalLocked}
                            title="Delete this material code"
                            className={`p-1.5 rounded-lg transition cursor-pointer ${
                              isGlobalLocked 
                                ? 'text-slate-300 cursor-not-allowed' 
                                : 'text-rose-600 hover:bg-rose-50 hover:text-rose-700'
                            }`}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: DAY-WISE PURCHASES */}
      {activeTab === 'purchases' && (
        <div className="space-y-4">
          <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs space-y-3">
            <div className="flex flex-wrap justify-between items-center gap-2 border-b border-slate-100 pb-3">
              <span className="font-bold text-slate-900 text-xs uppercase">Add Purchase Inward ({selectedVendor})</span>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleDownloadPurchaseTemplate}
                  className="px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs transition"
                >
                  <Download className="w-4 h-4 text-blue-600" /> Download Purchase Template (.xlsx)
                </button>
                <label className="px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-xs text-xs transition">
                  <Upload className="w-4 h-4" /> Bulk Upload (.xlsx)
                  <input type="file" accept=".xlsx, .xls" onChange={handlePurchaseBulkUpload} className="hidden" />
                </label>
              </div>
            </div>

            <form onSubmit={handleAddPurchase} className="flex flex-wrap items-center gap-2">
              <input 
                type="date" 
                value={purchaseForm.date} 
                onChange={e => setPurchaseForm({ ...purchaseForm, date: e.target.value })} 
                className="px-2.5 py-1.5 rounded-xl border border-slate-300 font-mono text-xs" 
              />
              <input 
                type="text" 
                placeholder="Supplier Name" 
                value={purchaseForm.supplierName} 
                onChange={e => setPurchaseForm({ ...purchaseForm, supplierName: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[120px]" 
              />
              <input 
                type="text" 
                placeholder="Invoice #" 
                value={purchaseForm.invoiceNo} 
                onChange={e => setPurchaseForm({ ...purchaseForm, invoiceNo: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono w-28" 
              />
              <input 
                type="text" 
                placeholder="Item Code" 
                value={purchaseForm.itemCode} 
                onChange={e => setPurchaseForm({ ...purchaseForm, itemCode: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono w-28" 
              />
              <input 
                type="text" 
                placeholder="Grade Description" 
                value={purchaseForm.grade} 
                onChange={e => setPurchaseForm({ ...purchaseForm, grade: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[140px]" 
              />
              <input 
                type="number" 
                placeholder="Qty (kg)" 
                value={purchaseForm.qty} 
                onChange={e => setPurchaseForm({ ...purchaseForm, qty: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24" 
              />
              <input 
                type="number" 
                step="0.01" 
                placeholder="Rate (₹/kg)" 
                value={purchaseForm.rate} 
                onChange={e => setPurchaseForm({ ...purchaseForm, rate: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24" 
              />
              <button 
                type="submit" 
                disabled={isGlobalLocked}
                className={`px-4 py-1.5 rounded-xl font-bold shadow-xs text-xs ${
                  isGlobalLocked ? 'bg-slate-200 text-slate-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer'
                }`}
              >
                + Add Inward
              </button>
            </form>
          </div>

          <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-700 uppercase font-bold text-[10px]">
                <tr>
                  <th className="py-2.5 px-3">Date</th>
                  <th className="py-2.5 px-3">Supplier</th>
                  <th className="py-2.5 px-3">Invoice #</th>
                  <th className="py-2.5 px-3">Item Code</th>
                  <th className="py-2.5 px-3">Grade</th>
                  <th className="py-2.5 px-3 text-right">Inward Qty (kg)</th>
                  <th className="py-2.5 px-3 text-right">Purchase Rate (₹/kg)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {purchases.length === 0 ? (
                  <tr><td colSpan={7} className="py-8 text-center text-slate-400">No inward purchase records found specifically for {selectedVendor}.</td></tr>
                ) : (
                  purchases.map((p, idx) => (
                    <tr key={idx} className="hover:bg-slate-50">
                      <td className="py-2.5 px-3 font-mono text-slate-600">{p.date}</td>
                      <td className="py-2.5 px-3 font-medium text-slate-800">{p.supplier || p.supplierName || '-'}</td>
                      <td className="py-2.5 px-3 font-mono font-bold text-blue-700">{p.invoiceNo}</td>
                      <td className="py-2.5 px-3 font-mono">{p.itemCode || '-'}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{p.grade}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-bold">{Number(p.qty || 0).toLocaleString()} kg</td>
                      <td className="py-2.5 px-3 text-right font-mono text-slate-900 font-bold">₹{Number(p.rate || 0).toFixed(2)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: DAY-WISE SALES */}
      {activeTab === 'sales' && (
        <div className="space-y-4">
          <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs space-y-3">
            <div className="flex flex-wrap justify-between items-center gap-2 border-b border-slate-100 pb-3">
              <span className="font-bold text-slate-900 text-xs uppercase">Add Dispatch Sale ({selectedVendor})</span>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleDownloadSalesTemplate}
                  className="px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs transition"
                >
                  <Download className="w-4 h-4 text-blue-600" /> Download Sales Template (.xlsx)
                </button>
                <label className="px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-xs text-xs transition">
                  <Upload className="w-4 h-4" /> Bulk Upload (.xlsx)
                  <input type="file" accept=".xlsx, .xls" onChange={handleSalesBulkUpload} className="hidden" />
                </label>
              </div>
            </div>

            <form onSubmit={handleAddSales} className="flex flex-wrap items-center gap-2">
              <input 
                type="date" 
                value={salesForm.date} 
                onChange={e => setSalesForm({ ...salesForm, date: e.target.value })} 
                className="px-2.5 py-1.5 rounded-xl border border-slate-300 font-mono text-xs" 
              />
              <select
                value={salesForm.vendor}
                onChange={e => setSalesForm({ ...salesForm, vendor: e.target.value })}
                className="px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs"
              >
                {vendors.map(v => (
                  <option key={v.vendorId} value={v.vendorId}>{v.vendorName}</option>
                ))}
              </select>
              <input 
                type="text" 
                placeholder="Item Code" 
                value={salesForm.itemCode} 
                onChange={e => setSalesForm({ ...salesForm, itemCode: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono w-28" 
              />
              <input 
                type="text" 
                placeholder="Invoice Number" 
                value={salesForm.invoiceNo} 
                onChange={e => setSalesForm({ ...salesForm, invoiceNo: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono w-28" 
              />
              <input 
                type="text" 
                placeholder="Component Name" 
                value={salesForm.componentName} 
                onChange={e => setSalesForm({ ...salesForm, componentName: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[140px]" 
              />
              <input 
                type="number" 
                placeholder="Dispatch Qty" 
                value={salesForm.qty} 
                onChange={e => setSalesForm({ ...salesForm, qty: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24" 
              />
              <input 
                type="number" 
                step="0.01" 
                placeholder="Selling Price" 
                value={salesForm.sellingPrice} 
                onChange={e => setSalesForm({ ...salesForm, sellingPrice: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24" 
              />
              <button 
                type="submit" 
                disabled={isGlobalLocked}
                className={`px-4 py-1.5 rounded-xl font-bold shadow-xs text-xs ${
                  isGlobalLocked ? 'bg-slate-200 text-slate-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer'
                }`}
              >
                + Record Dispatch
              </button>
            </form>
          </div>

          <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-700 uppercase font-bold text-[10px]">
                <tr>
                  <th className="py-2.5 px-3">Date</th>
                  <th className="py-2.5 px-3">Vendor</th>
                  <th className="py-2.5 px-3">Item Code</th>
                  <th className="py-2.5 px-3">Invoice Number</th>
                  <th className="py-2.5 px-3">Component Name</th>
                  <th className="py-2.5 px-3 text-right">Dispatch Qty</th>
                  <th className="py-2.5 px-3 text-right">Selling Price (₹)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {sales.length === 0 ? (
                  <tr><td colSpan={7} className="py-8 text-center text-slate-400">No dispatch records recorded specifically for {selectedVendor}.</td></tr>
                ) : (
                  sales.map((s, idx) => (
                    <tr key={idx} className="hover:bg-slate-50">
                      <td className="py-2.5 px-3 font-mono text-slate-600">{s.date}</td>
                      <td className="py-2.5 px-3 font-medium text-slate-800">{s.vendor}</td>
                      <td className="py-2.5 px-3 font-mono font-bold text-blue-700">{s.itemCode}</td>
                      <td className="py-2.5 px-3 font-mono">{s.invoiceNo}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{s.componentName}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-bold">{Number(s.qty || 0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-900">₹{Number(s.rate || s.sellingPrice || 0).toFixed(2)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: BASELINE & RM CHANGE LOG */}
      {activeTab === 'changelog' && (
        <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-700 uppercase font-bold text-[10px]">
              <tr>
                <th className="py-2.5 px-3">Timestamp</th>
                <th className="py-2.5 px-3">Code / Ref</th>
                <th className="py-2.5 px-4">Component / Target</th>
                <th className="py-2.5 px-4">Modifications</th>
                <th className="py-2.5 px-3 text-right">Cost Impact</th>
                <th className="py-2.5 px-4">Reason</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {auditLogs.map((log, idx) => (
                <tr key={idx} className="hover:bg-slate-50">
                  <td className="py-2.5 px-3 font-mono text-slate-500">{log.timestamp}</td>
                  <td className="py-2.5 px-3 font-mono font-bold text-blue-700">{log.partCode}</td>
                  <td className="py-2.5 px-4 font-semibold text-slate-800">{log.componentName}</td>
                  <td className="py-2.5 px-4 font-mono text-[11px] text-slate-700">{log.modifications}</td>
                  <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-900">{log.costImpact}</td>
                  <td className="py-2.5 px-4 text-slate-600">{log.reason}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ADD VENDOR RM/MB MODAL */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 shadow-2xl space-y-4">
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <h3 className="text-sm font-bold text-slate-900">Add New RM / Masterbatch for {selectedVendor}</h3>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">✕</button>
            </div>

            <form onSubmit={handleCreateNewMaterial} className="space-y-3">
              <div>
                <label className="block text-[11px] font-bold text-slate-700 mb-1">Material Type</label>
                <select
                  value={newMaterial.type}
                  onChange={e => setNewMaterial({ ...newMaterial, type: e.target.value })}
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs"
                >
                  <option value="RM">Raw Material (Polymer Base)</option>
                  <option value="MB">Masterbatch (Color / Additive)</option>
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-700 mb-1">Approved Grade / Code</label>
                <input
                  type="text"
                  placeholder={currentVendorNorm === 'atomberg' ? "e.g. PP H110MA or Gloss White MB" : "e.g. HIPS SH303 or White MB"}
                  value={newMaterial.approvedCode}
                  onChange={e => setNewMaterial({ ...newMaterial, approvedCode: e.target.value })}
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs"
                  required
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-700 mb-1">Approved Baseline Price (₹/kg)</label>
                <input
                  type="number"
                  step="0.01"
                  placeholder={currentVendorNorm === 'atomberg' ? "e.g. 131.00" : "e.g. 154.00"}
                  value={newMaterial.approvedPrice}
                  onChange={e => setNewMaterial({ ...newMaterial, approvedPrice: e.target.value })}
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs font-mono"
                  required
                />
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 border border-slate-300 rounded-xl font-bold cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold cursor-pointer"
                >
                  Register for {selectedVendor}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* PRODUCT USAGE INSPECTOR MODAL */}
      {viewingUsageMat && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-5 shadow-2xl space-y-4">
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <Package className="w-5 h-5 text-blue-600" />
                <div>
                  <h3 className="text-sm font-bold text-slate-900">Products Using Material</h3>
                  <p className="text-[11px] text-slate-500 font-mono">{viewingUsageMat.approvedCode} ({viewingUsageMat.type})</p>
                </div>
              </div>
              <button onClick={() => setViewingUsageMat(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="max-h-72 overflow-y-auto space-y-2">
              {activeUsageProducts.length === 0 ? (
                <div className="py-6 text-center text-slate-400 italic">
                  No baseline products are currently linked to "{viewingUsageMat.approvedCode}".
                </div>
              ) : (
                <table className="w-full text-left border-collapse text-xs">
                  <thead className="bg-slate-100 text-slate-700 uppercase font-bold text-[10px]">
                    <tr>
                      <th className="py-2 px-3">Part Code</th>
                      <th className="py-2 px-3">Component Name</th>
                      <th className="py-2 px-3 text-right">Net Wt</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {activeUsageProducts.map((p, i) => (
                      <tr key={i} className="hover:bg-slate-50">
                        <td className="py-2 px-3 font-mono font-bold text-blue-700">{p.itemCode}</td>
                        <td className="py-2 px-3 font-medium text-slate-800">{p.componentName}</td>
                        <td className="py-2 px-3 text-right font-mono font-bold">{p.netWeight}g</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <span className="text-[11px] text-slate-500 font-bold">Total: {activeUsageProducts.length} Linked Parts</span>
              <button
                onClick={() => setViewingUsageMat(null)}
                className="px-4 py-1.5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl font-bold cursor-pointer text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
RM_PAGE_EOF

echo "==> 3. Verifying build with Vite..."
npm run build

echo "==> 4. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ RM/MB DELETE & PRODUCT USAGE TRACKING DEPLOYED SUCCESSFULLY!"
echo "-------------------------------------------------------------------"
