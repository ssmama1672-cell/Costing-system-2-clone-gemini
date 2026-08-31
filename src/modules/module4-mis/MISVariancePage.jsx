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
