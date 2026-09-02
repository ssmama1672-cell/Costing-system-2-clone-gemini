import React, { useState, useEffect } from 'react';
import { Calculator, Download, Search, Layers, TrendingUp, TrendingDown } from 'lucide-react';
import * as XLSX from 'xlsx';
import { globalStore, subscribeStore, getActiveRmMapping, parseMaterialString, normalizeVendorId } from '../../shared/masterStore';
import { calculateDetailedCost } from '../module1-baseline/InlineEditModal';

export default function CostingRunEnginePage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');
  const [periodFrom, setPeriodFrom] = useState('2026-08-01');
  const [periodTo, setPeriodTo] = useState('2026-08-31');

  useEffect(() => {
    const unsub = subscribeStore(() => setStoreState({ ...globalStore }));
    return () => unsub();
  }, []);

  const vendors = storeState.vendors || [];
  const products = (storeState.baselineProducts || []).filter(p => 
    selectedVendor === 'ALL' || normalizeVendorId(p.vendor) === normalizeVendorId(selectedVendor)
  );

  const filteredProducts = products.filter(p => 
    !searchQuery || 
    (p.itemCode || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (p.componentName || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const simulationRows = filteredProducts.map(prod => {
    const { baseRm } = parseMaterialString(prod.approvedRm || prod.baseRm);
    const rmLookupKey = baseRm || prod.baseRm || prod.approvedRm;
    const rmMap = getActiveRmMapping(rmLookupKey, prod.vendor);
    
    // Live calculation fetching exact baseline and simulated costs
    const detailed = calculateDetailedCost(prod);
    const approvedBaselineCost = Number(detailed.approvedBaselineCost || prod.approvedCost || 0);
    const simulatedActualCost = Number(detailed.simulatedActualCost || detailed.finalLanded || approvedBaselineCost);
    const delta = Number((approvedBaselineCost - simulatedActualCost).toFixed(2));

    return {
      ...prod,
      rmLookupKey,
      approvedRmRate: rmMap.approvedPrice || prod.approvedRmPrice || 0,
      activeWaRate: rmMap.activeWaPrice || rmMap.approvedPrice || prod.approvedRmPrice || 0,
      approvedBaselineCost,
      simulatedActualCost,
      delta
    };
  });

  const handleDownloadCostMatrix = () => {
    const exportData = simulationRows.map(r => ({
      "Item Code": r.itemCode,
      "Component Name": r.componentName,
      "Vendor": r.vendor,
      "Approved RM": r.approvedRm,
      "Approved RM Rate (₹/kg)": r.approvedRmRate,
      "Active WA Rate (₹/kg)": r.activeWaRate,
      "Approved Baseline Cost (₹)": r.approvedBaselineCost,
      "Simulated Actual Cost (₹)": r.simulatedActualCost,
      "Profit / Loss Delta (₹)": r.delta
    }));
    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, "Simulation_Matrix");
    XLSX.writeFile(wb, `Cost_Simulation_Matrix_${selectedVendor}_${new Date().toISOString().slice(0,10)}.xlsx`);
  };

  return (
    <div className="space-y-4 text-xs font-sans">
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-blue-600 rounded-xl"><Calculator className="w-5 h-5 text-white" /></div>
          <div>
            <h1 className="text-sm font-bold">3. Dynamic Costing Run Engine</h1>
            <p className="text-[11px] text-slate-300">Live simulation matching contract baselines against active material inward rates.</p>
          </div>
        </div>
        <button onClick={handleDownloadCostMatrix} className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-sm text-xs">
          <Download className="w-4 h-4" /> Export Simulation (.xlsx)
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex flex-wrap justify-between items-center gap-3">
            <div className="flex items-center gap-2">
              <Layers className="w-4 h-4 text-blue-400" />
              <h2 className="text-xs font-bold uppercase tracking-wider">Live Product Cost Simulation Matrix</h2>
            </div>
            
            {/* VENDOR & PERIOD FILTER CONTROLS */}
            <div className="flex flex-wrap items-center gap-2 text-xs">
              <div className="flex items-center gap-1.5 bg-slate-800 px-2.5 py-1 rounded-xl border border-slate-700">
                <span className="text-slate-400 font-bold text-[11px]">Vendor:</span>
                <select 
                  value={selectedVendor} 
                  onChange={e => setSelectedVendor(e.target.value)}
                  className="bg-transparent text-white font-bold text-xs focus:outline-none cursor-pointer"
                >
                  <option value="ALL" className="bg-slate-900 text-white">All Vendors Combined</option>
                  {vendors.map(v => (
                    <option key={v.vendorId || v} value={v.vendorId || v} className="bg-slate-900 text-white">
                      {v.vendorName || v}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-1.5 bg-slate-800 px-2.5 py-1 rounded-xl border border-slate-700">
                <span className="text-slate-400 font-bold text-[11px]">Period:</span>
                <input 
                  type="date" 
                  value={periodFrom} 
                  onChange={e => setPeriodFrom(e.target.value)} 
                  className="bg-transparent text-white font-mono text-[11px] focus:outline-none"
                />
                <span className="text-slate-500">to</span>
                <input 
                  type="date" 
                  value={periodTo} 
                  onChange={e => setPeriodTo(e.target.value)} 
                  className="bg-transparent text-white font-mono text-[11px] focus:outline-none"
                />
              </div>

              <div className="relative">
                <Search className="w-3.5 h-3.5 absolute left-2.5 top-2 text-slate-400" />
                <input 
                  type="text" 
                  placeholder="Search parts..." 
                  value={searchQuery} 
                  onChange={e => setSearchQuery(e.target.value)} 
                  className="bg-slate-800 text-white text-xs pl-8 pr-3 py-1 rounded-xl border border-slate-700 focus:outline-none w-36 focus:w-48 transition-all"
                />
              </div>

              <button onClick={handleDownloadCostMatrix} className="px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 text-xs cursor-pointer shadow-sm">
                <Download className="w-3.5 h-3.5" /> Download Cost Matrix (.xlsx)
              </button>
            </div>
          </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead className="bg-slate-100 text-slate-800 uppercase font-bold text-[10px] border-b border-slate-300">
              <tr>
                <th className="py-2.5 px-3">Item Code / Component</th>
                <th className="py-2.5 px-3 text-center">Vendor</th>
                <th className="py-2.5 px-3">Approved RM</th>
                <th className="py-2.5 px-3 text-center">Approved RM Rate</th>
                <th className="py-2.5 px-3 text-center text-blue-700">Active WA Rate</th>
                <th className="py-2.5 px-3 text-right bg-amber-100 text-amber-950 font-bold">Approved Baseline</th>
                <th className="py-2.5 px-3 text-right font-bold text-slate-900">Simulated Actual</th>
                <th className="py-2.5 px-4 text-center">Profit / Loss (Δ)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {simulationRows.length === 0 ? (
                <tr><td colSpan={8} className="py-10 text-center text-slate-400 font-medium">No products found. Upload baseline data in <b>1. Baseline Master</b> to run live simulations.</td></tr>
              ) : (
                simulationRows.map(r => (
                  <tr key={r.id || r.itemCode} className="hover:bg-slate-50 transition font-medium">
                    <td className="py-2.5 px-3">
                      <div className="font-mono font-bold text-blue-700">{r.itemCode}</div>
                      <div className="font-semibold text-slate-800">{r.componentName}</div>
                    </td>
                    <td className="py-2.5 px-3 text-center font-bold text-slate-700">{r.vendor}</td>
                    <td className="py-2.5 px-3 text-slate-800">{r.approvedRm}</td>
                    <td className="py-2.5 px-3 text-center font-mono font-bold text-slate-700">₹{Number(r.approvedRmRate).toFixed(2)}/kg</td>
                    <td className="py-2.5 px-3 text-center font-mono font-bold text-blue-700">₹{Number(r.activeWaRate).toFixed(2)}/kg</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-amber-950 bg-amber-50">₹{r.approvedBaselineCost.toFixed(2)}</td>
                    <td className="py-2.5 px-3 text-right font-mono font-black text-slate-900">₹{r.simulatedActualCost.toFixed(2)}</td>
                    <td className="py-2.5 px-4 text-center font-bold font-mono">
                      <span className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs ${r.delta >= 0 ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                        {r.delta >= 0 ? <TrendingUp className="w-3.5 h-3.5" /> : <TrendingDown className="w-3.5 h-3.5" />}
                        {r.delta >= 0 ? `+ ₹${r.delta.toFixed(2)}` : `- ₹${Math.abs(r.delta).toFixed(2)}`}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
