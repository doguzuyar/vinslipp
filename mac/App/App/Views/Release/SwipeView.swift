import SwiftUI

@MainActor
class ImagePrefetcher: ObservableObject {
    @Published var cache: [String: NSImage] = [:]
    private var loading: Set<String> = []
    private let prefetchCount = 5

    func prefetchAround(index: Int, wines: [ReleaseWine]) {
        let end = min(index + prefetchCount, wines.count)
        for i in index..<end {
            guard let url = wines[i].imageUrl, !url.isEmpty else { continue }
            guard cache[url] == nil, !loading.contains(url) else { continue }
            loading.insert(url)
            Task {
                await fetchImage(urlString: url)
            }
        }
    }

    private func fetchImage(urlString: String) async {
        defer { loading.remove(urlString) }
        guard let url = URL(string: urlString) else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let img = NSImage(data: data) {
            cache[urlString] = img
        }
    }
}

struct SwipeView: View {
    let wines: [ReleaseWine]
    @EnvironmentObject var appDelegate: AppDelegate
    @Environment(\.dismiss) private var dismiss
    @StateObject private var prefetcher = ImagePrefetcher()
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var likedCount = 0
    @State private var skippedCount = 0

    private var isFinished: Bool {
        currentIndex >= wines.count
    }

    private var dragRotation: Double {
        Double(dragOffset) / 25.0
    }

    private var dragProgress: Double {
        Double(dragOffset) / 150.0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .padding()
            }

            if isFinished {
                summaryView
            } else {
                Spacer()

                HStack {
                    Text("Today's Releases")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(currentIndex + 1) / \(wines.count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                cardStack

                Spacer()
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            prefetcher.prefetchAround(index: 0, wines: wines)
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            if currentIndex + 1 < wines.count {
                let nextScale = 0.95 + 0.05 * min(abs(dragProgress), 1.0)
                let nextOpacity = 0.5 + 0.5 * min(abs(dragProgress), 1.0)
                wineCard(for: wines[currentIndex + 1])
                    .scaleEffect(nextScale)
                    .opacity(nextOpacity)
                    .allowsHitTesting(false)
            }

            wineCard(for: wines[currentIndex])
                .offset(x: dragOffset)
                .rotationEffect(.degrees(dragRotation))
                .overlay(swipeOverlay)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.linear(duration: 0.05)) {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let totalMovement = value.translation.width + velocity * 0.3

                            if totalMovement > 120 {
                                completeSwipe(direction: .right)
                            } else if totalMovement < -120 {
                                completeSwipe(direction: .left)
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
    }

    // MARK: - Wine Card

    private func wineCard(for wine: ReleaseWine) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(wineCardColor(for: wine))

                if let imageUrl = wine.imageUrl, !imageUrl.isEmpty,
                   let img = prefetcher.cache[imageUrl] {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                } else if let imageUrl = wine.imageUrl, !imageUrl.isEmpty {
                    ProgressView()
                } else {
                    Image("VinslippBottle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                }
            }
            .frame(height: 340)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wine.producer)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if let score = wine.ratingScore, score > 0 {
                        Text(String(repeating: "\u{2605}", count: score))
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                HStack {
                    Text(wine.wineName)
                        .lineLimit(1)
                    Spacer()
                    Text(wine.price)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(wine.vintage)
                    if !wine.region.isEmpty {
                        Text(wine.region)
                            .lineLimit(1)
                    }
                    Text(wine.countryEnglish)
                    Text(wine.wineTypeEnglish)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if let reason = wine.ratingReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                HStack(spacing: 12) {
                    if let url = URL(string: wine.searchLink) {
                        Button { LinkOpener.open(url) } label: {
                            Label("Search", systemImage: "globe")
                        }
                        .buttonStyle(.plain)
                    }
                    if let url = URL(string: wine.sbLink) {
                        Button { LinkOpener.open(url) } label: {
                            Label("Systembolaget", systemImage: "cart")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption.weight(.medium))
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            actionButtons
                .padding(.bottom, 16)
        }
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .frame(maxWidth: 500)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: - Swipe Overlay

    private var swipeOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green, lineWidth: 4)
                .overlay(
                    VStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("FAVORITE")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.green)
                    }
                    .rotationEffect(.degrees(-15))
                    .padding(.top, 40)
                    .padding(.leading, 20),
                    alignment: .topLeading
                )
                .opacity(max(0, dragProgress))
                .padding(.horizontal, 8)

            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red, lineWidth: 4)
                .overlay(
                    VStack {
                        Image(systemName: "xmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.red)
                        Text("SKIP")
                            .font(.title3.weight(.black))
                            .foregroundStyle(.red)
                    }
                    .rotationEffect(.degrees(15))
                    .padding(.top, 40)
                    .padding(.trailing, 20),
                    alignment: .topTrailing
                )
                .opacity(max(0, -dragProgress))
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 40) {
            actionButton(direction: .left, icon: "xmark", color: .red)
            actionButton(direction: .right, icon: "heart.fill", color: .green)
        }
    }

    private func actionButton(direction: SwipeDirection, icon: String, color: Color) -> some View {
        Button {
            completeSwipe(direction: direction)
        } label: {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(Color.tertiarySystemBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Swipe Logic

    private enum SwipeDirection {
        case left, right
    }

    private func completeSwipe(direction: SwipeDirection) {
        let wine = wines[currentIndex]

        if direction == .right {
            if !appDelegate.favoritesStore.isFavorite(wine.productNumber) {
                appDelegate.favoritesStore.toggle(wine.productNumber)
            }
            likedCount += 1
        } else {
            skippedCount += 1
        }

        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = direction == .right ? 600 : -600
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            var transaction = Transaction(animation: .none)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
                currentIndex += 1
            }
            prefetcher.prefetchAround(index: currentIndex, wines: wines)
        }
    }

    // MARK: - Summary View

    private var summaryView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All done!")
                .font(.title2.weight(.bold))

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.green)
                    Text("\(likedCount) favorited")
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                    Text("\(skippedCount) skipped")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Button("Close") {
                dismiss()
            }
            .font(.subheadline.weight(.medium))
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Helpers

    private static let redColors = ["4D1421", "722F37", "ee9595", "c890d8"]
    private static let whiteColors = ["ffd84a", "fff9c4", "ffb855", "ffe0b2"]
    private static let roseColors = ["f8bbd0", "ee9595", "e1bee7", "c890d8"]
    private static let sparklingColors = ["ffd84a", "6ab8f5", "fff9c4", "bbdefb"]

    private func wineCardColor(for wine: ReleaseWine) -> Color {
        let index = wines.firstIndex(where: { $0.id == wine.id }) ?? 0
        let variant = index % 4
        let hex: String
        switch wine.wineTypeEnglish {
        case "Red Wine":
            hex = Self.redColors[variant]
        case "White Wine":
            hex = Self.whiteColors[variant]
        case "Rose Wine":
            hex = Self.roseColors[variant]
        case "Sparkling Wine":
            hex = Self.sparklingColors[variant]
        default:
            hex = "888888"
        }
        return Color(hex: hex)
    }
}
