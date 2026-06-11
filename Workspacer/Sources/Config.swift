import Cocoa

package enum WorkspacePriority: String {
    case none
    case last
    case config
}

package enum InactiveWindowPosition: String {
    case left
    case right
    case top
    case bottom
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
}

package struct Binding {
    let key: UInt16
    let shift: Bool
    let command: String

    init(key: UInt16, shift: Bool = false, command: String) {
        self.key = key
        self.shift = shift
        self.command = command
    }
}

package enum Key {
    static let `return`: UInt16 = 36
    static let tab: UInt16 = 48
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51

    static let a: UInt16 = 0
    static let b: UInt16 = 11
    static let c: UInt16 = 8
    static let d: UInt16 = 2
    static let e: UInt16 = 14
    static let f: UInt16 = 3
    static let g: UInt16 = 5
    static let h: UInt16 = 4
    static let i: UInt16 = 34
    static let j: UInt16 = 38
    static let k: UInt16 = 40
    static let l: UInt16 = 37
    static let m: UInt16 = 46
    static let n: UInt16 = 45
    static let o: UInt16 = 31
    static let p: UInt16 = 35
    static let q: UInt16 = 12
    static let r: UInt16 = 15
    static let s: UInt16 = 1
    static let t: UInt16 = 17
    static let u: UInt16 = 32
    static let v: UInt16 = 9
    static let w: UInt16 = 13
    static let x: UInt16 = 7
    static let y: UInt16 = 16
    static let z: UInt16 = 6

    static let zero: UInt16 = 29
    static let one: UInt16 = 18
    static let two: UInt16 = 19
    static let three: UInt16 = 20
    static let four: UInt16 = 21
    static let five: UInt16 = 23
    static let six: UInt16 = 22
    static let seven: UInt16 = 26
    static let eight: UInt16 = 28
    static let nine: UInt16 = 25

    static let minus: UInt16 = 27
    static let equal: UInt16 = 24
    static let leftBracket: UInt16 = 33
    static let rightBracket: UInt16 = 30
    static let semicolon: UInt16 = 41
    static let quote: UInt16 = 39
    static let comma: UInt16 = 43
    static let period: UInt16 = 47
    static let slash: UInt16 = 44
    static let backslash: UInt16 = 42
    static let grave: UInt16 = 50

    static let byName: [String: UInt16] = [
        "return": Key.return, "tab": Key.tab, "space": Key.space,
        "escape": Key.escape, "delete": Key.delete,
        "a": Key.a, "b": Key.b, "c": Key.c, "d": Key.d, "e": Key.e,
        "f": Key.f, "g": Key.g, "h": Key.h, "i": Key.i, "j": Key.j,
        "k": Key.k, "l": Key.l, "m": Key.m, "n": Key.n, "o": Key.o,
        "p": Key.p, "q": Key.q, "r": Key.r, "s": Key.s, "t": Key.t,
        "u": Key.u, "v": Key.v, "w": Key.w, "x": Key.x, "y": Key.y,
        "z": Key.z,
        "0": Key.zero, "1": Key.one, "2": Key.two, "3": Key.three,
        "4": Key.four, "5": Key.five, "6": Key.six, "7": Key.seven,
        "8": Key.eight, "9": Key.nine,
        "minus": Key.minus, "equal": Key.equal,
        "leftbracket": Key.leftBracket, "rightbracket": Key.rightBracket,
        "semicolon": Key.semicolon, "quote": Key.quote,
        "comma": Key.comma, "period": Key.period,
        "slash": Key.slash, "backslash": Key.backslash, "grave": Key.grave,
    ]

    static let numberKeys: [UInt16] = [
        Key.one, Key.two, Key.three, Key.four, Key.five,
        Key.six, Key.seven, Key.eight, Key.nine,
    ]
}

