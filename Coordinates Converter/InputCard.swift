// InputCard.swift
// Coordinates Converter

import SwiftUI

struct InputCard: View {
    @Binding var inputFormat: CoordinateFormat
    @Binding var inputDatum:  Datum
    @Binding var freeText:    String
    @Binding var utmZone:     String
    @Binding var utmEasting:  String
    @Binding var utmNorthing: String

    let canConvert: Bool
    let onConvert:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── Title ────────────────────────────────────────────────────────
            Label("Input", systemImage: "location.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            // ── Format + datum pickers ───────────────────────────────────────
            HStack(spacing: 10) {
                // Format picker (menu)
                Menu {
                    ForEach(CoordinateFormat.allCases) { fmt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                inputFormat = fmt
                                freeText   = ""
                                utmZone    = ""; utmEasting = ""; utmNorthing = ""
                            }
                        } label: {
                            if inputFormat == fmt {
                                Label(fmt.displayName, systemImage: "checkmark")
                            } else {
                                Text(fmt.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(inputFormat.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(.primary)

                Spacer()

                // Datum picker (menu)
                Menu {
                    ForEach(Datum.allCases) { d in
                        Button {
                            inputDatum = d
                        } label: {
                            if inputDatum == d {
                                Label(d.rawValue, systemImage: "checkmark")
                            } else {
                                Text(d.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe.europe.africa")
                            .imageScale(.small)
                        Text(inputDatum.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(.primary)
            }

            // ── Input fields (adaptive by format) ───────────────────────────
            Group {
                switch inputFormat {
                case .utm:
                    utmFields
                default:
                    singleTextField
                }
            }
            .animation(.easeInOut(duration: 0.15), value: inputFormat)

            // ── Convert button ───────────────────────────────────────────────
            Button(action: onConvert) {
                Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canConvert)
            .controlSize(.large)
        }
        .cardStyle()
    }

    // ── Single text field (DD / DMS / DDM / MGRS) ────────────────────────────

    private var singleTextField: some View {
        TextField(inputFormat.placeholder, text: $freeText)
            .font(.system(.body, design: .monospaced))
            #if os(iOS)
            .padding(10)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .keyboardType(keyboardTypeForFormat(inputFormat))
            .textInputAutocapitalization(inputFormat == .mgrs ? .characters : .never)
            #else
            .textFieldStyle(.roundedBorder)
            .padding(.vertical, 2)
            #endif
            .autocorrectionDisabled()
            .onSubmit(onConvert)
    }

    // ── UTM structured fields ────────────────────────────────────────────────

    private var utmFields: some View {
        HStack(spacing: 8) {
            TextField("31U", text: $utmZone)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS)
                .frame(width: 52)
                .padding(10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .textInputAutocapitalization(.characters)
                .keyboardType(.numbersAndPunctuation)
                #else
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
                #endif
                .autocorrectionDisabled()

            TextField("Easting", text: $utmEasting)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS)
                .padding(10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .keyboardType(.numberPad)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .autocorrectionDisabled()
                .onSubmit(onConvert)

            TextField("Northing", text: $utmNorthing)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                #if os(iOS)
                .padding(10)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .keyboardType(.numberPad)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .autocorrectionDisabled()
                .onSubmit(onConvert)
        }
    }

    #if os(iOS)
    private func keyboardTypeForFormat(_ format: CoordinateFormat) -> UIKeyboardType {
        switch format {
        case .dd:   return .decimalPad
        case .mgrs: return .asciiCapable
        default:    return .numbersAndPunctuation
        }
    }
    #endif
}

#Preview {
    InputCard(
        inputFormat: .constant(.dd),
        inputDatum:  .constant(.wgs84),
        freeText:    .constant(""),
        utmZone:     .constant(""),
        utmEasting:  .constant(""),
        utmNorthing: .constant(""),
        canConvert:  false,
        onConvert:   {}
    )
    .padding()
    .background(.secondary.opacity(0.1))
}
