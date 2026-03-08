// ContentView.swift
// Coordinates Converter

import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
final class ConverterViewModel {

    // ── Input state ──────────────────────────────────────────────────────────
    var inputFormat:  CoordinateFormat = .dd
    var inputDatum:   Datum = .wgs84
    var outputDatum:  Datum = .wgs84

    /// Single text field content (DD / DMS / DDM / MGRS)
    var freeText:    String = ""
    /// UTM zone+band field (e.g. "31U")
    var utmZone:     String = ""
    /// UTM easting
    var utmEasting:  String = ""
    /// UTM northing
    var utmNorthing: String = ""

    // ── Output state ─────────────────────────────────────────────────────────
    var result:       ConversionResult? = nil
    var errorMessage: String? = nil

    // ── Last successful input (for output datum reconversion) ────────────────
    private var lastText:        String = ""
    private var lastInputFormat: CoordinateFormat = .dd
    private var lastInputDatum:  Datum = .wgs84

    // ── Computed ─────────────────────────────────────────────────────────────
    var canConvert: Bool {
        switch inputFormat {
        case .utm:
            return !utmZone.isEmpty && !utmEasting.isEmpty && !utmNorthing.isEmpty
        default:
            return !freeText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var hasContent: Bool {
        canConvert || result != nil || errorMessage != nil
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    func convert() {
        errorMessage = nil

        let text: String
        switch inputFormat {
        case .utm:
            text = "\(utmZone.uppercased().trimmingCharacters(in: .whitespaces)) \(utmEasting.trimmingCharacters(in: .whitespaces)) \(utmNorthing.trimmingCharacters(in: .whitespaces))"
        default:
            text = freeText.trimmingCharacters(in: .whitespaces)
        }

        do {
            result = try CoordinateConverter.convert(
                text: text,
                inputFormat: inputFormat,
                inputDatum: inputDatum,
                outputDatum: outputDatum
            )
            lastText        = text
            lastInputFormat = inputFormat
            lastInputDatum  = inputDatum
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    func reconvertWithNewOutputDatum() {
        guard !lastText.isEmpty else { return }
        errorMessage = nil
        do {
            result = try CoordinateConverter.convert(
                text: lastText,
                inputFormat: lastInputFormat,
                inputDatum: lastInputDatum,
                outputDatum: outputDatum
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        freeText    = ""
        utmZone     = ""
        utmEasting  = ""
        utmNorthing = ""
        result      = nil
        errorMessage = nil
        lastText    = ""
    }

    func copyAll() {
        guard let r = result else { return }
        let text = """
        DD:    \(r.dd)
        DMS:   \(r.dms)
        DDM:   \(r.ddm)
        UTM:   \(r.utm)
        MGRS:  \(r.mgrs)
        Datum: \(r.datum.rawValue)
        """
        ClipboardHelper.copy(text)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var vm = ConverterViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    mainCard
                        .frame(maxWidth: 560)
                        .padding(16)
                        // La carte grandit pour remplir tout l'écran disponible
                        .frame(minHeight: geo.size.height - 32, alignment: .top)
                        .frame(maxWidth: .infinity)
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            }
            .background(Color.secondary.opacity(0.08).ignoresSafeArea())
            .navigationTitle("Coordinates Converter")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        withAnimation { vm.clear() }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(!vm.hasContent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
    }

    // ── Carte unique plein écran ──────────────────────────────────────────────

    private var mainCard: some View {
        VStack(spacing: 0) {

            // ── Zone haute : Input ────────────────────────────────────────────
            // Prend 50% si résultats visibles, sinon tout l'espace
            VStack(alignment: .leading, spacing: 14) {
                pickerRow
                inputField
                if let err = vm.errorMessage {
                    errorBanner(err)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // ── Bouton Convert — ancré entre les deux zones ───────────────────
            convertButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.background)

            // ── Zone basse : Résultats ────────────────────────────────────────
            if let r = vm.result {
                Divider()
                resultsSection(r)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        .animation(.spring(duration: 0.3), value: vm.result == nil)
        .animation(.spring(duration: 0.2), value: vm.errorMessage)
    }

    // ── Ligne de pickers ─────────────────────────────────────────────────────

    private var pickerRow: some View {
        HStack(spacing: 10) {
            Label("Input", systemImage: "location.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // Format picker
            Menu {
                ForEach(CoordinateFormat.allCases) { fmt in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.inputFormat = fmt
                            vm.freeText = ""
                            vm.utmZone = ""; vm.utmEasting = ""; vm.utmNorthing = ""
                        }
                    } label: {
                        if vm.inputFormat == fmt {
                            Label(fmt.displayName, systemImage: "checkmark")
                        } else {
                            Text(fmt.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.inputFormat.rawValue)
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

            // Datum picker
            Menu {
                ForEach(Datum.allCases) { d in
                    Button {
                        vm.inputDatum = d
                    } label: {
                        if vm.inputDatum == d {
                            Label(d.rawValue, systemImage: "checkmark")
                        } else {
                            Text(d.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe.europe.africa").imageScale(.small)
                    Text(vm.inputDatum.rawValue)
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
    }

    // ── Champ de saisie ──────────────────────────────────────────────────────

    private var inputField: some View {
        Group {
            if vm.inputFormat == .utm {
                utmFields
            } else {
                singleTextField
            }
        }
        .animation(.easeInOut(duration: 0.15), value: vm.inputFormat)
    }

    // ── Bouton Convert ───────────────────────────────────────────────────────

    private var convertButton: some View {
        Button(action: vm.convert) {
            Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!vm.canConvert)
        .controlSize(.large)
    }

    private var singleTextField: some View {
        TextField(vm.inputFormat.placeholder, text: $vm.freeText, axis: .vertical)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            #if os(iOS)
            .padding(12)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .keyboardType(keyboardTypeForFormat(vm.inputFormat))
            .textInputAutocapitalization(vm.inputFormat == .mgrs ? .characters : .never)
            #else
            .textFieldStyle(.roundedBorder)
            #endif
            .autocorrectionDisabled()
            .onSubmit(vm.convert)
    }

    private var utmFields: some View {
        HStack(spacing: 8) {
            TextField("31U", text: $vm.utmZone)
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

            TextField("Easting", text: $vm.utmEasting)
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
                .onSubmit(vm.convert)

            TextField("Northing", text: $vm.utmNorthing)
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
                .onSubmit(vm.convert)
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

    // ── Section Résultats (contenu de l'ancienne ResultsCard) ────────────────

    private func resultsSection(_ r: ConversionResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Output datum", systemImage: "globe.europe.africa")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Output datum", selection: $vm.outputDatum) {
                    ForEach(Datum.allCases) { d in Text(d.rawValue).tag(d) }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.outputDatum) { _, _ in vm.reconvertWithNewOutputDatum() }
            }

            Divider().padding(.vertical, 12)

            VStack(spacing: 0) {
                ForEach(Array(resultRows(r).enumerated()), id: \.offset) { idx, row in
                    if idx > 0 { Divider().padding(.leading, 54) }
                    ResultRow(label: row.0, value: row.1)
                }
            }

            Divider().padding(.vertical, 12)

            copyAllButton
        }
    }

    @State private var copiedAll = false

    private var copyAllButton: some View {
        Button {
            vm.copyAll()
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

    private func resultRows(_ r: ConversionResult) -> [(String, String)] {
        [("DD", r.dd), ("DMS", r.dms), ("DDM", r.ddm), ("UTM", r.utm), ("MGRS", r.mgrs)]
    }

    // ── Bannière d'erreur ─────────────────────────────────────────────────────

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(14)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.red.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
