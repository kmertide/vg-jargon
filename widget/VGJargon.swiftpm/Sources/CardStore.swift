import Foundation
import SwiftUI

class CardStore: ObservableObject {
    @Published var cards: [Card] = []
    @Published var currentIndex: Int = 0
    @Published var isShowingAnswer: Bool = false
    @Published var selectedDeck: String? = nil
    @Published var selectedDifficulty: String? = nil

    var filteredCards: [Card] {
        cards.filter { card in
            let deckMatch = selectedDeck == nil || card.deck == selectedDeck
            let difficultyMatch = selectedDifficulty == nil || card.difficulty == selectedDifficulty
            return deckMatch && difficultyMatch
        }
    }

    var currentCard: Card? {
        guard !filteredCards.isEmpty else { return nil }
        let index = currentIndex % filteredCards.count
        return filteredCards[index]
    }

    var decks: [String] {
        Array(Set(cards.map { $0.deck })).sorted()
    }

    init() {
        loadCards()
    }

    func loadCards() {
        // Primary: the bundled resource (Sources/Resources/cards.json), which
        // works regardless of the process's current working directory - this
        // is what makes `swift run` work from any directory, and what a
        // packaged .app would use.
        if let bundleURL = Bundle.module.url(forResource: "cards", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL) {
            do {
                let database = try JSONDecoder().decode(CardDatabase.self, from: data)
                self.cards = database.cards
                print("Loaded \(cards.count) cards from bundle resource")
                return
            } catch {
                print("Failed to decode bundled cards.json: \(error)")
            }
        }

        // Fallback for local development when run via `swift run` from the
        // repo (in case the bundled resource is stale or missing).
        for path in ["../cards.json", "cards.json"] {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url) {
                do {
                    let database = try JSONDecoder().decode(CardDatabase.self, from: data)
                    self.cards = database.cards
                    print("Loaded \(cards.count) cards from \(path)")
                    return
                } catch {
                    print("Failed to decode \(path): \(error)")
                }
            }
        }

        // Last resort so the UI has something to show.
        loadSampleCards()
    }

    func loadSampleCards() {
        cards = [
            Card(
                id: "sample-001",
                deck: "vg-jargon::sample",
                front: "What is a HandleGraph?",
                back: "The base interface for all graph implementations in vg.",
                tags: ["interface", "core"],
                difficulty: "beginner",
                source: "libhandlegraph"
            ),
            Card(
                id: "sample-002",
                deck: "vg-jargon::sample",
                front: "What does the distance index store?",
                back: "A hierarchical snarl decomposition for computing shortest distances.",
                tags: ["index", "distance"],
                difficulty: "intermediate",
                source: "libbdsg"
            ),
            Card(
                id: "sample-003",
                deck: "vg-jargon::sample",
                front: "What is GBZ?",
                back: "Compressed graph format combining GBWT haplotypes + GBWTGraph.",
                tags: ["format", "graph"],
                difficulty: "beginner",
                source: "vg"
            )
        ]
        print("Loaded \(cards.count) sample cards")
    }

    func nextCard() {
        isShowingAnswer = false
        currentIndex = (currentIndex + 1) % max(1, filteredCards.count)
    }

    func previousCard() {
        isShowingAnswer = false
        currentIndex = (currentIndex - 1 + filteredCards.count) % max(1, filteredCards.count)
    }

    func randomCard() {
        isShowingAnswer = false
        currentIndex = Int.random(in: 0..<max(1, filteredCards.count))
    }

    func toggleAnswer() {
        isShowingAnswer.toggle()
    }
}
