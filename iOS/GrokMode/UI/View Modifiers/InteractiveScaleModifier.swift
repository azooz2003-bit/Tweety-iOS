//
//  InteractiveScaleModifier.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct InteractiveScaleModifier: ViewModifier {
    let scale: CGFloat
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            let generator = UIImpactFeedbackGenerator(style: hapticFeedback)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func interactiveScale(
        scale: CGFloat = 0.95,
        hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some View {
        self.modifier(InteractiveScaleModifier(scale: scale, hapticFeedback: hapticFeedback))
    }
}
