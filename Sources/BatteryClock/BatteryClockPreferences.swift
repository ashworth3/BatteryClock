import AppKit
import PockKit

@objc(BatteryClockPreferences)
class BatteryClockPreferences: NSViewController, PKWidgetPreference {
    static var nibName: NSNib.Name = "BatteryClockPreferences"
    
    weak var widget: BatteryClockWidget?
    
    // UI Elements
    private var iconStyleCheckbox: NSButton!
    private var showPercentageCheckbox: NSButton!
    private var showTimeRemainingCheckbox: NSButton!
    
    override func loadView() {
        // Create the main view
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        // Create checkboxes
        iconStyleCheckbox = NSButton(checkboxWithTitle: "Use macOS Style Battery Icon", target: self, action: #selector(iconStyleChanged(_:)))
        showPercentageCheckbox = NSButton(checkboxWithTitle: "Show Battery Percentage", target: self, action: #selector(showPercentageChanged(_:)))
        showTimeRemainingCheckbox = NSButton(checkboxWithTitle: "Show Time Remaining", target: self, action: #selector(showTimeRemainingChanged(_:)))
        
        // Position checkboxes
        iconStyleCheckbox.frame = NSRect(x: 18, y: 84, width: 264, height: 18)
        showPercentageCheckbox.frame = NSRect(x: 18, y: 52, width: 264, height: 18)
        showTimeRemainingCheckbox.frame = NSRect(x: 18, y: 20, width: 264, height: 18)
        
        // Add checkboxes to view
        mainView.addSubview(iconStyleCheckbox)
        mainView.addSubview(showPercentageCheckbox)
        mainView.addSubview(showTimeRemainingCheckbox)
        
        self.view = mainView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadCurrentPreferences()
    }
    
    func reset() {
        iconStyleCheckbox.state = .on
        showPercentageCheckbox.state = .on
        showTimeRemainingCheckbox.state = .on
        
        // Apply reset values to widget
        widget?.useMacOSStyle = true
        widget?.showPercentage = true
        widget?.showTimeRemaining = true
        widget?.updateBatteryInfo()
    }
    
    private func loadCurrentPreferences() {
        guard let widget = widget else { return }
        
        iconStyleCheckbox.state = widget.useMacOSStyle ? .on : .off
        showPercentageCheckbox.state = widget.showPercentage ? .on : .off
        showTimeRemainingCheckbox.state = widget.showTimeRemaining ? .on : .off
    }
    
    @objc func iconStyleChanged(_ sender: NSButton) {
        widget?.useMacOSStyle = (sender.state == .on)
        widget?.updateBatteryInfo()
    }
    
    @objc func showPercentageChanged(_ sender: NSButton) {
        widget?.showPercentage = (sender.state == .on)
        widget?.updateBatteryInfo()
    }
    
    @objc func showTimeRemainingChanged(_ sender: NSButton) {
        widget?.showTimeRemaining = (sender.state == .on)
        widget?.updateBatteryInfo()
    }
} 