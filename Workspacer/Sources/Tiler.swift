import Foundation
import CoreGraphics

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
        let padding = Config.shared.padding
        let gap = Config.shared.gap

        let insetScreen = CGRect(
            x: screen.origin.x + padding,
            y: screen.origin.y + padding,
            width: max(screen.width - 2 * padding, 0),
            height: max(screen.height - 2 * padding, 0)
        )

        if count == 1 {
            if Config.shared.noPaddingForSingleWindow {
                return [screen]
            } else {
                return [insetScreen]
            }
        }

        var result: [CGRect] = []
        result.reserveCapacity(count)

        let availableWidth = max(insetScreen.width - gap, 0)
        let masterWidth = floor(availableWidth * masterRatio)
        result.append(CGRect(
            x: insetScreen.origin.x,
            y: insetScreen.origin.y,
            width: masterWidth,
            height: insetScreen.height
        ))

        let stackCount = count - 1
        let stackWidth = max(availableWidth - masterWidth, 0)

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

        let totalVerticalGaps = CGFloat(stackCount - 1) * gap
        let availableHeight = max(insetScreen.height - totalVerticalGaps, 0)

        var currentY = insetScreen.origin.y
        for i in 0..<stackCount {
            let h = floor(availableHeight * resolvedRatios[i])
            let actualH = (i == stackCount - 1) ? (insetScreen.origin.y + insetScreen.height - currentY) : h
            result.append(CGRect(
                x: insetScreen.origin.x + masterWidth + gap,
                y: currentY,
                width: stackWidth,
                height: actualH
            ))
            currentY += actualH + gap
        }
        return result
    }

    private static func monocleFrames(count: Int, screen: CGRect) -> [CGRect] {
        Array(repeating: screen, count: count)
    }
}
