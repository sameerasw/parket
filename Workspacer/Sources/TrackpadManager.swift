import Cocoa

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTReadout {
    var pos: MTPoint
    var vel: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var foo3: Int32
    var foo4: Int32
    var normalized: MTReadout
    var size: Float
    var zero1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var mm: MTReadout
    var zero2_0: Int32
    var zero2_1: Int32
    var unk2: Float
}

typealias MTDeviceCreateDefaultFunc = @convention(c) () -> UnsafeMutableRawPointer?
typealias MTDeviceCreateListFunc = @convention(c) () -> Unmanaged<CFArray>?
typealias MTDeviceStartFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
typealias MTDeviceStopFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
typealias MTRegisterContactFrameCallbackFunc = @convention(c) (
    UnsafeMutableRawPointer,
    @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32
) -> Void
typealias MTUnregisterContactFrameCallbackFunc = @convention(c) (
    UnsafeMutableRawPointer,
    @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32
) -> Void

package final class TrackpadManager {
    package static let shared = TrackpadManager()

    private var isTracking = false
    private var activeDevices: [UnsafeMutableRawPointer] = []
    
    // Loaded functions
    private var mtDeviceStop: MTDeviceStopFunc?
    private var mtUnregisterCallback: MTUnregisterContactFrameCallbackFunc?

    // Gesture tracking state
    private var sessionFingerIds: Set<Int32> = []
    private var startingAverageX: Float = 0.0
    private var hasTriggered = false
    private var lastRumbleX: Float = 0.0
    private var lastTriggeredDirection: Int = 0
    private var hasShownHUD = false

    private init() {}

    package func start() {
        guard Config.shared.trackpadSwipeEnabled else {
            fputs("workspacer: trackpad swipe support is disabled in config\n", stderr)
            return
        }
        guard !isTracking else { return }

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW) else {
            fputs("workspacer: failed to load MultitouchSupport.framework\n", stderr)
            return
        }

        guard let createList = dlsym(handle, "MTDeviceCreateList"),
              let deviceStart = dlsym(handle, "MTDeviceStart"),
              let deviceStop = dlsym(handle, "MTDeviceStop"),
              let registerCallback = dlsym(handle, "MTRegisterContactFrameCallback")
              else {
            fputs("workspacer: failed to load MultitouchSupport symbols\n", stderr)
            return
        }
        
        let mtUnregisterCallbackSym = dlsym(handle, "MTUnregisterContactFrameCallback") ?? registerCallback
        let mtDeviceCreateDefaultSym = dlsym(handle, "MTDeviceCreateDefault")

        let MTDeviceCreateList = unsafeBitCast(createList, to: MTDeviceCreateListFunc.self)
        let MTDeviceStart = unsafeBitCast(deviceStart, to: MTDeviceStartFunc.self)
        let MTRegisterContactFrameCallback = unsafeBitCast(registerCallback, to: MTRegisterContactFrameCallbackFunc.self)
        let MTDeviceCreateDefault = mtDeviceCreateDefaultSym.map { unsafeBitCast($0, to: MTDeviceCreateDefaultFunc.self) }
        
        self.mtDeviceStop = unsafeBitCast(deviceStop, to: MTDeviceStopFunc.self)
        self.mtUnregisterCallback = unsafeBitCast(mtUnregisterCallbackSym, to: MTUnregisterContactFrameCallbackFunc.self)

        var deviceCount = 0
        if let devicesUnmanaged = MTDeviceCreateList() {
            let devices = devicesUnmanaged.takeRetainedValue()
            let count = CFArrayGetCount(devices)
            fputs("workspacer: MTDeviceCreateList found \(count) devices\n", stderr)

            for i in 0..<count {
                if let deviceRaw = CFArrayGetValueAtIndex(devices, i) {
                    let device = UnsafeMutableRawPointer(mutating: deviceRaw)
                    
                    MTRegisterContactFrameCallback(device) { device, contacts, numContacts, timestamp, frame in
                        TrackpadManager.shared.handleContacts(contacts, count: numContacts)
                        return 0
                    }
                    MTDeviceStart(device, 0)
                    activeDevices.append(device)
                    deviceCount += 1
                }
            }
        } else {
            fputs("workspacer: MTDeviceCreateList returned nil\n", stderr)
        }

        if deviceCount == 0, let createDefault = MTDeviceCreateDefault, let defaultDevice = createDefault() {
            fputs("workspacer: using MTDeviceCreateDefault fallback\n", stderr)
            MTRegisterContactFrameCallback(defaultDevice) { device, contacts, numContacts, timestamp, frame in
                TrackpadManager.shared.handleContacts(contacts, count: numContacts)
                return 0
            }
            MTDeviceStart(defaultDevice, 0)
            activeDevices.append(defaultDevice)
            deviceCount += 1
        }
        
        if deviceCount > 0 {
            isTracking = true
            fputs("workspacer: trackpad swipe gesture monitoring started on \(deviceCount) devices\n", stderr)
        } else {
            fputs("workspacer: no multitouch devices registered\n", stderr)
        }
    }

    package func stop() {
        guard isTracking else { return }
        
        for device in activeDevices {
            // Note: We don't call mtUnregisterCallback and mtDeviceStop sequentially in the same block if it causes crashes,
            // but normally we can just call stop on device.
            if let stopFunc = mtDeviceStop {
                stopFunc(device)
            }
        }
        activeDevices.removeAll()
        isTracking = false
        sessionFingerIds.removeAll()
        hasTriggered = false
        fputs("workspacer: trackpad swipe gesture monitoring stopped\n", stderr)
    }

    package func reload() {
        stop()
        if Config.shared.trackpadSwipeEnabled {
            start()
        }
    }

    private func handleContacts(_ contactsPtr: UnsafeRawPointer?, count: Int32) {
        guard let contacts = contactsPtr?.assumingMemoryBound(to: MTTouch.self) else { return }
        let config = Config.shared
        guard config.trackpadSwipeEnabled else { return }

        let targetFingers = config.trackpadSwipeFingers

        // Filter and map active touches
        var currentFingers: [Int32: Float] = [:]
        for i in 0..<Int(count) {
            let contact = contacts[i]
            // state: 4 is touching, 3 is making, 5 is breaking, 7 is leaving
            // Ignore breaking or leaving touches to avoid false triggers
            if contact.state != 5 && contact.state != 7 {
                currentFingers[contact.identifier] = contact.normalized.pos.x
            }
        }

        let activeCount = currentFingers.count

        if activeCount == targetFingers {
            let currentIds = Set(currentFingers.keys)
            let avgX = currentFingers.values.reduce(0, +) / Float(activeCount)

            if sessionFingerIds.isEmpty {
                // Initialize swipe session
                sessionFingerIds = currentIds
                startingAverageX = avgX
                hasTriggered = false
                lastRumbleX = avgX
                lastTriggeredDirection = 0
                hasShownHUD = false
            } else if currentIds == sessionFingerIds {
                // Ongoing swipe gesture
                let diff = avgX - startingAverageX
                let baseThreshold: Float = 0.15
                let threshold = baseThreshold / Float(config.trackpadSwipeSensitivity)

                let noiseThreshold = threshold * 0.05
                if abs(diff) >= noiseThreshold {
                    let focusedMonitor = WorkspaceManager.shared.focusedMonitor
                    let currentProgress = CGFloat(abs(diff) / threshold)
                    SwitchOverlayManager.shared.updateInteractiveProgress(
                        currentProgress,
                        on: focusedMonitor.screen,
                        oldFrames: focusedMonitor.captureWindowFrames()
                    )
                }

                // Show HUD overlay persistently as soon as swipe movement starts and update its position
                if config.hudEnabled && config.hudOnWorkspaceSwitch {
                    let noiseThreshold = threshold * 0.05
                    if hasShownHUD || abs(diff) >= noiseThreshold {
                        let activeIndex = WorkspaceManager.shared.focusedMonitor.active
                        let name = config.workspaceName(for: activeIndex)
                        var progress = CGFloat(diff / threshold)

                        // Rubber-band at boundaries: asymptotic formula so it drifts a little
                        // but smoothly resists further movement without ever jumping back
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
                            HUDManager.shared.show(text: name, systemImage: "desktopcomputer", type: .workspaceSwitch, isPersistent: true, swipeProgress: progress, isInteractive: true)
                        }
                        hasShownHUD = true
                    }
                }

                // Subtle haptic rumble triggered based strictly on finger travel distance (displacement)
                if config.trackpadSwipeRumble && !hasTriggered {
                    let displacement = abs(avgX - lastRumbleX)
                    let rumbleStep: Float = 0.015
                    if displacement >= rumbleStep {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        lastRumbleX = avgX
                    }
                }

                if abs(diff) >= threshold {
                    let direction = diff < 0 ? -1 : 1
                    let isOppositeDirection = (direction != lastTriggeredDirection)

                    // Check boundary: if loop is off and we're already at the edge, skip entirely
                    let activeIndex = WorkspaceManager.shared.focusedMonitor.active
                    let count = config.workspaceCount
                    let atBoundary = !config.workspaceLoopEnabled && (
                        (direction < 0 && activeIndex >= count - 1) ||
                        (direction > 0 && activeIndex <= 0)
                    )

                    if !atBoundary && (!hasTriggered || config.trackpadSwipeMultiple || isOppositeDirection) {
                        // Play main haptic feedback immediately
                        self.playHaptic(config.trackpadSwipeHaptic)

                        if direction < 0 {
                            // Swipe left (fingers move left) -> switch next
                            DispatchQueue.main.async {
                                WorkspaceManager.shared.switchToNext(isPersistent: true)
                            }
                        } else {
                            // Swipe right (fingers move right) -> switch prev
                            DispatchQueue.main.async {
                                WorkspaceManager.shared.switchToPrev(isPersistent: true)
                            }
                        }

                        // Reset session baseline relative to this trigger point
                        startingAverageX = avgX
                        lastRumbleX = avgX
                        hasTriggered = true
                        lastTriggeredDirection = direction
                    }
                }
            } else {
                // Finger IDs changed, reset starting point
                sessionFingerIds = currentIds
                startingAverageX = avgX
                hasTriggered = false
                lastRumbleX = avgX
                lastTriggeredDirection = 0
                hasShownHUD = false
            }
        } else {
            // Finger count doesn't match target, reset session if all fingers lifted
            if activeCount == 0 {
                sessionFingerIds.removeAll()
                hasTriggered = false
                lastRumbleX = 0.0
                lastTriggeredDirection = 0
                
                SwitchOverlayManager.shared.cancelInteractive()
                
                if hasShownHUD {
                    let activeIndex = WorkspaceManager.shared.focusedMonitor.active
                    let name = config.workspaceName(for: activeIndex)
                    DispatchQueue.main.async {
                        HUDManager.shared.show(text: name, systemImage: "desktopcomputer", type: .workspaceSwitch, isPersistent: true, swipeProgress: 0.0, isInteractive: false)
                        HUDManager.shared.releasePersistentHUD()
                    }
                }
                hasShownHUD = false
            }
        }
    }

    private func playHaptic(_ typeStr: String) {
        let type = HapticType(rawValue: typeStr.lowercased()) ?? .none
        switch type {
        case .none, .noneAlt:
            break
        case .light:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .strong:
            // Stack two levelChange pulses 8ms apart so they fuse into one single, heavy tap
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

enum HapticType: String {
    case none = "non"
    case noneAlt = "none"
    case light
    case double
    case strong
}
