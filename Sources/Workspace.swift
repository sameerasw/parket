import Foundation
import AppKit
import ApplicationServices

package final class WorkspaceManager {
    package static let shared = WorkspaceManager()

    private struct WindowLocation {
        let monitorIndex: Int
        let workspaceIndex: Int
        let windowIndex: Int
    }

    private static let focusFollowRetryDelay: TimeInterval = 0.015
    private static let focusFollowMaxAttempts = 5

    private(set) var monitors: [Monitor] = []
    private(set) var focusedMonitorIndex: Int = 0
    private var screenChangeWork: DispatchWorkItem?
    private var focusFollowWork: DispatchWorkItem?

    var focusedMonitor: Monitor { monitors[focusedMonitorIndex] }

    private init() {}

    package func bootstrap() {
        rebuildMonitors()
        focusedMonitorIndex = 0
        let windows = WindowManager.allWindows()
        for window in windows {
            let monitor = monitorForWindow(window)
            if let bundleId = bundleIdentifier(for: window),
               let savedWorkspace = AppStateStore.shared.getWorkspace(for: bundleId) {
                monitor.insertWindow(window, to: savedWorkspace)
            } else {
                monitor.insertWindow(window)
            }
        }
        for monitor in monitors {
            monitor.retile()
        }
        syncApplicationVisibility()
        CornerMaskManager.shared.configure()
        MenuBarManager.shared.configure()
        StatusBar.shared.update()
    }

    func switchTo(_ index: Int) {
        for monitor in monitors {
            monitor.switchTo(index)
        }
        syncApplicationVisibility()
        StatusBar.shared.update()
    }

    func switchToLast() {
        let target = focusedMonitor.previousActive
        guard target != focusedMonitor.active else { return }
        switchTo(target)
    }

    func switchToPrev() {
        let current = focusedMonitor.active
        let count = Config.shared.workspaceCount
        let target = (current - 1 + count) % count
        switchTo(target)
    }

    func switchToNext() {
        let current = focusedMonitor.active
        let count = Config.shared.workspaceCount
        let target = (current + 1) % count
        switchTo(target)
    }

    func moveActiveWindowToPrev() {
        let current = focusedMonitor.active
        let count = Config.shared.workspaceCount
        let target = (current - 1 + count) % count
        moveActiveWindowTo(target)
    }

    func moveActiveWindowToNext() {
        let current = focusedMonitor.active
        let count = Config.shared.workspaceCount
        let target = (current + 1) % count
        moveActiveWindowTo(target)
    }

    func moveActiveWindowTo(_ index: Int) {
        guard let focused = WindowManager.focusedWindow() else { return }
        focusedMonitor.moveActiveWindowTo(index)
        if let bundleId = bundleIdentifier(for: focused) {
            AppStateStore.shared.saveWorkspace(index, for: bundleId)
        }
        syncApplicationVisibility()
        StatusBar.shared.update()
    }

    func refresh() {
        let windows = WindowManager.allWindows()
        for monitor in monitors {
            _ = monitor.removeWindows { window in
                !windows.contains(window)
            }
        }
        for window in windows {
            _ = addWindow(window)
        }
        for monitor in monitors {
            for (idx, ws) in monitor.workspaces.enumerated() {
                if idx != monitor.active {
                    let rect = WindowManager.screenRect(for: monitor.screen)
                    for win in ws {
                        win.hideOffscreen(rect)
                    }
                }
            }
            monitor.retile()
        }
        syncApplicationVisibility()
        StatusBar.shared.update()
    }

    @discardableResult
    func addWindow(_ window: TrackedWindow) -> WindowUpdate {
        for monitor in monitors {
            let result = monitor.updateExistingWindow(window)
            if result != .missing {
                return result
            }
        }
        let result: WindowUpdate
        if let bundleId = bundleIdentifier(for: window) {
            if let savedWorkspace = AppStateStore.shared.getWorkspace(for: bundleId) {
                result = focusedMonitor.addWindow(window, to: savedWorkspace)
            } else {
                AppStateStore.shared.saveWorkspace(focusedMonitor.active, for: bundleId)
                result = focusedMonitor.addWindow(window)
            }
        } else {
            result = focusedMonitor.addWindow(window)
        }
        if result == .inserted {
            syncApplicationVisibility()
            StatusBar.shared.update()
        }
        return result
    }

    func syncWindows(pid: pid_t, windows: [TrackedWindow]) {
        var changed = false
        for monitor in monitors {
            if monitor.removeStaleWindows(pid: pid, current: windows) {
                changed = true
            }
        }

        for window in windows {
            let result = addWindow(window)
            changed = changed || result == .inserted || result == .replaced
        }

        if changed {
            StatusBar.shared.update()
        }
    }

    func removeWindow(pid: pid_t) {
        removeWindows { $0.pid == pid }
    }

    func removeWindow(_ window: TrackedWindow) {
        removeWindows { $0.hasElement(window) }
    }

    private func removeWindows(where predicate: (TrackedWindow) -> Bool) {
        var changed = false
        for monitor in monitors {
            if monitor.removeWindows(where: predicate) {
                changed = true
            }
        }
        guard changed else { return }
        StatusBar.shared.update()
    }

    func focusNext() {
        focusedMonitor.focusNext()
    }

    func focusPrev() {
        focusedMonitor.focusPrev()
    }

    func swapMaster() {
        focusedMonitor.swapMaster()
    }

    func toggleLayout() {
        focusedMonitor.toggleLayout()
        StatusBar.shared.update()
    }

    func toggleActiveWindowFloating() {
        guard let focused = WindowManager.focusedWindow() else { return }
        let isFloating = focused.isFloating
        FloatingRegistry.shared.setFloating(!isFloating, for: focused)
        focusedMonitor.retile()
        if !isFloating {
            focused.focus()
            focused.raise()
        }
        StatusBar.shared.update()
    }

    func focusMonitor(offset: Int) {
        guard monitors.count > 1 else { return }
        focusedMonitor.saveFocusedIndex()
        focusedMonitorIndex = (focusedMonitorIndex + offset + monitors.count) % monitors.count
        let target = focusedMonitor
        target.restoreFocusedWindow()
        StatusBar.shared.update()
    }

    func moveWindowToMonitor(offset: Int) {
        guard monitors.count > 1 else { return }
        guard let focused = WindowManager.focusedWindow() else { return }

        let source = focusedMonitor
        guard let i = source.workspaces[source.active].firstIndex(of: focused) else { return }
        let moved = focused.keepingMembers(from: source.workspaces[source.active][i])
        source.workspaces[source.active].remove(at: i)
        source.retile()

        let targetIndex = (focusedMonitorIndex + offset + monitors.count) % monitors.count
        let target = monitors[targetIndex]
        target.insertWindow(moved)
        
        if moved.isFloating, let frame = moved.floatingFrame {
            let srcScreen = WindowManager.screenFrame(for: source.screen)
            let destScreen = WindowManager.screenFrame(for: target.screen)
            let dx = frame.origin.x - srcScreen.origin.x
            let dy = frame.origin.y - srcScreen.origin.y
            let newFrame = CGRect(
                x: destScreen.origin.x + dx,
                y: destScreen.origin.y + dy,
                width: frame.width,
                height: frame.height
            )
            moved.floatingFrame = newFrame
        }
        
        target.retile()

        focusedMonitorIndex = targetIndex
        moved.focus()
        StatusBar.shared.update()
    }

    func followExternalFocus(pid: pid_t) {
        if Thread.isMainThread {
            startExternalFocus(pid: pid)
        } else {
            DispatchQueue.main.async {
                self.startExternalFocus(pid: pid)
            }
        }
    }

    func handleWindowGeometryChange(pid: pid_t, element: AXUIElement) {
        if Thread.isMainThread {
            performWindowGeometryChange(pid: pid, element: element)
        } else {
            DispatchQueue.main.async {
                self.performWindowGeometryChange(pid: pid, element: element)
            }
        }
    }

    private func performWindowGeometryChange(pid: pid_t, element: AXUIElement) {
        guard let location = locateWindow(pid: pid, element: element) else { return }
        let monitor = monitors[location.monitorIndex]
        guard monitor.active == location.workspaceIndex else { return }
        monitor.scheduleCorrectiveRetile()
    }

    private func startExternalFocus(pid: pid_t) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
        focusFollowWork?.cancel()
        performExternalFocus(pid: pid, attempt: 0)
    }

    private func scheduleExternalFocus(pid: pid_t, attempt: Int) {
        focusFollowWork?.cancel()
        let work = DispatchWorkItem { [self] in
            performExternalFocus(pid: pid, attempt: attempt)
        }
        focusFollowWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusFollowRetryDelay, execute: work)
    }

    private func performExternalFocus(pid: pid_t, attempt: Int) {
        focusFollowWork = nil
        guard !monitors.isEmpty,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        else { return }

        if let focused = WindowManager.focusedWindow(pid: pid),
           let location = locateWindow(focused) {
            revealExternalFocus(focused, at: location)
            return
        }

        if let fallback = singleTrackedWindow(pid: pid) {
            revealExternalFocus(fallback.window, at: fallback.location)
            return
        }

        retryExternalFocus(pid: pid, attempt: attempt)
    }

    private func revealExternalFocus(_ window: TrackedWindow, at location: WindowLocation) {
        let monitor = monitors[location.monitorIndex]
        if monitor.active == location.workspaceIndex {
            focusedMonitorIndex = location.monitorIndex
            if monitor.workspaces[monitor.active].indices.contains(location.windowIndex) {
                monitor.focusedIndices[monitor.active] = location.windowIndex
            }
            monitor.rememberFocusedWindow(window)
            StatusBar.shared.update()
            return
        }

        focusedMonitorIndex = location.monitorIndex
        for m in monitors {
            if m === monitor {
                m.revealWorkspace(location.workspaceIndex, focusing: window)
            } else {
                m.switchTo(location.workspaceIndex)
            }
        }
        StatusBar.shared.update()
    }

    private func retryExternalFocus(pid: pid_t, attempt: Int) {
        guard attempt < Self.focusFollowMaxAttempts else { return }
        scheduleExternalFocus(pid: pid, attempt: attempt + 1)
    }

    package func handleScreenChange() {
        screenChangeWork?.cancel()
        let work = DispatchWorkItem { [self] in
            performScreenChange()
        }
        screenChangeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func performScreenChange() {
        screenChangeWork = nil
        let old = Dictionary(uniqueKeysWithValues: monitors.map { ($0.displayID, $0) })
        let oldPrimaryID = primaryDisplayID()
        let focusedDisplayID = monitors.isEmpty ? 0 : focusedMonitor.displayID
        rebuildMonitors()

        for monitor in monitors {
            if let existing = old[monitor.displayID] {
                monitor.copyState(from: existing)
            }
        }

        let currentIDs = Set(monitors.map { $0.displayID })
        for (id, oldMonitor) in old where !currentIDs.contains(id) {
            let target = monitors[0]
            for ws in oldMonitor.workspaces {
                for window in ws {
                    target.workspaces[target.active].insert(window, at: 0)
                }
            }
        }

        let newPrimaryID = primaryDisplayID()

        if newPrimaryID != oldPrimaryID,
           let newPrimary = monitors.first(where: { $0.displayID == newPrimaryID }),
           let oldPrimary = monitors.first(where: { $0.displayID == oldPrimaryID }),
           newPrimary.workspaces.allSatisfy({ $0.isEmpty }) {
            newPrimary.copyState(from: oldPrimary)
            oldPrimary.resetState()
        }
        
        let currentActive = monitors.first(where: { old[$0.displayID] != nil })?.active ?? 0
        for monitor in monitors {
            if old[monitor.displayID] == nil {
                monitor.active = currentActive
                monitor.previousActive = currentActive
            }
        }

        if newPrimaryID != oldPrimaryID {
            focusedMonitorIndex = monitors.firstIndex(where: { $0.displayID == newPrimaryID }) ?? 0
        } else {
            focusedMonitorIndex = monitors.firstIndex(where: { $0.displayID == focusedDisplayID }) ?? 0
        }

        for monitor in monitors {
            monitor.retile()
        }
        StatusBar.shared.update()
    }

    package func reloadConfig() {
        Config.load()
        let count = Config.shared.workspaceCount
        for monitor in monitors {
            monitor.resizeWorkspaces(to: count)
            monitor.retile()
        }
        CornerMaskManager.shared.configure()
        MenuBarManager.shared.configure()
        StatusBar.shared.update()
        fputs("parket: config reloaded\n", stderr)
    }

    package func restoreAllWindows() {
        for monitor in monitors {
            monitor.restoreAllWindows()
        }
    }

    private func rebuildMonitors() {
        monitors = NSScreen.screens
            .map { screen in
                Monitor(
                    displayID: WindowManager.displayID(for: screen),
                    screen: screen
                )
            }
            .sorted { $0.screen.frame.origin.x < $1.screen.frame.origin.x }
    }

    private func primaryDisplayID() -> CGDirectDisplayID {
        guard !monitors.isEmpty else { return 0 }
        return monitors.first(where: { $0.screen == NSScreen.main })?.displayID ?? monitors[0].displayID
    }

    private func locateWindow(_ window: TrackedWindow) -> WindowLocation? {
        for monitorIndex in monitors.indices {
            let monitor = monitors[monitorIndex]
            for workspaceIndex in monitor.workspaces.indices {
                if let windowIndex = monitor.workspaces[workspaceIndex].firstIndex(of: window) {
                    return WindowLocation(
                        monitorIndex: monitorIndex,
                        workspaceIndex: workspaceIndex,
                        windowIndex: windowIndex
                    )
                }
            }
        }
        return nil
    }

    private func locateWindow(pid: pid_t, element: AXUIElement) -> WindowLocation? {
        for monitorIndex in monitors.indices {
            let monitor = monitors[monitorIndex]
            for workspaceIndex in monitor.workspaces.indices {
                for windowIndex in monitor.workspaces[workspaceIndex].indices {
                    let window = monitor.workspaces[workspaceIndex][windowIndex]
                    guard window.pid == pid, window.containsElement(element) else { continue }
                    return WindowLocation(
                        monitorIndex: monitorIndex,
                        workspaceIndex: workspaceIndex,
                        windowIndex: windowIndex
                    )
                }
            }
        }
        return nil
    }

    private func singleTrackedWindow(pid: pid_t) -> (window: TrackedWindow, location: WindowLocation)? {
        var result: (window: TrackedWindow, location: WindowLocation)?

        for monitorIndex in monitors.indices {
            let monitor = monitors[monitorIndex]
            for workspaceIndex in monitor.workspaces.indices {
                for windowIndex in monitor.workspaces[workspaceIndex].indices {
                    let window = monitor.workspaces[workspaceIndex][windowIndex]
                    guard window.pid == pid, window.isTileable() else { continue }

                    guard result == nil else { return nil }
                    result = (
                        window,
                        WindowLocation(
                            monitorIndex: monitorIndex,
                            workspaceIndex: workspaceIndex,
                            windowIndex: windowIndex
                        )
                    )
                }
            }
        }

        return result
    }

    private func monitorForWindow(_ window: TrackedWindow) -> Monitor {
        guard monitors.count > 1, var frame = window.getFrame() else {
            return monitors[0]
        }
        
        if frame.origin.x < -10000 {
            frame.origin.x += 30000
        } else if frame.origin.x > 20000 {
            frame.origin.x -= 30000
        }
        if frame.origin.y < -10000 {
            frame.origin.y += 30000
        } else if frame.origin.y > 20000 {
            frame.origin.y -= 30000
        }
        
        let center = CGPoint(x: frame.midX, y: frame.midY)
        for monitor in monitors {
            let rect = WindowManager.screenRect(for: monitor.screen)
            if rect.contains(center) {
                return monitor
            }
        }
        
        var closestMonitor = monitors[0]
        var minDistance = CGFloat.greatestFiniteMagnitude
        for monitor in monitors {
            let rect = WindowManager.screenRect(for: monitor.screen)
            let monitorCenter = CGPoint(x: rect.midX, y: rect.midY)
            let dx = center.x - monitorCenter.x
            let dy = center.y - monitorCenter.y
            let dist = dx * dx + dy * dy
            if dist < minDistance {
                minDistance = dist
                closestMonitor = monitor
            }
        }
        return closestMonitor
    }

    private func syncApplicationVisibility() {
        let now = ProcessInfo.processInfo.systemUptime
        for monitor in monitors {
            monitor.ignoreGeometryUntil = now + 0.8
        }

        guard Config.shared.hideInactiveApps else {
            for app in NSWorkspace.shared.runningApplications {
                if app.activationPolicy == .regular {
                    app.unhide()
                }
            }
            return
        }

        var activePIDs = Set<pid_t>()
        for monitor in monitors {
            if monitor.active < monitor.workspaces.count {
                for win in monitor.workspaces[monitor.active] {
                    activePIDs.insert(win.pid)
                }
            }
        }

        var inactivePIDs = Set<pid_t>()
        for monitor in monitors {
            for (idx, ws) in monitor.workspaces.enumerated() {
                guard idx != monitor.active else { continue }
                for win in ws {
                    inactivePIDs.insert(win.pid)
                }
            }
        }

        for pid in inactivePIDs {
            if !activePIDs.contains(pid) {
                if let app = NSRunningApplication(processIdentifier: pid) {
                    app.hide()
                }
            }
        }

        for pid in activePIDs {
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.unhide()
            }
        }

        // Re-apply hideOffscreen for all windows in inactive workspaces that belong to unhidden apps
        for monitor in monitors {
            for (idx, ws) in monitor.workspaces.enumerated() {
                guard idx != monitor.active else { continue }
                let rect = WindowManager.screenRect(for: monitor.screen)
                for win in ws {
                    if activePIDs.contains(win.pid) {
                        win.hideOffscreen(rect)
                    }
                }
            }
        }
    }

    private func bundleIdentifier(for window: TrackedWindow) -> String? {
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            return app.bundleIdentifier
        }
        return nil
    }
}
