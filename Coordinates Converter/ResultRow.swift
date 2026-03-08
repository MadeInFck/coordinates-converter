// ResultRow.swift
// Coordinates Converter

import SwiftUI

struct ResultRow: View {
    let label: String
    let value: String

    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            // Format label badge
            Text(label)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            // Coordinate value
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button
            Button {
                ClipboardHelper.copy(value)
                withAnimation(.spring(duration: 0.2)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .imageScale(.medium)
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy \(label)")
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack(spacing: 0) {
        ResultRow(label: "DD",   value: "48.856614° N  2.352222° E")
        Divider().padding(.leading, 54)
        ResultRow(label: "DMS",  value: "48°51'23.81\" N  2°21'07.99\" E")
        Divider().padding(.leading, 54)
        ResultRow(label: "DDM",  value: "48° 51.39684' N  2° 21.13320' E")
        Divider().padding(.leading, 54)
        ResultRow(label: "UTM",  value: "31U 0452484 5411719")
        Divider().padding(.leading, 54)
        ResultRow(label: "MGRS", value: "31UDQ 52484 11719")
    }
    .cardStyle()
    .padding()
}
