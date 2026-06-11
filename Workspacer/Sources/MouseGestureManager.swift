import Cocoa

package final class MouseGestureManager {
    package static let shared = MouseGestureManager()

    private var isDragging = false
    private var startingMouseX: CGFloat = 0.0
    private var hasTriggered = false
    private var lastTriggeredDirection: Int = 0
    private var hasShownHUD = false

    private init() {}

    package func startDrag(at point: CGPoint) {
        isDragging = true
        startingMouseX = point.x
        hasTriggered = false
        lastTriggeredDirection = 0
        hasShownHUD = false
    }

    package func dragged(to point: CGPoint) {
        guard isDragging else { return }
        let config = Config.shared
        
        let diffX = point.x - startingMouseX
        let sensitivity = config.mouseGestureSensitivity
        let threshold: CGFloat = 350.0 / CGFloat(sensitivity)

        if config.hudEnabled && config.hudOnWorkspaceSwitch {
            let noiseThreshold = threshold * 0.05
            if hasShownHUD || abs(diffX) >= noiseThreshold {
                let activeIndex = WorkspaceManager.shared.focusedMonitor.active
                let name = config.workspaceName(for: activeIndex)
                var progress = diffX / threshold

                if !config.workspaceLoopEnabled {
                    let count = config.workspaceCount
                    let atStart = activeIndex <= 0
                    let atEnd   = activeIndex >= count - 1
                    let maxOverscroll: CGFloat = 0.28
                    if atStart && progress > 0 {
                        let x = progress
                        progress = maxOverscroll * (x / (x + 1))
                    } else if atEnd && progress < 0 {
                        let x = -progress
                        progress = -maxOverscroll * (x / (x + 1))
                    }
                }

                DispatchQueue.main.async {
                    HUDManager.shared.show(
                        text: name,
                        systemImage: "desktopcomputer",
                        type: .workspaceSwitch,
                        isPersistent: true,
                        swipeProgress: progress,
                        isInteractive: true
                    )
                }
                hasShownHUD = true
            }
        }

        if abs(diffX) >= threshold {
            let direction = diffX < 0 ? -1 : 1
            let isOppositeDirection = (direction != lastTriggeredDirection)

            let activeIndex = WorkspaceManager.shared.focusedMonitor.active
            let count = config.workspaceCount
            let atBoundary = !config.workspaceLoopEnabled && (
                (direction < 0 && activeIndex >= count - 1) ||
                (direction > 0 && activeIndex <= 0)
            )

            if !atBoundary && (!hasTriggered || config.trackpadSwipeMultiple || isOppositeDirection) {
                playHaptic(config.trackpadSwipeHaptic)

                if direction < 0 {
                    DispatchQueue.main.async {
                        WorkspaceManager.shared.switchToNext(isPersistent: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        WorkspaceManager.shared.switchToPrev(isPersistent: true)
                    }
                }

                startingMouseX = point.x
                hasTriggered = true
                lastTriggeredDirection = direction
            }
        }
    }

    package func endDrag() {
        guard isDragging else { return }
        isDragging = false
        hasTriggered = false
        lastTriggeredDirection = 0

        let config = Config.shared
        if hasShownHUD {
            let activeIndex = WorkspaceManager.shared.focusedMonitor.active
            let name = config.workspaceName(for: activeIndex)
            DispatchQueue.main.async {
                HUDManager.shared.show(
                    text: name,
                    systemImage: "desktopcomputer",
                    type: .workspaceSwitch,
                    isPersistent: true,
                    swipeProgress: 0.0,
                    isInteractive: false
                )
                HUDManager.shared.releasePersistentHUD()
            }
        }
        hasShownHUD = false
    }

    private func playHaptic(_ typeStr: String) {
        let type = HapticType(rawValue: typeStr.lowercased()) ?? .none
        switch type {
        case .none, .noneAlt:
            break
        case .light:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .strong:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.008) {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        case .double:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }
}
