//
//  View+Ext.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import SwiftUI

extension View {
    func simulateTextHeight(_ font: Font) -> some View {
        Text("|")
          .font(font)
          .opacity(0)
          .background(self)
    }
}

extension View {
    @ViewBuilder
    func clipRoundedRectangleWithBorder(_ cornerRadius: CGFloat = 20, borderColor: Color) -> some View {
        self
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }

    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct InteractiveScaleButtonStyle: PrimitiveButtonStyle {
    let scale: CGFloat = 0.95
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle = .light

    @State private var isPressed = false
    @State var frame: CGRect?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
                    .onEnded { value in
                        isPressed = false
                        configuration.trigger()
                    }
            )
    }
}

extension PrimitiveButtonStyle where Self == InteractiveScaleButtonStyle {
    static var interactiveScale: InteractiveScaleButtonStyle { InteractiveScaleButtonStyle() }
}
