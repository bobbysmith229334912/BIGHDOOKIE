import Foundation

class AILogic {

    // Easy AI burns random cards
    func burnRandomCards(_ hand: [Card], day: Int) -> [Card] {
        return Array(hand.shuffled().prefix(day))
    }

    // Normal AI burns the highest-ranked cards
    func burnWeakestCards(_ hand: [Card], day: Int) -> [Card] {
        return hand.sorted(by: { cardValue($0) > cardValue($1) }).prefix(day).map { $0 }
    }

    // Hard AI burns cards strategically based on their rank
    func burnStrategicCards(_ hand: [Card], day: Int) -> [Card] {
        return hand.filter { cardValue($0) > 7 }.prefix(day).map { $0 }
    }

    // AI decides betting action based on random logic (refined for stability)
    func decideBetAction() -> String {
        let actions = ["Check", "Bet", "Raise"]
        // Ensure the actions array is non-empty and select an action using arc4random
        if actions.isEmpty { return "Check" }
        let randomIndex = Int(arc4random_uniform(UInt32(actions.count)))
        return actions[randomIndex]
    }

    // Helper function to convert the card's rank to a numeric value
    private func cardValue(_ card: Card) -> Int {
        switch card.rank {
        case "A": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        case "7": return 7
        case "8": return 8
        case "9": return 9
        case "10": return 10
        case "J": return 11
        case "Q": return 12
        case "K": return 13
        default: return 0
        }
    }
}
