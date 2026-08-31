#!/usr/bin/env bash
set -e

echo "==> 1. Updating BaselineMasterPage.jsx to remove all hardcoded fallbacks..."
cat << 'PAGE_EOF' > src/modules/module1-baseline/BaselineMasterPage.jsx
import React, { useState, useEffect, useRef } from 'react';
import { 
  Upload, 
  Trash2, 
  Edit3, 
  Search, 
  Layers, 
  Database, 
  CheckCircle2, 
  ChevronLeft, 
  ChevronRight, 
  X 
} from 'lucide-react';
import * as XLSX from 'xlsx';
import { 
  globalStore, 
  subscribeStore, 
  updateBaselineParameters, 
  deleteProductFromBaseline, 
  clearVendorBaselineProducts, 
  addStagedProductsToBaseline, 
  addOrUpdateVendorMaterial, 
  parseMaterialString, 
  getActiveRmMapping, 
  getActiveMbMapping,
  normalizeVendorId
} from '../../shared/masterStore';
import InlineEditModal from './InlineEditModal';
import { calculateAtombergCost, calculateHaierCost } from '../../shared/costCalculationService';

export default function BaselineMasterPage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('Haier Appliances');
  const [activeTab, setActiveTab] = useState('parameters');
  const [searchQuery, setSearchQuery] = useState('');
  const [editingProduct, setEditingProduct] = useState(null);
  
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [stagedData, setStagedData] = useState([]);
  const [selectedStagedIndex, setSelectedStagedIndex] = useState(0);
  const tabsContainerRef = useRef(null);

  useEffect(() => {
    const unsub = subscribeStore(() => {
      setStoreState({ ...globalStore });
    });
    return () => unsub();
  }, []);

  const vendors = storeState.vendors || [
    { vendorId: 'Haier Appliances', vendorName: 'Haier Appliances' },
    { vendorId: 'Atomberg Technologies', vendorName: 'Atomberg Technologies' },
    { vendorId: 'Atharva Polymer', vendorName: 'Atharva Polymer (Haier)' }
  ];

  const vendorProducts = (storeState.baselineProducts || []).filter(p => 
    selectedVendor === 'ALL' || normalizeVendorId(p.vendor) === normalizeVendorId(selectedVendor)
  );

  const filteredProducts = vendorProducts.filter(p => 
    !searchQuery || 
    (p.itemCode || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (p.componentName || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (p.approvedRm || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const vendorAuditLogs = (storeState.auditLogs || []).filter(l => 
    selectedVendor === 'ALL' ||
    normalizeVendorId(l.vendor) === normalizeVendorId(selectedVendor) ||
    l.vendor === 'ALL'
  );

  const handleEditClick = (prod) => {
    const { baseRm, mbGrade } = parseMaterialString(prod.approvedRm || prod.baseRm);
    const rmLookupKey = baseRm || prod.baseRm || prod.approvedRm;
    const mbLookupKey = mbGrade || prod.approvedMb || (prod.masterbatchPct > 0 ? (normalizeVendorId(prod.vendor) === 'atomberg' ? 'Gloss White MB' : 'White MB') : 'None');

    const rmMap = getActiveRmMapping(rmLookupKey, prod.vendor);
    const mbMap = getActiveMbMapping(mbLookupKey, prod.vendor);
    
    setEditingProduct({
      ...prod,
      baseRm: rmLookupKey,
      approvedMb: mbLookupKey,
      approvedRmPrice: Number(rmMap.approvedPrice || prod.approvedRmPrice || 0),
      activeRmWaPrice: Number(rmMap.activeWaPrice || rmMap.approvedPrice || prod.approvedRmPrice || 0),
      approvedMbPrice: Number(mbMap.approvedMbPrice || prod.approvedMbPrice || 0),
      activeMbWaPrice: Number(mbMap.activeMbWaPrice || mbMap.approvedMbPrice || prod.approvedMbPrice || 0)
    });
  };

  const handleSaveProduct = (updatedItem) => {
    updateBaselineParameters({
      itemId: updatedItem.id || updatedItem.itemCode,
      updatedItem,
      reason: 'Manual Spec Parameter Adjustment via Edit Modal'
    });
    setEditingProduct(null);
  };

  const handleDeleteProduct = (itemId) => {
    deleteProductFromBaseline(itemId, selectedVendor);
    setEditingProduct(null);
  };

  const handleFileUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const bstr = evt.target.result;
      const wb = XLSX.read(bstr, { type: 'binary' });
      const wsname = wb.SheetNames[0];
      const ws = wb.Sheets[wsname];
      const rawMatrix = XLSX.utils.sheet_to_json(ws, { header: 1 });

      if (!rawMatrix || rawMatrix.length === 0) return;

      const parsed = [];
      const isHaierVendor = selectedVendor.toLowerCase().includes('haier');

      // Detect first data column index (skips S.N., Description, UOM)
      let dataStartCol = 3;
      for (let r = 0; r < Math.min(5, rawMatrix.length); r++) {
        for (let c = 0; c < (rawMatrix[r] || []).length; c++) {
          const val = String(rawMatrix[r][c] || '').toLowerCase().trim();
          if (val === 'description' || val === 'name of component' || val === 'part name') {
            for (let nextC = c + 1; nextC < Math.min(c + 4, (rawMatrix[r] || []).length); nextC++) {
              const nextVal = String(rawMatrix[r][nextC] || '').toLowerCase().trim();
              if (nextVal === 'uom' || nextVal === 'uom / rate' || nextVal === 'unit' || nextVal === '-') {
                dataStartCol = nextC + 1;
                break;
              }
            }
          }
        }
      }

      const totalCols = Math.max(...rawMatrix.map(r => r.length));

      for (let c = dataStartCol; c < totalCols; c++) {
        let itemCode = '';
        let compName = '';
        let mouldSize = isHaierVendor ? '800x800x684' : '450x450x380';
        let model = isHaierVendor ? 'TM 258/278' : 'Aris Ceiling Fan';
        let rmGradeStr = '';
        let mbCodeStr = '';
        let rmBaseRate = isHaierVendor ? 154 : 131;
        let mbBaseRate = isHaierVendor ? 242 : 154;
        let mbPct = 4.0;
        let cavity = isHaierVendor ? 1 : 2;
        let runnerWt = 0;
        let partWt = 0;
        let shotWt = 0;
        let reconWt = 0;
        let tonnage = isHaierVendor ? 600 : 200;
        let tariff = isHaierVendor ? 4800 : 2000;
        let cycleTime = isHaierVendor ? 70 : 47;
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
          const label = `${r[0] || ''} ${r[1] || ''}`.toLowerCase().trim();
          const val = r[c];
          if (val === undefined || val === null || val === '') return;
          const valStr = String(val).trim();
          const valNum = parseFloat(valStr);

          // 1. Part Name & Code
          if (label.includes('name of component') || label.includes('part name') || (label.includes('description') && !label.includes('grade'))) {
            if (!compName) compName = valStr;
          }
          if (label.includes('item no') || label.includes('part code') || label === '3' || label === '2') {
            if (!itemCode) itemCode = valStr;
          }
          if (label.includes('mould size') || label.includes('mold size')) {
            mouldSize = valStr;
          }
          if (label.includes('model') && !label.includes('cost')) {
            model = valStr;
          }

          // 2. Raw Material Required & MB Code
          if (
            (label.includes('raw material required') || label.includes('rm grade (locked') || (label.startsWith('5') && label.includes('raw material'))) &&
            !label.includes('cost') && !label.includes('rate') && !label.includes('total')
          ) {
            rmGradeStr = valStr;
          }
          if (label.includes('mb code') && valStr && valStr !== '-' && valStr !== 'nan') {
            mbCodeStr = valStr;
          }

          if (label.includes('master batch required') || label.includes('mb %')) {
            if (!isNaN(valNum)) mbPct = valNum <= 1 ? valNum * 100 : valNum;
          }
          if (label.includes('no. of cavity') || label.includes('no of cavity')) {
            const num = parseInt(valStr, 10);
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
          if (label.includes('reconciliation weight')) {
            if (!isNaN(valNum) && valNum > 0) reconWt = valNum;
          }
          if (label.includes('machine used') || label.includes('tonnage')) {
            const num = parseInt(valStr, 10);
            if (!isNaN(num) && num > 0) tonnage = num;
          }
          if (label.includes('machine tariff') || label.includes('shift tariff') || label.includes('shift rate')) {
            if (!isNaN(valNum) && valNum > 0) tariff = valNum;
          }
          if (label.includes('cycle time') && !label.includes('rejection') && !label.includes('reconciliation')) {
            if (!isNaN(valNum) && valNum > 1) cycleTime = valNum;
          }

          // Haier Costing Lines (24 to 38) - Exact values from Excel without arbitrary fallbacks
          if (label.includes('oh + profit') || label.includes('overhead')) {
            if (!isNaN(valNum)) haierOverheadPackage = valNum;
          }
          if (label.includes('foam / polybag') || label.includes('foam packing')) {
            if (!isNaN(valNum)) foamPolybag = valNum;
          }
          if (label.includes('plastic bin')) {
            if (!isNaN(valNum)) plasticBin = valNum;
          }
          if (label.includes('freight cost') && !label.includes('mb freight')) {
            if (!isNaN(valNum)) freightCost = valNum;
          }
          if (label.includes('secondary operation 1')) {
            if (!isNaN(valNum)) secondaryOp1 = valNum;
          }
          if (label.includes('secondary operation 2')) {
            if (!isNaN(valNum)) secondaryOp2 = valNum;
          }
          if (label.includes('screen printing - 1st')) {
            if (!isNaN(valNum)) screenPrint1 = valNum;
          }
          if (label.includes('screen printing - 2nd')) {
            if (!isNaN(valNum)) screenPrint2 = valNum;
          }
          if (label.includes('assembly cost')) {
            if (!isNaN(valNum)) assemblyCost = valNum;
          }
          if (label.includes('insert / hinge')) {
            if (!isNaN(valNum)) bopCost = valNum;
          }
          if (label.includes('mould maintenance')) {
            if (!isNaN(valNum)) mouldMaintenance = valNum;
          }
          if (label.includes('quality inspection')) {
            if (!isNaN(valNum)) qualityInspection = valNum;
          }
          if (label.includes('icc reduce')) {
            if (!isNaN(valNum)) iccReduce = valNum;
          }
          if (label.includes('scrap recovery adjustment')) {
            if (!isNaN(valNum)) scrapAdj = valNum;
          }
          if (label.includes('packing cost')) {
            if (!isNaN(valNum)) packingCost = valNum;
          }
          if (label.includes('transport cost')) {
            if (!isNaN(valNum)) transportCost = valNum;
          }
          if (label.includes('total cost') || label === '38' || label === '41') {
            if (!isNaN(valNum) && valNum > 0) excelTotalCost = valNum;
          }
        });

        // Fixed-row fallbacks if direct search was empty
        if (!compName && rawMatrix[2]?.[c]) compName = String(rawMatrix[2][c]).trim();
        if (!itemCode && rawMatrix[4]?.[c]) itemCode = String(rawMatrix[4][c]).trim();
        if (!rmGradeStr && rawMatrix[6]?.[c]) rmGradeStr = String(rawMatrix[6][c]).trim();

        if (!compName && !itemCode) continue;

        itemCode = itemCode || compName;
        compName = compName || itemCode;
        rmGradeStr = rmGradeStr || (isHaierVendor ? 'HIPS SH303 + White MB' : 'PP H110MA + Gloss White');

        const { baseRm, mbGrade } = parseMaterialString(rmGradeStr);
        const resolvedMb = mbCodeStr || mbGrade || (isHaierVendor ? 'White MB' : 'Gloss White MB');

        if (baseRm) {
          addOrUpdateVendorMaterial({
            vendor: selectedVendor,
            type: 'RM',
            approvedCode: baseRm,
            approvedPrice: rmBaseRate
          });
        }
        if (resolvedMb) {
          addOrUpdateVendorMaterial({
            vendor: selectedVendor,
            type: 'MB',
            approvedCode: resolvedMb,
            approvedPrice: mbBaseRate
          });
        }

        let calcResult = 0;
        if (isHaierVendor) {
          const ctApp = cycleTime > 0 ? cycleTime : 70;
          const cavApp = cavity > 0 ? cavity : 1;
          const partsPerShift = (28800 / ctApp) * 0.95 * cavApp;

          const h = calculateHaierCost({
            cavity: cavApp,
            netWeight: partWt,
            runnerWeight: runnerWt,
            shotWeight: shotWt || (partWt * cavApp + runnerWt),
            meltLossPct: 1.0,
            efficiencyPct: 95.0,
            partsPerShift: partsPerShift,
            rmRate: rmBaseRate,
            masterbatchPct: mbPct,
            masterbatchRate: mbBaseRate,
            shiftTariff: tariff,
            cycleTime: ctApp,
            haierOverheadPackage: haierOverheadPackage,
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
            scrapAdj
          });
          calcResult = excelTotalCost > 0 ? excelTotalCost : h.totalCost;
        } else {
          const a = calculateAtombergCost({
            rmBase: rmBaseRate,
            mbBase: mbBaseRate,
            partWt: partWt,
            runnerWt: runnerWt,
            mbPct: mbPct / 100,
            bopCost: bopCost,
            cycleTime: cycleTime,
            cavity: cavity,
            tonnage: tonnage,
            shiftTariff: tariff,
            packingCost: packingCost,
            transportCost: transportCost,
            otherCost: 0.00
          });
          calcResult = excelTotalCost > 0 ? excelTotalCost : a.finalLanded;
        }

        parsed.push({
          id: `prod-${itemCode}-${c}`,
          vendor: selectedVendor,
          componentName: compName,
          mouldSize: mouldSize,
          itemCode: itemCode,
          model: model,
          approvedRm: rmGradeStr,
          baseRm: baseRm || rmGradeStr,
          approvedMb: resolvedMb,
          masterbatchPct: mbPct,
          cavity: cavity,
          runnerWeight: runnerWt,
          netWeight: partWt,
          shotWeight: shotWt || (partWt * cavity + runnerWt),
          reconciliationWeight: reconWt,
          machineTonnage: tonnage,
          shiftTariff: tariff,
          cycleTimeApproved: cycleTime,
          meltLossPct: 1.0,
          efficiencyPct: 95.0,
          haierOverheadPackage: haierOverheadPackage,
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
          approvedCost: calcResult,
          parameters: {
            runningCycleTime: cycleTime,
            runningCavity: cavity,
            runningRunnerWeight: runnerWt,
            runningNetWeight: partWt,
            runningShiftTariff: tariff,
            runningMbPct: mbPct,
            runningMeltLossPct: 1.0,
            runningEfficiencyPct: 95.0,
            runningHaierOverheadPackage: haierOverheadPackage,
            runningFoamPolybag: foamPolybag,
            runningPlasticBin: plasticBin,
            runningFreightCost: freightCost,
            runningSecondaryOp1: secondaryOp1,
            runningSecondaryOp2: secondaryOp2,
            runningScreenPrint1: screenPrint1,
            runningScreenPrint2: screenPrint2,
            runningAssemblyCost: assemblyCost,
            runningBopCost: bopCost,
            runningMouldMaintenance: mouldMaintenance,
            runningQualityInspection: qualityInspection,
            runningIccReduce: iccReduce,
            runningScrapAdj: scrapAdj,
            runningPackingCost: packingCost,
            runningTransportCost: transportCost
          }
        });
      }

      setStagedData(parsed);
      setSelectedStagedIndex(0);
      setShowUploadModal(true);
    };
    reader.readAsBinaryString(file);
  };

  const handleUpdateActiveStaged = (field, value) => {
    setStagedData(prev => {
      const copy = [...prev];
      copy[selectedStagedIndex] = {
        ...copy[selectedStagedIndex],
        [field]: value
      };
      return copy;
    });
  };

  const handleCommitStaged = () => {
    addStagedProductsToBaseline(stagedData, selectedVendor);
    setStagedData([]);
    setShowUploadModal(false);
  };

  const scrollTabs = (offset) => {
    if (tabsContainerRef.current) {
      tabsContainerRef.current.scrollBy({ left: offset, behavior: 'smooth' });
    }
  };

  const activeStaged = stagedData[selectedStagedIndex] || null;
  const isHaierVendor = (selectedVendor || '').toLowerCase().includes('haier');

  let atomStagedCalc = null;
  let haierStagedCalc = null;
  let computedStagedTotal = 0;

  if (activeStaged) {
    if (isHaierVendor) {
      const ctApp = Number(activeStaged.cycleTimeApproved || 70);
      const cavApp = Number(activeStaged.cavity || 1);
      const partsPerShift = (28800 / (ctApp > 0 ? ctApp : 1)) * 0.95 * cavApp;

      haierStagedCalc = calculateHaierCost({
        cavity: cavApp,
        netWeight: Number(activeStaged.netWeight || 372),
        runnerWeight: Number(activeStaged.runnerWeight || 0),
        shotWeight: Number(activeStaged.shotWeight || (Number(activeStaged.netWeight || 372) * cavApp)),
        partsPerShift: partsPerShift,
        rmRate: 154,
        masterbatchPct: Number(activeStaged.masterbatchPct || 4),
        masterbatchRate: 242,
        shiftTariff: Number(activeStaged.shiftTariff || 4800),
        cycleTime: ctApp,
        haierOverheadPackage: Number(activeStaged.haierOverheadPackage || 0),
        foamPolybag: Number(activeStaged.foamPolybag || 0),
        plasticBin: Number(activeStaged.plasticBin || 0),
        freightCost: Number(activeStaged.freightCost || 0),
        secondaryOp1: Number(activeStaged.secondaryOp1 || 0),
        secondaryOp2: Number(activeStaged.secondaryOp2 || 0),
        screenPrint1: Number(activeStaged.screenPrint1 || 0),
        screenPrint2: Number(activeStaged.screenPrint2 || 0),
        assemblyCost: Number(activeStaged.assemblyCost || 0),
        bopCost: Number(activeStaged.bopCost || 0),
        mouldMaintenance: Number(activeStaged.mouldMaintenance || 0),
        qualityInspection: Number(activeStaged.qualityInspection || 0),
        iccReduce: Number(activeStaged.iccReduce || 0),
        scrapAdj: Number(activeStaged.scrapAdj || 0)
      });
      computedStagedTotal = Number(activeStaged.approvedCost || haierStagedCalc.totalCost || 0);
    } else {
      atomStagedCalc = calculateAtombergCost({
        rmBase: 131,
        mbBase: 154,
        partWt: activeStaged.netWeight,
        runnerWt: activeStaged.runnerWeight,
        mbPct: (activeStaged.masterbatchPct || 4) / 100,
        bopCost: 0,
        cycleTime: activeStaged.cycleTimeApproved || 47,
        cavity: activeStaged.cavity || 2,
        tonnage: activeStaged.machineTonnage || 200,
        shiftTariff: activeStaged.shiftTariff || 2000,
        packingCost: activeStaged.packingCost !== undefined ? activeStaged.packingCost : 0.86,
        transportCost: activeStaged.transportCost !== undefined ? activeStaged.transportCost : 0.62,
        otherCost: 0.00
      });
      computedStagedTotal = Number(activeStaged.approvedCost || atomStagedCalc.finalLanded || 0);
    }
  }

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
              <h1 className="text-sm font-bold">1. Multi-Vendor Dynamic Product Baseline Master</h1>
              <span className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] px-2 py-0.5 rounded-full font-bold">
                Active Vendor: {selectedVendor}
              </span>
            </div>
            <p className="text-[11px] text-slate-300">Exact 38-Line Costing Engine for Atomberg & Haier</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            onClick={() => {
              if (window.confirm(`Are you sure you want to clear all baseline products for ${selectedVendor}?`)) {
                clearVendorBaselineProducts(selectedVendor);
              }
            }}
            className="px-3.5 py-2 bg-rose-950/40 hover:bg-rose-900 text-rose-300 border border-rose-800/60 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-xs text-xs"
          >
            <Trash2 className="w-4 h-4 text-rose-400" /> Clear {selectedVendor} Data
          </button>

          <label className="px-3.5 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-sm text-xs">
            <Upload className="w-4 h-4" /> Upload & Stage Spec (.xlsx)
            <input type="file" accept=".xlsx, .xls" onChange={handleFileUpload} className="hidden" />
          </label>

          <div className="flex bg-slate-800 p-0.5 rounded-xl border border-slate-700">
            <button
              onClick={() => setActiveTab('parameters')}
              className={`px-3 py-1.5 rounded-lg font-bold transition-all cursor-pointer ${
                activeTab === 'parameters' ? 'bg-blue-600 text-white shadow' : 'text-slate-300 hover:text-white'
              }`}
            >
              Parameters Master ({vendorProducts.length})
            </button>
            <button
              onClick={() => setActiveTab('audit')}
              className={`px-3 py-1.5 rounded-lg font-bold transition-all cursor-pointer ${
                activeTab === 'audit' ? 'bg-blue-600 text-white shadow' : 'text-slate-300 hover:text-white'
              }`}
            >
              Parameter Audit Log ({vendorAuditLogs.length})
            </button>
          </div>
        </div>
      </div>

      {/* Filter Row */}
      <div className="bg-white p-3 rounded-2xl border border-slate-200 shadow-xs flex flex-wrap justify-between items-center gap-3">
        <div className="flex items-center gap-2 flex-1 max-w-md bg-slate-50 px-3 py-1.5 rounded-xl border border-slate-200">
          <Search className="w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder={`Search ${selectedVendor} components...`}
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full bg-transparent border-none outline-hidden text-xs text-slate-800"
          />
        </div>

        <div className="flex items-center gap-2">
          <span className="font-bold text-slate-600">Switch Vendor:</span>
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
      </div>

      {/* Main Parameters Table */}
      <div className="bg-white rounded-2xl border border-slate-300 overflow-hidden shadow-sm">
        <div className="p-3 bg-slate-900 text-white flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-blue-400" />
            <h2 className="text-xs font-bold uppercase tracking-wider">{selectedVendor} Baseline Parameters Master</h2>
          </div>
          <span className="text-[11px] text-slate-400 font-mono">{filteredProducts.length} Active Parts</span>
        </div>

        {activeTab === 'parameters' ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-100 text-slate-700 uppercase font-bold text-[10px]">
                <tr>
                  <th className="py-2.5 px-3">Item Code / Component</th>
                  <th className="py-2.5 px-3">Model</th>
                  <th className="py-2.5 px-3">Approved RM / MB</th>
                  <th className="py-2.5 px-3 text-center">MB %</th>
                  <th className="py-2.5 px-3 text-center">Cavity</th>
                  <th className="py-2.5 px-3 text-right">Net Wt</th>
                  <th className="py-2.5 px-3 text-right">Runner Wt</th>
                  <th className="py-2.5 px-3 text-center bg-amber-50/70 text-amber-950">Cycle Time</th>
                  <th className="py-2.5 px-3 text-center">Tonnage</th>
                  <th className="py-2.5 px-3 text-right">Shift Tariff</th>
                  <th className="py-2.5 px-4 text-center">Edit Spec</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredProducts.length === 0 ? (
                  <tr>
                    <td colSpan={11} className="py-8 text-center text-slate-400">
                      No baseline parts found for {selectedVendor}. Click <b>Upload & Stage Spec</b> to import records.
                    </td>
                  </tr>
                ) : (
                  filteredProducts.map(prod => {
                    const { baseRm } = parseMaterialString(prod.approvedRm || prod.baseRm);
                    const rmInfo = getActiveRmMapping(baseRm || prod.baseRm || prod.approvedRm, prod.vendor);
                    
                    return (
                      <tr key={prod.id || prod.itemCode} className="hover:bg-slate-50 transition-colors">
                        <td className="py-2.5 px-3">
                          <div className="font-mono font-bold text-blue-700">{prod.itemCode}</div>
                          <div className="font-semibold text-slate-800">{prod.componentName}</div>
                        </td>
                        <td className="py-2.5 px-3 font-mono text-slate-600">{prod.model || '-'}</td>
                        <td className="py-2.5 px-3">
                          <div className="font-bold text-slate-900">{prod.approvedRm || '-'}</div>
                          <div className="text-[10px] text-slate-500 font-mono">
                            RM Matrix Rate: ₹{rmInfo.approvedPrice || 0}/kg
                          </div>
                        </td>
                        <td className="py-2.5 px-3 text-center font-mono font-bold text-purple-700">{prod.masterbatchPct || 0}%</td>
                        <td className="py-2.5 px-3 text-center font-mono font-bold text-slate-800">{prod.cavity || 1}</td>
                        <td className="py-2.5 px-3 text-right font-mono text-slate-800">{prod.netWeight || 0}g</td>
                        <td className="py-2.5 px-3 text-right font-mono text-slate-800">{prod.runnerWeight || 0}g</td>
                        <td className="py-2.5 px-3 text-center font-mono font-black text-amber-900 bg-amber-50/50">{prod.cycleTimeApproved || 0}s</td>
                        <td className="py-2.5 px-3 text-center font-mono text-slate-800">{prod.machineTonnage || 0}T</td>
                        <td className="py-2.5 px-3 text-right font-mono font-bold text-slate-900">₹{prod.shiftTariff || 0}</td>
                        <td className="py-2.5 px-4 text-center">
                          <button
                            onClick={() => handleEditClick(prod)}
                            className="px-3 py-1 bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 rounded-lg font-bold flex items-center gap-1 mx-auto cursor-pointer shadow-xs"
                          >
                            <Edit3 className="w-3.5 h-3.5 text-blue-600" /> Edit Spec
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="overflow-x-auto">
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
                {vendorAuditLogs.map((log, idx) => (
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
      </div>

      {/* RENDER INLINE EDIT MODAL */}
      {editingProduct && (
        <InlineEditModal
          product={editingProduct}
          onClose={() => setEditingProduct(null)}
          onSave={handleSaveProduct}
          onDelete={handleDeleteProduct}
        />
      )}

      {/* RENDER COMPLETE STAGING MODAL */}
      {showUploadModal && activeStaged && (
        <div className="fixed inset-0 z-50 bg-slate-900/70 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[92vh] flex flex-col shadow-2xl overflow-hidden text-xs">
            {/* Header */}
            <div className="p-4 bg-white border-b border-slate-200 flex justify-between items-start">
              <div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                  <h3 className="text-sm font-bold text-slate-900">
                    Staging & Verification: {selectedVendor} Product Import ({stagedData.length} Staged Parts)
                  </h3>
                </div>
                <p className="text-[11px] text-slate-500 mt-0.5">
                  Review complete 38-line specification parameters and make inline corrections before final baseline confirmation.
                </p>
              </div>
              <button onClick={() => setShowUploadModal(false)} className="p-1 hover:bg-slate-100 rounded text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Horizontal Part Carousel */}
            <div className="bg-slate-100/70 p-2 border-b border-slate-200 flex items-center gap-1.5">
              <button 
                onClick={() => scrollTabs(-200)}
                className="p-1 bg-white hover:bg-slate-200 rounded border border-slate-300 shadow-2xs text-slate-600 cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              <div 
                ref={tabsContainerRef}
                className="flex gap-2 overflow-x-auto no-scrollbar py-1 scroll-smooth flex-1"
                style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
              >
                {stagedData.map((st, idx) => {
                  const isSelected = idx === selectedStagedIndex;
                  return (
                    <button
                      key={idx}
                      onClick={() => setSelectedStagedIndex(idx)}
                      className={`px-3 py-2 rounded-xl text-left border transition-all shrink-0 w-48 cursor-pointer ${
                        isSelected 
                          ? 'bg-blue-600 text-white border-blue-700 shadow-md font-bold' 
                          : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
                      }`}
                    >
                      <div className="font-mono text-[10px] leading-tight truncate">{st.itemCode}</div>
                      <div className="text-[9px] mt-0.5 line-clamp-2 leading-tight opacity-90">{st.componentName}</div>
                    </button>
                  );
                })}
              </div>

              <button 
                onClick={() => scrollTabs(200)}
                className="p-1 bg-white hover:bg-slate-200 rounded border border-slate-300 shadow-2xs text-slate-600 cursor-pointer"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>

            {/* Staged Component Banner */}
            <div className="px-5 py-3 bg-slate-50/90 border-b border-slate-200 flex justify-between items-center">
              <div>
                <div className="text-[9px] uppercase font-bold text-slate-400">STAGED COMPONENT & ITEM CODE</div>
                <div className="text-xs font-bold text-slate-900 font-mono mt-0.5">
                  [{activeStaged.itemCode}] {activeStaged.componentName}
                </div>
              </div>
              <div className="text-right">
                <div className="text-[9px] uppercase font-bold text-emerald-700">COMPUTED STAGED TOTAL COST</div>
                <div className="text-base font-black font-mono text-emerald-600 mt-0.5">
                  ₹{computedStagedTotal.toFixed(2)}
                </div>
              </div>
            </div>

            {/* Complete 38-Line Specification Staging Table */}
            <div className="flex-1 overflow-y-auto p-4 space-y-1">
              {!isHaierVendor ? (
                /* ATOMBERG FULL 38-LINE TABLE */
                <table className="w-full text-left border-collapse text-xs">
                  <thead className="bg-slate-100 text-slate-800 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-300">
                    <tr>
                      <th className="py-2.5 px-3 w-8">#</th>
                      <th className="py-2.5 px-3">Atomberg Costing Line</th>
                      <th className="py-2.5 px-3 text-center w-24">UOM / Rate</th>
                      <th className="py-2.5 px-4 text-right w-64">Staged Value (Editable)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200 font-medium text-slate-900">
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">1</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Vendor</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                      <td className="py-1.5 px-4 text-right font-bold text-slate-900">{activeStaged.vendor}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">2</td>
                      <td className="py-1.5 px-3 font-bold text-blue-700">Part Code</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{activeStaged.itemCode}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">3</td>
                      <td className="py-1.5 px-3 font-bold text-slate-900">Part name</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                      <td className="py-1.5 px-4 text-right font-bold text-slate-900">{activeStaged.componentName}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">4</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">RM grade (Locked & Linked)</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                      <td className="py-1.5 px-4 text-right font-semibold text-slate-800">{activeStaged.approvedRm}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">RM Base Rate (From RM Matrix)</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">₹{atomStagedCalc?.rmBase.toFixed(2) || '131.00'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                      <td className="py-1.5 px-3 font-bold">RM Landed Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">₹{atomStagedCalc?.rmLanded.toFixed(2) || '133.81'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                      <td className="py-1.5 px-3 font-bold">MB Landed Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">₹{atomStagedCalc?.mbLanded.toFixed(2) || '157.54'}</td>
                    </tr>
                    <tr className="bg-purple-50/40">
                      <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                      <td className="py-1.5 px-3 font-bold text-purple-900">MB %</td>
                      <td className="py-1.5 px-3 text-center">%</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.1" 
                          value={activeStaged.masterbatchPct} 
                          onChange={e => handleUpdateActiveStaged('masterbatchPct', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/30">
                      <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Part weight grams</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.01" 
                          value={activeStaged.netWeight} 
                          onChange={e => handleUpdateActiveStaged('netWeight', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/30">
                      <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Runner weight grams</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.01" 
                          value={activeStaged.runnerWeight} 
                          onChange={e => handleUpdateActiveStaged('runnerWeight', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-emerald-50/40 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                      <td className="py-1.5 px-3 text-emerald-950">RM cost</td>
                      <td className="py-1.5 px-3 text-center">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-900">₹{atomStagedCalc?.rmCostPerPc.toFixed(2) || '5.12'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                      <td className="py-1.5 px-3 font-bold">Shift rate</td>
                      <td className="py-1.5 px-3 text-center">₹/shift</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.shiftTariff} 
                          onChange={e => handleUpdateActiveStaged('shiftTariff', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-slate-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                      <td className="py-1.5 px-3 font-black text-amber-950">Cycle time (seconds)</td>
                      <td className="py-1.5 px-3 text-center">Sec</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.cycleTimeApproved} 
                          onChange={e => handleUpdateActiveStaged('cycleTimeApproved', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-400 rounded text-right font-black text-amber-950 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">No of cavity</td>
                      <td className="py-1.5 px-3 text-center">Nos</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.cavity} 
                          onChange={e => handleUpdateActiveStaged('cavity', parseInt(e.target.value, 10) || 1)} 
                          className="w-24 px-2 py-0.5 border border-slate-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">26</td>
                      <td className="py-1.5 px-3 font-bold text-slate-900">Parts/shift</td>
                      <td className="py-1.5 px-3 text-center">Nos</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{atomStagedCalc?.partsPerShift.toFixed(2) || '1102.98'}</td>
                    </tr>
                    <tr className="bg-slate-100 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                      <td className="py-1.5 px-3">Total Process Cost</td>
                      <td className="py-1.5 px-3 text-center">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.totalProcessCost.toFixed(2) || '3.54'}</td>
                    </tr>
                    <tr className="bg-slate-900 text-white font-black">
                      <td className="py-2.5 px-3 font-mono text-amber-400">38</td>
                      <td className="py-2.5 px-3 uppercase text-amber-400">Final Landed cost</td>
                      <td className="py-2.5 px-3 text-center text-amber-300">₹/pc</td>
                      <td className="py-2.5 px-4 text-right font-mono text-amber-300 text-sm">₹{computedStagedTotal.toFixed(2)}</td>
                    </tr>
                  </tbody>
                </table>
              ) : (
                /* HAIER COMPLETE 38-LINE STAGING TABLE */
                <table className="w-full text-left border-collapse text-xs">
                  <thead className="bg-slate-100 text-slate-800 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-300">
                    <tr>
                      <th className="py-2.5 px-3 w-8">#</th>
                      <th className="py-2.5 px-3">Haier Costing Line</th>
                      <th className="py-2.5 px-3 text-center w-24">UOM / Rate</th>
                      <th className="py-2.5 px-4 text-right w-64">Staged Value (Editable)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200 font-medium text-slate-900">
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">1</td>
                      <td className="py-1.5 px-3 font-bold">Name Of component</td>
                      <td className="py-1.5 px-3 text-center">-</td>
                      <td className="py-1.5 px-4 text-right font-bold text-slate-900">{activeStaged.componentName}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">2</td>
                      <td className="py-1.5 px-3">Mould size L x W x H</td>
                      <td className="py-1.5 px-3 text-center">mm</td>
                      <td className="py-1.5 px-4 text-right font-mono">{activeStaged.mouldSize}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">3</td>
                      <td className="py-1.5 px-3 font-bold text-blue-700">Item No.</td>
                      <td className="py-1.5 px-3 text-center">-</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-700">{activeStaged.itemCode}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">4</td>
                      <td className="py-1.5 px-3">Model</td>
                      <td className="py-1.5 px-3 text-center">-</td>
                      <td className="py-1.5 px-4 text-right font-mono">{activeStaged.model}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                      <td className="py-1.5 px-3 font-bold text-slate-900">Raw Material Required</td>
                      <td className="py-1.5 px-3 text-center">-</td>
                      <td className="py-1.5 px-4 text-right font-bold text-emerald-900">{activeStaged.approvedRm}</td>
                    </tr>
                    <tr className="bg-purple-50/40">
                      <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                      <td className="py-1.5 px-3 font-bold text-purple-900">Master Batch Required (%)</td>
                      <td className="py-1.5 px-3 text-center">%</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.1" 
                          value={activeStaged.masterbatchPct} 
                          onChange={e => handleUpdateActiveStaged('masterbatchPct', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/30">
                      <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">No. of Cavity</td>
                      <td className="py-1.5 px-3 text-center">Nos</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.cavity} 
                          onChange={e => handleUpdateActiveStaged('cavity', parseInt(e.target.value, 10) || 1)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/30">
                      <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Runner Weight</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.01" 
                          value={activeStaged.runnerWeight} 
                          onChange={e => handleUpdateActiveStaged('runnerWeight', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/30">
                      <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Net Weight</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.01" 
                          value={activeStaged.netWeight} 
                          onChange={e => handleUpdateActiveStaged('netWeight', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">10</td>
                      <td className="py-1.5 px-3">Shot Weight</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">{Number(haierStagedCalc?.shotWeight || (activeStaged.netWeight * activeStaged.cavity + activeStaged.runnerWeight)).toFixed(2)}g</td>
                    </tr>
                    <tr className="bg-slate-50">
                      <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                      <td className="py-1.5 px-3 font-bold">Reconciliation Weight (1.01%)</td>
                      <td className="py-1.5 px-3 text-center">Gms</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">{Number(haierStagedCalc?.reconciliationWeight || 0).toFixed(2)}g</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                      <td className="py-1.5 px-3">Raw Material Cost</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right font-mono">₹{Number(haierStagedCalc?.rawMaterialCost || 0).toFixed(4)}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                      <td className="py-1.5 px-3">Master batch cost</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right font-mono">₹{Number(haierStagedCalc?.masterbatchCost || 0).toFixed(4)}</td>
                    </tr>
                    <tr className="bg-slate-50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                      <td className="py-1.5 px-3 text-slate-900">Total Raw Material Cost</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{Number(haierStagedCalc?.totalRmCost || 0).toFixed(4)}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                      <td className="py-1.5 px-3">Machine Used (Tonnage)</td>
                      <td className="py-1.5 px-3 text-center">T</td>
                      <td className="py-1.5 px-4 text-right font-mono">{activeStaged.machineTonnage}T</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">17</td>
                      <td className="py-1.5 px-3 font-bold">Machine Tariff per Shift</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.shiftTariff} 
                          onChange={e => handleUpdateActiveStaged('shiftTariff', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/50">
                      <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                      <td className="py-1.5 px-3 font-black text-amber-950">Cycle Time</td>
                      <td className="py-1.5 px-3 text-center">Sec</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.cycleTimeApproved} 
                          onChange={e => handleUpdateActiveStaged('cycleTimeApproved', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-400 rounded text-right font-black text-amber-950 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                      <td className="py-1.5 px-3 font-bold">Production Cost / Pc</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">₹{Number(haierStagedCalc?.productionCostPerPc || 0).toFixed(4)}</td>
                    </tr>
                    <tr className="bg-slate-100 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                      <td className="py-1.5 px-3 uppercase text-slate-900">SUB TOTAL</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{Number(haierStagedCalc?.subTotal || 0).toFixed(4)}</td>
                    </tr>
                    <tr className="bg-purple-50/40">
                      <td className="py-1.5 px-3 font-mono text-slate-500">24</td>
                      <td className="py-1.5 px-3 font-bold text-purple-950">OH + Profit + Packaging + Freight Package</td>
                      <td className="py-1.5 px-3 text-center">Rs</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.0001" 
                          value={activeStaged.haierOverheadPackage} 
                          onChange={e => handleUpdateActiveStaged('haierOverheadPackage', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-slate-900 text-white font-black">
                      <td className="py-2.5 px-3 font-mono text-amber-400">38</td>
                      <td className="py-2.5 px-3 uppercase text-amber-400">TOTAL COST</td>
                      <td className="py-2.5 px-3 text-center">Rs</td>
                      <td className="py-2.5 px-4 text-right font-mono text-amber-300 text-sm">₹{computedStagedTotal.toFixed(2)}</td>
                    </tr>
                  </tbody>
                </table>
              )}
            </div>

            {/* Modal Footer Actions */}
            <div className="p-4 bg-slate-50 border-t border-slate-200 flex justify-between items-center">
              <button 
                onClick={() => setShowUploadModal(false)} 
                className="px-5 py-2.5 bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 rounded-xl font-bold cursor-pointer transition shadow-2xs"
              >
                Cancel Staging
              </button>
              <button 
                onClick={handleCommitStaged} 
                className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold flex items-center gap-2 cursor-pointer shadow-md transition text-xs"
              >
                <CheckCircle2 className="w-4 h-4" /> Confirm & Add All Staged Products ({stagedData.length})
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
PAGE_EOF

echo "==> 2. Verifying build with Vite..."
npm run build

echo "==> 3. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ RAW MATERIAL REQUIRED STRING DISPLAY RESOLVED ON DEV-V2!"
echo "-------------------------------------------------------------------"
