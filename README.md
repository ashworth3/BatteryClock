# BatteryClock v1.4

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

### Building from Source
If you prefer to build from source:
```bash
# Clone the repository
git clone https://github.com/ashworth3/BatteryClock.git
cd BatteryClock

# Build the widget
swift build -c release

# Run the install script
./install.sh

# The widget will be at:
.build/release/BatteryClock.pock
```

### Requirements
- macOS 11.0 or later
- [Pock](https://pock.app) installed
- MacBook Pro with Touch Bar

## 🔄 Updates

### v1.4
- Simplified installation
- Robust functionality

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
