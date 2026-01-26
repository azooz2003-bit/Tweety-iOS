//
//  ConfirmationActionPreferencesView.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/24/26.
//

import SwiftUI

struct ConfirmationActionPreferencesView: View {
    @State private var featureFlags = FeatureFlags.shared

    var confirmationSensitiveEndpoints: [XAPIEndpoint] {
        featureFlags.confirmationPreferences.keys.compactMap { XAPIEndpoint(rawValue: $0) }
            .sorted {
                $0.name < $1.name
            }
    }

    var allIsEnabled: Bool {
        featureFlags.confirmationPreferences.map(\.value).reduce(true) { $0 && $1 }
    }

    var allIsDisabled: Bool {
        featureFlags.confirmationPreferences.map(\.value).reduce(true) { $0 && !$1 }
    }

    var body: some View {
        List {
            Section {
                ForEach(confirmationSensitiveEndpoints, id: \.rawValue) { endpoint in
                    ConfirmationToggleRow(endpoint: endpoint, featureFlags: featureFlags)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                if allIsEnabled {
                    Button("Enable All", systemImage: "checkmark") {
                        enableAll()
                    }
                } else {
                    Button("Enable All") {
                        enableAll()
                    }
                }

                if allIsDisabled {
                    Button("Disable All", systemImage: "checkmark") {
                        disableAll()
                    }
                } else {
                    Button("Disable All") {
                        disableAll()
                    }
                }


            }
        }
        .navigationTitle("Actions - Confirmation Required")
        .navigationSubtitle("Actions that require confirmation before executing.")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.hard, for: .top)

    }

    func enableAll() {
        for tool in XAPIEndpoint.confirmationSensitiveEndpoints {
            featureFlags.setRequiresConfirmation(true, for: tool)
        }
    }

    func disableAll() {
        for tool in XAPIEndpoint.confirmationSensitiveEndpoints {
            featureFlags.setRequiresConfirmation(false, for: tool)
        }
    }
}

struct ConfirmationToggleRow: View {
    let endpoint: XAPIEndpoint
    let featureFlags: FeatureFlags

    var requiresConfirmation: Bool {
        featureFlags.shouldRequireConfirmation(for: endpoint)
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { requiresConfirmation },
            set: { newValue in
                featureFlags.setRequiresConfirmation(newValue, for: endpoint)
            }
        )) {
            Text(endpoint.displayName)
        }
    }
}

#Preview {
    NavigationStack {
        ConfirmationActionPreferencesView()
    }
}
