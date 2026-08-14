# Toolchain setup (Windows) — one time

Goal: get `flutter doctor` to pass and your Android phone recognized over USB. Budget ~45–60 min (mostly downloads). You have **Chocolatey**, so most of it is a few commands.

> Run the install commands in an **Administrator PowerShell**: press <kbd>Win</kbd>, type *PowerShell*, right-click → **Run as administrator**.

## 1. Install Android Studio + Flutter

```powershell
choco install -y androidstudio
choco install -y flutter
```

- `androidstudio` brings the Android SDK, platform tools, and a bundled JDK.
- `flutter` installs the SDK (to `C:\tools\flutter`) and adds it to PATH.

Close and reopen PowerShell afterwards so PATH refreshes.

> Prefer the official Flutter SDK instead of Chocolatey? Skip `choco install flutter` and instead:
> ```powershell
> git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
> ```
> then add `C:\src\flutter\bin` to your PATH (System Properties → Environment Variables). Use **one** method, not both.

## 2. First-run Android Studio setup

1. Launch **Android Studio** → complete the **Setup Wizard** (Standard install). Let it download the **Android SDK**, **SDK Platform-Tools**, and **command-line tools**.
2. In **Settings → Languages & Frameworks → Android SDK → SDK Tools**, make sure **Android SDK Command-line Tools** is checked → Apply.

## 3. Accept licenses & verify

Back in a normal PowerShell:

```powershell
flutter doctor --android-licenses
flutter doctor
```

Work through anything `flutter doctor` flags until **Flutter**, **Android toolchain**, and **VS Code** show ✓. (An iOS ✗ is expected on Windows — we don't need it until the Mac/Codemagic step much later.)

## 4. VS Code extensions

```powershell
code --install-extension Dart-Code.dart-code
code --install-extension Dart-Code.flutter
```

## 5. Connect your Android phone

1. On the phone: **Settings → About phone → tap "Build number" 7 times** to unlock Developer options.
2. **Settings → Developer options → enable "USB debugging"**.
3. Plug the phone into the PC with a USB cable. Tap **Allow** on the "Allow USB debugging?" prompt.
4. Verify the PC sees it:

```powershell
flutter devices
```

You should see your phone listed. That's the green light — tell me `flutter doctor` is clean and your device shows up, and I'll scaffold the app and run it on your phone.

---

### Quick checklist
- [ ] `choco install -y androidstudio flutter` (admin)
- [ ] Android Studio setup wizard completed (SDK + cmdline-tools)
- [ ] `flutter doctor --android-licenses` all accepted
- [ ] `flutter doctor` — Flutter, Android toolchain, VS Code all ✓
- [ ] Dart + Flutter VS Code extensions installed
- [ ] USB debugging on, phone shows in `flutter devices`
