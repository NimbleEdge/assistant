/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct NETopBar: View {
    
    var onBackButtonPressed: (() -> ())?
    var onEditButtonPressed: (() -> ())?
    var onAudioModeButtonPressed: (() -> ())?
    var title: String
    var logo: Image?
    @Binding var path: NavigationPath

    var body: some View {
        VStack() {
            HStack(alignment: .center, spacing: 14) {
                
                Button(action: {
                    if let onBackButtonPressed = onBackButtonPressed {
                        onBackButtonPressed()
                    } else {
                        path.removeLast()
                    }
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.custom("", fixedSize: 17))
                        .fontWeight(.bold)
                        .tint(Color.accent)
                }
                
                
                Text(title)
                    .font(.custom("", fixedSize: 17))
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                HStack(spacing: 30) {
                    Button(action: {
                        if let onAudioModeButtonPressed = onAudioModeButtonPressed {
                            onAudioModeButtonPressed()
                        }
                    }) {
                        Image(systemName: "waveform")
                            .font(.custom("", fixedSize: 19))
                            .tint(Color.textPrimary)
                    }
                    
                    
                    Button(action: {
                        if let onCancelButtonPressed = onEditButtonPressed {
                             onCancelButtonPressed()
                        } else {
                            path.append(HomeDestination.chatView)
                        }
                    }) {
                        Image(systemName: "pencil")
                            .font(.custom("", fixedSize: 19))
                            .tint(Color.textPrimary)
                    }
                }
                
            }
            .padding([.leading, .trailing], 20)
            .padding(.top, 17)
            .padding(.bottom, 12)
            
            Rectangle()
                .foregroundColor(.gray.opacity(0.6))
                .frame(height: 0.5)
            
            
        }
    }
}
