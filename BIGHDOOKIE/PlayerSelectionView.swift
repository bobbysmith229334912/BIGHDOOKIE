import SwiftUI
import Firebase
import FirebaseFirestore

struct PlayerSelectionView: View {
    @EnvironmentObject var gameSession: GameSession
    @State private var availableUsers: [String] = []
    @State private var selectedOpponents: [String?] = ["None", "None", "None"]
    @State private var errorMessage: String?
    @State private var isGameReady = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Player Selection")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text("Select Opponents")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    if isLoading {
                        ProgressView("Loading players...")
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // Opponent selection Pickers
                        ForEach(0..<selectedOpponents.count, id: \.self) { index in
                            Picker("Opponent \(index + 1)", selection: $selectedOpponents[index]) {
                                Text("None").tag("None" as String?)
                                ForEach(availableUsers, id: \.self) { user in
                                    if !selectedOpponents.contains(user) || selectedOpponents[index] == user {
                                        Text(user).tag(user as String?)
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                        }
                    }
                    
                    // Start Game Button
                    Button(action: startGame) {
                        Text("Start Game")
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isOpponentSelected() ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }
                    .disabled(!isOpponentSelected())
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .onAppear { fetchAvailableUsers() }
            .navigationDestination(isPresented: $isGameReady) {
                ContentView(numberOfPlayers: selectedOpponents.filter { $0 != "None" }.count + 1, gameSession: gameSession)
                    .environmentObject(gameSession)
            }
        }
    }
    
    private func isOpponentSelected() -> Bool {
        selectedOpponents.contains { $0 != "None" }
    }
    
    private func fetchAvailableUsers() {
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                errorMessage = "Failed to load users."
            } else if let snapshot = snapshot {
                availableUsers = snapshot.documents.compactMap { document in
                    document.data()["username"] as? String
                }
                if availableUsers.isEmpty { errorMessage = "No available users found." }
            } else {
                errorMessage = "No users found."
            }
        }
    }
    
    private func startGame() {
        gameSession.addPlayer(name: "Player 1")
        
        // Add selected opponents
        for opponent in selectedOpponents where opponent != "None" {
            if let opponent = opponent { gameSession.addPlayer(name: opponent) }
        }
        
        gameSession.saveSession()
        loadSession()
        isGameReady = true
    }
    
    private func loadSession() {
        if let sessionID = gameSession.sessionID {
            gameSession.listenToSession(sessionID: sessionID)
        } else {
            print("Error: Session ID is nil.")
        }
    }
}
