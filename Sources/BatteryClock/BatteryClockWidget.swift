import AppKit
import PockKit
import IOKit.ps
import TinyConstraints

@_exported import struct Foundation.TimeInterval

@available(macOS 11.0, *)
public class BatteryClockWidget: PKWidget {
    public static let identifier = "com.andreashworth.batteryclock"
    public var customizationLabel: String = "BatteryClock"
    public var version = "1.5"
    public var view: NSView!
    public var hasPreferences: Bool { return true }

    private static let powerSourceCallback: IOPowerSourceCallbackType = { context in
        guard let ctx = context else { return }
        let widget = Unmanaged<BatteryClockWidget>.fromOpaque(ctx).takeUnretainedValue()
        DispatchQueue.main.async {
            widget.updateBatteryInfo()
        }
    }

    private var label: NSTextField!
    private var batteryIcon: NSImageView!
    private var stackView: NSStackView!

    internal var showTimeRemaining: Bool {
        get { UserDefaults.standard.bool(forKey: "showTimeRemaining") }
        set { UserDefaults.standard.set(newValue, forKey: "showTimeRemaining") }
    }
    internal var showPercentage: Bool {
        get { UserDefaults.standard.bool(forKey: "showPercentage") }
        set { UserDefaults.standard.set(newValue, forKey: "showPercentage") }
    }
    internal var useMacOSStyle: Bool {
        get { UserDefaults.standard.bool(forKey: "useMacOSStyle") }
        set { UserDefaults.standard.set(newValue, forKey: "useMacOSStyle") }
    }

    public required init() {
        initializeDefaultPreferences()
        self.view = NSView()
        setupUI()

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let runLoopSource = IOPSNotificationCreateRunLoopSource(BatteryClockWidget.powerSourceCallback, ctx)!.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)

        updateBatteryInfo()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func initializeDefaultPreferences() {
        guard !UserDefaults.standard.bool(forKey: "preferencesInitialized") else { return }
        UserDefaults.standard.set(true, forKey: "showTimeRemaining")
        UserDefaults.standard.set(true, forKey: "showPercentage")
        UserDefaults.standard.set(true, forKey: "useMacOSStyle")
        UserDefaults.standard.set(true, forKey: "preferencesInitialized")
    }

    private func setupUI() {
        setupStackView()
        setupBatteryIcon()
        setupLabel()
        setupLayout()
    }

    private func setupStackView() {
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.alignment = .centerY
        stackView.distribution = .fill
    }

    private func setupBatteryIcon() {
        batteryIcon = NSImageView()
        batteryIcon.imageScaling = .scaleProportionallyDown
        batteryIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            batteryIcon.widthAnchor.constraint(equalToConstant: 22),
            batteryIcon.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    private func setupLabel() {
        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .left
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
    }

    private func setupLayout() {
        stackView.addArrangedSubview(batteryIcon)
        stackView.addArrangedSubview(label)
        view.addSubview(stackView)
        stackView.centerInSuperview()
        stackView.edgesToSuperview(insets: .uniform(4))
        view.frame.size = NSSize(width: 120, height: 30)
    }

    private func updateBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        if useMacOSStyle {
            updateMacOSStyleBatteryIcon(level: level, isCharging: isCharging, isCharged: isCharged)
        } else {
            updateEmojiBatteryIcon(level: level, isCharging: isCharging, isCharged: isCharged)
        }
    }

    private func updateMacOSStyleBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        let image = NSImage(size: NSSize(width: 22, height: 12))
        image.lockFocus()

        let frame = NSRect(x: 0, y: 0, width: 20, height: 12)
        let path = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1
        path.stroke()

        let tip = NSRect(x: 20, y: 4, width: 2, height: 4)
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(rect: tip).fill()

        let widthVal = max(CGFloat(level) / 100.0 * 18, 1)
        let levelRect = NSRect(x: 1, y: 1, width: widthVal, height: 10)

        let currentTime = Date().timeIntervalSince1970
        let pulse = (sin(currentTime * 2) + 1) / 2
        var color: NSColor

        if isCharged {
            let brightness = 0.9 + (pulse * 0.1)
            color = NSColor(calibratedRed: 0, green: CGFloat(brightness), blue: 0, alpha: 1)
        } else if isCharging {
            let base = 0.6 + (pulse * 0.3)
            color = NSColor(calibratedRed: 0.2, green: CGFloat(base), blue: 0.2, alpha: 1)
        } else if level <= 10 {
            let redPulse = 0.7 + (pulse * 0.3)
            color = NSColor(calibratedRed: CGFloat(redPulse), green: 0, blue: 0, alpha: 1)
        } else if level <= 20 {
            let orangePulse = 0.8 + (pulse * 0.2)
            color = NSColor(calibratedRed: CGFloat(orangePulse), green: 0.4, blue: 0, alpha: 1)
        } else if level <= 50 {
            color = NSColor(calibratedRed: 0.9, green: 0.8, blue: 0, alpha: 1)
        } else {
            color = NSColor(calibratedRed: 0, green: 0.8, blue: 0, alpha: 1)
        }

