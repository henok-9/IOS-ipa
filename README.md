# 📱 Antigrav iOS App

A native SwiftUI client for the **Antigrav** headless server. Allows scanning TikTok profiles for target poses, reviewing close matches, and downloading extracted video segments.

---

## 🚀 Building the Sideloadable IPA (Automated via GitHub Actions)

This repository includes a GitHub Actions workflow that builds an unsigned, ARM64 `.ipa` package ready for **SideStore** or **AltStore**.

### Workflow:
1. Push your changes or trigger the workflow manually in **Actions** -> **Build iOS IPA (SideStore)**.
2. Download the `Antigrav-SideStore-IPA` artifact from the workflow summary.
3. On iOS, open the downloaded `.zip` in the **Files** app; tap it once to unpack `Antigrav.ipa`.
4. In **SideStore**, tap `+` in the top bar, select `Antigrav.ipa`, and install.

---

## 🛠 Local Project Generation (Optional, on macOS)

If you ever need to open or develop the project inside Xcode on a Mac:

```bash
brew install xcodegen
xcodegen generate
open Antigrav.xcodeproj
```

---

## ⚙️ Connecting to your Antigrav Backend

1. Ensure the Antigrav server is running on your host machine:
   ```bash
   antigrav-server
   ```
2. Open **Antigrav** on your iPhone.
3. Tap the **gear icon** (Settings) in the top-right toolbar.
4. Set the **Headless Backend URL** to your server's IP and port (e.g. `http://192.168.1.100:8000`).
5. Tap **Reload Poses from Server** to confirm connection.
