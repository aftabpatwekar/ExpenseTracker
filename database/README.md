# Supabase setup — one time

This creates your cloud database + auth. Free tier, no card required. You can do this **now**, in parallel with the toolchain install — it's all in the browser.

## 1. Create the project
1. Go to <https://supabase.com> → **Sign in** (GitHub or email) → **New project**.
2. Name it `expense-tracker`, pick a **region** near you (e.g. *South Asia (Mumbai)*), set a strong **database password** (save it), → **Create**. Wait ~2 min for it to provision.

## 2. Create the tables
1. Left sidebar → **SQL Editor** → **New query**.
2. Open [`schema.sql`](schema.sql), copy everything, paste into the editor → **Run**.
3. You should see *Success*. Check **Table Editor** — you'll have `profiles`, `categories`, `expenses`, `budgets`.

## 3. Turn on the sign-in methods you want
**Authentication → Providers**:
- **Email** is on by default. For quick testing, also go to **Authentication → Sign In / Providers → Email** and (optionally) turn **"Confirm email" off** so you can log in immediately without clicking a confirmation link.
- **Google** / **Apple**: optional, add later — they need OAuth client setup. Email is enough to start.

## 4. Grab your keys (I'll need these for the app)
**Project Settings → API**:
- **Project URL** — looks like `https://xxxxxxxx.supabase.co`
- **anon public** key — a long JWT starting with `eyJ...`

> The **anon** key is safe to ship inside a mobile app — Row-Level Security (already in the schema) is what actually protects the data, so every user only ever sees their own rows. **Never** put the `service_role` key in the app.

Paste those two values back to me (or drop them into `../.env` later) and I'll wire the app to your backend.

## What the schema gives you
- **profiles** — per-user settings (currency, locale). Auto-created on signup.
- **categories** — per-user, each with the **keywords** the voice parser matches on; 8 sensible defaults are seeded automatically on signup, fully editable in-app later.
- **expenses** — the ledger: amount, currency, category, note, `raw_text` (original dictation), `spent_at`.
- **budgets** — optional monthly/weekly caps (overall or per category).
- **Row-Level Security** on every table: a user can only read/write rows where `user_id = auth.uid()`.
