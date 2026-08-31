import React, { useState } from 'react';
import { LayoutDashboard, Database, Layers, Calculator, Activity, Bot } from 'lucide-react';
import DashboardPage from './modules/module0-dashboard/DashboardPage';
import BaselineMasterPage from './modules/module1-baseline/BaselineMasterPage';
import RMPriceMatrixPage from './modules/module2-rm-matrix/RMPriceMatrixPage';
import CostingRunEnginePage from './modules/module3-costing-engine/CostingRunEnginePage';
import MISVariancePage from './modules/module4-mis/MISVariancePage';
import AIAnalystPage from './modules/module5-ai-analyst/AIAnalystPage';

export default function App() {
  const [activeModule, setActiveModule] = useState('baseline');

  const navItems = [
    { id: 'dashboard', label: '0. Dashboard', icon: LayoutDashboard },
    { id: 'baseline', label: '1. Baseline Master', icon: Database },
    { id: 'rm_matrix', label: '2. RM & Matrix', icon: Layers },
    { id: 'costing', label: '3. Costing Engine', icon: Calculator },
    { id: 'mis', label: '4. MIS & Gap', icon: Activity },
    { id: 'ai', label: '5. AI Analyst', icon: Bot },
  ];

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans">
      {/* Top Navbar */}
      <header className="bg-slate-950 border-b border-slate-800 px-6 py-3 flex flex-wrap justify-between items-center gap-4 sticky top-0 z-40">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-blue-600 flex items-center justify-center font-black text-white text-xs shadow-md">
            CPC
          </div>
          <div>
            <div className="font-bold text-sm text-white tracking-wide">Product Costing & MIS Control System</div>
            <div className="text-[10px] text-slate-400">Multi-Vendor Approved vs Actual Costing Engine</div>
          </div>
        </div>

        <nav className="flex items-center gap-1 bg-slate-900 p-1 rounded-2xl border border-slate-800">
          {navItems.map(item => {
            const Icon = item.icon;
            const isActive = activeModule === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveModule(item.id)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-bold text-xs transition cursor-pointer ${
                  isActive ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'
                }`}
              >
                <Icon className="w-3.5 h-3.5" />
                {item.label}
              </button>
            );
          })}
        </nav>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 p-6 max-w-7xl w-full mx-auto">
        {activeModule === 'dashboard' && <DashboardPage />}
        {activeModule === 'baseline' && <BaselineMasterPage />}
        {activeModule === 'rm_matrix' && <RMPriceMatrixPage />}
        {activeModule === 'costing' && <CostingRunEnginePage />}
        {activeModule === 'mis' && <MISVariancePage />}
        {activeModule === 'ai' && <AIAnalystPage />}
      </main>
    </div>
  );
}
