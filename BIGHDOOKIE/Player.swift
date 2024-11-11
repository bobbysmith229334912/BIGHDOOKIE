import Foundation
import FirebaseFirestore

class Player: Identifiable {
    var id: String
    var name: String
    var bankroll: Double
    var hand: [Card] = []

    init(id: String = UUID().uuidString, name: String, bankroll: Double = 1000.0, hand: [Card] = []) {
        self.id = id
        self.name = name
        self.bankroll = bankroll
        self.hand = hand
    }

    // Convert player's hand to a dictionary format suitable for Firestore
    func handAsDictionary() -> [[String: String]] {
        return hand.map { card in
            return ["rank": card.rank, "suit": card.suit]
        }
    }

    // Initialize a player from Firestore data
    convenience init(fromData data: [String: Any]) {
        let name = data["name"] as? String ?? "Unknown"
        let bankroll = data["bankroll"] as? Double ?? 1000.0
        let handData = data["hand"] as? [[String: String]] ?? []
        let hand = handData.map { Card(rank: $0["rank"] ?? "", suit: $0["suit"] ?? "") }
        self.init(name: name, bankroll: bankroll, hand: hand)
    }
}
