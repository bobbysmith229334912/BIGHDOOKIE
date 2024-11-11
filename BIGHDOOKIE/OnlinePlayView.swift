import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseFunctions

struct OnlinePlayView: View {
    var numberOfHumanPlayers: Int
    @EnvironmentObject var gameSession: GameSession
    @State private var sessionID: String = ""
    @State private var availableSessions: [String] = []
    @State private var errorMessage: String?
    @State private var navigateToGame = false
    @State private var isLoading = false
    @State private var currentUser: String? = nil
    @State private var users: [String] = [] // List of usernames to invite
    @State private var selectedUsers: Set<String> = [] // Stores selected usernames
    @State private var showInviteDialog = false
    @State private var isDarkMode: Bool = false
    @State private var navigateToWaitingScreen = false
    @State private var invitesSent = false // Track if invites are sent
    
    // Use InviteManager for handling invites
    @StateObject private var inviteManager = InviteManager()
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("BIGDOOKIE Online Play")
                    .font(.largeTitle)
                    .padding()

                // Create new session button
                Button(action: createNewSession) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Session")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isDarkMode ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()

                // Join existing session by session ID
                TextField("Enter Session ID", text: $sessionID)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding()

                Button(action: joinSession) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Join Session")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || sessionID.isEmpty)
                .padding()

                // Show available sessions
                Text("Available Sessions")
                    .font(.headline)
                    .padding()

                if isLoading {
                    ProgressView("Loading sessions...")
                        .padding()
                } else {
                    List(availableSessions, id: \.self) { session in
                        Button(action: {
                            sessionID = session
                            joinSession()
                        }) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(.blue)
                                Text("Join session: \(session)")
                                    .font(.body)
                                    .padding(.leading, 5)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(height: 150)
                    .listStyle(PlainListStyle())
                }

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                Spacer()

                // Navigation to waiting screen once session is created or joined
                .navigationDestination(isPresented: $navigateToWaitingScreen) {
                    WaitingScreenView(
                        sessionID: sessionID,
                        selectedUsers: selectedUsers,
                        navigateToGame: $navigateToGame
                    )
                }
            }
            .onAppear {
                loadCurrentUser()
                loadAvailableSessions()
                fetchUsersFromFirestore()
                detectTheme()
            }
            .sheet(isPresented: $showInviteDialog) {
                inviteDialog
            }
        }
    }

    // Invite dialog for choosing users
    private var inviteDialog: some View {
        VStack(spacing: 15) {
            Text("Select Players to Invite")
                .font(.headline)
                .padding()

            List {
                ForEach(users, id: \.self) { user in
                    Button(action: {
                        toggleUserSelection(user)
                    }) {
                        HStack {
                            Text(user)
                                .padding()
                                .background(selectedUsers.contains(user) ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            Spacer()
                            if selectedUsers.contains(user) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            if !selectedUsers.isEmpty {
                Text("Selected Players: \(selectedUsers.joined(separator: ", "))")
                    .padding()
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            Button(action: {
                invitesSent = true
                sendInvites()
            }) {
                Text(invitesSent ? "Invites Sent" : "Invite Players")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: { showInviteDialog = false }) {
                Text("Cancel")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func detectTheme() {
        isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
    }

    private func loadCurrentUser() {
        if let user = Auth.auth().currentUser {
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(user.uid)
            userRef.getDocument { document, error in
                if let document = document, document.exists {
                    self.currentUser = document.data()?["username"] as? String
                } else {
                    self.errorMessage = "Failed to load username."
                }
            }
        } else {
            self.errorMessage = "No logged-in user found."
        }
    }

    private func fetchUsersFromFirestore() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching users: \(error.localizedDescription)"
            } else if let snapshot = snapshot {
                self.users = snapshot.documents.map { $0.data()["username"] as? String ?? "Unknown" }
            }
        }
    }

    private func toggleUserSelection(_ user: String) {
        if selectedUsers.contains(user) {
            selectedUsers.remove(user)
        } else {
            selectedUsers.insert(user)
        }
    }

    private func createNewSession() {
        guard let currentUser = currentUser else {
            self.errorMessage = "Username not available."
            return
        }

        let newSessionID = UUID().uuidString
        let db = Firestore.firestore()

        let newSessionData: [String: Any] = [
            "sessionID": newSessionID,
            "players": [
                [
                    "uid": Auth.auth().currentUser?.uid ?? "",
                    "name": currentUser,
                    "hasJoined": false
                ]
            ],
            "currentTurnPlayerID": ""
        ]

        db.collection("gameSessions").document(newSessionID).setData(newSessionData) { error in
            if let error = error {
                self.errorMessage = "Failed to create session: \(error.localizedDescription)"
            } else {
                self.sessionID = newSessionID
                showInviteDialog = true
            }
        }
    }

    private func sendInvites() {
        let db = Firestore.firestore()
        let sessionRef = db.collection("gameSessions").document(sessionID)

        sessionRef.getDocument { document, error in
            if let document = document, document.exists {
                if var sessionData = document.data() {
                    var players = sessionData["players"] as? [[String: Any]] ?? []

                    for user in selectedUsers {
                        players.append([
                            "name": user,
                            "hasJoined": false
                        ])
                        inviteManager.sendInviteMessage(toUser: user) { result in
                            switch result {
                            case .success(let message):
                                print("Invite sent to \(user): \(message)")
                            case .failure(let error):
                                print("Error sending invite to \(user): \(error.localizedDescription)")
                            }
                        }
                    }

                    sessionRef.updateData(["players": players]) { error in
                        if let error = error {
                            self.errorMessage = "Failed to update session: \(error.localizedDescription)"
                        } else {
                            navigateToWaitingScreen = true
                        }
                    }
                }
            }
        }
    }

    private func joinSession() {
        guard let currentUser = currentUser else {
            self.errorMessage = "Username not available."
            return
        }

        let db = Firestore.firestore()
        let sessionRef = db.collection("gameSessions").document(sessionID)

        sessionRef.getDocument { document, error in
            if let document = document, document.exists {
                if var sessionData = document.data() {
                    var players = sessionData["players"] as? [[String: Any]] ?? []

                    players.append([
                        "uid": Auth.auth().currentUser?.uid ?? "",
                        "name": currentUser,
                        "hasJoined": true
                    ])

                    sessionRef.updateData(["players": players]) { error in
                        if let error = error {
                            self.errorMessage = "Failed to join session: \(error.localizedDescription)"
                        } else {
                            navigateToWaitingScreen = true
                        }
                    }
                }
            } else {
                self.errorMessage = "Session not found."
            }
        }
    }

    private func loadAvailableSessions() {
        isLoading = true
        let db = Firestore.firestore()

        db.collection("gameSessions").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = "Error loading sessions: \(error.localizedDescription)"
            } else if let snapshot = snapshot {
                availableSessions = snapshot.documents.map { $0.documentID }
            }
        }
    }
}
