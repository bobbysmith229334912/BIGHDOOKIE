import Foundation

// Card struct representing a single card
struct Card: Identifiable, Hashable, Codable {
    var id = UUID() // Identifiable conformance
    var rank: String
    var suit: String
    
    var description: String {
        return "\(rank) of \(suit)"
    }
    
    // Implementing Hashable protocol
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rank)
        hasher.combine(suit)
    }
}

// Deck class representing the deck of cards
class Deck {
    var cards: [Card] = []
    let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    let suits = ["hearts", "diamonds", "clubs", "spades"]
    
    init() {
        for suit in suits {
            for rank in ranks {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        shuffleDeck() // Shuffle the deck when it's initialized
    }
    
    // Shuffle the deck
    func shuffleDeck() {
        cards.shuffle()
    }
    
    // Draw a card from the deck
    func drawCard() -> Card? {
        return cards.isEmpty ? nil : cards.removeFirst()
    }
}
