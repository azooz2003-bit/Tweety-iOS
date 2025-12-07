//
//  SimpleConnectorExample.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI

struct SimpleConnectorExample: View {
    var body: some View {
        ZStack {
            // Parent box at top-left
            Rectangle()
                .fill(Color.blue)
                .frame(width: 200, height: 100)
                .position(x: 150, y: 100)

            // Child box at bottom-right
            Rectangle()
                .fill(Color.green)
                .frame(width: 200, height: 100)
                .position(x: 350, y: 300)

            // Path connecting bottom of parent to leading edge of child
            Path { path in
                // Start at bottom center of parent box
                let startX: CGFloat = 150
                let startY: CGFloat = 150  // 100 (y position) + 50 (half height)

                // End at leading edge (left center) of child box
                let endX: CGFloat = 250  // 350 (x position) - 100 (half width)
                let endY: CGFloat = 300

                path.move(to: CGPoint(x: startX, y: startY))

                // Go down
                path.addLine(to: CGPoint(x: startX, y: startY + 50))

                // Go right
                path.addLine(to: CGPoint(x: endX, y: startY + 50))

                // Go down to child
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color.cyan, lineWidth: 2)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SimpleConnectorExample()
    }
}
