// CardStyle.swift
// Coordinates Converter

import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
