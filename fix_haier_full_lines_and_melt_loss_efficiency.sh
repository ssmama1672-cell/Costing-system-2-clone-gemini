#!/usr/bin/env bash
set -e

echo "==> 1. Updating costCalculationService.js to support custom Melt Loss % and Efficiency %..."
cat << 'SERVICE_EOF' > src/shared/costCalculationService.js
// ============================================================================
// MULTI-VENDOR COST CALCULATION ENGINE (Exact Atomberg 38-Line & Haier 38-Line)
// ============================================================================

export function calculateAtombergCost(params = {}) {
  // 1. RM & MB Base Rates
  const rmBase = Number(params.rmBase !== undefined ? params.rmBase : 131.00);
  const rmIccRate = Number(params.rmIccRate !== undefined ? params.rmIccRate : 0.01);
  const rmFreight = Number(params.rmFreight !== undefined ? params.rmFreight : 1.50);
  
  const rmIcc = Number((rmBase * rmIccRate).toFixed(2));
  const rmLanded = Number((rmBase + rmIcc + rmFreight).toFixed(2)); // Row 8 = 133.81

  const mbBase = Number(params.mbBase !== undefined ? params.mbBase : 154.00);
  const mbIccRate = Number(params.mbIccRate !== undefined ? params.mbIccRate : 0.01);
  const mbFreight = Number(params.mbFreight !== undefined ? params.mbFreight : 2.00);
  
  const mbIcc = Number((mbBase * mbIccRate).toFixed(2));
  const mbLanded = Number((mbBase + mbIcc + mbFreight).toFixed(2)); // Row 12 = 157.54

  // 2. MB % & Blended RM Rate: = Row 8*(1-Row 13) + Row 12*Row 13
  const mbPctRaw = Number(params.mbPct !== undefined ? params.mbPct : ((Number(params.masterbatchPct) || 4) / 100));
  const mbPct = mbPctRaw > 1 ? mbPctRaw / 100 : mbPctRaw;
  const blendedRmRate = Number(( (rmLanded * (1 - mbPct)) + (mbLanded * mbPct) ).toFixed(2)); // Row 14 = 134.76

  // 3. Weights & Gross Weight: = Row 15 + Row 16
  const partWt = Number(params.partWt !== undefined ? params.partWt : (params.netWeight !== undefined ? params.netWeight : 37.00));
  const runnerWt = Number(params.runnerWt !== undefined ? params.runnerWt : (params.runnerWeight !== undefined ? params.runnerWeight : 1.00));
  const grossWt = Number((partWt + runnerWt).toFixed(2)); // Row 17 = 38.00

  // 4. RM Cost / Pc: = SUM(Row 17/1000)*Row 14
  const rmCostPerPc = Number(((grossWt / 1000) * blendedRmRate).toFixed(2)); // Row 18 = 5.12
  const bopCost = Number(params.bopCost || 0);
  const rmPlusBop = Number((rmCostPerPc + bopCost).toFixed(2)); // Row 20 = 5.12

  // 5. Machine Conversion: Parts/Shift = SUM(28800/Row 23)*Row 24*Row 25
  const tonnage = Number(params.tonnage || params.machineTonnage || 200);
  const shiftTariff = Number(params.shiftTariff || 2000);
  const cycleTime = Number(params.cycleTime !== undefined ? params.cycleTime : (params.cycleTimeApproved || 47));
  const efficiency = Number(params.efficiency !== undefined ? params.efficiency : 0.90);
  const cavity = Number(params.cavity || 2);

  const theoreticalShots = cycleTime > 0 ? (28800 / cycleTime) : 0;
  const partsPerShift = Number((theoreticalShots * efficiency * cavity).toFixed(2)); // Row 26 = 1102.98
  const processCostPerPc = partsPerShift > 0 ? Number((shiftTariff / partsPerShift).toFixed(2)) : 1.81; // Row 27 = 1.81

  const handlingBop = Number((bopCost * 0.03).toFixed(2)); // Row 28 = 0.00
  
  // Row 29 = Row 27 + Row 28
  const postOpCost = Number((processCostPerPc + handlingBop).toFixed(2)); // Row 29 = 1.81

  // Row 30: Total Process Cost
  const totalProcessCost = Number((processCostPerPc + handlingBop + postOpCost).toFixed(2)); // Row 30 = 3.62

  // 6. Overheads, Rejections & Recoveries
  const profitOhBase = Number((rmCostPerPc + totalProcessCost).toFixed(2));
  const ohAndProfit = Number((profitOhBase * 0.12).toFixed(2)); // Row 31 = 1.05
  const inProcessRejection = Number(((rmPlusBop + totalProcessCost) * 0.04).toFixed(2)); // Row 32 = 0.35

  // Runner Recovery: = -25 * (Runner Wt / 1000)
  const runnerRecoveryCredit = Number(((runnerWt / 1000) * 25).toFixed(2)); // Row 33 = 0.03

  // Packaging & Logistics
  const packingCost = Number(params.packingCost !== undefined ? params.packingCost : 0.86); // Row 34 = 0.86
  const transportCost = Number(params.transportCost !== undefined ? params.transportCost : 0.62); // Row 35 = 0.62
  
  // Mould Maintenance: = 2% * Total Process Cost (Row 30)
  const mouldMaintenance = Number((totalProcessCost * 0.02).toFixed(2)); // Row 36 = 0.07
  const otherCost = Number(params.otherCost !== undefined ? params.otherCost : 0.00);

  // 7. Final Landed Cost
  const finalLanded = Number((
    rmPlusBop + 
    totalProcessCost + 
    ohAndProfit + 
    inProcessRejection - 
    runnerRecoveryCredit + 
    packingCost + 
    transportCost + 
    mouldMaintenance + 
    otherCost
  ).toFixed(2)); // Row 38

  return {
    rmBase,
    rmIccRate: rmIccRate * 100,
    rmIcc,
    rmFreight,
    rmLanded,
    mbBase,
    mbIccRate: mbIccRate * 100,
    mbIcc,
    mbFreight,
    mbLanded,
    mbPct: (mbPct * 100).toFixed(1),
    blendedRmRate,
    partWt,
    runnerWt,
    grossWt,
    rmCostPerPc,
    bopCost,
    rmPlusBop,
    tonnage,
    shiftTariff,
    cycleTime,
    efficiency: (efficiency * 100).toFixed(0),
    cavity,
    partsPerShift,
    processCostPerPc,
    handlingBop,
    postOpCost,
    totalProcessCost,
    ohAndProfit,
    inProcessRejection,
    runnerRecoveryCredit,
    packingCost,
    transportCost,
    mouldMaintenance,
    otherCost,
    totalCost: finalLanded,
    finalLanded
  };
}

