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
