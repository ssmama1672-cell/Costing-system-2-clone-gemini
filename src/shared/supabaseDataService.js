import { supabase } from './supabaseClient';

export async function upsertProductCosting(productData) {
  if (!supabase) {
    console.warn('Supabase client not initialized. Check .env variables.');
    return { success: false, error: 'Supabase client missing' };
  }

  const recordId = String(productData.id || productData.itemCode || `prod-${Date.now()}`);

  const payload = {
    id: recordId,
    vendor: productData.vendor || 'Atomberg Technologies',
    component_name: productData.componentName || '',
    model: productData.model || '',
    item_code: productData.itemCode || '',
    mould_size: productData.mouldSize || '',
    approved_rm: productData.approvedRm || '',
    approved_mb: productData.approvedMb || '',
    params: {
      ...productData,
      id: recordId
    },
    running_params: productData.parameters || {},
    calculated_results: {
      approvedCost: productData.approvedCost,
      simulatedCost: productData.simulatedCost
    },
    updated_at: new Date().toISOString()
  };

  const { data, error } = await supabase
    .from('product_costing_master')
    .upsert(payload, { onConflict: 'id' });

  if (error) {
    console.error('Supabase upsert failed:', error);
    return { success: false, error };
  }

  return { success: true, data };
}

export async function fetchAllProductsFromSupabase(vendor = null) {
  if (!supabase) return [];

  let query = supabase.from('product_costing_master').select('*');
  if (vendor) {
    query = query.eq('vendor', vendor);
  }

  const { data, error } = await query;
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }

  return (data || []).map(row => ({
    id: row.id,
    vendor: row.vendor,
    componentName: row.component_name,
    model: row.model,
    itemCode: row.item_code,
    mouldSize: row.mould_size,
    approvedRm: row.approved_rm,
    approvedMb: row.approved_mb,
    ...(row.params || {}),
    parameters: row.running_params || {},
    ...(row.calculated_results || {})
  }));
}


// Multi-period RM Mapping Upsert preserving historical periods
export async function saveRmMappingToSupabase(mapping) {
  if (!supabase) return { success: false, error: 'No client' };
  
  // Composite unique ID per Material + Vendor + Period so July & August stay separate!
  const vNorm = (mapping.vendor || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const codeNorm = (mapping.approvedCode || mapping.approved_code || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const pFrom = mapping.periodFrom || mapping.period_from || '2026-07-01';
  const pTo = mapping.periodTo || mapping.period_to || '2026-07-31';
  const uniqueId = `rm_${vNorm}_${codeNorm}_${pFrom}_${pTo}`;

  const payload = {
    id: uniqueId,
    vendor: mapping.vendor,
    type: mapping.type || 'RM',
    approved_code: mapping.approvedCode || mapping.approved_code,
    approved_price: Number(mapping.approvedPrice || mapping.approved_price || 0),
    selected_alts: mapping.selectedAlts || mapping.selected_alts || [mapping.approvedCode || mapping.approved_code],
    alt1_code: mapping.alt1Code || mapping.alt1_code || mapping.approvedCode,
    alt1_price: Number(mapping.alt1Price || mapping.alt1_price || mapping.approvedPrice || 0),
    period_from: pFrom,
    period_to: pTo,
    updated_at: new Date().toISOString()
  };

  const { data, error } = await supabase
    .from('rm_mappings')
    .upsert(payload, { onConflict: 'id' });

  if (error) console.error('Error saving historical RM mapping:', error);
  return { success: !error, data };
}

// Fetch all historical RM mappings for specific vendor & period
export async function fetchRmMappingsFromSupabase(vendor = null, periodFrom = null, periodTo = null) {
  if (!supabase) return [];
  let query = supabase.from('rm_mappings').select('*');
  if (vendor && vendor !== 'ALL') {
    query = query.eq('vendor', vendor);
  }
  if (periodFrom && periodTo) {
    query = query.eq('period_from', periodFrom).eq('period_to', periodTo);
  }
  const { data, error } = await query;
  if (error) {
    console.error('Error fetching rm_mappings:', error);
    return [];
  }
  return data || [];
}
