// Dual-Provider AI Engine: Google Gemini Flash (with Google Search Grounding) + Groq Llama 3.3 70B
const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const GROQ_API_KEY = import.meta.env.VITE_GROQ_API_KEY || "";

// Primary Gemini call with Google Search Grounding enabled
async function callGeminiFlash(systemPrompt, userPrompt) {
  if (!GEMINI_API_KEY) {
    throw new Error("Google Gemini API Key is missing. Check VITE_GEMINI_API_KEY in .env.local");
  }

  const models = ["gemini-2.5-flash", "gemini-1.5-flash"];
  let lastError = null;

  for (const model of models) {
    try {
      const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + encodeURIComponent(GEMINI_API_KEY.trim());
      
      const payload = {
        contents: [
          {
            role: "user",
            parts: [{ text: systemPrompt + "\n\nUSER PROMPT / TASK:\n" + userPrompt }]
          }
        ],
        tools: [
          {
            google_search: {}
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
        throw new Error("Gemini (" + model + ") HTTP " + resp.status + ": " + (errorJson.error?.message || resp.statusText));
      }

      const result = await resp.json();
      const candidate = result.candidates?.[0];
      const text = candidate?.content?.parts?.map(p => p.text).filter(Boolean).join("\n");
      if (!text) throw new Error("Empty response received from Gemini API.");

      const groundingSources = candidate?.groundingMetadata?.groundingChunks || [];

      return { 
        text, 
        provider: "Google Gemini Flash (Search-Enabled)", 
        model,
        hasGrounding: groundingSources.length > 0
      };
    } catch (err) {
      lastError = err;
      console.warn("Gemini attempt with model " + model + " failed:", err.message);
    }
  }
  throw lastError;
}

// Groq Llama 3.3 70B call (Fast Open-Source Failover Engine)
async function callGroqLlama(systemPrompt, userPrompt) {
  if (!GROQ_API_KEY) {
    throw new Error("Groq API Key is missing. Check VITE_GROQ_API_KEY in .env.local");
  }

  const endpoint = "https://api.groq.com/openai/v1/chat/completions";
  const payload = {
    model: "llama-3.3-70b-versatile",
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt }
    ],
    temperature: 0.3,
    max_tokens: 2048
  };

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + GROQ_API_KEY.trim()
    },
    body: JSON.stringify(payload)
  });

  if (!resp.ok) {
    const errJson = await resp.json().catch(() => ({}));
    throw new Error("Groq HTTP " + resp.status + ": " + (errJson.error?.message || resp.statusText));
  }

  const data = await resp.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) throw new Error("Empty response received from Groq API.");
  return { text, provider: "Groq Cloud", model: "llama-3.3-70b-versatile" };
}

// Dispatcher with Automatic Fallback
export async function executeAIAnalysis({ systemPrompt, userPrompt, preferredEngine = "auto" }) {
  if (preferredEngine === "groq") {
    return await callGroqLlama(systemPrompt, userPrompt);
  }

  if (preferredEngine === "gemini") {
    return await callGeminiFlash(systemPrompt, userPrompt);
  }

  // Automatic preference: Gemini Flash (Primary + Live Web) -> Groq Llama 3.3
  try {
    const res = await callGeminiFlash(systemPrompt, userPrompt);
    return { ...res, failoverOccurred: false };
  } catch (geminiError) {
    console.warn("Primary engine failed, switching to Groq failover...", geminiError);
    try {
      const groqRes = await callGroqLlama(systemPrompt, userPrompt);
      return { 
        ...groqRes, 
        failoverOccurred: true, 
        fallbackReason: geminiError.message || "Gemini unavailable" 
      };
    } catch (groqError) {
      throw new Error("Both AI engines failed:\n• Gemini: " + geminiError.message + "\n• Groq: " + groqError.message);
    }
  }
}
