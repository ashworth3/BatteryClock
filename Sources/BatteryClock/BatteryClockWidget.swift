import AppKit
import PockKit
import IOKit.ps
import TinyConstraints

@_exported import struct Foundation.TimeInterval

@available(macOS 11.0, *)
public class BatteryClockWidget: PKWidget {
    // MARK: - Widget Configuration
    public static let identifier = "com.andreashworth.batteryclock"
    public var customizationLabel: String = "BatteryClock 1.3"
    public var version = "1.3"
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
    private let updateInterval: TimeInterval = 3  // Update every 3 seconds - balanced between responsiveness and battery life
    
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
        let preferences: BatteryClockPreferencesPane = BatteryClockPreferencesPane()
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
        
        // Draw battery level with gradient and dynamic effects
        let levelWidth = max(CGFloat(level) / 100.0 * 18, 1)
        let levelFrame = NSRect(x: 1, y: 1, width: levelWidth, height: 10)
        
        // Dynamic color and pulse effects
        let levelColor: NSColor
        let pulseFrequency: Double = 2.0 // Adjust for faster/slower pulsing
        let currentTime = Date().timeIntervalSince1970
        let pulseValue = (sin(currentTime * pulseFrequency) + 1) / 2 // Normalized pulse between 0 and 1
        
        if isCharged {
            // Fully charged - bright green with subtle pulse
            let brightness = 0.9 + (pulseValue * 0.1)
            levelColor = NSColor(calibratedRed: 0.0, green: CGFloat(brightness), blue: 0.0, alpha: 1.0)
        } else if isCharging {
            // Charging animation - moving gradient
            let gradientPhase = (currentTime * 2).truncatingRemainder(dividingBy: 2.0)
            let baseGreen = 0.6 + (pulseValue * 0.3)
            levelColor = NSColor(calibratedRed: 0.2, green: CGFloat(baseGreen), blue: 0.2, alpha: 1.0)
            
            // Add charging wave effect
            let waveWidth = levelFrame.width
            let wavePhase = gradientPhase * Double.pi * 2
            let wavePath = NSBezierPath()
            wavePath.move(to: NSPoint(x: levelFrame.minX, y: levelFrame.minY))
            
            for x in stride(from: 0, through: waveWidth, by: 1) {
                let normalizedX = x / waveWidth
                let y = sin(normalizedX * 4 * Double.pi + wavePhase) * 2 + 5 // Wave amplitude = 2
                wavePath.line(to: NSPoint(x: levelFrame.minX + x, y: levelFrame.minY + y))
            }
            
            wavePath.line(to: NSPoint(x: levelFrame.maxX, y: levelFrame.minY))
            wavePath.close()
            
            NSColor(calibratedRed: 0.3, green: 0.8, blue: 0.3, alpha: 0.3).setFill()
            wavePath.fill()
        } else if level <= 10 {
            // Critical - pulsing red
            let redPulse = 0.7 + (pulseValue * 0.3)
            levelColor = NSColor(calibratedRed: CGFloat(redPulse), green: 0.0, blue: 0.0, alpha: 1.0)
        } else if level <= 20 {
            // Low - orange with subtle pulse
            let orangePulse = 0.8 + (pulseValue * 0.2)
            levelColor = NSColor(calibratedRed: CGFloat(orangePulse), green: 0.4, blue: 0.0, alpha: 1.0)
        } else if level <= 50 {
            levelColor = NSColor(calibratedRed: 0.9, green: 0.8, blue: 0.0, alpha: 1.0)
        } else {
            levelColor = NSColor(calibratedRed: 0.0, green: 0.8, blue: 0.0, alpha: 1.0)
        }
        
        // Create gradient with dynamic effect
        let gradientLocations: [CGFloat] = [0.0, 1.0]
        let gradientColors = [levelColor, levelColor.withAlphaComponent(0.8)]
        let gradient = NSGradient(colors: gradientColors, atLocations: gradientLocations, colorSpace: NSColorSpace.deviceRGB)!
        gradient.draw(in: levelFrame, angle: isCharging ? (360.0 * pulseValue) : 90)
        
        // Draw charging indicator
        if isCharging || isCharged {
            context.saveGState()
            
            // Create dynamic bolt path
            let boltPath = NSBezierPath()
            let boltScale = 1.0 + (pulseValue * 0.2) // Dynamic scaling
            let centerX = 11.0
            let centerY = 6.0
            
            boltPath.move(to: NSPoint(x: centerX - 2 * boltScale, y: centerY + 3 * boltScale))
            boltPath.line(to: NSPoint(x: centerX + 2 * boltScale, y: centerY))
            boltPath.line(to: NSPoint(x: centerX, y: centerY))
            boltPath.line(to: NSPoint(x: centerX + 2 * boltScale, y: centerY - 3 * boltScale))
            boltPath.line(to: NSPoint(x: centerX - 2 * boltScale, y: centerY))
            boltPath.line(to: NSPoint(x: centerX, y: centerY))
            boltPath.close()
            
            // Dynamic glow effect
            let boltColor = isCharging ? NSColor.yellow : NSColor.white
            let glowRadius = isCharging ? (2 + pulseValue * 2) : 2
            context.setShadow(offset: .zero, blur: glowRadius, color: boltColor.withAlphaComponent(0.9).cgColor)
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
} 