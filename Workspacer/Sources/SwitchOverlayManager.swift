import Cocoa
import SwiftUI
public import Combine

package final class SwitchOverlayManager {
    package static let shared = SwitchOverlayManager()

    private var overlayWindow: SwitchOverlayWindow?
    private var fadeOutTimer: Timer?

    private init() {}

    package func updateInteractiveProgress(_ progress: CGFloat, on screen: NSScreen, oldFrames: [CGRect]) {
        guard Config.shared.switchOverlayEnabled else { return }
        guard oldFrames.count >= 1 else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = self.overlayWindow {
                if !window.isCommitted {
                    window.alphaValue = min(1.0, progress)
                }
            } else {
                let window = SwitchOverlayWindow(screen: screen, oldFrames: oldFrames, to: oldFrames, isInteractive: true)
                self.overlayWindow = window
                window.alphaValue = min(1.0, progress)
            }
        }
    }

    package func cancelInteractive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let window = self.overlayWindow {
                if !window.isCommitted {
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

    package func show(from oldFrames: [CGRect], to newFrames: [CGRect], on screen: NSScreen) {
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
                let window = SwitchOverlayWindow(screen: screen, oldFrames: oldFrames, to: newFrames, isInteractive: false)
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
}

private final class SwitchOverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let model: SwitchOverlayModel
    var isCommitted: Bool

    init(screen: NSScreen, oldFrames: [CGRect], to newFrames: [CGRect], isInteractive: Bool) {
        self.targetScreen = screen
        self.model = SwitchOverlayModel()
        self.isCommitted = !isInteractive

        let screenFrame = screen.frame
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false
        self.level = .statusBar // below HUD (.statusBar + 1) but above everything else
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
        let screenWidth = screenRectYDown.width
        let screenHeight = screenRectYDown.height
        
        var boxes: [BoxState] = []
        let maxCount = max(oldFrames.count, newFrames.count)
        
        for i in 0..<maxCount {
            if i < oldFrames.count && i < newFrames.count {
                let old = oldFrames[i]
                let new = newFrames[i]
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
                    targetOpacity: 1.0
                ))
            } else if i < oldFrames.count {
                let old = oldFrames[i]
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
                    targetOpacity: 0.0
                ))
            } else {
                let new = newFrames[i]
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
                    targetOpacity: 1.0
                ))
            }
        }

        self.model.boxes = boxes
        self.model.animate = !isInteractive

        let viewSize = screenRectYDown.size
        let overlayView = SwitchOverlayView(model: model, viewSize: viewSize)
        self.contentView = NSHostingView(rootView: AnyView(overlayView))
        
        self.orderFrontRegardless()
    }

    func fadeIn() {
        self.alphaValue = 1.0
    }

    func commit(to newFrames: [CGRect]) {
        guard !isCommitted else { return }
        isCommitted = true

        let screenRectYDown = WindowManager.screenRect(for: self.targetScreen)
        let screenWidth = screenRectYDown.width
        let screenHeight = screenRectYDown.height
        var updatedBoxes = model.boxes

        let maxCount = max(updatedBoxes.count, newFrames.count)

        for i in 0..<maxCount {
            if i < updatedBoxes.count {
                if i < newFrames.count {
                    let new = newFrames[i]
                    updatedBoxes[i].targetFrame = CGRect(
                        x: new.origin.x - screenRectYDown.origin.x,
                        y: new.origin.y - screenRectYDown.origin.y,
                        width: new.width,
                        height: new.height
                    )
                    updatedBoxes[i].targetOpacity = 1.0
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
                let new = newFrames[i]
                let targetLocal = CGRect(
                    x: new.origin.x - screenRectYDown.origin.x,
                    y: new.origin.y - screenRectYDown.origin.y,
                    width: new.width,
                    height: new.height
                )
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
                
                updatedBoxes.append(BoxState(
                    currentFrame: currentLocal,
                    targetFrame: targetLocal,
                    startOpacity: 0.0,
                    targetOpacity: 1.0
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
}

private struct SwitchOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: SwitchOverlayModel
    let viewSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            
            ForEach(model.boxes) { box in
                let frame = model.animate ? box.targetFrame : box.currentFrame
                let opacity = model.animate ? box.targetOpacity : box.startOpacity
                
                let theme = Config.shared.switchOverlayColor
                let isDark = theme == "dark" || (theme == "system" && colorScheme == .dark)
                let isLight = theme == "light" || (theme == "system" && colorScheme == .light)
                
                let fillColor = isDark ? Color.black.opacity(0.3) : (isLight ? Color.white.opacity(0.3) : Color.accentColor.opacity(0.15))
                let borderColor = isDark ? Color.white.opacity(0.15) : (isLight ? Color.black.opacity(0.15) : Color.accentColor.opacity(0.25))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .applyGlassViewIfAvailable(cornerRadius: 12)
                    .frame(width: max(0, frame.width), height: max(0, frame.height))
                    .offset(x: frame.origin.x, y: frame.origin.y)
                    .opacity(opacity)
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .ignoresSafeArea()
        .onAppear {
            if model.animate {
                model.animate = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                    model.animate = true
                }
            }
        }
    }
}
