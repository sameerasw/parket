import Cocoa
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

final class FloatingRegistry {
    static let shared = FloatingRegistry()

    private var floatingKeys = Set<String>()
    private var floatingFrames = [String: CGRect]()
    private let defaultsKey = "parket.floatingWindows"

    private init() {
        loadPersisted()
    }

    private func windowKey(_ window: TrackedWindow) -> String {
        if let windowID = getWindowID(window.element) {
            return "id-\(windowID)"
        }
        return "group-\(window.group.pid)-\(window.group.frame.x)-\(window.group.frame.y)"
    }

    private func persistKey(for window: TrackedWindow) -> String? {
        guard let app = NSRunningApplication(processIdentifier: window.pid),
              let bundleId = app.bundleIdentifier
        else { return nil }
        let title = window.title() ?? ""
        return "\(bundleId)|\(title)"
    }

    func isFloating(_ window: TrackedWindow) -> Bool {
        if floatingKeys.contains(windowKey(window)) {
            return true
        }
        if let pKey = persistKey(for: window), floatingKeys.contains(pKey) {
            return true
        }
        return false
    }

    func setFloating(_ floating: Bool, for window: TrackedWindow) {
        let wKey = windowKey(window)
        let pKey = persistKey(for: window)

        if floating {
            floatingKeys.insert(wKey)
            if let pKey = pKey {
                floatingKeys.insert(pKey)
            }
            if floatingFrames[wKey] == nil, let frame = window.getFrame() {
                floatingFrames[wKey] = frame
            }
        } else {
            floatingKeys.remove(wKey)
            if let pKey = pKey {
                floatingKeys.remove(pKey)
            }
        }
        savePersisted()
    }

    func floatingFrame(_ window: TrackedWindow) -> CGRect? {
        return floatingFrames[windowKey(window)]
    }

    func setFloatingFrame(_ frame: CGRect?, for window: TrackedWindow) {
        floatingFrames[windowKey(window)] = frame
    }

    private func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let status = _AXUIElementGetWindow(element, &windowID)
        return status == .success ? windowID : nil
    }

    private func loadPersisted() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        for key in saved {
            floatingKeys.insert(key)
        }
    }

    private func savePersisted() {
        let keysToSave = floatingKeys.filter { $0.contains("|") }
        UserDefaults.standard.set(Array(keysToSave), forKey: defaultsKey)
    }
}
