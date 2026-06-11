import Cocoa
import ApplicationServices

package final class Hotkeys {
    package static let shared = Hotkeys()

    private var tap: CFMachPort?

    private init() {}

    package func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.otherMouseDown.rawValue) |
                                (1 << CGEventType.otherMouseUp.rawValue) |
                                (1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Hotkeys.callback,
            userInfo: nil
        ) else {
            fputs("workspacer: failed to create event tap (check Input Monitoring permission)\n", stderr)
            exit(1)
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private static let callback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = Hotkeys.shared.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let config = Config.shared
        let targetButtonIndex = config.mouseGestureButton - 1
        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let hasClickBinding = config.mouseBindings.keys.contains(buttonNumber + 1)

        if type == .otherMouseDown {
            if (config.mouseGestureEnabled && buttonNumber == targetButtonIndex) || hasClickBinding {
                MouseGestureManager.shared.startDrag(at: event.location, button: buttonNumber + 1)
                return nil
            }
        } else if type == .otherMouseUp {
            if (config.mouseGestureEnabled && buttonNumber == targetButtonIndex) || hasClickBinding {
                MouseGestureManager.shared.endDrag(button: buttonNumber + 1)
                return nil
            }
        } else if type == .otherMouseDragged {
            if config.mouseGestureEnabled && buttonNumber == targetButtonIndex {
                MouseGestureManager.shared.dragged(to: event.location)
                return nil
            } else if hasClickBinding {
                return nil
            }
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == Key.r && flags.contains(.maskAlternate) && flags.contains(.maskControl) && flags.contains(.maskShift) {
            DispatchQueue.main.async { WorkspaceManager.shared.applyDefaultPlacement() }
            return nil
        }

        if config.modifier == .maskCommand && keyCode == Key.tab && flags.contains(.maskCommand) {
            return Unmanaged.passRetained(event)
        }

        let hasModifier = flags.contains(config.modifier)
        let hasShift = flags.contains(.maskShift)
        let hasExtraModifiers =
            (config.modifier != .maskCommand && flags.contains(.maskCommand)) ||
            (config.modifier != .maskControl && flags.contains(.maskControl)) ||
            (config.modifier != .maskAlternate && flags.contains(.maskAlternate))

        guard hasModifier, !hasExtraModifiers else {
            return Unmanaged.passRetained(event)
        }

        for binding in config.customBindings {
            guard binding.key == keyCode, binding.shift == hasShift else { continue }
            let cmd = binding.command
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", cmd]
                try? process.run()
            }
            return nil
        }

        if let number = config.numberKeys[keyCode] {
            let index = number - 1
            DispatchQueue.main.async {
                if hasShift {
                    WorkspaceManager.shared.moveActiveWindowTo(index)
                } else {
                    WorkspaceManager.shared.switchTo(index)
                }
            }
            return nil
        }

        let b = config.bindings

        if keyCode == b.focusMonitorPrev.key && hasShift == b.focusMonitorPrev.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.focusMonitor(offset: -1) }
            return nil
        }
        if keyCode == b.focusMonitorNext.key && hasShift == b.focusMonitorNext.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.focusMonitor(offset: 1) }
            return nil
        }
        if keyCode == b.moveMonitorPrev.key && hasShift == b.moveMonitorPrev.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.moveWindowToMonitor(offset: -1) }
            return nil
        }
        if keyCode == b.moveMonitorNext.key && hasShift == b.moveMonitorNext.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.moveWindowToMonitor(offset: 1) }
            return nil
        }
        if keyCode == b.lastWorkspace.key && hasShift == b.lastWorkspace.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.switchToLast() }
            return nil
        }
        if keyCode == b.prevWorkspace.key && hasShift == b.prevWorkspace.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.switchToPrev() }
            return nil
        }
        if keyCode == b.nextWorkspace.key && hasShift == b.nextWorkspace.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.switchToNext() }
            return nil
        }
        if keyCode == b.moveWorkspacePrev.key && hasShift == b.moveWorkspacePrev.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.moveActiveWindowToPrev() }
            return nil
        }
        if keyCode == b.moveWorkspaceNext.key && hasShift == b.moveWorkspaceNext.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.moveActiveWindowToNext() }
            return nil
        }
        if keyCode == b.refresh.key && hasShift == b.refresh.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.refresh() }
            return nil
        }
        if keyCode == b.focusNext.key && hasShift == b.focusNext.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.focusNext() }
            return nil
        }
        if keyCode == b.focusPrev.key && hasShift == b.focusPrev.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.focusPrev() }
            return nil
        }
        if keyCode == b.swapMaster.key && hasShift == b.swapMaster.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.swapMaster() }
            return nil
        }
        if keyCode == b.toggleLayout.key && hasShift == b.toggleLayout.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.toggleLayout() }
            return nil
        }
        if keyCode == b.toggleFloat.key && hasShift == b.toggleFloat.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.toggleActiveWindowFloating() }
            return nil
        }
        if keyCode == b.toggleAlwaysCenterFloating.key && hasShift == b.toggleAlwaysCenterFloating.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.toggleAlwaysCenterFloating() }
            return nil
        }
        if config.enableCopyPackageName && keyCode == Key.i && hasShift {
            DispatchQueue.main.async {
                if let focused = WindowManager.focusedWindow(),
                   let app = NSRunningApplication(processIdentifier: focused.pid),
                   let bundleId = app.bundleIdentifier {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(bundleId, forType: .string)
                    HUDManager.shared.show(text: "Copied Package Name", systemImage: "doc.on.doc.fill", type: .other)
                }
            }
            return nil
        }
        if keyCode == b.reloadConfig.key && hasShift == b.reloadConfig.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.reloadConfig() }
            return nil
        }
        if keyCode == b.toggleMenubar.key && hasShift == b.toggleMenubar.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.toggleMenuBarAutoHide() }
            return nil
        }
        if keyCode == b.toggleDynamicMenubar.key && hasShift == b.toggleDynamicMenubar.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.toggleDynamicMenuBar() }
            return nil
        }
        if keyCode == b.shrinkWindow.key && hasShift == b.shrinkWindow.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.adjustActiveWindowSize(direction: -0.05) }
            return nil
        }
        if keyCode == b.expandWindow.key && hasShift == b.expandWindow.shift {
            DispatchQueue.main.async { WorkspaceManager.shared.adjustActiveWindowSize(direction: 0.05) }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
