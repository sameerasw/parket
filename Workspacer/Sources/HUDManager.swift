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
    private var isPersistent = false

    private init() {}

    package func show(text: String, systemImage: String, type: HUDActionType, slideOffset: CGFloat = 0, isOn: Bool? = nil, isPersistent: Bool = false, swipeProgress: CGFloat = 0, isInteractive: Bool = false) {
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
        self.isPersistent = isPersistent

        DispatchQueue.main.async { [self] in
            let screen = WorkspaceManager.shared.focusedMonitor.screen
            
            if hudWindow == nil {
                hudWindow = HUDWindow(screen: screen, text: text, systemImage: systemImage, slideOffset: slideOffset, isOn: isOn, type: type, swipeProgress: swipeProgress, isInteractive: isInteractive)
            } else {
                hudWindow?.updateContent(text: text, systemImage: systemImage, slideOffset: slideOffset, isOn: isOn, type: type, swipeProgress: swipeProgress, isInteractive: isInteractive)
                hudWindow?.updatePosition(screen: screen)
            }

            hudWindow?.fadeIn()

            if !isPersistent {
                hideTimer = Timer.scheduledTimer(withTimeInterval: config.hudDuration, repeats: false) { [weak self] _ in
                    self?.hudWindow?.fadeOut {
                        self?.hudWindow?.close()
                        self?.hudWindow = nil
                    }
                }
            }
        }
    }

    package func releasePersistentHUD() {
        guard isPersistent else { return }
        isPersistent = false

        let config = Config.shared
        hideTimer?.invalidate()

        DispatchQueue.main.async { [self] in
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
    private var currentIsOn: Bool?
    private var currentType: HUDActionType
    private var currentSwipeProgress: CGFloat
    private var currentIsInteractive: Bool
    private var isFadingIn = false

    init(screen: NSScreen, text: String, systemImage: String, slideOffset: CGFloat, isOn: Bool?, type: HUDActionType, swipeProgress: CGFloat, isInteractive: Bool) {
        self.currentText = text
        self.currentSystemImage = systemImage
        self.currentSlideOffset = slideOffset
        self.currentIsOn = isOn
        self.currentType = type
        self.currentSwipeProgress = swipeProgress
        self.currentIsInteractive = isInteractive
        
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

    func updateContent(text: String, systemImage: String, slideOffset: CGFloat, isOn: Bool?, type: HUDActionType, swipeProgress: CGFloat, isInteractive: Bool) {
        self.currentText = text
        self.currentSystemImage = systemImage
        self.currentSlideOffset = slideOffset
        self.currentIsOn = isOn
        self.currentType = type
        self.currentSwipeProgress = swipeProgress
        self.currentIsInteractive = isInteractive
        updateContentView()
    }

    private func updateContentView() {
        let activeIndex = WorkspaceManager.shared.focusedMonitor.active
        let count = Config.shared.workspaceCount
        var names: [String] = []
        for i in 0..<count {
            names.append(Config.shared.workspaceName(for: i))
        }

        let hudView = HUDView(
            type: currentType,
            text: currentText,
            systemImage: currentSystemImage,
            slideOffset: currentSlideOffset,
            isOn: currentIsOn,
            activeIndex: activeIndex,
            workspaceNames: names,
            swipeProgress: currentSwipeProgress,
            isInteractive: currentIsInteractive
        )
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
        guard !isFadingIn && self.alphaValue < 1.0 else { return }
        isFadingIn = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            self?.isFadingIn = false
        })
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
    let type: HUDActionType
    let text: String
    let systemImage: String
    let slideOffset: CGFloat
    let isOn: Bool?
    
    // For workspace switch picker view
    let activeIndex: Int
    let workspaceNames: [String]
    let swipeProgress: CGFloat
    let isInteractive: Bool
    
    @Namespace private var namespace

    var body: some View {
        ZStack {
            if type == .workspaceSwitch {
                let itemWidth: CGFloat = 90
                let count = workspaceNames.count
                
                // Keep highlighted index strictly to the active workspace index so it doesn't prematurely switch
                let highlightedIndex = activeIndex
                
                // Determine targetIndex (next workspace in swipe direction)
                let targetIndex = swipeProgress < 0 ? activeIndex + 1 : activeIndex - 1
                
                // Offset shifts workspace list based on current active workspace + swipe progress
                let totalOffset = ((CGFloat(count) - 1.0) / 2.0 - CGFloat(activeIndex) + swipeProgress) * itemWidth

                ZStack {
                    ZStack {
                        HStack(spacing: 0) {
                            ForEach(0..<count, id: \.self) { index in
                                let isActive = (index == highlightedIndex)
                                let isTarget = (index == targetIndex)
                                let progressToTarget = isTarget ? min(1.0, max(0.0, abs(swipeProgress))) : 0.0
                                
                                Group {
                                    if isActive {
                                        Text(workspaceNames[index])
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(width: itemWidth - 10, height: 36)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.accentColor)
                                                    .matchedGeometryEffect(id: "activePill", in: namespace)
                                            )
                                            .applyGlassViewIfAvailable(cornerRadius: 24)
                                            .scaleEffect(1.1)
                                    } else {
                                        ZStack {
                                            Text(workspaceNames[index])
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.primary.opacity(0.65))
                                                .opacity(1.0 - Double(progressToTarget))
                                            
                                            Text(workspaceNames[index])
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
//                                                .foregroundColor(Color.accentColor.opacity(0.95))
                                                .opacity(Double(progressToTarget))
                                        }
                                        .frame(width: itemWidth - 10, height: 36)
                                        .background(
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.primary.opacity(0.04))
                                                
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.accentColor.opacity(0.2 * Double(progressToTarget)))
                                            }
                                        )

                                          .applyGlassViewIfAvailable(cornerRadius: 24)
                                        .scaleEffect(1.0 + 0.03 * progressToTarget)
                                    }
                                }
                                .frame(width: itemWidth) // Keeps fixed item slots
                            }
                        }
                        .offset(x: totalOffset)
                        .frame(width: itemWidth * CGFloat(count))
                        .animation(isInteractive ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: totalOffset)
                    }
                    .frame(width: 320, height: 50)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.2),
                                .init(color: .black, location: 0.8),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .frame(width: 320, height: 50)
                .applyGlassViewIfAvailable(cornerRadius: 24)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                    
                    Text(text)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    if let isOn = isOn {
                        Toggle("", isOn: SwiftUI.Binding.constant(isOn))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .applyGlassViewIfAvailable(cornerRadius: 24)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            }
        }
        .frame(width: 800, height: 100)
    }
}