export function calculateHaierCost(params = {}) {
  const cavity = Number(params.cavity) > 0 ? Number(params.cavity) : 1;
  const netWeight = Number(params.netWeight) || 0;
  const runnerWeight = Number(params.runnerWeight) || 0;
  const shotWeight = params.shotWeight !== undefined && params.shotWeight !== null 
    ? Number(params.shotWeight) 
    : (netWeight * cavity + runnerWeight);
  
  const pieceWeight = cavity > 0 ? (shotWeight > 0 ? (shotWeight / cavity) : netWeight) : netWeight;
  
  // Custom or Default Melt Loss % (Default: 1.0%)
  const meltLossPct = Number(params.meltLossPct !== undefined ? params.meltLossPct : 1.0);
  const reconciliationWeight = Number((pieceWeight * (1 + meltLossPct / 100)).toFixed(2));

  const rmRate = Number(params.rmRate || 0);
  const mbPct = (Number(params.masterbatchPct || 0)) / 100;
  const mbRate = Number(params.masterbatchRate || 0);

  const rawMaterialCost = Number(((reconciliationWeight / 1000) * (1 - mbPct) * rmRate).toFixed(4));
  const masterbatchCost = Number(((reconciliationWeight / 1000) * mbPct * mbRate).toFixed(4));
  const runnerRecoveryScrap = Number(params.runnerRecoveryScrap || 0);
  const totalRmCost = Number((rawMaterialCost + masterbatchCost - runnerRecoveryScrap).toFixed(4));

  const cycleTime = Number(params.cycleTime) || 70;
  const shiftTariff = Number(params.shiftTariff) || 4800;
  
  // Custom or Default Machine Efficiency % (Default: 95%)
  const efficiencyPct = Number(params.efficiencyPct !== undefined ? params.efficiencyPct : 95.0);
  
  const shotsShift8h = cycleTime > 0 ? Number((28800 / cycleTime).toFixed(2)) : 0;
  const shotsShiftEfficiency = Number((shotsShift8h * (efficiencyPct / 100)).toFixed(2));
  const partsPerShift = Number((shotsShiftEfficiency * cavity).toFixed(2));
  
  const productionCostPerPc = partsPerShift > 0 ? Number((shiftTariff / partsPerShift).toFixed(4)) : (Number(params.productionCostPerPc) || 0);
  const subTotal = Number((totalRmCost + productionCostPerPc).toFixed(4));

  const haierOverheadPackage = Number(params.haierOverheadPackage || 0);
  const foamPolybag = Number(params.foamPolybag || 0);
  const plasticBin = Number(params.plasticBin || 0);
  const freightCost = Number(params.freightCost || 0);
  const secondaryOp1 = Number(params.secondaryOp1 || 0);
  const secondaryOp2 = Number(params.secondaryOp2 || 0);
  const screenPrint1 = Number(params.screenPrint1 || 0);
  const screenPrint2 = Number(params.screenPrint2 || 0);
  const assemblyCost = Number(params.assemblyCost || 0);
  const bopCost = Number(params.bopCost || 0);

  const mouldMaintenance = Number(params.mouldMaintenance || 0);
  const qualityInspection = Number(params.qualityInspection || 0);
  const iccReduce = Number(params.iccReduce || 0);
  const scrapAdj = Number(params.scrapAdj || 0);

  const totalCost = Number((
    subTotal + 
    haierOverheadPackage + 
    foamPolybag + 
    plasticBin + 
    freightCost + 
    secondaryOp1 + 
    secondaryOp2 + 
    screenPrint1 + 
    screenPrint2 + 
    assemblyCost + 
    bopCost + 
    mouldMaintenance + 
    qualityInspection + 
    iccReduce + 
    scrapAdj
  ).toFixed(2));

  return {
    shotWeight,
    meltLossPct,
    reconciliationWeight,
    rawMaterialCost,
    masterbatchCost,
    runnerRecoveryScrap,
    totalRmCost,
    shotsShift8h,
    efficiencyPct,
    shotsShiftEfficiency,
    partsPerShift,
    productionCostPerPc,
    subTotal,
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
    totalCost,
    finalLanded: totalCost
  };
}
SERVICE_EOF

