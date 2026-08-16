# PWA / web voice setup (works on iPhone)

iOS Safari has no on-device speech API, so the web app records audio in the
browser and sends it to a Supabase **Edge Function** (`transcribe`) that proxies
to a speech-to-text provider. The provider key stays on the server.

The app code is already wired. You just deploy the function once and add a key.
Until then, tapping the mic on web shows a friendly “type it” message.

## 1. Get a speech-to-text key (Deepgram — free credit)
1. Sign up at <https://deepgram.com> (free, ~$200 credit — plenty for personal use).
2. Create an **API key** and copy it.

*(Prefer another provider? The only file to change is
`supabase/functions/transcribe/index.ts` — swap the `fetch` call. OpenAI Whisper
and Google STT work too.)*

## 2. Deploy the Edge Function
Install the Supabase CLI if you don't have it (`npm i -g supabase`), then:

```bash
cd C:/src/expense_tracker
supabase login
supabase link --project-ref dcbgcintizqbsczncmqe
supabase secrets set DEEPGRAM_API_KEY=YOUR_DEEPGRAM_KEY
supabase functions deploy transcribe
```

That's it. The function lives at
`https://dcbgcintizqbsczncmqe.supabase.co/functions/v1/transcribe` and the app
calls it automatically (with the signed-in user's token).

## 3. Use it
On the web app / PWA: tap the mic → **allow microphone** → speak → tap ⏹ →
it transcribes and fills the expense. Works on iPhone Safari and Android Chrome.

## Notes
- The function requires a signed-in Supabase user (default `verify_jwt`), so
  random visitors can't burn your credits.
- iOS Safari records `audio/mp4`; Android/desktop Chrome records `audio/webm` —
  the app forwards the right content-type and Deepgram handles both.
- Cost is per-minute of audio; expense clips are a few seconds, so it's tiny.
