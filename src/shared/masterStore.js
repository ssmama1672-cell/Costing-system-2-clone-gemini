// ============================================================================
// GLOBAL MASTER DATA STORE (Supabase Cloud Sync + Multi-Lot WA Engine)
// ============================================================================
import { supabase } from './supabaseClient';

const STORAGE_KEY = 'CPC_MASTER_STORE_DEV_V2_SUPABASE_SYNC_V1';

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
    const saved = localStorage.getItem(STORAGE_KEY);
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
  isLocked: false,
  isMatrixLocked: false,
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
  isLocked: initialStore.isLocked !== undefined ? initialStore.isLocked : false,
  isMatrixLocked: initialStore.isMatrixLocked !== undefined ? initialStore.isMatrixLocked : false,
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

// ============================================================================
// SUPABASE ASYNCHRONOUS DATA INITIALIZATION & SYNC
// ============================================================================
export async function initSupabaseData() {
  if (!supabase) return;
  try {
    const [
      { data: rmData },
      { data: prodsData },
      { data: purData },
      { data: salesData },
      { data: logsData }
    ] = await Promise.all([
      supabase.from('rm_mappings').select('*'),
      supabase.from('baseline_products').select('*'),
      supabase.from('purchases').select('*').order('date', { ascending: false }),
      supabase.from('sales').select('*').order('date', { ascending: false }),
      supabase.from('audit_logs').select('*').order('created_at', { ascending: false })
    ]);

    if (rmData) {
      globalStore.rmMappingsData = rmData.map(r => ({
        id: r.id,
        vendor: r.vendor,
        type: r.type,
        approvedCode: r.approved_code,
        approvedPrice: Number(r.approved_price || 0),
        selectedAlts: r.selected_alts || [r.approved_code],
        alt1Code: r.alt1_code,
        alt1Price: Number(r.alt1_price || 0),
        periodFrom: r.period_from,
        periodTo: r.period_to
      }));
    }

    if (prodsData) {
      globalStore.baselineProducts = prodsData.map(p => ({
        id: p.id,
        vendor: p.vendor,
        itemCode: p.item_code,
        componentName: p.component_name,
        model: p.model,
        mouldSize: p.mould_size,
        approvedRm: p.approved_rm,
        baseRm: p.base_rm,
        approvedMb: p.approved_mb,
        masterbatchPct: Number(p.masterbatch_pct || 4),
        cavity: Number(p.cavity || 1),
        netWeight: Number(p.net_weight || 0),
        runnerWeight: Number(p.runner_weight || 0),
        shotWeight: Number(p.shot_weight || 0),
        reconciliationWeight: Number(p.reconciliation_weight || 0),
        machineTonnage: Number(p.machine_tonnage || 200),
        shiftTariff: Number(p.shift_tariff || 2000),
        cycleTimeApproved: Number(p.cycle_time_approved || 47),
        meltLossPct: Number(p.melt_loss_pct || 1),
        efficiencyPct: Number(p.efficiency_pct || 95),
        approvedCost: Number(p.approved_cost || 0),
        approvedRmPrice: Number(p.approved_rm_price || 0),
        approvedMbPrice: Number(p.approved_mb_price || 0),
        haierOverheadPackage: Number(p.haier_overhead_package || 0),
        foamPolybag: Number(p.foam_polybag || 0),
        plasticBin: Number(p.plastic_bin || 0),
        freightCost: Number(p.freight_cost || 0),
        secondaryOp1: Number(p.secondary_op1 || 0),
        secondaryOp2: Number(p.secondary_op2 || 0),
        screenPrint1: Number(p.screen_print1 || 0),
        screenPrint2: Number(p.screen_print2 || 0),
        assemblyCost: Number(p.assembly_cost || 0),
        bopCost: Number(p.bop_cost || 0),
        mouldMaintenance: Number(p.mould_maintenance || 0),
        qualityInspection: Number(p.quality_inspection || 0),
        iccReduce: Number(p.icc_reduce || 0),
        scrapAdj: Number(p.scrap_adj || 0),
        packingCost: Number(p.packing_cost || 0),
        transportCost: Number(p.transport_cost || 0),
        otherCost: Number(p.other_cost || 0),
        parameters: p.parameters || {}
      }));
    }

    if (purData) {
      globalStore.purchases = purData.map(pur => ({
        id: pur.id,
        date: pur.date,
        vendor: pur.vendor,
        supplier: pur.supplier,
        invoiceNo: pur.invoice_no,
        itemCode: pur.item_code,
        grade: pur.grade,
        qty: Number(pur.qty || 0),
        rate: Number(pur.rate || 0),
        type: pur.type || 'RM'
      }));
    }

    if (salesData) {
      globalStore.sales = salesData.map(s => ({
        id: s.id,
        date: s.date,
        vendor: s.vendor,
        itemCode: s.item_code,
        invoiceNo: s.invoice_no,
        componentName: s.component_name,
        qty: Number(s.qty || 0),
        rate: Number(s.rate || 0),
        amount: Number(s.amount || 0)
      }));
    }

    if (logsData) {
      globalStore.auditLogs = logsData.map(l => ({
        id: l.id,
        timestamp: l.timestamp,
        partCode: l.part_code,
        componentName: l.component_name,
        vendor: l.vendor,
        modifications: l.modifications,
        costImpact: l.cost_impact,
        reason: l.reason
      }));
    }

    notifyStore();
  } catch (err) {
    console.error("Supabase sync error:", err);
  }
}

