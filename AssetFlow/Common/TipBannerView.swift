//
//  TipBannerView.swift
//  AssetFlow
//
//  Created by 한현민 on 3/6/26.
//

import SwiftUI

/// 아이콘 디자인 팁 배너 뷰
struct TipBannerView: View {
    @Binding var isPresented: Bool
    @State private var isOnHover: Bool = false

    let tipText: String = "Tip: Press Command key with 1~4 number to switch tools quickly!"

    var body: some View {
        HStack {
            Text(tipText)
                .font(.subheadline)
                .foregroundColor(.black)
                .bold()
                .lineLimit(1)
                .multilineTextAlignment(.center)

            Spacer()

            // dismiss button
            Button {
                isPresented.toggle()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(isOnHover ? .white : .gray)
            }
            .buttonStyle(.plain)
            .scaleEffect(isOnHover ? 1.4 : 1.0)
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isOnHover = hover
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.8))
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: isPresented)
    }
}

#Preview {
    TipBannerView(isPresented: .constant(true))
}
