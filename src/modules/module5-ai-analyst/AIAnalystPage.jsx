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
  Bot,
  Search
} from "lucide-react";
import { globalStore, subscribeStore } from "../../shared/masterStore";
import { executeAIAnalysis } from "./aiService";

export default function AIAnalystPage() {
  const [store, setStore] = useState({ ...globalStore });
  const [engineMode, setEngineMode] = useState("auto");
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

  const vendorList = (store.vendors && store.vendors.length > 0 ? store.vendors : [
    { vendorId: "Haier Appliances", vendorName: "Haier Appliances" },
    { vendorId: "Atomberg Technologies", vendorName: "Atomberg Technologies" },
    { vendorId: "Atharva Polymer", vendorName: "Atharva Polymer (Haier)" }
  ]).map(v => typeof v === "object" ? { id: v.vendorId || v.id || "", name: v.vendorName || v.name || "" } : { id: v, name: v });

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

    const systemPrompt = "You are Srikants, the Enterprise AI Industrial Copilot & Costing Intelligence Analyst.\n" +
      "1. PRIMARY FOCUS: Internal Enterprise Costing Database (read-only snapshot provided below). Prioritize internal baseline numbers, inward purchases, RM grades, and BOM records for all enterprise queries.\n" +
      "2. OPEN WEB SEARCH & GENERAL KNOWLEDGE: If the user asks general, world, polymer market commodity price, technical definition, or open-web questions, use your live search capabilities and knowledge to provide up-to-date answers.\n" +
      "3. MULTILINGUAL SUPPORT: Full fluency in English, Odia (ଓଡ଼ିଆ), Marathi (मराठी), and Hindi (हिंदी). You MUST detect the input language and respond in that exact language (e.g. if the user writes in Odia, answer completely in fluent Odia script).\n" +
      "4. DATA PRESENTATION: Format outputs with clean Markdown, clear bold section headers, and comparison tables where helpful.\n" +
      "5. If internal database arrays currently have 0 rows, clearly state that internal records are currently clean and awaiting transaction imports.";

    const fullUserPrompt = "ENTERPRISE READ-ONLY DB CONTEXT:\n" + JSON.stringify(dbSnapshot, null, 2) + "\n\nUSER QUERY / INSTRUCTION:\n" + taskPrompt;

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
        fallbackReason: response.fallbackReason,
        hasGrounding: response.hasGrounding
      });
    } catch (err) {
      setErrorMsg(err.message || "Srikants AI analysis execution failed.");
    } finally {
      setLoading(false);
    }
  };

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
      {/* Top Banner */}
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
              Internal DB synthesis (Primary) &bull; Open Web Search &bull; Multilingual (English, ଓଡ଼ିଆ, मराठी, हिंदी) &bull; Offline exports
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
            <option value="auto">Auto (Gemini Search &rarr; Groq Failover)</option>
            <option value="gemini">Google Gemini Flash + Web Search</option>
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
              <Globe className="w-3.5 h-3.5" /> English &bull; ଓଡ଼ିଆ &bull; मराठी &bull; हिंदी
            </span>
          </div>
        </div>

        {/* Input Area */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <label className="text-[11px] font-bold text-slate-700 flex items-center gap-1.5">
              <MessageSquare className="w-3.5 h-3.5 text-blue-600" />
              Ask Srikants Any Internal Audit or Open-Web Question:
            </label>
            <span className="text-[10px] text-slate-400">Supports English, Odia, Marathi, Hindi</span>
          </div>
          <textarea
            rows={3}
            value={promptText}
            onChange={e => setPromptText(e.target.value)}
            placeholder="e.g. Srikants, check our RM purchase rates vs baseline. Or ask: ଶ୍ରୀକାନ୍ତ, ଆମର କଞ୍ଚାମାଲ ଦର ଏବଂ ଉତ୍ପାଦନ ଖର୍ଚ୍ଚ ବିଶ୍ଳେଷଣ କରନ୍ତୁ | Or search: What is current PP/ABS polymer price in India?"
            className="w-full bg-slate-50 border border-slate-300 rounded-xl p-3 text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
          />
        </div>

        {/* Presets Bar with Odia Included */}
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
                const q = "ଶ୍ରୀକାନ୍ତ, ଆମର ସମସ୍ତ କଞ୍ଚାମାଲ (Raw Material) ଦର ଏବଂ ବେସଲାଇନ ମୂଲ୍ୟ ଯାଞ୍ଚ କରି ଓଡ଼ିଆରେ ଏକ ବିସ୍ତୃତ ଟେବୁଲ୍ ରିପୋର୍ଟ ଦିଅନ୍ତୁ |";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-orange-50 hover:bg-orange-100 text-orange-800 border border-orange-200 rounded-lg text-[10px] font-semibold transition-colors"
            >
              🇮🇳 Odia (ଓଡ଼ିଆ) Audit
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
            <button
              type="button"
              onClick={() => {
                const q = "Search open web: What are current market prices and weekly trends for injection molding polymers (PP, ABS, Nylon) in India?";
                setPromptText(q);
                handleRunAnalysis(q);
              }}
              className="px-2.5 py-1 bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 rounded-lg text-[10px] font-medium transition-colors"
            >
              🌐 Web Polymer Trends
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
              <strong>Failover Active:</strong> Primary Gemini request failed ({metaInfo.fallbackReason}). Srikants responded via <strong>Groq ({metaInfo.model})</strong>.
            </span>
          </div>
          <span className="text-[10px] bg-amber-200 px-2 py-0.5 rounded font-bold">FAILOVER OK</span>
        </div>
      )}

      {/* Srikants Report Output & Export */}
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

      {/* Initial Guidance */}
      {!analysisResult && !loading && !errorMsg && (
        <div className="bg-slate-50/70 border border-dashed border-slate-300 rounded-2xl p-8 text-center space-y-3">
          <BrainCircuit className="w-10 h-10 text-slate-400 mx-auto" />
          <h3 className="text-xs font-bold text-slate-700">Srikants Industrial AI Ready</h3>
          <p className="text-[11px] text-slate-500 max-w-md mx-auto">
            Primary focus on internal costing, BOM, and purchase drifts. Supports general Q&amp;A, live web searches, and full multilingual output (English, ଓଡ଼ିଆ, मराठी, हिंदी) with offline downloads.
          </p>
        </div>
      )}
    </div>
  );
}
