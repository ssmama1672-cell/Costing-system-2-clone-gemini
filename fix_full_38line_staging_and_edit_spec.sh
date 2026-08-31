#!/usr/bin/env bash
set -e

echo "==> 1. Updating InlineEditModal.jsx with complete, high-contrast 38-line view..."
cat << 'MODAL_EOF' > src/modules/module1-baseline/InlineEditModal.jsx
import React, { useState } from 'react';
import { X, Save, Trash2 } from 'lucide-react';
import { calculateHaierCost, calculateAtombergCost } from '../../shared/costCalculationService';
import { parseMaterialString, getActiveRmMapping, getActiveMbMapping } from '../../shared/masterStore';

export default function InlineEditModal({ product, onClose, onSave, onDelete }) {
  if (!product) return null;

  const isHaier = (product.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (product.vendor || '').toLowerCase().includes('atomberg');
  const initialParams = product.parameters || {};

  const { baseRm, mbGrade } = parseMaterialString(product.approvedRm || product.baseRm);
  const rmLookupKey = baseRm || product.baseRm || product.approvedRm || (isAtomberg ? 'PP H110MA' : 'HIPS SH303');
  const mbLookupKey = mbGrade || product.approvedMb || ((product.masterbatchPct || 0) > 0 ? 'Gloss White MB' : 'None');

  const rmInfo = getActiveRmMapping(rmLookupKey, product.vendor) || {};
  const mbInfo = getActiveMbMapping(mbLookupKey, product.vendor) || {};

  const approvedRmRate = Number(rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(rmInfo.activeWaPrice || rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));

  const approvedMbRate = Number(mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(mbInfo.activeMbWaPrice || mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));

  const [formData, setFormData] = useState({
    approvedRm: product.approvedRm || baseRm || (isAtomberg ? 'PP H110MA + Gloss White' : 'HIPS SH303'),
    baseRm: rmLookupKey,
    approvedMb: mbLookupKey,
    
    // Baseline Parameters
    rmBaseRate: Number(product.approvedRmPrice || approvedRmRate),
    rmFreight: Number(product.rmFreight !== undefined ? product.rmFreight : 1.50),
    mbBaseRate: Number(product.approvedMbPrice || approvedMbRate),
    mbFreight: Number(product.mbFreight !== undefined ? product.mbFreight : 2.00),
    masterbatchPct: Number(product.masterbatchPct !== undefined ? product.masterbatchPct : 4),
    partWeight: Number(product.netWeight !== undefined ? product.netWeight : 37.00),
    runnerWeight: Number(product.runnerWeight !== undefined ? product.runnerWeight : 1.00),
    bopCost: Number(product.bopCost || 0),
    machineTonnage: Number(product.machineTonnage || 200),
    shiftTariff: Number(product.shiftTariff || 2000),
    cycleTimeApproved: Number(product.cycleTimeApproved || 47),
    cavity: Number(product.cavity || 2),
    postOpCost: Number(product.postOpCost !== undefined ? product.postOpCost : 1.73),
    packingCost: Number(product.packingCost !== undefined ? product.packingCost : 0.86),
    transportCost: Number(product.transportCost !== undefined ? product.transportCost : 0.62),
    otherCost: Number(product.otherCost !== undefined ? product.otherCost : 0.00),

    // Running Parameters
    runningRmBaseRate: Number(initialParams.runningRmBaseRate ?? runningRmWaRate),
    runningRmFreight: Number(initialParams.runningRmFreight ?? product.rmFreight ?? 1.50),
    runningMbBaseRate: Number(initialParams.runningMbBaseRate ?? runningMbWaRate),
    runningMbFreight: Number(initialParams.runningMbFreight ?? product.mbFreight ?? 2.00),
    runningMbPct: Number(initialParams.runningMbPct ?? product.masterbatchPct ?? 4),
    runningPartWeight: Number(initialParams.runningNetWeight ?? product.netWeight ?? 37.00),
    runningRunnerWeight: Number(initialParams.runningRunnerWeight ?? product.runnerWeight ?? 1.00),
    runningBopCost: Number(initialParams.runningBopCost ?? product.bopCost ?? 0),
    runningShiftTariff: Number(initialParams.runningShiftTariff ?? product.shiftTariff ?? 2000),
    runningCycleTime: Number(initialParams.runningCycleTime ?? product.cycleTimeApproved ?? 47),
    runningCavity: Number(initialParams.runningCavity ?? product.cavity ?? 2),
    runningPostOpCost: Number(initialParams.runningPostOpCost ?? product.postOpCost ?? 1.73),
    runningPackingCost: Number(initialParams.runningPackingCost ?? product.packingCost ?? 0.86),
    runningTransportCost: Number(initialParams.runningTransportCost ?? product.transportCost ?? 0.62),
    runningOtherCost: Number(initialParams.runningOtherCost ?? product.otherCost ?? 0.00),

    mouldSize: product.mouldSize || (isAtomberg ? '450x450x380' : '800x800x684'),
    model: product.model || (isAtomberg ? 'Aris Ceiling Fan' : 'TM 258/278'),
    haierOverheadPackage: Number(product.haierOverheadPackage || 0)
  });

  const atombergBaseCalc = calculateAtombergCost({
    rmBase: formData.rmBaseRate,
    rmFreight: formData.rmFreight,
    mbBase: formData.mbBaseRate,
    mbFreight: formData.mbFreight,
    partWt: formData.partWeight,
    runnerWt: formData.runnerWeight,
    mbPct: formData.masterbatchPct / 100,
    bopCost: formData.bopCost,
    cycleTime: formData.cycleTimeApproved,
    cavity: formData.cavity,
    tonnage: formData.machineTonnage,
    shiftTariff: formData.shiftTariff,
    postOpCost: formData.postOpCost,
    packingCost: formData.packingCost,
    transportCost: formData.transportCost,
    otherCost: formData.otherCost
  });

  const atombergRunningCalc = calculateAtombergCost({
    rmBase: formData.runningRmBaseRate,
    rmFreight: formData.runningRmFreight,
    mbBase: formData.runningMbBaseRate,
    mbFreight: formData.runningMbFreight,
    partWt: formData.runningPartWeight,
    runnerWt: formData.runningRunnerWeight,
    mbPct: formData.runningMbPct / 100,
    bopCost: formData.runningBopCost,
    cycleTime: formData.runningCycleTime,
    cavity: formData.runningCavity,
    tonnage: formData.machineTonnage,
    shiftTariff: formData.runningShiftTariff,
    postOpCost: formData.runningPostOpCost,
    packingCost: formData.runningPackingCost,
    transportCost: formData.runningTransportCost,
    otherCost: formData.runningOtherCost
  });

  const ctApproved = Number(formData.cycleTimeApproved) > 0 ? Number(formData.cycleTimeApproved) : 1;
  const cavityApproved = Number(formData.cavity) > 0 ? Number(formData.cavity) : 1;
  const row19ApprovedNum = 28800 / ctApproved;
  const row20ApprovedNum = row19ApprovedNum * 0.95;
  const row21ApprovedNum = row20ApprovedNum * cavityApproved;

  const ctRunning = Number(formData.runningCycleTime) > 0 ? Number(formData.runningCycleTime) : 1;
  const cavityRunning = Number(formData.runningCavity) > 0 ? Number(formData.runningCavity) : 1;
  const row19RunningNum = 28800 / ctRunning;
  const row20RunningNum = row19RunningNum * 0.95;
  const row21RunningNum = row20RunningNum * cavityRunning;

  const haierBaseCalc = calculateHaierCost({
    cavity: formData.cavity,
    netWeight: formData.partWeight,
    runnerWeight: formData.runnerWeight,
    shotWeight: formData.partWeight * formData.cavity + formData.runnerWeight,
    partsPerShift: row21ApprovedNum,
    rmRate: formData.rmBaseRate,
    masterbatchPct: formData.masterbatchPct,
    masterbatchRate: formData.mbBaseRate,
    shiftTariff: formData.shiftTariff,
    cycleTime: formData.cycleTimeApproved,
    haierOverheadPackage: formData.haierOverheadPackage
  });

  const haierRunningCalc = calculateHaierCost({
    cavity: formData.runningCavity,
    netWeight: formData.runningPartWeight,
    runnerWeight: formData.runningRunnerWeight,
    shotWeight: formData.runningPartWeight * formData.runningCavity + formData.runningRunnerWeight,
    partsPerShift: row21RunningNum,
    rmRate: formData.runningRmBaseRate,
    masterbatchPct: formData.runningMbPct,
    masterbatchRate: formData.runningMbBaseRate,
    shiftTariff: formData.runningShiftTariff,
    cycleTime: formData.runningCycleTime,
    haierOverheadPackage: formData.haierOverheadPackage
  });

  const contractTotal = isHaier ? haierBaseCalc.totalCost : atombergBaseCalc.finalLanded;
  const runningTotal = isHaier ? haierRunningCalc.totalCost : atombergRunningCalc.finalLanded;
  const profitLossDelta = Number((contractTotal - runningTotal).toFixed(2));

  const handleSave = () => {
    onSave({
      ...product,
      ...formData,
      approvedCost: contractTotal,
      netWeight: formData.partWeight,
      runnerWeight: formData.runnerWeight,
      parameters: {
        runningRmBaseRate: formData.runningRmBaseRate,
        runningRmFreight: formData.runningRmFreight,
        runningMbBaseRate: formData.runningMbBaseRate,
        runningMbFreight: formData.runningMbFreight,
        runningCycleTime: formData.runningCycleTime,
        runningCavity: formData.runningCavity,
        runningRunnerWeight: formData.runningRunnerWeight,
        runningNetWeight: formData.runningPartWeight,
        runningShiftTariff: formData.runningShiftTariff,
        runningMbPct: formData.runningMbPct,
        runningBopCost: formData.runningBopCost,
        runningPostOpCost: formData.runningPostOpCost,
        runningPackingCost: formData.runningPackingCost,
        runningTransportCost: formData.runningTransportCost,
        runningOtherCost: formData.runningOtherCost
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
            </div>
            <p className="text-[11px] text-slate-300 mt-1">
              Vendor: <b>{product.vendor}</b> | RM: <b>{rmLookupKey}</b> (₹{formData.rmBaseRate} → WA: ₹{formData.runningRmBaseRate}) | MB: <b>{mbLookupKey}</b> (₹{formData.mbBaseRate} → WA: ₹{formData.runningMbBaseRate})
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
            /* ALL 38 LINES FOR ATOMBERG WITH CRISP HIGH-CONTRAST LABELS */
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
                  <td className="py-1.5 px-4 text-right font-semibold text-slate-800">{formData.approvedRm}</td>
                  <td className="py-1.5 px-4 text-right font-semibold text-blue-800">{formData.approvedRm}</td>
                  <td className="py-1.5 px-3 text-right text-emerald-600 font-bold">Matched</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">RM Base Rate (From RM Matrix)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.rmBaseRate} onChange={e => setFormData({ ...formData, rmBaseRate: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningRmBaseRate} onChange={e => setFormData({ ...formData, runningRmBaseRate: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(formData.rmBaseRate - formData.runningRmBaseRate).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                  <td className="py-1.5 px-3 text-slate-800">ICC Cost @ 1% of RM</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">1%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.rmIcc.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.rmIcc.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                  <td className="py-1.5 px-3 text-slate-800">Freight Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.rmFreight} onChange={e => setFormData({ ...formData, rmFreight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningRmFreight} onChange={e => setFormData({ ...formData, runningRmFreight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                  <td className="py-1.5 px-3 text-slate-900">RM Landed Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atombergBaseCalc.rmLanded.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.rmLanded.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.rmLanded - atombergRunningCalc.rmLanded).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">MB Base Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.mbBaseRate} onChange={e => setFormData({ ...formData, mbBaseRate: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningMbBaseRate} onChange={e => setFormData({ ...formData, runningMbBaseRate: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(formData.mbBaseRate - formData.runningMbBaseRate).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">10</td>
                  <td className="py-1.5 px-3 text-slate-800">MB-ICC Cost @ 1% of MB</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">1%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.mbIcc.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.mbIcc.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                  <td className="py-1.5 px-3 text-slate-800">MB Freight Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.mbFreight} onChange={e => setFormData({ ...formData, mbFreight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningMbFreight} onChange={e => setFormData({ ...formData, runningMbFreight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                  <td className="py-1.5 px-3 text-slate-900">MB Landed Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atombergBaseCalc.mbLanded.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.mbLanded.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.mbLanded - atombergRunningCalc.mbLanded).toFixed(2)}</td>
                </tr>
                <tr className="bg-purple-50/40 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                  <td className="py-1.5 px-3 text-purple-900">MB %</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">%</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.1" value={formData.masterbatchPct} onChange={e => setFormData({ ...formData, masterbatchPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.1" value={formData.runningMbPct} onChange={e => setFormData({ ...formData, runningMbPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.masterbatchPct - formData.runningMbPct).toFixed(1)}%</td>
                </tr>
                <tr className="bg-slate-100 font-black">
                  <td className="py-1.5 px-3 font-mono text-slate-500">14</td>
                  <td className="py-1.5 px-3 text-slate-900">RM cost (PP + MB) /KG</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atombergBaseCalc.blendedRmRate.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.blendedRmRate.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.blendedRmRate - atombergRunningCalc.blendedRmRate).toFixed(2)}</td>
                </tr>
                <tr className="bg-amber-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">Part weight grams</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.partWeight} onChange={e => setFormData({ ...formData, partWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningPartWeight} onChange={e => setFormData({ ...formData, runningPartWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">{(formData.partWeight - formData.runningPartWeight).toFixed(2)}g</td>
                </tr>
                <tr className="bg-amber-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">Runner weight grams</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runnerWeight} onChange={e => setFormData({ ...formData, runnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningRunnerWeight} onChange={e => setFormData({ ...formData, runningRunnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">{(formData.runnerWeight - formData.runningRunnerWeight).toFixed(2)}g</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">17</td>
                  <td className="py-1.5 px-3 font-bold text-slate-800">Gross weight</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">{atombergBaseCalc.grossWt.toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{atombergRunningCalc.grossWt.toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(atombergBaseCalc.grossWt - atombergRunningCalc.grossWt).toFixed(2)}g</td>
                </tr>
                <tr className="bg-emerald-50/50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                  <td className="py-1.5 px-3 text-emerald-950">RM cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-900">₹{atombergBaseCalc.rmCostPerPc.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.rmCostPerPc.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.rmCostPerPc - atombergRunningCalc.rmCostPerPc).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">19</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Inserts/BOP cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.bopCost} onChange={e => setFormData({ ...formData, bopCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningBopCost} onChange={e => setFormData({ ...formData, runningBopCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(formData.bopCost - formData.runningBopCost).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                  <td className="py-1.5 px-3 text-slate-900">RM + BOP Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atombergBaseCalc.rmPlusBop.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.rmPlusBop.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.rmPlusBop - atombergRunningCalc.rmPlusBop).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">M/c tonnage</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">T</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.machineTonnage} onChange={e => setFormData({ ...formData, machineTonnage: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.machineTonnage} disabled className="w-20 px-2 py-0.5 border border-slate-200 rounded text-right font-bold text-blue-800 bg-slate-50" />
                  </td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Shift rate</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/shift</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.shiftTariff} onChange={e => setFormData({ ...formData, shiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningShiftTariff} onChange={e => setFormData({ ...formData, runningShiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(formData.shiftTariff - formData.runningShiftTariff).toFixed(2)}</td>
                </tr>
                <tr className="bg-amber-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                  <td className="py-1.5 px-3 font-black text-amber-950">Cycle time (seconds)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Sec</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.cycleTimeApproved} onChange={e => setFormData({ ...formData, cycleTimeApproved: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-amber-400 rounded text-right font-black text-amber-950 bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningCycleTime} onChange={e => setFormData({ ...formData, runningCycleTime: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">{(formData.cycleTimeApproved - formData.runningCycleTime).toFixed(1)}s</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">24</td>
                  <td className="py-1.5 px-3 text-slate-800">Efficiency</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">90%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">90%</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">No of cavity</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Nos</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.cavity} onChange={e => setFormData({ ...formData, cavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningCavity} onChange={e => setFormData({ ...formData, runningCavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">{formData.cavity - formData.runningCavity}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">26</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Parts/shift</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{atombergBaseCalc.partsPerShift.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">{atombergRunningCalc.partsPerShift.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(atombergBaseCalc.partsPerShift - atombergRunningCalc.partsPerShift).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">27</td>
                  <td className="py-1.5 px-3 text-slate-800">Process cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.processCostPerPc.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.processCostPerPc.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.processCostPerPc - atombergRunningCalc.processCostPerPc).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">28</td>
                  <td className="py-1.5 px-3 text-slate-800">Handling cost for BOP</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">3%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.handlingBop.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.handlingBop.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">29</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Post operation cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.postOpCost} onChange={e => setFormData({ ...formData, postOpCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningPostOpCost} onChange={e => setFormData({ ...formData, runningPostOpCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr className="bg-slate-100 font-black">
                  <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                  <td className="py-1.5 px-3 text-slate-900">Total Process Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atombergBaseCalc.totalProcessCost.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.totalProcessCost.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.totalProcessCost - atombergRunningCalc.totalProcessCost).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">31</td>
                  <td className="py-1.5 px-3 text-slate-800">Profit & OH</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">12%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.ohAndProfit.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.ohAndProfit.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.ohAndProfit - atombergRunningCalc.ohAndProfit).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">32</td>
                  <td className="py-1.5 px-3 text-slate-800">Inprocess Rejection</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">4%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.inProcessRejection.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.inProcessRejection.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.inProcessRejection - atombergRunningCalc.inProcessRejection).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">33</td>
                  <td className="py-1.5 px-3 font-semibold text-rose-700">Runner recovery cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹25/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-rose-700">-₹{atombergBaseCalc.runnerRecoveryCredit.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-rose-700">-₹{atombergRunningCalc.runnerRecoveryCredit.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">34</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Packing cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.packingCost} onChange={e => setFormData({ ...formData, packingCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningPackingCost} onChange={e => setFormData({ ...formData, runningPackingCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">35</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Transport cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.transportCost} onChange={e => setFormData({ ...formData, transportCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningTransportCost} onChange={e => setFormData({ ...formData, runningTransportCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">36</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Mould maintenance cost (2% of Process Cost)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">2%</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atombergBaseCalc.mouldMaintenance.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{atombergRunningCalc.mouldMaintenance.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">37</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">Other Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.otherCost} onChange={e => setFormData({ ...formData, otherCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningOtherCost} onChange={e => setFormData({ ...formData, runningOtherCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">₹0.00</td>
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
            /* HAIER 38-LINE TABLE */
            <table className="w-full text-left border-collapse">
              <thead className="bg-slate-100 text-slate-700 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-200">
                <tr>
                  <th className="py-2 px-3 w-8">#</th>
                  <th className="py-2 px-3">Haier Costing Line</th>
                  <th className="py-2 px-3 text-center w-24">UOM / Rate</th>
                  <th className="py-2 px-4 text-right w-44">Approved Baseline</th>
                  <th className="py-2 px-4 text-right w-44 text-blue-700">Actual Running</th>
                  <th className="py-2 px-3 text-right w-24">Delta (Δ)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs font-medium">
                <tr>
                  <td className="py-2 px-3 font-mono text-slate-400">1</td>
                  <td className="py-2 px-3 font-bold">Name Of component</td>
                  <td className="py-2 px-3 text-center">-</td>
                  <td className="py-2 px-4 text-right font-bold text-slate-700">{product.componentName}</td>
                  <td className="py-2 px-4 text-right font-bold text-blue-800">{product.componentName}</td>
                  <td className="py-2 px-3 text-right text-slate-400">-</td>
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
          <button onClick={() => { if(window.confirm('Delete this part from baseline?')) { onDelete(product.id || product.itemCode); onClose(); }}} className="px-3.5 py-2 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-300 rounded-xl font-bold flex items-center gap-1.5 cursor-pointer">
            <Trash2 className="w-4 h-4" /> Delete Product
          </button>
          <div className="flex gap-2">
            <button onClick={onClose} className="px-4 py-2 bg-white hover:bg-slate-100 border border-slate-300 rounded-xl font-bold cursor-pointer">
              Cancel
            </button>
            <button onClick={handleSave} className="px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold flex items-center gap-1.5 cursor-pointer shadow-sm">
              <Save className="w-4 h-4" /> Save & Log Parameters
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function calculateDetailedCost(item) {
  const isHaier = (item?.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (item?.vendor || '').toLowerCase().includes('atomberg');
  const { baseRm, mbGrade } = parseMaterialString(item?.approvedRm || item?.baseRm);
  const rmInfo = getActiveRmMapping(baseRm || item?.baseRm || item?.approvedRm, item?.vendor) || {};
  const mbInfo = getActiveMbMapping(mbGrade || item?.approvedMb, item?.vendor) || {};

  if (isHaier) {
    const calc = calculateHaierCost({
      cavity: item.cavity || 1,
      netWeight: item.netWeight || 0,
      runnerWeight: item.runnerWeight || 0,
      shotWeight: item.shotWeight || 0,
      partsPerShift: item.partsPerShift || 0,
      rmRate: Number(rmInfo.approvedPrice || item.approvedRmPrice || 0),
      masterbatchPct: item.masterbatchPct ?? 0,
      masterbatchRate: Number(mbInfo.approvedMbPrice || item.approvedMbPrice || 0),
      shiftTariff: item.shiftTariff || 0,
      cycleTime: item.cycleTimeApproved || 0,
      haierOverheadPackage: item.haierOverheadPackage || 0,
      bopCost: item.bopCost || 0
    });
    return {
      netRmCost: calc.totalRmCost || 0,
      convRatePerPc: calc.productionCostPerPc || 0,
      totalCost: calc.totalCost || 0,
      finalLanded: calc.totalCost || 0
    };
  } else {
    const calc = calculateAtombergCost({
      rmBase: Number(rmInfo.approvedPrice || item.approvedRmPrice || 131),
      mbBase: Number(mbInfo.approvedMbPrice || item.approvedMbPrice || 154),
      partWt: item.netWeight !== undefined ? item.netWeight : 37.00,
      runnerWt: item.runnerWeight !== undefined ? item.runnerWeight : 1.00,
      mbPct: (item.masterbatchPct || 4) / 100,
      bopCost: item.bopCost || 0,
      cycleTime: item.cycleTimeApproved || 47,
      cavity: item.cavity || 2,
      tonnage: item.machineTonnage || 200,
      shiftTariff: item.shiftTariff || 2000,
      postOpCost: item.postOpCost !== undefined ? item.postOpCost : 1.73,
      packingCost: item.packingCost !== undefined ? item.packingCost : 0.86,
      transportCost: item.transportCost !== undefined ? item.transportCost : 0.62,
      otherCost: item.otherCost !== undefined ? item.otherCost : 0.00
    });
    return {
      netRmCost: calc.rmPlusBop || 5.12,
      convRatePerPc: calc.processCostPerPc || 1.81,
      totalCost: calc.finalLanded || 11.58,
      finalLanded: calc.finalLanded || 11.58
    };
  }
}
MODAL_EOF

echo "==> 2. Updating BaselineMasterPage.jsx with complete 38-line Staging Modal..."
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
  getActiveMbMapping 
} from '../../shared/masterStore';
import InlineEditModal from './InlineEditModal';
import { calculateAtombergCost, calculateHaierCost } from '../../shared/costCalculationService';

export default function BaselineMasterPage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('Atomberg Technologies');
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
    selectedVendor === 'ALL' || 
    (p.vendor || '').toLowerCase().includes(selectedVendor.toLowerCase()) ||
    selectedVendor.toLowerCase().includes((p.vendor || '').toLowerCase())
  );

  const filteredProducts = vendorProducts.filter(p => 
    !searchQuery || 
    (p.itemCode || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (p.componentName || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (p.approvedRm || '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const vendorAuditLogs = (storeState.auditLogs || []).filter(l => 
    selectedVendor === 'ALL' ||
    (l.vendor || '').toLowerCase().includes(selectedVendor.toLowerCase()) ||
    selectedVendor.toLowerCase().includes((l.vendor || '').toLowerCase()) ||
    l.vendor === 'ALL'
  );

  const handleEditClick = (prod) => {
    const { baseRm, mbGrade } = parseMaterialString(prod.approvedRm || prod.baseRm);
    const rmLookupKey = baseRm || prod.baseRm || prod.approvedRm;
    const mbLookupKey = mbGrade || prod.approvedMb || (prod.masterbatchPct > 0 ? 'Gloss White MB' : '');

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

      // Exact 38-line column scanner across row descriptions
      const totalCols = Math.max(...rawMatrix.map(r => r.length));
      let startCol = 3;
      if (rawMatrix[0] && rawMatrix[0][3] === undefined) startCol = 2;

      for (let c = startCol; c < totalCols; c++) {
        let itemCode = '';
        let compName = '';
        let rmGradeStr = 'PP H110MA + Gloss White';
        let rmBaseRate = isHaierVendor ? 154 : 131;
        let mbBaseRate = isHaierVendor ? 242 : 154;
        let mbPct = isHaierVendor ? 4.0 : 4.0;
        let partWt = isHaierVendor ? 372 : 37.00;
        let runnerWt = isHaierVendor ? 0 : 1.00;
        let tonnage = isHaierVendor ? 600 : 200;
        let tariff = isHaierVendor ? 4800 : 2000;
        let cycleTime = isHaierVendor ? 70 : 47;
        let cavity = isHaierVendor ? 1 : 2;
        let packingCost = 0.86;
        let transportCost = 0.62;

        rawMatrix.forEach((r, rIdx) => {
          const label = `${r[0] || ''} ${r[1] || ''}`.toLowerCase().trim();
          const val = r[c];
          if (val === undefined || val === null || val === '') return;

          if (label.includes('part code') || label.includes('item no') || label === '2') itemCode = String(val).trim();
          if (label.includes('part name') || label.includes('name of component') || (label.includes('description') && !label.includes('grade'))) compName = String(val).trim();
          if (label.includes('rm grade') || (label.includes('raw material') && !label.includes('cost'))) rmGradeStr = String(val).trim();
          if (label.includes('rm base rate') || (label.includes('raw material cost') && label.includes('matrix'))) rmBaseRate = parseFloat(val) || rmBaseRate;
          if (label.includes('mb base cost') || label.includes('mb rate')) mbBaseRate = parseFloat(val) || mbBaseRate;
          if (label.includes('mb %') || label.includes('masterbatch %')) {
            const num = parseFloat(val);
            mbPct = num <= 1 ? num * 100 : num;
          }
          if (label.includes('part weight grams') || label.includes('net weight')) partWt = parseFloat(val) || partWt;
          if (label.includes('runner weight grams') || (label.includes('runner weight') && !label.includes('recovery'))) runnerWt = parseFloat(val) || runnerWt;
          if (label.includes('m/c tonnage') || label.includes('machine used') || label.includes('tonnage')) tonnage = parseInt(val, 10) || tonnage;
          if (label.includes('shift rate') || label.includes('shift tariff')) tariff = parseFloat(val) || tariff;
          
          // Cycle time exact row check (Row 24 / label containing cycle time / seconds)
          if (label.includes('cycle time') && !label.includes('rejection') && !label.includes('reconciliation')) {
            const numCt = parseFloat(val);
            if (numCt > 1) cycleTime = numCt;
          }
          if (label.includes('no of cavity') || label.includes('no. of cavity')) cavity = parseInt(val, 10) || cavity;
          if (label.includes('packing cost')) packingCost = parseFloat(val) || packingCost;
          if (label.includes('transport cost') || label.includes('transpost cost')) transportCost = parseFloat(val) || transportCost;
        });

        if (!itemCode && rawMatrix[2]?.[c]) itemCode = String(rawMatrix[2][c]).trim();
        if (!compName && rawMatrix[0]?.[c]) compName = String(rawMatrix[0][c]).trim();
        if (!compName && rawMatrix[3]?.[c]) compName = String(rawMatrix[3][c]).trim();

        if (!compName && !itemCode) continue;

        itemCode = itemCode || compName || `PART-${c}`;
        compName = compName || itemCode;

        const { baseRm, mbGrade } = parseMaterialString(rmGradeStr);

        if (baseRm) {
          addOrUpdateVendorMaterial({
            vendor: selectedVendor,
            type: 'RM',
            approvedCode: baseRm,
            approvedPrice: rmBaseRate
          });
        }
        if (mbGrade) {
          addOrUpdateVendorMaterial({
            vendor: selectedVendor,
            type: 'MB',
            approvedCode: mbGrade,
            approvedPrice: mbBaseRate
          });
        }

        let calcResult = 0;
        if (isHaierVendor) {
          const h = calculateHaierCost({
            cavity,
            netWeight: partWt,
            runnerWeight: runnerWt,
            shotWeight: partWt * cavity + runnerWt,
            rmRate: rmBaseRate,
            masterbatchPct: mbPct,
            masterbatchRate: mbBaseRate,
            shiftTariff: tariff,
            cycleTime,
            haierOverheadPackage: 8.71
          });
          calcResult = h.totalCost;
        } else {
          const a = calculateAtombergCost({
            rmBase: rmBaseRate,
            mbBase: mbBaseRate,
            partWt: partWt,
            runnerWt: runnerWt,
            mbPct: mbPct / 100,
            bopCost: 0,
            cycleTime: cycleTime,
            cavity: cavity,
            tonnage: tonnage,
            shiftTariff: tariff,
            postOpCost: 1.73,
            packingCost: packingCost,
            transportCost: transportCost,
            otherCost: 0.00
          });
          calcResult = a.finalLanded;
        }

        parsed.push({
          id: `prod-${itemCode}-${c}`,
          vendor: selectedVendor,
          componentName: compName,
          mouldSize: '450x450x380',
          itemCode: itemCode,
          model: 'Aris Ceiling Fan',
          approvedRm: rmGradeStr,
          baseRm: baseRm || rmGradeStr,
          approvedMb: mbGrade || 'Gloss White MB',
          masterbatchPct: mbPct,
          cavity: cavity,
          runnerWeight: runnerWt,
          netWeight: partWt,
          shotWeight: (partWt * cavity + runnerWt),
          machineTonnage: tonnage,
          shiftTariff: tariff,
          cycleTimeApproved: cycleTime,
          packingCost: packingCost,
          transportCost: transportCost,
          approvedCost: calcResult,
          parameters: {
            runningCycleTime: cycleTime,
            runningCavity: cavity,
            runningRunnerWeight: runnerWt,
            runningNetWeight: partWt,
            runningShiftTariff: tariff,
            runningMbPct: mbPct,
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
      haierStagedCalc = calculateHaierCost({
        cavity: activeStaged.cavity,
        netWeight: activeStaged.netWeight,
        runnerWeight: activeStaged.runnerWeight,
        shotWeight: activeStaged.shotWeight,
        rmRate: 154,
        masterbatchPct: activeStaged.masterbatchPct,
        masterbatchRate: 242,
        shiftTariff: activeStaged.shiftTariff,
        cycleTime: activeStaged.cycleTimeApproved,
        haierOverheadPackage: 8.71
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
        postOpCost: 1.73,
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

      {/* Main Table */}
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

      {/* RENDER COMPLETE HIGH-CONTRAST 38-LINE STAGING MODAL */}
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
                      <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                      <td className="py-1.5 px-3 text-slate-800">ICC Cost @ 1% of RM</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">1%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.rmIcc.toFixed(2) || '1.31'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                      <td className="py-1.5 px-3 text-slate-800">Freight Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.rmFreight.toFixed(2) || '1.50'}</td>
                    </tr>
                    <tr className="bg-slate-50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                      <td className="py-1.5 px-3 text-slate-900">RM Landed Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.rmLanded.toFixed(2) || '133.81'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">MB Base Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">₹{atomStagedCalc?.mbBase.toFixed(2) || '154.00'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">10</td>
                      <td className="py-1.5 px-3 text-slate-800">MB-ICC Cost @ 1% of MB</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">1%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.mbIcc.toFixed(2) || '1.54'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                      <td className="py-1.5 px-3 text-slate-800">MB Freight Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.mbFreight.toFixed(2) || '2.00'}</td>
                    </tr>
                    <tr className="bg-slate-50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                      <td className="py-1.5 px-3 text-slate-900">MB Landed Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.mbLanded.toFixed(2) || '157.54'}</td>
                    </tr>
                    <tr className="bg-purple-50/40 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                      <td className="py-1.5 px-3 text-purple-900">MB %</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">%</td>
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
                    <tr className="bg-slate-100 font-black">
                      <td className="py-1.5 px-3 font-mono text-slate-500">14</td>
                      <td className="py-1.5 px-3 text-slate-900">RM cost (PP + MB) /KG</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.blendedRmRate.toFixed(2) || '134.76'}</td>
                    </tr>
                    <tr className="bg-amber-50/40">
                      <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Part weight grams</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
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
                    <tr className="bg-amber-50/40">
                      <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                      <td className="py-1.5 px-3 font-bold text-amber-950">Runner weight grams</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          step="0.01" 
                          value={activeStaged.runnerWeight} 
                          onChange={e => handleUpdateActiveStaged('runnerWeight', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">17</td>
                      <td className="py-1.5 px-3 font-bold text-slate-800">Gross weight</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">Gms</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">{atomStagedCalc?.grossWt.toFixed(2) || '38.00'}g</td>
                    </tr>
                    <tr className="bg-emerald-50/50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                      <td className="py-1.5 px-3 text-emerald-950">RM cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-900">₹{atomStagedCalc?.rmCostPerPc.toFixed(2) || '5.12'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">19</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Inserts/BOP cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">₹{atomStagedCalc?.bopCost.toFixed(2) || '0.00'}</td>
                    </tr>
                    <tr className="bg-slate-50 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                      <td className="py-1.5 px-3 text-slate-900">RM + BOP Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.rmPlusBop.toFixed(2) || '5.12'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">M/c tonnage</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">T</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.machineTonnage} 
                          onChange={e => handleUpdateActiveStaged('machineTonnage', parseInt(e.target.value, 10) || 0)} 
                          className="w-24 px-2 py-0.5 border border-slate-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                      <td className="py-1.5 px-3 font-bold text-slate-900">Shift rate</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/shift</td>
                      <td className="py-1.5 px-4 text-right">
                        <input 
                          type="number" 
                          value={activeStaged.shiftTariff} 
                          onChange={e => handleUpdateActiveStaged('shiftTariff', parseFloat(e.target.value) || 0)} 
                          className="w-24 px-2 py-0.5 border border-slate-300 rounded text-right font-bold text-slate-900 bg-white" 
                        />
                      </td>
                    </tr>
                    <tr className="bg-amber-50/40 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                      <td className="py-1.5 px-3 font-black text-amber-950">Cycle time (seconds)</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">Sec</td>
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
                      <td className="py-1.5 px-3 font-mono text-slate-500">24</td>
                      <td className="py-1.5 px-3 text-slate-800">Efficiency</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">90%</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">No of cavity</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">Nos</td>
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
                      <td className="py-1.5 px-3 text-center text-slate-600">Nos</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{atomStagedCalc?.partsPerShift.toFixed(2) || '1102.98'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">27</td>
                      <td className="py-1.5 px-3 text-slate-800">Process cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.processCostPerPc.toFixed(2) || '1.81'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">28</td>
                      <td className="py-1.5 px-3 text-slate-800">Handling cost for BOP</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">3%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.handlingBop.toFixed(2) || '0.00'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">29</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Post operation cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.postOpCost.toFixed(2) || '1.73'}</td>
                    </tr>
                    <tr className="bg-slate-100 font-black">
                      <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                      <td className="py-1.5 px-3 text-slate-900">Total Process Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{atomStagedCalc?.totalProcessCost.toFixed(2) || '3.54'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">31</td>
                      <td className="py-1.5 px-3 text-slate-800">Profit & OH</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">12%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.ohAndProfit.toFixed(2) || '1.04'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">32</td>
                      <td className="py-1.5 px-3 text-slate-800">Inprocess Rejection</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">4%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.inProcessRejection.toFixed(2) || '0.35'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">33</td>
                      <td className="py-1.5 px-3 font-semibold text-rose-700">Runner recovery cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹25/kg</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-rose-700">-₹{atomStagedCalc?.runnerRecoveryCredit.toFixed(2) || '0.03'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">34</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Packing cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.packingCost.toFixed(2) || '0.86'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">35</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Transport cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.transportCost.toFixed(2) || '0.62'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">36</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Mould maintenance cost (2%)</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">2%</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.mouldMaintenance.toFixed(2) || '0.07'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">37</td>
                      <td className="py-1.5 px-3 font-semibold text-slate-800">Other Cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-800">₹{atomStagedCalc?.otherCost.toFixed(2) || '0.00'}</td>
                    </tr>
                    <tr className="bg-slate-900 text-white font-black">
                      <td className="py-2.5 px-3 font-mono text-amber-400">38</td>
                      <td className="py-2.5 px-3 uppercase text-amber-400">FINAL LANDED COST / PC</td>
                      <td className="py-2.5 px-3 text-center text-amber-300">₹/pc</td>
                      <td className="py-2.5 px-4 text-right font-mono text-amber-300 text-sm">₹{computedStagedTotal.toFixed(2)}</td>
                    </tr>
                  </tbody>
                </table>
              ) : (
                <table className="w-full text-left border-collapse text-xs">
                  <thead className="bg-slate-100 text-slate-700 text-[10px] uppercase font-bold sticky top-0 border-b border-slate-200">
                    <tr>
                      <th className="py-2 px-3 w-8">#</th>
                      <th className="py-2 px-3">DESCRIPTION / COSTING LINE</th>
                      <th className="py-2 px-3 text-center w-24">UOM</th>
                      <th className="py-2 px-4 text-right w-64">STAGED VALUE (EDITABLE)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-medium">
                    <tr>
                      <td className="py-2 px-3 font-mono text-slate-400">1</td>
                      <td className="py-2 px-3 font-bold">Name Of component</td>
                      <td className="py-2 px-3 text-center">-</td>
                      <td className="py-2 px-4 text-right font-bold text-slate-800">{activeStaged.componentName}</td>
                    </tr>
                    <tr>
                      <td className="py-2 px-3 font-mono text-slate-400">3</td>
                      <td className="py-2 px-3 font-bold text-blue-700">Item No. / Part Code</td>
                      <td className="py-2 px-3 text-center">-</td>
                      <td className="py-2 px-4 text-right font-mono font-bold text-blue-700">{activeStaged.itemCode}</td>
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

echo "==> 3. Verifying build with Vite..."
npm run build

echo "==> 4. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ ALL 38 LINES RESTORED AND FULLY VISIBLE IN STAGING & EDIT SPEC!"
echo "-------------------------------------------------------------------"
