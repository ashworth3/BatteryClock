import Cocoa
import PockKit

extension Notification.Name {
    static let didChangeWidgetLayout = Notification.Name("com.andreashworth.batteryclock.didChangeWidgetLayout")
}

@objc(BatteryClockPreferencesPane)
class BatteryClockPreferencesPane: NSViewController, PKWidgetPreference {
    static var nibName: NSNib.Name = "BatteryClockPreferencesPane"
    
    // UI Elements
    @IBOutlet private weak var styleSegmentedControl: NSSegmentedControl!
    @IBOutlet private weak var showPercentageButton: NSButton!
    @IBOutlet private weak var showTimeRemainingButton: NSButton!
    @IBOutlet private weak var colorThemePopUpButton: NSPopUpButton!
    
    // Reference to widget
    weak var widget: BatteryClockWidget?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateControlStates()
    }
    
    private func setupUI() {
        // Setup style segmented control
        styleSegmentedControl.segmentCount = 2
        styleSegmentedControl.setLabel("macOS Style", forSegment: 0)
        styleSegmentedControl.setLabel("Emoji Style", forSegment: 1)
        styleSegmentedControl.selectedSegment = widget?.useMacOSStyle == true ? 0 : 1
        
        // Setup checkboxes
        showPercentageButton.state = widget?.showPercentage == true ? .on : .off
        showTimeRemainingButton.state = widget?.showTimeRemaining == true ? .on : .off
        
        // Setup color theme popup
        colorThemePopUpButton.removeAllItems()
        colorThemePopUpButton.addItems(withTitles: ["Default", "Monochrome", "Colorful", "Minimal"])
        colorThemePopUpButton.selectItem(at: 0)
    }
    
    private func updateControlStates() {
        styleSegmentedControl.selectedSegment = widget?.useMacOSStyle == true ? 0 : 1
        showPercentageButton.state = widget?.showPercentage == true ? .on : .off
        showTimeRemainingButton.state = widget?.showTimeRemaining == true ? .on : .off
    }
    
    @IBAction private func didChangePreferences(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        
        switch control {
        case styleSegmentedControl:
            widget?.useMacOSStyle = styleSegmentedControl.selectedSegment == 0
            
        case showPercentageButton:
            widget?.showPercentage = showPercentageButton.state == .on
            
        case showTimeRemainingButton:
            widget?.showTimeRemaining = showTimeRemainingButton.state == .on
            
        case colorThemePopUpButton:
            // TODO: Implement color themes
            break
            
        default:
            return
        }
        
        // Update widget
        widget?.updateBatteryInfo()
        
        // Notify about layout changes
        NotificationCenter.default.post(name: .didChangeWidgetLayout, object: nil)
    }
    
    func reset() {
        // Reset to default values
        widget?.useMacOSStyle = true
        widget?.showPercentage = true
        widget?.showTimeRemaining = true
        
        // Update UI
        updateControlStates()
        
        // Update widget
        widget?.updateBatteryInfo()
        
        // Notify about changes
        NotificationCenter.default.post(name: .didChangeWidgetLayout, object: nil)
    }
} 