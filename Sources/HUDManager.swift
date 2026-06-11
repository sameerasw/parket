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

    package func show(text: String, systemImage: String, type: HUDActionType) {
        let config = Config.shared
        guard config.hudEnabled else { return }

        // Check individual controls
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

        // Cancel previous timer
        hideTimer?.invalidate()

        DispatchQueue.main.async { [self] in
            // Find active screen
            let screen = WorkspaceManager.shared.focusedMonitor.screen
            
            if hudWindow == nil {
                hudWindow = HUDWindow(screen: screen, text: text, systemImage: systemImage)
            } else {
                hudWindow?.updateContent(text: text, systemImage: systemImage)
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
    private var hostingView: NSHostingView<HUDView>?
    private var currentText: String
    private var currentSystemImage: String

    init(screen: NSScreen, text: String, systemImage: String) {
        self.currentText = text
        self.currentSystemImage = systemImage
        
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false
        self.level = .statusBar + 1
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.alphaValue = 0

        updateContentView()
        updatePosition(screen: screen)
        orderFrontRegardless()
    }

    func updateContent(text: String, systemImage: String) {
        self.currentText = text
        self.currentSystemImage = systemImage
        updateContentView()
    }

    private func updateContentView() {
        let hudView = HUDView(text: currentText, systemImage: currentSystemImage)
        if hostingView == nil {
            hostingView = NSHostingView(rootView: hudView)
            self.contentView = hostingView
        } else {
            hostingView?.rootView = hudView
        }
    }

    func updatePosition(screen: NSScreen) {
        let config = Config.shared
        let screenFrame = screen.frame
        let windowSize = CGSize(width: 300, height: 60)

        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y: CGFloat
        if config.hudPosition == "bottom" {
            y = screenFrame.origin.y + config.hudYOffset
        } else {
            y = screenFrame.origin.y + screenFrame.height - windowSize.height - config.hudYOffset
        }

        self.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: windowSize), display: true)
    }

    func fadeIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 1.0
        }
    }

    func fadeOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0.0
        }, completionHandler: completion)
    }
}

private struct HUDView: View {
    let text: String
    let systemImage: String

    var body: some View {
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
    }
}
