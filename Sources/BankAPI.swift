import Foundation

enum BankAPI {
    // Injected at build time from the BANK_BASE_URL secret (public repo:
    // endpoints stay out of source control).
    static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "BankBaseURL") as? String) ?? ""
    }

    static func registerDevice(token: String, user: String, state: AppState) async {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)/devices") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "user": user])
        let code = (try? await URLSession.shared.data(for: req))
            .flatMap { ($0.1 as? HTTPURLResponse)?.statusCode } ?? 0
        await MainActor.run { state.registered = (code == 200) }
    }

    static func refreshAccount(state: AppState) async {
        let user = await state.accountHolder
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)/account/\(user)") else { return }
        guard let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let acct = try? JSONDecoder().decode(Account.self, from: data) else { return }
        await MainActor.run {
            state.balance = acct.balance
            state.currency = acct.currency
            state.transactions = acct.transactions
        }
    }

    @discardableResult
    static func approve(urlString: String, state: AppState) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return false }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        return code == 200 && body.contains("Approved")
    }
}
