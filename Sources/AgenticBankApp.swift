// Agentic Bank — the maker-checker approver for the agentic-banking demo.
// An AI agent can only REQUEST payments; this app is where the human releases
// them. A push notification carries the transfer, and Approve is gated by
// Face ID (authenticationRequired on the action, biometrics in-app).
import SwiftUI
import UserNotifications

@main
struct AgenticBankApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appDelegate.state)
                .preferredColorScheme(.light) // committed light fintech look
        }
    }
}

// MARK: - Models

struct BankTx: Identifiable, Decodable {
    let id: String
    let from: String
    let to: String
    let amount: Double
    let description: String
    let direction: String   // "in" | "out"
    var counterparty: String { direction == "out" ? to : from }
}

struct Account: Decodable {
    let balance: Double
    let currency: String
    let transactions: [BankTx]
}

struct PendingApproval: Identifiable, Decodable {
    let id: String          // server's PT-... id (stable across push and fetch)
    let from: String
    let to: String
    let amountText: String
    let reference: String
    let approveURL: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var accountHolder: String = UserDefaults.standard.string(forKey: "accountHolder") ?? "alice"
    @Published var deviceToken: String?
    @Published var registered = false
    @Published var balance: Double?
    @Published var currency = "EUR"
    @Published var transactions: [BankTx] = []
    @Published var pending: PendingApproval?
    // Open approvals fetched from the server - the app does not depend on
    // push delivery (Focus mode, force-quit, swiped-away banner).
    @Published var waiting: [PendingApproval] = []
}

// MARK: - Push / lifecycle

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let state = AppState()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let approve = UNNotificationAction(identifier: "APPROVE", title: "Approve", options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: "DENY", title: "Deny", options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "TRANSFER_APPROVAL", actions: [approve, deny],
                                   intentIdentifiers: [], options: [])
        ])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            state.deviceToken = token
            await BankAPI.registerDevice(token: token, user: state.accountHolder, state: state)
            await BankAPI.refreshAccount(state: state)
            await BankAPI.fetchPending(state: state)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let approveURL = info["approveURL"] as? String else { return }
        let pending = PendingApproval(
            id: info["id"] as? String ?? UUID().uuidString,
            from: info["from"] as? String ?? state.accountHolder,
            to: info["to"] as? String ?? "recipient",
            amountText: info["amountText"] as? String ?? "",
            reference: info["reference"] as? String ?? "",
            approveURL: approveURL
        )
        switch response.actionIdentifier {
        case "APPROVE":
            _ = await BankAPI.approve(urlString: approveURL, state: state)
            await BankAPI.refreshAccount(state: state)
        case "DENY":
            break
        default:
            state.pending = pending   // tapped the body -> open in-app approval
        }
    }
}
