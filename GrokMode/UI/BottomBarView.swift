//
//  BottomBarView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct BottomBarView: View {
    @State private var animator = WaveformAnimator()
    @State private var isListening = false
    @Namespace private var morphNamespace

    var body: some View {
        HStack {
            stopButton
        }
    }

    private var stopButton: some View {
        Button {
            withAnimation {
                isListening = false
                animator.stopAnimating()
            }
        } label: {
            Image(systemName: "stop.fill")
                .foregroundStyle(.white)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
        }
    }
}

#Preview {
    NavigationStack {
        ZStack {
            VStack {
                Text("Content Area")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                BottomBarView()
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        .toolbarBackgroundVisibility(.visible, for: .bottomBar)
    }
}
