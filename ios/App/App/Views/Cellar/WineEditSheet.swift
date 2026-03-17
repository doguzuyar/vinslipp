import SwiftUI

struct WineEditSheet: View {
    @State var entry: CellarEntry
    let isNew: Bool
    let onSave: (CellarEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Wine") {
                    TextField("Winery", text: $entry.winery)
                    TextField("Wine Name", text: $entry.wineName)
                    TextField("Vintage", text: $entry.vintage)
                        .keyboardType(.numberPad)
                }

                Section("Origin") {
                    TextField("Region", text: $entry.region)
                    TextField("Country", text: $entry.country)
                    TextField("Wine Type", text: $entry.wineType)
                }

                Section("Cellar") {
                    Picker("Status", selection: $entry.status) {
                        ForEach(WineStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Bottles")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            if entry.count > 0 { entry.count -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                        }
                        .disabled(entry.count <= 0)
                        Text("\(entry.count)")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 30)
                        Button {
                            entry.count += 1
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                        }
                    }

                    TextField("Price", text: $entry.price)
                        .keyboardType(.numberPad)
                    TextField("Drink Year", text: $entry.drinkYear)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Tasting notes, storage location...", text: $entry.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if entry.links.isEmpty {
                        Text("No links added")
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(entry.links.indices, id: \.self) { index in
                        HStack {
                            TextField("URL", text: $entry.links[index])
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button {
                                entry.links.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        entry.links.append("")
                    } label: {
                        Label("Add Link", systemImage: "plus")
                            .font(.subheadline)
                    }
                } header: {
                    Text("Links")
                }

                if !isNew {
                    Section {
                        HStack {
                            Text("Source")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.source.rawValue.capitalized)
                                .foregroundStyle(.tertiary)
                        }
                        HStack {
                            Text("Added")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.addedDate)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Wine" : "Edit Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var cleaned = entry
                        cleaned.links = cleaned.links.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        onSave(cleaned)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(entry.winery.isEmpty && entry.wineName.isEmpty)
                }
            }
        }
    }
}
