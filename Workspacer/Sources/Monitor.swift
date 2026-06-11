import AppKit

enum WindowUpdate {
    case missing
    case inserted
    case replaced
    case unchanged
}

package final class Monitor {
    private static let geometryDebounceDelay: TimeInterval = 0.08
    private static let geometrySuppressionDelay: TimeInterval = 0.60
    private static let frameTolerance: CGFloat = 2.0

    let displayID: CGDirectDisplayID
    var screen: NSScreen
    var workspaces: [[TrackedWindow]] = Array(repeating: [], count: Config.shared.workspaceCount)
    var layouts: [Layout] = Array(repeating: .tile, count: Config.shared.workspaceCount)
    var focusedIndices: [Int] = Array(repeating: 0, count: Config.shared.workspaceCount)
    var masterRatios: [CGFloat] = Array(repeating: Config.shared.masterRatio, count: Config.shared.workspaceCount)
    var stackRatios: [[CGFloat]] = Array(repeating: [], count: Config.shared.workspaceCount)
    var active: Int = 0
    var previousActive: Int = 0
    private var retileScheduled = false
    private var geometryRetileWork: DispatchWorkItem?
    package var ignoreGeometryUntil: TimeInterval = 0

    init(displayID: CGDirectDisplayID, screen: NSScreen) {
        self.displayID = displayID
        self.screen = screen
    }

    func switchTo(_ index: Int) {
        guard index >= 0, index < Config.shared.workspaceCount, index != active else { return }

        let previous = active
        previousActive = previous
        saveFocusedIndex()
        active = index

        let screen = WindowManager.screenRect(for: self.screen)
        for win in workspaces[previous] {
            if win.isFloating, let frame = win.getFrame(), frame.width > 1, frame.height > 1 {
                win.floatingFrame = frame
            }
            win.hideOffscreen(screen)
        }

        if Config.shared.alwaysCenterFloating {
            for win in workspaces[active] where win.isFloating {
                centerFloatingWindow(win, on: self.screen)
            }
        }

        retile()
        restoreFocusedWindow()
    }

    func revealWorkspace(_ index: Int, focusing focused: TrackedWindow) {
        guard index >= 0, index < Config.shared.workspaceCount else { return }

        if index != active {
            let previous = active
            previousActive = previous
            saveFocusedIndex()
            active = index

            let screen = WindowManager.screenRect(for: self.screen)
            for win in workspaces[previous] {
                if win.isFloating, let frame = win.getFrame(), frame.width > 1, frame.height > 1 {
                    win.floatingFrame = frame
                }
                win.hideOffscreen(screen)
            }

            if Config.shared.alwaysCenterFloating {
                for win in workspaces[active] where win.isFloating {
                    centerFloatingWindow(win, on: self.screen)
                }
            }
        }

        guard rememberFocusedWindow(focused) else { return }
        retile()
        guard rememberFocusedWindow(focused) else { return }

        let target = workspaces[active][focusedIndices[active]]
        target.focus()
        if layouts[active] == .monocle {
            target.raise()
        }
    }

    func moveActiveWindowTo(_ index: Int) {
        guard index >= 0, index < Config.shared.workspaceCount, index != active else { return }
        guard let focused = WindowManager.focusedWindow() else { return }

        guard let i = workspaces[active].firstIndex(of: focused) else { return }
        let moved = focused.keepingMembers(from: workspaces[active][i])
        workspaces[active].remove(at: i)
        workspaces[index].insert(moved, at: 0)

        retile()
        moved.hideOffscreen(WindowManager.screenRect(for: self.screen))

        if let next = workspaces[active].first {
            next.focus()
        }
    }

    @discardableResult
    func insertWindow(_ window: TrackedWindow) -> Bool {
        guard updateExistingWindow(window) == .missing else { return false }
        workspaces[active].insert(window, at: 0)
        return true
    }

    @discardableResult
    func insertWindow(_ window: TrackedWindow, to workspaceIndex: Int) -> Bool {
        guard updateExistingWindow(window) == .missing else { return false }
        guard workspaceIndex >= 0, workspaceIndex < Config.shared.workspaceCount else {
            return insertWindow(window)
        }
        workspaces[workspaceIndex].insert(window, at: 0)
        if workspaceIndex != active {
            window.hideOffscreen(WindowManager.screenRect(for: self.screen))
        }
        return true
    }

    @discardableResult
    func addWindow(_ window: TrackedWindow) -> WindowUpdate {
        let existing = updateExistingWindow(window)
        if existing == .replaced && workspaces[active].contains(window) {
            scheduleRetile()
        }
        guard existing == .missing else { return existing }
        workspaces[active].insert(window, at: 0)
        if window.isFloating {
            centerFloatingWindow(window, on: self.screen)
        }
        scheduleRetile()
        return .inserted
    }

    @discardableResult
    func addWindow(_ window: TrackedWindow, to workspaceIndex: Int) -> WindowUpdate {
        let existing = updateExistingWindow(window)
        if existing == .replaced && workspaces[active].contains(window) {
            scheduleRetile()
        }
        guard existing == .missing else { return existing }
        guard workspaceIndex >= 0, workspaceIndex < Config.shared.workspaceCount else {
            return addWindow(window)
        }
        workspaces[workspaceIndex].insert(window, at: 0)
        if window.isFloating {
            centerFloatingWindow(window, on: self.screen)
        }
        if workspaceIndex == active {
            scheduleRetile()
        } else {
            window.hideOffscreen(WindowManager.screenRect(for: self.screen))
        }
        return .inserted
    }

    func updateExistingWindow(_ window: TrackedWindow) -> WindowUpdate {
        for ws in 0..<workspaces.count {
            guard let i = workspaces[ws].firstIndex(of: window) else { continue }
            let current = workspaces[ws][i]
            if current.hasElement(window) {
                if current.group != window.group || !current.hasSameMembers(window) {
                    workspaces[ws][i] = window
                    return .replaced
                }
                return .unchanged
            }
            if current.isTileable() {
                if current.group == window.group && !current.hasSameMembers(window) {
                    workspaces[ws][i] = window
                    return .replaced
                }
                return .unchanged
            }
            workspaces[ws][i] = window
            return .replaced
        }
        return .missing
    }

    func removeWindows(where predicate: (TrackedWindow) -> Bool) -> Bool {
        var needsRetile = false
        var changed = false
        for i in 0..<Config.shared.workspaceCount {
            let before = workspaces[i].count
            workspaces[i].removeAll(where: predicate)
            if workspaces[i].count != before {
                changed = true
                needsRetile = needsRetile || (i == active)
            }
        }
        if changed && needsRetile { scheduleRetile() }
        return changed
    }

    func removeStaleWindows(pid: pid_t, current: [TrackedWindow]) -> Bool {
        removeWindows { window in
            window.pid == pid && !current.contains(window)
        }
    }

    func containsWindow(_ window: TrackedWindow) -> Bool {
        workspaces.contains { $0.contains(window) }
    }

    func focusNext() { focusOffset(1) }
    func focusPrev() { focusOffset(-1) }

    private func focusOffset(_ offset: Int) {
        let windows = workspaces[active]
        guard windows.count > 1,
              let focused = WindowManager.focusedWindow(),
              let i = windows.firstIndex(of: focused)
        else { return }
        let targetIndex = (i + offset + windows.count) % windows.count
        let target = windows[targetIndex]
        target.focus()
        focusedIndices[active] = targetIndex
        if layouts[active] == .monocle {
            target.raise()
        }
    }

    func swapMaster() {
        guard workspaces[active].count > 1 else { return }
        guard let focused = WindowManager.focusedWindow(),
              let i = workspaces[active].firstIndex(of: focused),
              i != 0
        else { return }
        workspaces[active].swapAt(0, i)
        retile()
        workspaces[active][0].focus()
    }

    func adjustActiveWindowSize(direction: CGFloat) {
        if let focused = WindowManager.focusedWindow(), focused.isFloating {
            let screenFrame = WindowManager.screenFrame(for: self.screen)
            let dw = screenFrame.width * direction
            let dh = screenFrame.height * direction
            
            guard let frame = focused.getFrame() else { return }
            let newWidth = max(frame.width + dw, 100)
            let newHeight = max(frame.height + dh, 100)
            
            let cx = frame.origin.x + frame.width / 2
            let cy = frame.origin.y + frame.height / 2
            let newOrigin = CGPoint(x: cx - newWidth / 2, y: cy - newHeight / 2)
            
            let newFrame = CGRect(origin: newOrigin, size: CGSize(width: newWidth, height: newHeight))
            focused.setFrame(newFrame)
            focused.floatingFrame = newFrame
            return
        }

        guard layouts[active] == .tile else { return }
        let windows = workspaces[active]
        guard windows.count > 1 else { return }
        
        guard let focused = WindowManager.focusedWindow(),
              let focusedIndex = windows.firstIndex(of: focused)
        else { return }
        
        if focusedIndex == 0 {
            let current = masterRatios[active]
            let newRatio = min(max(current + direction, 0.1), 0.9)
            masterRatios[active] = newRatio
            retile()
        } else {
            let stackIndex = focusedIndex - 1
            let count = windows.count - 1
            
            if stackRatios[active].count != count {
                stackRatios[active] = Array(repeating: 1.0 / CGFloat(count), count: count)
            }
            
            var ratios = stackRatios[active]
            let currentRatio = ratios[stackIndex]
            
            let newRatio = min(max(currentRatio + direction, 0.05), 0.95)
            let diff = newRatio - currentRatio
            
            let otherCount = count - 1
            if otherCount > 0 {
                let adjustAmount = diff / CGFloat(otherCount)
                for i in 0..<count {
                    if i == stackIndex {
                        ratios[i] = newRatio
                    } else {
                        ratios[i] = min(max(ratios[i] - adjustAmount, 0.05), 0.95)
                    }
                }
                
                let sum = ratios.reduce(0, +)
                if sum > 0 {
                    ratios = ratios.map { $0 / sum }
                }
                
                stackRatios[active] = ratios
                retile()
            }
        }
    }

    func toggleLayout() {
        layouts[active] = layouts[active] == .tile ? .monocle : .tile
        retile()
        if layouts[active] == .monocle, let focused = WindowManager.focusedWindow(),
           workspaces[active].contains(focused) {
            focused.raise()
        }
    }

    private func scheduleRetile() {
        guard !retileScheduled else { return }
        retileScheduled = true
        DispatchQueue.main.async { [self] in
            retileScheduled = false
            retile()
        }
    }

    func scheduleCorrectiveRetile() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= ignoreGeometryUntil else { return }

        geometryRetileWork?.cancel()
        let scheduledActive = active
        let work = DispatchWorkItem { [self] in
            geometryRetileWork = nil
            guard active == scheduledActive else { return }
            guard ProcessInfo.processInfo.systemUptime >= ignoreGeometryUntil else { return }
            guard !activeWorkspaceMatchesLayout(tolerance: Self.frameTolerance) else { return }
            if layouts[active] == .tile && NSEvent.pressedMouseButtons != 0 {
                updateRatiosFromActualFrames()
            }
            retile()
        }
        geometryRetileWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.geometryDebounceDelay, execute: work)
    }

    @discardableResult
    func retile() -> CGRect {
        cleanActiveWorkspace()
        let screen = WindowManager.screenFrame(for: self.screen)
        ignoreGeometryUntil = ProcessInfo.processInfo.systemUptime + Self.geometrySuppressionDelay
        
        let tiledWindows = workspaces[active].filter { !$0.isFloating }
        Tiler.tile(
            windows: tiledWindows,
            screen: screen,
            layout: layouts[active],
            masterRatio: masterRatios[active],
            stackRatios: stackRatios[active]
        )
        
        for window in workspaces[active] where window.isFloating {
            if let frame = window.floatingFrame {
                window.setFrame(frame)
            }
        }
        
        return screen
    }

    private func cleanActiveWorkspace() {
        var windows: [TrackedWindow] = []
        for window in workspaces[active] {
            if let app = NSRunningApplication(processIdentifier: window.pid), app.isHidden {
                windows.append(window)
                continue
            }
            guard window.isTileable(), !windows.contains(window) else { continue }
            windows.append(window)
        }
        workspaces[active] = windows
    }

    private func updateRatiosFromActualFrames() {
        let windows = workspaces[active].filter { !$0.isFloating }
        guard windows.count > 1 else { return }
        let screen = WindowManager.screenFrame(for: self.screen)
        guard screen.width > 0, screen.height > 0 else { return }

        let padding = Config.shared.padding
        let gap = Config.shared.gap

        let insetScreenWidth = max(screen.width - 2 * padding, 0)
        let insetScreenHeight = max(screen.height - 2 * padding, 0)

        if let masterFrame = windows[0].getFrame() {
            let actualMasterWidth = masterFrame.width
            let availableWidth = max(insetScreenWidth - gap, 0)
            if availableWidth > 0 {
                let proposedMasterRatio = actualMasterWidth / availableWidth
                let clampedMasterRatio = min(max(proposedMasterRatio, 0.1), 0.9)
                masterRatios[active] = clampedMasterRatio
            }
        }

        let stackCount = windows.count - 1
        let totalVerticalGaps = CGFloat(stackCount - 1) * gap
        let availableHeight = max(insetScreenHeight - totalVerticalGaps, 0)

        var newStackRatios: [CGFloat] = []
        for i in 1..<windows.count {
            if let frame = windows[i].getFrame(), availableHeight > 0 {
                newStackRatios.append(frame.height / availableHeight)
            } else {
                newStackRatios.append(1.0 / CGFloat(stackCount))
            }
        }
        stackRatios[active] = newStackRatios
    }

    private func activeWorkspaceMatchesLayout(tolerance: CGFloat) -> Bool {
        let windows = workspaces[active].filter { !$0.isFloating }
        let screen = WindowManager.screenFrame(for: self.screen)
        let frames = Tiler.calculateFrames(
            count: windows.count,
            screen: screen,
            layout: layouts[active],
            masterRatio: masterRatios[active],
            stackRatios: stackRatios[active]
        )
        guard frames.count == windows.count else { return false }

        for i in windows.indices {
            guard windows[i].isTileable(), let frame = windows[i].getFrame() else { return false }
            guard framesMatch(frame, frames[i], tolerance: tolerance) else { return false }
        }

        return true
    }

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    package func resizeWorkspaces(to count: Int) {
        let old = workspaces.count
        guard count != old else { return }

        if count > old {
            workspaces.append(contentsOf: Array(repeating: [], count: count - old))
            layouts.append(contentsOf: Array(repeating: .tile, count: count - old))
            focusedIndices.append(contentsOf: Array(repeating: 0, count: count - old))
            masterRatios.append(contentsOf: Array(repeating: Config.shared.masterRatio, count: count - old))
            stackRatios.append(contentsOf: Array(repeating: [], count: count - old))
        } else {
            let overflow = workspaces[count..<old].joined()
            workspaces.removeSubrange(count...)
            layouts.removeSubrange(count...)
            focusedIndices.removeSubrange(count...)
            masterRatios.removeSubrange(count...)
            stackRatios.removeSubrange(count...)
            if active >= count {
                active = count - 1
            }
            if previousActive >= count {
                previousActive = active
            }
            workspaces[active].append(contentsOf: overflow)
        }
    }

    func saveFocusedIndex() {
        guard let focused = WindowManager.focusedWindow(),
              rememberFocusedWindow(focused)
        else { return }
    }

    @discardableResult
    func rememberFocusedWindow(_ focused: TrackedWindow) -> Bool {
        guard let i = workspaces[active].firstIndex(of: focused) else { return false }
        workspaces[active][i] = focused.keepingMembers(from: workspaces[active][i])
        focusedIndices[active] = i
        return true
    }

    func copyState(from source: Monitor) {
        workspaces = source.workspaces
        layouts = source.layouts
        focusedIndices = source.focusedIndices
        masterRatios = source.masterRatios
        stackRatios = source.stackRatios
        active = source.active
        previousActive = source.previousActive
    }

    func resetState() {
        geometryRetileWork?.cancel()
        geometryRetileWork = nil
        ignoreGeometryUntil = 0
        let count = Config.shared.workspaceCount
        workspaces = Array(repeating: [], count: count)
        layouts = Array(repeating: .tile, count: count)
        focusedIndices = Array(repeating: 0, count: count)
        masterRatios = Array(repeating: Config.shared.masterRatio, count: count)
        stackRatios = Array(repeating: [], count: count)
        active = 0
        previousActive = 0
    }

    func restoreFocusedWindow() {
        let windows = workspaces[active]
        guard !windows.isEmpty else { return }
        let idx = min(focusedIndices[active], windows.count - 1)
        let target = windows[idx]
        target.focus()
        if layouts[active] == .monocle {
            target.raise()
        }
    }

    func restoreAllWindows() {
        let screen = WindowManager.screenFrame(for: self.screen)
        let center = CGPoint(
            x: screen.origin.x + screen.width / 4,
            y: screen.origin.y + screen.height / 4
        )
        let size = CGSize(width: screen.width / 2, height: screen.height / 2)

        for ws in workspaces {
            for win in ws {
                win.setFrame(CGRect(origin: center, size: size))
            }
        }
    }

    func moveWindow(_ window: TrackedWindow, from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < workspaces.count else { return }
        guard targetIndex >= 0, targetIndex < workspaces.count else { return }
        guard let i = workspaces[sourceIndex].firstIndex(of: window) else { return }
        let moved = window.keepingMembers(from: workspaces[sourceIndex][i])
        workspaces[sourceIndex].remove(at: i)
        workspaces[targetIndex].insert(moved, at: 0)
    }

    private func centerFloatingWindow(_ window: TrackedWindow, on screen: NSScreen) {
        let screenFrame = WindowManager.screenFrame(for: screen)
        var size = CGSize(width: screenFrame.width * 0.7, height: screenFrame.height * 0.7)
        if let savedFrame = window.floatingFrame {
            if savedFrame.width > 10 && savedFrame.height > 10 {
                size = savedFrame.size
            }
        }
        let center = CGPoint(
            x: screenFrame.origin.x + (screenFrame.width - size.width) / 2,
            y: screenFrame.origin.y + (screenFrame.height - size.height) / 2
        )
        let centeredFrame = CGRect(origin: center, size: size)
        window.setFrame(centeredFrame)
        window.floatingFrame = centeredFrame
    }
}
