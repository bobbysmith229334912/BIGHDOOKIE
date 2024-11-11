import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct ProfileView: View {
    @State private var userEmail: String = ""
    @State private var displayName: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var selectedPlayMode: String = ""
    @State private var navigateToLocalPlay = false
    @State private var navigateToOnlinePlay = false
    @State private var numberOfHumanPlayers: Int = 2
    @State private var showConfirmationDialog = false
    @State private var showImagePicker = false
    @State private var profileImage: UIImage? = nil
    @State private var profileImageURL: URL? = nil
    @State private var isDarkMode = false

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gameSession: GameSession

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                VStack {
                    if isLoading {
                        ProgressView("Loading Profile...")
                            .padding()
                            .transition(.opacity)
                    } else {
                        profileDetails
                            .transition(.move(edge: .bottom))
                    }
                }
                .padding()
                .onAppear {
                    loadUserProfile()
                    isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
                }
            }
            .navigationDestination(isPresented: $navigateToLocalPlay) {
                PlayerSelectionView(
                    gameSession: _gameSession
                )
                .environmentObject(gameSession)
            }
            .navigationDestination(isPresented: $navigateToOnlinePlay) {
                OnlinePlayView(numberOfHumanPlayers: numberOfHumanPlayers)
            }

        }
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("Confirm Logout"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Logout")) {
                    logout()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            if let profileImage = profileImage {
                uploadProfileImage(profileImage)
            }
        }) {
            ImagePicker(image: $profileImage)
        }
    }

    var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: isDarkMode ? [Color.gray, Color.black] : [Color.cyan, Color.purple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .blur(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
        )
    }

    var profileDetails: some View {
        VStack(spacing: 20) {
            profileInfoSection
                .shadow(radius: 10)
            
            profileProgressSection

            playModeSelection
                .shadow(radius: 10)

            logoutButton
                .padding(.top, 30)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.2)).shadow(radius: 10))
        .scaleEffect(1.05)
    }

    var profileInfoSection: some View {
        VStack(spacing: 10) {
            if let profileImageURL = profileImageURL {
                AsyncImage(url: profileImageURL) { image in
                    image.resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 10)
                        .onTapGesture {
                            showImagePicker.toggle()
                        }
                } placeholder: {
                    ProgressView()
                        .frame(width: 120, height: 120)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
            } else {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                    .onTapGesture {
                        showImagePicker.toggle()
                    }
            }

            Text(displayName.isEmpty ? "No Display Name" : displayName)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .shadow(radius: 5)

            Text("Email: \(userEmail)")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .transition(.opacity)
        }
    }

    var profileProgressSection: some View {
        VStack {
            Text("Profile Completion")
                .font(.headline)
                .foregroundColor(.white)

            ProgressView(value: profileCompletionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.green))
                .padding()
        }
    }

    var profileCompletionProgress: Double {
        var completion = 0.0
        if !userEmail.isEmpty { completion += 0.33 }
        if !displayName.isEmpty { completion += 0.33 }
        if profileImageURL != nil { completion += 0.34 }
        return completion
    }

    var playModeSelection: some View {
        VStack {
            Text("Select Play Mode")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)
                .transition(.slide)

            HStack {
                playModeButton(text: "Local Play", color: .blue) {
                    selectedPlayMode = "Local"
                    navigateToLocalPlay = true
                }

                playModeButton(text: "Online Play", color: .green) {
                    selectedPlayMode = "Online"
                    navigateToOnlinePlay = true
                }
            }
            .padding()
        }
    }

    func playModeButton(text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(radius: 10)
                .scaleEffect(1.1)
        }
        .padding(.horizontal, 10)
    }

    var logoutButton: some View {
        Button(action: {
            showConfirmationDialog.toggle()
        }) {
            Text("Log Out")
                .bold()
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(15)
                .scaleEffect(1.2)
                .shadow(radius: 10)
        }
    }

    private func loadUserProfile() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No user is logged in."
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)

        userRef.addSnapshotListener { document, error in
            if let error = error {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
            } else if let document = document, document.exists, let data = document.data() {
                userEmail = data["email"] as? String ?? "No email"
                displayName = data["displayName"] as? String ?? currentUser.displayName ?? "No display name"
                if let profileImageURLString = data["profileImageURL"] as? String,
                   let url = URL(string: profileImageURLString) {
                    profileImageURL = url
                }
                errorMessage = nil
            } else {
                errorMessage = "Profile not found."
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }

    private func uploadProfileImage(_ image: UIImage) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(currentUser.uid).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error)")
                self.errorMessage = "Failed to upload image."
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error fetching download URL: \(error)")
                    self.errorMessage = "Failed to get image URL."
                    return
                }
                
                if let url = url {
                    self.profileImageURL = url
                    self.saveProfileImageURLToFirestore(url: url)
                }
            }
        }
    }

    private func saveProfileImageURLToFirestore(url: URL) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)
        
        userRef.updateData(["profileImageURL": url.absoluteString]) { error in
            if let error = error {
                print("Error saving profile image URL to Firestore: \(error)")
                self.errorMessage = "Failed to save image URL."
            }
        }
    }

    private func logout() {
        do {
            try Auth.auth().signOut()
            errorMessage = nil
        } catch let signOutError as NSError {
            errorMessage = "Error signing out: \(signOutError.localizedDescription)"
        }
    }
}