// Auto-trigger sync on load in browser
if (typeof window !== 'undefined') {
  initSupabaseData();
}

export function purgeAllTestData() {
  globalStore.rmMappingsData = [];
  globalStore.baselineProducts = [];
  globalStore.purchases = [];
  globalStore.sales = [];
  globalStore.auditLogs = [];
  if (typeof window !== 'undefined') {
    localStorage.removeItem(STORAGE_KEY);
  }
  if (supabase) {
    Promise.all([
      supabase.from('rm_mappings').delete().neq('id', '0'),
      supabase.from('baseline_products').delete().neq('id', '0'),
      supabase.from('purchases').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
      supabase.from('sales').delete().neq('id', '00000000-0000-0000-0000-000000000000'),
      supabase.from('audit_logs').delete().neq('id', '00000000-0000-0000-0000-000000000000')
    ]).catch(console.error);
  }
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

  let targetId = item.id;
  if (idx >= 0) {
    targetId = globalStore.rmMappingsData[idx].id;
    globalStore.rmMappingsData[idx] = { 
      ...globalStore.rmMappingsData[idx], 
      ...item, 
      approvedCode: cleanCode, 
      selectedAlts: item.selectedAlts || globalStore.rmMappingsData[idx].selectedAlts || [cleanCode], 
      vendor: item.vendor || globalStore.rmMappingsData[idx].vendor 
    };
  } else {
    targetId = item.id || `mat-${vNorm}-${Date.now()}-${Math.random().toString(36).substr(2,4)}`;
    globalStore.rmMappingsData.push({ 
      id: targetId, 
      ...item, 
      approvedCode: cleanCode, 
      selectedAlts: item.selectedAlts || [cleanCode] 
    });
  }
  notifyStore();

  if (supabase) {
    supabase.from('rm_mappings').upsert({
      id: targetId,
      vendor: item.vendor || 'Haier Appliances',
      type: item.type,
      approved_code: cleanCode,
      approved_price: Number(item.approvedPrice || 0),
      selected_alts: item.selectedAlts || [cleanCode],
      alt1_code: item.alt1Code || cleanCode,
      alt1_price: Number(item.alt1Price || item.approvedPrice || 0),
      period_from: item.periodFrom || '2026-08-01',
      period_to: item.periodTo || '2026-08-31',
      updated_at: new Date().toISOString()
    }).catch(console.error);
  }
}

