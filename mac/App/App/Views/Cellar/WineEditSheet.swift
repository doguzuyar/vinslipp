import SwiftUI

struct WineEditSheet: View {
    @State var entry: CellarEntry
    let isNew: Bool
    let onSave: (CellarEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Wine")
                    field("Winery", text: $entry.winery)
                    field("Wine Name", text: $entry.wineName)
                    field("Vintage", text: $entry.vintage)

                    sectionHeader("Origin")
                    field("Region", text: $entry.region)
                    field("Country", text: $entry.country)
                    field("Wine Type", text: $entry.wineType)

                    sectionHeader("Cellar")
                    Picker("Status", selection: $entry.status) {
                        ForEach(WineStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Bottles")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Button {
                            if entry.count > 0 { entry.count -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
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
                        .buttonStyle(.plain)
                    }

                    field("Price", text: $entry.price)
                    field("Drink Year", text: $entry.drinkYear)

                    sectionHeader("Notes")
                    TextField("Tasting notes, storage location...", text: $entry.notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)

                    sectionHeader("Links")
                    if entry.links.isEmpty {
                        Text("No links added")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    ForEach(entry.links.indices, id: \.self) { index in
                        HStack {
                            TextField("URL", text: $entry.links[index])
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            Button {
                                entry.links.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
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
                    .buttonStyle(.plain)

                    if !isNew {
                        sectionHeader("Info")
                        HStack {
                            Text("Source").font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(entry.source.rawValue.capitalized).font(.caption).foregroundColor(.gray)
                        }
                        HStack {
                            Text("Added").font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(entry.addedDate).font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    var cleaned = entry
                    cleaned.links = cleaned.links.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    onSave(cleaned)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(entry.winery.isEmpty && entry.wineName.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 420, height: 560)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.gray)
            .textCase(.uppercase)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
    }
}
