# Expense Tracker (Flutter + Supabase)

A cross-platform (iOS + Android) voice-first expense tracker. One Flutter codebase, a Supabase cloud backend (Postgres + Auth), real users/auth/tokens, and in-app voice capture triggered by the phone's back-tap gesture.

> Status: **Phase 1 (core) done** — project scaffolded, dependencies in, on-device parser ported to Dart with a passing test suite. See [`ROADMAP.md`](ROADMAP.md).

## Setup (one time)
1. **Toolchain** → [`INSTALL.md`](INSTALL.md) — Flutter + Android SDK. ✅ done (`flutter doctor` clean).
2. **Backend** → [`database/README.md`](database/README.md) — Supabase project + [`database/schema.sql`](database/schema.sql). ✅ done. Put your `SUPABASE_URL` + anon key in `.env` (copy from `.env.example`).
3. **Run** → connect an Android phone (USB debugging) and `flutter run`.

## Architecture
```
lib/
  core/        default_categories, theme, formatting        (cross-cutting)
  domain/      models/ (ExpenseCategory, ParsedExpense…)     (pure Dart)
               services/ (ExpenseParser)
  data/        supabase client, repositories                 (added next)
  features/    auth/ dashboard/ entry/ txns/ settings/       (added next)
test/          expense_parser_test.dart (19 cases, passing)
database/      schema.sql + Supabase setup guide
```
The parser and models are pure Dart (no Flutter imports) so the core logic is trivially unit-testable. Repositories will sit behind interfaces so the backend stays swappable.

## Why these choices
- **Flutter** — one codebase; in-app speech on both platforms.
- **Supabase** — Postgres (grows into complex relational structure), built-in Auth issuing JWTs, Row-Level Security so each user only sees their own data.
- Built on **Windows targeting Android**; iOS packaging comes later via a Mac or Codemagic + an Apple Developer account (Apple requires macOS to build iOS).
