// Molbhav — receipt scanner. Client POSTs a photo (raw image bytes); we ask a
// Groq vision model (free tier, OpenAI-compatible API) for the total, merchant,
// and date, and return JSON.
// Deploy:  supabase functions deploy scan-receipt
// Set key: supabase secrets set GROQ_API_KEY=gsk_...
// Optional override of the model:
//          supabase secrets set GROQ_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
import { encodeBase64 } from "jsr:@std/encoding/base64";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}

// The vision model may wrap its answer in a <think>…</think> reasoning block and
// prose. Strip that and pull out the JSON object.
function extractJson(text: string): Record<string, unknown> {
  const t = text.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  const start = t.indexOf("{");
  const end = t.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return {};
  try {
    return JSON.parse(t.slice(start, end + 1));
  } catch (_) {
    return {};
  }
}

const PROMPT =
  'You are reading a shopping/restaurant receipt or bill. Return ONLY a JSON ' +
  'object: {"amount": number|null, "merchant": string|null, "date": ' +
  '"YYYY-MM-DD"|null}. "amount" is the FINAL grand total the customer paid, as ' +
  'a plain number with no currency symbol or commas. "merchant" is the shop/' +
  'restaurant name. "date" is the bill date. Use null for anything not clearly ' +
  "visible. Do not guess.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) return json({ error: "Receipt scanning not configured" }, 500);
  const model = Deno.env.get("GROQ_MODEL") || "qwen/qwen3.6-27b";

  const contentType = req.headers.get("content-type") || "image/jpeg";
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) return json({ error: "Empty image" }, 400);

  const dataUrl = `data:${contentType};base64,${encodeBase64(bytes)}`;

  try {
    const r = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: PROMPT },
                { type: "image_url", image_url: { url: dataUrl } },
              ],
            },
          ],
          // NB: no response_format — the vision model is a reasoning model that
          // emits a <think> block, which strict JSON mode rejects. We strip the
          // reasoning and extract the JSON object ourselves (see extractJson).
          max_tokens: 800,
          temperature: 0,
        }),
      },
    );
    if (!r.ok) {
      return json({ error: "Scan failed", detail: await r.text() }, 502);
    }
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    const parsed = extractJson(content);
    return json({
      amount: parsed.amount ?? null,
      merchant: parsed.merchant ?? null,
      date: parsed.date ?? null,
    });
  } catch (e) {
    return json({ error: "Scan error", detail: String(e) }, 500);
  }
});
