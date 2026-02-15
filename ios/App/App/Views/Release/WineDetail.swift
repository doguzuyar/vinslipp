import SwiftUI
import FirebaseAuth

struct WineDetail: View {
    let wine: ReleaseWine
    @State private var showBlogSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            if let reason = wine.ratingReason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                if let url = URL(string: wine.vivinoLink) {
                    Link(destination: url) {
                        Label("Vivino", systemImage: "globe")
                            .font(.caption.weight(.medium))
                    }
                }
                if let url = URL(string: wine.sbLink) {
                    Link(destination: url) {
                        Label("Systembolaget", systemImage: "cart")
                            .font(.caption.weight(.medium))
                    }
                }
                Button {
                    showBlogSheet = true
                } label: {
                    Label("Blog", systemImage: "square.and.pencil")
                        .font(.caption.weight(.medium))
                }
            }

            HStack(spacing: 16) {
                if !wine.country.isEmpty {
                    DetailChip(label: "Country", value: wine.countryEnglish)
                }
                DetailChip(label: "Type", value: wine.wineTypeEnglish)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
        .sheet(isPresented: $showBlogSheet) {
            BlogSheet(wine: wine)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Blog Sheet

private struct BlogSheet: View {
    let wine: ReleaseWine
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var hideName = false
    @State private var isPosting = false
    @State private var posted = false
    @StateObject private var blogService = BlogService()

    private var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Wine info header
                VStack(alignment: .leading, spacing: 2) {
                    Text(wine.producer)
                        .font(.subheadline.weight(.semibold))
                    Text("\(wine.wineName) \(wine.vintage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSignedIn {
                    if posted {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("Posted!")
                                .font(.subheadline.weight(.medium))
                            Text("Your note will appear in the blog within a few hours.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxHeight: .infinity)
                    } else if blogService.hasPostedToday {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("You've already posted today")
                                .font(.subheadline.weight(.medium))
                            Text("Come back tomorrow!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        TextField("Write your tasting note...", text: $comment, axis: .vertical)
                            .lineLimit(4...6)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Text("\(comment.count)/140")
                                .font(.caption2)
                                .foregroundStyle(comment.count > 130 ? .red : .secondary)
                            Spacer()
                            Button {
                                hideName.toggle()
                            } label: {
                                Label("Hide name", systemImage: hideName ? "person.slash.fill" : "person.slash")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(hideName ? .primary : .tertiary)
                            }
                            Spacer()
                            Button("Post") {
                                Task { await post() }
                            }
                            .font(.subheadline.weight(.medium))
                            .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting || comment.count > 140)
                        }
                    }
                } else {
                    Spacer()
                    Text("Sign in to write a tasting note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Blog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func post() async {
        isPosting = true
        let success = await blogService.addPost(
            wineId: wine.productNumber,
            wineName: wine.wineName,
            winery: wine.producer,
            vintage: wine.vintage,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: hideName ? "Vinslipp User" : nil
        )
        if success {
            posted = true
        }
        isPosting = false
    }
}

struct DetailChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
