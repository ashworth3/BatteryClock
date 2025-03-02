# BatteryClock v1.1

A minimal battery status widget for [Pock](https://pock.app) that displays your MacBook's battery information in the Touch Bar.

## ✨ Features

- **Battery Status Display**
  - Battery percentage
  - Status battery level Indicator

- **Time Information**
  - On Battery: Shows estimated time remaining
  - While Charging: Shows time until fully charged
  - Auto-hides when information unavailable

- **Battery Icon**
  - Clean, native macOS-style battery indicator
  - Changes based on battery level

## 📦 Installation

1. Build the widget using the instructions below
2. Locate the widget at `.build/release/BatteryClock.pock`
3. Double-click the .pock file to install it in Pock
4. Enable the widget in Pock's widget manager

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/andreashworth/BatteryClock.git
cd BatteryClock

# Build the widget
swift build -c release

# The widget will be at:
.build/release/BatteryClock.pock
```

## 📋 Requirements

- macOS 11.0 or later
- [Pock](https://pock.app) installed
- MacBook Pro with Touch Bar

## 👤 Author

Made with ❤️ by [Andre Ashworth](https://github.com/ashworth3)

---

<p align="center">
  Made with ❤️ for the Pock community
</p>
