# Building the iPhone app on your Mac mini

You develop/test on Windows (Android); when you want an iPhone build, pull the repo on the Mac mini and run it from Xcode. **A free Apple ID is enough** to install on your own iPhone (7-day expiry — just re-run from Xcode to refresh). Pay the $99/yr Apple Developer fee only if/when you want TestFlight or App Store.

## One-time setup on the Mac mini

1. **Xcode** — install from the App Store, open it once to finish component install, then:
   ```bash
   sudo xcodebuild -license accept
   ```
2. **Homebrew** (if not installed) — <https://brew.sh>
3. **Flutter + CocoaPods**:
   ```bash
   brew install --cask flutter
   brew install cocoapods
   flutter doctor        # accept any prompts; Xcode + CocoaPods should be ✓
   ```

## Every time you pull new code

```bash
git clone https://github.com/<your-username>/expense_tracker.git
cd expense_tracker

# .env is NOT in git (secrets). Recreate it once from the example:
cp .env.example .env
# then edit .env and paste your SUPABASE_URL + SUPABASE_ANON_KEY
# (same values already in your Windows .env / Supabase dashboard)

flutter pub get
cd ios && pod install && cd ..
```

## Run on your iPhone

1. Open the iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode: select the **Runner** target → **Signing & Capabilities** →
   - Tick **Automatically manage signing**.
   - **Team:** add your Apple ID (free "Personal Team" is fine).
   - If it complains the bundle id is taken, change it to something unique, e.g. `com.aftabpatwekar.expensetracker`.
3. Plug in your iPhone via USB → **Trust** the computer on the phone.
4. Pick your iPhone in the device dropdown → press **▶ Run**. (Or from terminal: `flutter run -d <your-iphone>`.)
5. First launch: on the iPhone, **Settings → General → VPN & Device Management → Developer App → Trust**.

The app already has what iOS needs: **microphone + speech** permission strings, and the **`expensetracker://` URL scheme** so the Back-Tap → Shortcut → voice flow works.

## Set up "double-tap back → voice" on the iPhone (the original ask)

1. **Shortcuts app** → **+** → add action **Open URL** → `expensetracker://add` → name it "Add Expense".
2. **Settings → Accessibility → Touch → Back Tap → Double Tap → "Add Expense"**.

Now double-tapping the back of your iPhone opens the app straight into voice-add. 🎙️

## Notes
- **7-day expiry (free Apple ID):** the app stops opening after 7 days — just re-run from Xcode to refresh another 7 days. TestFlight ($99/yr) removes this.
- You can also do all future development on the Mac mini if you prefer — `flutter run` works the same.
