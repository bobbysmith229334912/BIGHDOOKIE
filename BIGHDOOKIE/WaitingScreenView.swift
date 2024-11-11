import SwiftUI
import Firebase

struct WaitingScreenView: View {
    var sessionID: String
    var selectedUsers: Set<String>
    @EnvironmentObject var gameSession: GameSession
    @Binding var navigateToGame: Bool
    @State private var readyUsers: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Text("Waiting for Players to Join...")
                .font(.headline)
                .padding()

            List(selectedUsers.sorted(), id: \.self) { user in
                HStack {
                    Text(user)
                    Spacer()
                    if readyUsers.contains(user) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }

            Button(action: {
                markPlayerAsJoined()
            }) {
                Text("Join")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            Spacer()
        }
        .onAppear {
            listenToJoinStatus()
        }
    }

    private func markPlayerAsJoined() {
        let db = Firestore.firestore()
        let sessionRef = db.collection("gameSessions").document(sessionID)

        sessionRef.getDocument { document, error in
            if let document = document, document.exists {
                var players = document.data()?["players"] as? [[String: Any]] ?? []

                if let index = players.firstIndex(where: { $0["uid"] as? String == Auth.auth().currentUser?.uid }) {
                    players[index]["hasJoined"] = true
                }

                sessionRef.updateData(["players": players]) { error in
                    if let error = error {
                        self.errorMessage = "Error marking as joined: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func listenToJoinStatus() {
        let db = Firestore.firestore()
        db.collection("gameSessions").document(sessionID).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot, document.exists else {
                print("Error fetching game state: \(String(describing: error))")
                return
            }

            let gameData = document.data() ?? [:]
            let players = gameData["players"] as? [[String: Any]] ?? []

            readyUsers = Set(players.compactMap { player in
                if let hasJoined = player["hasJoined"] as? Bool, hasJoined {
                    return player["name"] as? String
                }
                return nil
            })

            let humanPlayers = players.filter { !($0["isComputer"] as? Bool ?? false) }
            if readyUsers.count == humanPlayers.count {
                DispatchQueue.main.async {
                    navigateToGame = true
                }
            }
        }
    }
}
