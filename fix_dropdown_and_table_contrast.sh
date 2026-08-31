#!/usr/bin/env bash
set -e

echo "==> 1. Updating src/index.css with global high-contrast rules for dropdowns and disabled inputs..."
cat << 'CSS_EOF' > src/index.css
@import "tailwindcss";

@layer base {
  body {
    font-feature-settings: "cv02", "cv03", "cv04", "cv11";
  }
}

/* Force dark, bold text on all native select dropdown options across all browsers */
select, select option, select optgroup {
  background-color: #ffffff !important;
  color: #0f172a !important;
  font-weight: 700 !important;
}

/* Ensure disabled inputs and dropdowns remain high-contrast and legible */
select:disabled, input:disabled {
  opacity: 1 !important;
  color: #0f172a !important;
  -webkit-text-fill-color: #0f172a !important;
  background-color: #f8fafc !important;
  cursor: default !important;
}

.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
CSS_EOF

echo "==> 2. Updating RMPriceMatrixPage.jsx to ensure high contrast in all dropdowns, rows, and inputs..."
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
            <p className="text-[11px] text-slate-300">Synchronized RM & MB Baseline to Purchase Weighted Average Mapping</p>
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
            activeTab === 'matrix' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-700 hover:bg-slate-100 font-semibold'
          }`}
        >
          <Layers className="w-4 h-4" /> RM Price Matrix ({vendorMaterials.length})
        </button>
        <button
          onClick={() => setActiveTab('purchases')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'purchases' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-700 hover:bg-slate-100 font-semibold'
          }`}
        >
          <ShoppingBag className="w-4 h-4" /> Day-wise Purchases ({purchases.length})
        </button>
        <button
          onClick={() => setActiveTab('sales')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'sales' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-700 hover:bg-slate-100 font-semibold'
          }`}
        >
          <TrendingUp className="w-4 h-4" /> Day-wise Sales ({sales.length})
        </button>
        <button
          onClick={() => setActiveTab('changelog')}
          className={`px-4 py-2 rounded-xl font-bold transition-all cursor-pointer flex items-center gap-2 ${
            activeTab === 'changelog' ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-700 hover:bg-slate-100 font-semibold'
          }`}
        >
          <History className="w-4 h-4" /> Baseline & RM Change Log ({auditLogs.length})
        </button>
      </div>

      {/* Filter Row with Level 2 Matrix Rates Lock & Save for Vendor + Period */}
      <div className="bg-white p-3 rounded-2xl border border-slate-200 shadow-xs flex flex-wrap justify-between items-center gap-3">
        <div className="flex items-center gap-2">
          <span className="font-bold text-slate-900">FILTER: Vendor:</span>
          <select
            value={selectedVendor}
            onChange={e => setSelectedVendor(e.target.value)}
            className="px-3 py-1.5 rounded-xl bg-slate-100 text-slate-900 border border-slate-300 font-bold text-xs"
          >
            {vendors.map(v => (
              <option key={v.vendorId} value={v.vendorId} className="text-slate-900 font-bold bg-white">{v.vendorName}</option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-slate-900 font-bold">Period: From</span>
          <input 
            type="date" 
            value={periodFrom} 
            onChange={e => setPeriodFrom(e.target.value)} 
            className="px-2 py-1 rounded-xl bg-white border border-slate-300 text-xs font-mono font-bold text-slate-900" 
          />
          <span className="text-slate-900 font-bold">To</span>
          <input 
            type="date" 
            value={periodTo} 
            onChange={e => setPeriodTo(e.target.value)} 
            className="px-2 py-1 rounded-xl bg-white border border-slate-300 text-xs font-mono font-bold text-slate-900" 
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

      {/* TAB 1: RM PRICE MATRIX */}
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
              <tbody className="divide-y divide-slate-200">
                {vendorMaterials.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-12 text-center text-slate-500 font-bold">
                      No material codes mapped specifically for {selectedVendor}. Upload a baseline sheet in <b>1. Baseline Master</b> to auto-register grades.
                    </td>
                  </tr>
                ) : (
                  vendorMaterials.map(m => {
                    const activeAlt = m.activeAlt || 'alt1';
                    const usingProds = getProductsUsingMaterial(m.approvedCode, selectedVendor);

                    return (
                      <tr key={m.id} className="hover:bg-slate-50 transition">
                        <td className="py-3 px-4">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2">
                              <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                m.type === 'MB' ? 'bg-purple-100 text-purple-900 font-bold' : 'bg-blue-100 text-blue-900 font-bold'
                              }`}>
                                {m.type === 'MB' ? 'MASTERBATCH' : 'RM CODE'}
                              </span>
                              <span className="font-bold text-slate-900">{m.approvedCode}</span>
                            </div>
                            
                            <div>
                              <button
                                onClick={() => setViewingUsageMat(m)}
                                className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold cursor-pointer transition ${
                                  usingProds.length > 0 
                                    ? 'bg-emerald-100 text-emerald-900 border border-emerald-300 hover:bg-emerald-200' 
                                    : 'bg-slate-100 text-slate-700 border border-slate-300 hover:bg-slate-200'
                                }`}
                              >
                                <Package className="w-3 h-3 text-emerald-700" />
                                {usingProds.length > 0 ? `Used in ${usingProds.length} Part(s)` : '0 Parts Linked (Unused)'}
                              </button>
                            </div>
                          </div>
                        </td>

                        <td className="py-3 px-4 text-center">
                          <div className="inline-flex items-center bg-amber-50 border border-amber-300 rounded-lg px-2 py-1 shadow-2xs">
                            <span className="text-amber-950 font-bold mr-1">₹</span>
                            <input
                              type="number"
                              step="0.01"
                              disabled={isRowDisabled}
                              value={m.approvedPrice || ''}
                              onChange={(e) => handleApprovedPriceChange(m.id, e.target.value)}
                              className="w-16 bg-transparent font-black text-amber-950 text-center outline-hidden"
                            />
                          </div>
                        </td>

                        {/* Alternate RM-1 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt1Code || m.approvedCode}
                              onChange={(e) => handleAltSelectChange(m.id, 1, e.target.value, m.approvedCode, m.approvedPrice)}
                              className="w-full px-2 py-1 rounded-lg border border-slate-300 font-bold text-xs bg-white text-slate-900 shadow-2xs"
                            >
                              <option value={m.approvedCode} className="text-slate-900 font-bold bg-white">{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code} className="text-slate-900 font-semibold bg-white">{opt.label}</option>
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
                                <span className="text-[10px] text-slate-800 font-bold">Set Active</span>
                              </label>
                              {activeAlt === 'alt1' && (
                                <span className="px-1.5 py-0.2 bg-blue-600 text-white rounded text-[9px] font-black uppercase tracking-wider">
                                  ACTIVE
                                </span>
                              )}
                            </div>
                          </div>
                        </td>

                        <td className="py-3 px-4 text-center">
                          <span className="font-mono font-black text-blue-900 text-xs">
                            ₹{Number(m.alt1Price !== undefined ? m.alt1Price : m.approvedPrice || 0).toFixed(2)}
                          </span>
                        </td>

                        {/* Alternate RM-2 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt2Code || ''}
                              onChange={(e) => handleAltSelectChange(m.id, 2, e.target.value, m.approvedCode, m.approvedPrice)}
                              className="w-full px-2 py-1 rounded-lg border border-slate-300 font-bold text-xs bg-white text-slate-900 shadow-2xs"
                            >
                              <option value="" className="text-slate-700 bg-white">Select Alternate Lot 2</option>
                              <option value={m.approvedCode} className="text-slate-900 font-bold bg-white">{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code} className="text-slate-900 font-semibold bg-white">{opt.label}</option>
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
                                <span className="text-[10px] text-slate-800 font-bold">Set Active</span>
                              </label>
                              <span className={`px-1.5 py-0.2 rounded text-[9px] font-black uppercase tracking-wider ${
                                activeAlt === 'alt2' ? 'bg-blue-600 text-white' : 'bg-slate-200 text-slate-700 font-bold'
                              }`}>
                                {activeAlt === 'alt2' ? 'ACTIVE' : 'STANDBY'}
                              </span>
                            </div>
                          </div>
                        </td>

                        <td className="py-3 px-4 text-center">
                          <span className="font-mono font-black text-slate-900 text-xs">
                            ₹{Number(m.alt2Price || 0).toFixed(2)}
                          </span>
                        </td>

                        {/* Alternate RM-3 */}
                        <td className="py-3 px-4">
                          <div className="space-y-1.5">
                            <select
                              disabled={isRowDisabled}
                              value={m.alt3Code || ''}
                              onChange={(e) => handleAltSelectChange(m.id, 3, e.target.value, m.approvedCode, m.approvedPrice)}
                              className="w-full px-2 py-1 rounded-lg border border-slate-300 font-bold text-xs bg-white text-slate-900 shadow-2xs"
                            >
                              <option value="" className="text-slate-700 bg-white">Select Alternate Lot 3</option>
                              <option value={m.approvedCode} className="text-slate-900 font-bold bg-white">{m.approvedCode} (Contract Baseline)</option>
                              {allPurchasedGradeOptions.map((opt, i) => (
                                <option key={i} value={opt.code} className="text-slate-900 font-semibold bg-white">{opt.label}</option>
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
                                <span className="text-[10px] text-slate-800 font-bold">Set Active</span>
                              </label>
                              <span className={`px-1.5 py-0.2 rounded text-[9px] font-black uppercase tracking-wider ${
                                activeAlt === 'alt3' ? 'bg-blue-600 text-white' : 'bg-slate-200 text-slate-700 font-bold'
                              }`}>
                                {activeAlt === 'alt3' ? 'ACTIVE' : 'STANDBY'}
                              </span>
                            </div>
                          </div>
                        </td>

                        <td className="py-3 px-4 text-center">
                          <span className="font-mono font-black text-slate-900 text-xs">
                            ₹{Number(m.alt3Price || 0).toFixed(2)}
                          </span>
                        </td>

                        <td className="py-3 px-3 text-center">
                          <button
                            onClick={() => handleDeleteMaterial(m)}
                            disabled={isGlobalLocked}
                            title="Delete this material code"
                            className={`p-1.5 rounded-lg transition cursor-pointer ${
                              isGlobalLocked 
                                ? 'text-slate-300 cursor-not-allowed' 
                                : 'text-rose-600 hover:bg-rose-50 hover:text-rose-800'
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
              <span className="font-black text-slate-900 text-xs uppercase">Add Purchase Inward ({selectedVendor})</span>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleDownloadPurchaseTemplate}
                  className="px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-800 border border-slate-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs transition"
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
                className="px-2.5 py-1.5 rounded-xl border border-slate-300 font-mono text-xs font-bold text-slate-900 bg-white" 
              />
              <input 
                type="text" 
                placeholder="Supplier Name" 
                value={purchaseForm.supplierName} 
                onChange={e => setPurchaseForm({ ...purchaseForm, supplierName: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[120px] font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <input 
                type="text" 
                placeholder="Invoice #" 
                value={purchaseForm.invoiceNo} 
                onChange={e => setPurchaseForm({ ...purchaseForm, invoiceNo: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono font-bold text-slate-900 bg-white w-28 placeholder-slate-400" 
              />
              <input 
                type="text" 
                placeholder="Item Code" 
                value={purchaseForm.itemCode} 
                onChange={e => setPurchaseForm({ ...purchaseForm, itemCode: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono font-bold text-slate-900 bg-white w-28 placeholder-slate-400" 
              />
              <input 
                type="text" 
                placeholder="Grade Description" 
                value={purchaseForm.grade} 
                onChange={e => setPurchaseForm({ ...purchaseForm, grade: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[140px] font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <input 
                type="number" 
                placeholder="Qty (kg)" 
                value={purchaseForm.qty} 
                onChange={e => setPurchaseForm({ ...purchaseForm, qty: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24 font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <input 
                type="number" 
                step="0.01" 
                placeholder="Rate (₹/kg)" 
                value={purchaseForm.rate} 
                onChange={e => setPurchaseForm({ ...purchaseForm, rate: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24 font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <button 
                type="submit" 
                disabled={isGlobalLocked}
                className={`px-4 py-1.5 rounded-xl font-bold shadow-xs text-xs ${
                  isGlobalLocked ? 'bg-slate-200 text-slate-500 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer'
                }`}
              >
                + Add Inward
              </button>
            </form>
          </div>

          <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
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
              <tbody className="divide-y divide-slate-200">
                {purchases.length === 0 ? (
                  <tr><td colSpan={7} className="py-8 text-center text-slate-500 font-bold">No inward purchase records found specifically for {selectedVendor}.</td></tr>
                ) : (
                  purchases.map((p, idx) => (
                    <tr key={idx} className="hover:bg-slate-50 font-medium">
                      <td className="py-2.5 px-3 font-mono font-bold text-slate-800">{p.date}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{p.supplier || p.supplierName || '-'}</td>
                      <td className="py-2.5 px-3 font-mono font-black text-blue-700">{p.invoiceNo}</td>
                      <td className="py-2.5 px-3 font-mono font-bold text-slate-800">{p.itemCode || '-'}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{p.grade}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">{Number(p.qty || 0).toLocaleString()} kg</td>
                      <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{Number(p.rate || 0).toFixed(2)}</td>
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
              <span className="font-black text-slate-900 text-xs uppercase">Add Dispatch Sale ({selectedVendor})</span>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleDownloadSalesTemplate}
                  className="px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-800 border border-slate-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs transition"
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
                className="px-2.5 py-1.5 rounded-xl border border-slate-300 font-mono text-xs font-bold text-slate-900 bg-white" 
              />
              <select
                value={salesForm.vendor}
                onChange={e => setSalesForm({ ...salesForm, vendor: e.target.value })}
                className="px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs bg-white text-slate-900"
              >
                {vendors.map(v => (
                  <option key={v.vendorId} value={v.vendorId} className="text-slate-900 font-semibold bg-white">{v.vendorName}</option>
                ))}
              </select>
              <input 
                type="text" 
                placeholder="Item Code" 
                value={salesForm.itemCode} 
                onChange={e => setSalesForm({ ...salesForm, itemCode: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono font-bold text-slate-900 bg-white w-28 placeholder-slate-400" 
              />
              <input 
                type="text" 
                placeholder="Invoice Number" 
                value={salesForm.invoiceNo} 
                onChange={e => setSalesForm({ ...salesForm, invoiceNo: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-mono font-bold text-slate-900 bg-white w-28 placeholder-slate-400" 
              />
              <input 
                type="text" 
                placeholder="Component Name" 
                value={salesForm.componentName} 
                onChange={e => setSalesForm({ ...salesForm, componentName: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs flex-1 min-w-[140px] font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <input 
                type="number" 
                placeholder="Dispatch Qty" 
                value={salesForm.qty} 
                onChange={e => setSalesForm({ ...salesForm, qty: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24 font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <input 
                type="number" 
                step="0.01" 
                placeholder="Selling Price" 
                value={salesForm.sellingPrice} 
                onChange={e => setSalesForm({ ...salesForm, sellingPrice: e.target.value })} 
                className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs w-24 font-bold text-slate-900 bg-white placeholder-slate-400" 
              />
              <button 
                type="submit" 
                disabled={isGlobalLocked}
                className={`px-4 py-1.5 rounded-xl font-bold shadow-xs text-xs ${
                  isGlobalLocked ? 'bg-slate-200 text-slate-500 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 text-white cursor-pointer'
                }`}
              >
                + Record Dispatch
              </button>
            </form>
          </div>

          <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
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
              <tbody className="divide-y divide-slate-200">
                {sales.length === 0 ? (
                  <tr><td colSpan={7} className="py-8 text-center text-slate-500 font-bold">No dispatch records recorded specifically for {selectedVendor}.</td></tr>
                ) : (
                  sales.map((s, idx) => (
                    <tr key={idx} className="hover:bg-slate-50 font-medium">
                      <td className="py-2.5 px-3 font-mono font-bold text-slate-800">{s.date}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{s.vendor}</td>
                      <td className="py-2.5 px-3 font-mono font-black text-blue-700">{s.itemCode}</td>
                      <td className="py-2.5 px-3 font-mono font-bold text-slate-800">{s.invoiceNo}</td>
                      <td className="py-2.5 px-3 font-bold text-slate-900">{s.componentName}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">{Number(s.qty || 0).toLocaleString()}</td>
                      <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{Number(s.rate || s.sellingPrice || 0).toFixed(2)}</td>
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
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th className="py-2.5 px-3">Timestamp</th>
                <th className="py-2.5 px-3">Code / Ref</th>
                <th className="py-2.5 px-4">Component / Target</th>
                <th className="py-2.5 px-4">Modifications</th>
                <th className="py-2.5 px-3 text-right">Cost Impact</th>
                <th className="py-2.5 px-4">Reason</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {auditLogs.map((log, idx) => (
                <tr key={idx} className="hover:bg-slate-50 font-medium">
                  <td className="py-2.5 px-3 font-mono font-bold text-slate-700">{log.timestamp}</td>
                  <td className="py-2.5 px-3 font-mono font-black text-blue-700">{log.partCode}</td>
                  <td className="py-2.5 px-4 font-bold text-slate-900">{log.componentName}</td>
                  <td className="py-2.5 px-4 font-mono font-bold text-[11px] text-slate-800">{log.modifications}</td>
                  <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">{log.costImpact}</td>
                  <td className="py-2.5 px-4 font-semibold text-slate-700">{log.reason}</td>
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
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs bg-white text-slate-900"
                >
                  <option value="RM" className="bg-white text-slate-900">Raw Material (Polymer Base)</option>
                  <option value="MB" className="bg-white text-slate-900">Masterbatch (Color / Additive)</option>
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-700 mb-1">Approved Grade / Code</label>
                <input
                  type="text"
                  placeholder={currentVendorNorm === 'atomberg' ? "e.g. PP H110MA or Gloss White MB" : "e.g. HIPS SH303 or White MB"}
                  value={newMaterial.approvedCode}
                  onChange={e => setNewMaterial({ ...newMaterial, approvedCode: e.target.value })}
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs bg-white text-slate-900"
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
                  className="w-full px-3 py-1.5 rounded-xl border border-slate-300 font-bold text-xs font-mono bg-white text-slate-900"
                  required
                />
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-4 py-2 border border-slate-300 rounded-xl font-bold cursor-pointer text-slate-700"
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
                        <td className="py-2 px-3 text-right font-mono font-bold text-slate-900">{p.netWeight}g</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <span className="text-[11px] text-slate-700 font-bold">Total: {activeUsageProducts.length} Linked Parts</span>
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

echo "==> 3. Updating MISVariancePage.jsx with high-contrast text across all tables..."
cat << 'MIS_PAGE_EOF' > src/modules/module4-mis/MISVariancePage.jsx
import React, { useState, useEffect } from 'react';
import { 
  Download, 
  Layers, 
  Activity, 
  ArrowUpRight, 
  ArrowDownRight, 
  DollarSign, 
  TrendingUp, 
  Database,
  Calendar,
  Filter,
  FileSpreadsheet
} from 'lucide-react';
import * as XLSX from 'xlsx';
import { globalStore, subscribeStore, getActiveRmMapping, normalizeVendorId } from '../../shared/masterStore';
import { calculateDetailedCost } from '../module1-baseline/InlineEditModal';

export default function MISVariancePage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('ALL');
  const [drilldownVendor, setDrilldownVendor] = useState('Haier Appliances');
  const [periodFrom, setPeriodFrom] = useState('2026-08-01');
  const [periodTo, setPeriodTo] = useState('2026-08-31');
  const [activeTab, setActiveTab] = useState('summary');

  useEffect(() => {
    const unsub = subscribeStore(() => setStoreState({ ...globalStore }));
    return () => unsub();
  }, []);

  const vendors = storeState.vendors || [
    { vendorId: 'Haier Appliances', vendorName: 'Haier Appliances' },
    { vendorId: 'Atomberg Technologies', vendorName: 'Atomberg Technologies' },
    { vendorId: 'Atharva Polymer', vendorName: 'Atharva Polymer' }
  ];

  const sales = storeState.sales || [];
  const purchases = storeState.purchases || [];
  const baselineProducts = storeState.baselineProducts || [];

  const filteredSales = sales.filter(s => {
    const sVendorNorm = normalizeVendorId(s.vendor);
    const matchVendor = selectedVendor === 'ALL' || sVendorNorm === normalizeVendorId(selectedVendor);
    const sDate = s.date || s.invoiceDate || '';
    const matchDate = (!periodFrom || sDate >= periodFrom) && (!periodTo || sDate <= periodTo);
    return matchVendor && matchDate;
  });

  const productSummaryMap = {};
  let totalVolume = 0;
  let totalRevenue = 0;
  let totalApprovedCost = 0;
  let totalActualCost = 0;

  filteredSales.forEach(s => {
    const code = s.itemCode || s.partCode || 'UNKNOWN';
    const qty = Number(s.qty || s.quantity || 0);
    const rev = Number(s.amount || s.totalAmount || (qty * Number(s.rate || s.price || 0)));
    const baseProd = baselineProducts.find(b => b.itemCode === code && normalizeVendorId(b.vendor) === normalizeVendorId(s.vendor)) || {};
    const detailed = calculateDetailedCost(baseProd);
    
    const approvedUnitCost = Number(detailed.approvedBaselineCost || baseProd.approvedCost || 0);
    const actualUnitCost = Number(detailed.simulatedActualCost || detailed.finalLanded || approvedUnitCost);
    const unitGainLoss = approvedUnitCost - actualUnitCost;

    totalVolume += qty;
    totalRevenue += rev;
    totalApprovedCost += (approvedUnitCost * qty);
    totalActualCost += (actualUnitCost * qty);

    if (!productSummaryMap[code]) {
      productSummaryMap[code] = {
        itemCode: code,
        componentName: s.componentName || baseProd.componentName || code,
        vendor: s.vendor || baseProd.vendor || 'Haier Appliances',
        invoicesCount: 0,
        totalQty: 0,
        totalRevenue: 0,
        approvedUnitCost: approvedUnitCost,
        actualUnitCost: actualUnitCost,
        unitGainLoss: unitGainLoss,
        totalGainLoss: 0
      };
    }

    productSummaryMap[code].invoicesCount += 1;
    productSummaryMap[code].totalQty += qty;
    productSummaryMap[code].totalRevenue += rev;
    productSummaryMap[code].totalGainLoss += (unitGainLoss * qty);
  });

  const productSummaryList = Object.values(productSummaryMap);
  const totalCostGainLoss = totalApprovedCost - totalActualCost;
  const grossProfit = totalRevenue - totalActualCost;
  const grossMarginPct = totalRevenue > 0 ? ((grossProfit / totalRevenue) * 100).toFixed(1) : '0';

  const vendorBreakdowns = vendors.map(v => {
    const vSales = sales.filter(s => normalizeVendorId(s.vendor) === normalizeVendorId(v.vendorId));
    let currentRev = 0;
    let currentGainLoss = 0;

    vSales.forEach(s => {
      const q = Number(s.qty || 0);
      const r = Number(s.amount || (q * Number(s.rate || 0)));
      const bp = baselineProducts.find(b => b.itemCode === (s.itemCode || s.partCode) && normalizeVendorId(b.vendor) === normalizeVendorId(v.vendorId)) || {};
      const det = calculateDetailedCost(bp);
      const appCost = Number(det.approvedBaselineCost || bp.approvedCost || 0);
      const actCost = Number(det.simulatedActualCost || det.finalLanded || appCost);
      currentRev += r;
      currentGainLoss += ((appCost - actCost) * q);
    });

    return {
      vendorName: v.vendorName,
      currentRev,
      currentGainLoss,
      prevRev: 0,
      prevGainLoss: 0,
      growthPct: '+0%',
      varianceDelta: currentGainLoss
    };
  });

  const allVendorsRev = vendorBreakdowns.reduce((acc, v) => acc + v.currentRev, 0);
  const allVendorsGainLoss = vendorBreakdowns.reduce((acc, v) => acc + v.currentGainLoss, 0);

  const drilldownSales = sales.filter(s => {
    const sv = (s.vendor || '').toLowerCase();
    return drilldownVendor === 'ALL' || sv.includes(drilldownVendor.toLowerCase()) || drilldownVendor.toLowerCase().includes(sv);
  });

  const drilldownSummaryMap = {};
  drilldownSales.forEach(s => {
    const code = s.itemCode || s.partCode;
    const qty = Number(s.qty || 0);
    const bp = baselineProducts.find(b => b.itemCode === code && normalizeVendorId(b.vendor) === normalizeVendorId(s.vendor)) || {};
    const det = calculateDetailedCost(bp);
    const appCost = Number(det.approvedBaselineCost || bp.approvedCost || 0);
    const actCost = Number(det.simulatedActualCost || det.finalLanded || appCost);
    const gainLoss = (appCost - actCost) * qty;

    if (!drilldownSummaryMap[code]) {
      drilldownSummaryMap[code] = {
        itemCode: code,
        componentName: s.componentName || bp.componentName || code,
        gainLoss: 0
      };
    }
    drilldownSummaryMap[code].gainLoss += gainLoss;
  });

  const drilldownParts = Object.values(drilldownSummaryMap);
  const topProfitParts = drilldownParts.filter(p => p.gainLoss > 0).sort((a,b) => b.gainLoss - a.gainLoss).slice(0, 3);
  const topLossParts = drilldownParts.filter(p => p.gainLoss < 0).sort((a,b) => a.gainLoss - b.gainLoss).slice(0, 3);

  let haierRmDelta = 0, atomRmDelta = 0;
  let haierMbDelta = 0, atomMbDelta = 0;

  purchases.forEach(p => {
    const isHaier = (p.vendor || '').toLowerCase().includes('haier');
    const isAtom = (p.vendor || '').toLowerCase().includes('atomberg');
    const rmMap = getActiveRmMapping(p.grade || p.itemCode, p.vendor);
    const appRate = Number(rmMap.approvedPrice || 0);
    const actRate = Number(p.rate || p.netRate || 0);
    const qty = Number(p.qty || 0);

    if (appRate > 0 && actRate > 0) {
      const delta = (appRate - actRate) * qty;
      const isMb = p.type === 'MB' || (p.grade || '').toLowerCase().includes('mb');
      if (isMb) {
        if (isHaier) haierMbDelta += delta;
        if (isAtom) atomMbDelta += delta;
      } else {
        if (isHaier) haierRmDelta += delta;
        if (isAtom) atomRmDelta += delta;
      }
    }
  });

  const handleExportRealizationSection = () => {
    const dataToExport = activeTab === 'summary' ? productSummaryList : filteredSales;
    const ws = XLSX.utils.json_to_sheet(dataToExport);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, activeTab === 'summary' ? "Realization_Summary" : "Sales_Invoices");
    XLSX.writeFile(wb, `MIS_Sales_Realization_${selectedVendor}_${new Date().toISOString().slice(0,10)}.xlsx`);
  };

  const exportReport = () => {
    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet(productSummaryList);
    XLSX.utils.book_append_sheet(wb, ws, "Product_Sales_MIS");
    XLSX.writeFile(wb, `Complete_MIS_Report_${new Date().toISOString().slice(0,10)}.xlsx`);
  };

  return (
    <div className="space-y-4 text-xs font-sans">
      {/* Top Banner */}
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex flex-wrap justify-between items-center gap-3">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-blue-600 rounded-xl">
            <Database className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold">4. Vendor & Product Sales P&L MIS Intelligence</h1>
            <p className="text-[11px] text-slate-300">Decoupled Output Store • Zero BOM Overhead • Synced Live</p>
          </div>
        </div>
        <button 
          onClick={exportReport} 
          className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-1.5 shadow-sm text-xs cursor-pointer"
        >
          <Download className="w-4 h-4" /> Download Complete MIS Report (.xlsx)
        </button>
      </div>

      {/* 4 KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-500">Period Sales Volume</div>
          <div className="text-2xl font-black font-mono text-slate-900 mt-1">{totalVolume.toLocaleString()} pcs</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-500">Total Sales Revenue</div>
          <div className="text-2xl font-black font-mono text-blue-900 mt-1">₹{totalRevenue.toLocaleString()}</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-500">Gross Profit & Margin</div>
          <div className="text-2xl font-black font-mono text-emerald-800 mt-1">₹{grossProfit.toLocaleString()} ({grossMarginPct}%)</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-500">Cost Variance Gain / Loss</div>
          <div className={`text-2xl font-black font-mono mt-1 ${totalCostGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
            {totalCostGainLoss >= 0 ? `+ ₹${totalCostGainLoss.toLocaleString()}` : `- ₹${Math.abs(totalCostGainLoss).toLocaleString()}`}
          </div>
        </div>
      </div>

      {/* SECTION 1: Product Sales Realization & Costing Analysis Table */}
      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex flex-wrap justify-between items-center gap-3">
          <div className="flex items-center gap-3">
            <Activity className="w-4 h-4 text-blue-400" />
            <h2 className="text-xs font-bold uppercase tracking-wider">Product Sales Realization & Costing Analysis</h2>
            <div className="flex bg-slate-800 p-0.5 rounded-lg border border-slate-700">
              <button 
                onClick={() => setActiveTab('summary')} 
                className={`px-3 py-1 rounded font-bold cursor-pointer transition ${activeTab === 'summary' ? 'bg-blue-600 text-white' : 'text-slate-300 hover:text-white'}`}
              >
                Product Summary ({productSummaryList.length})
              </button>
              <button 
                onClick={() => setActiveTab('invoices')} 
                className={`px-3 py-1 rounded font-bold cursor-pointer transition ${activeTab === 'invoices' ? 'bg-blue-600 text-white' : 'text-slate-300 hover:text-white'}`}
              >
                Invoices Log ({filteredSales.length})
              </button>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-slate-300 font-bold">Vendor:</span>
            <select
              value={selectedVendor}
              onChange={e => setSelectedVendor(e.target.value)}
              className="px-2.5 py-1 bg-slate-800 text-white border border-slate-700 rounded-lg text-xs font-bold"
            >
              <option value="ALL" className="bg-white text-slate-900">All Vendors Combined</option>
              {vendors.map(v => (
                <option key={v.vendorId} value={v.vendorId} className="bg-white text-slate-900">{v.vendorName}</option>
              ))}
            </select>

            <input 
              type="date" 
              value={periodFrom} 
              onChange={e => setPeriodFrom(e.target.value)} 
              className="px-2 py-1 bg-slate-800 text-white border border-slate-700 rounded-lg text-xs font-mono" 
            />
            <span className="text-slate-300">to</span>
            <input 
              type="date" 
              value={periodTo} 
              onChange={e => setPeriodTo(e.target.value)} 
              className="px-2 py-1 bg-slate-800 text-white border border-slate-700 rounded-lg text-xs font-mono" 
            />

            <button
              onClick={handleExportRealizationSection}
              className="px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-bold flex items-center gap-1.5 cursor-pointer text-xs shadow-sm transition"
            >
              <Download className="w-3.5 h-3.5" /> Export Section (.xlsx)
            </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th className="py-2.5 px-3">Part Code</th>
                <th className="py-2.5 px-3">Component Name</th>
                <th className="py-2.5 px-3">Vendor</th>
                <th className="py-2.5 px-2 text-center">Invoices</th>
                <th className="py-2.5 px-3 text-right">Total Qty Sold</th>
                <th className="py-2.5 px-3 text-right">Avg Selling Price</th>
                <th className="py-2.5 px-3 text-right bg-amber-100 text-amber-950 font-bold">Contract Baseline</th>
                <th className="py-2.5 px-3 text-right font-bold text-slate-900">Actual Unit Cost</th>
                <th className="py-2.5 px-3 text-right">Profit / Loss (Δ)</th>
                <th className="py-2.5 px-3 text-right">Total Gain/Loss</th>
                <th className="py-2.5 px-4 text-right bg-blue-100 text-blue-950 font-black">Total Sales Revenue</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {productSummaryList.length === 0 ? (
                <tr>
                  <td colSpan={11} className="py-10 text-center text-slate-500 font-bold">
                    No sales transactions recorded for the selected period.
                  </td>
                </tr>
              ) : (
                productSummaryList.map((p, idx) => (
                  <tr key={idx} className="hover:bg-slate-50 transition font-medium">
                    <td className="py-2.5 px-3 font-mono font-black text-blue-700">{p.itemCode}</td>
                    <td className="py-2.5 px-3 font-bold text-slate-900">{p.componentName}</td>
                    <td className="py-2.5 px-3 text-slate-700 font-bold">{p.vendor}</td>
                    <td className="py-2.5 px-2 text-center font-mono font-black text-slate-900">{p.invoicesCount}</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">{p.totalQty.toLocaleString()}</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{(p.totalRevenue / (p.totalQty || 1)).toFixed(2)}</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-amber-950 bg-amber-50">₹{p.approvedUnitCost.toFixed(2)}</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{p.actualUnitCost.toFixed(2)}</td>
                    <td className={`py-2.5 px-3 text-right font-mono font-black ${p.unitGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                      {p.unitGainLoss >= 0 ? `+₹${p.unitGainLoss.toFixed(2)}` : `-₹${Math.abs(p.unitGainLoss).toFixed(2)}`}
                    </td>
                    <td className={`py-2.5 px-3 text-right font-mono font-black ${p.totalGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                      {p.totalGainLoss >= 0 ? `+₹${p.totalGainLoss.toFixed(2)}` : `-₹${Math.abs(p.totalGainLoss).toFixed(2)}`}
                    </td>
                    <td className="py-2.5 px-4 text-right font-mono font-black text-blue-950 bg-blue-50">₹{p.totalRevenue.toFixed(2)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* SECTION 2: Vendor-Wise Period Comparison Table */}
      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex flex-wrap justify-between items-center gap-3">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-blue-400" />
            <h3 className="text-xs font-bold uppercase">Vendor-Wise Period VS Previous Period Comparison</h3>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th rowSpan={2} className="py-2.5 px-4 border-r border-slate-300">Vendor</th>
                <th colSpan={2} className="py-1.5 px-3 text-center border-r border-slate-300 bg-blue-100/60 text-blue-950 font-black">Current Period ({periodFrom} to {periodTo})</th>
                <th colSpan={2} className="py-1.5 px-3 text-center border-r border-slate-300 text-slate-800 font-bold">Previous Period / Month</th>
                <th colSpan={2} className="py-1.5 px-3 text-center bg-emerald-100/60 text-emerald-950 font-black">Period-on-Period Growth / Variance (Δ)</th>
              </tr>
              <tr className="border-t border-slate-300 text-[9px]">
                <th className="py-1.5 px-3 text-right text-slate-900 font-black">Total Sales Revenue</th>
                <th className="py-1.5 px-3 text-right border-r border-slate-300 text-slate-900 font-black">Cost Variance Gain / Loss</th>
                <th className="py-1.5 px-3 text-right text-slate-900 font-black">Total Sales Revenue</th>
                <th className="py-1.5 px-3 text-right border-r border-slate-300 text-slate-900 font-black">Cost Variance Gain / Loss</th>
                <th className="py-1.5 px-3 text-center text-slate-900 font-black">Revenue Growth %</th>
                <th className="py-1.5 px-3 text-right text-slate-900 font-black">Variance Delta (Δ)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 font-medium">
              {vendorBreakdowns.map((vb, idx) => (
                <tr key={idx} className="hover:bg-slate-50 font-medium">
                  <td className="py-2.5 px-4 font-bold text-slate-900 flex items-center gap-2 border-r border-slate-200">
                    <span className="w-2 h-2 rounded-full bg-blue-600"></span> {vb.vendorName}
                  </td>
                  <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{vb.currentRev.toLocaleString()}</td>
                  <td className={`py-2.5 px-3 text-right font-mono font-black border-r border-slate-200 ${vb.currentGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                    {vb.currentGainLoss >= 0 ? `+ ₹${vb.currentGainLoss.toLocaleString()}` : `- ₹${Math.abs(vb.currentGainLoss).toLocaleString()}`}
                  </td>
                  <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹0</td>
                  <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900 border-r border-slate-200">+ ₹0</td>
                  <td className="py-2.5 px-3 text-center font-mono font-black text-emerald-800">+0%</td>
                  <td className={`py-2.5 px-3 text-right font-mono font-black ${vb.varianceDelta >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                    {vb.varianceDelta >= 0 ? `+ ₹${vb.varianceDelta.toLocaleString()}` : `- ₹${Math.abs(vb.varianceDelta).toLocaleString()}`}
                  </td>
                </tr>
              ))}
              <tr className="bg-slate-900 text-white font-bold">
                <td className="py-2.5 px-4 uppercase text-amber-400 font-black">All Vendors Combined</td>
                <td className="py-2.5 px-3 text-right font-mono font-black text-amber-300">₹{allVendorsRev.toLocaleString()}</td>
                <td className="py-2.5 px-3 text-right font-mono font-black text-emerald-400">
                  {allVendorsGainLoss >= 0 ? `+ ₹${allVendorsGainLoss.toLocaleString()}` : `- ₹${Math.abs(allVendorsGainLoss).toLocaleString()}`}
                </td>
                <td className="py-2.5 px-3 text-right font-mono font-black text-slate-300">₹0</td>
                <td className="py-2.5 px-3 text-right font-mono font-black text-slate-300">+ ₹0</td>
                <td className="py-2.5 px-3 text-center font-mono text-emerald-400 font-black">+0%</td>
                <td className="py-2.5 px-3 text-right font-mono text-emerald-400 font-black">
                  {allVendorsGainLoss >= 0 ? `+ ₹${allVendorsGainLoss.toLocaleString()}` : `- ₹${Math.abs(allVendorsGainLoss).toLocaleString()}`}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* SECTION 3: Multi-Month Variance Drilldown */}
      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Activity className="w-4 h-4 text-emerald-400" />
            <h3 className="text-xs font-bold uppercase">Multi-Month Variance Drilldown & Top-6 Part Breakdown</h3>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="text-slate-300 font-bold">Filter Vendor:</span>
            <select
              value={drilldownVendor}
              onChange={e => setDrilldownVendor(e.target.value)}
              className="px-2.5 py-1 bg-slate-800 text-white border border-slate-700 rounded-lg text-xs font-bold"
            >
              {vendors.map(v => (
                <option key={v.vendorId} value={v.vendorId} className="bg-white text-slate-900">{v.vendorName}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th className="py-2.5 px-4 w-1/3">Filter Category / Drilldown</th>
                <th className="py-2.5 px-3 text-right font-bold text-slate-900">Month-1 (May)</th>
                <th className="py-2.5 px-3 text-right font-bold text-slate-900">Month-2 (June)</th>
                <th className="py-2.5 px-3 text-right font-bold text-slate-900">Month-3 (July)</th>
                <th className="py-2.5 px-4 text-right bg-blue-100 text-blue-950 font-black">Month-4 (August)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 font-medium">
              <tr className="bg-slate-50 font-bold">
                <td className="py-2.5 px-4 uppercase text-slate-900">Total Sales Revenue</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">₹0</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">₹0</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">₹0</td>
                <td className="py-2.5 px-4 text-right font-mono font-black text-blue-950 bg-blue-50">₹{totalRevenue.toLocaleString()}</td>
              </tr>
              <tr className="bg-slate-50 font-bold">
                <td className="py-2.5 px-4 uppercase text-slate-900">Cost Variance Gain / Loss</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">+ ₹0</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">+ ₹0</td>
                <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-800">+ ₹0</td>
                <td className={`py-2.5 px-4 text-right font-mono font-black bg-blue-50 ${totalCostGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {totalCostGainLoss >= 0 ? `+ ₹${totalCostGainLoss.toLocaleString()}` : `- ₹${Math.abs(totalCostGainLoss).toLocaleString()}`}
                </td>
              </tr>
              
              <tr className="bg-emerald-100/50 font-bold text-emerald-950">
                <td colSpan={5} className="py-2 px-4 flex items-center gap-1.5">
                  <ArrowUpRight className="w-4 h-4 text-emerald-700" /> DrillDown - COST VARIANCE GAIN / LOSS: Top-6 parts with Profit (Favorable Variance)
                </td>
              </tr>
              {topProfitParts.length === 0 ? (
                <tr><td colSpan={5} className="py-3 px-6 text-slate-500 font-medium italic">No favorable parts recorded for this period.</td></tr>
              ) : (
                topProfitParts.map((p, idx) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="py-2 px-6 font-mono text-blue-700 font-bold">{p.itemCode} <span className="text-slate-800 font-sans font-semibold ml-2">{p.componentName}</span></td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">+ ₹0</td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">+ ₹0</td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">+ ₹0</td>
                    <td className="py-2 px-4 text-right font-mono font-black text-emerald-700">+ ₹{p.gainLoss.toFixed(2)}</td>
                  </tr>
                ))
              )}

              <tr className="bg-rose-100/50 font-bold text-rose-950">
                <td colSpan={5} className="py-2 px-4 flex items-center gap-1.5">
                  <ArrowDownRight className="w-4 h-4 text-rose-700" /> DrillDown: Top-6 parts with Loss (Unfavorable Variance / Drift)
                </td>
              </tr>
              {topLossParts.length === 0 ? (
                <tr><td colSpan={5} className="py-3 px-6 text-slate-500 font-medium italic">No unfavorable drift parts recorded for this period.</td></tr>
              ) : (
                topLossParts.map((p, idx) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="py-2 px-6 font-mono text-rose-700 font-bold">{p.itemCode} <span className="text-slate-800 font-sans font-semibold ml-2">{p.componentName}</span></td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">- ₹0</td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">- ₹0</td>
                    <td className="py-2 px-3 text-right font-mono text-slate-700">- ₹0</td>
                    <td className="py-2 px-4 text-right font-mono font-black text-rose-700">- ₹{Math.abs(p.gainLoss).toFixed(2)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* SECTION 4: Root-Cause Cost Gap Breakdown by Driver */}
      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex justify-between items-center">
          <div className="flex items-center gap-2">
            <DollarSign className="w-4 h-4 text-amber-400" />
            <h3 className="text-xs font-bold uppercase">Root-Cause Cost Gap Breakdown by Driver</h3>
          </div>
          <span className="text-[11px] text-slate-300 font-bold">Live Sync with Day-Wise Purchases & Invoices</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th className="py-2.5 px-4 w-1/3">Cost Driver & Parameter Variance</th>
                <th className="py-2.5 px-4 text-right">Haier Appliances Impact</th>
                <th className="py-2.5 px-4 text-right">Atomberg Technologies Impact</th>
                <th className="py-2.5 px-4 text-right">Net Combined Variance (₹)</th>
                <th className="py-2.5 px-4 text-center">Variance Classification</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200 font-medium">
              <tr>
                <td className="py-2.5 px-4 font-bold text-slate-900">Polymer Base Rate Variance (RM Purchase vs Approved Contract)</td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${haierRmDelta >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {haierRmDelta >= 0 ? `+ ₹${haierRmDelta.toFixed(2)}` : `- ₹${Math.abs(haierRmDelta).toFixed(2)}`}
                </td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${atomRmDelta >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {atomRmDelta >= 0 ? `+ ₹${atomRmDelta.toFixed(2)}` : `- ₹${Math.abs(atomRmDelta).toFixed(2)}`}
                </td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${(haierRmDelta + atomRmDelta) >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {(haierRmDelta + atomRmDelta) >= 0 ? `+ ₹${(haierRmDelta + atomRmDelta).toFixed(2)}` : `- ₹${Math.abs(haierRmDelta + atomRmDelta).toFixed(2)}`}
                </td>
                <td className="py-2.5 px-4 text-center">
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black ${(haierRmDelta + atomRmDelta) >= 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                    {(haierRmDelta + atomRmDelta) >= 0 ? 'Favorable' : 'Unfavorable'}
                  </span>
                </td>
              </tr>
              <tr>
                <td className="py-2.5 px-4 font-bold text-slate-900">Masterbatch Rate Variance (MB Actual Landed vs Approved)</td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${haierMbDelta >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {haierMbDelta >= 0 ? `+ ₹${haierMbDelta.toFixed(2)}` : `- ₹${Math.abs(haierMbDelta).toFixed(2)}`}
                </td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${atomMbDelta >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {atomMbDelta >= 0 ? `+ ₹${atomMbDelta.toFixed(2)}` : `- ₹${Math.abs(atomMbDelta).toFixed(2)}`}
                </td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${(haierMbDelta + atomMbDelta) >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {(haierMbDelta + atomMbDelta) >= 0 ? `+ ₹${(haierMbDelta + atomMbDelta).toFixed(2)}` : `- ₹${Math.abs(haierMbDelta + atomMbDelta).toFixed(2)}`}
                </td>
                <td className="py-2.5 px-4 text-center">
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black ${(haierMbDelta + atomMbDelta) >= 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                    {(haierMbDelta + atomMbDelta) >= 0 ? 'Favorable' : 'Unfavorable'}
                  </span>
                </td>
              </tr>
              <tr>
                <td className="py-2.5 px-4 font-bold text-slate-900">Cycle Time & Shopfloor Machine Efficiency Variance</td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${totalCostGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {totalCostGainLoss >= 0 ? `+ ₹${totalCostGainLoss.toFixed(2)}` : `- ₹${Math.abs(totalCostGainLoss).toFixed(2)}`}
                </td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">+ ₹0.00</td>
                <td className={`py-2.5 px-4 text-right font-mono font-black ${totalCostGainLoss >= 0 ? 'text-emerald-700' : 'text-rose-700'}`}>
                  {totalCostGainLoss >= 0 ? `+ ₹${totalCostGainLoss.toFixed(2)}` : `- ₹${Math.abs(totalCostGainLoss).toFixed(2)}`}
                </td>
                <td className="py-2.5 px-4 text-center">
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black ${totalCostGainLoss >= 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                    {totalCostGainLoss >= 0 ? 'Favorable' : 'Unfavorable'}
                  </span>
                </td>
              </tr>
              <tr>
                <td className="py-2.5 px-4 font-bold text-slate-900">Runner Scrap Weight & Regrind Credit Delta</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">+ ₹0.00</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">- ₹0.00</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">+ ₹0.00</td>
                <td className="py-2.5 px-4 text-center">
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black bg-slate-200 text-slate-800">Neutral</span>
                </td>
              </tr>
              <tr>
                <td className="py-2.5 px-4 font-bold text-slate-900">BOP / Inserts & Packaging Overhead Variance</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">+ ₹0.00</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">- ₹0.00</td>
                <td className="py-2.5 px-4 text-right font-mono font-bold text-slate-700">+ ₹0.00</td>
                <td className="py-2.5 px-4 text-center">
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black bg-slate-200 text-slate-800">Neutral</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
MIS_PAGE_EOF

echo "==> 4. Verifying build with Vite..."
npm run build

echo "==> 5. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ HIGH CONTRAST STYLES APPLIED ACROSS ALL DROPDOWNS & TABLES!"
echo "-------------------------------------------------------------------"
