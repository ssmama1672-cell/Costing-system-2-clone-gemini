// ============================================================================
// MULTI-VENDOR COST CALCULATION ENGINE (Exact Atomberg 38-Line & Haier 38-Line)
// ============================================================================

export function calculateAtombergCost(params = {}) {
  // 1. RM & MB Base Rates
  const rmBase = Number(params.rmBase !== undefined ? params.rmBase : 131.00);
  const rmIccRate = Number(params.rmIccRate !== undefined ? params.rmIccRate : 0.01);
  const rmFreight = Number(params.rmFreight !== undefined ? params.rmFreight : 1.50);
  
  const rmIcc = Number((rmBase * rmIccRate).toFixed(2));
  const rmLanded = Number((rmBase + rmIcc + rmFreight).toFixed(2)); // Row 8

  const mbBase = Number(params.mbBase !== undefined ? params.mbBase : 154.00);
  const mbIccRate = Number(params.mbIccRate !== undefined ? params.mbIccRate : 0.01);
  const mbFreight = Number(params.mbFreight !== undefined ? params.mbFreight : 2.00);
  
  const mbIcc = Number((mbBase * mbIccRate).toFixed(2));
  const mbLanded = Number((mbBase + mbIcc + mbFreight).toFixed(2)); // Row 12

  // 2. MB % & Blended RM Rate: = Row 8*(1-Row 13) + Row 12*Row 13
  const mbPctRaw = Number(params.mbPct !== undefined ? params.mbPct : ((Number(params.masterbatchPct) || 4) / 100));
  const mbPct = mbPctRaw > 1 ? mbPctRaw / 100 : mbPctRaw;
  const blendedRmRate = Number(( (rmLanded * (1 - mbPct)) + (mbLanded * mbPct) ).toFixed(2)); // Row 14

  // 3. Weights & Gross Weight: = Row 15 + Row 16
  const partWt = Number(params.partWt !== undefined ? params.partWt : (params.netWeight !== undefined ? params.netWeight : 37.00));
  const runnerWt = Number(params.runnerWt !== undefined ? params.runnerWt : (params.runnerWeight !== undefined ? params.runnerWeight : 1.00));
  const grossWt = Number((partWt + runnerWt).toFixed(2)); // Row 17

  // 4. RM Cost / Pc: = SUM(Row 17/1000)*Row 14
  const rmCostPerPc = Number(((grossWt / 1000) * blendedRmRate).toFixed(2)); // Row 18
  const bopCost = Number(params.bopCost || 0);
  const rmPlusBop = Number((rmCostPerPc + bopCost).toFixed(2)); // Row 20

  // 5. Machine Conversion: Parts/Shift = SUM(28800/Row 23)*Row 24*Row 25
  const tonnage = Number(params.tonnage || params.machineTonnage || 200);
  const shiftTariff = Number(params.shiftTariff !== undefined ? params.shiftTariff : 2000);
  const cycleTime = Number(params.cycleTime !== undefined ? params.cycleTime : (params.cycleTimeApproved || 47));
  const efficiencyPct = Number(params.efficiencyPct !== undefined ? params.efficiencyPct : 95);
  const cavity = Number(params.cavity !== undefined ? params.cavity : 2);

  const partsPerShift = cycleTime > 0 ? (((8 * 3600) / cycleTime) * cavity * (efficiencyPct / 100)) : 0; // Row 26
  const processCostPerPc = partsPerShift > 0 ? Number((shiftTariff / partsPerShift).toFixed(2)) : 0; // Row 27
  const handlingBop = Number((bopCost * 0.03).toFixed(2)); // Row 28
  const postOpCost = Number((params.postOpCost !== undefined ? params.postOpCost : processCostPerPc).toFixed(2)); // Row 29
  const totalProcessCost = Number((processCostPerPc + handlingBop + postOpCost).toFixed(2)); // Row 30

  // 6. Overheads & Margin: (RM+BOP + TotalProcessCost) * 12%
  const subTotalForOh = rmPlusBop + totalProcessCost;
  const ohProfit = Number((subTotalForOh * 0.12).toFixed(2)); // Row 31
  const inProcessRejection = Number(((subTotalForOh + ohProfit) * 0.04).toFixed(2)); // Row 32

  // 7. Runner Recovery Credit (credit is fixed -25/kg on runnerWt)
  const runnerCredit = Number((((runnerWt / 1000) * 25)).toFixed(2)); // Row 33 (deduction)

  // 8. Commercials & Final Piece Cost
  const packingCost = Number(params.packingCost || 0);
  const transportCost = Number(params.transportCost || 0.06);
  const totalCost = Number((subTotalForOh + ohProfit + inProcessRejection - runnerCredit + packingCost + transportCost).toFixed(2));

  return {
    rmLanded,
    mbLanded,
    blendedRmRate,
    grossWt,
    rmCostPerPc,
    bopCost,
    rmPlusBop,
    partsPerShift,
    processCostPerPc,
    handlingBop,
    postOpCost,
    totalProcessCost,
    ohProfit,
    inProcessRejection,
    runnerCredit,
    packingCost,
    transportCost,
    totalCost,
    finalPieceCost: totalCost
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
  
  // RUNNER RECOVERY CALCULATION:
  // Option 2 (Standard per-piece): (Runner Weight / Cavity) * (RM Rate / 1000) * 50%
  // Option 1 (Total runner): Runner Weight * (RM Rate / 1000) * 50%
  const isOption1 = params.runnerRecoveryOption === 1;
  const runnerWeightPerPiece = isOption1 ? runnerWeight : (runnerWeight / cavity);
  const runnerRecoveryPct = Number((runnerWeightPerPiece * (rmRate / 1000) * 0.50).toFixed(4));
  
  // Row 15: Total Raw Material Cost = Raw Material Cost + Masterbatch Cost - Runner Recovery
  const totalRmCost = Number((rawMaterialCost + masterbatchCost - runnerRecoveryPct).toFixed(4));

  const cycleTime = Number(params.cycleTime) || 70;
  const shiftTariff = Number(params.shiftTariff) || 4800;
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
    runnerRecoveryPct,
    runnerRecoveryScrap: runnerRecoveryPct,
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