package struct BuiltinBindings {
    var focusNext: (key: UInt16, shift: Bool) = (Key.j, false)
    var focusPrev: (key: UInt16, shift: Bool) = (Key.k, false)
    var swapMaster: (key: UInt16, shift: Bool) = (Key.return, false)
    var toggleLayout: (key: UInt16, shift: Bool) = (Key.m, false)
    var focusMonitorPrev: (key: UInt16, shift: Bool) = (Key.comma, false)
    var focusMonitorNext: (key: UInt16, shift: Bool) = (Key.period, false)
    var moveMonitorPrev: (key: UInt16, shift: Bool) = (Key.comma, true)
    var moveMonitorNext: (key: UInt16, shift: Bool) = (Key.period, true)
    var lastWorkspace: (key: UInt16, shift: Bool) = (Key.tab, false)
    var prevWorkspace: (key: UInt16, shift: Bool) = (Key.q, false)
    var nextWorkspace: (key: UInt16, shift: Bool) = (Key.e, false)
    var moveWorkspacePrev: (key: UInt16, shift: Bool) = (Key.q, true)
    var moveWorkspaceNext: (key: UInt16, shift: Bool) = (Key.e, true)
    var refresh: (key: UInt16, shift: Bool) = (Key.r, false)
    var toggleFloat: (key: UInt16, shift: Bool) = (Key.p, false)
    var reloadConfig: (key: UInt16, shift: Bool) = (Key.r, true)
    var toggleMenubar: (key: UInt16, shift: Bool) = (Key.m, false)
    var toggleDynamicMenubar: (key: UInt16, shift: Bool) = (Key.m, true)
    var shrinkWindow: (key: UInt16, shift: Bool) = (Key.minus, false)
    var expandWindow: (key: UInt16, shift: Bool) = (Key.equal, false)
    var toggleAlwaysCenterFloating: (key: UInt16, shift: Bool) = (Key.o, false)
}

