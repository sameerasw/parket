import SwiftUI
import AppKit
public import Combine

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

package final class SettingsWindowController {
    package static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    package func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let viewModel = SettingsViewModel()
        let contentView = SettingsView(viewModel: viewModel)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "Workspacer"
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }
    }
}

package final class SettingsViewModel: ObservableObject {
    @Published var workspaceCount: Int = 9
    @Published var workspaceNames: String = ""
    @Published var masterRatio: Double = 0.5
    @Published var padding: Double = 0
    @Published var gap: Double = 0
    @Published var hideInactiveApps: Bool = false
    @Published var resizeOnHide: Bool = true
    @Published var noPaddingForSingleWindow: Bool = false
    @Published var workspaceLoopEnabled: Bool = false
    @Published var inactiveWindowPosition: String = "left"
    @Published var alwaysCenterFloating: Bool = false
    @Published var workspacePriority: String = "last"
    @Published var enableCopyPackageName: Bool = false
    
    @Published var enableCorners: Bool = false
    @Published var cornerRadius: Double = 0
    @Published var enableDynamicMenubar: Bool = false
    
    @Published var hudEnabled: Bool = true
    @Published var switchOverlayEnabled: Bool = true
    @Published var switchOverlayColor: String = "accent"
    @Published var switchOverlayDelayEnabled: Bool = true
    @Published var switchOverlayShowIcons: Bool = true
    @Published var switchOverlayIconSize: Double = 64.0
    @Published var switchOverlayColorOpacity: Double = 0.2
    @Published var switchOverlayMode: String = "morph"
    @Published var hudPosition: String = "top"
    @Published var hudYOffset: Double = 50.0
    @Published var hudDuration: Double = 1.5
    @Published var hudOnWorkspaceSwitch: Bool = true
    @Published var hudOnLayoutSwitch: Bool = true
    @Published var hudOnConfigReload: Bool = true
    
    @Published var trackpadSwipeEnabled: Bool = false
    @Published var trackpadSwipeFingers: Int = 3
    @Published var trackpadSwipeHaptic: String = "non"
    @Published var trackpadSwipeSensitivity: Double = 1.0
    @Published var trackpadSwipeMultiple: Bool = false
    @Published var trackpadSwipeRumble: Bool = false
    
    @Published var mouseGestureEnabled: Bool = false
    @Published var mouseGestureButton: Int = 5
    @Published var mouseGestureSensitivity: Double = 1.0
    @Published var mouseGestureAllowMultiple: Bool = false
    @Published var mouseClickThreshold: Double = 0.4
    
    @Published var button4Action: String = "back"
    @Published var button5Action: String = "forward"
    
    init() {
        loadFromConfig()
    }
    
    func loadFromConfig() {
        let config = Config.shared
        workspaceCount = config.workspaceCount
        workspaceNames = config.workspaceNames.joined(separator: ", ")
        masterRatio = Double(config.masterRatio)
        padding = Double(config.padding)
        gap = Double(config.gap)
        hideInactiveApps = config.hideInactiveApps
        resizeOnHide = config.resizeOnHide
        noPaddingForSingleWindow = config.noPaddingForSingleWindow
        workspaceLoopEnabled = config.workspaceLoopEnabled
        inactiveWindowPosition = config.inactiveWindowPosition.rawValue
        alwaysCenterFloating = config.alwaysCenterFloating
        workspacePriority = config.workspacePriority.rawValue
        enableCopyPackageName = config.enableCopyPackageName
        
        enableCorners = config.enableCorners
        cornerRadius = Double(config.cornerRadius)
        enableDynamicMenubar = config.enableDynamicMenubar
        
        hudEnabled = config.hudEnabled
        switchOverlayEnabled = config.switchOverlayEnabled
        switchOverlayColor = config.switchOverlayColor
        switchOverlayDelayEnabled = config.switchOverlayDelayEnabled
        switchOverlayShowIcons = config.switchOverlayShowIcons
        switchOverlayIconSize = Double(config.switchOverlayIconSize)
        switchOverlayColorOpacity = Double(config.switchOverlayColorOpacity)
        switchOverlayMode = config.switchOverlayMode
        hudPosition = config.hudPosition
        hudYOffset = Double(config.hudYOffset)
        hudDuration = config.hudDuration
        hudOnWorkspaceSwitch = config.hudOnWorkspaceSwitch
        hudOnLayoutSwitch = config.hudOnLayoutSwitch
        hudOnConfigReload = config.hudOnConfigReload
        
        trackpadSwipeEnabled = config.trackpadSwipeEnabled
        trackpadSwipeFingers = config.trackpadSwipeFingers
        trackpadSwipeHaptic = config.trackpadSwipeHaptic
        trackpadSwipeSensitivity = config.trackpadSwipeSensitivity
        trackpadSwipeMultiple = config.trackpadSwipeMultiple
        trackpadSwipeRumble = config.trackpadSwipeRumble
        
        mouseGestureEnabled = config.mouseGestureEnabled
        mouseGestureButton = config.mouseGestureButton
        mouseGestureSensitivity = config.mouseGestureSensitivity
        mouseGestureAllowMultiple = config.mouseGestureAllowMultiple
        mouseClickThreshold = config.mouseClickThreshold
        
        button4Action = config.mouseBindings[4] ?? "back"
        button5Action = config.mouseBindings[5] ?? "forward"
    }
    
    func saveToConfig() {
        var config = Config.shared
        config.workspaceCount = workspaceCount
        config.workspaceNames = workspaceNames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        config.masterRatio = CGFloat(masterRatio)
        config.padding = CGFloat(padding)
        config.gap = CGFloat(gap)
        config.hideInactiveApps = hideInactiveApps
        config.resizeOnHide = resizeOnHide
        config.noPaddingForSingleWindow = noPaddingForSingleWindow
        config.workspaceLoopEnabled = workspaceLoopEnabled
        config.inactiveWindowPosition = InactiveWindowPosition(rawValue: inactiveWindowPosition) ?? .left
        config.alwaysCenterFloating = alwaysCenterFloating
        config.workspacePriority = WorkspacePriority(rawValue: workspacePriority) ?? .last
        config.enableCopyPackageName = enableCopyPackageName
        
        config.enableCorners = enableCorners
        config.cornerRadius = CGFloat(cornerRadius)
        config.enableDynamicMenubar = enableDynamicMenubar
        
        config.hudEnabled = hudEnabled
        config.switchOverlayEnabled = switchOverlayEnabled
        config.switchOverlayColor = switchOverlayColor
        config.switchOverlayDelayEnabled = switchOverlayDelayEnabled
        config.switchOverlayShowIcons = switchOverlayShowIcons
        config.switchOverlayIconSize = CGFloat(switchOverlayIconSize)
        config.switchOverlayColorOpacity = CGFloat(switchOverlayColorOpacity)
        config.switchOverlayMode = switchOverlayMode
        config.hudPosition = hudPosition
        config.hudYOffset = CGFloat(hudYOffset)
        config.hudDuration = hudDuration
        config.hudOnWorkspaceSwitch = hudOnWorkspaceSwitch
        config.hudOnLayoutSwitch = hudOnLayoutSwitch
        config.hudOnConfigReload = hudOnConfigReload
        
        config.trackpadSwipeEnabled = trackpadSwipeEnabled
        config.trackpadSwipeFingers = trackpadSwipeFingers
        config.trackpadSwipeHaptic = trackpadSwipeHaptic
        config.trackpadSwipeSensitivity = trackpadSwipeSensitivity
        config.trackpadSwipeMultiple = trackpadSwipeMultiple
        config.trackpadSwipeRumble = trackpadSwipeRumble
        
        config.mouseGestureEnabled = mouseGestureEnabled
        config.mouseGestureButton = mouseGestureButton
        config.mouseGestureSensitivity = mouseGestureSensitivity
        config.mouseGestureAllowMultiple = mouseGestureAllowMultiple
        config.mouseClickThreshold = mouseClickThreshold
        
        config.mouseBindings[4] = button4Action
        config.mouseBindings[5] = button5Action
        
        Config.shared = config
        Config.shared.save()
        WorkspaceManager.shared.reloadConfig()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var activeTab = "General"
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar area — sits in the titlebar region
                HStack {
                    Spacer()
                    
                    Picker("", selection: $activeTab) {
                        Label("General", systemImage: "slider.horizontal.3").tag("General")
                        Label("Appearance", systemImage: "paintpalette").tag("Appearance")
                        Label("HUD", systemImage: "macwindow").tag("HUD")
                        Label("Input", systemImage: "keyboard").tag("Input")
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(width: 360)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .frame(height: 50)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch activeTab {
                        case "General":
                            generalView
                        case "Appearance":
                            appearanceView
                        case "HUD":
                            hudView
                        case "Input":
                            inputView
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 550, height: 500)
    }
    
    private var generalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Workspaces")
                    .font(.headline)
                
                HStack {
                    Text("Workspace Count")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.workspaceCount },
                        set: { viewModel.workspaceCount = $0; viewModel.saveToConfig() }
                    )) {
                        ForEach(1...9, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .frame(width: 80)
                }
                
                HStack {
                    Text("Workspace Names")
                    Spacer()
                    TextField("e.g. Chat, Web, Code", text: SwiftUI.Binding(
                        get: { viewModel.workspaceNames },
                        set: { viewModel.workspaceNames = $0; viewModel.saveToConfig() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                }
            }
            

            
            Group {
                Text("Tiling Layout")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Master Window Ratio")
                        Spacer()
                        Text(String(format: "%.0f%%", viewModel.masterRatio * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.masterRatio },
                        set: { viewModel.masterRatio = $0; viewModel.saveToConfig() }
                    ), in: 0.2...0.8, step: 0.05)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Padding")
                        Spacer()
                        Text("\(Int(viewModel.padding)) px")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.padding },
                        set: { viewModel.padding = $0; viewModel.saveToConfig() }
                    ), in: 0...50, step: 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Gaps")
                        Spacer()
                        Text("\(Int(viewModel.gap)) px")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.gap },
                        set: { viewModel.gap = $0; viewModel.saveToConfig() }
                    ), in: 0...50, step: 1)
                }
                
                Toggle("Loop Workspaces", isOn: SwiftUI.Binding(
                    get: { viewModel.workspaceLoopEnabled },
                    set: { viewModel.workspaceLoopEnabled = $0; viewModel.saveToConfig() }
                ))
                
                Toggle("Always Center Floating Windows", isOn: SwiftUI.Binding(
                    get: { viewModel.alwaysCenterFloating },
                    set: { viewModel.alwaysCenterFloating = $0; viewModel.saveToConfig() }
                ))
                
                HStack {
                    Text("Workspace Priority")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.workspacePriority },
                        set: { viewModel.workspacePriority = $0; viewModel.saveToConfig() }
                    )) {
                        Text("None").tag("none")
                        Text("Last Session").tag("last")
                        Text("Config Rules").tag("config")
                    }
                    .frame(width: 140)
                }
            }
        }
    }
    
    private var appearanceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Corners Overlay")
                    .font(.headline)
                
                Toggle("Enable Rounded Corners", isOn: SwiftUI.Binding(
                    get: { viewModel.enableCorners },
                    set: { viewModel.enableCorners = $0; viewModel.saveToConfig() }
                ))
                
                if viewModel.enableCorners {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            Text(String(format: "%.1f px", viewModel.cornerRadius))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: SwiftUI.Binding(
                            get: { viewModel.cornerRadius },
                            set: { viewModel.cornerRadius = $0; viewModel.saveToConfig() }
                        ), in: 5...35, step: 0.5)
                    }
                }
            }
            

            
            Group {
                Text("Menu Bar")
                    .font(.headline)
                
                Toggle("Auto-Hide Dynamic Menu Bar", isOn: SwiftUI.Binding(
                    get: { viewModel.enableDynamicMenubar },
                    set: { viewModel.enableDynamicMenubar = $0; viewModel.saveToConfig() }
                ))
                
                HStack {
                    Text("Off-screen Window Target Edge")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.inactiveWindowPosition },
                        set: { viewModel.inactiveWindowPosition = $0; viewModel.saveToConfig() }
                    )) {
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                        Text("Top").tag("top")
                        Text("Bottom").tag("bottom")
                        Text("Top-Left").tag("top-left")
                        Text("Top-Right").tag("top-right")
                        Text("Bottom-Left").tag("bottom-left")
                        Text("Bottom-Right").tag("bottom-right")
                    }
                    .frame(width: 160)
                }
            }
        }
    }
    
    private var hudView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heads-Up Display (HUD)")
                .font(.headline)
            
            Toggle("Enable HUD Overlay", isOn: SwiftUI.Binding(
                get: { viewModel.hudEnabled },
                set: { viewModel.hudEnabled = $0; viewModel.saveToConfig() }
            ))
            
            Toggle("Enable Layout Switch Overlay Animation", isOn: SwiftUI.Binding(
                get: { viewModel.switchOverlayEnabled },
                set: { viewModel.switchOverlayEnabled = $0; viewModel.saveToConfig() }
            ))
            
            if viewModel.switchOverlayEnabled {
                HStack {
                    Text("Overlay Color Theme")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.switchOverlayColor },
                        set: { viewModel.switchOverlayColor = $0; viewModel.saveToConfig() }
                    )) {
                        Text("Accent Color").tag("accent")
                        Text("System Theme").tag("system")
                        Text("Dark Mode").tag("dark")
                        Text("Light Mode").tag("light")
                    }
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Overlay Color Opacity")
                        Spacer()
                        Text(String(format: "%.0f%%", viewModel.switchOverlayColorOpacity * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.switchOverlayColorOpacity },
                        set: { viewModel.switchOverlayColorOpacity = $0; viewModel.saveToConfig() }
                    ), in: 0.0...1.0, step: 0.05)
                }

                HStack {
                    Text("Overlay Animation Mode")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.switchOverlayMode },
                        set: { viewModel.switchOverlayMode = $0; viewModel.saveToConfig() }
                    )) {
                        Text("Morph").tag("morph")
                        Text("Slide").tag("slide")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                Toggle("Align Window Switch with Animation", isOn: SwiftUI.Binding(
                    get: { viewModel.switchOverlayDelayEnabled },
                    set: { viewModel.switchOverlayDelayEnabled = $0; viewModel.saveToConfig() }
                ))

                Toggle("Show App Icons in Overlay", isOn: SwiftUI.Binding(
                    get: { viewModel.switchOverlayShowIcons },
                    set: { viewModel.switchOverlayShowIcons = $0; viewModel.saveToConfig() }
                ))

                if viewModel.switchOverlayShowIcons {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Icon Size")
                            Spacer()
                            Text("\(Int(viewModel.switchOverlayIconSize)) px")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: SwiftUI.Binding(
                            get: { viewModel.switchOverlayIconSize },
                            set: { viewModel.switchOverlayIconSize = $0; viewModel.saveToConfig() }
                        ), in: 32...192, step: 8)
                    }
                }
            }
            
            if viewModel.hudEnabled {
                HStack {
                    Text("HUD Position")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.hudPosition },
                        set: { viewModel.hudPosition = $0; viewModel.saveToConfig() }
                    )) {
                        Text("Top").tag("top")
                        Text("Bottom").tag("bottom")
                        Text("Center").tag("center")
                    }
                    .frame(width: 120)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("HUD Y-Offset")
                        Spacer()
                        Text("\(Int(viewModel.hudYOffset)) px")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.hudYOffset },
                        set: { viewModel.hudYOffset = $0; viewModel.saveToConfig() }
                    ), in: 0...200, step: 5)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("HUD Duration")
                        Spacer()
                        Text(String(format: "%.1fs", viewModel.hudDuration))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.hudDuration },
                        set: { viewModel.hudDuration = $0; viewModel.saveToConfig() }
                    ), in: 0.5...4.0, step: 0.1)
                }
                

                
                Text("Show HUD On:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Toggle("Workspace Switches", isOn: SwiftUI.Binding(
                    get: { viewModel.hudOnWorkspaceSwitch },
                    set: { viewModel.hudOnWorkspaceSwitch = $0; viewModel.saveToConfig() }
                ))
                
                Toggle("Layout Switches", isOn: SwiftUI.Binding(
                    get: { viewModel.hudOnLayoutSwitch },
                    set: { viewModel.hudOnLayoutSwitch = $0; viewModel.saveToConfig() }
                ))
                
                Toggle("Config Reloads", isOn: SwiftUI.Binding(
                    get: { viewModel.hudOnConfigReload },
                    set: { viewModel.hudOnConfigReload = $0; viewModel.saveToConfig() }
                ))
            }
        }
    }
    
    private var inputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Trackpad Swiping")
                    .font(.headline)
                
                Toggle("Enable Trackpad Swipe Gestures", isOn: SwiftUI.Binding(
                    get: { viewModel.trackpadSwipeEnabled },
                    set: { viewModel.trackpadSwipeEnabled = $0; viewModel.saveToConfig() }
                ))
                
                if viewModel.trackpadSwipeEnabled {
                    HStack {
                        Text("Fingers Count")
                        Spacer()
                        Picker("", selection: SwiftUI.Binding(
                            get: { viewModel.trackpadSwipeFingers },
                            set: { viewModel.trackpadSwipeFingers = $0; viewModel.saveToConfig() }
                        )) {
                            Text("3 Fingers").tag(3)
                            Text("4 Fingers").tag(4)
                        }
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Haptic Feedback")
                        Spacer()
                        Picker("", selection: SwiftUI.Binding(
                            get: { viewModel.trackpadSwipeHaptic },
                            set: { viewModel.trackpadSwipeHaptic = $0; viewModel.saveToConfig() }
                        )) {
                            Text("None").tag("non")
                            Text("Light").tag("light")
                            Text("Strong").tag("strong")
                            Text("Double").tag("double")
                        }
                        .frame(width: 120)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text(String(format: "%.1fx", viewModel.trackpadSwipeSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: SwiftUI.Binding(
                            get: { viewModel.trackpadSwipeSensitivity },
                            set: { viewModel.trackpadSwipeSensitivity = $0; viewModel.saveToConfig() }
                        ), in: 0.2...3.0, step: 0.1)
                    }
                    
                    Toggle("Allow Multiple switches per swipe", isOn: SwiftUI.Binding(
                        get: { viewModel.trackpadSwipeMultiple },
                        set: { viewModel.trackpadSwipeMultiple = $0; viewModel.saveToConfig() }
                    ))
                    
                    Toggle("Light Rumble Feedback on trigger start", isOn: SwiftUI.Binding(
                        get: { viewModel.trackpadSwipeRumble },
                        set: { viewModel.trackpadSwipeRumble = $0; viewModel.saveToConfig() }
                    ))
                }
            }
            

            
            Group {
                Text("Mouse Swiping & Clicks")
                    .font(.headline)
                
                Toggle("Enable Mouse Gesture Swiping", isOn: SwiftUI.Binding(
                    get: { viewModel.mouseGestureEnabled },
                    set: { viewModel.mouseGestureEnabled = $0; viewModel.saveToConfig() }
                ))
                
                if viewModel.mouseGestureEnabled {
                    HStack {
                        Text("Gesture Drag Button")
                        Spacer()
                        Picker("", selection: SwiftUI.Binding(
                            get: { viewModel.mouseGestureButton },
                            set: { viewModel.mouseGestureButton = $0; viewModel.saveToConfig() }
                        )) {
                            Text("Middle Click (Button 3)").tag(3)
                            Text("Back Button (Button 4)").tag(4)
                            Text("Forward Button (Button 5)").tag(5)
                        }
                        .frame(width: 200)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Swipe Sensitivity")
                            Spacer()
                            Text(String(format: "%.1fx", viewModel.mouseGestureSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: SwiftUI.Binding(
                            get: { viewModel.mouseGestureSensitivity },
                            set: { viewModel.mouseGestureSensitivity = $0; viewModel.saveToConfig() }
                        ), in: 0.2...3.0, step: 0.1)
                    }
                    
                    Toggle("Allow Multiple switches per drag", isOn: SwiftUI.Binding(
                        get: { viewModel.mouseGestureAllowMultiple },
                        set: { viewModel.mouseGestureAllowMultiple = $0; viewModel.saveToConfig() }
                    ))
                }
                

                
                Text("Mouse Button Click Bindings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Button 4 Click Action")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.button4Action },
                        set: { viewModel.button4Action = $0; viewModel.saveToConfig() }
                    )) {
                        actionOptions
                    }
                    .frame(width: 200)
                }
                
                HStack {
                    Text("Button 5 Click Action")
                    Spacer()
                    Picker("", selection: SwiftUI.Binding(
                        get: { viewModel.button5Action },
                        set: { viewModel.button5Action = $0; viewModel.saveToConfig() }
                    )) {
                        actionOptions
                    }
                    .frame(width: 200)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Click Duration Threshold")
                        Spacer()
                        Text(String(format: "%.2fs", viewModel.mouseClickThreshold))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: SwiftUI.Binding(
                        get: { viewModel.mouseClickThreshold },
                        set: { viewModel.mouseClickThreshold = $0; viewModel.saveToConfig() }
                    ), in: 0.1...1.0, step: 0.05)
                }
            }
            

            
            Group {
                Text("Shortcuts")
                    .font(.headline)
                
                Toggle("Copy Package Name Shortcut (option+shift+i)", isOn: SwiftUI.Binding(
                    get: { viewModel.enableCopyPackageName },
                    set: { viewModel.enableCopyPackageName = $0; viewModel.saveToConfig() }
                ))
            }
        }
    }
    
    @ViewBuilder
    private var actionOptions: some View {
        Text("No Action").tag("none")
        Text("Back Navigation").tag("back")
        Text("Forward Navigation").tag("forward")
        Text("Previous Workspace").tag("prev_workspace")
        Text("Next Workspace").tag("next_workspace")
        Text("Focus Next Window").tag("focus_next")
        Text("Focus Previous Window").tag("focus_prev")
        Text("Swap Master").tag("swap_master")
        Text("Toggle Layout").tag("toggle_layout")
        Text("Focus Monitor Prev").tag("focus_monitor_prev")
        Text("Focus Monitor Next").tag("focus_monitor_next")
        Text("Move Monitor Prev").tag("move_monitor_prev")
        Text("Move Monitor Next").tag("move_monitor_next")
        Text("Switch to Last Workspace").tag("last_workspace")
        Text("Move Active Window to Prev Workspace").tag("move_workspace_prev")
        Text("Move Active Window to Next Workspace").tag("move_workspace_next")
        Text("Refresh Workspace").tag("refresh")
        Text("Toggle Active Window Float").tag("toggle_float")
        Text("Reload Config").tag("reload_config")
        Text("Toggle Menu Bar Auto-Hide").tag("toggle_menubar")
        Text("Toggle Dynamic Menu Bar").tag("toggle_dynamic_menubar")
        Text("Shrink Window Size").tag("shrink_window")
        Text("Expand Window Size").tag("expand_window")
        Text("Toggle Always Center Floating").tag("toggle_always_center_floating")
    }
}
