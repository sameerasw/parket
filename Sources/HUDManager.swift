import AppKit
import SwiftUI

package enum HUDActionType {
    case workspaceSwitch
    case layoutSwitch
    case configReload
    case other
}

package final class HUDManager {
    package static let shared = HUDManager()

    private var hudWindow: HUDWindow?
    private var hideTimer: Timer?

    private init() {}

    package func show(text: String, systemImage: String, type: HUDActionType, slideOffset: CGFloat = 0) {
        let config = Config.shared
        guard config.hudEnabled else { return }

        switch type {
        case .workspaceSwitch:
            guard config.hudOnWorkspaceSwitch else { return }
        case .layoutSwitch:
            guard config.hudOnLayoutSwitch else { return }
        case .configReload:
            guard config.hudOnConfigReload else { return }
        case .other:
            break
        }

        hideTimer?.invalidate()

        DispatchQueue.main.async { [self] in
            let screen = WorkspaceManager.shared.focusedMonitor.screen
            
            if hudWindow == nil {
                hudWindow = HUDWindow(screen: screen, text: text, systemImage: systemImage, slideOffset: slideOffset)
            } else {
                hudWindow?.updateContent(text: text, systemImage: systemImage, slideOffset: slideOffset)
                hudWindow?.updatePosition(screen: screen)
            }

            hudWindow?.fadeIn()

            hideTimer = Timer.scheduledTimer(withTimeInterval: config.hudDuration, repeats: false) { [weak self] _ in
                self?.hudWindow?.fadeOut {
                    self?.hudWindow?.close()
                    self?.hudWindow = nil
                }
            }
        }
    }
}

private final class HUDWindow: NSWindow {
    private var hostingView: NSHostingView<AnyView>?
    private var currentText: String
    private var currentSystemImage: String
    private var currentSlideOffset: CGFloat

    init(screen: NSScreen, text: String, systemImage: String, slideOffset: CGFloat) {
        self.currentText = text
        self.currentSystemImage = systemImage
        self.currentSlideOffset = slideOffset
        
        let config = Config.shared
        let screenFrame = screen.frame
        let windowSize = CGSize(width: 800, height: 100)
        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y: CGFloat
        if config.hudPosition == "bottom" {
            y = screenFrame.origin.y + config.hudYOffset - 20
        } else {
            y = screenFrame.origin.y + screenFrame.height - windowSize.height - config.hudYOffset + 20
        }
        let frame = CGRect(origin: CGPoint(x: x, y: y), size: windowSize)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false
        self.level = .statusBar + 1
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.alphaValue = 0

        updateContentView()
        orderFrontRegardless()
    }

    func updateContent(text: String, systemImage: String, slideOffset: CGFloat) {
        self.currentText = text
        self.currentSystemImage = systemImage
        self.currentSlideOffset = slideOffset
        updateContentView()
    }

    private func updateContentView() {
        let hudView = HUDView(text: currentText, systemImage: currentSystemImage, slideOffset: currentSlideOffset)
            .id(UUID())
        let anyView = AnyView(hudView)
        if hostingView == nil {
            hostingView = NSHostingView(rootView: anyView)
            self.contentView = hostingView
        } else {
            hostingView?.rootView = anyView
        }
    }

    func updatePosition(screen: NSScreen) {
        let config = Config.shared
        let screenFrame = screen.frame
        let windowSize = CGSize(width: 800, height: 100)

        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y: CGFloat
        if config.hudPosition == "bottom" {
            y = screenFrame.origin.y + config.hudYOffset - 20
        } else {
            y = screenFrame.origin.y + screenFrame.height - windowSize.height - config.hudYOffset + 20
        }

        self.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: windowSize), display: true)
    }

    func fadeIn() {
        self.alphaValue = 1.0
    }

    func fadeOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0.0
        }, completionHandler: completion)
    }
}

private struct HUDView: View {
    let text: String
    let systemImage: String
    let slideOffset: CGFloat
    @State private var animOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(width: 300, height: 60)
            .applyGlassViewIfAvailable(cornerRadius: 24)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            .scaleEffect(scale)
            .offset(x: animOffset)
            .opacity(opacity)
        }
        .frame(width: 800, height: 100)
        .onAppear {
            if slideOffset != 0 {
                animOffset = slideOffset
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    animOffset = 0
                    opacity = 1.0
                }
            } else {
                animOffset = 0
                scale = 1.0
                withAnimation(.easeOut(duration: 0.12)) {
                    opacity = 1.0
                }
            }
        }
    }
}
