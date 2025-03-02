import AppKit
import PockKit
import IOKit.ps
import TinyConstraints

// Import the AppIcon extension
@_exported import struct Foundation.URL
@_exported import struct Foundation.TimeInterval

@available(macOS 11.0, *)
public class BatteryClockWidget: PKWidget {
    // MARK: - Widget Configuration
    public static let identifier = "com.andreashworth.batteryclock"
    public var customizationLabel = "Battery Clock"
    public var view: NSView!
    public var hasPreferences: Bool { return true }
    
    // MARK: - UI Components
    private var label: NSTextField!
    private var batteryIcon: NSImageView!
    private var stackView: NSStackView!
    
    // MARK: - Battery Info
    private var updateTimer: Timer?
    private let powerSource = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    private let powerSourcesList = IOPSCopyPowerSourcesList(IOPSCopyPowerSourcesInfo().takeRetainedValue()).takeRetainedValue() as Array
    private let updateInterval: TimeInterval = 5  // Fixed update interval
    
    // MARK: - User Preferences
    internal var showTimeRemaining: Bool {
        get { return UserDefaults.standard.bool(forKey: "showTimeRemaining") }
        set { UserDefaults.standard.set(newValue, forKey: "showTimeRemaining") }
    }
    
    internal var showPercentage: Bool {
        get { return UserDefaults.standard.bool(forKey: "showPercentage") }
        set { UserDefaults.standard.set(newValue, forKey: "showPercentage") }
    }
    
    internal var useMacOSStyle: Bool {
        get { return UserDefaults.standard.bool(forKey: "useMacOSStyle") }
        set { UserDefaults.standard.set(newValue, forKey: "useMacOSStyle") }
    }
    
