import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            List {
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
}
