import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            List {
                if let p = state.pending {
                    Section("Transfer request") {
                        Text(p.body).font(.headline)
                        Text("Requested by your AI agent. Approve to execute.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button {
                            approve(p)
                        } label: {
                            Label("Approve with Face ID", systemImage: "faceid")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Dismiss", role: .cancel) { state.pending = nil }
                    }
                }
                Section("Account") {
                    HStack {
                        Text("Holder")
                        Spacer()
                        TextField("account", text: $state.accountHolder)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .onSubmit {
                                UserDefaults.standard.set(state.accountHolder, forKey: "accountHolder")
                                if let t = state.deviceToken {
                                    Task { await BankAPI.registerDevice(token: t, user: state.accountHolder, state: state) }
                                }
                            }
                    }
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(state.registrationStatus).foregroundStyle(.secondary)
                    }
                }
                Section("How it works") {
                    Text("Your AI agent can request transfers but can never execute them. When it does, you get a push notification here — Approve is protected by Face ID. You press send on money. Always.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Activity") {
                    if state.log.isEmpty {
                        Text("No activity yet").foregroundStyle(.secondary)
                    }
                    ForEach(state.log, id: \.self) { line in
                        Text(line).font(.system(.footnote, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Agentic Bank")
        }
    }

    private func approve(_ p: PendingApproval) {
        let ctx = LAContext()
        var err: NSError?
        let reason = "Approve transfer: \(p.body)"
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                guard ok else { return }
                Task { @MainActor in
                    let done = await BankAPI.approve(urlString: p.approveURL, state: state)
                    if done { state.pending = nil }
                }
            }
        } else {
            Task { @MainActor in
                let done = await BankAPI.approve(urlString: p.approveURL, state: state)
                if done { state.pending = nil }
            }
        }
    }
}
