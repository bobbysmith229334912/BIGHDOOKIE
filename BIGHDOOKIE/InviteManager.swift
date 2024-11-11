import FirebaseFunctions
import Combine

class InviteManager: ObservableObject {
    private lazy var functions = Functions.functions()
    
    func sendInviteMessage(toUser username: String, completion: @escaping (Result<String, Error>) -> Void) {
        let data: [String: Any] = [
            "title": "Game Invite",
            "body": "You've been invited to join a game session.",
            "username": username
        ]
        
        functions.httpsCallable("sendInviteMessage").call(data) { result, error in
            if let error = error as NSError? {
                completion(.failure(error))
            } else if let resultData = result?.data as? [String: Any],
                      let message = resultData["message"] as? String {
                completion(.success(message))
            } else {
                completion(.failure(NSError(domain: "InviteError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected data format."])))
            }
        }
    }
}
