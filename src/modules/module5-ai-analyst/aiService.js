// Dual-Provider AI Engine: Google Gemini 3.6 Flash (Primary) + OpenRouter Free (Failover)
const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const OPENROUTER_API_KEY = import.meta.env.VITE_OPENROUTER_API_KEY || "";

// Primary: Google Gemini 3.6 Flash
async function callGeminiFlash(systemPrompt, userPrompt) {
  if (!GEMINI_API_KEY) {
    throw new Error("Google Gemini API Key is missing. Check VITE_GEMINI_API_KEY in .env.local");
  }

  const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=" + encodeURIComponent(GEMINI_API_KEY.trim());
  
  const payload = {
    contents: [
      {
        role: "user",
        parts: [{ text: systemPrompt + "\n\nUSER REQUEST / QUERY:\n" + userPrompt }]
      }
    ],
    generationConfig: {
      temperature: 0.3,
      maxOutputTokens: 2500,
    }
  };

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    const errorJson = await resp.json().catch(() => ({}));
    throw new Error("Gemini HTTP " + resp.status + ": " + (errorJson.error?.message || resp.statusText));
  }

  const result = await resp.json();
  const text = result.candidates?.[0]?.content?.parts?.map(p => p.text).filter(Boolean).join("\n");
  if (!text) throw new Error("Empty response received from Gemini API.");

  return { 
    text, 
    provider: "Google Gemini", 
    model: "gemini-3.6-flash" 
  };
}

// Failover: OpenRouter Free Models Router
async function callOpenRouter(systemPrompt, userPrompt) {
  if (!OPENROUTER_API_KEY) {
    throw new Error("OpenRouter API Key is missing. Check VITE_OPENROUTER_API_KEY in .env.local");
  }

  const models = ["openrouter/free", "meta-llama/llama-3.2-3b-instruct:free"];
  let lastError = null;

  for (const model of models) {
    try {
      const resp = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer " + OPENROUTER_API_KEY.trim(),
          "HTTP-Referer": "https://costing-system.vercel.app",
          "X-Title": "Srikants Costing Intelligence"
        },
        body: JSON.stringify({
          model: model,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt }
          ],
          temperature: 0.3,
          max_tokens: 2048
        })
      });

      if (!resp.ok) {
        const errJson = await resp.json().catch(() => ({}));
        throw new Error("OpenRouter (" + model + ") HTTP " + resp.status + ": " + (errJson.error?.message || resp.statusText));
      }

      const data = await resp.json();
      const text = data.choices?.[0]?.message?.content;
      if (!text) throw new Error("Empty response from OpenRouter model: " + model);

      return { 
        text, 
        provider: "OpenRouter", 
        model: data.model || model 
      };
    } catch (err) {
      lastError = err;
      console.warn("OpenRouter model " + model + " failed:", err.message);
    }
  }

  throw lastError;
}

// Central Dispatcher
export async function executeAIAnalysis({ systemPrompt, userPrompt, preferredEngine = "auto" }) {
  if (preferredEngine === "openrouter") {
    return await callOpenRouter(systemPrompt, userPrompt);
  }

  if (preferredEngine === "gemini") {
    return await callGeminiFlash(systemPrompt, userPrompt);
  }

  // Auto failover: Gemini 3.6 Flash -> OpenRouter Free
  try {
    const res = await callGeminiFlash(systemPrompt, userPrompt);
    return { ...res, failoverOccurred: false };
  } catch (geminiError) {
    console.warn("Gemini primary failed, switching to OpenRouter failover...", geminiError);
    try {
      const orRes = await callOpenRouter(systemPrompt, userPrompt);
      return { 
        ...orRes, 
        failoverOccurred: true, 
        fallbackReason: geminiError.message || "Gemini unavailable" 
      };
    } catch (orError) {
      throw new Error("Both AI engines failed:\n• Gemini: " + geminiError.message + "\n• OpenRouter: " + orError.message);
    }
  }
}
