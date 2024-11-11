import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import FirebaseFunctions
import FirebaseMessaging

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = true

    init() {
        checkLoginStatus()
    }

    // Check if the user is logged in or not
    func checkLoginStatus() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let user = user {
                    self?.isLoggedIn = true
                    self?.setupUserDocument(user: user)
                    self?.setupGameSession(for: user) // Ensure game session document exists
                } else {
                    self?.isLoggedIn = false
                }
            }
        }
    }

    // Ensure Firestore document structure for the user
    func setupUserDocument(user: User) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                print("User document exists")
            } else {
                // Document doesn't exist, create with initial fields
                userRef.setData([
                    "email": user.email ?? "",
                    "displayName": user.displayName ?? "Player",
                    "createdAt": Timestamp(),
                    "profileImageURL": ""
                ]) { error in
                    if let error = error {
                        print("Error creating user document: \(error.localizedDescription)")
                    } else {
                        print("User document created successfully")
                    }
                }
            }
        }
    }

    // Ensure Firestore document structure for the game session
    func setupGameSession(for user: User) {
        let db = Firestore.firestore()
        let gameSessionRef = db.collection("gameSessions").document(user.uid)

        gameSessionRef.getDocument { document, error in
            if let document = document, document.exists {
                print("Game session document exists for user \(user.uid)")
            } else {
                // Initialize game session document with default values
                gameSessionRef.setData([
                    "state": "initial",
                    "createdAt": Timestamp(),
                    "players": []
                ]) { error in
                    if let error = error {
                        print("Error creating game session document: \(error.localizedDescription)")
                    } else {
                        print("Game session document created successfully for user \(user.uid)")
                    }
                }
            }
        }
    }

    // Login function
    func login(email: String, password: String, completion: @escaping (String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(error.localizedDescription)
            } else {
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                }
                completion(nil)
            }
        }
    }

    // Register function with displayName
    func register(email: String, password: String, username: String, completion: @escaping (String?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(error.localizedDescription)
            } else if let user = result?.user {
                // Update the display name in Firebase Auth profile
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        completion("Error updating profile: \(error.localizedDescription)")
                    } else {
                        // Ensure user and game session documents are created
                        self.setupUserDocument(user: user)
                        self.setupGameSession(for: user)
                        completion(nil)
                    }
                }
            }
        }
    }

    // Logout function
    func logout() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isLoggedIn = false
            }
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
        }
    }
}