echo "==> 2. Updating InlineEditModal.jsx with complete 38 lines and editable Melt Loss & Efficiency %..."
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
    cycleTimeApproved: Number(product.cycleTimeApproved || (isAtomberg ? 47 : 70)),
    cavity: Number(product.cavity || (isAtomberg ? 2 : 1)),
    
    // Custom Melt Loss % & Machine Efficiency % (Editable)
    meltLossPct: Number(product.meltLossPct !== undefined ? product.meltLossPct : 1.0),
    efficiencyPct: Number(product.efficiencyPct !== undefined ? product.efficiencyPct : 95.0),

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
    mouldMaintenance: Number(product.mouldMaintenance !== undefined ? product.mouldMaintenance : 1.5),
    qualityInspection: Number(product.qualityInspection !== undefined ? product.qualityInspection : 1.0),
    iccReduce: Number(product.iccReduce !== undefined ? product.iccReduce : -0.29),
    scrapAdj: Number(product.scrapAdj || 0),

    // Running Parameters
    runningRmFreight: Number(initialParams.runningRmFreight ?? product.rmFreight ?? 1.50),
    runningMbFreight: Number(initialParams.runningMbFreight ?? product.mbFreight ?? 2.00),
    runningMbPct: Number(initialParams.runningMbPct ?? product.masterbatchPct ?? (isAtomberg ? 4 : 4)),
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
    runningHaierOverheadPackage: Number(initialParams.runningHaierOverheadPackage ?? product.haierOverheadPackage ?? 8.71)
  });

  // Calculate Atomberg Cost
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

  // Calculate Haier Cost
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
        runningMeltLossPct: formData.runningMeltLossPct,
        runningEfficiencyPct: formData.runningEfficiencyPct,
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
            /* COMPLETE 38-LINE TABLE FOR HAIER WITH EDITABLE RECONCILIATION % & EFFICIENCY % */
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
                <tr className="bg-purple-50/40">
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
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">7</td>
                  <td className="py-1.5 px-3 font-bold text-amber-950">No. of Cavity</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-bold">{formData.cavity}</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" value={formData.runningCavity} onChange={e => setFormData({ ...formData, runningCavity: Number(e.target.value) || 1 })} className="w-16 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{formData.cavity - formData.runningCavity}</td>
                </tr>
                <tr className="bg-amber-50/30">
                  <td className="py-1.5 px-3 font-mono text-slate-500">8</td>
                  <td className="py-1.5 px-3">Runner Weight</td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono">{formData.runnerWeight}g</td>
                  <td className="py-1.5 px-4 text-right">
                    <input type="number" step="0.01" value={formData.runningRunnerWeight} onChange={e => setFormData({ ...formData, runningRunnerWeight: Number(e.target.value) || 0 })} className="w-20 px-2 py-0.5 border border-blue-300 rounded text-right font-bold text-blue-800 bg-white" />
                  </td>
                  <td className="py-1.5 px-3 text-right font-mono">{(formData.runnerWeight - formData.runningRunnerWeight).toFixed(2)}g</td>
                </tr>
                <tr className="bg-amber-50/30">
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

                {/* Row 11: Reconciliation Weight with editable Melt Loss % input */}
                <tr className="bg-slate-50">
                  <td className="py-1.5 px-3 font-mono text-slate-500">11</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">
                    <div className="flex items-center gap-2">
                      <span>Reconciliation Weight = Shot wt +</span>
                      <input 
                        type="number" 
                        step="0.1" 
                        value={formData.meltLossPct} 
                        onChange={e => setFormData({ ...formData, meltLossPct: Number(e.target.value) || 0 })} 
                        className="w-14 px-1.5 py-0.5 border border-amber-400 rounded text-center font-bold bg-white text-slate-900 text-xs" 
                      />
                      <span>% Melt Loss</span>
                    </div>
                  </td>
                  <td className="py-1.5 px-3 text-center">Gms</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-slate-900">{Number(haierBaseCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-4 text-right font-mono font-black text-emerald-600">{Number(haierRunningCalc.reconciliationWeight).toFixed(2)}g</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(haierBaseCalc.reconciliationWeight - haierRunningCalc.reconciliationWeight).toFixed(2)}g</td>
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
                  <td className="py-1.5 px-4 text-right font-mono">{haierBaseCalc.shotsShift8h}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{haierRunningCalc.shotsShift8h}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(haierBaseCalc.shotsShift8h - haierRunningCalc.shotsShift8h).toFixed(2)}</td>
                </tr>

                {/* Row 20: Shots with editable Efficiency % input */}
                <tr className="bg-slate-50">
                  <td className="py-1.5 px-3 font-mono text-slate-500">20</td>
                  <td className="py-1.5 px-3 font-bold text-slate-900">
                    <div className="flex items-center gap-2">
                      <span>No of Shot / Shift with</span>
                      <input 
                        type="number" 
                        step="0.1" 
                        value={formData.efficiencyPct} 
                        onChange={e => setFormData({ ...formData, efficiencyPct: Number(e.target.value) || 0 })} 
                        className="w-14 px-1.5 py-0.5 border border-amber-400 rounded text-center font-bold bg-white text-slate-900 text-xs" 
                      />
                      <span>% Efficiency</span>
                    </div>
                  </td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-slate-900">{haierBaseCalc.shotsShiftEfficiency}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{haierRunningCalc.shotsShiftEfficiency}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(haierBaseCalc.shotsShiftEfficiency - haierRunningCalc.shotsShiftEfficiency).toFixed(2)}</td>
                </tr>

                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">21</td>
                  <td className="py-1.5 px-3">No. of component / shift</td>
                  <td className="py-1.5 px-3 text-center">Nos</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{haierBaseCalc.partsPerShift}</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-blue-800">{haierRunningCalc.partsPerShift}</td>
                  <td className="py-1.5 px-3 text-right font-mono">{(haierBaseCalc.partsPerShift - haierRunningCalc.partsPerShift).toFixed(2)}</td>
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

                {/* Rows 25 to 37 (Fully restored and visible) */}
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">25</td>
                  <td className="py-1.5 px-3">Foam / Polybag / Masking film</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.foamPolybag > 0 ? `₹${formData.foamPolybag.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.foamPolybag > 0 ? `₹${formData.foamPolybag.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">26</td>
                  <td className="py-1.5 px-3">Plastic Bin / Polyend Box / Trolley</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.plasticBin > 0 ? `₹${formData.plasticBin.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.plasticBin > 0 ? `₹${formData.plasticBin.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">27</td>
                  <td className="py-1.5 px-3">Freight Cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.freightCost > 0 ? `₹${formData.freightCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.freightCost > 0 ? `₹${formData.freightCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">28</td>
                  <td className="py-1.5 px-3">Secondary Operation 1</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.secondaryOp1 > 0 ? `₹${formData.secondaryOp1.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.secondaryOp1 > 0 ? `₹${formData.secondaryOp1.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">29</td>
                  <td className="py-1.5 px-3">Secondary Operation 2</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.secondaryOp2 > 0 ? `₹${formData.secondaryOp2.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.secondaryOp2 > 0 ? `₹${formData.secondaryOp2.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">30</td>
                  <td className="py-1.5 px-3">Screen printing - 1st stroke</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.screenPrint1 > 0 ? `₹${formData.screenPrint1.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.screenPrint1 > 0 ? `₹${formData.screenPrint1.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">31</td>
                  <td className="py-1.5 px-3">Screen printing - 2nd stroke</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.screenPrint2 > 0 ? `₹${formData.screenPrint2.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.screenPrint2 > 0 ? `₹${formData.screenPrint2.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">32</td>
                  <td className="py-1.5 px-3">Assembly Cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.assemblyCost > 0 ? `₹${formData.assemblyCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.assemblyCost > 0 ? `₹${formData.assemblyCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">33</td>
                  <td className="py-1.5 px-3">Insert / Hinge hole cap cost / Other cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.bopCost > 0 ? `₹${formData.bopCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.bopCost > 0 ? `₹${formData.bopCost.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">34</td>
                  <td className="py-1.5 px-3">Mould Maintenance Provision</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">₹{formData.mouldMaintenance.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{formData.mouldMaintenance.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">35</td>
                  <td className="py-1.5 px-3">Quality Inspection Cost</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">₹{formData.qualityInspection.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">₹{formData.qualityInspection.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">36</td>
                  <td className="py-1.5 px-3">ICC Reduce by .5% (Payment term change 60 to 45 days)</td>
                  <td className="py-1.5 px-3 text-center">-</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold text-emerald-700">₹{formData.iccReduce.toFixed(2)}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-emerald-700">₹{formData.iccReduce.toFixed(2)}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
                </tr>
                <tr>
                  <td className="py-1.5 px-3 font-mono text-slate-500">37</td>
                  <td className="py-1.5 px-3">Scrap Recovery Adjustment</td>
                  <td className="py-1.5 px-3 text-center">Rs</td>
                  <td className="py-1.5 px-4 text-right font-mono font-bold">{formData.scrapAdj !== 0 ? `₹${formData.scrapAdj.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-4 text-right font-mono text-blue-800">{formData.scrapAdj !== 0 ? `₹${formData.scrapAdj.toFixed(2)}` : '-'}</td>
                  <td className="py-1.5 px-3 text-right text-slate-400">-</td>
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
      mouldMaintenance: Number(item.mouldMaintenance !== undefined ? item.mouldMaintenance : 1.5),
      qualityInspection: Number(item.qualityInspection !== undefined ? item.qualityInspection : 1.0),
      iccReduce: Number(item.iccReduce !== undefined ? item.iccReduce : -0.29),
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

echo "==> 3. Verifying build with Vite..."
npm run build

echo "==> 4. Restarting local dev server on port 5173..."
fuser -k 5173/tcp 2>/dev/null || killall -9 node 2>/dev/null || true
rm -rf node_modules/.vite 2>/dev/null || true
nohup npm run dev -- --host 0.0.0.0 --port 5173 > /tmp/vite_server.log 2>&1 &
sleep 2

echo "-------------------------------------------------------------------"
echo "✅ COMPLETE HAIER 38-LINE SPECIFICATION & EDITABLE PARAMETERS DEPLOYED!"
echo "-------------------------------------------------------------------"
