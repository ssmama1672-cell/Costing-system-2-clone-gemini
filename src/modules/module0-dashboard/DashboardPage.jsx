import React, { useState, useEffect } from 'react';
import { LayoutDashboard, Database, TrendingUp, DollarSign, Layers } from 'lucide-react';
import { globalStore, subscribeStore } from '../../shared/masterStore';

export default function DashboardPage() {
  const [store, setStore] = useState(globalStore);

  useEffect(() => {
    const unsub = subscribeStore(() => setStore({ ...globalStore }));
    return () => unsub();
  }, []);

  const totalProducts = (store.baselineProducts || []).length;
  const totalMaterials = (store.rmMappingsData || []).length;
  const totalPurchases = (store.purchases || []).length;
  const totalSales = (store.sales || []).length;

  return (
    <div className="space-y-4 text-xs font-sans">
      <div className="bg-slate-900 text-white p-4 rounded-2xl shadow-md flex items-center gap-3">
        <div className="p-2.5 bg-blue-600 rounded-xl">
          <LayoutDashboard className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-sm font-bold">Multi-Vendor Costing & Variance Intelligence Dashboard</h1>
          <p className="text-[11px] text-slate-300">Live synchronization between baseline contracts, shopfloor telemetry, and purchase weighted averages</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-400">Baseline Products</div>
          <div className="text-2xl font-black font-mono text-slate-900 mt-1">{totalProducts}</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-400">Mapped RM / MB Grades</div>
          <div className="text-2xl font-black font-mono text-blue-700 mt-1">{totalMaterials}</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-400">Purchase Inward Batches</div>
          <div className="text-2xl font-black font-mono text-emerald-700 mt-1">{totalPurchases}</div>
        </div>
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs">
          <div className="text-[10px] uppercase font-bold text-slate-400">Sales Invoices Logged</div>
          <div className="text-2xl font-black font-mono text-purple-700 mt-1">{totalSales}</div>
        </div>
      </div>
    </div>
  );
}