        let gradient = NSGradient(colors: [color, color.withAlphaComponent(0.8)], atLocations: [0, 1], colorSpace: .deviceRGB)!
        gradient.draw(in: levelRect, angle: isCharging ? CGFloat(360 * pulse) : 90)

        if isCharging {
            let bolt = "⚡"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor.white
            ]
            let point = NSPoint(x: 5, y: 1)
            (bolt as NSString).draw(at: point, withAttributes: attributes)
        }

        image.unlockFocus()
        batteryIcon.image = image
    }

    private func updateEmojiBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        let emoji: String
        if isCharged || isCharging {
            emoji = "🔋⚡️"
        } else if level <= 10 {
            emoji = "🪫"
        } else if level <= 20 {
            emoji = "🔴"
        } else if level <= 50 {
            emoji = "🟡"
        } else {
            emoji = "🟢"
        }
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        (emoji as NSString).draw(at: NSPoint(x: 0, y: 0), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
        image.unlockFocus()
        batteryIcon.image = image
    }

    internal func updateBatteryInfo() {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        guard let ps = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
        else {
            label.stringValue = "No battery info"
            return
        }
        let info = getBatteryInfo(from: desc)
        updateDisplay(with: info)
    }

    private struct BatteryInfo {
        let percentage: Int
        let isACPowered: Bool
        let isCharging: Bool
        let isCharged: Bool
        let timeToEmpty: TimeInterval
        let timeToFullCharge: TimeInterval?
    }

    private func getBatteryInfo(from desc: [String: Any]) -> BatteryInfo {
        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxLevel = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = Int((Double(level) / Double(maxLevel)) * 100)
        let state = desc[kIOPSPowerSourceStateKey] as? String
        let ac = (state == kIOPSACPowerValue)
        let charging = ac && (desc[kIOPSIsChargingKey] as? Bool == true)
        let charged = ac && percentage >= 95
        let toFull: TimeInterval? = {
            if charging,
               let mins = desc[kIOPSTimeToFullChargeKey] as? Int,
               mins != -1 {
                return TimeInterval(mins * 60)
            }
            return nil
        }()
        let toEmpty: TimeInterval = {
            if !charging,
               let mins = desc[kIOPSTimeToEmptyKey] as? Int,
               mins != -1 {
                return TimeInterval(mins * 60)
            }
            return -1
        }()
        return BatteryInfo(percentage: percentage, isACPowered: ac, isCharging: charging, isCharged: charged, timeToEmpty: toEmpty, timeToFullCharge: toFull)
    }

    private func updateDisplay(with info: BatteryInfo) {
        DispatchQueue.main.async {
            self.updateBatteryIcon(level: info.percentage, isCharging: info.isCharging, isCharged: info.isCharged)
            let text = self.createDisplayString(from: info)
            self.updateLabelAndSize(with: text)
        }
    }

    private func createDisplayString(from info: BatteryInfo) -> String {
        var parts = [String]()

        if info.isCharging {
            parts.append("⚡")
        }

        if showPercentage {
            parts.append("\(info.percentage)%")
        }

        if showTimeRemaining {
            if info.isCharging, let tf = info.timeToFullCharge {
                let (h, m) = getHoursAndMinutes(from: tf)
                parts.append("(\(h)h \(m)m)")
            } else if !info.isACPowered, info.timeToEmpty != -1 {
                let (h, m) = getHoursAndMinutes(from: info.timeToEmpty)
                parts.append("(\(h)h \(m)m)")
            }
        }

        return parts.joined(separator: " ")
    }

    private func getHoursAndMinutes(from t: TimeInterval) -> (Int, Int) {
        (Int(t / 3600), Int((t.truncatingRemainder(dividingBy: 3600)) / 60))
    }

    private func updateLabelAndSize(with text: String) {
        label.stringValue = text
        let size = (text as NSString).size(withAttributes: [.font: label.font!])
        let width = size.width + (batteryIcon.isHidden ? 0 : 26) + 8
        view.frame.size = NSSize(width: width, height: 30)
    }

    public var preferenceViewController: PKWidgetPreference? {
        let prefs = BatteryClockPreferencesPane()
        prefs.widget = self
        return prefs
    }
}