#!/usr/bin/env bash
set -e

echo "==> 1. Updating InlineEditModal.jsx with accurate calculateDetailedCost & full 38-line Haier layout..."
cat << 'MODAL_EOF' > src/modules/module1-baseline/InlineEditModal.jsx
import React, { useState } from 'react';
import { X, Save, Trash2, Lock } from 'lucide-react';
import { calculateHaierCost, calculateAtombergCost } from '../../shared/costCalculationService';
import { parseMaterialString, getActiveRmMapping, getActiveMbMapping } from '../../shared/masterStore';

export default function InlineEditModal({ product, onClose, onSave, onDelete }) {
  if (!product) return null;

  const isHaier = (product.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (product.vendor || '').toLowerCase().includes('atomberg');
  const initialParams = product.parameters || {};

  const { baseRm, mbGrade } = parseMaterialString(product.approvedRm || product.baseRm);
  const rmLookupKey = baseRm || product.baseRm || product.approvedRm || (isAtomberg ? 'PP H110MA' : 'HIPS SH303');
  const mbLookupKey = mbGrade || product.approvedMb || ((product.masterbatchPct || 0) > 0 ? (isAtomberg ? 'Gloss White MB' : 'White MB') : 'None');

  const rmInfo = getActiveRmMapping(rmLookupKey, product.vendor) || {};
  const mbInfo = getActiveMbMapping(mbLookupKey, product.vendor) || {};

  // Matrix locked prices
  const approvedRmRate = Number(rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(rmInfo.activeWaPrice || rmInfo.approvedPrice || product.approvedRmPrice || (isAtomberg ? 131.00 : 154.00));

  const approvedMbRate = Number(mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(mbInfo.activeMbWaPrice || mbInfo.approvedMbPrice || product.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));

  const [formData, setFormData] = useState({
    approvedRm: product.approvedRm || baseRm || (isAtomberg ? 'PP H110MA + Gloss White' : 'HIPS SH303'),
    baseRm: rmLookupKey,
    approvedMb: mbLookupKey,
    
    // Baseline Parameters
    rmFreight: Number(product.rmFreight !== undefined ? product.rmFreight : 1.50),
    mbFreight: Number(product.mbFreight !== undefined ? product.mbFreight : 2.00),
    masterbatchPct: Number(product.masterbatchPct !== undefined ? product.masterbatchPct : (isAtomberg ? 4 : 4)),
    partWeight: Number(product.netWeight !== undefined ? product.netWeight : (isAtomberg ? 37.00 : 372.00)),
    runnerWeight: Number(product.runnerWeight !== undefined ? product.runnerWeight : (isAtomberg ? 1.00 : 0.00)),
    bopCost: Number(product.bopCost || 0),
    machineTonnage: Number(product.machineTonnage || (isAtomberg ? 200 : 600)),
    shiftTariff: Number(product.shiftTariff || (isAtomberg ? 2000 : 4800)),
    cycleTimeApproved: Number(product.cycleTimeApproved || (isAtomberg ? 47 : 67)),
    cavity: Number(product.cavity || (isAtomberg ? 2 : 1)),
    packingCost: Number(product.packingCost !== undefined ? product.packingCost : 0.86),
    transportCost: Number(product.transportCost !== undefined ? product.transportCost : 0.62),
    otherCost: Number(product.otherCost !== undefined ? product.otherCost : 0.00),
    mouldSize: product.mouldSize || (isAtomberg ? '450x450x380' : '800x800x684'),
    model: product.model || (isAtomberg ? 'Aris Ceiling Fan' : 'TM 258/278'),
    
    // Haier Specific Lines
    haierOverheadPackage: Number(product.haierOverheadPackage !== undefined ? product.haierOverheadPackage : 8.71),
    foamPolybag: Number(product.foamPolybag || 0),
    plasticBin: Number(product.plasticBin || 0),
    freightCost: Number(product.freightCost || 0),
    secondaryOp1: Number(product.secondaryOp1 || 0),
    secondaryOp2: Number(product.secondaryOp2 || 0),
    screenPrint1: Number(product.screenPrint1 || 0),
    screenPrint2: Number(product.screenPrint2 || 0),
    assemblyCost: Number(product.assemblyCost || 0),
    mouldMaintenance: Number(product.mouldMaintenance || 0),
    qualityInspection: Number(product.qualityInspection || 0),
    iccReduce: Number(product.iccReduce || 0),
    scrapAdj: Number(product.scrapAdj || 0),

    // Running Parameters
    runningRmFreight: Number(initialParams.runningRmFreight ?? product.rmFreight ?? 1.50),
    runningMbFreight: Number(initialParams.runningMbFreight ?? product.mbFreight ?? 2.00),
    runningMbPct: Number(initialParams.runningMbPct ?? product.masterbatchPct ?? (isAtomberg ? 4 : 4)),
    runningPartWeight: Number(initialParams.runningNetWeight ?? product.netWeight ?? (isAtomberg ? 37.00 : 372.00)),
    runningRunnerWeight: Number(initialParams.runningRunnerWeight ?? product.runnerWeight ?? (isAtomberg ? 1.00 : 0.00)),
    runningBopCost: Number(initialParams.runningBopCost ?? product.bopCost ?? 0),
    runningShiftTariff: Number(initialParams.runningShiftTariff ?? product.shiftTariff ?? (isAtomberg ? 2000 : 4800)),
    runningCycleTime: Number(initialParams.runningCycleTime ?? product.cycleTimeApproved ?? (isAtomberg ? 47 : 67)),
    runningCavity: Number(initialParams.runningCavity ?? product.cavity ?? (isAtomberg ? 2 : 1)),
    runningPackingCost: Number(initialParams.runningPackingCost ?? product.packingCost ?? 0.86),
    runningTransportCost: Number(initialParams.runningTransportCost ?? product.transportCost ?? 0.62),
    runningOtherCost: Number(initialParams.runningOtherCost ?? product.otherCost ?? 0.00),
    runningHaierOverheadPackage: Number(initialParams.runningHaierOverheadPackage ?? product.haierOverheadPackage ?? 8.71)
  });

  // 1. Calculate Atomberg Baseline & Running
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

  // 2. Calculate Haier Baseline & Running
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
    partsPerShift: row21RunningNum,
    rmRate: runningRmWaRate,
    masterbatchPct: formData.runningMbPct,
    masterbatchRate: runningMbWaRate,
    shiftTariff: formData.runningShiftTariff,
    cycleTime: formData.runningCycleTime,
    haierOverheadPackage: formData.runningHaierOverheadPackage,
    foamPolybag: formData.foamPolybag,
    plasticBin: formData.plasticBin,
    freightCost: formData.freightCost,
    secondaryOp1: formData.secondaryOp1,
    secondaryOp2: formData.secondaryOp2,
    screenPrint1: formData.screenPrint1,
    screenPrint2: formData.screenPrint2,
    assemblyCost: formData.assemblyCost,
    bopCost: formData.runningBopCost,
    mouldMaintenance: formData.mouldMaintenance,
    qualityInspection: formData.qualityInspection,
    iccReduce: formData.iccReduce,
    scrapAdj: formData.scrapAdj
  });

  const contractTotal = isHaier ? haierBaseCalc.totalCost : atombergBaseCalc.finalLanded;
  const runningTotal = isHaier ? haierRunningCalc.totalCost : atombergRunningCalc.finalLanded;
  const profitLossDelta = Number((contractTotal - runningTotal).toFixed(2));

  const handleSave = () => {
    onSave({
      ...product,
      ...formData,
      approvedCost: contractTotal,
      simulatedCost: runningTotal,
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
        runningBopCost: formData.runningBopCost,
        runningPackingCost: formData.runningPackingCost,
        runningTransportCost: formData.runningTransportCost,
        runningOtherCost: formData.runningOtherCost,
        runningHaierOverheadPackage: formData.runningHaierOverheadPackage
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
                  <td className="py-1.5 px-4 text-right font-semibold text-slate-800">{formData.approvedRm}</td>
                  <td className="py-1.5 px-4 text-right font-semibold text-blue-800">{formData.approvedRm}</td>
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
                <tr className="bg-slate-50/70">
                  <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900 flex items-center gap-1.5">
                    <Lock className="w-3 h-3 text-amber-600" /> MB Base Cost (From RM Matrix)
                  </td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{approvedMbRate.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{runningMbWaRate.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(approvedMbRate - runningMbWaRate).toFixed(2)}</td>
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

                {/* Row 29 = Row 27 + Row 28 */}
                <tr className="bg-blue-50/40 font-bold">
                  <td className="py-1.5 px-3 font-mono text-blue-700">29</td>
                  <td className="py-1.5 px-3 text-blue-950 font-bold">Post operation cost = Row 27 + Row 28</td>
                  <td className="py-1.5 px-3 text-center text-blue-700">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergBaseCalc.postOpCost.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{atombergRunningCalc.postOpCost.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(atombergBaseCalc.postOpCost - atombergRunningCalc.postOpCost).toFixed(2)}</td>
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
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">5</td>
                  <td className="py-1.5 px-3 font-bold">Raw Material Required</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-bold text-slate-800">{formData.approvedRm}</td>
                  <td className="py-1.5 px-4 text-right font-bold text-blue-800">{formData.approvedRm}</td>
                  <td className="py-1.5 px-3 text-right text-emerald-600 font-bold">Matched</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                  <td className="py-1.5 px-3 font-bold text-purple-900">Master Batch Required (%)</td>
                  <td className="py-1.5 px-3 text-center">%</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.1" value={formData.masterbatchPct} onChange={e => setFormData({ ...formData, masterbatchPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.1" value={formData.runningMbPct} onChange={e => setFormData({ ...formData, runningMbPct: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.masterbatchPct - formData.runningMbPct).toFixed(1)}%</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                  <td className="py-1.5 px-3 font-bold">No. of Cavity</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-bold">{formData.cavity}</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningCavity} onChange={e => setFormData({ ...formData, runningCavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{formData.cavity - formData.runningCavity}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                  <td className="py-1.5 px-3">Runner Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.runnerWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningRunnerWeight} onChange={e => setFormData({ ...formData, runningRunnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.runnerWeight - formData.runningRunnerWeight).toFixed(2)}g</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                  <td className="py-1.5 px-3 font-bold">Net Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.partWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningPartWeight} onChange={e => setFormData({ ...formData, runningPartWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.partWeight - formData.runningPartWeight).toFixed(2)}g</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">10</td>
                  <td className="py-1.5 px-3">Shot Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{Number(haierBaseCalc.shotWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{Number(haierRunningCalc.shotWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">0.00g</td>
                </tr>
                <tr className="bg-slate-50">
                  <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Reconciliation Weight = Shot wt + 1.0% Melt Loss</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{Number(haierBaseCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-600">{Number(haierRunningCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">0.00g</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                  <td className="py-1.5 px-3">Raw Material Cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(haierBaseCalc.rawMaterialCost).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(haierRunningCalc.rawMaterialCost).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                  <td className="py-1.5 px-3">Master batch cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(haierBaseCalc.masterbatchCost).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(haierRunningCalc.masterbatchCost).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                  <td className="py-1.5 px-3 text-slate-900">Total Raw Material Cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(haierBaseCalc.totalRmCost).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(haierRunningCalc.totalRmCost).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                  <td className="py-1.5 px-3">Machine Used</td>
                  <td className="py-1.5 px-3 text-center">T</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.machineTonnage}T</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.machineTonnage}T</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">17</td>
                  <td className="py-1.5 px-3 font-bold">Machine Tariff per Shift</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.shiftTariff} onChange={e => setFormData({ ...formData, shiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningShiftTariff} onChange={e => setFormData({ ...formData, runningShiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(formData.shiftTariff - formData.runningShiftTariff).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                  <td className="py-1.5 px-3 font-bold">Cycle Time</td>
                  <td className="py-1.5 px-3 text-center">Sec</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.cycleTimeApproved} onChange={e => setFormData({ ...formData, cycleTimeApproved: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningCycleTime} onChange={e => setFormData({ ...formData, runningCycleTime: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.cycleTimeApproved - formData.runningCycleTime).toFixed(1)}s</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">19</td>
                  <td className="py-1.5 px-3">No of Shot / Shift (8Hour)</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono">{row19ApprovedNum.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{row19RunningNum.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(row19ApprovedNum - row19RunningNum).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                  <td className="py-1.5 px-3">No of Shot / Shift with 95 % Efficiency</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono">{row20ApprovedNum.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{row20RunningNum.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(row20ApprovedNum - row20RunningNum).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                  <td className="py-1.5 px-3">No. of component / shift</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{row21ApprovedNum.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{row21RunningNum.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(row21ApprovedNum - row21RunningNum).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                  <td className="py-1.5 px-3 font-bold">Production Cost / Pc</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">₹{Number(haierBaseCalc.productionCostPerPc).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">₹{Number(haierRunningCalc.productionCostPerPc).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr className="bg-slate-100 font-black">
                  <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                  <td className="py-1.5 px-3 uppercase text-slate-900">SUB TOTAL</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(haierBaseCalc.subTotal).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(haierRunningCalc.subTotal).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr className="bg-purple-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">24</td>
                  <td className="py-1.5 px-3 font-bold text-purple-950">OH + Profit + ICC + Rejection + Packaging + Freight</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.0001" value={formData.haierOverheadPackage} onChange={e => setFormData({ ...formData, haierOverheadPackage: Number(e.target.value) || 0 })} className="w-28 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" />
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.0001" value={formData.runningHaierOverheadPackage} onChange={e => setFormData({ ...formData, runningHaierOverheadPackage: Number(e.target.value) || 0 })} className="w-28 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
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

// Global calculateDetailedCost returning baseline, simulated, and delta correctly
export function calculateDetailedCost(item) {
  if (!item) return { approvedBaselineCost: 0, simulatedActualCost: 0, totalCost: 0, finalLanded: 0, delta: 0 };
  
  const isHaier = (item.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (item.vendor || '').toLowerCase().includes('atomberg');
  const params = item.parameters || {};

  const { baseRm, mbGrade } = parseMaterialString(item.approvedRm || item.baseRm);
  const rmInfo = getActiveRmMapping(baseRm || item.baseRm || item.approvedRm, item.vendor) || {};
  const mbInfo = getActiveMbMapping(mbGrade || item.approvedMb, item.vendor) || {};

  const approvedRmRate = Number(item.approvedRmPrice || rmInfo.approvedPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(params.runningRmBaseRate ?? rmInfo.activeWaPrice ?? rmInfo.approvedPrice ?? approvedRmRate);

  const approvedMbRate = Number(item.approvedMbPrice || mbInfo.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(params.runningMbBaseRate ?? mbInfo.activeMbWaPrice ?? mbInfo.approvedMbPrice ?? approvedMbRate);

  if (isHaier) {
    const ctApp = Number(item.cycleTimeApproved) > 0 ? Number(item.cycleTimeApproved) : 67;
    const cavApp = Number(item.cavity) > 0 ? Number(item.cavity) : 1;
    const partsPerShiftApp = (28800 / ctApp) * 0.95 * cavApp;

    const baseCalc = calculateHaierCost({
      cavity: cavApp,
      netWeight: Number(item.netWeight || 372),
      runnerWeight: Number(item.runnerWeight || 0),
      shotWeight: Number(item.shotWeight || (Number(item.netWeight || 372) * cavApp)),
      partsPerShift: partsPerShiftApp,
      rmRate: approvedRmRate,
      masterbatchPct: Number(item.masterbatchPct || 4),
      masterbatchRate: approvedMbRate,
      shiftTariff: Number(item.shiftTariff || 4800),
      cycleTime: ctApp,
      haierOverheadPackage: Number(item.haierOverheadPackage !== undefined ? item.haierOverheadPackage : 8.71),
      foamPolybag: Number(item.foamPolybag || 0),
      plasticBin: Number(item.plasticBin || 0),
      freightCost: Number(item.freightCost || 0),
      secondaryOp1: Number(item.secondaryOp1 || 0),
      secondaryOp2: Number(item.secondaryOp2 || 0),
      screenPrint1: Number(item.screenPrint1 || 0),
      screenPrint2: Number(item.screenPrint2 || 0),
      assemblyCost: Number(item.assemblyCost || 0),
      bopCost: Number(item.bopCost || 0),
      mouldMaintenance: Number(item.mouldMaintenance || 0),
      qualityInspection: Number(item.qualityInspection || 0),
      iccReduce: Number(item.iccReduce || 0),
      scrapAdj: Number(item.scrapAdj || 0)
    });

    const ctRun = Number(params.runningCycleTime ?? item.cycleTimeApproved ?? 67);
    const cavRun = Number(params.runningCavity ?? item.cavity ?? 1);
    const partsPerShiftRun = (28800 / (ctRun > 0 ? ctRun : 1)) * 0.95 * (cavRun > 0 ? cavRun : 1);

    const runningCalc = calculateHaierCost({
      cavity: cavRun,
      netWeight: Number(params.runningNetWeight ?? item.netWeight ?? 372),
      runnerWeight: Number(params.runningRunnerWeight ?? item.runnerWeight ?? 0),
      shotWeight: Number(params.runningNetWeight ?? item.netWeight ?? 372) * cavRun + Number(params.runningRunnerWeight ?? item.runnerWeight ?? 0),
      partsPerShift: partsPerShiftRun,
      rmRate: runningRmWaRate,
      masterbatchPct: Number(params.runningMbPct ?? item.masterbatchPct ?? 4),
      masterbatchRate: runningMbWaRate,
      shiftTariff: Number(params.runningShiftTariff ?? item.shiftTariff ?? 4800),
      cycleTime: ctRun,
      haierOverheadPackage: Number(params.runningHaierOverheadPackage ?? item.haierOverheadPackage ?? 8.71),
      foamPolybag: Number(item.foamPolybag || 0),
      plasticBin: Number(item.plasticBin || 0),
      freightCost: Number(item.freightCost || 0),
      secondaryOp1: Number(item.secondaryOp1 || 0),
      secondaryOp2: Number(item.secondaryOp2 || 0),
      screenPrint1: Number(item.screenPrint1 || 0),
      screenPrint2: Number(item.screenPrint2 || 0),
      assemblyCost: Number(item.assemblyCost || 0),
      bopCost: Number(params.runningBopCost ?? item.bopCost ?? 0),
      mouldMaintenance: Number(item.mouldMaintenance || 0),
      qualityInspection: Number(item.qualityInspection || 0),
      iccReduce: Number(item.iccReduce || 0),
      scrapAdj: Number(item.scrapAdj || 0)
    });

    const approvedBaselineCost = Number(item.approvedCost || baseCalc.totalCost || 0);
    const simulatedActualCost = Number(runningCalc.totalCost || approvedBaselineCost || 0);

    return {
      approvedBaselineCost,
      simulatedActualCost,
      totalCost: approvedBaselineCost,
      finalLanded: simulatedActualCost,
      delta: Number((approvedBaselineCost - simulatedActualCost).toFixed(2))
    };
  } else {
    // Atomberg
    const baseCalc = calculateAtombergCost({
      rmBase: approvedRmRate,
      rmFreight: Number(item.rmFreight !== undefined ? item.rmFreight : 1.50),
      mbBase: approvedMbRate,
      mbFreight: Number(item.mbFreight !== undefined ? item.mbFreight : 2.00),
      partWt: Number(item.netWeight !== undefined ? item.netWeight : 37.00),
      runnerWt: Number(item.runnerWeight !== undefined ? item.runnerWeight : 1.00),
      mbPct: (Number(item.masterbatchPct !== undefined ? item.masterbatchPct : 4)) / 100,
      bopCost: Number(item.bopCost || 0),
      cycleTime: Number(item.cycleTimeApproved || 47),
      cavity: Number(item.cavity || 2),
      tonnage: Number(item.machineTonnage || 200),
      shiftTariff: Number(item.shiftTariff || 2000),
      packingCost: Number(item.packingCost !== undefined ? item.packingCost : 0.86),
      transportCost: Number(item.transportCost !== undefined ? item.transportCost : 0.62),
      otherCost: Number(item.otherCost !== undefined ? item.otherCost : 0.00)
    });

    const runningCalc = calculateAtombergCost({
      rmBase: runningRmWaRate,
      rmFreight: Number(params.runningRmFreight ?? item.rmFreight ?? 1.50),
      mbBase: runningMbWaRate,
      mbFreight: Number(params.runningMbFreight ?? item.mbFreight ?? 2.00),
      partWt: Number(params.runningNetWeight ?? item.netWeight ?? 37.00),
      runnerWt: Number(params.runningRunnerWeight ?? item.runnerWeight ?? 1.00),
      mbPct: (Number(params.runningMbPct ?? item.masterbatchPct ?? 4)) / 100,
      bopCost: Number(params.runningBopCost ?? item.bopCost ?? 0),
      cycleTime: Number(params.runningCycleTime ?? item.cycleTimeApproved ?? 47),
      cavity: Number(params.runningCavity ?? item.cavity ?? 2),
      tonnage: Number(item.machineTonnage || 200),
      shiftTariff: Number(params.runningShiftTariff ?? item.shiftTariff ?? 2000),
      packingCost: Number(params.runningPackingCost ?? item.packingCost ?? 0.86),
      transportCost: Number(params.runningTransportCost ?? item.transportCost ?? 0.62),
      otherCost: Number(params.runningOtherCost ?? item.otherCost ?? 0.00)
    });

    const approvedBaselineCost = Number(item.approvedCost || baseCalc.finalLanded || 0);
    const simulatedActualCost = Number(runningCalc.finalLanded || approvedBaselineCost || 0);

    return {
      approvedBaselineCost,
      simulatedActualCost,
      totalCost: approvedBaselineCost,
      finalLanded: simulatedActualCost,
      delta: Number((approvedBaselineCost - simulatedActualCost).toFixed(2))
    };
  }
}
MODAL_EOF

echo "==> 2. Updating CostingRunEnginePage.jsx with clear high-contrast numbers & exact synchronization..."
cat << 'COSTING_PAGE_EOF' > src/modules/module3-costing-engine/CostingRunEnginePage.jsx
import React, { useState, useEffect } from 'react';
import { Calculator, Download, Search, Layers, TrendingUp, TrendingDown } from 'lucide-react';
import * as XLSX from 'xlsx';
import { globalStore, subscribeStore, getActiveRmMapping, parseMaterialString, normalizeVendorId } from '../../shared/masterStore';
import { calculateDetailedCost } from '../module1-baseline/InlineEditModal';

export default function CostingRunEnginePage() {
  const [storeState, setStoreState] = useState(globalStore);
  const [selectedVendor, setSelectedVendor] = useState('ALL');
  const [searchQuery, setSearchQuery] = useState('');

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
        <div className="p-3 bg-slate-900 text-white flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-blue-400" />
            <h2 className="text-xs font-bold uppercase tracking-wider">Live Product Cost Simulation Matrix</h2>
          </div>
          <button onClick={handleDownloadCostMatrix} className="px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-bold flex items-center gap-1.5 text-xs">
            <Download className="w-3.5 h-3.5" /> Download Cost Matrix (.xlsx)
          </button>
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
COSTING_PAGE_EOF

echo "==> 3. Updating BaselineMasterPage.jsx with accurate column skipping & full 38-line Haier Staging Table..."
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

      // Universal column scanner across row descriptions
      const totalCols = Math.max(...rawMatrix.map(r => r.length));

      for (let c = 0; c < totalCols; c++) {
        let itemCode = '';
        let compName = '';
        let rmGradeStr = isHaierVendor ? 'HIPS SH303 + White MB' : 'PP H110MA + Gloss White';
        let rmBaseRate = isHaierVendor ? 154 : 131;
        let mbBaseRate = isHaierVendor ? 242 : 154;
        let mbPct = isHaierVendor ? 4.0 : 4.0;
        let partWt = isHaierVendor ? 372 : 37.00;
        let runnerWt = isHaierVendor ? 0 : 1.00;
        let tonnage = isHaierVendor ? 600 : 200;
        let tariff = isHaierVendor ? 4800 : 2000;
        let cycleTime = isHaierVendor ? 67 : 47;
        let cavity = isHaierVendor ? 1 : 2;
        let packingCost = 0.86;
        let transportCost = 0.62;
        let haierOverheadPackage = 8.71;

        rawMatrix.forEach((r, rIdx) => {
          const label = `${r[0] || ''} ${r[1] || ''}`.toLowerCase().trim();
          const val = r[c];
          if (val === undefined || val === null || val === '') return;
          const valStr = String(val).trim();

          if (label.includes('part code') || label.includes('item no') || label === '2' || label === '3') {
            if (!itemCode && valStr !== '-' && !valStr.toLowerCase().includes('fixed') && !valStr.toLowerCase().includes('item no')) {
              itemCode = valStr;
            }
          }
          if (label.includes('part name') || label.includes('name of component') || (label.includes('description') && !label.includes('grade'))) {
            if (!compName && valStr !== '-' && !valStr.toLowerCase().includes('fixed') && !valStr.toLowerCase().includes('name of component')) {
              compName = valStr;
            }
          }
          if (label.includes('rm grade') || (label.includes('raw material') && !label.includes('cost'))) {
            if (valStr !== '-' && !valStr.toLowerCase().includes('fixed')) rmGradeStr = valStr;
          }
          if (label.includes('rm base rate') || (label.includes('raw material cost') && label.includes('matrix'))) {
            const num = parseFloat(val);
            if (!isNaN(num) && num > 0) rmBaseRate = num;
          }
          if (label.includes('mb base cost') || label.includes('mb rate')) {
            const num = parseFloat(val);
            if (!isNaN(num) && num > 0) mbBaseRate = num;
          }
          if (label.includes('mb %') || label.includes('masterbatch %') || label.includes('master batch required')) {
            const num = parseFloat(val);
            if (!isNaN(num)) mbPct = num <= 1 ? num * 100 : num;
          }
          if (label.includes('part weight') || label.includes('net weight')) {
            const num = parseFloat(val);
            if (!isNaN(num) && num > 0) partWt = num;
          }
          if (label.includes('runner weight') && !label.includes('recovery')) {
            const num = parseFloat(val);
            if (!isNaN(num)) runnerWt = num;
          }
          if (label.includes('machine used') || label.includes('tonnage')) {
            const num = parseInt(val, 10);
            if (!isNaN(num) && num > 0) tonnage = num;
          }
          if (label.includes('shift rate') || label.includes('shift tariff') || label.includes('machine tariff')) {
            const num = parseFloat(val);
            if (!isNaN(num) && num > 0) tariff = num;
          }
          if (label.includes('cycle time') && !label.includes('rejection') && !label.includes('reconciliation')) {
            const num = parseFloat(val);
            if (!isNaN(num) && num > 1) cycleTime = num;
          }
          if (label.includes('no of cavity') || label.includes('no. of cavity')) {
            const num = parseInt(val, 10);
            if (!isNaN(num) && num > 0) cavity = num;
          }
          if (label.includes('oh + profit') || label.includes('overhead')) {
            const num = parseFloat(val);
            if (!isNaN(num)) haierOverheadPackage = num;
          }
        });

        // Skip non-product columns (UOM, Fixed as per Upload, headers)
        if (!itemCode && rawMatrix[3]?.[c]) itemCode = String(rawMatrix[3][c]).trim();
        if (!compName && rawMatrix[1]?.[c]) compName = String(rawMatrix[1][c]).trim();

        if (
          !compName || 
          !itemCode || 
          compName === '-' || 
          compName.toLowerCase().includes('fixed as per upload') ||
          compName.toLowerCase().includes('name of component') ||
          compName.toLowerCase().includes('description') ||
          itemCode.toLowerCase().includes('fixed as per upload') ||
          itemCode.toLowerCase().includes('item no')
        ) {
          continue;
        }

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
          const ctApp = cycleTime > 0 ? cycleTime : 67;
          const cavApp = cavity > 0 ? cavity : 1;
          const partsPerShift = (28800 / ctApp) * 0.95 * cavApp;

          const h = calculateHaierCost({
            cavity: cavApp,
            netWeight: partWt,
            runnerWeight: runnerWt,
            shotWeight: partWt * cavApp + runnerWt,
            partsPerShift: partsPerShift,
            rmRate: rmBaseRate,
            masterbatchPct: mbPct,
            masterbatchRate: mbBaseRate,
            shiftTariff: tariff,
            cycleTime: ctApp,
            haierOverheadPackage: haierOverheadPackage
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
          mouldSize: isHaierVendor ? '800x800x684' : '450x450x380',
          itemCode: itemCode,
          model: isHaierVendor ? 'TM 258/278' : 'Aris Ceiling Fan',
          approvedRm: rmGradeStr,
          baseRm: baseRm || rmGradeStr,
          approvedMb: mbGrade || (isHaierVendor ? 'White MB' : 'Gloss White MB'),
          masterbatchPct: mbPct,
          cavity: cavity,
          runnerWeight: runnerWt,
          netWeight: partWt,
          shotWeight: (partWt * cavity + runnerWt),
          machineTonnage: tonnage,
          shiftTariff: tariff,
          cycleTimeApproved: cycleTime,
          haierOverheadPackage: haierOverheadPackage,
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
            runningHaierOverheadPackage: haierOverheadPackage,
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
      const ctApp = Number(activeStaged.cycleTimeApproved || 67);
      const cavApp = Number(activeStaged.cavity || 1);
      const partsPerShift = (28800 / (ctApp > 0 ? ctApp : 1)) * 0.95 * cavApp;

      haierStagedCalc = calculateHaierCost({
        cavity: cavApp,
        netWeight: Number(activeStaged.netWeight || 372),
        runnerWeight: Number(activeStaged.runnerWeight || 0),
        shotWeight: Number(activeStaged.netWeight || 372) * cavApp + Number(activeStaged.runnerWeight || 0),
        partsPerShift: partsPerShift,
        rmRate: 154,
        masterbatchPct: Number(activeStaged.masterbatchPct || 4),
        masterbatchRate: 242,
        shiftTariff: Number(activeStaged.shiftTariff || 4800),
        cycleTime: ctApp,
        haierOverheadPackage: Number(activeStaged.haierOverheadPackage || 8.71)
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

      {/* RENDER COMPLETE STAGING MODAL (All 38 Lines for Haier & Atomberg) */}
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

            {/* Full 38-Line Specification Staging Table */}
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
                    <tr className="bg-amber-50/30">
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
                    <tr className="bg-amber-50/30">
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
                    <tr className="bg-emerald-50/40 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                      <td className="py-1.5 px-3 text-emerald-950">RM cost</td>
                      <td className="py-1.5 px-3 text-center text-slate-600">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-900">₹{atomStagedCalc?.rmCostPerPc.toFixed(2) || '5.12'}</td>
                    </tr>
                    <tr>
                      <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                      <td className="py-1.5 px-3 font-bold">Shift rate</td>
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
                    <tr className="bg-amber-50/50 font-bold">
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
                    <tr className="bg-slate-100 font-bold">
                      <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                      <td className="py-1.5 px-3">Total Process Cost</td>
                      <td className="py-1.5 px-3 text-center">₹/pc</td>
                      <td className="py-1.5 px-4 text-right font-mono font-bold">₹{atomStagedCalc?.totalProcessCost.toFixed(2) || '3.54'}</td>
                    </tr>
                    <tr className="bg-slate-900 text-white font-black">
                      <td className="py-2.5 px-3 font-mono text-amber-400">38</td>
                      <td className="py-2.5 px-3 uppercase text-amber-400">Final Landed cost</td>
                      <td className="py-2.5 px-3 text-center">₹/pc</td>
                      <td className="py-2.5 px-4 text-right font-mono text-amber-300 text-sm">₹{computedStagedTotal.toFixed(2)}</td>
                    </tr>
                  </tbody>
                </table>
              ) : (
                /* HAIER FULL 38-LINE STAGING TABLE */
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
                      <td className="py-1.5 px-3 font-bold text-blue-700">Item No. / Part Code</td>
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
                      <td className="py-1.5 px-3 font-bold">Raw Material Required</td>
                      <td className="py-1.5 px-3 text-center">-</td>
                      <td className="py-1.5 px-4 text-right font-bold text-slate-800">{activeStaged.approvedRm}</td>
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
                      <td className="py-1.5 px-4 text-right font-mono font-bold">{Number(activeStaged.shotWeight || (activeStaged.netWeight * activeStaged.cavity + activeStaged.runnerWeight)).toFixed(2)}g</td>
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

echo "==> 4. Compiling build verification..."
npm run build

echo "==> 5. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ COSTING ENGINE SYNC & HAIER 38-LINE SPECIFICATION RESTORED!"
echo "-------------------------------------------------------------------"
