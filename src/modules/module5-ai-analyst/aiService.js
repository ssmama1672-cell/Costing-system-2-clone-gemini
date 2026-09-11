// Dual-Provider AI Engine: Google Gemini 3 / 2.5 Flash (Primary) + Groq Llama 3.3 70B (Failover)
const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const GROQ_API_KEY = import.meta.env.VITE_GROQ_API_KEY || "";

// Primary Gemini call via official Google AI REST API
async function callGeminiFlash(systemPrompt, userPrompt) {
  if (!GEMINI_API_KEY) {
    throw new Error("Google Gemini API Key is missing. Check VITE_GEMINI_API_KEY in .env.local");
  }

  // Model cascade: Gemini 3 Flash -> 2.5 Flash -> 2.0 Flash
  const models = ["gemini-3-flash", "gemini-2.5-flash", "gemini-2.0-flash"];
  let lastError = null;

  for (const model of models) {
    try {
      const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + encodeURIComponent(GEMINI_API_KEY.trim());
      
      const payload = {
        contents: [
          {
            role: "user",
            parts: [{ text: systemPrompt + "\n\nUSER REQUEST / DATA CONTEXT:\n" + userPrompt }]
          }
        ],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
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
      const text = result.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error("Empty response received from Gemini API.");
      return { text, provider: "Google Gemini Flash", model };
    } catch (err) {
      lastError = err;
      console.warn("Gemini model " + model + " attempt failed:", err.message);
    }
  }
  throw lastError;
}

// Secondary Groq Llama 3.3 70B call via Groq Chat Completions API
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
    temperature: 0.2,
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

// Unified Dispatcher with Automatic Failover
export async function executeAIAnalysis({ systemPrompt, userPrompt, preferredEngine = "auto" }) {
  if (preferredEngine === "groq") {
    return await callGroqLlama(systemPrompt, userPrompt);
  }

  if (preferredEngine === "gemini") {
    return await callGeminiFlash(systemPrompt, userPrompt);
  }

  // Auto Mode: 1st Preference Gemini Flash -> Automatic failover to Groq Llama 3.3
  try {
    const res = await callGeminiFlash(systemPrompt, userPrompt);
    return { ...res, failoverOccurred: false };
  } catch (geminiError) {
    console.warn("Gemini failed, engaging Groq Llama-3.3-70B failover...", geminiError);
    try {
      const groqRes = await callGroqLlama(systemPrompt, userPrompt);
      return { 
        ...groqRes, 
        failoverOccurred: true, 
        fallbackReason: geminiError.message || "Gemini service unreachable" 
      };
    } catch (groqError) {
      throw new Error("Both AI Providers Failed:\n• Primary (Gemini): " + geminiError.message + "\n• Failover (Groq): " + groqError.message);
    }
  }
}