package struct Config {
    package static var shared = Config()

    package var workspaceCount: Int = 9
    package var masterRatio: CGFloat = 0.50
    package var padding: CGFloat = 0
    package var gap: CGFloat = 0
    package var hideInactiveApps: Bool = false
    package var resizeOnHide: Bool = true
    package var noPaddingForSingleWindow: Bool = false
    package var workspaceLoopEnabled: Bool = false
    package var inactiveWindowPosition: InactiveWindowPosition = .left
    package var enableCorners: Bool = false
    package var cornerRadius: CGFloat = 0
    package var enableDynamicMenubar: Bool = false
    package var hudEnabled: Bool = true
    package var hudPosition: String = "top"
    package var hudYOffset: CGFloat = 50.0
    package var hudDuration: Double = 1.5
    package var hudOnWorkspaceSwitch: Bool = true
    package var hudOnLayoutSwitch: Bool = true
    package var hudOnConfigReload: Bool = true
    package var workspaceNames: [String] = []
    package var modifier: CGEventFlags = .maskAlternate
    package var customBindings: [Binding] = [
        Binding(key: Key.return, shift: true, command: "open -n -a Terminal"),
    ]
    package var bindings = BuiltinBindings()

    package var alwaysCenterFloating: Bool = false
    package var workspacePriority: WorkspacePriority = .last

    package var enableCopyPackageName: Bool = false
    package var floatingApps: Set<String> = []
    package var workspaceRules: [String: Int] = [:]

    package var mouseGestureEnabled: Bool = false
    package var mouseGestureButton: Int = 5
    package var mouseGestureSensitivity: Double = 1.0
    package var mouseBindings: [Int: String] = [
        4: "back",
        5: "forward"
    ]

    package var trackpadSwipeEnabled: Bool = false
    package var trackpadSwipeFingers: Int = 3
    package var trackpadSwipeHaptic: String = "non"
    package var trackpadSwipeSensitivity: Double = 1.0
    package var trackpadSwipeMultiple: Bool = false
    package var trackpadSwipeRumble: Bool = false

    package private(set) var numberKeys: [UInt16: Int] = buildNumberKeys(count: 9)

    package func workspaceName(for index: Int) -> String {
        if index >= 0 && index < workspaceNames.count {
            return workspaceNames[index]
        }
        return "\(index + 1)"
    }

    private static func buildNumberKeys(count: Int) -> [UInt16: Int] {
        var map: [UInt16: Int] = [:]
        for i in 0..<count { map[Key.numberKeys[i]] = i + 1 }
        return map
    }

    package static func load() {
        let path = NSString("~/.config/workspacer/config.toml").expandingTildeInPath
        let legacyPath = NSString("~/.config/parket/config.toml").expandingTildeInPath
        
        var configPath = path
        if !FileManager.default.fileExists(atPath: path) && FileManager.default.fileExists(atPath: legacyPath) {
            do {
                let dir = (path as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.copyItem(atPath: legacyPath, toPath: path)
                configPath = path
            } catch {
                fputs("workspacer: failed to migrate config file: \(error)\n", stderr)
            }
        }
        
        guard FileManager.default.fileExists(atPath: configPath) else { return }

        guard let data = FileManager.default.contents(atPath: configPath),
              let text = String(data: data, encoding: .utf8)
        else {
            fputs("workspacer: failed to read config file\n", stderr)
            return
        }

        let toml: [String: Any]
        do {
            toml = try Toml.parse(text)
        } catch {
            fputs("workspacer: config parse error: \(error)\n", stderr)
            return
        }

        var config = Config()

        if let count = toml["workspace_count"] as? Int, count >= 1, count <= 9 {
            config.workspaceCount = count
            config.numberKeys = buildNumberKeys(count: count)
        }

        if let ratio = toml["master_ratio"] as? Double {
            config.masterRatio = CGFloat(ratio)
        }

        if let paddingVal = toml["padding"] as? Double {
            config.padding = CGFloat(paddingVal)
        } else if let paddingVal = toml["padding"] as? Int {
            config.padding = CGFloat(paddingVal)
        }

        if let gapVal = toml["gap"] as? Double {
            config.gap = CGFloat(gapVal)
        } else if let gapVal = toml["gap"] as? Int {
            config.gap = CGFloat(gapVal)
        }

        if let hideInactive = toml["hide_inactive_apps"] as? Bool {
            config.hideInactiveApps = hideInactive
        }

        if let resizeOnHide = toml["resize_on_hide"] as? Bool {
            config.resizeOnHide = resizeOnHide
        }

        if let noPaddingSingle = toml["no_padding_for_single_window"] as? Bool {
            config.noPaddingForSingleWindow = noPaddingSingle
        }

        if let loopEnabled = toml["workspace_loop"] as? Bool {
            config.workspaceLoopEnabled = loopEnabled
        }

        if let enableCorners = toml["enable_corners"] as? Bool {
            config.enableCorners = enableCorners
        }

        if let cornerRadiusVal = toml["corner_radius"] as? Double {
            config.cornerRadius = CGFloat(cornerRadiusVal)
        } else if let cornerRadiusVal = toml["corner_radius"] as? Int {
            config.cornerRadius = CGFloat(cornerRadiusVal)
        }

        if let enableDynamic = toml["enable_dynamic_menubar"] as? Bool {
            config.enableDynamicMenubar = enableDynamic
        }

        if let hudEnabled = toml["hud_enabled"] as? Bool {
            config.hudEnabled = hudEnabled
        }

        if let hudPosition = toml["hud_position"] as? String {
            config.hudPosition = hudPosition.lowercased()
        }

        if let hudYOffsetVal = toml["hud_y_offset"] as? Double {
            config.hudYOffset = CGFloat(hudYOffsetVal)
        } else if let hudYOffsetVal = toml["hud_y_offset"] as? Int {
            config.hudYOffset = CGFloat(hudYOffsetVal)
        }

        if let hudDurationVal = toml["hud_duration"] as? Double {
            config.hudDuration = hudDurationVal
        } else if let hudDurationVal = toml["hud_duration"] as? Int {
            config.hudDuration = Double(hudDurationVal)
        }

        if let hudOnWS = toml["hud_on_workspace_switch"] as? Bool {
            config.hudOnWorkspaceSwitch = hudOnWS
        }

        if let hudOnLayout = toml["hud_on_layout_switch"] as? Bool {
            config.hudOnLayoutSwitch = hudOnLayout
        }

        if let hudOnConfig = toml["hud_on_config_reload"] as? Bool {
            config.hudOnConfigReload = hudOnConfig
        }

        if let names = toml["workspace_names"] as? [Any] {
            config.workspaceNames = names.compactMap { $0 as? String }
        }

        if let posStr = toml["inactive_window_position"] as? String {
            let normalized = posStr.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "_", with: "-")
            
            if normalized == "left" { config.inactiveWindowPosition = .left }
            else if normalized == "right" { config.inactiveWindowPosition = .right }
            else if normalized == "top" { config.inactiveWindowPosition = .top }
            else if normalized == "bottom" { config.inactiveWindowPosition = .bottom }
            else if normalized == "top-left" || normalized == "left-top" { config.inactiveWindowPosition = .topLeft }
            else if normalized == "top-right" || normalized == "right-top" { config.inactiveWindowPosition = .topRight }
            else if normalized == "bottom-left" || normalized == "left-bottom" { config.inactiveWindowPosition = .bottomLeft }
            else if normalized == "bottom-right" || normalized == "right-bottom" { config.inactiveWindowPosition = .bottomRight }
        }

        if let mod = toml["modifier"] as? String {
            switch mod {
            case "option": config.modifier = .maskAlternate
            case "control": config.modifier = .maskControl
            case "command": config.modifier = .maskCommand
            default: fputs("workspacer: unknown modifier '\(mod)', using option\n", stderr)
            }
        }

        if let alwaysCenter = toml["always_center_floating"] as? Bool {
            config.alwaysCenterFloating = alwaysCenter
        }

        if let priorityStr = toml["workspace_priority"] as? String {
            if let p = WorkspacePriority(rawValue: priorityStr.lowercased()) {
                config.workspacePriority = p
            }
        }

        if let enableCopy = toml["enable_copy_package_name"] as? Bool {
            config.enableCopyPackageName = enableCopy
        }

        if let floatApps = toml["floating_apps"] as? [Any] {
            config.floatingApps = Set(floatApps.compactMap { $0 as? String })
        }

        if let rulesDict = toml["workspace_rules"] as? [String: Any] {
            var rules: [String: Int] = [:]
            for (key, val) in rulesDict {
                if let index = val as? Int {
                    rules[key] = index
                }
            }
            config.workspaceRules = rules
        }

        if let mouseEnabled = toml["mouse_gesture_enabled"] as? Bool {
            config.mouseGestureEnabled = mouseEnabled
        }
        if let mouseButton = toml["mouse_gesture_button"] as? Int {
            config.mouseGestureButton = mouseButton
        }
        if let mouseSensitivity = toml["mouse_gesture_sensitivity"] as? Double {
            config.mouseGestureSensitivity = mouseSensitivity
        } else if let mouseSensitivity = toml["mouse_gesture_sensitivity"] as? Int {
            config.mouseGestureSensitivity = Double(mouseSensitivity)
        }

        if let mouse = toml["mouse_gesture"] as? [String: Any] {
            if let enabled = mouse["enable"] as? Bool {
                config.mouseGestureEnabled = enabled
            }
            if let button = mouse["button"] as? Int {
                config.mouseGestureButton = button
            }
            if let sensitivity = mouse["sensitivity"] as? Double {
                config.mouseGestureSensitivity = sensitivity
            } else if let sensitivity = mouse["sensitivity"] as? Int {
                config.mouseGestureSensitivity = Double(sensitivity)
            }
        }

        if let mouseBind = toml["mouse_bindings"] as? [String: Any] {
            var bindings: [Int: String] = [:]
            for (key, val) in mouseBind {
                if let btn = Int(key), let action = val as? String {
                    bindings[btn] = action
                }
            }
            config.mouseBindings = bindings
        }

        // Parse trackpad configs (supporting both top-level and [trackpad] table)
        if let swipeEnabled = toml["trackpad_swipe_enabled"] as? Bool {
            config.trackpadSwipeEnabled = swipeEnabled
        }
        if let swipeFingers = toml["trackpad_swipe_fingers"] as? Int {
            config.trackpadSwipeFingers = swipeFingers
        }
        if let swipeHaptic = toml["trackpad_swipe_haptic"] as? String {
            config.trackpadSwipeHaptic = swipeHaptic.lowercased()
        }
        if let swipeSensitivity = toml["trackpad_swipe_sensitivity"] as? Double {
            config.trackpadSwipeSensitivity = swipeSensitivity
        } else if let swipeSensitivity = toml["trackpad_swipe_sensitivity"] as? Int {
            config.trackpadSwipeSensitivity = Double(swipeSensitivity)
        }
        if let swipeMultiple = toml["trackpad_swipe_multiple"] as? Bool {
            config.trackpadSwipeMultiple = swipeMultiple
        }
        if let swipeRumble = toml["trackpad_swipe_rumble"] as? Bool {
            config.trackpadSwipeRumble = swipeRumble
        }

        if let trackpad = toml["trackpad"] as? [String: Any] {
            if let enabled = trackpad["enable"] as? Bool {
                config.trackpadSwipeEnabled = enabled
            }
            if let fingers = trackpad["fingers"] as? Int, fingers == 3 || fingers == 4 {
                config.trackpadSwipeFingers = fingers
            }
            if let haptic = trackpad["haptic_type"] as? String {
                config.trackpadSwipeHaptic = haptic.lowercased()
            }
            if let sensitivity = trackpad["sensitivity"] as? Double {
                config.trackpadSwipeSensitivity = sensitivity
            } else if let sensitivity = trackpad["sensitivity"] as? Int {
                config.trackpadSwipeSensitivity = Double(sensitivity)
            }
            if let allowMultiple = trackpad["allow_multiple"] as? Bool {
                config.trackpadSwipeMultiple = allowMultiple
            }
            if let rumble = trackpad["rumble"] as? Bool {
                config.trackpadSwipeRumble = rumble
            }
        }

        if let bindings = toml["bindings"] as? [String: Any] {
            applyBinding(bindings, "focus_next", to: &config.bindings.focusNext)
            applyBinding(bindings, "focus_prev", to: &config.bindings.focusPrev)
            applyBinding(bindings, "swap_master", to: &config.bindings.swapMaster)
            applyBinding(bindings, "toggle_layout", to: &config.bindings.toggleLayout)
            applyBinding(bindings, "focus_monitor_prev", to: &config.bindings.focusMonitorPrev)
            applyBinding(bindings, "focus_monitor_next", to: &config.bindings.focusMonitorNext)
            applyBinding(bindings, "move_monitor_prev", to: &config.bindings.moveMonitorPrev)
            applyBinding(bindings, "move_monitor_next", to: &config.bindings.moveMonitorNext)
            applyBinding(bindings, "last_workspace", to: &config.bindings.lastWorkspace)
            applyBinding(bindings, "prev_workspace", to: &config.bindings.prevWorkspace)
            applyBinding(bindings, "next_workspace", to: &config.bindings.nextWorkspace)
            applyBinding(bindings, "move_workspace_prev", to: &config.bindings.moveWorkspacePrev)
            applyBinding(bindings, "move_workspace_next", to: &config.bindings.moveWorkspaceNext)
            applyBinding(bindings, "refresh", to: &config.bindings.refresh)
            applyBinding(bindings, "toggle_float", to: &config.bindings.toggleFloat)
            applyBinding(bindings, "reload_config", to: &config.bindings.reloadConfig)
            applyBinding(bindings, "toggle_menubar", to: &config.bindings.toggleMenubar)
            applyBinding(bindings, "toggle_dynamic_menubar", to: &config.bindings.toggleDynamicMenubar)
            applyBinding(bindings, "shrink_window", to: &config.bindings.shrinkWindow)
            applyBinding(bindings, "expand_window", to: &config.bindings.expandWindow)
            applyBinding(bindings, "toggle_always_center_floating", to: &config.bindings.toggleAlwaysCenterFloating)
        }

        if let customs = toml["custom"] as? [[String: Any]] {
            config.customBindings = customs.compactMap { entry in
                guard let keyStr = entry["key"] as? String,
                      let command = entry["command"] as? String
                else { return nil }
                let (keyCode, shift) = parseKeyString(keyStr)
                guard let code = keyCode else {
                    fputs("workspacer: unknown key '\(keyStr)' in custom binding\n", stderr)
                    return nil
                }
                return Binding(key: code, shift: shift, command: command)
            }
        }

        shared = config
    }

    private static func parseKeyString(_ s: String) -> (key: UInt16?, shift: Bool) {
        if s.hasPrefix("shift+") {
            let name = String(s.dropFirst(6))
            return (Key.byName[name], true)
        }
        return (Key.byName[s], false)
    }

    private static func applyBinding(
        _ dict: [String: Any], _ name: String,
        to binding: inout (key: UInt16, shift: Bool)
    ) {
        guard let value = dict[name] as? String else { return }
        let (keyCode, shift) = parseKeyString(value)
        guard let code = keyCode else {
            fputs("workspacer: unknown key '\(value)' for binding '\(name)'\n", stderr)
            return
        }
        binding = (code, shift)
    }
}
