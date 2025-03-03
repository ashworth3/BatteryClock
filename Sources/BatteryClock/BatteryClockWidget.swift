import AppKit
import PockKit
import IOKit.ps
import TinyConstraints

@_exported import struct Foundation.TimeInterval

public class BatteryClockWidget: PKWidget {
    // MARK: - Widget Configuration
    public static let identifier = "com.andreashworth.batteryclock"
    public var customizationLabel: String = "BatteryClock 1.5"
    public var version = "1.5"
    public var view: NSView!
    public var hasPreferences: Bool { return false }
    
    // MARK: - UI Elements
    private lazy var stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        return stack
    }()
    
    private lazy var batteryIcon: NSImageView = {
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyDown
        return icon
    }()
    
    private lazy var label: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.alignment = .left
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    
    // MARK: - State
    internal var useMacOSStyle: Bool = true
    internal var showPercentage: Bool = true
    internal var showTimeRemaining: Bool = true
    private var lastPercentage: Int = -1
    private var lastChargingState: Bool = false
    private var lastChargedState: Bool = false
    private var powerSourceCallback: CFRunLoopSource?
    private var lastUpdateTime: TimeInterval = 0
    private var minimumUpdateInterval: TimeInterval = 0.1
    
    // MARK: - Initialization
    public required init() {
        view = NSView()
        setupUI()
        registerForPowerSourceChanges()
        
        // Initial update
        updateBatteryInfo()
        
        // Backup timer for reliability (every 30 seconds)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 30)
                DispatchQueue.main.async {
                    self?.updateBatteryInfo()
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let source = powerSourceCallback {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
        }
    }
    
    private func registerForPowerSourceChanges() {
        let powerSourceCallback: IOPowerSourceCallbackType = { context in
            let widget = Unmanaged<BatteryClockWidget>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                widget.updateBatteryInfo()  // Direct call to update
            }
        }
        
        let runLoopSource = IOPSNotificationCreateRunLoopSource(powerSourceCallback, Unmanaged.passUnretained(self).toOpaque())
        if let source = runLoopSource?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
            self.powerSourceCallback = source
        }
    }
    
    private func setupUI() {
        // Add views to stack
        stackView.addArrangedSubview(batteryIcon)
        stackView.addArrangedSubview(label)
        
        // Set main view
        self.view = stackView
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
        let pulseFrequency: Double = 2.0 // Adjust for faster/slower pulsing
        let currentTime = Date().timeIntervalSince1970
        let pulseValue = (sin(currentTime * pulseFrequency) + 1) / 2 // Normalized pulse between 0 and 1
        
        // Draw charging indicator (lightning bolt) when charging
        if isCharging {
            // Charging animation - yellow-green pulsing
            let baseGreen = 0.8 + (pulseValue * 0.2)
            let levelColor = NSColor(calibratedRed: 0.8, green: baseGreen, blue: 0.0, alpha: 1.0)
            
            // Create gradient with dynamic effect
            let gradientLocations: [CGFloat] = [0.0, 1.0]
            let gradientColors = [levelColor, levelColor.withAlphaComponent(0.8)]
            let gradient = NSGradient(colors: gradientColors, atLocations: gradientLocations, colorSpace: NSColorSpace.deviceRGB)!
            gradient.draw(in: levelFrame, angle: 360.0 * pulseValue)
            
            context.saveGState()
            
            // Create lightning bolt path
            let boltPath = NSBezierPath()
            let boltScale = 1.0 + (pulseValue * 0.3) // More pronounced pulsing
            let centerX = levelFrame.midX
            let centerY = levelFrame.midY
            
            // Draw a larger lightning bolt
            boltPath.move(to: NSPoint(x: centerX - 5 * boltScale, y: centerY + 4))
            boltPath.line(to: NSPoint(x: centerX, y: centerY))
            boltPath.line(to: NSPoint(x: centerX - 2, y: centerY))
            boltPath.line(to: NSPoint(x: centerX + 5 * boltScale, y: centerY - 4))
            boltPath.close()
            
            // Enhanced glow effect
            let boltColor = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)
            context.setShadow(offset: .zero, blur: 4 + pulseValue * 2, color: boltColor.cgColor)
            
            boltColor.setFill()
            boltPath.fill()
            
            context.restoreGState()
        } else {
            // Normal battery colors
            let levelColor: NSColor
            if isCharged {
                levelColor = NSColor(calibratedRed: 0.2, green: 0.9, blue: 0.2, alpha: 1.0)
            } else if level <= 10 {
                let redPulse = 0.7 + (pulseValue * 0.3)
                levelColor = NSColor(calibratedRed: CGFloat(redPulse), green: 0.0, blue: 0.0, alpha: 1.0)
            } else if level <= 20 {
                levelColor = NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.0, alpha: 1.0)
            } else {
                levelColor = NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
            }
            
            let gradientLocations: [CGFloat] = [0.0, 1.0]
            let gradientColors = [levelColor, levelColor.withAlphaComponent(0.8)]
            let gradient = NSGradient(colors: gradientColors, atLocations: gradientLocations, colorSpace: NSColorSpace.deviceRGB)!
            gradient.draw(in: levelFrame, angle: 90)
        }
        
        image.unlockFocus()
        
        // Update the image immediately on the main thread
        DispatchQueue.main.async {
            self.batteryIcon.image = image
        }
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
    
    // MARK: - Battery Info Update
    internal func updateBatteryInfo() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let battery = sources.first,
              let description = IOPSGetPowerSourceDescription(info, battery)?.takeUnretainedValue() as? [String: Any] else { return }
        
        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int ?? -1
        let isCharged = description[kIOPSIsChargedKey] as? Bool ?? false
        
        // Update state
        lastPercentage = currentCapacity
        lastChargingState = isCharging
        lastChargedState = isCharged
        lastUpdateTime = Date().timeIntervalSince1970
        
        // Update UI on main thread with high priority
        DispatchQueue.main.async(qos: .userInteractive) { [weak self] in
            guard let self = self else { return }
            
            // Update battery icon
            self.updateBatteryIcon(level: currentCapacity, isCharging: isCharging, isCharged: isCharged)
            
            // Build status text
            var statusText = ""
            
            // Add percentage
            if self.showPercentage {
                statusText += "\(currentCapacity)%"
            }
            
            // Add charging indicator if charging
            if isCharging {
                statusText += " ⚡️"
            }
            
            // Only show time remaining when not charging
            if self.showTimeRemaining && !isCharging && timeToEmpty > 0 {
                let (hours, mins) = self.formatTime(minutes: timeToEmpty)
                if hours > 0 {
                    statusText += " (\(hours)h \(mins)m)"
                } else {
                    statusText += " (\(mins)m)"
                }
            }
            
            // Ensure text updates on main thread
            self.label.stringValue = statusText
            
            // Update stack view size
            let labelSize = statusText.size(withAttributes: [.font: self.label.font!])
            self.view.frame.size = NSSize(width: self.batteryIcon.frame.width + labelSize.width + 8,
                                        height: 30)
        }
    }
    
    private func formatTime(minutes: Int) -> (hours: Int, minutes: Int) {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return (hours, remainingMinutes)
    }
    
    // MARK: - Widget Lifecycle
    public func widgetDidLoad() {
        updateBatteryInfo()
    }
    
    public func viewWillAppear() {
        updateBatteryInfo()
    }
    
    public func viewDidAppear() {
        updateBatteryInfo()
    }
    
    public func viewWillDisappear() {}
    
    public func viewDidDisappear() {}
    
    // MARK: - Preferences
    public var preferenceViewController: PKWidgetPreference? {
        let preferences = BatteryClockPreferencesPane()
        preferences.widget = self
        return preferences
    }
    
    // MARK: - Touch Bar Events
    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier.rawValue == BatteryClockWidget.identifier {
            let customViewItem = NSCustomTouchBarItem(identifier: identifier)
            customViewItem.view = self.view
            customViewItem.customizationLabel = self.customizationLabel
            return customViewItem
        }
        return nil
    }
} 