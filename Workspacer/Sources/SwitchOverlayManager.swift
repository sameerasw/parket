    import Cocoa
    import SwiftUI
    public import Combine

    package struct CapturedWindowInfo {
        package let frame: CGRect
        package let bundleId: String?
        
        package init(frame: CGRect, bundleId: String?) {
            self.frame = frame
            self.bundleId = bundleId
        }
    }

    package final class AppIconCache {
        package static let shared = AppIconCache()
        
        private var cache = [String: NSImage]()
        private let lock = NSLock()
        
        private init() {}
        
        package func icon(for bundleId: String) -> NSImage? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = cache[bundleId] {
                return cached
            }
            
            preloadIcon(for: bundleId)
            return nil
        }
        
        package func preloadIcon(for bundleId: String) {
            DispatchQueue.global(qos: .background).async {
                self.lock.lock()
                let alreadyCached = self.cache[bundleId] != nil
                self.lock.unlock()
                
                if alreadyCached { return }
                
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let image = NSWorkspace.shared.icon(forFile: appURL.path)
                    let resized = self.resizeImage(image, to: CGSize(width: 256, height: 256))
                    
                    self.lock.lock()
                    self.cache[bundleId] = resized
                    self.lock.unlock()
                }
            }
        }
        
    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

package final class SwitchOverlayManager {
    package static let shared = SwitchOverlayManager()

    private var overlayWindow: SwitchOverlayWindow?
    private var fadeOutTimer: Timer?

    private init() {}

    package func updateInteractiveProgress(_ progress: CGFloat, on screen: NSScreen, oldFrames: [CapturedWindowInfo]) {
        guard Config.shared.switchOverlayEnabled else { return }
        guard oldFrames.count >= 1 else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.overlayWindow {
                if !window.isCommitted {
                    window.alphaValue = min(1.0, abs(progress))
                    window.setInteractiveProgress(progress)
                }
            } else {
                let window = SwitchOverlayWindow(screen: screen, oldFrames: oldFrames, to: oldFrames, isInteractive: true, direction: progress < 0 ? -1.0 : 1.0)
                self.overlayWindow = window
                window.alphaValue = min(1.0, abs(progress))
                window.setInteractiveProgress(progress)
            }
        }
    }

    package func cancelInteractive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let window = self.overlayWindow {
                if !window.isCommitted {
                    if window.model.mode == "slide" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            window.model.progress = 0.0
                        }
                    }
                    window.fadeOut {
                        window.close()
                        if self.overlayWindow === window {
                            self.overlayWindow = nil
                        }
                    }
                }
            }
        }
    }

    package func show(from oldFrames: [CapturedWindowInfo], to newFrames: [CapturedWindowInfo], on screen: NSScreen, direction: CGFloat = -1.0) {
        guard Config.shared.switchOverlayEnabled else { return }
        guard oldFrames.count >= 1 || newFrames.count >= 1 else { return }

        fadeOutTimer?.invalidate()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.overlayWindow {
                // If it was interactive, commit the transition
                window.commit(to: newFrames)
                
                self.fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { _ in
                    window.fadeOut {
                        window.close()
                        if self.overlayWindow === window {
                            self.overlayWindow = nil
                        }
                    }
                }
            } else {
                // Non-interactive path
                let window = SwitchOverlayWindow(screen: screen, oldFrames: oldFrames, to: newFrames, isInteractive: false, direction: direction)
                self.overlayWindow = window
                window.fadeIn()

                self.fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { _ in
                    window.fadeOut {
                        window.close()
                        if self.overlayWindow === window {
                            self.overlayWindow = nil
                        }
                    }
                }
            }
        }
    }
}

private final class SwitchOverlayModel: ObservableObject {
    @Published var animate = false
    @Published var boxes: [BoxState] = []
    @Published var sourceBoxes: [BoxState] = []
    @Published var targetBoxes: [BoxState] = []
    @Published var progress: CGFloat = 0.0
    @Published var direction: CGFloat = -1.0
    @Published var mode: String = "morph"
}

