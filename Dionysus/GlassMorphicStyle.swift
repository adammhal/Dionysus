import SwiftUI

struct GlassmorphicStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassmorphicStyle() -> some View {
        self.modifier(GlassmorphicStyle())
    }
}
