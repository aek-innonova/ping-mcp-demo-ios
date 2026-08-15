// Agentic Bank - the maker-checker approver for the agentic-banking demo.
// An AI agent can only REQUEST transfers; this app is where the human
// approves them: a push notification carries the approval capability URL,
// and the Approve action is gated by FaceID/passcode (authenticationRequired).
import SwiftUI
import UserNotifications

@main
struct AgenticBankApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.state)
        }
    }
}

struct PendingApproval: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let approveURL: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var accountHolder: String = UserDefaults.standard.string(forKey: "accountHolder") ?? "alice"
    @Published var deviceToken: String?
    @Published var registrationStatus: String = "not registered"
    @Published var log: [String] = []
    @Published var pending: PendingApproval?

    nonisolated func append(_ line: String) {
        Task { @MainActor in
            self.log.insert("\(Self.time()) \(line)", at: 0)
            if self.log.count > 50 { self.log.removeLast() }
        }
    }

    nonisolated static func time() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let state = AppState()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Approve is FaceID/passcode-gated by iOS itself; works from the lock screen.
        let approve = UNNotificationAction(
            identifier: "APPROVE",
            title: "Approve",
            options: [.authenticationRequired]
        )
        let deny = UNNotificationAction(
            identifier: "DENY",
            title: "Deny",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "TRANSFER_APPROVAL",
            actions: [approve, deny],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.state.append("notification permission: \(granted ? "granted" : "denied")")
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        state.deviceToken = token
        state.append("APNs token acquired")
        Task { await BankAPI.registerDevice(token: token, user: self.state.accountHolder, state: self.state) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        state.append("APNs registration failed: \(error.localizedDescription)")
    }

    // Show notifications even when the app is foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Approve/Deny action from the (lock-screen) notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let approveURL = info["approveURL"] as? String else {
            state.append("notification without approveURL")
            return
        }
        switch response.actionIdentifier {
        case "APPROVE":
            state.append("approving via FaceID-gated action…")
            await BankAPI.approve(urlString: approveURL, state: state)
        case "DENY":
            state.append("denied transfer request")
        default:
            // Tapped the notification body -> show an in-app approval card
            let content = response.notification.request.content
            state.pending = PendingApproval(
                title: content.title,
                body: content.body,
                approveURL: approveURL
            )
            state.append("opened transfer request in app")
        }
    }
}
