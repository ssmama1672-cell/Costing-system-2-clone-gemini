import React from 'react';
import { Bot, Sparkles, BrainCircuit } from 'lucide-react';

export default function AIAnalystPage() {
  return (
    <div className="space-y-4 text-xs font-sans">
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex items-center gap-3">
        <div className="p-2.5 bg-blue-600 rounded-xl"><BrainCircuit className="w-5 h-5 text-white" /></div>
        <div>
          <h1 className="text-sm font-bold">5. Multi-Vendor AI Variance Analyst & Optimization Engine</h1>
          <p className="text-[11px] text-slate-300">Automated root-cause driver decomposition, margin recovery recommendations, and shopfloor drift alerts.</p>
        </div>
      </div>

      <div className="bg-white p-8 rounded-2xl border border-slate-200 text-center space-y-3">
        <Bot className="w-12 h-12 text-blue-600 mx-auto animate-bounce" />
        <h2 className="text-sm font-bold text-slate-800">AI Cost Optimization Copilot Active</h2>
        <p className="text-xs text-slate-500 max-w-md mx-auto">
          Synchronizing with live baseline specifications, purchase inward weighted averages, and sales realizations.
        </p>
      </div>
    </div>
  );
}
