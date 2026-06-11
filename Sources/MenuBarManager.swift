import Foundation
import AppKit

package final class MenuBarManager {
    package static let shared = MenuBarManager()

    private var isEnabled: Bool = false
    private var isAutoHideActive: Bool = false

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(evaluateState),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    package func configure() {
        let config = Config.shared
        self.isEnabled = config.enableDynamicMenubar
        
        if isEnabled {
            evaluateState()
        } else {
            setMenuBarAutoHide(enabled: false)
        }
    }

    package func toggleMenuBarAutoHide() {
        let scriptSource = """
        if application "System Events" is not running then
            launch application "System Events"
        end if
        tell application "System Events"
            set autohide menu bar of dock preferences to not (autohide menu bar of dock preferences)
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                let osascript = "tell application \"System Events\" to set autohide menu bar of dock preferences to not (autohide menu bar of dock preferences)"
                let fallbackProc = Process()
                fallbackProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                fallbackProc.arguments = ["-e", osascript]
                try? fallbackProc.run()
            }
        }
    }

    package func toggleDynamicMenubar() -> Bool {
        isEnabled.toggle()
        Config.shared.enableDynamicMenubar = isEnabled
        if isEnabled {
            evaluateState()
        } else {
            setMenuBarAutoHide(enabled: false)
        }
        return isEnabled
    }

    @objc private func evaluateState() {
        guard isEnabled else { return }

        let screens = NSScreen.screens
        let hasInternalDisplay = screens.contains { screen in
            let name = screen.localizedName.lowercased()
            return name.contains("built-in") || name.contains("retina")
        }

        if !hasInternalDisplay {
            fputs("parket: Clamshell mode detected: Forcing Auto-Hide\n", stderr)
            setMenuBarAutoHide(enabled: true)
        } else {
            fputs("parket: Internal display detected: Disabling Auto-Hide\n", stderr)
            setMenuBarAutoHide(enabled: false)
        }
    }

    private func setMenuBarAutoHide(enabled: Bool) {
        let fullscreenVal = enabled ? 0 : 1
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "NSGlobalDomain", "AppleMenuBarVisibleInFullscreen", "-int", "\(fullscreenVal)"]
        try? process.run()

        let scriptSource = """
        if application "System Events" is not running then
            launch application "System Events"
        end if
        tell application "System Events"
            set autohide menu bar of dock preferences to \(enabled)
        end tell
        """
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                let osascript = "tell application \"System Events\" to set autohide menu bar of dock preferences to \(enabled)"
                let fallbackProc = Process()
                fallbackProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                fallbackProc.arguments = ["-e", osascript]
                try? fallbackProc.run()
            }
        }
    }
}
