//
//  Snapshot.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/1/26.
//

import SwiftUI
import UIKit

/// https://medium.com/@justdoswift/a-better-way-to-snapshot-swiftui-views-yes-uikit-is-involved-7b2be6f66eba

extension View {
    @ViewBuilder
    func snapshot(trigger: Binding<Bool>, onComplete: @escaping (UIImage) -> ()) -> some View {
        self
            .modifier(SnapshotModifier(trigger: trigger, onComplete: onComplete))
    }
}

fileprivate struct ViewExtractor: UIViewRepresentable {
    var view: UIView
    func makeUIView(context: Context) -> UIView {
        view.backgroundColor = .clear
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        // no process
    }
}

fileprivate struct SnapshotModifier: ViewModifier {
    @Binding var trigger: Bool
    var onComplete: (UIImage) -> ()
    @State private var view: UIView = .init(frame: .zero)
    func body(content: Content) -> some View {
        content
            .background(ViewExtractor(view: view))
            .compositingGroup()
            .onChange(of: trigger) { oldValue, newValue in
                guard trigger else { return }
                generateSnapshot()
                trigger = false
            }
    }
    private func generateSnapshot() {
        if let superView = view.superview {
            let render = UIGraphicsImageRenderer(size: superView.bounds.size)
            let image = render.image { _ in
                superView.drawHierarchy(in: superView.bounds, afterScreenUpdates: true)
            }
            onComplete(image)
        }
    }
}

extension View {
    func takeSnapshot() -> UIImage {
        let controller = UIHostingController(rootView: self.fixedSize(horizontal: false, vertical: true))
        guard let view = controller.view else { return .init() }

        // Calculate the target size based on the intrinsic content size of the view
        let targetSize = controller.sizeThatFits(in: .init(width: view.intrinsicContentSize.width, height: .greatestFiniteMagnitude))
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let image = renderer.image { render in
            view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        return image
    }
}

struct SnapshotShakeListener: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
                UIImageWriteToSavedPhotosAlbum(content.takeSnapshot(), nil, nil, nil)
            }
    }
}

extension View {
    func saveToPhotosOnShake() -> some View {
        self.modifier(SnapshotShakeListener())
    }
}
