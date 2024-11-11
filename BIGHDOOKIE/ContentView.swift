import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFunctions


struct ContentView: View {
    @State private var deck = Deck() // Deck of cards
    @State private var playerHand: [Card] = [] // Player's hand
    @State private var currentDay = 0 // Tracks the game day
    @State private var maxBurnCards = 0 // The number of cards a player can burn
    @State private var showDialog = false // Controls dialog visibility
    @State private var dialogMessage = "" // Message to display in dialog
    @State private var selectedBurnCards: [Card] = [] // Cards selected for burning
    @State private var isMadeHand = false // Checks if player has a "made hand"
    @State private var showBurnAction = false // Controls burn action dialog
    @State private var currentPlayerTurn = 0 // Active player's turn
    @State private var betPlaced = false // Tracks if a bet was placed
    @State private var playersTurnComplete = false // Tracks if all players completed their turn
    @State private var isBetPhase = true // Tracks the bet phase
    @State private var burnPhaseCompleted = false // Tracks if all players completed the burn phase
    @State private var cardOffset: CGFloat = 0 // Controls the horizontal offset of the hand
    @State private var gameOver = false // Tracks if the game has ended

    let cardWidth: CGFloat = 80 // Width of each card
    let spacing: CGFloat = 10 // Spacing between cards
    
    var numberOfPlayers: Int // Only human players
    var gameSession: GameSession
    private var db = Firestore.firestore() // Firebase Firestore instance
    private let gameId = "gameId12345" // Example game ID

    public init(numberOfPlayers: Int, gameSession: GameSession) {
        self.numberOfPlayers = numberOfPlayers
        self.gameSession = gameSession
    }

