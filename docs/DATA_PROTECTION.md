# Data protection strategy

Your data lives in **Supabase Postgres (cloud)** — never on the device. Rebuilding
or reinstalling the app only clears the **local login session**; it cannot touch the
database. If the app looks empty after a reinstall, sign in with the **same account**
and everything is back. This doc lists the durability layers.

## 1. Per-user isolation (Row-Level Security) — already on
Every table (`expenses`, `categories`, `budgets`, `profiles`) has RLS policies that
scope every read/write to `user_id = auth.uid()`. A new client signing up gets their
own isolated rows and **cannot read, edit, or delete anyone else's data**. New clients
joining can never affect existing data.

## 2. Non-destructive migrations — practice
Schema changes live in `database/migrations/` and only ever **add** things
(`create ... if not exists`, `add column if not exists`). We never `drop` or
`truncate`. Re-running any migration is safe.

## 3. Soft deletes — recoverable (migration 003)
Deleting an expense sets `deleted_at` instead of removing the row, and the app hides
`deleted_at is not null`. Nothing is ever truly gone; an accidental delete is one
"Undo" away (or recoverable directly in the DB). Run `migrations/003_soft_delete.sql`.

## 4. Automated backups — the real safety net
`.github/workflows/backup.yml` dumps the **entire** database daily and stores it as a
downloadable artifact (90-day retention). One-time setup:

1. Supabase → **Project Settings → Database → Connection string → URI** (this includes
   the DB password). Copy it.
2. GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**
   → name `SUPABASE_DB_URL`, value = that URI.
3. GitHub → **Actions** tab → run **"Daily database backup"** once to verify, then it
   runs automatically each day. Download any run's artifact to get a `.sql.gz` dump.

**Restore** (if ever needed): `gunzip -c supabase-backup-*.sql.gz | psql "$SUPABASE_DB_URL"`.

> For hands-off managed backups + point-in-time recovery (roll back to any second in
> the last 7 days), Supabase **Pro ($25/mo)** adds them automatically. The free workflow
> above is a solid substitute until then.

## 5. Account recovery (planned)
The only real way to "lose" data is losing access to the account it's under. Next up:
a **password reset** flow so an account is always recoverable. Until then, keep the
sign-in email + password saved in a password manager.
