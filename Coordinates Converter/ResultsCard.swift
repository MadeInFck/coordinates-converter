// ResultsCard.swift
// Coordinates Converter

import SwiftUI

struct ResultsCard: View {
    let result: ConversionResult
    @Binding var outputDatum: Datum
    let onOutputDatumChange: () -> Void
    let onCopyAll: () -> Void

    @State private var copiedAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header: output datum selector ────────────────────────────────
            HStack {
                Label("Output datum", systemImage: "globe.europe.africa")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Picker("Output datum", selection: $outputDatum) {
                    ForEach(Datum.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: outputDatum) { _, _ in onOutputDatumChange() }
            }

            Divider()
                .padding(.vertical, 12)

            // ── Result rows ──────────────────────────────────────────────────
            VStack(spacing: 0) {
                ForEach(Array(rows(for: result).enumerated()), id: \.offset) { idx, row in
                    if idx > 0 {
                        Divider().padding(.leading, 54)
                    }
                    ResultRow(label: row.label, value: row.value)
                }
            }

            Divider()
                .padding(.vertical, 12)

            // ── Copy all button ──────────────────────────────────────────────
            Button {
                onCopyAll()
                withAnimation(.spring(duration: 0.2)) { copiedAll = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { copiedAll = false }
                }
            } label: {
                Label(
                    copiedAll ? "Copied!" : "Copy all",
                    systemImage: copiedAll ? "checkmark.circle.fill" : "doc.on.clipboard"
                )
                .frame(maxWidth: .infinity)
                .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.bordered)
            .tint(copiedAll ? .green : .accentColor)
        }
        .cardStyle()
    }

    private struct RowItem { let label: String; let value: String }

    private func rows(for r: ConversionResult) -> [RowItem] {
        [
            RowItem(label: "DD",   value: r.dd),
            RowItem(label: "DMS",  value: r.dms),
            RowItem(label: "DDM",  value: r.ddm),
            RowItem(label: "UTM",  value: r.utm),
            RowItem(label: "MGRS", value: r.mgrs),
        ]
    }
}

#Preview {
    let result = try! CoordinateConverter.convert(lat: 48.856614, lon: 2.352222, datum: .wgs84)
    ResultsCard(
        result: result,
        outputDatum: .constant(.wgs84),
        onOutputDatumChange: {},
        onCopyAll: {}
    )
    .padding()
    .background(.secondary.opacity(0.1))
}
