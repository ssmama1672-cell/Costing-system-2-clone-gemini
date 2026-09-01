import React, { useState, useEffect } from 'react';
import * as XLSX from 'xlsx';
import {
  Upload, Trash2, Edit3, Search, FileSpreadsheet,
  Layers, Lock, Unlock, ArrowRight, CheckCircle2,
  AlertCircle, History, Sparkles, Filter, ChevronRight, X
} from 'lucide-react';
import {
  globalStore,
  subscribeStore,
  addStagedProductsToBaseline,
  deleteProductFromBaseline,
  clearVendorBaselineProducts,
  updateBaselineParameters,
  toggleGlobalLock,
  getActiveRmMapping,
  getActiveMbMapping,
  sanitizeMaterialName,
  parseMaterialString
} from '../../shared/masterStore';
import InlineEditModal from './InlineEditModal';

export default function BaselineMasterPage() {
  const [store, setStore] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('Haier Appliances');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState('specs'); // 'specs' | 'audit'

  // Staging Modal State
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [stagedData, setStagedData] = useState([]);
  const [selectedStagedIndex, setSelectedStagedIndex] = useState(0);

  // Edit Spec Modal State
  const [editingProduct, setEditingProduct] = useState(null);

  useEffect(() => {
    return subscribeStore(setStore);
  }, []);

  // Filter products for active vendor and search query
  const vendorProducts = (store.baselineProducts || []).filter(p => {
    const vMatch = (p.vendor || '').toLowerCase().includes(selectedVendor.toLowerCase()) ||
                   selectedVendor.toLowerCase().includes((p.vendor || '').toLowerCase());
    if (!vMatch) return false;
    if (!searchQuery) return true;
    const q = searchQuery.toLowerCase();
    return (
      (p.itemCode || '').toLowerCase().includes(q) ||
      (p.componentName || '').toLowerCase().includes(q) ||
      (p.approvedRm || '').toLowerCase().includes(q) ||
      (p.model || '').toLowerCase().includes(q)
    );
  });

  const activeStaged = stagedData[selectedStagedIndex] || null;

  // --------------------------------------------------------------------------
  // Robust Multi-Column Excel Parser
  // --------------------------------------------------------------------------
  const handleFileUpload = (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const bstr = evt.target.result;
        const wb = XLSX.read(bstr, { type: 'binary' });
        const wsname = wb.SheetNames[0];
        const ws = wb.Sheets[wsname];
        const rawMatrix = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

        if (!rawMatrix || rawMatrix.length === 0) {
          alert('Uploaded sheet appears to be empty.');
          return;
        }

        const isHaierVendor = selectedVendor.toLowerCase().includes('haier');
        const parsed = [];
        const maxCols = Math.max(...rawMatrix.map(r => (r && Array.isArray(r) ? r.length : 0)));

        // Scan all data columns starting from index 2 up to maxCols (e.g., Column K, D, etc.)
        for (let c = 2; c < maxCols; c++) {
          let itemCode = '';
          let compName = '';
          let mouldSize = isHaierVendor ? '800x800x684' : '450x450x380';
          let model = isHaierVendor ? 'TM 258/278' : 'Aris Ceiling Fan';
          let rmGradeStr = '';
          let mbCodeStr = '';
          let mbPct = 4.0;
          let cavity = 1;
          let runnerWt = 0;
          let partWt = 0;
          let shotWt = 0;
          let reconWt = 0;
          let tonnage = isHaierVendor ? 600 : 200;
          let tariff = isHaierVendor ? 4800 : 2000;
          let cycleTime = isHaierVendor ? 70 : 47;
          let meltLossPct = 1.0;
          let efficiencyPct = 95.0;

          let haierOverheadPackage = 0;
          let foamPolybag = 0;
          let plasticBin = 0;
          let freightCost = 0;
          let secondaryOp1 = 0;
          let secondaryOp2 = 0;
          let screenPrint1 = 0;
          let screenPrint2 = 0;
          let assemblyCost = 0;
          let bopCost = 0;
          let mouldMaintenance = 0;
          let qualityInspection = 0;
          let iccReduce = 0;
          let scrapAdj = 0;
          let packingCost = 0;
          let transportCost = 0;
          let excelTotalCost = 0;

          rawMatrix.forEach((r) => {
            if (!r || !Array.isArray(r)) return;
            const labelA = String(r[0] || '').toLowerCase().trim();
            const labelB = String(r[1] || '').toLowerCase().trim();
            const labelC = String(r[2] || '').toLowerCase().trim();
            const label = `${labelA} ${labelB} ${labelC}`;

            const rawVal = r[c];
            if (rawVal === undefined || rawVal === null || String(rawVal).trim() === '') return;
            const valStr = String(rawVal).trim();
            const cleanNumStr = valStr.replace(/[^0-9.-]+/g, '');
            const valNum = parseFloat(cleanNumStr);

            // 1. Part Name & Code
            if (label.includes('name of component') || label.includes('part name') || (label.includes('description') && !label.includes('raw') && !label.includes('material'))) {
              if (!compName && isNaN(Number(valStr))) compName = valStr;
            }
            if (label.includes('item no') || label.includes('part code') || label.includes('item code') || (labelA === '3' && !label.includes('master batch'))) {
              if (!itemCode) itemCode = valStr;
            }
            if (label.includes('mould size') || label.includes('mold size')) mouldSize = valStr;
            if (label.includes('model') && !label.includes('cost')) model = valStr;

            // 2. Raw Material & Masterbatch
            if ((label.includes('raw material required') || label.includes('rm grade') || label.includes('material')) && !label.includes('cost') && !label.includes('total') && !label.includes('rate')) {
              if (!rmGradeStr && isNaN(Number(valStr))) rmGradeStr = valStr;
            }
            if (label.includes('mb code') && valStr && valStr !== '-' && isNaN(Number(valStr))) mbCodeStr = valStr;
            if (label.includes('master batch required') || label.includes('mb %') || label.includes('masterbatch %')) {
              if (!isNaN(valNum)) mbPct = valNum <= 1 && valNum > 0 ? Number((valNum * 100).toFixed(2)) : valNum;
            }

            // 3. Technical Parameters
            if (label.includes('cavity') || label.includes('no. of cavity') || label.includes('no of cavity')) {
              const num = parseInt(cleanNumStr, 10);
              if (!isNaN(num) && num > 0) cavity = num;
            }
            if (label.includes('runner weight') && !label.includes('recovery')) {
              if (!isNaN(valNum)) runnerWt = valNum;
            }
            if (label.includes('net weight') || label.includes('part weight')) {
              if (!isNaN(valNum) && valNum > 0) partWt = valNum;
            }
            if (label.includes('shot weight') && !label.includes('reconciliation')) {
              if (!isNaN(valNum) && valNum > 0) shotWt = valNum;
            }
            if (label.includes('reconciliation weight') || label.includes('melt loss on shot')) {
              if (!isNaN(valNum) && valNum > 0) reconWt = valNum;
            }
            if (label.includes('melt loss') || label.includes('% melt loss')) {
              if (!isNaN(valNum)) meltLossPct = valNum <= 1 && valNum > 0 ? valNum * 100 : valNum;
            }

            // 4. Machine & Production
            if (label.includes('machine used') || label.includes('tonnage')) {
              const num = parseInt(cleanNumStr, 10);
              if (!isNaN(num)) tonnage = num;
            }
            if (label.includes('machine tariff') || label.includes('tariff') || label.includes('machine trariff')) {
              if (!isNaN(valNum)) tariff = valNum;
            }
            if (label.includes('cycle time')) {
              if (!isNaN(valNum) && valNum > 0) cycleTime = valNum;
            }
            if (label.includes('efficiency') || label.includes('% efficiency')) {
              if (!isNaN(valNum)) efficiencyPct = valNum <= 1 && valNum > 0 ? valNum * 100 : valNum;
            }

            // 5. Overheads & Secondary
            if (label.includes('overhead') || label.includes('oh+profit')) {
              if (!isNaN(valNum)) haierOverheadPackage = valNum;
            }
            if (label.includes('foam') || label.includes('polybag')) {
              if (!isNaN(valNum)) foamPolybag = valNum;
            }
            if (label.includes('plastic bin') || label.includes('polyenda')) {
              if (!isNaN(valNum)) plasticBin = valNum;
            }
            if (label.includes('freight')) {
              if (!isNaN(valNum)) freightCost = valNum;
            }
            if (label.includes('printing') || label.includes('screen print')) {
              if (!isNaN(valNum)) screenPrint1 = valNum;
            }
            if (label.includes('assembly') || label.includes('assy')) {
              if (!isNaN(valNum)) assemblyCost = valNum;
            }
            if (label.includes('bop')) {
              if (!isNaN(valNum)) bopCost = valNum;
            }
            if (label.includes('maintenance')) {
              if (!isNaN(valNum)) mouldMaintenance = valNum;
            }
            if (label.includes('quality') || label.includes('inspection')) {
              if (!isNaN(valNum)) qualityInspection = valNum;
            }
            if (label.includes('icc')) {
              if (!isNaN(valNum)) iccReduce = valNum;
            }
            if (label.includes('total landed') || label.includes('final cost') || label.includes('grand total') || (label.includes('cost') && label.includes('total'))) {
              if (!isNaN(valNum) && valNum > 0) excelTotalCost = valNum;
            }
          });

          if (itemCode || compName || (partWt > 0 && shotWt > 0)) {
            const finalItemCode = itemCode || `ITEM-${c}`;
            const finalCompName = compName || (itemCode ? `Component ${itemCode}` : `Part Column ${c}`);
            const finalRmStr = sanitizeMaterialName(rmGradeStr, finalCompName, finalItemCode, selectedVendor);
            const { baseRm, mbGrade } = parseMaterialString(finalRmStr);
            const activeMbCode = mbCodeStr || mbGrade || 'None';
            const activeRm = getActiveRmMapping(baseRm || finalRmStr, selectedVendor);
            const activeMb = getActiveMbMapping(activeMbCode, selectedVendor);

            parsed.push({
              id: `prod-${selectedVendor.toLowerCase().replace(/\s+/g, '-')}-${finalItemCode}-${Date.now()}-${c}`,
              vendor: selectedVendor,
              itemCode: finalItemCode,
              componentName: finalCompName,
              model: model,
              mouldSize: mouldSize,
              approvedRm: finalRmStr,
              baseRm: baseRm || finalRmStr,
              approvedMb: activeMbCode,
              masterbatchPct: mbPct,
              cavity: cavity,
              netWeight: partWt,
              runnerWeight: runnerWt,
              shotWeight: shotWt || (partWt * cavity + runnerWt),
              reconciliationWeight: reconWt,
              machineTonnage: tonnage,
              shiftTariff: tariff,
              cycleTimeApproved: cycleTime,
              meltLossPct: meltLossPct,
              efficiencyPct: efficiencyPct,
              approvedCost: excelTotalCost,
              approvedRmPrice: activeRm.approvedPrice || 154,
              approvedMbPrice: activeMb.approvedMbPrice || 242,
              haierOverheadPackage,
              foamPolybag,
              plasticBin,
              freightCost,
              secondaryOp1,
              secondaryOp2,
              screenPrint1,
              screenPrint2,
              assemblyCost,
              bopCost,
              mouldMaintenance,
              qualityInspection,
              iccReduce,
              scrapAdj,
              packingCost,
              transportCost,
              otherCost: 0
            });
          }
        }

        if (parsed.length > 0) {
          setStagedData(parsed);
          setSelectedStagedIndex(0);
          setShowUploadModal(true);
        } else {
          alert('Could not find product specifications in this file. Please check that column headers match.');
        }
      } catch (err) {
        console.error('Error parsing excel:', err);
        alert('Failed to parse Excel file: ' + err.message);
      }
    };
    reader.readAsBinaryString(file);
  };

  const handleSaveStagedProducts = () => {
    if (!stagedData || stagedData.length === 0) return;
    addStagedProductsToBaseline(stagedData, selectedVendor);
    setShowUploadModal(false);
    setStagedData([]);
  };

  return (
    <div className="space-y-6">
      {/* Top Banner / Vendor Header */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center space-x-4">
          <div className="w-12 h-12 rounded-xl bg-blue-600/20 border border-blue-500/30 flex items-center justify-center text-blue-400">
            <Layers className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center space-x-3">
              <h1 className="text-xl font-bold text-white">1. Multi-Vendor Dynamic Product Baseline Master</h1>
              <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                Active Vendor: {selectedVendor}
              </span>
            </div>
            <p className="text-xs text-slate-400 mt-1">Exact 38-Line Costing Engine for Atomberg & Haier</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => clearVendorBaselineProducts(selectedVendor)}
            className="flex items-center space-x-2 px-3.5 py-2 rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-400 border border-rose-500/30 text-xs font-medium transition"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Clear {selectedVendor} Data</span>
          </button>

          <label className="flex items-center space-x-2 px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs shadow-lg shadow-blue-500/25 cursor-pointer transition">
            <Upload className="w-4 h-4" />
            <span>Upload & Stage Spec (.xlsx)</span>
            <input
              type="file"
              accept=".xlsx, .xls"
              onClick={e => (e.target.value = null)}
              onChange={handleFileUpload}
              className="hidden"
            />
          </label>

          <div className="flex rounded-xl bg-slate-800 p-1 border border-slate-700 text-xs">
            <button
              onClick={() => setActiveTab('specs')}
              className={`px-3 py-1.5 rounded-lg font-medium transition ${
                activeTab === 'specs' ? 'bg-blue-600 text-white shadow' : 'text-slate-400 hover:text-white'
              }`}
            >
              Parameters Master ({vendorProducts.length})
            </button>
            <button
              onClick={() => setActiveTab('audit')}
              className={`px-3 py-1.5 rounded-lg font-medium transition ${
                activeTab === 'audit' ? 'bg-blue-600 text-white shadow' : 'text-slate-400 hover:text-white'
              }`}
            >
              Parameter Audit Log ({(store.auditLogs || []).length})
            </button>
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-4 flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-96">
          <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
          <input
            type="text"
            placeholder={`Search ${selectedVendor} components...`}
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-800/80 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div className="flex items-center space-x-3 w-full md:w-auto justify-end">
          <span className="text-xs text-slate-400 font-medium">Switch Vendor:</span>
          <select
            value={selectedVendor}
            onChange={e => setSelectedVendor(e.target.value)}
            className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-xl text-xs text-white focus:outline-none focus:border-blue-500 font-semibold"
          >
            {(store.vendors || []).map(v => (
              <option key={v.vendorId} value={v.vendorName}>
                {v.vendorName}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Table Section */}
      {activeTab === 'specs' ? (
        <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
          <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between">
            <div className="flex items-center space-x-2">
              <FileSpreadsheet className="w-4 h-4 text-blue-400" />
              <h3 className="text-xs font-bold uppercase tracking-wider text-slate-200">
                {selectedVendor.toUpperCase()} BASELINE PARAMETERS MASTER
              </h3>
            </div>
            <span className="text-xs text-slate-400 font-medium">{vendorProducts.length} Active Parts</span>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-800/60 text-slate-400 border-b border-slate-800 font-semibold uppercase tracking-wider text-[10px]">
                  <th className="py-3 px-4">Item Code / Component</th>
                  <th className="py-3 px-3">Model</th>
                  <th className="py-3 px-3">Approved RM / MB</th>
                  <th className="py-3 px-3 text-center">MB %</th>
                  <th className="py-3 px-3 text-center">Cavity</th>
                  <th className="py-3 px-3 text-right">Net Wt</th>
                  <th className="py-3 px-3 text-right">Runner Wt</th>
                  <th className="py-3 px-3 text-center bg-amber-500/10 text-amber-300">Cycle Time</th>
                  <th className="py-3 px-3 text-center">Tonnage</th>
                  <th className="py-3 px-3 text-right">Shift Tariff</th>
                  <th className="py-3 px-4 text-center">Edit Spec</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-slate-300">
                {vendorProducts.length === 0 ? (
                  <tr>
                    <td colSpan={11} className="py-12 text-center text-slate-500 text-xs">
                      No baseline parts found for {selectedVendor}. Click <span className="text-blue-400 font-semibold">Upload & Stage Spec</span> to import records.
                    </td>
                  </tr>
                ) : (
                  vendorProducts.map(p => (
                    <tr key={p.id || p.itemCode} className="hover:bg-slate-800/40 transition">
                      <td className="py-3 px-4">
                        <div className="font-bold text-white">{p.itemCode}</div>
                        <div className="text-[11px] text-slate-400 truncate max-w-xs">{p.componentName}</div>
                      </td>
                      <td className="py-3 px-3 text-slate-300">{p.model || '-'}</td>
                      <td className="py-3 px-3">
                        <div className="text-slate-200 font-medium">{p.approvedRm || p.baseRm}</div>
                        <div className="text-[10px] text-slate-400">{p.approvedMb || 'None'}</div>
                      </td>
                      <td className="py-3 px-3 text-center font-mono">{p.masterbatchPct || 4}%</td>
                      <td className="py-3 px-3 text-center font-mono">{p.cavity || 1}</td>
                      <td className="py-3 px-3 text-right font-mono">{Number(p.netWeight || 0).toFixed(2)}g</td>
                      <td className="py-3 px-3 text-right font-mono">{Number(p.runnerWeight || 0).toFixed(2)}g</td>
                      <td className="py-3 px-3 text-center font-mono bg-amber-500/5 text-amber-300 font-bold">{p.cycleTimeApproved || 47}s</td>
                      <td className="py-3 px-3 text-center font-mono">{p.machineTonnage || 200}T</td>
                      <td className="py-3 px-3 text-right font-mono font-semibold text-emerald-400">₹{p.shiftTariff || 2000}</td>
                      <td className="py-3 px-4 text-center">
                        <button
                          onClick={() => setEditingProduct(p)}
                          className="px-3 py-1 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 border border-blue-500/30 text-xs font-medium transition"
                        >
                          Edit
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* Audit Log Tab */
        <div className="bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden shadow-xl p-6">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-200 mb-4 flex items-center space-x-2">
            <History className="w-4 h-4 text-purple-400" />
            <span>Parameter Revision History</span>
          </h3>
          <div className="space-y-3">
            {(store.auditLogs || []).length === 0 ? (
              <p className="text-xs text-slate-500 text-center py-8">No audit logs recorded yet.</p>
            ) : (
              (store.auditLogs || []).map((log, idx) => (
                <div key={idx} className="p-3 bg-slate-800/40 border border-slate-800 rounded-xl flex items-center justify-between text-xs">
                  <div>
                    <span className="font-bold text-white">{log.partCode}</span> - {log.componentName} ({log.vendor})
                    <p className="text-[11px] text-slate-400">{log.modifications} • {log.reason}</p>
                  </div>
                  <div className="text-right">
                    <span className="text-[10px] text-slate-500">{log.timestamp}</span>
                    <div className="text-xs font-semibold text-emerald-400">{log.costImpact}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Staging Modal */}
      {showUploadModal && activeStaged && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col shadow-2xl">
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-800/60">
              <div className="flex items-center space-x-3">
                <Sparkles className="w-5 h-5 text-blue-400" />
                <h3 className="font-bold text-white text-sm">
                  Staging Review ({selectedStagedIndex + 1} of {stagedData.length}): {activeStaged.itemCode}
                </h3>
              </div>
              <button
                onClick={() => setShowUploadModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700 transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-4 text-xs">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-slate-800/50 rounded-xl border border-slate-700/60">
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Component Name</label>
                  <div className="font-semibold text-white mt-1">{activeStaged.componentName}</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Item Code</label>
                  <div className="font-semibold text-white mt-1">{activeStaged.itemCode}</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Approved RM</label>
                  <div className="font-semibold text-emerald-400 mt-1">{activeStaged.approvedRm}</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Approved MB</label>
                  <div className="font-semibold text-purple-400 mt-1">{activeStaged.approvedMb}</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Part Net Wt</label>
                  <div className="font-mono text-white mt-1">{activeStaged.netWeight} g</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Runner Wt</label>
                  <div className="font-mono text-white mt-1">{activeStaged.runnerWeight} g</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Cavity</label>
                  <div className="font-mono text-white mt-1">{activeStaged.cavity}</div>
                </div>
                <div>
                  <label className="text-slate-400 block text-[10px] uppercase font-bold">Cycle Time</label>
                  <div className="font-mono text-amber-300 font-bold mt-1">{activeStaged.cycleTimeApproved} s</div>
                </div>
              </div>

              {/* Staging Carousel Navigation */}
              {stagedData.length > 1 && (
                <div className="flex items-center justify-between pt-2">
                  <button
                    disabled={selectedStagedIndex === 0}
                    onClick={() => setSelectedStagedIndex(prev => Math.max(0, prev - 1))}
                    className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-white font-medium text-xs disabled:opacity-50 transition"
                  >
                    Previous Part
                  </button>
                  <span className="text-xs text-slate-400">
                    Viewing {selectedStagedIndex + 1} of {stagedData.length} parts
                  </span>
                  <button
                    disabled={selectedStagedIndex === stagedData.length - 1}
                    onClick={() => setSelectedStagedIndex(prev => Math.min(stagedData.length - 1, prev + 1))}
                    className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-white font-medium text-xs disabled:opacity-50 transition"
                  >
                    Next Part
                  </button>
                </div>
              )}
            </div>

            <div className="p-4 border-t border-slate-800 flex items-center justify-between bg-slate-800/40">
              <button
                onClick={() => setShowUploadModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveStagedProducts}
                className="flex items-center space-x-2 px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/20 transition"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>Confirm & Save All {stagedData.length} Parts to Baseline</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Spec Inline Modal */}
      {editingProduct && (
        <InlineEditModal
          product={editingProduct}
          isOpen={Boolean(editingProduct)}
          onClose={() => setEditingProduct(null)}
          onSave={(updatedItem, reason) => {
            updateBaselineParameters({ itemId: editingProduct.id || editingProduct.itemCode, updatedItem, reason });
            setEditingProduct(null);
          }}
        />
      )}
    </div>
  );
}
