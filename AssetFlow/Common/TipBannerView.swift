//
//  TipBannerView.swift
//  AssetFlow
//
//  Created by 한현민 on 3/6/26.
//

import SwiftUI

/// 아이콘 디자인 팁 배너 뷰
struct TipBannerView: View {
    @Environment(\.dismiss) private var dismiss

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
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.yellow.opacity(0.8))
        .frame(height: 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TipBannerView()
}
