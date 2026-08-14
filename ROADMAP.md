# Expense Tracker — build roadmap

Cross-platform (iOS + Android) expense tracker. **Flutter** app, **Supabase** backend (Postgres + Auth/JWT + RLS). Voice capture in-app; double-tap Back Tap launches the voice screen.

## Stack
- **App:** Flutter (Dart), `fl_chart` (charts), `speech_to_text` (in-app voice), `riverpod` (state), `go_router` (nav), `supabase_flutter` (backend), `drift` or `sqflite` (offline cache).
- **Backend:** Supabase — Postgres, Auth (email + Google/Apple), Row-Level Security.
- **Dev on:** Windows → Android phone over USB. **iOS packaging later** via Mac or Codemagic + Apple Developer ($99/yr).

## Architecture (clean layers)
```
lib/
  core/        theme, constants, result types, extensions
  data/        supabase client, DTOs, repositories (impl), local cache
  domain/      entities (Expense, Category, Budget, Profile), repository interfaces
  features/
    auth/      sign in / sign up, session
    dashboard/ stats: totals, category donut, monthly trend
    entry/     add expense, in-app voice capture, the parser
    txns/      list, edit, delete, filter
    settings/  currency, categories & keywords, budgets
  app.dart / main.dart
```
Repositories are interfaces in `domain/` with Supabase implementations in `data/` — so the backend stays swappable and the UI never touches Supabase directly.

## Phases
- [x] **P0 — Toolchain** — Flutter 3.41.9 + Android SDK 36 installed, `flutter doctor` clean. *(Connect phone → `flutter devices`.)*
- [x] **P0 — Supabase** — project + `schema.sql` live with RLS. *(Add anon key to `.env` to wire the app.)*
- [x] **P1 — Scaffold + core** — scaffolded, deps added, **Dart parser + 19 unit tests passing**, `analyze` clean, **Supabase wired** (`.env` → `Supabase.initialize`), **debug APK builds** end-to-end.
- [x] **P2 — Auth** — sign up / sign in, session persistence, route guards. Verified on device.
- [x] **P3 — Data layer** — expense & category repositories over Supabase (RLS-scoped), Riverpod providers.
- [x] **P4 — Dashboard** — month total, **category donut + 6-month trend (fl_chart)**, transactions list, pull-to-refresh.
- [x] **P5 — Entry + voice** — add sheet with parser + **in-app `speech_to_text` voice** (working on device).
- [x] **P6 — Back Tap trigger** — deep link `expensetracker://add` → voice-add (auto-starts listening); Android **"Speak expense"** long-press app shortcut. iOS Back Tap will call the same link (with the iOS build).
- [x] **UI redesign** — glassmorphism + dark mode + gradients + animations (IBM Plex Sans); floating glass bottom nav (Home · Stats · Add · Account · More); redesigned home + analysis/account/more tabs.
- [x] **P7 — Settings & More** — CSV export, dark/light/system theme, monthly/annual budgets, **category editing (add · edit · delete · keywords · colours)**.
- [ ] **P8 — Polish + tests** — error/empty/loading states, widget tests, `flutter analyze` clean.
- [ ] **P9 — iOS packaging** — Codemagic build + Apple Developer + install on iPhone / TestFlight.

## Notes / decisions
- Data lives at `C:\src\expense_tracker` (no spaces in path, not OneDrive-synced) to avoid Gradle build failures.
- The HTML prototype in `Desktop\Smarte\projects\Expense Tracker\dashboard.html` stays as a design/logic reference.
- Voice recognition runs **inside** the Flutter app (works on iOS + Android), unlike the web prototype.