private final class SwitchOverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let model: SwitchOverlayModel
    var isCommitted: Bool

    init(screen: NSScreen, oldFrames: [CapturedWindowInfo], to newFrames: [CapturedWindowInfo], isInteractive: Bool, direction: CGFloat = -1.0) {
        self.targetScreen = screen
        self.model = SwitchOverlayModel()
        self.isCommitted = !isInteractive
        self.model.mode = Config.shared.switchOverlayMode

        let screenFrame = screen.frame
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false
        self.level = .floating // just above normal tiled windows, but below status bar, dock, and notifications
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.alphaValue = 0.0

        // Explicitly set vibrant dark/light appearance so system materials resolve properly
        let theme = Config.shared.switchOverlayColor
        let isSystemDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let useDarkAppearance: Bool
        if theme == "dark" {
            useDarkAppearance = true
        } else if theme == "light" {
            useDarkAppearance = false
        } else {
            useDarkAppearance = isSystemDark
        }
        self.appearance = NSAppearance(named: useDarkAppearance ? .vibrantDark : .vibrantLight)

        let screenRectYDown = WindowManager.screenRect(for: screen)
        if model.mode == "slide" {
            // Populate sourceBoxes
            var src: [BoxState] = []
            for frameInfo in oldFrames {
                let local = CGRect(
                    x: frameInfo.frame.origin.x - screenRectYDown.origin.x,
                    y: frameInfo.frame.origin.y - screenRectYDown.origin.y,
                    width: frameInfo.frame.width,
                    height: frameInfo.frame.height
                )
                src.append(BoxState(
                    currentFrame: local,
                    targetFrame: local,
                    startOpacity: 1.0,
                    targetOpacity: 0.0,
                    bundleId: frameInfo.bundleId
                ))
            }
            model.sourceBoxes = src
            
            // Populate targetBoxes (for non-interactive path)
            var dst: [BoxState] = []
            for frameInfo in newFrames {
                let local = CGRect(
                    x: frameInfo.frame.origin.x - screenRectYDown.origin.x,
                    y: frameInfo.frame.origin.y - screenRectYDown.origin.y,
                    width: frameInfo.frame.width,
                    height: frameInfo.frame.height
                )
                dst.append(BoxState(
                    currentFrame: local,
                    targetFrame: local,
                    startOpacity: 0.0,
                    targetOpacity: 1.0,
                    bundleId: frameInfo.bundleId
                ))
            }
            model.targetBoxes = dst
            
            model.direction = direction
            model.progress = 0.0
            
            if !isInteractive {
                model.animate = true
            }
        } else {
            let screenWidth = screenRectYDown.width
            let screenHeight = screenRectYDown.height
            
            var boxes: [BoxState] = []
            let maxCount = max(oldFrames.count, newFrames.count)
            
            for i in 0..<maxCount {
                if i < oldFrames.count && i < newFrames.count {
                    let old = oldFrames[i].frame
                    let new = newFrames[i].frame
                    let bundleId = newFrames[i].bundleId ?? oldFrames[i].bundleId
                    let currentLocal = CGRect(
                        x: old.origin.x - screenRectYDown.origin.x,
                        y: old.origin.y - screenRectYDown.origin.y,
                        width: old.width,
                        height: old.height
                    )
                    let targetLocal = CGRect(
                        x: new.origin.x - screenRectYDown.origin.x,
                        y: new.origin.y - screenRectYDown.origin.y,
                        width: new.width,
                        height: new.height
                    )
                    boxes.append(BoxState(
                        currentFrame: currentLocal,
                        targetFrame: targetLocal,
                        startOpacity: 1.0,
                        targetOpacity: 1.0,
                        bundleId: bundleId
                    ))
                } else if i < oldFrames.count {
                    let old = oldFrames[i].frame
                    let bundleId = oldFrames[i].bundleId
                    let currentLocal = CGRect(
                        x: old.origin.x - screenRectYDown.origin.x,
                        y: old.origin.y - screenRectYDown.origin.y,
                        width: old.width,
                        height: old.height
                    )
                    // Retract width or height to edge instead of scaling to center
                    let retractToRight = (currentLocal.midX > screenWidth / 2)
                    let retractToBottom = (currentLocal.midY > screenHeight / 2)
                    
                    let targetLocal: CGRect
                    if currentLocal.width > currentLocal.height {
                        if retractToBottom {
                            targetLocal = CGRect(x: currentLocal.origin.x, y: currentLocal.maxY, width: currentLocal.width, height: 0)
                        } else {
                            targetLocal = CGRect(x: currentLocal.origin.x, y: currentLocal.origin.y, width: currentLocal.width, height: 0)
                        }
                    } else {
                        if retractToRight {
                            targetLocal = CGRect(x: currentLocal.maxX, y: currentLocal.origin.y, width: 0, height: currentLocal.height)
                        } else {
                            targetLocal = CGRect(x: currentLocal.origin.x, y: currentLocal.origin.y, width: 0, height: currentLocal.height)
                        }
                    }
                    
                    boxes.append(BoxState(
                        currentFrame: currentLocal,
                        targetFrame: targetLocal,
                        startOpacity: 1.0,
                        targetOpacity: 0.0,
                        bundleId: bundleId
                    ))
                } else {
                    let new = newFrames[i].frame
                    let bundleId = newFrames[i].bundleId
                    let targetLocal = CGRect(
                        x: new.origin.x - screenRectYDown.origin.x,
                        y: new.origin.y - screenRectYDown.origin.y,
                        width: new.width,
                        height: new.height
                    )
                    // Expand width or height from edge instead of scaling from center
                    let expandFromRight = (targetLocal.midX > screenWidth / 2)
                    let expandFromBottom = (targetLocal.midY > screenHeight / 2)
                    
                    let currentLocal: CGRect
                    if targetLocal.width > targetLocal.height {
                        if expandFromBottom {
                            currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.maxY, width: targetLocal.width, height: 0)
                        } else {
                            currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.origin.y, width: targetLocal.width, height: 0)
                        }
                    } else {
                        if expandFromRight {
                            currentLocal = CGRect(x: targetLocal.maxX, y: targetLocal.origin.y, width: 0, height: targetLocal.height)
                        } else {
                            currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.origin.y, width: 0, height: targetLocal.height)
                        }
                    }
                    
                    boxes.append(BoxState(
                        currentFrame: currentLocal,
                        targetFrame: targetLocal,
                        startOpacity: 0.0,
                        targetOpacity: 1.0,
                        bundleId: bundleId
                    ))
                }
            }

            self.model.boxes = boxes
            self.model.animate = !isInteractive
        }

        let viewSize = screenRectYDown.size
        let overlayView = SwitchOverlayView(model: model, viewSize: viewSize)
        self.contentView = NSHostingView(rootView: AnyView(overlayView))
        
        self.orderFrontRegardless()
    }

    func fadeIn() {
        self.alphaValue = 1.0
        if model.mode == "slide" && model.animate {
            model.progress = 0.0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                model.progress = model.direction
            }
        }
    }

    func setInteractiveProgress(_ progress: CGFloat) {
        if model.mode == "slide" {
            self.model.progress = 0.0 // Sticky till trigger
            let dir: CGFloat = progress < 0 ? -1.0 : (progress > 0 ? 1.0 : 0.0)
            if dir != 0.0 && dir != model.direction {
                model.direction = dir
                
                if let monitor = WorkspaceManager.shared.monitors.first(where: { $0.screen == self.targetScreen }) {
                    let count = Config.shared.workspaceCount
                    let active = monitor.active
                    let targetIndex: Int
                    if dir < 0 {
                        targetIndex = Config.shared.workspaceLoopEnabled ? (active + 1) % count : min(active + 1, count - 1)
                    } else {
                        targetIndex = Config.shared.workspaceLoopEnabled ? (active - 1 + count) % count : max(active - 1, 0)
                    }
                    
                    let targetTiledWindows = monitor.workspaces[targetIndex].filter { !$0.isFloating }
                    let targetLayout = monitor.layouts[targetIndex]
                    let targetMasterRatio = monitor.masterRatios[targetIndex]
                    let targetStackRatios = monitor.stackRatios[targetIndex]
                    let screenRect = WindowManager.screenFrame(for: monitor.screen)
                    let targetFrames = Tiler.calculateFrames(
                        count: targetTiledWindows.count,
                        screen: screenRect,
                        layout: targetLayout,
                        masterRatio: targetMasterRatio,
                        stackRatios: targetStackRatios
                    )
                    
                    let screenRectYDown = WindowManager.screenRect(for: monitor.screen)
                    var targetBoxes: [BoxState] = []
                    for (i, frame) in targetFrames.enumerated() {
                        let bundleId = i < targetTiledWindows.count ? NSRunningApplication(processIdentifier: targetTiledWindows[i].pid)?.bundleIdentifier : nil
                        let local = CGRect(
                            x: frame.origin.x - screenRectYDown.origin.x,
                            y: frame.origin.y - screenRectYDown.origin.y,
                            width: frame.width,
                            height: frame.height
                        )
                        targetBoxes.append(BoxState(
                            currentFrame: local,
                            targetFrame: local,
                            startOpacity: 0.0,
                            targetOpacity: 1.0,
                            bundleId: bundleId
                        ))
                    }
                    self.model.targetBoxes = targetBoxes
                }
            }
        } else {
            self.model.progress = progress
        }
    }

    func commit(to newFrames: [CapturedWindowInfo]) {
        guard !isCommitted else { return }
        isCommitted = true

        if model.mode == "slide" {
            let screenRectYDown = WindowManager.screenRect(for: self.targetScreen)
            var targetBoxes: [BoxState] = []
            for frameInfo in newFrames {
                let local = CGRect(
                    x: frameInfo.frame.origin.x - screenRectYDown.origin.x,
                    y: frameInfo.frame.origin.y - screenRectYDown.origin.y,
                    width: frameInfo.frame.width,
                    height: frameInfo.frame.height
                )
                targetBoxes.append(BoxState(
                    currentFrame: local,
                    targetFrame: local,
                    startOpacity: 0.0,
                    targetOpacity: 1.0,
                    bundleId: frameInfo.bundleId
                ))
            }
            model.targetBoxes = targetBoxes
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                model.progress = model.direction
                model.animate = true
            }
            self.alphaValue = 1.0
            return
        }

        let screenRectYDown = WindowManager.screenRect(for: self.targetScreen)
        let screenWidth = screenRectYDown.width
        let screenHeight = screenRectYDown.height
        var updatedBoxes = model.boxes

        let maxCount = max(updatedBoxes.count, newFrames.count)

        for i in 0..<maxCount {
            if i < updatedBoxes.count {
                if i < newFrames.count {
                    let new = newFrames[i].frame
                    updatedBoxes[i].targetFrame = CGRect(
                        x: new.origin.x - screenRectYDown.origin.x,
                        y: new.origin.y - screenRectYDown.origin.y,
                        width: new.width,
                        height: new.height
                    )
                    updatedBoxes[i].targetOpacity = 1.0
                    updatedBoxes[i].bundleId = newFrames[i].bundleId
                } else {
                    updatedBoxes[i].targetOpacity = 0.0
                    // Retract width or height to edge
                    let current = updatedBoxes[i].currentFrame
                    let retractToRight = (current.midX > screenWidth / 2)
                    let retractToBottom = (current.midY > screenHeight / 2)
                    
                    if current.width > current.height {
                        if retractToBottom {
                            updatedBoxes[i].targetFrame = CGRect(x: current.origin.x, y: current.maxY, width: current.width, height: 0)
                        } else {
                            updatedBoxes[i].targetFrame = CGRect(x: current.origin.x, y: current.origin.y, width: current.width, height: 0)
                        }
                    } else {
                        if retractToRight {
                            updatedBoxes[i].targetFrame = CGRect(x: current.maxX, y: current.origin.y, width: 0, height: current.height)
                        } else {
                            updatedBoxes[i].targetFrame = CGRect(x: current.origin.x, y: current.origin.y, width: 0, height: current.height)
                        }
                    }
                }
            } else {
                // New window box appearing
                let new = newFrames[i].frame
                let bundleId = newFrames[i].bundleId
                let expandFromRight = (new.midX > screenWidth / 2)
                let expandFromBottom = (new.midY > screenHeight / 2)
                
                let targetLocal = CGRect(
                    x: new.origin.x - screenRectYDown.origin.x,
                    y: new.origin.y - screenRectYDown.origin.y,
                    width: new.width,
                    height: new.height
                )
                let currentLocal: CGRect
                if targetLocal.width > targetLocal.height {
                    if expandFromBottom {
                        currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.maxY, width: targetLocal.width, height: 0)
                    } else {
                        currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.origin.y, width: targetLocal.width, height: 0)
                    }
                } else {
                    if expandFromRight {
                        currentLocal = CGRect(x: targetLocal.maxX, y: targetLocal.origin.y, width: 0, height: targetLocal.height)
                    } else {
                        currentLocal = CGRect(x: targetLocal.origin.x, y: targetLocal.origin.y, width: 0, height: targetLocal.height)
                    }
                }
                
                updatedBoxes.append(BoxState(
                    currentFrame: currentLocal,
                    targetFrame: targetLocal,
                    startOpacity: 0.0,
                    targetOpacity: 1.0,
                    bundleId: bundleId
                ))
            }
        }

        model.boxes = updatedBoxes

        withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
            model.animate = true
        }

        self.alphaValue = 1.0
    }

    func fadeOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 0.0
        }, completionHandler: completion)
    }
}