    var body: some View {
        ZStack {
            Image("pokerTable")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    listenToGameStateChanges()
                }

            VStack {
                Text("Welcome to BIGDOOKIE")
                    .font(.largeTitle)
                    .padding()

                Text("Your Hand")
                    .font(.headline)
                    .padding()

                // Display the player's hand
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(playerHand, id: \.id) { card in
                            Image("\(card.rank)_of_\(card.suit)")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cardWidth, height: 120)
                                .padding(3)
                        }
                    }
                    .offset(x: cardOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.cardOffset = value.translation.width
                            }
                            .onEnded { value in
                                let fullHandWidth = (cardWidth + spacing) * 4
                                
                                if value.translation.width < -50 {
                                    self.cardOffset = -fullHandWidth
                                } else if value.translation.width > 50 {
                                    self.cardOffset = 0
                                } else {
                                    self.cardOffset = self.cardOffset < 0 ? -fullHandWidth : 0
                                }
                            }
                    )
                }
                .frame(width: (cardWidth + spacing) * 4, height: 120)

                Spacer()

                Text("Your Turn")
                    .font(.headline)
                    .padding()

                // Action Buttons
                VStack(spacing: 10) {
                    HStack {
                        Button("Check") {
                            playerCheck()
                        }
                        .disabled(betPlaced || !isBetPhase)
                        .padding()
                        .background(betPlaced || !isBetPhase ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Bet") {
                            betPlaced = true
                            nextPlayerTurn()
                        }
                        .disabled(betPlaced || !isBetPhase)
                        .padding()
                        .background(betPlaced || !isBetPhase ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Burn Cards") {
                            showBurnAction = true
                            showDialog = true
                        }
                        .disabled(isBetPhase || maxBurnCards == 0)
                        .padding()
                        .background((isBetPhase || maxBurnCards == 0) ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    HStack {
                        Button("Fold") {
                            nextPlayerTurn()
                        }
                        .disabled(playerHand.isEmpty || isBetPhase)
                        .padding()
                        .background(playerHand.isEmpty || isBetPhase ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Call") {
                            nextPlayerTurn()
                        }
                        .disabled(!betPlaced || isBetPhase)
                        .padding()
                        .background(!betPlaced || isBetPhase ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Raise") {
                            nextPlayerTurn()
                        }
                        .disabled(!betPlaced || isBetPhase)
                        .padding()
                        .background(!betPlaced || isBetPhase ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }

                Spacer()

                if currentDay == 0 {
                    Button("Start Game") {
                        startGame()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                if isMadeHand {
                    Button("Press for Made Hand!") {
                        dialogMessage = "You have a made hand!"
                        showDialog = true
                        showBurnAction = false
                    }
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }

                Text("Day \(currentDay)")
                    .font(.headline)
                    .padding()
            }
        }
        .padding()
        .alert(isPresented: $showDialog) {
            if showBurnAction {
                return Alert(
                    title: Text("Burn Cards"),
                    message: Text("Select up to \(maxBurnCards) cards to burn."),
                    primaryButton: .default(Text("Burn")) {
                        burnSelectedCards()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            } else {
                return Alert(
                    title: Text("Game Alert"),
                    message: Text(dialogMessage),
                    dismissButton: .default(Text("OK")))
            }
        }
    }

    private func listenToGameStateChanges() {
        db.collection("games").document(gameId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot, document.exists else {
                print("Error fetching game state: \(String(describing: error))")
                return
            }

            let gameData = document.data() ?? [:]
            if let newPlayerTurn = gameData["currentPlayerTurn"] as? Int {
                self.currentPlayerTurn = newPlayerTurn
            }
        }
    }

    func startGame() {
        deck.shuffleDeck()
        playerHand = []

        for _ in 0..<4 {
            if let card = deck.drawCard() {
                playerHand.append(card)
            }
        }

        currentDay = 1
        maxBurnCards = 3
        selectedBurnCards = []
        isMadeHand = false
        betPlaced = false
        playersTurnComplete = false
        isBetPhase = true

        db.collection("games").document(gameId).setData([
            "currentPlayerTurn": currentPlayerTurn,
            "currentDay": currentDay
        ])

        checkForMadeHand()
    }

    func burnSelectedCards() {
        for card in selectedBurnCards {
            if let index = playerHand.firstIndex(where: { $0.id == card.id }), let newCard = deck.drawCard() {
                playerHand[index] = newCard
            }
        }

        selectedBurnCards = []
        showDialog = false
        showBurnAction = false
        checkForMadeHand()

        nextPlayerTurn()
    }

    func playerCheck() {
        nextPlayerTurn()
    }

    func nextPlayerTurn() {
        currentPlayerTurn = (currentPlayerTurn + 1) % numberOfPlayers

        if currentPlayerTurn == 0 {
            playersTurnComplete = true
        }

        if playersTurnComplete && isBetPhase {
            isBetPhase = false // Move to burn phase
        } else if playersTurnComplete && !isBetPhase {
            progressToNextDay() // Progress the day after the burn phase
        }

        db.collection("games").document(gameId).updateData([
            "currentPlayerTurn": currentPlayerTurn
        ])
    }

    func checkForMadeHand() {
        let ranks = playerHand.map { $0.rank }
        let suits = playerHand.map { $0.suit }

        let uniqueRanks = Set(ranks)
        let uniqueSuits = Set(suits)

        if uniqueRanks.count == 4 && uniqueSuits.count == 4 {
            dialogMessage = "Congratulations! You have a made hand!"
            isMadeHand = true
        }
    }

    func revealHands() {
        dialogMessage = "All players reveal their hands!"
        showDialog = true
        gameOver = true
    }

    func progressToNextDay() {
        if currentDay < 3 {
            currentDay += 1

            switch currentDay {
            case 2:
                maxBurnCards = 2 // Day 2: burn up to 2 cards
            case 3:
                maxBurnCards = 1 // Day 3: burn 1 card
            default:
                maxBurnCards = 0
                revealHands() // End the game and reveal hands
            }

            db.collection("games").document(gameId).updateData([
                "currentDay": currentDay
            ])
        } else {
            revealHands()
        }
    }

    func toggleCardSelection(_ card: Card) {
        if selectedBurnCards.contains(where: { $0.id == card.id }) {
            selectedBurnCards.removeAll { $0.id == card.id }
        } else if selectedBurnCards.count < maxBurnCards {
            selectedBurnCards.append(card)
        }
    }
}
