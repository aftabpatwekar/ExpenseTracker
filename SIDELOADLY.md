# Installing Expense Tracker on your iPhone for FREE (Codemagic + Sideloadly)

No Apple Developer fee ($99/yr) and no Xcode on the Mac. You build the app in the cloud
(Codemagic) and install it with a **free Apple ID** using **Sideloadly**.

> Trade-off of the free path: the app **expires after 7 days**. To refresh it, reconnect the
> iPhone to the Mac and re-run the Sideloadly step (a few clicks). Also: a free Apple ID can
> have at most **3** sideloaded apps installed at once.

---

## Part 1 — Build the IPA in the cloud (Codemagic)

1. Push this repo (with `codemagic.yaml`) to GitHub:
   ```bash
   git add codemagic.yaml SIDELOADLY.md && git commit -m "Add free iOS build path" && git push
   ```
2. Go to <https://codemagic.io> → sign in with **GitHub** → **Add application** → pick
   **ExpenseTracker** → choose **“codemagic.yaml”** as the config source.
3. In the app’s **Environment variables**, add a group named **`supabase`**:
   | Variable | Value | Secure |
   |---|---|---|
   | `SUPABASE_URL` | `https://dcbgcintizqbsczncmqe.supabase.co` | no |
   | `SUPABASE_ANON_KEY` | *your anon public key* | ✅ yes |
4. Start a build of the **`ios-unsigned-ipa`** workflow.
5. When it finishes, download the artifact **`ExpenseTracker.ipa`** onto the Mac.

---

## Part 2 — Install onto the iPhone (Sideloadly)

1. Download Sideloadly for macOS from <https://sideloadly.io> and install it.
   (No Xcode needed. AltStore is an equivalent alternative.)
2. Plug the iPhone into the Mac via USB. On the phone, tap **Trust** if prompted.
3. Open Sideloadly:
   - It should show your connected iPhone at the top.
   - Drag **`ExpenseTracker.ipa`** onto the Sideloadly window.
   - Enter your **free Apple ID** (e.g. `patwekaraftab@gmail.com`) in the Apple ID field.
   - Click **Start**. Enter your Apple ID password when asked.
     - If you use 2-factor auth, generate an **app-specific password** at
       <https://account.apple.com> → Sign-In & Security → App-Specific Passwords, and use that.
4. Sideloadly signs the IPA with a free 7-day certificate and installs it. Wait for **“Done”**.

---

## Part 3 — Trust the app + first launch (on the iPhone)

1. **Settings → General → VPN & Device Management → Developer App** → tap your Apple ID →
   **Trust**.
2. Open **Expense Tracker** from the home screen.

---

## Part 4 — The back-tap → voice shortcut (the original goal)

1. **Shortcuts** app → **+** → add action **Open URL** → `expensetracker://add` → name it
   *“Add Expense”*.
2. **Settings → Accessibility → Touch → Back Tap → Double Tap → “Add Expense”**.

Double-tapping the back of the iPhone now opens the app straight into voice-add. 🎙️

---

## Refreshing every 7 days
Reconnect the iPhone to the Mac, open Sideloadly, and re-run the same install (or use
AltStore’s auto-refresh feature if you prefer that tool). No rebuild needed unless the code
changed.
