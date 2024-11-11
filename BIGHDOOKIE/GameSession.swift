import Foundation
import Firebase
import FirebaseFirestore

class GameSession: ObservableObject {
    @Published var players: [Player] = [] // List of players in the game session
    @Published var sessionID: String? // Unique identifier for the game session
    @Published var currentTurnPlayerID: String? // Track the current player's turn
    private let db = Firestore.firestore() // Firestore database reference

    init() {
        self.sessionID = UUID().uuidString
    }

    // Function to add a player to the session
    @MainActor func addPlayer(name: String) {
        let player = Player(name: name)
        players.append(player)
        saveSession() // Save the session immediately after adding a player
    }

    // Save session data to Firestore
    @MainActor func saveSession() {
        guard let sessionID = sessionID else { return }
        
        let playerData = players.map { player -> [String: Any] in
            return [
                "id": player.id,
                "name": player.name,
                "bankroll": player.bankroll,
                "hand": player.handAsDictionary()
            ]
        }
        
        let sessionData: [String: Any] = [
            "sessionID": sessionID,
            "players": playerData,
            "currentTurnPlayerID": players.first?.id ?? "" // Default to first player's turn
        ]

        db.collection("gameSessions").document(sessionID).setData(sessionData) { error in
            if let error = error {
                print("Error saving session: \(error.localizedDescription)")
            } else {
                print("Session successfully saved.")
            }
        }
    }

    // Listen for session changes
    func listenToSession(sessionID: String) {
        let docRef = db.collection("gameSessions").document(sessionID)

        docRef.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching session updates: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let data = document.data() {
                self.sessionID = data["sessionID"] as? String
                self.currentTurnPlayerID = data["currentTurnPlayerID"] as? String
                if let playersData = data["players"] as? [[String: Any]] {
                    self.players = playersData.compactMap { playerDict in
                        Player(fromData: playerDict)
                    }
                }
            }
        }
    }
}
