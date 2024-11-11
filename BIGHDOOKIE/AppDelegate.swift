import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseFunctions
import UserNotifications
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        // Set up notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Notification permission granted: \(granted)")
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return true
    }

    // Handle Firebase Messaging registration token updates
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(fcmToken ?? "")")
        
        // Optional: Send token to the server if needed
    }

    // Display notification when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }

    // Handle notification taps, including custom actions like "summon"
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let action = userInfo["action"] as? String, action == "summon" {
            presentSummonAlert()
        }
        
        completionHandler()
    }

    // Present alert to ask user to join the game
    private func presentSummonAlert() {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "You’ve been summoned!", message: "Do you want to join the game?", preferredStyle: .alert)
            
            let joinAction = UIAlertAction(title: "Join", style: .default) { _ in
                self.navigateToGame()
            }
            alertController.addAction(joinAction)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }

    // Navigate to the ContentView (game screen) in SwiftUI
    private func navigateToGame() {
        DispatchQueue.main.async {
            if let rootVC = self.window?.rootViewController as? UINavigationController {
                let gameSession = GameSession() // Initialize GameSession as needed
                let contentView = ContentView(numberOfPlayers: 2, gameSession: gameSession) // Adjust ContentView parameters as necessary
                let gameViewController = UIHostingController(rootView: contentView)
                rootVC.pushViewController(gameViewController, animated: true)
            }
        }
    }
}
