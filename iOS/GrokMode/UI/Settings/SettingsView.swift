//
//  SettingsView.swift
//  GrokMode
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeManager = StoreManager()
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    let onLogout: () async -> Void

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    SettingsRow(icon: "person.circle.fill", title: "Account", iconColor: .blue)
                    SettingsRow(icon: "bell.fill", title: "Notifications", iconColor: .red)
                } header: {
                    Text("General")
                }

                // Usage Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("4/5 min")
                            Spacer()
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Text("used this month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.15))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue.gradient)
                                    .frame(width: geometry.size.width * 0.8, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.vertical, 4)

                    // Upgrade to Plus
                    SubscriptionRow(
                        tier: .plus,
                        storeManager: storeManager,
                        isPurchasing: $isPurchasing,
                        showError: $showError,
                        errorMessage: $errorMessage
                    )

                    // Upgrade to Pro
                    SubscriptionRow(
                        tier: .pro,
                        storeManager: storeManager,
                        isPurchasing: $isPurchasing,
                        showError: $showError,
                        errorMessage: $errorMessage
                    )
                } header: {
                    Text("Usage")
                }

                // Voice Section
                Section {
                    SettingsRow(icon: "waveform", title: "Voice Settings", iconColor: .purple)
                    SettingsRow(icon: "speaker.wave.3.fill", title: "Audio Output", iconColor: .green)
                } header: {
                    Text("Voice")
                }

                // About Section
                Section {
                    SettingsRow(icon: "info.circle.fill", title: "About", iconColor: .gray)
                    SettingsRow(icon: "doc.text.fill", title: "Privacy Policy", iconColor: .gray)
                    SettingsRow(icon: "doc.text.fill", title: "Terms of Service", iconColor: .gray)
                } header: {
                    Text("About")
                }

                // Logout Section
                Section {
                    Button {
                        Task {
                            await onLogout()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isPurchasing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor.gradient)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Subscription Row

private struct SubscriptionRow: View {
    let tier: SubscriptionTier
    let storeManager: StoreManager
    @Binding var isPurchasing: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String

    private var isSubscribed: Bool {
        storeManager.isSubscribed(to: tier)
    }

    private var title: String {
        if isSubscribed {
            return "\(tier.displayName) (Current)"
        }
        return "Upgrade to \(tier.displayName)"
    }

    private var subtitle: String {
        if let minutes = tier.minutesPerMonth {
            return "\(minutes) min / month"
        }
        return "Unlimited"
    }

    var body: some View {
        Button {
            guard !isSubscribed else { return }
            Task {
                isPurchasing = true
                do {
                    _ = try await storeManager.purchase(tier: tier)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                isPurchasing = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSubscribed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text(storeManager.priceString(for: tier))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isSubscribed)
    }
}

#Preview {
    SettingsView(onLogout: {})
}
