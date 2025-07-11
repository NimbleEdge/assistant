/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */
 
import SwiftUI

struct IntroductionPage: View {
    let onProceed: () -> Void
    @State private var showDownloadAlert = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .edgesIgnoringSafeArea(.all)
            
            BlurryShapesBackground()
            
            HStack {
                VStack(alignment: .leading) {
                    Image("ic_ne_logo")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hi! I'm \nNimbleEdge ")
                            .foregroundColor(.textPrimary)
                            .fontWeight(.bold)
                            .font(.system(size: 38)) +
                        Text("AI. \n")
                            .foregroundColor(Color.accent)
                            .fontWeight(.bold)
                            .font(.system(size: 38)) +
                        Text("Your privacy \naware personal assistant.")
                            .foregroundColor(.textPrimary)
                            .fontWeight(.bold)
                            .font(.system(size: 38))
                        
                        Text("All your interactions are completely private and powered by ")
                            .foregroundColor(Color.textSecondary)
                            .font(.body) +
                        Text("Llama 3.2")
                            .foregroundColor(Color.accent)
                            .font(.body)
                        
                        Spacer().frame(height: 64)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Button(action: {
                                showDownloadAlert = true
                            }) {
                                HStack {
                                    Text("Let's get started")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.accent)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.body)
                                        .foregroundColor(Color.accent)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            HStack(spacing: 0) {
                                Text("By proceeding, you agree to our ")
                                    .foregroundColor(.gray)
                                    .font(.caption) +
                                Text("Privacy Policy")
                                    .foregroundColor(Color.textPrimary.opacity(0.8))
                                    .fontWeight(.semibold)
                                    .font(.caption) +
                                Text(".")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .onTapGesture {
                                if let url = URL(string: "https://nimbleedge.com/privacy-policy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                }
                .padding(24)
                
                Spacer()
            }

        }
        .alert("Download Required", isPresented: $showDownloadAlert) {
            Button("Cancel") { }
            Button("Download") {
                onProceed()
            }
        } message: {
            Text("The app needs to download assets of \((DownloadItem.getDefaultDownloadSize().asReadableSize(unit: [.useGB]))) to proceed. Wi-Fi is recommended.")
        }
    }
}

struct BlurryShapesBackground: View {
    @State private var offsetX1: CGFloat = 0
    @State private var offsetY1: CGFloat = 0
    @State private var offsetX2: CGFloat = 100
    @State private var offsetY2: CGFloat = 200
    
    private let shapeColors = [
        Color(hex:0xFF313A61),
        Color(hex:0xFF972A2A),
        Color(hex:0xFF0DB8C6),
        Color(hex:0xFFEABB0F),
        Color(hex:0xFFF3EEE8)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                Circle()
                    .fill(shapeColors[0].opacity(0.7))
                    .frame(width: min(geometry.size.width, geometry.size.height) / 3)
                    .position(
                        x: geometry.size.width / 4 + offsetX1,
                        y: geometry.size.height / 3 + offsetY1 - 80
                    )
                
                Circle()
                    .fill(shapeColors[2].opacity(0.5))
                    .frame(width: min(geometry.size.width, geometry.size.height) / 4)
                    .position(
                        x: geometry.size.width * 3/4 + offsetX2,
                        y: geometry.size.height * 2/3 + offsetY2 - 80
                    )
                
                Circle()
                    .fill(shapeColors[3].opacity(0.4))
                    .frame(width: min(geometry.size.width, geometry.size.height) / 2.5)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2 - 80
                    )
                
                Circle()
                    .fill(shapeColors[1].opacity(0.3))
                    .frame(width: min(geometry.size.width, geometry.size.height) / 3.5)
                    .position(
                        x: geometry.size.width / 2 - offsetX2 / 2,
                        y: geometry.size.height / 2 + offsetY1 / 2 - 80
                    )
                
                Circle()
                    .fill(shapeColors[4].opacity(0.2))
                    .frame(width: min(geometry.size.width, geometry.size.height) / 1.75)
                    .position(
                        x: geometry.size.width / 2 + offsetX1 / 2,
                        y: geometry.size.height / 2 - offsetY2 / 2 - 80
                    )
            }
            .blur(radius: 60)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 5).repeatForever(autoreverses: true)
                ) {
                    offsetX1 = 200
                }
                withAnimation(
                    Animation.linear(duration: 7).repeatForever(autoreverses: true)
                ) {
                    offsetY1 = 100
                }
                withAnimation(
                    Animation.linear(duration: 6).repeatForever(autoreverses: true)
                ) {
                    offsetX2 = 300
                }
                withAnimation(
                    Animation.linear(duration: 8).repeatForever(autoreverses: true)
                ) {
                    offsetY2 = 50
                }
            }
        }
    }
}
