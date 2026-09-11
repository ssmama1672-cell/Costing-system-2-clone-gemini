// Dual-Provider AI Engine: Google Gemini (Primary Dual-Tier) + OpenRouter (Failover)
const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const OPENROUTER_API_KEY = import.meta.env.VITE_OPENROUTER_API_KEY || "";

function extractGeminiText(data) {
  const candidate = data?.candidates?.[0];
  if (!candidate) return "";
  
  const parts = candidate?.content?.parts || [];
  const validText = parts
    .filter(p => p.text && !p.thought)
    .map(p => p.text)
    .join("\n")
    .trim();

  if (validText) return validText;
  return parts.map(p => p.text).filter(Boolean).join("\n").trim();
}

async function callGemini(systemPrompt, userPrompt) {
  if (!GEMINI_API_KEY) {
    throw new Error("Google Gemini API Key is missing. Check VITE_GEMINI_API_KEY in .env.local");
  }

  // Verified 200 OK models from active probe: gemini-3.6-flash -> gemini-flash-lite-latest
  const activeModels = ["gemini-3.6-flash", "gemini-flash-lite-latest"];
  let lastError = null;

  for (const model of activeModels) {
    try {
      const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + encodeURIComponent(GEMINI_API_KEY.trim());
      
      const payload = {
        systemInstruction: {
          parts: [{ text: systemPrompt }]
        },
        contents: [
          {
            role: "user",
            parts: [{ text: userPrompt }]
          }
        ],
        generationConfig: {
          maxOutputTokens: 4096
        }
      };

      const resp = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!resp.ok) {
        const errorJson = await resp.json().catch(() => ({}));
        throw new Error(model + " HTTP " + resp.status + ": " + (errorJson.error?.message || resp.statusText));
      }

      const result = await resp.json();
      const text = extractGeminiText(result);
      if (!text) {
        throw new Error(model + " finished with empty response text.");
      }

      return { 
        text, 
        provider: "Google Gemini", 
        model: model 
      };
    } catch (err) {
      lastError = err;
      console.warn("Gemini attempt on " + model + " failed:", err.message);
    }
  }

  throw lastError;
}

// Failover: OpenRouter Free Models Router
async function callOpenRouter(systemPrompt, userPrompt) {
  if (!OPENROUTER_API_KEY) {
    throw new Error("OpenRouter API Key is missing. Check VITE_OPENROUTER_API_KEY in .env.local");
  }

  const resp = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + OPENROUTER_API_KEY.trim(),
      "HTTP-Referer": "https://costing-system.vercel.app",
      "X-Title": "Srikants Costing Intelligence"
    },
    body: JSON.stringify({
      model: "openrouter/free",
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
    throw new Error("OpenRouter HTTP " + resp.status + ": " + (errJson.error?.message || resp.statusText));
  }

  const data = await resp.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) throw new Error("Empty response from OpenRouter router.");

  return { 
    text, 
    provider: "OpenRouter", 
    model: data.model || "openrouter/free" 
  };
}

// Central Dispatcher
export async function executeAIAnalysis({ systemPrompt, userPrompt, preferredEngine = "auto" }) {
  if (preferredEngine === "openrouter") {
    return await callOpenRouter(systemPrompt, userPrompt);
  }

  if (preferredEngine === "gemini") {
    return await callGemini(systemPrompt, userPrompt);
  }

  // Automatic Strategy: Gemini (3.6 Flash -> Flash-Lite) -> OpenRouter Failover
  try {
    const res = await callGemini(systemPrompt, userPrompt);
    return { ...res, failoverOccurred: false };
  } catch (geminiError) {
    console.warn("Gemini primary stack exhausted, switching to OpenRouter...", geminiError);
    try {
      const orRes = await callOpenRouter(systemPrompt, userPrompt);
      return { 
        ...orRes, 
        failoverOccurred: true, 
        fallbackReason: geminiError.message || "Gemini capacity reached" 
      };
    } catch (orError) {
      throw new Error("Both AI engines failed:\n• Gemini: " + geminiError.message + "\n• OpenRouter: " + orError.message);
    }
  }
}
