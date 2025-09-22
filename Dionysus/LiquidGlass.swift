import SwiftUI

struct LiquidGlassViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }
}

extension View {
    func liquidGlass() -> some View {
        self.modifier(LiquidGlassViewModifier())
    }
}
