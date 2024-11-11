import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseCrashlytics
import FirebaseFunctions
import FirebaseMessaging
import SwiftData

@main
struct BIGHDOOKIEApp: App {
    // Connect AppDelegate to the SwiftUI lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var gameSession = GameSession()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                ProfileView()
                    .environmentObject(authViewModel)
                    .environmentObject(gameSession)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
