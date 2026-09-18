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
        // Try loading from various paths
        let possiblePaths = [
            // Widget directory
            "/Users/apblair/Desktop/vg-cheatsheet/vg-jargon/widget/cards.json",
            // Relative paths
            "../cards.json",
            "cards.json",
        ]

        for path in possiblePaths {
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

        // Load sample cards if no JSON found
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
