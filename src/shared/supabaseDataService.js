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
