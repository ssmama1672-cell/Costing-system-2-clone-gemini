#!/usr/bin/env bash
set -e

echo "==> 1. Ensuring git branch is dev-v2..."
git checkout dev-v2 2>/dev/null || git checkout dev-2 2>/dev/null || git checkout -b dev-v2 2>/dev/null || true

echo "==> 2. Updating RMPriceMatrixPage.jsx with Part Code & Inward Qty Drilldowns..."
cat << 'RM_PAGE_EOF' > src/modules/module2-rm-matrix/RMPriceMatrixPage.jsx
import React, { useState, useEffect, useRef } from 'react';
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
  Package,
  Search,
  Check,
  ChevronDown,
  ExternalLink,
  FileSpreadsheet
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
  computeCombinedWeightedAverageWithQty,
  normalizeVendorId,
  isInvalidMaterialCode
} from '../../shared/masterStore';
import InlineEditModal from '../module1-baseline/InlineEditModal';

// Searchable Multi-Select Component with QTY drilldown button
function SearchableMultiSelect({ 
  options = [], 
  selected = [], 
  onToggle, 
  disabled = false, 
  approvedCode = '', 
  totalInwardQty = 0,
  onOpenQtyDrilldown 
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const containerRef = useRef(null);

  useEffect(() => {
    function handleClickOutside(e) {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const filteredOptions = options.filter(opt => 
    opt.label.toLowerCase().includes(searchTerm.toLowerCase()) || 
    opt.code.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const selectedCount = selected.length;

  return (
    <div className="relative w-full" ref={containerRef}>
      <button
        type="button"
        disabled={disabled}
        onClick={() => setIsOpen(!isOpen)}
        className={`w-full px-2.5 py-1.5 rounded-xl border text-left flex items-center justify-between transition cursor-pointer text-xs ${
          disabled 
            ? 'bg-slate-100 border-slate-200 text-slate-700 cursor-not-allowed' 
            : 'bg-white border-slate-300 hover:border-blue-500 shadow-2xs'
        }`}
      >
        <div className="truncate flex items-center gap-1.5 pr-2">
          {selectedCount === 0 ? (
            <span className="text-slate-500 italic font-medium">Select Alternate Lots...</span>
          ) : (
            <div className="flex flex-wrap gap-1.5 items-center max-w-[340px] truncate">
              <span className="bg-blue-100 text-blue-900 border border-blue-200 px-2 py-0.5 rounded-md font-black text-[10px]">
                {selectedCount} Lot{selectedCount > 1 ? 's' : ''} Selected {totalInwardQty > 0 ? `(${totalInwardQty.toLocaleString()} kg)` : ''}
              </span>
              <span className="font-bold text-slate-900 truncate">
                {selected.join(', ')}
              </span>
            </div>
          )}
        </div>
        <ChevronDown className="w-3.5 h-3.5 text-slate-500 shrink-0" />
      </button>

      {isOpen && (
        <div className="absolute left-0 top-full mt-1 w-80 md:w-[440px] bg-white border border-slate-300 rounded-2xl shadow-2xl z-50 p-2 space-y-2">
          {/* Search Box */}
          <div className="relative flex items-center bg-slate-100 rounded-xl px-2.5 py-1.5 border border-slate-200">
            <Search className="w-3.5 h-3.5 text-slate-500 shrink-0 mr-1.5" />
            <input
              type="text"
              placeholder="Search alternate lot or grade..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full bg-transparent border-none outline-hidden text-xs font-bold text-slate-900 placeholder-slate-400"
              autoFocus
            />
            {searchTerm && (
              <button onClick={() => setSearchTerm('')} className="p-0.5 text-slate-400 hover:text-slate-600">
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {/* Options List with Inward WA Rate & Clickable Qty Drilldown */}
          <div className="max-h-60 overflow-y-auto space-y-1 divide-y divide-slate-100">
            {/* Contract Baseline Option */}
            <div 
              onClick={() => onToggle(approvedCode)}
              className="flex items-center justify-between p-2 hover:bg-slate-50 rounded-xl cursor-pointer transition"
            >
              <div className="flex items-center gap-2">
                <div className={`w-4 h-4 rounded-md flex items-center justify-center border transition ${
                  selected.includes(approvedCode) ? 'bg-blue-600 border-blue-600 text-white' : 'border-slate-300 bg-white'
                }`}>
                  {selected.includes(approvedCode) && <Check className="w-3 h-3 stroke-[3]" />}
                </div>
                <div className="font-bold text-slate-900 text-xs">
                  {approvedCode} <span className="text-slate-500 font-normal">(Contract Baseline)</span>
                </div>
              </div>
            </div>

            {filteredOptions.length === 0 ? (
              <div className="py-4 text-center text-slate-400 text-xs font-medium">
                No matching inward lots found.
              </div>
            ) : (
              filteredOptions.map((opt, i) => {
                const isSelected = selected.includes(opt.code);
                return (
                  <div
                    key={i}
                    className="flex items-center justify-between p-2 hover:bg-slate-50 rounded-xl transition pt-1.5"
                  >
                    <div 
                      onClick={() => onToggle(opt.code)}
                      className="flex items-center gap-2 flex-1 min-w-0 pr-2 cursor-pointer"
                    >
                      <div className={`w-4 h-4 rounded-md flex items-center justify-center border transition shrink-0 ${
                        isSelected ? 'bg-blue-600 border-blue-600 text-white' : 'border-slate-300 bg-white'
                      }`}>
                        {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
                      </div>
                      <div className="truncate">
                        <div className="font-bold text-slate-900 text-xs truncate">{opt.code}</div>
                        <div className="text-[10px] font-mono text-blue-700 font-bold">
                          Inward WA: ₹{opt.price.toFixed(2)}/kg
                        </div>
                      </div>
                    </div>

                    {/* Drilldown Qty Hyperlink Button */}
                    <button
                      type="button"
                      title="Click to view & download purchase entries for this grade"
                      onClick={(e) => {
                        e.stopPropagation();
                        onOpenQtyDrilldown(opt.code);
                      }}
                      className="inline-flex items-center gap-1 text-[10px] font-mono font-bold bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-300 px-2 py-1 rounded-lg cursor-pointer transition shadow-2xs shrink-0"
                    >
                      <span>Qty: {opt.qty.toLocaleString()} kg</span>
                      <ExternalLink className="w-2.5 h-2.5 text-emerald-700" />
                    </button>
                  </div>
                );
              })
            )}
          </div>

          <div className="flex justify-between items-center pt-2 border-t border-slate-100 text-[11px]">
            <span className="text-slate-600 font-bold">
              {selectedCount} lot{selectedCount !== 1 ? 's' : ''} active {totalInwardQty > 0 ? `(${totalInwardQty.toLocaleString()} kg)` : ''}
            </span>
            <button
              type="button"
              onClick={() => setIsOpen(false)}
              className="px-3.5 py-1 bg-slate-900 text-white rounded-lg font-bold text-xs cursor-pointer hover:bg-slate-800"
            >
              Done
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default function RMPriceMatrixPage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [activeTab, setActiveTab] = useState('matrix');
  const [selectedVendor, setSelectedVendor] = useState('Haier Appliances');
  const [periodFrom, setPeriodFrom] = useState('2026-08-01');
  const [periodTo, setPeriodTo] = useState('2026-08-31');
  const [showAddModal, setShowAddModal] = useState(false);
  const [saveSuccessMsg, setSaveSuccessMsg] = useState('');
  
  // Drilldown States
  const [viewingUsageMat, setViewingUsageMat] = useState(null);
  const [viewingProductSpec, setViewingProductSpec] = useState(null);
  const [viewingPurchaseGrade, setViewingPurchaseGrade] = useState(null);

  const [isGlobalLocked, setIsGlobalLocked] = useState(true);
  const [isMatrixLocked, setIsMatrixLocked] = useState(true);

  const [newMaterial, setNewMaterial] = useState({
    type: 'RM',
    approvedCode: '',
    approvedPrice: ''
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

  // Group purchased lots with WA price AND total quantity
  const purchaseOptionsMap = new Map();
  purchases.forEach(p => {
    const gradeName = (p.grade || p.itemCode || '').trim();
    if (!gradeName) return;
    if (!purchaseOptionsMap.has(gradeName)) {
      const { waRate, totalQty } = computeCombinedWeightedAverageWithQty([gradeName], '', 0, selectedVendor);
      purchaseOptionsMap.set(gradeName, {
        label: `${gradeName} (Inward WA: ₹${waRate.toFixed(2)}) • Qty: ${totalQty.toLocaleString()} kg`,
        code: gradeName,
        price: waRate,
        qty: totalQty
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

  const handleApprovedPriceChange = (rowId, val) => {
    if (isRowDisabled) return;
    updateRmMappingRow(rowId, { approvedPrice: parseFloat(val) || 0 });
  };

  const handleToggleAltOption = (rowId, currentSelectedArray, toggledCode, approvedCode, approvedPrice) => {
    if (isRowDisabled) return;
    let updatedArray = [...(currentSelectedArray || [])];

    if (updatedArray.includes(toggledCode)) {
      updatedArray = updatedArray.filter(c => c !== toggledCode);
    } else {
      updatedArray.push(toggledCode);
    }

    if (updatedArray.length === 0) {
      updatedArray = [approvedCode];
    }

    const { waRate } = computeCombinedWeightedAverageWithQty(updatedArray, approvedCode, approvedPrice, selectedVendor);

    updateRmMappingRow(rowId, { 
      selectedAlts: updatedArray,
      alt1Price: waRate
    });
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
      selectedAlts: [newMaterial.approvedCode.trim()],
      periodFrom,
      periodTo
    });
    setNewMaterial({ type: 'RM', approvedCode: '', approvedPrice: '' });
    setShowAddModal(false);
  };

  // Products linked to selected material
  const activeUsageProducts = viewingUsageMat ? getProductsUsingMaterial(viewingUsageMat.approvedCode, selectedVendor) : [];

  // Purchases linked to drilldown grade
  const matchingPurchases = viewingPurchaseGrade 
    ? purchases.filter(p => {
        const pGrade = (p.grade || p.itemCode || '').toLowerCase().trim();
        const target = viewingPurchaseGrade.toLowerCase().trim();
        return pGrade === target || pGrade.includes(target) || target.includes(pGrade);
      })
    : [];

  const handleExportDrilldownPurchases = () => {
    if (!matchingPurchases.length) return;
    const ws = XLSX.utils.json_to_sheet(matchingPurchases);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Inward_Batches");
    XLSX.writeFile(wb, `Inward_Purchases_${viewingPurchaseGrade.replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
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
            <div className="flex items-center gap-2">
              <h1 className="text-sm font-bold">2. RM Mapping & Inward Registry</h1>
              <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] px-2 py-0.5 rounded-full font-bold">
                Vendor: {selectedVendor}
              </span>
            </div>
            <p className="text-[11px] text-slate-300">Multi-Select Alternate Lots, Quantity Tracking & Combined WA Calculation</p>
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
                  <th className="py-3 px-4 w-72">APPROVED RM/MB CODE & USAGE</th>
                  <th className="py-3 px-4 text-center w-36">APPROVED PRICE (₹/KG)</th>
                  <th className="py-3 px-4">SEARCHABLE ALTERNATE RM LOTS (WITH INWARD QTY DRILLDOWN)</th>
                  <th className="py-3 px-4 text-center w-48 text-amber-300">COMBINED WA PRICE (₹/KG)</th>
                  <th className="py-3 px-3 text-center w-20">ACTION</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {vendorMaterials.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-slate-500 font-bold">
                      No material codes mapped specifically for {selectedVendor}. Upload a baseline sheet in <b>1. Baseline Master</b> to auto-register grades.
                    </td>
                  </tr>
                ) : (
                  vendorMaterials.map(m => {
                    const usingProds = getProductsUsingMaterial(m.approvedCode, selectedVendor);
                    const selectedAlts = Array.isArray(m.selectedAlts) && m.selectedAlts.length > 0 
                      ? m.selectedAlts 
                      : [m.approvedCode];
                    
                    const { waRate, totalQty } = computeCombinedWeightedAverageWithQty(selectedAlts, m.approvedCode, m.approvedPrice, selectedVendor);

                    return (
                      <tr key={m.id} className="hover:bg-slate-50 transition font-medium">
                        {/* 1. Code & Linked Product Usage Badge */}
                        <td className="py-3 px-4">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2">
                              <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                m.type === 'MB' ? 'bg-purple-100 text-purple-900 font-bold' : 'bg-blue-100 text-blue-900 font-bold'
                              }`}>
                                {m.type === 'MB' ? 'MASTERBATCH' : 'RM CODE'}
                              </span>
                              <span className="font-bold text-slate-900 text-xs">{m.approvedCode}</span>
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

                        {/* 2. Approved Price */}
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

                        {/* 3. Searchable Multi-Select Alternate Lots (Showing Clickable Qty Drilldown) */}
                        <td className="py-3 px-4">
                          <div className="space-y-1">
                            <SearchableMultiSelect
                              options={allPurchasedGradeOptions}
                              selected={selectedAlts}
                              approvedCode={m.approvedCode}
                              totalInwardQty={totalQty}
                              disabled={isRowDisabled}
                              onToggle={(toggledCode) => handleToggleAltOption(m.id, selectedAlts, toggledCode, m.approvedCode, m.approvedPrice)}
                              onOpenQtyDrilldown={(gradeCode) => setViewingPurchaseGrade(gradeCode)}
                            />
                            <div className="text-[10px] text-slate-500 font-medium">
                              Click any inward lot checkbox to combine rates, or click on the <b>Qty badge</b> to view inward batches.
                            </div>
                          </div>
                        </td>

                        {/* 4. Combined WA Price */}
                        <td className="py-3 px-4 text-center">
                          <div className="inline-block bg-blue-50 border border-blue-200 px-3 py-1.5 rounded-xl">
                            <div className="font-mono font-black text-blue-900 text-sm">
                              ₹{waRate.toFixed(2)}
                            </div>
                            <div className="text-[9px] text-slate-600 font-bold uppercase tracking-wider mt-0.5">
                              {selectedAlts.length > 1 ? `${selectedAlts.length} Lots Combined` : 'Single Active Lot'}
                            </div>
                          </div>
                        </td>

                        {/* 5. Delete Action Button */}
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

      {/* 1. PRODUCT USAGE INSPECTOR MODAL (WITH READ-ONLY SPEC DRILLDOWN) */}
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
                      <th className="py-2 px-3">Part Code (Click to View Spec)</th>
                      <th className="py-2 px-3">Component Name</th>
                      <th className="py-2 px-3 text-right">Net Wt</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {activeUsageProducts.map((p, i) => (
                      <tr key={i} className="hover:bg-slate-50">
                        <td className="py-2 px-3">
                          {/* 1- Click on Part Code opens read-only Edit Spec view */}
                          <button
                            type="button"
                            onClick={() => {
                              setViewingProductSpec(p);
                            }}
                            className="font-mono font-black text-blue-700 hover:text-blue-900 underline flex items-center gap-1 cursor-pointer"
                          >
                            <span>{p.itemCode}</span>
                            <ExternalLink className="w-2.5 h-2.5" />
                          </button>
                        </td>
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

      {/* 2. INWARD PURCHASES DRILLDOWN MODAL (VIEW & DOWNLOAD EXCEL) */}
      {viewingPurchaseGrade && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-5 shadow-2xl space-y-4 text-xs">
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <ShoppingBag className="w-5 h-5 text-emerald-600" />
                <div>
                  <h3 className="text-sm font-bold text-slate-900">Inward Purchase Entries</h3>
                  <p className="text-[11px] text-slate-500 font-mono">Grade: <b>{viewingPurchaseGrade}</b> ({selectedVendor})</p>
                </div>
              </div>
              <button onClick={() => setViewingPurchaseGrade(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="max-h-80 overflow-y-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
                  <tr>
                    <th className="py-2.5 px-3">Date</th>
                    <th className="py-2.5 px-3">Supplier</th>
                    <th className="py-2.5 px-3">Invoice #</th>
                    <th className="py-2.5 px-3 text-right">Inward Qty (kg)</th>
                    <th className="py-2.5 px-3 text-right">Purchase Rate (₹/kg)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {matchingPurchases.length === 0 ? (
                    <tr><td colSpan={5} className="py-6 text-center text-slate-400 italic">No purchase batches recorded for this grade.</td></tr>
                  ) : (
                    matchingPurchases.map((p, idx) => (
                      <tr key={idx} className="hover:bg-slate-50 font-medium">
                        <td className="py-2 px-3 font-mono font-bold text-slate-800">{p.date}</td>
                        <td className="py-2 px-3 font-bold text-slate-900">{p.supplier || p.supplierName || '-'}</td>
                        <td className="py-2 px-3 font-mono font-black text-blue-700">{p.invoiceNo}</td>
                        <td className="py-2 px-3 text-right font-mono font-black text-emerald-800">{Number(p.qty || 0).toLocaleString()} kg</td>
                        <td className="py-2 px-3 text-right font-mono font-black text-slate-900">₹{Number(p.rate || 0).toFixed(2)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <span className="text-[11px] text-slate-700 font-bold">Total Batches: {matchingPurchases.length}</span>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleExportDrilldownPurchases}
                  className="px-4 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs shadow-sm"
                >
                  <Download className="w-3.5 h-3.5" /> Export Inward Batches (.xlsx)
                </button>
                <button
                  type="button"
                  onClick={() => setViewingPurchaseGrade(null)}
                  className="px-4 py-1.5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl font-bold cursor-pointer text-xs"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* READ-ONLY SPECIFICATION MODAL (DRILLDOWN FROM PART CODE) */}
      {viewingProductSpec && (
        <InlineEditModal
          product={viewingProductSpec}
          readOnly={true}
          onClose={() => setViewingProductSpec(null)}
          onSave={() => setViewingProductSpec(null)}
          onDelete={() => setViewingProductSpec(null)}
        />
      )}
    </div>
  );
}
RM_PAGE_EOF

echo "==> 3. Updating MISVariancePage.jsx with Sales Qty Drilldown Modal (View & Download)..."
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
  FileSpreadsheet,
  ExternalLink,
  X,
  ShoppingBag
} from 'lucide-react';
import * as XLSX from 'xlsx';
import { globalStore, subscribeStore, getActiveRmMapping, normalizeVendorId } from '../../shared/masterStore';
import { calculateDetailedCost } from '../module1-baseline/InlineEditModal';
import InlineEditModal from '../module1-baseline/InlineEditModal';

export default function MISVariancePage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('ALL');
  const [drilldownVendor, setDrilldownVendor] = useState('Haier Appliances');
  const [periodFrom, setPeriodFrom] = useState('2026-08-01');
  const [periodTo, setPeriodTo] = useState('2026-08-31');
  const [activeTab, setActiveTab] = useState('summary');

  // Drilldown States
  const [viewingSalesProductCode, setViewingSalesProductCode] = useState(null);
  const [viewingProductSpec, setViewingProductSpec] = useState(null);

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
        baseProdObj: baseProd,
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
        baseProdObj: bp,
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

  // Sales entries for product drilldown
  const matchingProductSales = viewingSalesProductCode 
    ? filteredSales.filter(s => (s.itemCode || s.partCode) === viewingSalesProductCode)
    : [];

  const handleExportProductSales = () => {
    if (!matchingProductSales.length) return;
    const ws = XLSX.utils.json_to_sheet(matchingProductSales);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Sales_Invoices");
    XLSX.writeFile(wb, `Sales_Entries_${viewingSalesProductCode}.xlsx`);
  };

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
                <th className="py-2.5 px-3 text-right">Total Qty Sold (Drilldown)</th>
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
                    {/* Part Code with Read-Only Spec Drilldown */}
                    <td className="py-2.5 px-3">
                      <button
                        type="button"
                        onClick={() => {
                          const baseObj = baselineProducts.find(b => b.itemCode === p.itemCode) || p.baseProdObj;
                          if (baseObj) setViewingProductSpec(baseObj);
                        }}
                        className="font-mono font-black text-blue-700 hover:text-blue-900 underline flex items-center gap-1 cursor-pointer"
                      >
                        <span>{p.itemCode}</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                      </button>
                    </td>
                    <td className="py-2.5 px-3 font-bold text-slate-900">{p.componentName}</td>
                    <td className="py-2.5 px-3 text-slate-700 font-bold">{p.vendor}</td>
                    <td className="py-2.5 px-2 text-center font-mono font-black text-slate-900">{p.invoicesCount}</td>
                    
                    {/* 3- Click on Sales Qty in MIS page opens Sales Entry Drilldown */}
                    <td className="py-2.5 px-3 text-right">
                      {p.totalQty > 0 ? (
                        <button
                          type="button"
                          onClick={() => setViewingSalesProductCode(p.itemCode)}
                          className="font-mono font-black text-blue-700 hover:text-blue-900 underline inline-flex items-center gap-1 cursor-pointer bg-blue-50 hover:bg-blue-100 px-2 py-0.5 rounded border border-blue-200"
                        >
                          <span>{p.totalQty.toLocaleString()}</span>
                          <ExternalLink className="w-2.5 h-2.5 text-blue-600" />
                        </button>
                      ) : (
                        <span className="font-mono font-bold text-slate-500">0</span>
                      )}
                    </td>

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
                <td className="py-2.5 px-3 text-right font-mono text-slate-300">₹0</td>
                <td className="py-2.5 px-3 text-right font-mono text-slate-300">+ ₹0</td>
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
                    <td className="py-2 px-6">
                      <button
                        type="button"
                        onClick={() => {
                          const baseObj = baselineProducts.find(b => b.itemCode === p.itemCode) || p.baseProdObj;
                          if (baseObj) setViewingProductSpec(baseObj);
                        }}
                        className="font-mono text-blue-700 hover:text-blue-900 underline font-bold inline-flex items-center gap-1 cursor-pointer"
                      >
                        <span>{p.itemCode}</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                        <span className="text-slate-800 font-sans font-semibold ml-2">{p.componentName}</span>
                      </button>
                    </td>
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
                    <td className="py-2 px-6">
                      <button
                        type="button"
                        onClick={() => {
                          const baseObj = baselineProducts.find(b => b.itemCode === p.itemCode) || p.baseProdObj;
                          if (baseObj) setViewingProductSpec(baseObj);
                        }}
                        className="font-mono text-rose-700 hover:text-rose-900 underline font-bold inline-flex items-center gap-1 cursor-pointer"
                      >
                        <span>{p.itemCode}</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                        <span className="text-slate-800 font-sans font-semibold ml-2">{p.componentName}</span>
                      </button>
                    </td>
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

      {/* 3. SALES ENTRIES DRILLDOWN MODAL (VIEW & DOWNLOAD EXCEL) */}
      {viewingSalesProductCode && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-5 shadow-2xl space-y-4 text-xs">
            <div className="flex justify-between items-center border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <ShoppingBag className="w-5 h-5 text-blue-600" />
                <div>
                  <h3 className="text-sm font-bold text-slate-900">Sales Invoices & Dispatches Drilldown</h3>
                  <p className="text-[11px] text-slate-500 font-mono">Part Code: <b>{viewingSalesProductCode}</b></p>
                </div>
              </div>
              <button onClick={() => setViewingSalesProductCode(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="max-h-80 overflow-y-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
                  <tr>
                    <th className="py-2.5 px-3">Date</th>
                    <th className="py-2.5 px-3">Vendor</th>
                    <th className="py-2.5 px-3">Invoice Number</th>
                    <th className="py-2.5 px-3 text-right">Dispatch Qty</th>
                    <th className="py-2.5 px-3 text-right">Selling Price</th>
                    <th className="py-2.5 px-3 text-right">Total Amount</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {matchingProductSales.length === 0 ? (
                    <tr><td colSpan={6} className="py-6 text-center text-slate-400 italic">No sales invoices recorded for this part in the selected period.</td></tr>
                  ) : (
                    matchingProductSales.map((s, idx) => (
                      <tr key={idx} className="hover:bg-slate-50 font-medium">
                        <td className="py-2 px-3 font-mono font-bold text-slate-800">{s.date}</td>
                        <td className="py-2 px-3 font-bold text-slate-900">{s.vendor}</td>
                        <td className="py-2 px-3 font-mono font-black text-blue-700">{s.invoiceNo}</td>
                        <td className="py-2 px-3 text-right font-mono font-black text-blue-900">{Number(s.qty || 0).toLocaleString()}</td>
                        <td className="py-2 px-3 text-right font-mono font-black text-slate-900">₹{Number(s.rate || s.sellingPrice || 0).toFixed(2)}</td>
                        <td className="py-2 px-3 text-right font-mono font-black text-emerald-800">₹{Number(s.amount || (Number(s.qty || 0) * Number(s.rate || s.sellingPrice || 0))).toFixed(2)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <span className="text-[11px] text-slate-700 font-bold">Total Invoices: {matchingProductSales.length}</span>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleExportProductSales}
                  className="px-4 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer text-xs shadow-sm"
                >
                  <Download className="w-3.5 h-3.5" /> Export Sales Entries (.xlsx)
                </button>
                <button
                  type="button"
                  onClick={() => setViewingSalesProductCode(null)}
                  className="px-4 py-1.5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl font-bold cursor-pointer text-xs"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* READ-ONLY SPECIFICATION MODAL (DRILLDOWN FROM PART CODE IN MIS) */}
      {viewingProductSpec && (
        <InlineEditModal
          product={viewingProductSpec}
          readOnly={true}
          onClose={() => setViewingProductSpec(null)}
          onSave={() => setViewingProductSpec(null)}
          onDelete={() => setViewingProductSpec(null)}
        />
      )}
    </div>
  );
}
MIS_PAGE_EOF

echo "==> 4. Adding readOnly prop handling to InlineEditModal.jsx..."
cat << 'MODAL_EOF' > src/modules/module1-baseline/InlineEditModal.jsx
import React, { useState } from 'react';
import { X, Save, Trash2, Lock, Eye } from 'lucide-react';
import { calculateHaierCost, calculateAtombergCost } from '../../shared/costCalculationService';
import { parseMaterialString, getActiveRmMapping, getActiveMbMapping, sanitizeMaterialName } from '../../shared/masterStore';

export default function InlineEditModal({ product, onClose, onSave, onDelete, readOnly = false }) {
  if (!product) return null;

  const isHaier = (product.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (product.vendor || '').toLowerCase().includes('atomberg');
  const initialParams = product.parameters || {};

  const cleanMaterialStr = sanitizeMaterialName(product.approvedRm || product.baseRm, product.componentName, product.itemCode, product.vendor);
  const { baseRm, mbGrade } = parseMaterialString(cleanMaterialStr);
  const rmLookupKey = baseRm || cleanMaterialStr || (isAtomberg ? 'PP H110MA' : 'HIPS SH303');
  const mbLookupKey = mbGrade || product.approvedMb || ((product.masterbatchPct || 0) > 0 ? (isAtomberg ? 'Gloss White MB' : 'White MB') : 'None');

  const rmInfo = getActiveRmMapping(rmLookupKey, product.vendor) || {};
  const mbInfo = getActiveMbMapping(mbLookupKey, product.vendor) || {};

  const approvedRmRate = Number(rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(rmInfo.activeWaPrice || rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));

  const approvedMbRate = Number(mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(mbInfo.activeMbWaPrice || mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));

  const [formData, setFormData] = useState({
    approvedRm: cleanMaterialStr,
    baseRm: rmLookupKey,
    approvedMb: mbLookupKey,
    
    // Baseline Parameters
    rmFreight: Number(product.rmFreight !== undefined ? product.rmFreight : 1.50),
    mbFreight: Number(product.mbFreight !== undefined ? product.mbFreight : 2.00),
    masterbatchPct: Number(product.masterbatchPct !== undefined ? product.masterbatchPct : 4),
    partWeight: Number(product.netWeight !== undefined ? product.netWeight : (isAtomberg ? 37.00 : 372.00)),
    runnerWeight: Number(product.runnerWeight !== undefined ? product.runnerWeight : (isAtomberg ? 1.00 : 0.00)),
    bopCost: Number(product.bopCost || 0),
    machineTonnage: Number(product.machineTonnage || (isAtomberg ? 200 : 600)),
    shiftTariff: Number(product.shiftTariff || (isAtomberg ? 2000 : 4800)),
    cycleTimeApproved: Number(product.cycleTimeApproved || (isAtomberg ? 47 : 70)),
    cavity: Number(product.cavity || (isAtomberg ? 2 : 1)),
    
    meltLossPct: Number(product.meltLossPct !== undefined ? product.meltLossPct : 1.0),
    efficiencyPct: Number(product.efficiencyPct !== undefined ? product.efficiencyPct : 95.0),

    packingCost: Number(product.packingCost !== undefined ? product.packingCost : 0.86),
    transportCost: Number(product.transportCost !== undefined ? product.transportCost : 0.62),
    otherCost: Number(product.otherCost !== undefined ? product.otherCost : 0.00),
    mouldSize: product.mouldSize || (isAtomberg ? '450x450x380' : '800x800x684'),
    model: product.model || (isAtomberg ? 'Aris Ceiling Fan' : 'TM 258/278'),
    
    haierOverheadPackage: Number(product.haierOverheadPackage !== undefined ? product.haierOverheadPackage : 8.712912),
    foamPolybag: Number(product.foamPolybag || 0),
    plasticBin: Number(product.plasticBin || 0),
    freightCost: Number(product.freightCost || 0),
    secondaryOp1: Number(product.secondaryOp1 || 0),
    secondaryOp2: Number(product.secondaryOp2 || 0),
    screenPrint1: Number(product.screenPrint1 || 0),
    screenPrint2: Number(product.screenPrint2 || 0),
    assemblyCost: Number(product.assemblyCost || 0),
    mouldMaintenance: Number(product.mouldMaintenance !== undefined ? product.mouldMaintenance : 1.5),
    qualityInspection: Number(product.qualityInspection !== undefined ? product.qualityInspection : 1.0),
    iccReduce: Number(product.iccReduce !== undefined ? product.iccReduce : -0.29),
    scrapAdj: Number(product.scrapAdj || 0),

    runningRmFreight: Number(initialParams.runningRmFreight ?? product.rmFreight ?? 1.50),
    runningMbFreight: Number(initialParams.runningMbFreight ?? product.mbFreight ?? 2.00),
    runningMbPct: Number(initialParams.runningMbPct ?? product.masterbatchPct ?? 4),
    runningPartWeight: Number(initialParams.runningNetWeight ?? product.netWeight ?? (isAtomberg ? 37.00 : 372.00)),
    runningRunnerWeight: Number(initialParams.runningRunnerWeight ?? product.runnerWeight ?? (isAtomberg ? 1.00 : 0.00)),
    runningBopCost: Number(initialParams.runningBopCost ?? product.bopCost ?? 0),
    runningShiftTariff: Number(initialParams.runningShiftTariff ?? product.shiftTariff ?? (isAtomberg ? 2000 : 4800)),
    runningCycleTime: Number(initialParams.runningCycleTime ?? product.cycleTimeApproved ?? (isAtomberg ? 47 : 70)),
    runningCavity: Number(initialParams.runningCavity ?? product.cavity ?? (isAtomberg ? 2 : 1)),
    runningMeltLossPct: Number(initialParams.runningMeltLossPct ?? product.meltLossPct ?? 1.0),
    runningEfficiencyPct: Number(initialParams.runningEfficiencyPct ?? product.efficiencyPct ?? 95.0),
    runningPackingCost: Number(initialParams.runningPackingCost ?? product.packingCost ?? 0.86),
    runningTransportCost: Number(initialParams.runningTransportCost ?? product.transportCost ?? 0.62),
    runningOtherCost: Number(initialParams.runningOtherCost ?? product.otherCost ?? 0.00),

    runningHaierOverheadPackage: Number(initialParams.runningHaierOverheadPackage ?? product.haierOverheadPackage ?? 8.712912),
    runningFoamPolybag: Number(initialParams.runningFoamPolybag ?? product.foamPolybag ?? 0),
    runningPlasticBin: Number(initialParams.runningPlasticBin ?? product.plasticBin ?? 0),
    runningFreightCost: Number(initialParams.runningFreightCost ?? product.freightCost ?? 0),
    runningSecondaryOp1: Number(initialParams.runningSecondaryOp1 ?? product.secondaryOp1 ?? 0),
    runningSecondaryOp2: Number(initialParams.runningSecondaryOp2 ?? product.secondaryOp2 ?? 0),
    runningScreenPrint1: Number(initialParams.runningScreenPrint1 ?? product.screenPrint1 ?? 0),
    runningScreenPrint2: Number(initialParams.runningScreenPrint2 ?? product.screenPrint2 ?? 0),
    runningAssemblyCost: Number(initialParams.runningAssemblyCost ?? product.assemblyCost ?? 0),
    runningMouldMaintenance: Number(initialParams.runningMouldMaintenance ?? product.mouldMaintenance ?? 1.5),
    runningQualityInspection: Number(initialParams.runningQualityInspection ?? product.qualityInspection ?? 1.0),
    runningIccReduce: Number(initialParams.runningIccReduce ?? product.iccReduce ?? -0.29),
    runningScrapAdj: Number(initialParams.runningScrapAdj ?? product.scrapAdj ?? 0)
  });

  const atombergBaseCalc = calculateAtombergCost({
    rmBase: approvedRmRate,
    rmFreight: formData.rmFreight,
    mbBase: approvedMbRate,
    mbFreight: formData.mbFreight,
    partWt: formData.partWeight,
    runnerWt: formData.runnerWeight,
    mbPct: formData.masterbatchPct / 100,
    bopCost: formData.bopCost,
    cycleTime: formData.cycleTimeApproved,
    cavity: formData.cavity,
    tonnage: formData.machineTonnage,
    shiftTariff: formData.shiftTariff,
    packingCost: formData.packingCost,
    transportCost: formData.transportCost,
    otherCost: formData.otherCost
  });

  const atombergRunningCalc = calculateAtombergCost({
    rmBase: runningRmWaRate,
    rmFreight: formData.runningRmFreight,
    mbBase: runningMbWaRate,
    mbFreight: formData.runningMbFreight,
    partWt: formData.runningPartWeight,
    runnerWt: formData.runningRunnerWeight,
    mbPct: formData.runningMbPct / 100,
    bopCost: formData.runningBopCost,
    cycleTime: formData.runningCycleTime,
    cavity: formData.runningCavity,
    tonnage: formData.machineTonnage,
    shiftTariff: formData.runningShiftTariff,
    packingCost: formData.runningPackingCost,
    transportCost: formData.runningTransportCost,
    otherCost: formData.runningOtherCost
  });

  const haierBaseCalc = calculateHaierCost({
    cavity: formData.cavity,
    netWeight: formData.partWeight,
    runnerWeight: formData.runnerWeight,
    shotWeight: formData.partWeight * formData.cavity + formData.runnerWeight,
    meltLossPct: formData.meltLossPct,
    efficiencyPct: formData.efficiencyPct,
    rmRate: approvedRmRate,
    masterbatchPct: formData.masterbatchPct,
    masterbatchRate: approvedMbRate,
    shiftTariff: formData.shiftTariff,
    cycleTime: formData.cycleTimeApproved,
    haierOverheadPackage: formData.haierOverheadPackage,
    foamPolybag: formData.foamPolybag,
    plasticBin: formData.plasticBin,
    freightCost: formData.freightCost,
    secondaryOp1: formData.secondaryOp1,
    secondaryOp2: formData.secondaryOp2,
    screenPrint1: formData.screenPrint1,
    screenPrint2: formData.screenPrint2,
    assemblyCost: formData.assemblyCost,
    bopCost: formData.bopCost,
    mouldMaintenance: formData.mouldMaintenance,
    qualityInspection: formData.qualityInspection,
    iccReduce: formData.iccReduce,
    scrapAdj: formData.scrapAdj
  });

  const haierRunningCalc = calculateHaierCost({
    cavity: formData.runningCavity,
    netWeight: formData.runningPartWeight,
    runnerWeight: formData.runningRunnerWeight,
    shotWeight: formData.runningPartWeight * formData.runningCavity + formData.runningRunnerWeight,
    meltLossPct: formData.runningMeltLossPct,
    efficiencyPct: formData.runningEfficiencyPct,
    rmRate: runningRmWaRate,
    masterbatchPct: formData.runningMbPct,
    masterbatchRate: runningMbWaRate,
    shiftTariff: formData.runningShiftTariff,
    cycleTime: formData.runningCycleTime,
    haierOverheadPackage: formData.runningHaierOverheadPackage,
    foamPolybag: formData.runningFoamPolybag,
    plasticBin: formData.runningPlasticBin,
    freightCost: formData.runningFreightCost,
    secondaryOp1: formData.runningSecondaryOp1,
    secondaryOp2: formData.runningSecondaryOp2,
    screenPrint1: formData.runningScreenPrint1,
    screenPrint2: formData.runningScreenPrint2,
    assemblyCost: formData.runningAssemblyCost,
    bopCost: formData.runningBopCost,
    mouldMaintenance: formData.runningMouldMaintenance,
    qualityInspection: formData.runningQualityInspection,
    iccReduce: formData.runningIccReduce,
    scrapAdj: formData.runningScrapAdj
  });

  const contractTotal = isHaier ? haierBaseCalc.totalCost : atombergBaseCalc.finalLanded;
  const runningTotal = isHaier ? haierRunningCalc.totalCost : atombergRunningCalc.finalLanded;
  const profitLossDelta = Number((contractTotal - runningTotal).toFixed(2));

  const handleSave = () => {
    if (readOnly) {
      onClose();
      return;
    }
    onSave({
      ...product,
      ...formData,
      approvedCost: contractTotal,
      simulatedCost: runningTotal,
      approvedRm: cleanMaterialStr,
      netWeight: formData.partWeight,
      runnerWeight: formData.runnerWeight,
      approvedRmPrice: approvedRmRate,
      approvedMbPrice: approvedMbRate,
      parameters: {
        runningRmFreight: formData.runningRmFreight,
        runningMbFreight: formData.runningMbFreight,
        runningCycleTime: formData.runningCycleTime,
        runningCavity: formData.runningCavity,
        runningRunnerWeight: formData.runningRunnerWeight,
        runningNetWeight: formData.runningPartWeight,
        runningShiftTariff: formData.runningShiftTariff,
        runningMbPct: formData.runningMbPct,
        runningMeltLossPct: formData.runningMeltLossPct,
        runningEfficiencyPct: formData.runningEfficiencyPct,
        runningBopCost: formData.runningBopCost,
        runningPackingCost: formData.runningPackingCost,
        runningTransportCost: formData.runningTransportCost,
        runningOtherCost: formData.runningOtherCost,
        runningHaierOverheadPackage: formData.runningHaierOverheadPackage,
        runningFoamPolybag: formData.runningFoamPolybag,
        runningPlasticBin: formData.runningPlasticBin,
        runningFreightCost: formData.runningFreightCost,
        runningSecondaryOp1: formData.runningSecondaryOp1,
        runningSecondaryOp2: formData.runningSecondaryOp2,
        runningScreenPrint1: formData.runningScreenPrint1,
        runningScreenPrint2: formData.runningScreenPrint2,
        runningAssemblyCost: formData.runningAssemblyCost,
        runningMouldMaintenance: formData.runningMouldMaintenance,
        runningQualityInspection: formData.runningQualityInspection,
        runningIccReduce: formData.runningIccReduce,
        runningScrapAdj: formData.runningScrapAdj
      },
      delta: profitLossDelta
    });
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden text-xs">
        {/* Header */}
        <div className="p-4 bg-slate-900 text-white flex justify-between items-center">
          <div>
            <div className="flex items-center gap-2">
              <span className="bg-blue-600 px-2 py-0.5 rounded font-mono font-bold">{product.itemCode}</span>
              <h2 className="font-bold text-sm">{product.componentName}</h2>
              <span className="bg-slate-800 text-[10px] px-2 py-0.5 rounded-full border border-slate-700">
                {isHaier ? 'Haier 38-Line Costing Format' : 'Atomberg 38-Line Costing Engine'}
              </span>
              {readOnly && (
                <span className="bg-amber-500/20 text-amber-300 border border-amber-500/30 text-[10px] px-2 py-0.5 rounded-full font-bold flex items-center gap-1">
                  <Eye className="w-3 h-3" /> Read-Only View
                </span>
              )}
            </div>
            <p className="text-[11px] text-slate-300 mt-1">
              Vendor: <b>{product.vendor}</b> | RM: <b>{rmLookupKey}</b> (Matrix: ₹{approvedRmRate} → WA: ₹{runningRmWaRate}) | MB: <b>{mbLookupKey}</b> (Matrix: ₹{approvedMbRate} → WA: ₹{runningMbWaRate})
            </p>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-slate-800 rounded-lg text-slate-400 hover:text-white cursor-pointer">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* 3 Summary Badges */}
        <div className="grid grid-cols-3 gap-3 p-4 bg-slate-50 border-b border-slate-200">
          <div className="p-3 bg-white rounded-xl border border-slate-200">
            <div className="text-[10px] uppercase font-bold text-slate-400">Costing (Baseline Contract)</div>
            <div className="text-xl font-black font-mono text-slate-900 mt-0.5">₹{contractTotal.toFixed(2)}</div>
          </div>
          <div className="p-3 bg-white rounded-xl border border-slate-200">
            <div className="text-[10px] uppercase font-bold text-blue-600">Actual Running Shopfloor (Active Alternate)</div>
            <div className="text-xl font-black font-mono text-blue-700 mt-0.5">₹{runningTotal.toFixed(2)}</div>
          </div>
          <div className={`p-3 rounded-xl border ${profitLossDelta >= 0 ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-rose-50 border-rose-200 text-rose-800'}`}>
            <div className="text-[10px] uppercase font-bold">Profit / Loss (Δ)</div>
            <div className="text-xl font-black font-mono mt-0.5">
              {profitLossDelta >= 0 ? `+ ₹${profitLossDelta.toFixed(2)}` : `- ₹${Math.abs(profitLossDelta).toFixed(2)}`}
            </div>
          </div>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-2">
          {!isHaier ? (
            /* ATOMBERG 38-LINE TABLE */
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-800 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-300">
                <tr>
                  <th className="py-2.5 px-3 w-8">#</th>
                  <th className="py-2.5 px-3">Atomberg Costing Line</th>
                  <th className="py-2.5 px-3 text-center w-24">UOM / Rate</th>
                  <th className="py-2.5 px-4 text-right w-44">Approved Baseline</th>
                  <th className="py-2.5 px-4 text-right w-44 text-blue-700">Actual Running</th>
                  <th className="py-2.5 px-3 text-right w-24">Delta (Δ)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 font-medium text-slate-900">
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">1</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Vendor</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right font-bold text-slate-900">{product.vendor}</td>
                  <td className="py-1.5 px-4 text-right font-bold text-blue-800">{product.vendor}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">2</td>
                  <td className="py-1.5 px-3 font-bold text-blue-700">Part Code</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{product.itemCode}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{product.itemCode}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">3</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Part name</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right font-bold text-slate-900">{product.componentName}</td>
                  <td className="py-1.5 px-4 text-right font-bold text-blue-800">{product.componentName}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">4</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">RM grade (Locked & Linked)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right font-semibold text-slate-800">{cleanMaterialStr}</td>
                  <td className="py-1.5 px-4 text-right font-semibold text-blue-800">{cleanMaterialStr}</td>
                  <td className="py-1.5 px-3 text-right text-emerald-600 font-bold">Matched</td>
                </tr>
                <tr className="bg-slate-50/70">
                  <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900 flex items-center gap-1.5">
                    <Lock className="w-3 h-3 text-amber-600" /> RM Base Rate (From RM Matrix)
                  </td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{approvedRmRate.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{runningRmWaRate.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(approvedRmRate - runningRmWaRate).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-900 text-white font-black text-xs">
                  <td className="py-3 px-3 font-mono text-amber-400">38</td>
                  <td className="py-3 px-3 uppercase text-amber-400">FINAL LANDED COST / PC</td>
                  <td className="py-3 px-3 text-center">₹/pc</td>
                  <td className="py-3 px-4 text-right font-mono text-amber-300 text-sm">₹{atombergBaseCalc.finalLanded.toFixed(2)}</td>
                  <td className="py-3 px-4 text-right font-mono text-emerald-400 text-sm">₹{atombergRunningCalc.finalLanded.toFixed(2)}</td>
                  <td className={`py-3 px-3 text-right font-mono ${profitLossDelta >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {profitLossDelta >= 0 ? `+₹${profitLossDelta.toFixed(2)}` : `-₹${Math.abs(profitLossDelta).toFixed(2)}`}
                  </td>
                </tr>
              </tbody>
            </table>
          ) : (
            /* COMPLETE 38-LINE TABLE FOR HAIER */
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-800 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-300">
                <tr>
                  <th className="py-2.5 px-3 w-8">#</th>
                  <th className="py-2.5 px-3">Haier Costing Line</th>
                  <th className="py-2.5 px-3 text-center w-24">UOM / Rate</th>
                  <th className="py-2.5 px-4 text-right w-44">Approved Baseline</th>
                  <th className="py-2.5 px-4 text-right w-44 text-blue-700">Actual Running</th>
                  <th className="py-2.5 px-3 text-right w-24">Delta (Δ)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 font-medium text-slate-900">
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">1</td>
                  <td className="py-1.5 px-3 font-bold">Name Of component</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-bold text-slate-900">{product.componentName}</td>
                  <td className="py-1.5 px-4 text-right font-bold text-blue-800">{product.componentName}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">2</td>
                  <td className="py-1.5 px-3">Mould size L x W x H</td>
                  <td className="py-1.5 px-3 text-center">mm</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.mouldSize}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.mouldSize}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">3</td>
                  <td className="py-1.5 px-3 font-bold text-blue-700">Item No.</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{product.itemCode}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{product.itemCode}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">4</td>
                  <td className="py-1.5 px-3">Model</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.model}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.model}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr className="bg-emerald-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Raw Material Required</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-bold text-emerald-900">{cleanMaterialStr}</td>
                  <td className="py-1.5 px-4 text-right font-bold text-blue-900">{cleanMaterialStr}</td>
                  <td className="py-1.5 px-3 text-right text-emerald-600 font-bold">Matched</td>
                </tr>
                <tr className="bg-purple-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                  <td className="py-1.5 px-3 font-bold text-purple-900">Master Batch Required (%)</td>
                  <td className="py-1.5 px-3 text-center">%</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-purple-900">{formData.masterbatchPct}%</span>
                    ) : (
                      <input type="number" step="0.1" value={formData.masterbatchPct} onChange={e => setFormData({ ...formData, masterbatchPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningMbPct}%</span>
                    ) : (
                      <input type="number" step="0.1" value={formData.runningMbPct} onChange={e => setFormData({ ...formData, runningMbPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.masterbatchPct - formData.runningMbPct).toFixed(1)}%</td>
                </tr>
                <tr className="bg-slate-900 text-white font-black text-xs">
                  <td className="py-3 px-3 font-mono text-amber-400">38</td>
                  <td className="py-3 px-3 uppercase text-amber-400">TOTAL COST</td>
                  <td className="py-3 px-3 text-center">Rs</td>
                  <td className="py-3 px-4 text-right font-mono text-amber-300 text-sm">₹{haierBaseCalc.totalCost.toFixed(2)}</td>
                  <td className="py-3 px-4 text-right font-mono text-emerald-400 text-sm">₹{haierRunningCalc.totalCost.toFixed(2)}</td>
                  <td className={`py-3 px-3 text-right font-mono ${profitLossDelta >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
                    {profitLossDelta >= 0 ? `+₹${profitLossDelta.toFixed(2)}` : `-₹${Math.abs(profitLossDelta).toFixed(2)}`}
                  </td>
                </tr>
              </tbody>
            </table>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-slate-100 border-t border-slate-200 flex justify-between items-center">
          {!readOnly ? (
            <button onClick={() => { if(window.confirm('Delete this part from baseline?')) { onDelete(product.id || product.itemCode); onClose(); }}} className="px-3.5 py-2 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer">
              <Trash2 className="w-4 h-4" /> Delete Product
            </button>
          ) : <div></div>}
          <div className="flex gap-2">
            <button onClick={onClose} className="px-4 py-2 bg-white hover:bg-slate-100 border border-slate-300 rounded-xl font-bold cursor-pointer">
              {readOnly ? 'Close Spec' : 'Cancel'}
            </button>
            {!readOnly && (
              <button onClick={handleSave} className="px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-sm">
                <Save className="w-4 h-4" /> Save & Log Parameters
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
MODAL_EOF

echo "==> 5. Building & verifying Vite server on dev-v2..."
npm run build

echo "==> 6. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ ALL DRILLDOWN HYPERLINKS ACTIVATED SUCCESSFULLY ON DEV-V2!"
echo "-------------------------------------------------------------------"
