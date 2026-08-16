// Molbhav — speech-to-text proxy for the web/PWA.
// The browser records audio and POSTs the bytes here; we forward them to
// Deepgram (key kept server-side) and return the transcript. Keeps the API key
// out of the client. Deploy with:  supabase functions deploy transcribe
// Set the key with:  supabase secrets set DEEPGRAM_API_KEY=xxxxx
// (Requires a signed-in Supabase user by default — verify_jwt stays on.)

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const key = Deno.env.get("DEEPGRAM_API_KEY");
  if (!key) return json({ error: "Transcription not configured" }, 500);

  const contentType = req.headers.get("content-type") || "audio/webm";
  const audio = await req.arrayBuffer();
  if (audio.byteLength === 0) return json({ error: "Empty audio" }, 400);

  try {
    const dg = await fetch(
      // numerals=true keeps "250" as digits; smart_format is OFF because it
      // was turning "250 rupees" into currency like "$2.50".
      "https://api.deepgram.com/v1/listen?model=nova-2&numerals=true&punctuate=false&language=en",
      {
        method: "POST",
        headers: { Authorization: `Token ${key}`, "Content-Type": contentType },
        body: audio,
      },
    );
    if (!dg.ok) {
      const detail = await dg.text();
      return json({ error: "Transcription failed", detail }, 502);
    }
    const data = await dg.json();
    const transcript =
      data?.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "";
    return json({ transcript });
  } catch (e) {
    return json({ error: "Transcription error", detail: String(e) }, 500);
  }
});
