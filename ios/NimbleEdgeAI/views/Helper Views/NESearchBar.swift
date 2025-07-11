/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct NESearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var showCancel: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text("Search...").foregroundColor(.textPrimary.opacity(0.4)))
                .foregroundColor(.textPrimary)
                .frame(height: 30)
                .focused($isFocused)
                .tint(.accentHigh1)
                .padding(8)
                .background(Color.backgroundSecondary)
                .cornerRadius(10)
                .onChange(of: isFocused) { newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCancel = true
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCancel = false
                        }
                    }
                }

            if showCancel {
                Button("Cancel") {
                    withAnimation {
                        isFocused = false
                        showCancel = false
                    }
                    text = ""
                }
                .tint(.accent)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCancel)
    }
}
