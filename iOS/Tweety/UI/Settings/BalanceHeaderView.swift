//
//  BalanceHeaderView.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import SwiftUI

struct BalanceHeaderView: View {
    let balance: CreditBalance?

    var body: some View {
        VStack(spacing: 8) {
            Text("Credit Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let balance = balance {
                Text("$\(balance.remaining, specifier: "%.2f")")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(balanceColor)
                    .contentTransition(.numericText())
            } else {
                ProgressView()
                    .simulateTextHeight(.system(size: 42, weight: .bold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var balanceColor: Color {
        guard let balance = balance else { return .primary }
        if balance.remaining <= 0 { return .red }
        if balance.remaining < 5 { return .orange }
        return .green
    }
}

#Preview {
    List {
        Section {
            BalanceHeaderView(balance: CreditBalance(userId: "test", spent: 5.0, total: 20.0, remaining: 15.0))
        }
    }
    .listStyle(.insetGrouped)
}
