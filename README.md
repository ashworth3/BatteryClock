# BatteryClock v1.3

A minimal battery status widget for [Pock](https://pock.app) that displays your MacBook's battery information in the Touch Bar.

## ✨ Features

- **Battery Status Display**
  - Battery percentage
  - Battery level indicator
  - Optimized 3-second refresh rate for battery efficiency

- **Time Information**
  - On Battery: Shows estimated time remaining
  - While Charging: Shows time until fully charged
  - Auto-hides when information unavailable

- **Battery Icon Styles**
  - Clean, native macOS-style battery indicator
  - Changes based on battery level
  - Basic charging indicator

## 📦 Installation

### Quick Install (Recommended)
1. Download [BatteryClock-1.3.pock.zip](BatteryClock-1.3.pock.zip) directly from this repository
2. Unzip the downloaded file
3. Double-click the `BatteryClock.pock` file
4. Click "Install" when prompted
5. Open Pock's Widget Manager (click Pock icon in menu bar)
6. Enable "BatteryClock" in the widget list

### Building from Source
If you prefer to build from source:
```bash
# Clone the repository
git clone https://github.com/ashworth3/BatteryClock.git
cd BatteryClock

# Build the widget
swift build -c release

# The widget will be at:
.build/release/BatteryClock.pock
```

### Requirements
- macOS 11.0 or later
- [Pock](https://pock.app) installed
- MacBook Pro with Touch Bar

### Troubleshooting
- If you have a previous version installed, remove it from Pock's Widget Manager before installing the new version
- Make sure Pock is running before installing the widget
- If the widget doesn't appear immediately, try restarting Pock

## 🔄 Updates

### v1.3
- Optimized refresh rate for better battery life
- Enhanced battery status display
- Improvements to functionality

### v1.2
- Initial public release
- Basic battery status display
- Time remaining calculations

### v1.1
- Initial basic version
- Estimated battery clock feature
- Emoji battery icon and percentage

## 👤 Author

Made with ❤️ by [Andre Ashworth](https://github.com/ashworth3)

---

<p align="center">
  Engineered by <a href="https://github.com/ashworth3">@ashworth3</a>
</p>