    // MARK: - Widget Icon
    public var icon: NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 12))
        image.lockFocus()
        
        // Draw battery outline
        let frame = NSRect(x: 0, y: 0, width: 20, height: 12)
        let path = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Draw battery tip
        let tipFrame = NSRect(x: 20, y: 4, width: 2, height: 4)
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(rect: tipFrame).fill()
        
        // Draw battery level - red on left side
        let redLevelFrame = NSRect(x: 1, y: 1, width: 4, height: 10)
        NSColor.red.setFill()
        NSBezierPath(rect: redLevelFrame).fill()
        
        image.unlockFocus()
        return image
    }
    
    // MARK: - Preferences
    public var preferenceViewController: PKWidgetPreference? {
        let preferences = BatteryClockPreferences()
        preferences.widget = self
        return preferences
    }
    
    // MARK: - Initialization
    public required init() {
        initializeDefaultPreferences()
        self.view = NSView()
        setupUI()
    }
    
    private func initializeDefaultPreferences() {
        guard !UserDefaults.standard.bool(forKey: "preferencesInitialized") else { return }
        
        UserDefaults.standard.set(true, forKey: "showTimeRemaining")
        UserDefaults.standard.set(true, forKey: "showPercentage")
        UserDefaults.standard.set(true, forKey: "useMacOSStyle")
        UserDefaults.standard.set(true, forKey: "preferencesInitialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopUpdatingBatteryInfo()
    }
    
    // MARK: - UI Setup
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
    
    // MARK: - Battery Icon Management
    private func updateBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        if useMacOSStyle {
            updateMacOSStyleBatteryIcon(level: level, isCharging: isCharging, isCharged: isCharged)
        } else {
            updateEmojiBatteryIcon(level: level, isCharging: isCharging, isCharged: isCharged)
        }
    }
    
    // MARK: - Widget Lifecycle
    public func widgetDidLoad() {
        updateBatteryInfo()
    }
    
    public func viewWillAppear() {
        startUpdatingBatteryInfo()
    }
    
    public func viewDidAppear() {
        updateBatteryInfo()
    }
    
    public func viewWillDisappear() {
        stopUpdatingBatteryInfo()
    }
    
    public func viewDidDisappear() {}
    
    // MARK: - Timer Management
    private func startUpdatingBatteryInfo() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
        updateTimer?.fire()
    }
    
    private func stopUpdatingBatteryInfo() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func restartTimer() {
        stopUpdatingBatteryInfo()
        startUpdatingBatteryInfo()
    }
    
    // MARK: - Battery Info Update
    internal func updateBatteryInfo() {
        guard let powerSource = powerSourcesList.first,
              let powerSourceDesc = IOPSGetPowerSourceDescription(self.powerSource, powerSource).takeUnretainedValue() as? [String: Any] else {
            label.stringValue = "No battery info"
            return
        }
        
        let batteryInfo = getBatteryInfo(from: powerSourceDesc)
        updateDisplay(with: batteryInfo)
    }
    
    private struct BatteryInfo {
        let level: Int
        let isACPowered: Bool
        let isCharging: Bool
        let isCharged: Bool
        let timeRemaining: TimeInterval
        let timeToFullCharge: TimeInterval?
    }
    
    private func getBatteryInfo(from powerSourceDesc: [String: Any]) -> BatteryInfo {
        let timeRemaining = IOPSGetTimeRemainingEstimate()
        let batteryLevel = powerSourceDesc[kIOPSCurrentCapacityKey] as? Int ?? 0
        
        let powerSourceState = powerSourceDesc[kIOPSPowerSourceStateKey] as? String
        let isACPowered = powerSourceState == kIOPSACPowerValue
        let isCharging = isACPowered && (powerSourceDesc[kIOPSIsChargingKey] as? Bool == true)
        let isCharged = isACPowered && batteryLevel >= 95
        
        let timeToFullCharge: TimeInterval? = {
            if isCharging, let timeToFull = powerSourceDesc[kIOPSTimeToFullChargeKey] as? Int, timeToFull != -1 {
                return TimeInterval(timeToFull * 60)
            }
            return nil
        }()
        
        return BatteryInfo(
            level: batteryLevel,
            isACPowered: isACPowered,
            isCharging: isCharging,
            isCharged: isCharged,
            timeRemaining: timeRemaining,
            timeToFullCharge: timeToFullCharge
        )
    }
    
    private func updateDisplay(with info: BatteryInfo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.updateBatteryIcon(level: info.level, isCharging: info.isCharging || info.isCharged, isCharged: info.isCharged)
            self.batteryIcon.isHidden = false
            
            let displayString = self.createDisplayString(from: info)
            self.updateLabelAndSize(with: displayString)
        }
    }
    
    private func createDisplayString(from info: BatteryInfo) -> String {
        var components: [String] = []
        
        if showPercentage {
            components.append("\(info.level)%")
        }
        
        if showTimeRemaining {
            if info.isCharging, let timeToFull = info.timeToFullCharge {
                let (hours, minutes) = getHoursAndMinutes(from: timeToFull)
                components.append("(⚡️ \(hours)h \(minutes)m)")
            } else if !info.isACPowered && info.timeRemaining != kIOPSTimeRemainingUnknown {
                let (hours, minutes) = getHoursAndMinutes(from: info.timeRemaining)
                components.append("(\(hours)h \(minutes)m)")
            }
        }
        
        return components.joined(separator: " ")
    }
    
    private func getHoursAndMinutes(from timeInterval: TimeInterval) -> (hours: Int, minutes: Int) {
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        return (hours, minutes)
    }
    
    private func updateLabelAndSize(with displayString: String) {
        let attributedString = NSAttributedString(string: displayString, attributes: [
            .font: label.font as Any
        ])
        let textWidth = attributedString.size().width
        let requiredWidth = textWidth + (batteryIcon.isHidden ? 0 : 26) + 8
        
        label.stringValue = displayString
        view.frame.size = NSSize(width: requiredWidth, height: 30)
    }
    
    private func updateMacOSStyleBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        let image = NSImage(size: NSSize(width: 22, height: 12))
        image.lockFocus()
        
        let context = NSGraphicsContext.current!.cgContext
        
        // Draw battery outline
        let frame = NSRect(x: 0, y: 0, width: 20, height: 12)
        let path = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Draw battery tip
        let tipFrame = NSRect(x: 20, y: 4, width: 2, height: 4)
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(rect: tipFrame).fill()
        
        // Draw battery level with gradient
        let levelWidth = max(CGFloat(level) / 100.0 * 18, 1) // Ensure at least 1px width for visibility
        let levelFrame = NSRect(x: 1, y: 1, width: levelWidth, height: 10)
        
        // Choose color based on battery level
        let levelColor: NSColor
        if isCharged {
            // Fully charged - bright green
            levelColor = NSColor(calibratedRed: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)
        } else if isCharging {
            // Charging but not full - pulsing green
            let pulseValue = sin(Date().timeIntervalSince1970 * 3) * 0.3 + 0.7
            levelColor = NSColor(calibratedRed: 0.2, green: 0.8 * CGFloat(pulseValue), blue: 0.2, alpha: 1.0)
        } else if level <= 10 {
            // Critical - solid red
            levelColor = NSColor(calibratedRed: 0.9, green: 0.1, blue: 0.1, alpha: 1.0)
        } else if level <= 20 {
            // Low - pulsing red
            let pulseValue = sin(Date().timeIntervalSince1970 * 3) * 0.5 + 0.5
            levelColor = NSColor(calibratedRed: 0.9, green: 0.3 * CGFloat(pulseValue), blue: 0.2 * CGFloat(pulseValue), alpha: 1.0)
        } else if level <= 50 {
            // Medium - yellow
            levelColor = NSColor(calibratedRed: 0.9, green: 0.8, blue: 0.0, alpha: 1.0)
        } else {
            // Good - green
            levelColor = NSColor(calibratedRed: 0.0, green: 0.8, blue: 0.0, alpha: 1.0)
        }
        
        // Create gradient
        let gradient = NSGradient(starting: levelColor, ending: levelColor.withAlphaComponent(0.8))!
        gradient.draw(in: levelFrame, angle: 90)
        
        // Draw charging bolt if charging
        if isCharging || isCharged {
            context.saveGState()
            
            // Create bolt path
            let boltPath = NSBezierPath()
            boltPath.move(to: NSPoint(x: 9, y: 9))
            boltPath.line(to: NSPoint(x: 13, y: 6))
            boltPath.line(to: NSPoint(x: 11, y: 6))
            boltPath.line(to: NSPoint(x: 13, y: 3))
            boltPath.line(to: NSPoint(x: 9, y: 6))
            boltPath.line(to: NSPoint(x: 11, y: 6))
            boltPath.close()
            
            // Draw bolt with glow effect - brighter for charging
            let boltColor = isCharging ? NSColor.yellow : NSColor.white
            context.setShadow(offset: .zero, blur: isCharging ? 4 : 2, 
                             color: boltColor.withAlphaComponent(0.9).cgColor)
            boltColor.setFill()
            boltPath.fill()
            
            context.restoreGState()
        }
        
        image.unlockFocus()
        batteryIcon.image = image
    }
    
    private func updateEmojiBatteryIcon(level: Int, isCharging: Bool, isCharged: Bool = false) {
        let batteryEmoji: String
        
        if isCharged {
            batteryEmoji = "🔋⚡️" // Fully charged battery
        } else if isCharging {
            batteryEmoji = "🔋⚡️" // Charging battery
        } else {
            switch level {
            case 0...10:
                batteryEmoji = "🪫" // Empty battery
            case 11...20:
                batteryEmoji = "🔴" // Red circle for low
            case 21...50:
                batteryEmoji = "🟡" // Yellow circle for medium
            case 51...100:
                batteryEmoji = "🟢" // Green circle for good
            default:
                batteryEmoji = "🔋" // Default battery
            }
        }
        
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14)
        ]
        
        let emojiString = NSAttributedString(string: batteryEmoji, attributes: attributes)
        emojiString.draw(at: NSPoint(x: 0, y: 0))
        
        image.unlockFocus()
        batteryIcon.image = image
    }
}

// MARK: - Font Extension
extension NSFont {
    static func monospacedDigitalFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
} 