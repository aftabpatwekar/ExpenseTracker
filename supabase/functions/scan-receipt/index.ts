// Molbhav — receipt scanner. Client POSTs a photo (raw image bytes); we ask
// OpenAI GPT-4o-mini (vision) for the total, merchant, and date, and return JSON.
// Deploy:  supabase functions deploy scan-receipt
// Set key: supabase secrets set OPENAI_API_KEY=sk-...
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

  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return json({ error: "Receipt scanning not configured" }, 500);

  const contentType = req.headers.get("content-type") || "image/jpeg";
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) return json({ error: "Empty image" }, 400);

  const dataUrl = `data:${contentType};base64,${encodeBase64(bytes)}`;

  try {
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: PROMPT },
              { type: "image_url", image_url: { url: dataUrl, detail: "low" } },
            ],
          },
        ],
        response_format: { type: "json_object" },
        max_tokens: 200,
        temperature: 0,
      }),
    });
    if (!r.ok) {
      return json({ error: "Scan failed", detail: await r.text() }, 502);
    }
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(content);
    } catch (_) {
      parsed = {};
    }
    return json({
      amount: parsed.amount ?? null,
      merchant: parsed.merchant ?? null,
      date: parsed.date ?? null,
    });
  } catch (e) {
    return json({ error: "Scan error", detail: String(e) }, 500);
  }
});
