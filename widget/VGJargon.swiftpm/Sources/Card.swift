import Foundation

struct Card: Codable, Identifiable {
    let id: String
    let deck: String
    let front: String
    let back: String
    let tags: [String]
    let difficulty: String
    let source: String

    var difficultyColor: String {
        switch difficulty {
        case "beginner": return "green"
        case "intermediate": return "yellow"
        case "advanced": return "red"
        default: return "gray"
        }
    }
}

struct CardDatabase: Codable {
    let version: String
    let generated: String
    let cardCount: Int
    let decks: [String]
    let cards: [Card]

    enum CodingKeys: String, CodingKey {
        case version, generated, decks, cards
        case cardCount = "card_count"
    }
}
