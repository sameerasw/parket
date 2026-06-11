import SwiftUI

package struct UIStyle {
    package static var pretendOlderOS: Bool = false
}

package struct GlassBoxView: View {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var maxWidth: CGFloat? = nil
    var maxHeight: CGFloat? = nil
    var radius: CGFloat = 16.0

    package init(width: CGFloat? = nil, height: CGFloat? = nil, maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, radius: CGFloat = 16.0) {
        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.radius = radius
    }

    package var body: some View {
        if !UIStyle.pretendOlderOS, #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .frame(width: width, height: height)
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                .glassBoxIfAvailable(radius: radius)
                .cornerRadius(radius)
        } else {
            Rectangle()
                .fill(.gray.opacity(0.2))
                .frame(width: width, height: height)
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                .cornerRadius(radius)
                .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    GlassBoxView(width: 100, height: 100)
}

extension View {
    @ViewBuilder
    package func glassBoxIfAvailable(radius: CGFloat) -> some View {
        if !UIStyle.pretendOlderOS, #available(macOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: radius))
        } else {
            self.background(.thinMaterial, in: .rect(cornerRadius: radius))
        }
    }
}

extension View {
    @ViewBuilder
    package func applyGlassViewIfAvailable(cornerRadius: CGFloat = 20) -> some View {
        if !UIStyle.pretendOlderOS, #available(macOS 26.0, *) {
            self.background(.clear)
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    package func segmentStyle(cornerRadius: CGFloat = 20) -> some View {
        self.applyGlassViewIfAvailable(cornerRadius: cornerRadius)
            .contentShape(Rectangle())
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    package func staggeredEntrance(index: Int, isVisible: Bool) -> some View {
        self.zIndex(Double(10 - index))
            .offset(y: isVisible ? 0 : -12)
            .opacity(isVisible ? 1 : 0)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 14)
                .delay(Double(index) * 0.05 + 0.05),
                value: isVisible
            )
    }
}