export function updateRmMappingRow(rowId, updatedFields) {
  if (!globalStore.rmMappingsData) globalStore.rmMappingsData = [];
  const idx = globalStore.rmMappingsData.findIndex(r => r.id === rowId);
  if (idx >= 0) {
    globalStore.rmMappingsData[idx] = { ...globalStore.rmMappingsData[idx], ...updatedFields };
    notifyStore();

    if (supabase) {
      const r = globalStore.rmMappingsData[idx];
      supabase.from('rm_mappings').update({
        approved_price: Number(r.approvedPrice || 0),
        selected_alts: r.selectedAlts || [],
        alt1_price: Number(r.alt1Price || 0),
        updated_at: new Date().toISOString()
      }).eq('id', rowId).catch(console.error);
    }
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

  if (supabase) {
    supabase.from('rm_mappings').delete().eq('id', id).catch(console.error);
  }
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

  if (supabase) {
    supabase.from('vendor_schedules').upsert({
      vendor_id: vendor,
      period_from: periodFrom,
      period_to: periodTo,
      saved_at: new Date().toISOString()
    }, { onConflict: 'vendor_id,period_from,period_to' }).catch(console.error);
  }

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

  if (supabase) {
    supabase.from('baseline_products').upsert({
      id: prod.id || prod.itemCode,
      vendor: prod.vendor,
      item_code: prod.itemCode,
      component_name: prod.componentName,
      model: prod.model,
      mould_size: prod.mouldSize,
      approved_rm: prod.approvedRm,
      base_rm: prod.baseRm,
      approved_mb: prod.approvedMb,
      masterbatch_pct: Number(prod.masterbatchPct || 4),
      cavity: Number(prod.cavity || 1),
      net_weight: Number(prod.netWeight || 0),
      runner_weight: Number(prod.runnerWeight || 0),
      shot_weight: Number(prod.shotWeight || 0),
      reconciliation_weight: Number(prod.reconciliationWeight || 0),
      machine_tonnage: Number(prod.machineTonnage || 200),
      shift_tariff: Number(prod.shiftTariff || 2000),
      cycle_time_approved: Number(prod.cycleTimeApproved || 47),
      melt_loss_pct: Number(prod.meltLossPct || 1),
      efficiency_pct: Number(prod.efficiencyPct || 95),
      approved_cost: Number(prod.approvedCost || 0),
      approved_rm_price: Number(prod.approvedRmPrice || 0),
      approved_mb_price: Number(prod.approvedMbPrice || 0),
      haier_overhead_package: Number(prod.haierOverheadPackage || 0),
      foam_polybag: Number(prod.foamPolybag || 0),
      plastic_bin: Number(prod.plasticBin || 0),
      freight_cost: Number(prod.freightCost || 0),
      secondary_op1: Number(prod.secondaryOp1 || 0),
      secondary_op2: Number(prod.secondaryOp2 || 0),
      screen_print1: Number(prod.screenPrint1 || 0),
      screen_print2: Number(prod.screenPrint2 || 0),
      assembly_cost: Number(prod.assemblyCost || 0),
      bop_cost: Number(prod.bopCost || 0),
      mould_maintenance: Number(prod.mouldMaintenance || 0),
      quality_inspection: Number(prod.qualityInspection || 0),
      icc_reduce: Number(prod.iccReduce || 0),
      scrap_adj: Number(prod.scrapAdj || 0),
      packing_cost: Number(prod.packingCost || 0),
      transport_cost: Number(prod.transportCost || 0),
      other_cost: Number(prod.otherCost || 0),
      parameters: prod.parameters || {},
      updated_at: new Date().toISOString()
    }).catch(console.error);
  }
}

export function addStagedProductsToBaseline(stagedList, vendor) {
  const upsertRows = [];

  stagedList.forEach(staged => {
    const cleanRm = sanitizeMaterialName(staged.approvedRm || staged.baseRm, staged.componentName, staged.itemCode, vendor);
    const idx = globalStore.baselineProducts.findIndex(p => p.itemCode === staged.itemCode && normalizeVendorId(p.vendor) === normalizeVendorId(vendor));
    let targetId = staged.id;

    if (idx >= 0) {
      targetId = globalStore.baselineProducts[idx].id;
      globalStore.baselineProducts[idx] = { ...globalStore.baselineProducts[idx], ...staged, approvedRm: cleanRm, vendor: vendor || staged.vendor };
    } else {
      targetId = staged.id || `prod-${Date.now()}-${Math.random().toString(36).substr(2,4)}`;
      globalStore.baselineProducts.push({ ...staged, approvedRm: cleanRm, id: targetId, vendor: vendor || staged.vendor });
    }

    upsertRows.push({
      id: targetId,
      vendor: vendor || staged.vendor,
      item_code: staged.itemCode,
      component_name: staged.componentName,
      model: staged.model,
      mould_size: staged.mouldSize,
      approved_rm: cleanRm,
      base_rm: staged.baseRm || cleanRm,
      approved_mb: staged.approvedMb || 'None',
      masterbatch_pct: Number(staged.masterbatchPct || 4),
      cavity: Number(staged.cavity || 1),
      net_weight: Number(staged.netWeight || 0),
      runner_weight: Number(staged.runnerWeight || 0),
      shot_weight: Number(staged.shotWeight || 0),
      reconciliation_weight: Number(staged.reconciliationWeight || 0),
      machine_tonnage: Number(staged.machineTonnage || 200),
      shift_tariff: Number(staged.shiftTariff || 2000),
      cycle_time_approved: Number(staged.cycleTimeApproved || 47),
      melt_loss_pct: Number(staged.meltLossPct || 1),
      efficiency_pct: Number(staged.efficiencyPct || 95),
      approved_cost: Number(staged.approvedCost || 0),
      approved_rm_price: Number(staged.approvedRmPrice || 0),
      approved_mb_price: Number(staged.approvedMbPrice || 0),
      haier_overhead_package: Number(staged.haierOverheadPackage || 0),
      foam_polybag: Number(staged.foamPolybag || 0),
      plastic_bin: Number(staged.plasticBin || 0),
      freight_cost: Number(staged.freightCost || 0),
      secondary_op1: Number(staged.secondaryOp1 || 0),
      secondary_op2: Number(staged.secondaryOp2 || 0),
      screen_print1: Number(staged.screenPrint1 || 0),
      screen_print2: Number(staged.screenPrint2 || 0),
      assembly_cost: Number(staged.assemblyCost || 0),
      bop_cost: Number(staged.bopCost || 0),
      mould_maintenance: Number(staged.mouldMaintenance || 0),
      quality_inspection: Number(staged.qualityInspection || 0),
      icc_reduce: Number(staged.iccReduce || 0),
      scrap_adj: Number(staged.scrapAdj || 0),
      packing_cost: Number(staged.packingCost || 0),
      transport_cost: Number(staged.transportCost || 0),
      other_cost: Number(staged.otherCost || 0),
      parameters: staged.parameters || {},
      updated_at: new Date().toISOString()
    });
  });

  notifyStore();

  if (supabase && upsertRows.length > 0) {
    supabase.from('baseline_products').upsert(upsertRows).catch(console.error);
  }
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

  if (supabase) {
    supabase.from('baseline_products').delete().or(`id.eq.${itemId},item_code.eq.${itemId}`).catch(console.error);
  }
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

  if (supabase) {
    supabase.from('baseline_products').delete().ilike('vendor', `%${vendorName}%`).catch(console.error);
  }
}

export function addAuditLog(entry) {
  const logItem = {
    timestamp: new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }),
    ...entry
  };
  globalStore.auditLogs = globalStore.auditLogs || [];
  globalStore.auditLogs.unshift(logItem);

  if (supabase) {
    supabase.from('audit_logs').insert({
      timestamp: logItem.timestamp,
      part_code: logItem.partCode,
      component_name: logItem.componentName,
      vendor: logItem.vendor,
      modifications: logItem.modifications,
      cost_impact: logItem.costImpact,
      reason: logItem.reason
    }).catch(console.error);
  }
}