private struct BoxState: Identifiable {
    let id = UUID()
    var currentFrame: CGRect
    var targetFrame: CGRect
    var startOpacity: Double
    var targetOpacity: Double
    var bundleId: String?
}

private struct SwitchOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: SwitchOverlayModel
    let viewSize: CGSize

    var body: some View {
        let theme = Config.shared.switchOverlayColor
        let isDark = theme == "dark" || (theme == "system" && colorScheme == .dark)
        let isLight = theme == "light" || (theme == "system" && colorScheme == .light)

        ZStack(alignment: .topLeading) {
            Color.clear
            
            if model.mode == "slide" {
                // Source workspace grid (slides off)
                ForEach(model.sourceBoxes) { box in
                    let xOffset = model.progress * viewSize.width
                    let opacity = 1.0 - Double(abs(model.progress))
                    
                    panel(box: box, isDark: isDark, isLight: isLight)
                        .frame(width: max(0, box.currentFrame.width), height: max(0, box.currentFrame.height))
                        .offset(x: box.currentFrame.origin.x + xOffset, y: box.currentFrame.origin.y)
                        .opacity(opacity)
                }
                
                // Target workspace grid (slides on)
                ForEach(model.targetBoxes) { box in
                    let xOffset = (model.progress - model.direction) * viewSize.width
                    let opacity = Double(abs(model.progress))
                    
                    panel(box: box, isDark: isDark, isLight: isLight)
                        .frame(width: max(0, box.currentFrame.width), height: max(0, box.currentFrame.height))
                        .offset(x: box.currentFrame.origin.x + xOffset, y: box.currentFrame.origin.y)
                        .opacity(opacity)
                }
            } else {
                // Morph mode
                ForEach(model.boxes) { box in
                    let frame = model.animate ? box.targetFrame : box.currentFrame
                    let opacity = model.animate ? box.targetOpacity : box.startOpacity
                    
                    panel(box: box, isDark: isDark, isLight: isLight)
                        .frame(width: max(0, frame.width), height: max(0, frame.height))
                        .offset(x: frame.origin.x, y: frame.origin.y)
                        .opacity(opacity)
                }
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .ignoresSafeArea()
        .onAppear {
            if model.mode == "slide" {
                if model.animate {
                    model.progress = 0.0
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                        model.progress = model.direction
                    }
                }
            } else if model.mode == "morph" && model.animate {
                model.animate = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                    model.animate = true
                }
            }
        }
    }

    private func panel(box: BoxState, isDark: Bool, isLight: Bool) -> some View {
        let fillColor = isDark ? Color.black : (isLight ? Color.white : Color.accentColor)
        let opacity = Config.shared.switchOverlayColorOpacity
        let borderColor = isDark ? Color.white.opacity(0.15) : (isLight ? Color.black.opacity(0.15) : Color.accentColor.opacity(0.25))
        
        return RoundedRectangle(cornerRadius: 12)
            .fill(fillColor.opacity(opacity))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(
                Group {
                    if Config.shared.switchOverlayShowIcons, let bundleId = box.bundleId, let nsImage = AppIconCache.shared.icon(for: bundleId) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: Config.shared.switchOverlayIconSize, height: Config.shared.switchOverlayIconSize)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                }
            )
            .applyGlassViewIfAvailable(cornerRadius: 12)
    }
}
