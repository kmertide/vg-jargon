import SwiftUI

struct CardView: View {
    let card: Card
    let isShowingAnswer: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with tags
            HStack {
                Text(card.deck.replacingOccurrences(of: "vg-jargon::", with: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                DifficultyBadge(difficulty: card.difficulty)
            }

            Divider()

            // Front (question)
            Text(card.front)
                .font(.headline)
                .foregroundStyle(.primary)

            if isShowingAnswer {
                Divider()

                // Back (answer)
                Text(card.back)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !card.source.isEmpty {
                    Text(card.source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            } else {
                Spacer()

                Text("Click to reveal answer")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)

            // Tags
            if !card.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(card.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill.tertiary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct DifficultyBadge: View {
    let difficulty: String

    var color: Color {
        switch difficulty {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(difficulty)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

