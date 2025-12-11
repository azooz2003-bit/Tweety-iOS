//
//  ToolConfirmationSheet.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import SwiftUI

struct ToolConfirmationSheet: View {
    let toolCall: PendingToolCall
    let onApprove: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview Action")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Grok needs your confirmation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)

            Divider()
                .background(.white.opacity(0.2))

            // Tool Details
            VStack(alignment: .leading, spacing: 8) {
                Text(toolCall.previewTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(toolCall.previewContent)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

                Button {
                    onApprove()
                    dismiss()
                } label: {
                    Text("Approve")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
        // Removed custom background and presentation modifications
    }
}

#Preview("Sheet") {
    ToolConfirmationSheet(toolCall: .init(id: "ddwd", functionName: "ffq", arguments: "fqfq", previewTitle: "fqf", previewContent: "fqffff"), onApprove: {}, onCancel: {})
}
