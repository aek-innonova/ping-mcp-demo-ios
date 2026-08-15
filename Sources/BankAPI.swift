import Foundation

enum BankAPI {
    // Injected at build time from the BANK_BASE_URL secret (public repo:
    // endpoints stay out of source control).
    static var baseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "BankBaseURL") as? String) ?? ""
    }

    static func registerDevice(token: String, user: String, state: AppState) async {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)/devices") else {
            state.append("no BankBaseURL configured")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "user": user])
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async { state.registrationStatus = code == 200 ? "registered as \(user)" : "registration failed (\(code))" }
            state.append("device registration: HTTP \(code)")
        } catch {
            DispatchQueue.main.async { state.registrationStatus = "registration error" }
            state.append("device registration error: \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func approve(urlString: String, state: AppState) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            if code == 200, body.contains("Approved") {
                state.append("transfer APPROVED and executed")
                return true
            }
            state.append("approve response: HTTP \(code)")
            return false
        } catch {
            state.append("approve error: \(error.localizedDescription)")
            return false
        }
    }
}
