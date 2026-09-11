// Dual-Provider AI Engine: Google Gemini 3.6 Flash (Primary) + Groq Qwen 3.8 27B (Failover)
const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const GROQ_API_KEY = import.meta.env.VITE_GROQ_API_KEY || "";

async function callGeminiFlash(systemPrompt, userPrompt) {
  if (!GEMINI_API_KEY) {
    throw new Error("Google Gemini API Key is missing. Check VITE_GEMINI_API_KEY in .env.local");
  }

  const models = ["gemini-3.6-flash", "gemini-flash-latest"];
  let lastError = null;

  for (const model of models) {
    try {
      const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + encodeURIComponent(GEMINI_API_KEY.trim());
      
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
        throw new Error("Gemini (" + model + ") HTTP " + resp.status + ": " + (errorJson.error?.message || resp.statusText));
      }

      const result = await resp.json();
      const text = result.candidates?.[0]?.content?.parts?.map(p => p.text).filter(Boolean).join("\n");
      if (!text) throw new Error("Empty response received from Gemini API.");

      return { 
        text, 
        provider: "Google Gemini", 
        model: model 
      };
    } catch (err) {
      lastError = err;
      console.warn("Gemini attempt with " + model + " failed:", err.message);
    }
  }
  throw lastError;
}

async function callGroq(systemPrompt, userPrompt) {
  if (!GROQ_API_KEY) {
    throw new Error("Groq API Key is missing. Check VITE_GROQ_API_KEY in .env.local");
  }

  const endpoint = "https://api.groq.com/openai/v1/chat/completions";
  const payload = {
    model: "qwen/qwen3.8-27b",
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
  return { text, provider: "Groq Cloud", model: "qwen/qwen3.8-27b" };
}

export async function executeAIAnalysis({ systemPrompt, userPrompt, preferredEngine = "auto" }) {
  if (preferredEngine === "groq") {
    return await callGroq(systemPrompt, userPrompt);
  }

  if (preferredEngine === "gemini") {
    return await callGeminiFlash(systemPrompt, userPrompt);
  }

  // Auto failover: Gemini 3.6 Flash -> Groq Qwen 3.8 27B
  try {
    const res = await callGeminiFlash(systemPrompt, userPrompt);
    return { ...res, failoverOccurred: false };
  } catch (geminiError) {
    console.warn("Gemini primary failed, switching to Groq failover...", geminiError);
    try {
      const groqRes = await callGroq(systemPrompt, userPrompt);
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
