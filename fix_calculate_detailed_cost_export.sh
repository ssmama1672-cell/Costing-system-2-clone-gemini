#!/usr/bin/env bash
set -e

echo "==> 1. Restoring calculateDetailedCost export in InlineEditModal.jsx..."
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

// RESTORED EXPORT REQUIRED BY CostingRunEnginePage and MISVariancePage
export function calculateDetailedCost(item) {
  if (!item) return { approvedBaselineCost: 0, simulatedActualCost: 0, totalCost: 0, finalLanded: 0, delta: 0 };
  
  const isHaier = (item.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (item.vendor || '').toLowerCase().includes('atomberg');
  const params = item.parameters || {};

  const cleanMaterialStr = sanitizeMaterialName(item.approvedRm || item.baseRm, item.componentName, item.itemCode, item.vendor);
  const { baseRm, mbGrade } = parseMaterialString(cleanMaterialStr);
  const rmInfo = getActiveRmMapping(baseRm || item.baseRm || cleanMaterialStr, item.vendor) || {};
  const mbInfo = getActiveMbMapping(mbGrade || item.approvedMb, item.vendor) || {};

  const approvedRmRate = Number(item.approvedRmPrice || rmInfo.approvedPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(params.runningRmBaseRate ?? rmInfo.activeWaPrice ?? rmInfo.approvedPrice ?? approvedRmRate);

  const approvedMbRate = Number(item.approvedMbPrice || mbInfo.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(params.runningMbBaseRate ?? mbInfo.activeMbWaPrice ?? mbInfo.approvedMbPrice ?? approvedMbRate);

  if (isHaier) {
    const ctApp = Number(item.cycleTimeApproved) > 0 ? Number(item.cycleTimeApproved) : 70;
    const cavApp = Number(item.cavity) > 0 ? Number(item.cavity) : 1;
    const meltLossApp = Number(item.meltLossPct !== undefined ? item.meltLossPct : 1.0);
    const effApp = Number(item.efficiencyPct !== undefined ? item.efficiencyPct : 95.0);

    const baseCalc = calculateHaierCost({
      cavity: cavApp,
      netWeight: Number(item.netWeight || 372),
      runnerWeight: Number(item.runnerWeight || 0),
      shotWeight: Number(item.shotWeight || (Number(item.netWeight || 372) * cavApp)),
      meltLossPct: meltLossApp,
      efficiencyPct: effApp,
      rmRate: approvedRmRate,
      masterbatchPct: Number(item.masterbatchPct || 4),
      masterbatchRate: approvedMbRate,
      shiftTariff: Number(item.shiftTariff || 4800),
      cycleTime: ctApp,
      haierOverheadPackage: Number(item.haierOverheadPackage !== undefined ? item.haierOverheadPackage : 8.712912),
      foamPolybag: Number(item.foamPolybag || 0),
      plasticBin: Number(item.plasticBin || 0),
      freightCost: Number(item.freightCost || 0),
      secondaryOp1: Number(item.secondaryOp1 || 0),
      secondaryOp2: Number(item.secondaryOp2 || 0),
      screenPrint1: Number(item.screenPrint1 || 0),
      screenPrint2: Number(item.screenPrint2 || 0),
      assemblyCost: Number(item.assemblyCost || 0),
      bopCost: Number(item.bopCost || 0),
      mouldMaintenance: Number(item.mouldMaintenance !== undefined ? item.mouldMaintenance : 1.5),
      qualityInspection: Number(item.qualityInspection !== undefined ? item.qualityInspection : 1.0),
      iccReduce: Number(item.iccReduce !== undefined ? item.iccReduce : -0.29),
      scrapAdj: Number(item.scrapAdj || 0)
    });

    const ctRun = Number(params.runningCycleTime ?? item.cycleTimeApproved ?? 70);
    const cavRun = Number(params.runningCavity ?? item.cavity ?? 1);
    const meltLossRun = Number(params.runningMeltLossPct ?? item.meltLossPct ?? 1.0);
    const effRun = Number(params.runningEfficiencyPct ?? item.efficiencyPct ?? 95.0);

    const runningCalc = calculateHaierCost({
      cavity: cavRun,
      netWeight: Number(params.runningNetWeight ?? item.netWeight ?? 372),
      runnerWeight: Number(params.runningRunnerWeight ?? item.runnerWeight ?? 0),
      shotWeight: Number(params.runningNetWeight ?? item.netWeight ?? 372) * cavRun + Number(params.runningRunnerWeight ?? item.runnerWeight ?? 0),
      meltLossPct: meltLossRun,
      efficiencyPct: effRun,
      rmRate: runningRmWaRate,
      masterbatchPct: Number(params.runningMbPct ?? item.masterbatchPct ?? 4),
      masterbatchRate: runningMbWaRate,
      shiftTariff: Number(params.runningShiftTariff ?? item.shiftTariff ?? 4800),
      cycleTime: ctRun,
      haierOverheadPackage: Number(params.runningHaierOverheadPackage ?? item.haierOverheadPackage ?? 8.712912),
      foamPolybag: Number(params.runningFoamPolybag ?? item.foamPolybag ?? 0),
      plasticBin: Number(params.runningPlasticBin ?? item.plasticBin ?? 0),
      freightCost: Number(params.runningFreightCost ?? item.freightCost ?? 0),
      secondaryOp1: Number(params.runningSecondaryOp1 ?? item.secondaryOp1 ?? 0),
      secondaryOp2: Number(params.runningSecondaryOp2 ?? item.secondaryOp2 ?? 0),
      screenPrint1: Number(params.runningScreenPrint1 ?? item.screenPrint1 ?? 0),
      screenPrint2: Number(params.runningScreenPrint2 ?? item.screenPrint2 ?? 0),
      assemblyCost: Number(params.runningAssemblyCost ?? item.assemblyCost ?? 0),
      bopCost: Number(params.runningBopCost ?? item.bopCost ?? 0),
      mouldMaintenance: Number(params.runningMouldMaintenance ?? item.mouldMaintenance ?? 1.5),
      qualityInspection: Number(params.runningQualityInspection ?? item.qualityInspection ?? 1.0),
      iccReduce: Number(params.runningIccReduce ?? item.iccReduce ?? -0.29),
      scrapAdj: Number(params.runningScrapAdj ?? item.scrapAdj ?? 0)
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

echo "==> 2. Building & verifying Vite production build..."
npm run build

echo "==> 3. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ BUILD PASSED AND DEV SERVER STARTED ON DEV-V2!"
echo "-------------------------------------------------------------------"
