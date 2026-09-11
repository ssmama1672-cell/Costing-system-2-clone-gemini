import React, { useState, useEffect, useRef } from "react";
import { 
  BrainCircuit, 
  Sparkles, 
  Cpu, 
  RefreshCw, 
  AlertTriangle, 
  CheckCircle2, 
  Zap,
  Download,
  FileText,
  Printer,
  Globe,
  Database,
  MessageSquare,
  Bot
} from "lucide-react";
import { globalStore, subscribeStore } from "../../shared/masterStore";
import { executeAIAnalysis } from "./aiService";

export default function AIAnalystPage() {
  const [store, setStore] = useState({ ...globalStore });
  const [engineMode, setEngineMode] = useState("auto"); // "auto" | "gemini" | "groq"
  const [selectedVendor, setSelectedVendor] = useState("all");
  const [promptText, setPromptText] = useState("");
  
  const [loading, setLoading] = useState(false);
  const [analysisResult, setAnalysisResult] = useState(null);
  const [metaInfo, setMetaInfo] = useState(null);
  const [errorMsg, setErrorMsg] = useState("");
  const reportRef = useRef(null);

  useEffect(() => {
    const unsub = subscribeStore(newStore => setStore({ ...newStore }));
    return () => unsub();
  }, []);

  // Normalize vendor objects safely
  const vendorList = (store.vendors && store.vendors.length > 0 ? store.vendors : [
    { vendorId: "Haier Appliances", vendorName: "Haier Appliances" },
    { vendorId: "Atomberg Technologies", vendorName: "Atomberg Technologies" },
    { vendorId: "Atharva Polymer", vendorName: "Atharva Polymer (Haier)" }
  ]).map(v => typeof v === "object" ? { id: v.vendorId || v.id || "", name: v.vendorName || v.name || "" } : { id: v, name: v });

  // Read-only database slices
  const allProducts = store.baselineProducts || [];
  const allPurchases = store.purchases || [];
  const allSales = store.sales || [];
  const allRmMappings = store.rmMappingsData || [];

  const filteredProducts = selectedVendor === "all" ? allProducts : allProducts.filter(p => p.vendor === selectedVendor);
  const filteredPurchases = selectedVendor === "all" ? allPurchases : allPurchases.filter(p => p.vendor === selectedVendor);
  const filteredSales = selectedVendor === "all" ? allSales : allSales.filter(s => s.vendor === selectedVendor);

  const handleRunAnalysis = async (customInstruction) => {
    const taskPrompt = customInstruction || promptText.trim();
    if (!taskPrompt) return;

    setLoading(true);
    setErrorMsg("");
    setAnalysisResult(null);
    setMetaInfo(null);

    // Read-only DB snapshot
    const dbSnapshot = {
      selectedScope: selectedVendor === "all" ? "Entire Enterprise Database" : selectedVendor,
      counts: {
        totalBaselineProducts: filteredProducts.length,
        totalPurchases: filteredPurchases.length,
        totalSales: filteredSales.length,
        totalRmMappings: allRmMappings.length
      },
      baselineSamples: filteredProducts.slice(0, 30).map(p => ({
        code: p.itemCode,
        name: p.componentName,
        vendor: p.vendor,
        approvedCost: p.approvedCost,
        shotWeight: p.shotWeight,
        cycleTime: p.cycleTimeApproved
      })),
      purchaseTransactions: filteredPurchases.slice(0, 40).map(pur => ({
        date: pur.date,
        code: pur.itemCode,
        grade: pur.grade,
        qty: pur.qty,
        rate: pur.rate,
        supplier: pur.supplier,
        vendor: pur.vendor
      })),
      salesTransactions: filteredSales.slice(0, 30).map(s => ({
        date: s.date,
        code: s.itemCode,
        qty: s.qty,
        billedRate: s.billedRate,
        vendor: s.vendor
      }))
    };

    const systemPrompt = "You are Srikants, the Chief Enterprise AI Costing Controller & Industrial Intelligence Analyst for high-precision injection moulding & manufacturing.\n" +
      "1. You have strictly READ-ONLY access to the enterprise internal database snapshot provided.\n" +
      "2. Answer ANY open-ended analytical, costing, operational, or trend query with deep precision.\n" +
      "3. MULTILINGUAL MASTERY: Detect the language of the user prompt (English, Hindi, Marathi, etc.) and respond fluently in that exact language.\n" +
      "4. DATA STRUCTURING: Whenever comparing prices, variances, or trends, structure output with clean Markdown Tables, bold key metrics, and actionable recommendations.\n" +
      "5. If database arrays currently have 0 rows, clearly explain that the system is clean and ready for inward transaction uploads.";

    const fullUserPrompt = "ENTERPRISE READ-ONLY DB SNAPSHOT:\n" + JSON.stringify(dbSnapshot, null, 2) + "\n\nUSER QUESTION / TASK:\n" + taskPrompt;

    try {
      const response = await executeAIAnalysis({
        systemPrompt,
        userPrompt: fullUserPrompt,
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
      setErrorMsg(err.message || "Srikants AI analysis execution failed.");
    } finally {
      setLoading(false);
    }
  };

  // Offline File Downloads
  const downloadAsMarkdown = () => {
    if (!analysisResult) return;
    const blob = new Blob([analysisResult], { type: "text/markdown;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", "Srikants_AI_Report_" + new Date().toISOString().slice(0, 10) + ".md");
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const downloadAsText = () => {
    if (!analysisResult) return;
    const blob = new Blob([analysisResult], { type: "text/plain;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", "Srikants_AI_Report_" + new Date().toISOString().slice(0, 10) + ".txt");
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="space-y-4 text-xs font-sans">
      {/* Top Banner with Srikants Agent Branding */}
      <div className="bg-slate-900 text-white rounded-2xl p-4 shadow-md flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-gradient-to-tr from-blue-600 to-indigo-600 rounded-xl shadow">
            <Bot className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-sm font-bold">5. Srikants &mdash; Enterprise AI Industrial Copilot</h1>
              <span className="px-2 py-0.5 text-[9px] font-bold bg-blue-500/20 text-blue-300 border border-blue-400/30 rounded-full">
                ACTIVE AGENT
              </span>
            </div>
            <p className="text-[11px] text-slate-300">
              Read-only internal DB synthesis &bull; Multilingual analysis (English, मराठी, हिंदी) &bull; Offline exportable audit reports
            </p>
          </div>
        </div>

        {/* Engine Switcher */}
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

      {/* Main Analysis Console */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3 pb-3 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <Database className="w-4 h-4 text-blue-600" />
            <span className="font-bold text-slate-800">Database Scope (Read-Only):</span>
            <select
              value={selectedVendor}
              onChange={e => setSelectedVendor(e.target.value)}
              className="bg-slate-50 border border-slate-300 rounded-lg px-2.5 py-1 text-xs font-semibold text-slate-800"
            >
              <option value="all">Entire Enterprise (All Vendors)</option>
              {vendorList.map(v => (
                <option key={v.id} value={v.id}>{v.name}</option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-4 text-[11px] text-slate-500">
            <span>Products: <strong className="text-slate-800">{filteredProducts.length}</strong></span>
            <span>Purchases: <strong className="text-slate-800">{filteredPurchases.length}</strong></span>
            <span>Sales: <strong className="text-slate-800">{filteredSales.length}</strong></span>
            <span className="flex items-center gap-1 text-emerald-600 font-semibold">
              <Globe className="w-3.5 h-3.5" /> English &bull; मराठी &bull; हिंदी
            </span>
          </div>
        </div>

        {/* Query Input Area */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-[11px] font-bold text-slate-700 flex items-center gap-1.5">
              <MessageSquare className="w-3.5 h-3.5 text-blue-600" />
              Ask Srikants Any Analytical or Operational Question:
            </label>
            <span className="text-[10px] text-slate-400">Supports English, Marathi, Hindi, etc.</span>
          </div>
          <textarea
            rows={3}
            value={promptText}
            onChange={e => setPromptText(e.target.value)}
            placeholder="e.g. Srikants, compare baseline RM prices with purchase inwards. (मराठीत विचारा: श्रीकांत, कच्च्या मालाच्या किमती वाढल्या आहेत का? टेबल स्वरूपात दाखवा)"
            className="w-full bg-slate-50 border border-slate-300 rounded-xl p-3 text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
          />
        </div>

        {/* Quick Directives & Action Buttons */}
        <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
          <div className="flex flex-wrap gap-1.5">
            <button
              type="button"
              onClick={() => {
                const q = "Srikants, perform a full Cost Variance & Baseline Audit across all recorded items. Generate a comparison table.";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-[10px] font-medium transition-colors"
            >
              📊 Full Variance Table
            </button>
            <button
              type="button"
              onClick={() => {
                const q = "Srikants, analyze raw material price drift. Which grades fluctuated the most? Suggest margin recovery steps.";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-[10px] font-medium transition-colors"
            >
              📈 RM Drift Analysis
            </button>
            <button
              type="button"
              onClick={() => {
                const q = "श्रीकांत, सर्व अंतर्गत डेटा तपासून सांगा: नफा वाढवण्यासाठी काय उपाययोजना कराव्यात? (मराठीत टेबल स्वरूपात माहिती द्या)";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-[10px] font-medium transition-colors"
            >
              🇮🇳 Marathi Audit
            </button>
            <button
              type="button"
              onClick={() => {
                const q = "श्रीकांत, खरीद और बेसलाइन डेटा का विश्लेषण करके हिंदी में एक विस्तृत ऑडिट टेबल तैयार करें।";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-[10px] font-medium transition-colors"
            >
              🇮🇳 Hindi Audit
            </button>
          </div>

          <button
            type="button"
            disabled={loading || !promptText.trim()}
            onClick={() => handleRunAnalysis()}
            className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-semibold px-4 py-2 rounded-xl shadow-md transition-all text-xs"
          >
            {loading ? (
              <>
                <RefreshCw className="w-4 h-4 animate-spin" />
                Srikants is analyzing...
              </>
            ) : (
              <>
                <Sparkles className="w-4 h-4" />
                Ask Srikants
              </>
            )}
          </button>
        </div>
      </div>

      {/* Error Notice */}
      {errorMsg && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-2xl flex items-start gap-3 text-red-700">
          <AlertTriangle className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <div className="space-y-1">
            <div className="font-bold text-xs">AI Inference Error</div>
            <pre className="text-[11px] whitespace-pre-wrap font-mono">{errorMsg}</pre>
          </div>
        </div>
      )}

      {/* Failover Notice */}
      {metaInfo?.failoverOccurred && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl flex items-center justify-between text-amber-800 text-[11px]">
          <div className="flex items-center gap-2">
            <Zap className="w-4 h-4 text-amber-600" />
            <span>
              <strong>Failover Active:</strong> Primary Gemini request failed ({metaInfo.fallbackReason}). Srikants responded via <strong>Groq ({metaInfo.model})</strong>.
            </span>
          </div>
          <span className="text-[10px] bg-amber-200 px-2 py-0.5 rounded font-bold">FAILOVER OK</span>
        </div>
      )}

      {/* Srikants Report Output & Offline Export Toolbar */}
      {analysisResult && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="p-4 bg-slate-50 border-b border-slate-200 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              <span className="font-bold text-slate-800 text-xs">Report from Srikants</span>
              {metaInfo && (
                <span className="text-[10px] bg-white border border-slate-200 px-2 py-0.5 rounded font-mono text-slate-600">
                  {metaInfo.provider} ({metaInfo.model})
                </span>
              )}
            </div>

            {/* Offline Export Controls */}
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={downloadAsMarkdown}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-slate-100 border border-slate-300 rounded-lg text-[11px] font-semibold text-slate-700 shadow-sm transition-colors"
                title="Save report offline as Markdown"
              >
                <Download className="w-3.5 h-3.5 text-blue-600" />
                Save .MD
              </button>

              <button
                type="button"
                onClick={downloadAsText}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-slate-100 border border-slate-300 rounded-lg text-[11px] font-semibold text-slate-700 shadow-sm transition-colors"
                title="Save report offline as Plain Text"
              >
                <FileText className="w-3.5 h-3.5 text-slate-600" />
                Save .TXT
              </button>

              <button
                type="button"
                onClick={handlePrint}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-slate-100 border border-slate-300 rounded-lg text-[11px] font-semibold text-slate-700 shadow-sm transition-colors"
                title="Print or Save to PDF"
              >
                <Printer className="w-3.5 h-3.5 text-slate-600" />
                Print / PDF
              </button>
            </div>
          </div>

          <div ref={reportRef} className="p-6 text-slate-800 leading-relaxed font-sans whitespace-pre-wrap text-[12px] bg-white selection:bg-blue-100">
            {analysisResult}
          </div>
        </div>
      )}

      {/* Default Prompt Card */}
      {!analysisResult && !loading && !errorMsg && (
        <div className="bg-slate-50/70 border border-dashed border-slate-300 rounded-2xl p-8 text-center space-y-3">
          <BrainCircuit className="w-10 h-10 text-slate-400 mx-auto" />
          <h3 className="text-xs font-bold text-slate-700">Srikants AI Copilot Ready</h3>
          <p className="text-[11px] text-slate-500 max-w-md mx-auto">
            Ask any question in English, Marathi, or Hindi. Srikants analyzes baseline parts, inward purchase records, and sales volumes in read-only mode, with direct offline export options.
          </p>
        </div>
      )}
    </div>
  );
}
