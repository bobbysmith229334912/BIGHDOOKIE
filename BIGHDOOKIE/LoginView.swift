import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import FirebaseFunctions
import FirebaseMessaging


struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var username: String = "" // New state for username
    @State private var isRegistering: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false // Loading state

    var body: some View {
        VStack {
            Text(isRegistering ? "Register" : "Login")
                .font(.largeTitle)
                .padding()

            if isRegistering {
                // Show the username field during registration
                TextField("Username", text: $username)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .disableAutocorrection(true)
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .disableAutocorrection(true)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

            // Error message display
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.bottom, 10)
            }

            // Show loading spinner while processing login/register
            if isLoading {
                ProgressView()
                    .padding()
            }

            // Login/Register button
            Button(isRegistering ? "Register" : "Login") {
                if isValidInput() {
                    isLoading = true
                    isRegistering ? register() : login()
                }
            }
            .disabled(!isValidInput() || isLoading) // Disable button if input is invalid or loading
            .padding()
            .background(isValidInput() ? Color.blue : Color.gray) // Button color changes based on validity
            .foregroundColor(.white)
            .cornerRadius(8)

            // Toggle between Login and Register
            Button(isRegistering ? "Already have an account? Login" : "Don't have an account? Register") {
                isRegistering.toggle()
            }
            .padding()
        }
        .padding()
    }

    // Login function
    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false // Stop loading
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                // Successfully logged in, navigate to profile view
                errorMessage = nil
                authViewModel.isLoggedIn = true
            }
        }
    }

    // Register function
    private func register() {
        guard !username.isEmpty else {
            errorMessage = "Username cannot be empty."
            isLoading = false
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            isLoading = false // Stop loading
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let result = result {
                // Successfully registered, update the isLoggedIn state
                errorMessage = nil

                // Save user data to Firestore
                let db = Firestore.firestore()
                let userRef = db.collection("users").document(result.user.uid)

                userRef.setData([
                    "email": email,
                    "username": username, // Save the username to Firestore
                    "createdAt": Timestamp()
                ]) { err in
                    if let err = err {
                        errorMessage = "Error saving user data: \(err.localizedDescription)"
                    } else {
                        authViewModel.isLoggedIn = true
                    }
                }

                // Optionally update the Firebase Authentication profile to include displayName (username)
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = username
                changeRequest.commitChanges { error in
                    if let error = error {
                        errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // Helper function to check if the input is valid
    private func isValidInput() -> Bool {
        return !email.isEmpty && !password.isEmpty && email.contains("@") && (!isRegistering || !username.isEmpty)
    }
}
