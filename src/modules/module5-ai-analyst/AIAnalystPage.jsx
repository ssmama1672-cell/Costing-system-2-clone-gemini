import React, { useState, useEffect } from "react";
import { 
  BrainCircuit, 
  Sparkles, 
  Cpu, 
  RefreshCw, 
  AlertTriangle, 
  CheckCircle2, 
  Zap 
} from "lucide-react";
import { globalStore, subscribeStore } from "../../shared/masterStore";
import { executeAIAnalysis } from "./aiService";

export default function AIAnalystPage() {
  const [store, setStore] = useState({ ...globalStore });
  const [engineMode, setEngineMode] = useState("auto"); // "auto" | "gemini" | "groq"
  const [selectedVendor, setSelectedVendor] = useState("Haier Appliances");
  const [queryPreset, setQueryPreset] = useState("variance-audit");
  const [customQuestion, setCustomQuestion] = useState("");
  
  const [loading, setLoading] = useState(false);
  const [analysisResult, setAnalysisResult] = useState(null);
  const [metaInfo, setMetaInfo] = useState(null);
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    const unsub = subscribeStore(newStore => setStore({ ...newStore }));
    return () => unsub();
  }, []);

  // Normalize vendors whether they are strings or objects { vendorId, vendorName }
  const vendorList = (store.vendors && store.vendors.length > 0 ? store.vendors : [
    { vendorId: "Haier Appliances", vendorName: "Haier Appliances" },
    { vendorId: "Atomberg Technologies", vendorName: "Atomberg Technologies" },
    { vendorId: "Atharva Polymer", vendorName: "Atharva Polymer (Haier)" }
  ]).map(v => typeof v === "object" ? { id: v.vendorId || v.id || "", name: v.vendorName || v.name || "" } : { id: v, name: v });

  const vendorProducts = (store.baselineProducts || []).filter(p => !selectedVendor || p.vendor === selectedVendor);
  const vendorPurchases = (store.purchases || []).filter(p => !selectedVendor || p.vendor === selectedVendor);
  const vendorSales = (store.sales || []).filter(p => !selectedVendor || p.vendor === selectedVendor);
  const vendorRm = (store.rmMappingsData || []).filter(r => !selectedVendor || r.vendor === selectedVendor);

  const triggerAnalysis = async () => {
    setLoading(true);
    setErrorMsg("");
    setAnalysisResult(null);
    setMetaInfo(null);

    const systemPrompt = "You are the Chief Costing Controller & AI Industrial Analyst for high-precision injection moulding & manufacturing.\n" +
      "Analyze price drift, BOM reconciliation, inward purchases vs baseline, and recommend margin recovery actions.\n" +
      "Format output in clear Markdown with bold headers and itemized bullet points.";

    const dataContext = {
      vendor: selectedVendor,
      totalBaselineProducts: vendorProducts.length,
      sampleBaselineParts: vendorProducts.slice(0, 10).map(p => ({
        code: p.itemCode,
        name: p.componentName,
        approvedCost: p.approvedCost
      })),
      totalPurchaseTransactions: vendorPurchases.length,
      samplePurchases: vendorPurchases.slice(0, 15).map(pur => ({
        date: pur.date,
        itemCode: pur.itemCode,
        grade: pur.grade,
        qty: pur.qty,
        rate: pur.rate
      })),
      totalSalesInvoices: vendorSales.length,
      totalRmMappings: vendorRm.length
    };

    let promptTask = "";
    if (queryPreset === "variance-audit") {
      promptTask = "Perform a comprehensive Cost Variance & Inward vs Baseline Audit for " + selectedVendor + ".\n" +
        "1. Check if database is currently clean or has active inwards.\n" +
        "2. Evaluate raw material baseline controls and suggest operational guidelines.";
    } else if (queryPreset === "rm-drift") {
      promptTask = "Analyze Raw Material (RM) price drift and assess weighted average inward impact on total unit costing.";
    } else {
      promptTask = customQuestion || "Perform an operational health check on product margins and purchase rate drift.";
    }

    const userPrompt = "DATA SNAPSHOT:\n" + JSON.stringify(dataContext, null, 2) + "\n\nTASK:\n" + promptTask;

    try {
      const response = await executeAIAnalysis({
        systemPrompt,
        userPrompt,
        preferredEngine: engineMode
      });

      setAnalysisResult(response.text);
      setMetaInfo({
        provider: response.provider,
        model: response.model,
        failoverOccurred: response.failoverOccurred,
        fallbackReason: response.fallbackReason
      });
    } catch (err) {
      setErrorMsg(err.message || "Analysis generation failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4 text-xs font-sans">
      {/* Header Banner */}
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-blue-600 rounded-xl">
            <BrainCircuit className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold">5. Multi-Vendor AI Variance Analyst & Optimization Engine</h1>
            <p className="text-[11px] text-slate-300">
              Dual-provider: Google Gemini 3/2.5 Flash (1st Preference) + Groq Llama 3.3 70B (Failover).
            </p>
          </div>
        </div>

        {/* Manual Provider Selector */}
        <div className="flex items-center gap-2 bg-slate-800/80 p-1.5 px-3 rounded-xl border border-slate-700">
          <Cpu className="w-4 h-4 text-cyan-400" />
          <span className="text-[11px] font-semibold text-slate-300">Engine:</span>
          <select 
            value={engineMode} 
            onChange={e => setEngineMode(e.target.value)}
            className="bg-slate-900 text-white text-[11px] font-medium border border-slate-600 rounded-lg px-2.5 py-1 focus:outline-none focus:border-blue-500"
          >
            <option value="auto">Auto (Gemini 1st &rarr; Groq Failover)</option>
            <option value="gemini">Google Gemini Flash Only</option>
            <option value="groq">Groq Llama 3.3 70B Only</option>
          </select>
        </div>
      </div>

      {/* Control Grid: Scope + Presets */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm space-y-3">
          <div className="flex items-center justify-between">
            <span className="font-bold text-slate-700">Analysis Target</span>
            <span className="px-2 py-0.5 text-[10px] font-semibold bg-blue-50 text-blue-700 rounded-full border border-blue-200">
              Live Store
            </span>
          </div>

          <div>
            <label className="text-[10px] text-slate-500 block mb-1 font-semibold uppercase">Vendor Partner</label>
            <select
              value={selectedVendor}
              onChange={e => setSelectedVendor(e.target.value)}
              className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-1.5 text-xs font-semibold text-slate-800"
            >
              {vendorList.map(v => (
                <option key={v.id} value={v.id}>{v.name}</option>
              ))}
            </select>
          </div>

          <div className="grid grid-cols-3 gap-2 pt-2 border-t border-slate-100 text-center">
            <div className="p-2 bg-slate-50 rounded-xl">
              <div className="text-slate-400 text-[10px]">Products</div>
              <div className="text-xs font-bold text-slate-800">{vendorProducts.length}</div>
            </div>
            <div className="p-2 bg-slate-50 rounded-xl">
              <div className="text-slate-400 text-[10px]">Purchases</div>
              <div className="text-xs font-bold text-slate-800">{vendorPurchases.length}</div>
            </div>
            <div className="p-2 bg-slate-50 rounded-xl">
              <div className="text-slate-400 text-[10px]">Sales</div>
              <div className="text-xs font-bold text-slate-800">{vendorSales.length}</div>
            </div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm space-y-3 md:col-span-2 flex flex-col justify-between">
          <div>
            <span className="font-bold text-slate-700 block mb-2">Audit Scenario & Directives</span>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => setQueryPreset("variance-audit")}
                className={"p-2.5 text-left rounded-xl border transition-all " + (
                  queryPreset === "variance-audit"
                    ? "border-blue-600 bg-blue-50/70 text-blue-900 font-semibold shadow-sm"
                    : "border-slate-200 hover:bg-slate-50 text-slate-700"
                )}
              >
                <div className="text-xs">Full Variance Audit</div>
                <div className="text-[10px] text-slate-500">Inward rate vs BOM Baseline</div>
              </button>

              <button
                type="button"
                onClick={() => setQueryPreset("rm-drift")}
                className={"p-2.5 text-left rounded-xl border transition-all " + (
                  queryPreset === "rm-drift"
                    ? "border-blue-600 bg-blue-50/70 text-blue-900 font-semibold shadow-sm"
                    : "border-slate-200 hover:bg-slate-50 text-slate-700"
                )}
              >
                <div className="text-xs">RM & MB Price Drift</div>
                <div className="text-[10px] text-slate-500">Weighted avg inward trend</div>
              </button>

              <button
                type="button"
                onClick={() => setQueryPreset("custom")}
                className={"p-2.5 text-left rounded-xl border transition-all " + (
                  queryPreset === "custom"
                    ? "border-blue-600 bg-blue-50/70 text-blue-900 font-semibold shadow-sm"
                    : "border-slate-200 hover:bg-slate-50 text-slate-700"
                )}
              >
                <div className="text-xs">Custom Investigation</div>
                <div className="text-[10px] text-slate-500">Specific SKU or root cause</div>
              </button>
            </div>

            {queryPreset === "custom" && (
              <div className="mt-2.5">
                <input
                  type="text"
                  placeholder="e.g., Explain margin trends for August 2026..."
                  value={customQuestion}
                  onChange={e => setCustomQuestion(e.target.value)}
                  className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs focus:outline-none focus:border-blue-500"
                />
              </div>
            )}
          </div>

          <div className="flex justify-end pt-2">
            <button
              type="button"
              disabled={loading}
              onClick={triggerAnalysis}
              className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-semibold px-4 py-2 rounded-xl shadow-md transition-all text-xs"
            >
              {loading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Generating AI Audit...
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Run Multi-Vendor AI Analysis
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Error Alert */}
      {errorMsg && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-2xl flex items-start gap-3 text-red-700">
          <AlertTriangle className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <div className="space-y-1">
            <div className="font-bold text-xs">AI Inference Error</div>
            <pre className="text-[11px] whitespace-pre-wrap font-mono">{errorMsg}</pre>
          </div>
        </div>
      )}

      {/* Failover Indicator */}
      {metaInfo?.failoverOccurred && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl flex items-center justify-between text-amber-800 text-[11px]">
          <div className="flex items-center gap-2">
            <Zap className="w-4 h-4 text-amber-600" />
            <span>
              <strong>Automatic Failover Triggered:</strong> Primary Gemini request failed ({metaInfo.fallbackReason}). Completed via <strong>Groq ({metaInfo.model})</strong>.
            </span>
          </div>
          <span className="text-[10px] bg-amber-200 px-2 py-0.5 rounded font-bold">FAILOVER ACTIVE</span>
        </div>
      )}

      {/* Analysis Output */}
      {analysisResult && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 space-y-4">
          <div className="flex flex-wrap items-center justify-between pb-3 border-b border-slate-100 gap-2">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span className="font-bold text-slate-800 text-xs">Executive Audit Report</span>
            </div>
            {metaInfo && (
              <div className="flex items-center gap-2 text-[10px] text-slate-500">
                <span className="px-2 py-0.5 bg-slate-100 rounded-md font-mono">
                  Engine: {metaInfo.provider} ({metaInfo.model})
                </span>
              </div>
            )}
          </div>

          <div className="prose prose-xs max-w-none text-slate-700 leading-relaxed font-sans whitespace-pre-wrap text-[12px]">
            {analysisResult}
          </div>
        </div>
      )}

      {/* Default Prompt Card */}
      {!analysisResult && !loading && !errorMsg && (
        <div className="bg-slate-50/70 border border-dashed border-slate-300 rounded-2xl p-8 text-center space-y-3">
          <BrainCircuit className="w-10 h-10 text-slate-400 mx-auto" />
          <h3 className="text-xs font-bold text-slate-700">Ready to audit live operational data</h3>
          <p className="text-[11px] text-slate-500 max-w-md mx-auto">
            Choose your target vendor and scenario above, then click <strong>Run Multi-Vendor AI Analysis</strong>. The engine will evaluate baseline specifications, inward trends, and dispatches.
          </p>
        </div>
      )}
    </div>
  );
}