export function toggleGlobalLock() { 
  globalStore.isLocked = !globalStore.isLocked; 
  notifyStore(); 
}

export function toggleMatrixLock() { 
  globalStore.isMatrixLocked = !globalStore.isMatrixLocked; 
  notifyStore(); 
}

export function addDayWisePurchase(rec) {
  globalStore.purchases = globalStore.purchases || [];
  globalStore.purchases.unshift(rec);
  notifyStore();

  if (supabase) {
    supabase.from('purchases').insert({
      date: rec.date || '2026-08-15',
      vendor: rec.vendor || 'Haier Appliances',
      supplier: rec.supplier || rec.supplierName || '',
      invoice_no: rec.invoiceNo || '',
      item_code: rec.itemCode || '',
      grade: rec.grade || '',
      qty: Number(rec.qty || 0),
      rate: Number(rec.rate || 0),
      type: rec.type || 'RM'
    }).catch(console.error);
  }
  return { success: true };
}

export function addDayWiseSales(rec) {
  globalStore.sales = globalStore.sales || [];
  globalStore.sales.unshift(rec);
  notifyStore();

  if (supabase) {
    supabase.from('sales').insert({
      date: rec.date || '2026-08-15',
      vendor: rec.vendor || 'Haier Appliances',
      item_code: rec.itemCode || '',
      invoice_no: rec.invoiceNo || '',
      component_name: rec.componentName || '',
      qty: Number(rec.qty || 0),
      rate: Number(rec.rate || rec.sellingPrice || 0),
      amount: Number(rec.amount || (Number(rec.qty || 0) * Number(rec.rate || rec.sellingPrice || 0)))
    }).catch(console.error);
  }
  return { success: true };
}

export function onboardVendorWithBlueprint() { notifyStore(); }
