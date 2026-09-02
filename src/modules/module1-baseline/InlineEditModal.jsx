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
    postOpCost: Number(initialParams.postOpCost ?? product.postOpCost ?? 0),
    runningPostOpCost: Number(initialParams.runningPostOpCost ?? initialParams.postOpCost ?? product.postOpCost ?? 0),
    runnerRecoveryOption: product.runnerRecoveryOption || product.parameters?.runnerRecoveryOption || 'opt2',
    approvedRm: cleanMaterialStr,
    baseRm: rmLookupKey,
    approvedMb: mbLookupKey,
    
    // Baseline Shared Parameters
    rmFreight: Number(product.rmFreight !== undefined ? product.rmFreight : 1.50),
    mbFreight: Number(product.mbFreight !== undefined ? product.mbFreight : 2.00),
    masterbatchPct: Number(product.masterbatchPct !== undefined ? product.masterbatchPct : 4),
    partWeight: Number(product.netWeight !== undefined ? product.netWeight : (isAtomberg ? 37.00 : 372.00)),
    runnerWeight: Number(product.runnerWeight ?? initialParams.runnerWeight ?? (isAtomberg ? 1.00 : 0.00)),
    netWeight: Number(product.netWeight ?? product.partWeight ?? initialParams.netWeight ?? 0),
    bopCost: Number(product.bopCost || 0),
    machineTonnage: Number(product.machineTonnage || (isAtomberg ? 200 : 600)),
    shiftTariff: Number(product.shiftTariff || (isAtomberg ? 2000 : 4800)),
    cycleTimeApproved: Number(product.cycleTimeApproved || (isAtomberg ? 47 : 70)),
    cavity: Number(product.cavity || (isAtomberg ? 2 : 1)),
    
    meltLossPct: Number(product.meltLossPct !== undefined ? product.meltLossPct : 1.0),
    efficiencyPct: Number(product.efficiencyPct !== undefined ? product.efficiencyPct : (isAtomberg ? 90.0 : 95.0)),

    packingCost: Number(product.packingCost !== undefined ? product.packingCost : 0),
    transportCost: Number(product.transportCost !== undefined ? product.transportCost : 0.62),
    otherCost: Number(product.otherCost !== undefined ? product.otherCost : 0.00),
    mouldSize: product.mouldSize || (isAtomberg ? '450x450x380' : '800x800x684'),
    model: product.model || (isAtomberg ? 'Aris Ceiling Fan' : 'TM 258/278'),
    
    // Haier Baseline Lines
    haierOverheadPackage: Number(product.haierOverheadPackage !== undefined ? product.haierOverheadPackage : 0),
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

    // Running Overrides
    runningRmFreight: Number(initialParams.runningRmFreight ?? product.rmFreight ?? 1.50),
    runningMbFreight: Number(initialParams.runningMbFreight ?? product.mbFreight ?? 2.00),
    runningMbPct: Number(initialParams.runningMbPct ?? product.masterbatchPct ?? 4),
    runningPartWeight: Number(initialParams.runningNetWeight ?? product.netWeight ?? (isAtomberg ? 37.00 : 372.00)),
    runningRunnerWeight: Number(initialParams.runningRunnerWeight ?? product.runnerWeight ?? initialParams.runnerWeight ?? (isAtomberg ? 1.00 : 0.00)),
    runningNetWeight: Number(initialParams.runningNetWeight ?? product.netWeight ?? product.partWeight ?? 0),
    runningBopCost: Number(initialParams.runningBopCost ?? product.bopCost ?? 0),
    runningShiftTariff: Number(initialParams.runningShiftTariff ?? product.shiftTariff ?? (isAtomberg ? 2000 : 4800)),
    runningCycleTime: Number(initialParams.runningCycleTime ?? product.cycleTimeApproved ?? (isAtomberg ? 47 : 70)),
    runningCavity: Number(initialParams.runningCavity ?? product.cavity ?? (isAtomberg ? 2 : 1)),
    runningMeltLossPct: Number(initialParams.runningMeltLossPct ?? product.meltLossPct ?? 1.0),
    runningEfficiencyPct: Number(initialParams.runningEfficiencyPct ?? product.efficiencyPct ?? (isAtomberg ? 90.0 : 95.0)),
    runningPackingCost: Number(initialParams.runningPackingCost ?? product.packingCost ?? 0),
    runningTransportCost: Number(initialParams.runningTransportCost ?? product.transportCost ?? 0.62),
    runningOtherCost: Number(initialParams.runningOtherCost ?? product.otherCost ?? 0.00),

    runningHaierOverheadPackage: Number(initialParams.runningHaierOverheadPackage ?? product.haierOverheadPackage ?? 0),
    runningFoamPolybag: Number(initialParams.runningFoamPolybag ?? product.foamPolybag ?? 0),
    runningPlasticBin: Number(initialParams.runningPlasticBin ?? product.plasticBin ?? 0),
    runningFreightCost: Number(initialParams.runningFreightCost ?? product.freightCost ?? 0),
    runningSecondaryOp1: Number(initialParams.runningSecondaryOp1 ?? product.secondaryOp1 ?? 0),
    runningSecondaryOp2: Number(initialParams.runningSecondaryOp2 ?? product.secondaryOp2 ?? 0),
    runningScreenPrint1: Number(initialParams.runningScreenPrint1 ?? product.screenPrint1 ?? 0),
    runningScreenPrint2: Number(initialParams.runningScreenPrint2 ?? product.screenPrint2 ?? 0),
    runningAssemblyCost: Number(initialParams.runningAssemblyCost ?? product.assemblyCost ?? 0),
    runningMouldMaintenance: Number(initialParams.runningMouldMaintenance ?? product.mouldMaintenance ?? 0),
    runningQualityInspection: Number(initialParams.runningQualityInspection ?? product.qualityInspection ?? 0),
    runningIccReduce: Number(initialParams.runningIccReduce ?? product.iccReduce ?? 0),
    runningScrapAdj: Number(initialParams.runningScrapAdj ?? product.scrapAdj ?? 0)
  });

  // Calculate Atomberg Cost
  const atombergBaseCalc = calculateAtombergCost({
    rmBase: approvedRmRate,
    mbBase: approvedMbRate,
    mbPct: formData.masterbatchPct,
    partWt: formData.netWeight || formData.partWeight,
    runnerWt: formData.runnerWeight,
    cavity: formData.cavity,
    shiftTariff: formData.shiftTariff,
    cycleTime: formData.cycleTimeApproved,
    efficiencyPct: formData.efficiencyPct,
    tonnage: formData.tonnage,
    bopCost: formData.bopCost,
    postOpCost: formData.postOpCost,
    packingCost: formData.packingCost,
    transportCost: formData.transportCost !== undefined ? formData.transportCost : (formData.freightCost || 0),
    otherCost: formData.otherCost
  });

  const atombergRunningCalc = calculateAtombergCost({
    rmBase: runningRmWaRate,
    mbBase: runningMbWaRate,
    mbPct: formData.runningMbPct,
    partWt: formData.runningNetWeight || formData.runningPartWeight || formData.netWeight,
    runnerWt: formData.runningRunnerWeight,
    cavity: formData.runningCavity,
    shiftTariff: formData.runningShiftTariff,
    cycleTime: formData.runningCycleTime,
    efficiencyPct: formData.runningEfficiencyPct,
    tonnage: formData.runningTonnage || formData.tonnage,
    bopCost: formData.runningBopCost !== undefined ? formData.runningBopCost : formData.bopCost,
    postOpCost: formData.runningPostOpCost !== undefined ? formData.runningPostOpCost : (formData.postOpCost !== undefined ? formData.postOpCost : 0),
    packingCost: formData.runningPackingCost !== undefined ? formData.runningPackingCost : formData.packingCost,
    transportCost: formData.runningTransportCost !== undefined ? formData.runningTransportCost : (formData.runningFreightCost || formData.transportCost || 0),
    otherCost: formData.runningOtherCost !== undefined ? formData.runningOtherCost : formData.otherCost
  });

  // Calculate Haier Cost
  const haierBaseCalc = calculateHaierCost({
      runnerRecoveryOption: formData.runnerRecoveryOption || 'opt2',
    cavity: formData.cavity,
    netWeight: formData.netWeight || formData.partWeight,
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
      runnerRecoveryOption: formData.runnerRecoveryOption || 'opt2',
    cavity: formData.runningCavity,
    netWeight: formData.runningNetWeight || formData.runningPartWeight || formData.netWeight,
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
    secondaryOp2: formData.secondaryOp2,
    screenPrint1: formData.runningScreenPrint1,
    screenPrint2: formData.screenPrint2,
    assemblyCost: formData.runningAssemblyCost,
    bopCost: formData.runningBopCost,
    mouldMaintenance: formData.runningMouldMaintenance,
    qualityInspection: formData.runningQualityInspection,
    iccReduce: formData.runningIccReduce,
    scrapAdj: formData.runningScrapAdj
  });

  const contractTotal = isHaier ? haierBaseCalc.totalCost : atombergBaseCalc.finalLanded;
  const runningTotal = isHaier ? haierRunningCalc.totalCost : atombergRunningCalc.finalLanded;
  const profitLossDelta = Number((Number(contractTotal  || 0) - Number( runningTotal || 0)).toFixed(2));

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
      netWeight: formData.netWeight || formData.partWeight,
      runnerWeight: formData.runnerWeight,
      approvedRmPrice: approvedRmRate,
      approvedMbPrice: approvedMbRate,
      packingCost: formData.packingCost,
      transportCost: formData.transportCost,
      otherCost: formData.otherCost,
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
        postOpCost: formData.postOpCost,
        runningPostOpCost: formData.runningPostOpCost,
        runningOtherCost: formData.runningOtherCost,
        runningHaierOverheadPackage: formData.runningHaierOverheadPackage,
        runningFoamPolybag: formData.runningFoamPolybag,
        runningPlasticBin: formData.runningPlasticBin,
        runningFreightCost: formData.runningFreightCost,
        runningSecondaryOp1: formData.runningSecondaryOp1,
        runningSecondaryOp2: formData.secondaryOp2,
        runningScreenPrint1: formData.runningScreenPrint1,
        runningScreenPrint2: formData.screenPrint2,
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
            /* ATOMBERG 38-LINE COMPLETE TABLE (ROWS 1 TO 38) */
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
                  <td className="py-1.5 px-3 text-right font-mono font-bold">₹{(Number(approvedRmRate  || 0) - Number( runningRmWaRate || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">6</td>
                  <td className="py-1.5 px-3 text-slate-700">RM ICC (1%)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.rmIcc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.rmIcc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.rmIcc  || 0) - Number( atombergRunningCalc.rmIcc || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                  <td className="py-1.5 px-3 text-slate-700">RM Freight</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(formData.rmFreight || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(formData.runningRmFreight || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.rmFreight  || 0) - Number( formData.runningRmFreight || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                  <td className="py-1.5 px-3 text-slate-900">RM Landed Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(atombergBaseCalc.rmLanded || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(atombergRunningCalc.rmLanded || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.rmLanded  || 0) - Number( atombergRunningCalc.rmLanded || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                  <td className="py-1.5 px-3 text-slate-700">MB Base Rate (From RM Matrix)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{approvedMbRate.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{runningMbWaRate.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(approvedMbRate  || 0) - Number( runningMbWaRate || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">10</td>
                  <td className="py-1.5 px-3 text-slate-700">MB ICC (1%)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.mbIcc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.mbIcc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.mbIcc  || 0) - Number( atombergRunningCalc.mbIcc || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                  <td className="py-1.5 px-3 text-slate-700">MB Freight</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(formData.mbFreight || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(formData.runningMbFreight || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.mbFreight  || 0) - Number( formData.runningMbFreight || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">12</td>
                  <td className="py-1.5 px-3 text-slate-900">MB Landed Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(atombergBaseCalc.mbLanded || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(atombergRunningCalc.mbLanded || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.mbLanded  || 0) - Number( atombergRunningCalc.mbLanded || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-purple-50/40">
                  <td className="py-1.5 px-3 font-mono text-slate-500">13</td>
                  <td className="py-1.5 px-3 font-bold text-purple-900">MB %</td>
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
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.masterbatchPct  || 0) - Number( formData.runningMbPct || 0)).toFixed(1)}%</td>
                </tr>
                <tr className="bg-amber-50/50">
                  <td className="py-1.5 px-3 font-mono text-slate-500">14</td>
                  <td className="py-1.5 px-3 font-semibold text-amber-950">Runner recovery % (50%)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-amber-900">-₹{Number(haierBaseCalc.runnerRecoveryPct || 0).toFixed(4)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">-₹{Number(haierRunningCalc.runnerRecoveryPct || 0).toFixed(4)}</td>
                  <td className="py-1.5 px-3 text-right font-mono font-bold text-slate-700">₹{((haierBaseCalc.runnerRecoveryPct || 0) - (haierRunningCalc.runnerRecoveryPct || 0)).toFixed(4)}</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">14</td>
                  <td className="py-1.5 px-3 text-slate-900">Blended RM Rate</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">₹/kg</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(atombergBaseCalc.blendedRmRate || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(atombergRunningCalc.blendedRmRate || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.blendedRmRate  || 0) - Number( atombergRunningCalc.blendedRmRate || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">15</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">Part weight grams</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.partWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningPartWeight}g</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningPartWeight} onChange={e => setFormData({ ...formData, runningPartWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.partWeight  || 0) - Number( formData.runningPartWeight || 0)).toFixed(2)}g</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">16</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">Runner weight grams</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right">{readOnly ? <span className="font-mono">{formData.runnerWeight}g</span> : <input type="number" value={formData.runnerWeight} onChange={e => setFormData({...formData, runnerWeight: Number(e.target.value) || 0})} className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-800 bg-amber-50/50 focus:bg-white" />}</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningRunnerWeight}g</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningRunnerWeight} onChange={e => setFormData({ ...formData, runningRunnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.runnerWeight  || 0) - Number( formData.runningRunnerWeight || 0)).toFixed(2)}g</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">17</td>
                  <td className="py-1.5 px-3">Gross Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{Number(atombergBaseCalc.grossWt || 0).toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{Number(atombergRunningCalc.grossWt || 0).toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(atombergBaseCalc.grossWt  || 0) - Number( atombergRunningCalc.grossWt || 0)).toFixed(2)}g</td>
                </tr>
                <tr className="bg-emerald-50/40 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                  <td className="py-1.5 px-3 text-emerald-950">RM cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-900">₹{Number(atombergBaseCalc.rmCostPerPc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{Number(atombergRunningCalc.rmCostPerPc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.rmCostPerPc  || 0) - Number( atombergRunningCalc.rmCostPerPc || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">19</td>
                  <td className="py-1.5 px-3 text-slate-700">BOP Cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(formData.bopCost || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(formData.runningBopCost || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.bopCost  || 0) - Number( formData.runningBopCost || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-50 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                  <td className="py-1.5 px-3 text-slate-900">RM + BOP</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono text-slate-900">₹{Number(atombergBaseCalc.rmPlusBop || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-900">₹{Number(atombergRunningCalc.rmPlusBop || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.rmPlusBop  || 0) - Number( atombergRunningCalc.rmPlusBop || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                  <td className="py-1.5 px-3">Tonnage</td>
                  <td className="py-1.5 px-3 text-center">T</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.machineTonnage}T</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.machineTonnage}T</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">22</td>
                    <td className="py-1.5 px-3 font-bold text-slate-800">Shift rate</td>
                    <td className="py-1.5 px-3 text-center text-xs text-slate-500">₹/shift</td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-slate-800">₹{formData.shiftTariff}</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.shiftTariff} 
                          onChange={e => setFormData({ ...formData, shiftTariff: Number(e.target.value) || 0 })} 
                          className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-800 bg-amber-50/50 focus:bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-blue-800">₹{formData.runningShiftTariff}</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.runningShiftTariff} 
                          onChange={e => setFormData({ ...formData, runningShiftTariff: Number(e.target.value) || 0 })} 
                          className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-3 text-right font-mono font-bold text-slate-700">₹{(Number(formData.shiftTariff  || 0) - Number( formData.runningShiftTariff || 0)).toFixed(2)}</td>
                  </tr>
                  <tr className="bg-amber-50/40">
                    <td className="py-1.5 px-3 font-mono text-slate-500">23</td>
                    <td className="py-1.5 px-3 font-black text-amber-950">Cycle time (seconds)</td>
                    <td className="py-1.5 px-3 text-center text-xs text-slate-500">Sec</td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-amber-950">{formData.cycleTimeApproved}s</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.cycleTimeApproved} 
                          onChange={e => setFormData({ ...formData, cycleTimeApproved: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-amber-950 bg-amber-50/50 focus:bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-blue-800">{formData.runningCycleTime}s</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.runningCycleTime} 
                          onChange={e => setFormData({ ...formData, runningCycleTime: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-3 text-right font-mono font-bold text-slate-700">{(Number(formData.cycleTimeApproved  || 0) - Number( formData.runningCycleTime || 0)).toFixed(1)}s</td>
                  </tr>
                  <tr>
                    <td className="py-1.5 px-3 font-mono text-slate-500">24</td>
                    <td className="py-1.5 px-3 font-semibold text-slate-800">Machine Efficiency %</td>
                    <td className="py-1.5 px-3 text-center text-xs text-slate-500">%</td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-mono">{formData.efficiencyPct}%</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.efficiencyPct} 
                          onChange={e => setFormData({ ...formData, efficiencyPct: Number(e.target.value) || 0 })} 
                          className="w-16 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-800 bg-amber-50/50 focus:bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-mono text-blue-800">{formData.runningEfficiencyPct}%</span>
                      ) : (
                        <input 
                          type="number" 
                          value={formData.runningEfficiencyPct} 
                          onChange={e => setFormData({ ...formData, runningEfficiencyPct: Number(e.target.value) || 0 })} 
                          className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-3 text-right font-mono font-bold text-slate-700">{(Number(formData.efficiencyPct  || 0) - Number( formData.runningEfficiencyPct || 0)).toFixed(1)}%</td>
                  </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                  <td className="py-1.5 px-3 font-semibold text-slate-800">No of cavity</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-bold">{formData.cavity}</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningCavity}</span>
                    ) : (
                      <input type="number" value={formData.runningCavity} onChange={e => setFormData({ ...formData, runningCavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{formData.cavity - formData.runningCavity}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">26</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">Parts/shift</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{Number(atombergBaseCalc.partsPerShift || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">{Number(atombergRunningCalc.partsPerShift || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(atombergBaseCalc.partsPerShift  || 0) - Number( atombergRunningCalc.partsPerShift || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">27</td>
                  <td className="py-1.5 px-3">Process cost / pc</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.processCostPerPc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.processCostPerPc || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.processCostPerPc  || 0) - Number( atombergRunningCalc.processCostPerPc || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">28</td>
                  <td className="py-1.5 px-3 text-slate-700">Handling BOP (3%)</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.handlingBop || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.handlingBop || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">29</td>
                    <td className="py-1.5 px-3 font-bold text-slate-800">Post Operation Cost</td>
                    <td className="py-1.5 px-3 text-center text-xs text-slate-500">₹/pc</td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-slate-800">₹{Number(formData.postOpCost || 0).toFixed(2)}</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.01"
                          value={formData.postOpCost} 
                          onChange={e => setFormData({ ...formData, postOpCost: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold text-slate-800 bg-amber-50/50 focus:bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-blue-800">₹{Number(formData.runningPostOpCost || 0).toFixed(2)}</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.01"
                          value={formData.runningPostOpCost} 
                          onChange={e => setFormData({ ...formData, runningPostOpCost: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                        />
                      )}
                    </td>
                    <td className="py-1.5 px-3 text-right font-mono font-bold text-slate-700">
                      ₹{(Number(formData.postOpCost || 0) - Number(formData.runningPostOpCost || 0)).toFixed(2)}
                    </td>
                  </tr>
                <tr className="bg-slate-100 font-bold">
                  <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                  <td className="py-1.5 px-3">Total Process Cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">₹{Number(atombergBaseCalc.totalProcessCost || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-blue-900">₹{Number(atombergRunningCalc.totalProcessCost || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.totalProcessCost  || 0) - Number( atombergRunningCalc.totalProcessCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">31</td>
                  <td className="py-1.5 px-3">OH & Profit (12%)</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.ohAndProfit || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.ohAndProfit || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.ohAndProfit  || 0) - Number( atombergRunningCalc.ohAndProfit || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">32</td>
                  <td className="py-1.5 px-3">In-process rejection (4%)</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.inProcessRejection || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.inProcessRejection || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.inProcessRejection  || 0) - Number( atombergRunningCalc.inProcessRejection || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">33</td>
                  <td className="py-1.5 px-3 font-medium text-emerald-800">Runner Recovery Credit (-₹25/kg)</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono text-emerald-800">-₹{Number(atombergBaseCalc.runnerRecoveryCredit || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-emerald-800">-₹{Number(atombergRunningCalc.runnerRecoveryCredit || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">34</td>
                  <td className="py-1.5 px-3">Packing Cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">₹{Number(formData.packingCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.packingCost} 
                        onChange={e => setFormData({ ...formData, packingCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">₹{Number(formData.runningPackingCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.runningPackingCost} 
                        onChange={e => setFormData({ ...formData, runningPackingCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.packingCost  || 0) - Number( formData.runningPackingCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">35</td>
                  <td className="py-1.5 px-3">Transport Cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">₹{Number(formData.transportCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.transportCost} 
                        onChange={e => setFormData({ ...formData, transportCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">₹{Number(formData.runningTransportCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.runningTransportCost} 
                        onChange={e => setFormData({ ...formData, runningTransportCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.transportCost  || 0) - Number( formData.runningTransportCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">36</td>
                  <td className="py-1.5 px-3">Mould maintenance (2% Process)</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right font-mono">₹{Number(atombergBaseCalc.mouldMaintenance || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{Number(atombergRunningCalc.mouldMaintenance || 0).toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(atombergBaseCalc.mouldMaintenance  || 0) - Number( atombergRunningCalc.mouldMaintenance || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">37</td>
                  <td className="py-1.5 px-3">Other Cost</td>
                  <td className="py-1.5 px-3 text-center">₹/pc</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">₹{Number(formData.otherCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.otherCost} 
                        onChange={e => setFormData({ ...formData, otherCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white text-slate-900" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">₹{Number(formData.runningOtherCost || 0).toFixed(2)}</span>
                    ) : (
                      <input 
                        type="number" 
                        step="0.01" 
                        value={formData.runningOtherCost} 
                        onChange={e => setFormData({ ...formData, runningOtherCost: Number(e.target.value) || 0 })} 
                        className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                      />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.otherCost  || 0) - Number( formData.runningOtherCost || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-900 text-white font-black text-xs">
                  <td className="py-3 px-3 font-mono text-amber-400">38</td>
                  <td className="py-3 px-3 uppercase text-amber-400">FINAL LANDED COST / PC</td>
                  <td className="py-3 px-3 text-center">₹/pc</td>
                  <td className="py-3 px-4 text-right font-mono text-amber-300 text-sm">₹{Number(atombergBaseCalc.finalLanded || 0).toFixed(2)}</td>
                  <td className="py-3 px-4 text-right font-mono text-emerald-400 text-sm">₹{Number(atombergRunningCalc.finalLanded || 0).toFixed(2)}</td>
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
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.masterbatchPct  || 0) - Number( formData.runningMbPct || 0)).toFixed(1)}%</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">No. of Cavity</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-bold">{formData.cavity}</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningCavity}</span>
                    ) : (
                      <input type="number" value={formData.runningCavity} onChange={e => setFormData({ ...formData, runningCavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{formData.cavity - formData.runningCavity}</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                  <td className="py-1.5 px-3">Runner Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.runnerWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningRunnerWeight}g</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningRunnerWeight} onChange={e => setFormData({ ...formData, runningRunnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.runnerWeight  || 0) - Number( formData.runningRunnerWeight || 0)).toFixed(2)}g</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">9</td>
                  <td className="py-1.5 px-3 font-bold">Net Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.partWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningPartWeight}g</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningPartWeight} onChange={e => setFormData({ ...formData, runningPartWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.partWeight  || 0) - Number( formData.runningPartWeight || 0)).toFixed(2)}g</td>
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
                  <td className="py-1.5 px-3 font-bold text-slate-900">
                    <div className="flex items-center gap-2">
                      <span>Reconciliation Weight = Shot wt +</span>
                      {readOnly ? (
                        <span className="font-bold text-amber-950">{formData.meltLossPct}%</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.1" 
                          value={formData.meltLossPct} 
                          onChange={e => { const val = Number(e.target.value) || 0; setFormData({ ...formData, meltLossPct: val, runningMeltLossPct: val }); }} 
                          className="w-14 px-1.5 py-0.5 border border-amber-400 rounded text-center font-bold bg-white text-slate-900 text-xs" 
                        />
                      )}
                      <span>% Melt Loss</span>
                    </div>
                  </td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{Number(haierBaseCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-600">{Number(haierRunningCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(haierBaseCalc.reconciliationWeight  || 0) - Number( haierRunningCalc.reconciliationWeight || 0)).toFixed(2)}g</td>
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
                <tr className="bg-amber-50/70 border-y border-amber-200">
                  <td className="py-2 px-3 font-mono text-slate-500 text-xs">14</td>
                  <td className="py-2 px-3">
                    <div className="flex flex-col gap-1">
                      <div className="font-bold text-amber-950 flex items-center gap-2 text-xs">
                        <span>Runner Recovery (50%)</span>
                        <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-200/60 font-mono text-amber-900">
                          {formData.runnerRecoveryOption === 'opt1' ? 'Option 1: Total' : 'Option 2: Per Cavity'}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 pt-0.5">
                        <label className="inline-flex items-center gap-1 text-[11px] text-slate-700 cursor-pointer">
                          <input 
                            type="radio" 
                            name="runnerRecOpt" 
                            value="opt2"
                            checked={formData.runnerRecoveryOption === 'opt2' || formData.runnerRecoveryOption === 2 || !formData.runnerRecoveryOption}
                            onChange={() => setFormData(prev => ({ ...prev, runnerRecoveryOption: 'opt2' }))}
                            className="w-3 h-3 text-blue-600 focus:ring-0 cursor-pointer"
                          />
                          <span>Opt 2: <span className="font-mono text-slate-500">(Runner / Cavity / 1000) * RM * 50%</span></span>
                        </label>
                        <label className="inline-flex items-center gap-1 text-[11px] text-slate-700 cursor-pointer">
                          <input 
                            type="radio" 
                            name="runnerRecOpt" 
                            value="opt1"
                            checked={formData.runnerRecoveryOption === 'opt1'}
                            onChange={() => setFormData(prev => ({ ...prev, runnerRecoveryOption: 'opt1' }))}
                            className="w-3 h-3 text-blue-600 focus:ring-0 cursor-pointer"
                          />
                          <span>Opt 1: <span className="font-mono text-slate-500">(Runner / 1000) * RM * 50%</span></span>
                        </label>
                      </div>
                    </div>
                  </td>
                  <td className="py-2 px-3 text-center font-mono text-xs text-slate-500">Rs</td>
                  <td className="py-2 px-4 text-right font-mono font-bold text-rose-600">
                    -₹{Number(haierBaseCalc?.runnerRecoveryCost || 0).toFixed(4)}
                  </td>
                  <td className="py-2 px-4 text-right font-mono font-bold text-rose-600">
                    -₹{Number(haierRunningCalc?.runnerRecoveryCost || 0).toFixed(4)}
                  </td>
                  <td className="py-2 px-3 text-right font-mono font-bold text-slate-700">
                    ₹{Number((haierBaseCalc?.runnerRecoveryCost || 0) - (haierRunningCalc?.runnerRecoveryCost || 0)).toFixed(4)}
                  </td>
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
                    {readOnly ? (
                      <span className="font-bold">₹{formData.shiftTariff}</span>
                    ) : (
                      <input type="number" value={formData.shiftTariff} onChange={e => setFormData({ ...formData, shiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">₹{formData.runningShiftTariff}</span>
                    ) : (
                      <input type="number" value={formData.runningShiftTariff} onChange={e => setFormData({ ...formData, runningShiftTariff: Number(e.target.value) || 0 })} className="w-24 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.shiftTariff  || 0) - Number( formData.runningShiftTariff || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">18</td>
                  <td className="py-1.5 px-3 font-bold">Cycle Time</td>
                  <td className="py-1.5 px-3 text-center">Sec</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.cycleTimeApproved}s</span>
                    ) : (
                      <input type="number" value={formData.cycleTimeApproved} onChange={e => setFormData({ ...formData, cycleTimeApproved: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-amber-300 rounded text-right font-bold bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningCycleTime}s</span>
                    ) : (
                      <input type="number" value={formData.runningCycleTime} onChange={e => setFormData({ ...formData, runningCycleTime: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(formData.cycleTimeApproved  || 0) - Number( formData.runningCycleTime || 0)).toFixed(1)}s</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">19</td>
                  <td className="py-1.5 px-3">No of Shot / Shift (8Hour)</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono">{haierBaseCalc.shotsShift8h}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{haierRunningCalc.shotsShift8h}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(haierBaseCalc.shotsShift8h  || 0) - Number( haierRunningCalc.shotsShift8h || 0)).toFixed(2)}</td>
                </tr>
                <tr className="bg-slate-50">
                  <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">
                    <div className="flex items-center gap-2">
                      <span>No of Shot / Shift with</span>
                      {readOnly ? (
                        <span className="font-bold text-amber-950">{formData.efficiencyPct}%</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.1" 
                          value={formData.efficiencyPct} 
                          onChange={e => { const val = Number(e.target.value) || 0; setFormData({ ...formData, efficiencyPct: val, runningEfficiencyPct: val }); }} 
                          className="w-14 px-1.5 py-0.5 border border-amber-400 rounded text-center font-bold bg-white text-slate-900 text-xs" 
                        />
                      )}
                      <span>% Efficiency</span>
                    </div>
                  </td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">{haierBaseCalc.shotsShiftEfficiency}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{haierRunningCalc.shotsShiftEfficiency}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(haierBaseCalc.shotsShiftEfficiency  || 0) - Number( haierRunningCalc.shotsShiftEfficiency || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                  <td className="py-1.5 px-3">No. of component / shift</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{haierBaseCalc.partsPerShift}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{haierRunningCalc.partsPerShift}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(Number(haierBaseCalc.partsPerShift  || 0) - Number( haierRunningCalc.partsPerShift || 0)).toFixed(2)}</td>
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
                    {readOnly ? (
                      <span className="font-bold text-purple-900">₹{Number(formData.haierOverheadPackage || 0).toFixed(4)}</span>
                    ) : (
                      <input type="number" step="0.0001" value={formData.haierOverheadPackage} onChange={e => setFormData({ ...formData, haierOverheadPackage: Number(e.target.value) || 0 })} className="w-28 px-2 py-0.5 border border-purple-300 rounded text-right font-bold text-purple-900 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">₹{Number(formData.runningHaierOverheadPackage || 0).toFixed(4)}</span>
                    ) : (
                      <input type="number" step="0.0001" value={formData.runningHaierOverheadPackage} onChange={e => setFormData({ ...formData, runningHaierOverheadPackage: Number(e.target.value) || 0 })} className="w-28 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹0.00</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                  <td className="py-1.5 px-3 font-medium">Foam / Polybag / Masking film</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.foamPolybag > 0 ? `₹${Number(formData.foamPolybag || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.foamPolybag} onChange={e => setFormData({ ...formData, foamPolybag: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningFoamPolybag > 0 ? `₹${Number(formData.runningFoamPolybag || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningFoamPolybag} onChange={e => setFormData({ ...formData, runningFoamPolybag: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.foamPolybag  || 0) - Number( formData.runningFoamPolybag || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">26</td>
                  <td className="py-1.5 px-3 font-medium">Plastic Bin / Polyend Box / Trolley</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.plasticBin > 0 ? `₹${Number(formData.plasticBin || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.plasticBin} onChange={e => setFormData({ ...formData, plasticBin: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningPlasticBin > 0 ? `₹${Number(formData.runningPlasticBin || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningPlasticBin} onChange={e => setFormData({ ...formData, runningPlasticBin: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.plasticBin  || 0) - Number( formData.runningPlasticBin || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">27</td>
                  <td className="py-1.5 px-3 font-medium">Freight Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold">{Number(formData.freightCost || 0) > 0 ? `₹${Number(formData.freightCost || 0).toFixed(2)}` : '-'}</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.01" 
                          value={formData.freightCost} 
                          onChange={e => setFormData({ ...formData, freightCost: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" 
                        />
                      )}</td>
                  <td className="py-1.5 px-4 text-right">
                      {readOnly ? (
                        <span className="font-bold text-blue-800">{Number(formData.runningFreightCost || 0) > 0 ? `₹${Number(formData.runningFreightCost || 0).toFixed(2)}` : '-'}</span>
                      ) : (
                        <input 
                          type="number" 
                          step="0.01" 
                          value={formData.runningFreightCost} 
                          onChange={e => setFormData({ ...formData, runningFreightCost: Number(e.target.value) || 0 })} 
                          className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" 
                        />
                      )}</td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.freightCost  || 0) - Number( formData.runningFreightCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">28</td>
                  <td className="py-1.5 px-3 font-medium">Secondary Operation 1</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.secondaryOp1 > 0 ? `₹${Number(formData.secondaryOp1 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.secondaryOp1} onChange={e => setFormData({ ...formData, secondaryOp1: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningSecondaryOp1 > 0 ? `₹${Number(formData.runningSecondaryOp1 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningSecondaryOp1} onChange={e => setFormData({ ...formData, runningSecondaryOp1: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.secondaryOp1  || 0) - Number( formData.runningSecondaryOp1 || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">29</td>
                  <td className="py-1.5 px-3 font-medium">Secondary Operation 2</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.secondaryOp2 > 0 ? `₹${Number(formData.secondaryOp2 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.secondaryOp2} onChange={e => setFormData({ ...formData, secondaryOp2: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningSecondaryOp2 > 0 ? `₹${Number(formData.runningSecondaryOp2 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningSecondaryOp2} onChange={e => setFormData({ ...formData, runningSecondaryOp2: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.secondaryOp2  || 0) - Number( formData.runningSecondaryOp2 || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                  <td className="py-1.5 px-3 font-medium">Screen printing - 1st stroke</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.screenPrint1 !== 0 ? `₹${Number(formData.screenPrint1 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.screenPrint1} onChange={e => setFormData({ ...formData, screenPrint1: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningScreenPrint1 !== 0 ? `₹${Number(formData.runningScreenPrint1 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningScreenPrint1} onChange={e => setFormData({ ...formData, runningScreenPrint1: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.screenPrint1  || 0) - Number( formData.runningScreenPrint1 || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">31</td>
                  <td className="py-1.5 px-3 font-medium">Screen printing - 2nd stroke</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.screenPrint2 !== 0 ? `₹${Number(formData.screenPrint2 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.screenPrint2} onChange={e => setFormData({ ...formData, screenPrint2: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningScreenPrint2 !== 0 ? `₹${Number(formData.runningScreenPrint2 || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningScreenPrint2} onChange={e => setFormData({ ...formData, runningScreenPrint2: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.screenPrint2  || 0) - Number( formData.runningScreenPrint2 || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">32</td>
                  <td className="py-1.5 px-3 font-medium">Assembly Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.assemblyCost > 0 ? `₹${Number(formData.assemblyCost || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.assemblyCost} onChange={e => setFormData({ ...formData, assemblyCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningAssemblyCost > 0 ? `₹${Number(formData.runningAssemblyCost || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningAssemblyCost} onChange={e => setFormData({ ...formData, runningAssemblyCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.assemblyCost  || 0) - Number( formData.runningAssemblyCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">33</td>
                  <td className="py-1.5 px-3 font-medium">Insert / Hinge hole cap cost / Other cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.bopCost > 0 ? `₹${Number(formData.bopCost || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.bopCost} onChange={e => setFormData({ ...formData, bopCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningBopCost > 0 ? `₹${Number(formData.runningBopCost || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningBopCost} onChange={e => setFormData({ ...formData, runningBopCost: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.bopCost  || 0) - Number( formData.runningBopCost || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">34</td>
                  <td className="py-1.5 px-3 font-medium">Mould Maintenance Provision</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.mouldMaintenance > 0 ? `₹${Number(formData.mouldMaintenance || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.mouldMaintenance} onChange={e => setFormData({ ...formData, mouldMaintenance: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningMouldMaintenance > 0 ? `₹${Number(formData.runningMouldMaintenance || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningMouldMaintenance} onChange={e => setFormData({ ...formData, runningMouldMaintenance: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.mouldMaintenance  || 0) - Number( formData.runningMouldMaintenance || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">35</td>
                  <td className="py-1.5 px-3 font-medium">Quality Inspection Cost</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.qualityInspection > 0 ? `₹${Number(formData.qualityInspection || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.qualityInspection} onChange={e => setFormData({ ...formData, qualityInspection: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningQualityInspection > 0 ? `₹${Number(formData.runningQualityInspection || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningQualityInspection} onChange={e => setFormData({ ...formData, runningQualityInspection: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.qualityInspection  || 0) - Number( formData.runningQualityInspection || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">36</td>
                  <td className="py-1.5 px-3 font-medium">ICC Reduce by .5% (Payment term change 60 to 45 days)</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">-</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-emerald-700">{formData.iccReduce !== 0 ? `₹${Number(formData.iccReduce || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.iccReduce} onChange={e => setFormData({ ...formData, iccReduce: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-emerald-700">{formData.runningIccReduce !== 0 ? `₹${Number(formData.runningIccReduce || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningIccReduce} onChange={e => setFormData({ ...formData, runningIccReduce: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.iccReduce  || 0) - Number( formData.runningIccReduce || 0)).toFixed(2)}</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">37</td>
                  <td className="py-1.5 px-3 font-medium">Scrap Recovery Adjustment</td>
                  <td className="py-1.5 px-3 text-center text-slate-600">Rs</td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold">{formData.scrapAdj !== 0 ? `₹${Number(formData.scrapAdj || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.scrapAdj} onChange={e => setFormData({ ...formData, scrapAdj: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-slate-300 rounded text-right font-bold bg-white text-slate-900" />
                    )}
                  </td>
                  <td className="py-1.5 px-4 text-right">
                    {readOnly ? (
                      <span className="font-bold text-blue-800">{formData.runningScrapAdj !== 0 ? `₹${Number(formData.runningScrapAdj || 0).toFixed(2)}` : '-'}</span>
                    ) : (
                      <input type="number" step="0.01" value={formData.runningScrapAdj} onChange={e => setFormData({ ...formData, runningScrapAdj: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                    )}
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">₹{(Number(formData.scrapAdj  || 0) - Number( formData.runningScrapAdj || 0)).toFixed(2)}</td>
                </tr>

                <tr className="bg-slate-900 text-white font-black text-xs">
                  <td className="py-3 px-3 font-mono text-amber-400">38</td>
                  <td className="py-3 px-3 uppercase text-amber-400">TOTAL COST</td>
                  <td className="py-3 px-3 text-center">Rs</td>
                  <td className="py-3 px-4 text-right font-mono text-amber-300 text-sm">₹{Number(haierBaseCalc.totalCost || 0).toFixed(2)}</td>
                  <td className="py-3 px-4 text-right font-mono text-emerald-400 text-sm">₹{Number(haierRunningCalc.totalCost || 0).toFixed(2)}</td>
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

export function calculateDetailedCost(product) {
  if (!product) return { approvedBaselineCost: 0, simulatedActualCost: 0, totalCost: 0, finalLanded: 0, delta: 0 };
  
  const isHaier = (product.vendor || '').toLowerCase().includes('haier');
  const isAtomberg = (product.vendor || '').toLowerCase().includes('atomberg');
  const params = product.parameters || {};

  const cleanMaterialStr = sanitizeMaterialName(product.approvedRm || product.baseRm, product.componentName, product.itemCode, product.vendor);
  const { baseRm, mbGrade } = parseMaterialString(cleanMaterialStr);
  const rmInfo = getActiveRmMapping(baseRm || product.baseRm || cleanMaterialStr, product.vendor) || {};
  const mbInfo = getActiveMbMapping(mbGrade || product.approvedMb, product.vendor) || {};

  const approvedRmRate = Number(product.approvedRmPrice || rmInfo.approvedPrice || (isAtomberg ? 131.00 : 154.00));
  const runningRmWaRate = Number(params.runningRmBaseRate ?? rmInfo.activeWaPrice ?? rmInfo.approvedPrice ?? approvedRmRate);

  const approvedMbRate = Number(product.approvedMbPrice || mbInfo.approvedMbPrice || (isAtomberg ? 154.00 : 242.00));
  const runningMbWaRate = Number(params.runningMbBaseRate ?? mbInfo.activeMbWaPrice ?? mbInfo.approvedMbPrice ?? approvedMbRate);

  if (isHaier) {
    const ctApp = Number(product.cycleTimeApproved) > 0 ? Number(product.cycleTimeApproved) : 70;
    const cavApp = Number(product.cavity) > 0 ? Number(product.cavity) : 1;
    const meltLossApp = Number(product.meltLossPct !== undefined ? product.meltLossPct : 1.0);
    const effApp = Number(product.efficiencyPct !== undefined ? product.efficiencyPct : 95.0);

    const baseCalc = calculateHaierCost({
      cavity: cavApp,
      netWeight: Number(product.netWeight || 372),
      runnerWeight: Number(product.runnerWeight || 0),
      shotWeight: Number(product.shotWeight || (Number(product.netWeight || 372) * cavApp)),
      meltLossPct: meltLossApp,
      efficiencyPct: effApp,
      rmRate: approvedRmRate,
      masterbatchPct: Number(product.masterbatchPct || 4),
      masterbatchRate: approvedMbRate,
      shiftTariff: Number(product.shiftTariff || 4800),
      cycleTime: ctApp,
      haierOverheadPackage: Number(product.haierOverheadPackage !== undefined ? product.haierOverheadPackage : 0),
      foamPolybag: Number(product.foamPolybag || 0),
      plasticBin: Number(product.plasticBin || 0),
      freightCost: Number(product.freightCost || 0),
      secondaryOp1: Number(product.secondaryOp1 || 0),
      secondaryOp2: Number(product.secondaryOp2 || 0),
      screenPrint1: Number(product.screenPrint1 || 0),
      screenPrint2: Number(product.screenPrint2 || 0),
      assemblyCost: Number(product.assemblyCost || 0),
      bopCost: Number(product.bopCost || 0),
      mouldMaintenance: Number(product.mouldMaintenance || 0),
      qualityInspection: Number(product.qualityInspection || 0),
      iccReduce: Number(product.iccReduce || 0),
      scrapAdj: Number(product.scrapAdj || 0)
    });

    const ctRun = Number(params.runningCycleTime ?? product.cycleTimeApproved ?? 70);
    const cavRun = Number(params.runningCavity ?? product.cavity ?? 1);
    const meltLossRun = Number(params.runningMeltLossPct ?? product.meltLossPct ?? 1.0);
    const effRun = Number(params.runningEfficiencyPct ?? product.efficiencyPct ?? 95.0);

    const runningCalc = calculateHaierCost({
      cavity: cavRun,
      netWeight: Number(params.runningNetWeight ?? product.netWeight ?? 372),
      runnerWeight: Number(params.runningRunnerWeight ?? product.runnerWeight ?? 0),
      shotWeight: Number(params.runningNetWeight ?? product.netWeight ?? 372) * cavRun + Number(params.runningRunnerWeight ?? product.runnerWeight ?? 0),
      meltLossPct: meltLossRun,
      efficiencyPct: effRun,
      rmRate: runningRmWaRate,
      masterbatchPct: Number(params.runningMbPct ?? product.masterbatchPct ?? 4),
      masterbatchRate: runningMbWaRate,
      shiftTariff: Number(params.runningShiftTariff ?? product.shiftTariff ?? 4800),
      cycleTime: ctRun,
      haierOverheadPackage: Number(params.runningHaierOverheadPackage ?? product.haierOverheadPackage ?? 0),
      foamPolybag: Number(params.runningFoamPolybag ?? product.foamPolybag ?? 0),
      plasticBin: Number(params.runningPlasticBin ?? product.plasticBin ?? 0),
      freightCost: Number(params.runningFreightCost ?? product.freightCost ?? 0),
      secondaryOp1: Number(params.runningSecondaryOp1 ?? product.secondaryOp1 ?? 0),
      secondaryOp2: Number(params.secondaryOp2 ?? product.secondaryOp2 ?? 0),
      screenPrint1: Number(params.runningScreenPrint1 ?? product.screenPrint1 ?? 0),
      screenPrint2: Number(params.screenPrint2 ?? product.screenPrint2 ?? 0),
      assemblyCost: Number(params.runningAssemblyCost ?? product.assemblyCost ?? 0),
      bopCost: Number(params.runningBopCost ?? product.bopCost ?? 0),
      mouldMaintenance: Number(params.runningMouldMaintenance ?? product.mouldMaintenance ?? 0),
      qualityInspection: Number(params.runningQualityInspection ?? product.qualityInspection ?? 0),
      iccReduce: Number(params.runningIccReduce ?? product.iccReduce ?? 0),
      scrapAdj: Number(params.runningScrapAdj ?? product.scrapAdj ?? 0)
    });

    const approvedBaselineCost = Number(product.approvedCost || baseCalc.totalCost || 0);
    const simulatedActualCost = Number(runningCalc.totalCost || approvedBaselineCost || 0);

    return {
      approvedBaselineCost,
      simulatedActualCost,
      totalCost: approvedBaselineCost,
      finalLanded: simulatedActualCost,
      delta: Number((Number(approvedBaselineCost  || 0) - Number( simulatedActualCost || 0)).toFixed(2))
    };
  } else {
    const baseCalc = calculateAtombergCost({
      rmBase: approvedRmRate,
      rmFreight: Number(product.rmFreight !== undefined ? product.rmFreight : 1.50),
      mbBase: approvedMbRate,
      mbFreight: Number(product.mbFreight !== undefined ? product.mbFreight : 2.00),
      partWt: Number(product.netWeight !== undefined ? product.netWeight : 37.00),
      runnerWt: Number(product.runnerWeight !== undefined ? product.runnerWeight : 1.00),
      mbPct: (Number(product.masterbatchPct !== undefined ? product.masterbatchPct : 4)) / 100,
      bopCost: Number(product.bopCost || 0),
      cycleTime: Number(product.cycleTimeApproved || 47),
      cavity: Number(product.cavity || 2),
      tonnage: Number(product.machineTonnage || 200),
      shiftTariff: Number(product.shiftTariff || 2000),
      efficiency: (Number(product.efficiencyPct !== undefined ? product.efficiencyPct : 90.0)) / 100,
      packingCost: Number(product.packingCost !== undefined ? product.packingCost : 0),
      transportCost: Number(product.transportCost !== undefined ? product.transportCost : 0.62),
      otherCost: Number(product.otherCost !== undefined ? product.otherCost : 0.00)
    });

    const runningCalc = calculateAtombergCost({
      rmBase: runningRmWaRate,
      rmFreight: Number(params.runningRmFreight ?? product.rmFreight ?? 1.50),
      mbBase: runningMbWaRate,
      mbFreight: Number(params.runningMbFreight ?? product.mbFreight ?? 2.00),
      partWt: Number(params.runningNetWeight ?? product.netWeight ?? 37.00),
      runnerWt: Number(params.runningRunnerWeight ?? product.runnerWeight ?? 1.00),
      mbPct: (Number(params.runningMbPct ?? product.masterbatchPct ?? 4)) / 100,
      bopCost: Number(params.runningBopCost ?? product.bopCost ?? 0),
      cycleTime: Number(params.runningCycleTime ?? product.cycleTimeApproved ?? 47),
      cavity: Number(params.runningCavity ?? product.cavity ?? 2),
      tonnage: Number(product.machineTonnage || 200),
      shiftTariff: Number(params.runningShiftTariff ?? product.shiftTariff ?? 2000),
      efficiency: (Number(params.runningEfficiencyPct ?? product.efficiencyPct ?? 90.0)) / 100,
      packingCost: Number(params.runningPackingCost ?? product.packingCost ?? 0.86),
      transportCost: Number(params.runningTransportCost ?? product.transportCost ?? 0.62),
      otherCost: Number(params.runningOtherCost ?? product.otherCost ?? 0.00)
    });

    const approvedBaselineCost = Number(product.approvedCost || baseCalc.finalLanded || 0);
    const simulatedActualCost = Number(runningCalc.finalLanded || approvedBaselineCost || 0);

    return {
      approvedBaselineCost,
      simulatedActualCost,
      totalCost: approvedBaselineCost,
      finalLanded: simulatedActualCost,
      delta: Number((Number(approvedBaselineCost  || 0) - Number( simulatedActualCost || 0)).toFixed(2))
    };
  }
}
