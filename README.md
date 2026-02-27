# PureRate 🎧

**PureRate** is a lightweight, natively compiled macOS Menu Bar application that effortlessly synchronizes your system's hardware audio sample rate to match the exact lossless/hi-res lossless format of the currently playing track in Apple Music.

[![Vercel Deployment](https://img.shields.io/badge/Website-Live-7c5cfc?style=for-the-badge&logo=vercel)](https://purerate-web.vercel.app)
[![GitHub Release](https://img.shields.io/github/v/release/uzzano-info/PureRate?style=for-the-badge&color=3b82f6)](https://github.com/uzzano-info/PureRate/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

### The Problem
Apple Music currently does not automatically switch your macOS audio device's sample rate. This requirement often forces audiophiles to manually intervene via the **Audio MIDI Setup** utility every time a track changes from 44.1kHz to 96kHz or 192kHz. Failing to do so results in non-bit-perfect playback.

### The Solution
PureRate runs completely silently in the background. It monitors system logs to detect exactly what Apple Music is decoding and immediately instructs CoreAudio to match your DAC's sample rate. **Enjoy a true bit-perfect music listening experience with zero effort.**

---

## ✨ Key Features (v3.1)

- **⚡ Automatic Rate Switching:** Detects 44.1kHz, 48kHz, 88.2kHz, 96kHz, 176.4kHz, and 192kHz in real-time.
- **🪄 Glassmorphism UI:** A modern SwiftUI interface with gradient accents, info chips, and live-monitoring indicators.
- **📊 Rate Change History:** An expandable timeline records every successful (and failed) switch with timestamps.
- **🎯 Target Hardware Selection:** Explicitly assign which DAC gets synchronized, or let it follow the system default.
- **✨ Hi-Res Ready:** Full support for Apple Music's Hi-Res Lossless catalog (up to 24-bit/192kHz).
- **🚀 Zero Footprint:** Built with native Swift (SwiftUI, OSLog, CoreAudio). No Electron, no bloat, < 2 MB.
- **🔔 Desktop Notifications:** Optional alerts inform you when the sample rate changes.
- **🔄 Launch at Login:** Seamless integration with `SMAppService` to start with your Mac.

---

## 📥 Installation

### Method 1: Direct Download (Recommended)
1. Download the latest `PureRate.dmg` from the [Releases](https://github.com/uzzano-info/PureRate/releases/latest) page.
2. Open the disk image and drag **PureRate.app** to your **Applications** folder.
3. Launch PureRate and grant any requested permissions (Full Disk Access is often required for log reading).

### Method 2: Homebrew
```bash
brew install --cask https://github.com/uzzano-info/PureRate/raw/main/purerate.rb
```

---

## 🛠 Project Structure
The PureRate project is split into two repositories:
- **[PureRate](https://github.com/uzzano-info/PureRate)**: macOS App source code, build scripts, and DMG releases.
- **[PureRate-web](https://github.com/uzzano-info/PureRate-web)**: The premium landing page source code ([Live Site](https://purerate-web.vercel.app)).

---

## 🏗 Compiling From Source
Requires **macOS 14+** and **Swift 5.9+**.
```bash
git clone https://github.com/uzzano-info/PureRate.git
cd PureRate
./deploy.sh
```
*Note: `deploy.sh` will build the app and package it into a `.dmg` automatically.*

---

## ☕ Support & Share

If PureRate has improved your listening experience, consider supporting its continued development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-yellow.svg?style=for-the-badge&logoChart=buy-me-a-coffee)](https://www.buymeachoffee.com/purerate)

**Help others discover bit-perfect audio:**
- [Share on X (Twitter)](https://twitter.com/intent/tweet?text=Check%20out%20PureRate%20-%20The%20automatic%20sample%20rate%20switcher%20for%20Apple%20Music%20on%20macOS!%20https://purerate-web.vercel.app)
- [Post on Reddit](https://www.reddit.com/submit?url=https://purerate-web.vercel.app&title=PureRate:%20Automatic%20Sample%20Rate%20Switching%20for%20Apple%20Music%20on%20macOS)

---

## ⚖️ Acknowledgements
Inspiration and log-parsing concepts derived from the original [LosslessSwitcher](https://github.com/vincentneo/LosslessSwitcher). PureRate aims to provide a more modern, SwiftUI-based implementation with richer status tracking and a native glassmorphism UI.

---
© 2026 PureRate. Open-source under MIT license.
