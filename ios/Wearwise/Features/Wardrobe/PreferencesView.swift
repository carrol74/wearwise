import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PreferencesDraft()
    @State private var baseline = PreferencesDraft()
    @State private var loaded = false
    @State private var discarding = false
    @State private var errorText: String?
    @State private var errorTitle = "Could not load preferences"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencySelector(selection: $draft.currency)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target cost per wear").font(.subheadline)
                        HStack {
                            TextField("", text: $draft.costReference).keyboardType(.decimalPad)
                                .accessibilityLabel("Target cost per wear").accessibilityIdentifier("preferences.cost")
                            if !draft.currency.isEmpty { Text(draft.currency).foregroundStyle(.secondary) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target years of use").font(.subheadline)
                        HStack {
                            TextField("", text: $draft.yearReference).keyboardType(.numberPad)
                                .accessibilityLabel("Target years of use").accessibilityIdentifier("preferences.years")
                            Text("years").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Defaults for new clothes")
                }
            }
            .scrollDismissesKeyboard(.interactively).scrollContentBackground(.hidden).background(Color.wardrobeBackground)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).wearwiseKeyboardDismissal()
            .interactiveDismissDisabled(draft != baseline)
            .labelStyle(.iconOnly)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { if draft != baseline { discarding = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        do { try PreferencesStore().save(draft); dismiss() }
                        catch { errorTitle = "Could not save preferences"; errorText = error.localizedDescription }
                    }.disabled(!loaded)
                }
            }
            .task {
                guard !loaded else { return }
                do { draft = PreferencesDraft(try PreferencesStore().load()); baseline = draft; loaded = true }
                catch { errorTitle = "Could not load preferences"; errorText = error.localizedDescription }
            }
            .wearwiseDiscardConfirmation(isPresented: $discarding) { dismiss() }
            .wearwiseErrorToast(errorTitle, message: $errorText)
        }
    }
}

private struct CurrencySelector: View {
    @Binding var selection: String
    @State private var expanded = false
    @State private var query = ""
    @FocusState private var searching: Bool
    private var matches: [CurrencyOption] { CurrencyOption.all.filter { $0.matches(query) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                expanded.toggle()
                query = ""
                searching = expanded
            } label: {
                HStack {
                    Text("Currency").foregroundStyle(Color.charcoalText)
                    Spacer(minLength: 8)
                    Text(selection.isEmpty ? "Choose currency" : selection).foregroundStyle(Color.accentText)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.borderless)
                .accessibilityIdentifier("preferences.currency")
                .accessibilityLabel("Currency")
                .accessibilityValue(selection.isEmpty ? "No currency" : selection)
            if expanded {
                TextField("Search currencies", text: $query)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($searching).submitLabel(.done).onSubmit { searching = false }
                    .accessibilityLabel("Search currencies").accessibilityIdentifier("preferences.currency.search")
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button { choose("") } label: {
                                HStack {
                                    Text("No currency")
                                    Spacer()
                                    if selection.isEmpty { Image(systemName: "checkmark") }
                                }.frame(minHeight: 48).contentShape(Rectangle())
                            }.accessibilityIdentifier("preferences.currency.none")
                        }
                        ForEach(matches) { option in
                            Button { choose(option.code) } label: {
                                HStack {
                                    Text(option.code).font(.body)
                                    Spacer()
                                    if selection == option.code { Image(systemName: "checkmark") }
                                }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
                            }.accessibilityIdentifier("preferences.currency.option.\(option.code)")
                                .accessibilityLabel("\(option.code), \(option.name)")
                                .accessibilityAddTraits(selection == option.code ? [.isSelected] : [])
                        }
                        if matches.isEmpty { Text("No currencies found").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12) }
                    }.buttonStyle(.borderless)
                }.frame(height: CGFloat(min(matches.count + (query.isEmpty ? 1 : 0), 4)) * 52 + (matches.isEmpty ? 44 : 0))
            }
        }.labelStyle(.titleAndIcon)
    }

    private func choose(_ code: String) {
        selection = code
        expanded = false
        searching = false
        query = ""
    }
}
