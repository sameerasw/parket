import AppKit
import SwiftUI

package final class CornerMaskManager {
    package static let shared = CornerMaskManager()

    private var windows: [NSWindow] = []

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    package func configure() {
        setupWindows()
    }

    @objc private func handleScreenParametersChange() {
        setupWindows()
    }

    private func setupWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()

        let config = Config.shared
        guard config.enableCorners, config.cornerRadius > 0 else { return }

        for screen in NSScreen.screens {
            let window = CornerMaskWindow(screen: screen, radius: config.cornerRadius)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

private final class CornerMaskWindow: NSWindow {
    init(screen: NSScreen, radius: CGFloat) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.level = .mainMenu + 1
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        updateContentView(radius: radius)
    }
    
    private func updateContentView(radius: CGFloat) {
        let maskView = CornerMaskOverlayView(radius: radius)
        let hostingView = NSHostingView(rootView: maskView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        self.contentView = hostingView
    }
}

private struct CornerMaskOverlayView: View {
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            if radius > 0 {
                Color.clear
                    .overlay(
                        ZStack {
                            cornerShape(position: .topLeft)
                            cornerShape(position: .topRight)
                            cornerShape(position: .bottomLeft)
                            cornerShape(position: .bottomRight)
                        }
                    )
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func cornerShape(position: CornerPosition) -> some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: radius, y: 0))
                path.addArc(
                    center: CGPoint(x: radius, y: radius),
                    radius: radius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(180),
                    clockwise: true
                )
                path.addLine(to: .zero)
                path.closeSubpath()
            }
            .fill(Color.black)
            .frame(width: radius, height: radius)
            .rotationEffect(position.rotation)
            .position(position.offset(in: geo.size, radius: radius))
        }
    }
    
    enum CornerPosition {
        case topLeft, topRight, bottomLeft, bottomRight
        
        var rotation: Angle {
            switch self {
            case .topLeft: return .degrees(0)
            case .topRight: return .degrees(90)
            case .bottomRight: return .degrees(180)
            case .bottomLeft: return .degrees(270)
            }
        }
        
        func offset(in size: CGSize, radius: CGFloat) -> CGPoint {
            let r = radius / 2
            switch self {
            case .topLeft: return CGPoint(x: r, y: r)
            case .topRight: return CGPoint(x: size.width - r, y: r)
            case .bottomLeft: return CGPoint(x: r, y: size.height - r)
            case .bottomRight: return CGPoint(x: size.width - r, y: size.height - r)
            }
        }
    }
}
