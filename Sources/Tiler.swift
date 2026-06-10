import Foundation

package enum Layout {
    case tile
    case monocle
}

package enum Tiler {
    package static func calculateFrames(
        count: Int,
        screen: CGRect,
        layout: Layout,
        masterRatio: CGFloat = Config.shared.masterRatio,
        stackRatios: [CGFloat] = []
    ) -> [CGRect] {
        guard count > 0 else { return [] }
        switch layout {
        case .tile:
            return tileFrames(count: count, screen: screen, masterRatio: masterRatio, stackRatios: stackRatios)
        case .monocle:
            return monocleFrames(count: count, screen: screen)
        }
    }

    static func tile(
        windows: [TrackedWindow],
        screen: CGRect,
        layout: Layout,
        masterRatio: CGFloat = Config.shared.masterRatio,
        stackRatios: [CGFloat] = []
    ) {
        let frames = calculateFrames(
            count: windows.count,
            screen: screen,
            layout: layout,
            masterRatio: masterRatio,
            stackRatios: stackRatios
        )
        for (i, frame) in frames.enumerated() {
            windows[i].setFrame(frame)
        }
    }

    private static func tileFrames(
        count: Int,
        screen: CGRect,
        masterRatio: CGFloat,
        stackRatios: [CGFloat]
    ) -> [CGRect] {
        if count == 1 {
            return [screen]
        }

        var result: [CGRect] = []
        result.reserveCapacity(count)
        let masterWidth = floor(screen.width * masterRatio)
        result.append(CGRect(
            x: screen.origin.x, y: screen.origin.y,
            width: masterWidth, height: screen.height
        ))

        let stackCount = count - 1
        let stackWidth = screen.width - masterWidth

        var resolvedRatios = stackRatios
        if resolvedRatios.count != stackCount {
            resolvedRatios = Array(repeating: 1.0 / CGFloat(stackCount), count: stackCount)
        } else {
            let sum = resolvedRatios.reduce(0, +)
            if sum > 0 {
                resolvedRatios = resolvedRatios.map { $0 / sum }
            } else {
                resolvedRatios = Array(repeating: 1.0 / CGFloat(stackCount), count: stackCount)
            }
        }

        var currentY = screen.origin.y
        for i in 0..<stackCount {
            let h = floor(screen.height * resolvedRatios[i])
            let actualH = (i == stackCount - 1) ? (screen.origin.y + screen.height - currentY) : h
            result.append(CGRect(
                x: screen.origin.x + masterWidth,
                y: currentY,
                width: stackWidth,
                height: actualH
            ))
            currentY += actualH
        }
        return result
    }

    private static func monocleFrames(count: Int, screen: CGRect) -> [CGRect] {
        Array(repeating: screen, count: count)
    }
}
