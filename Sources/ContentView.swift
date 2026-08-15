import SwiftUI
import LocalAuthentication

// MARK: - Palette (matches the app icon: indigo→teal, green approval check)

enum Brand {
    static let indigo  = Color(red: 0.106, green: 0.145, blue: 0.349) // #1B2559
    static let teal    = Color(red: 0.055, green: 0.455, blue: 0.565) // #0E7490
    static let approve = Color(red: 0.122, green: 0.659, blue: 0.353) // #1FA85A
    static let deny    = Color(red: 0.714, green: 0.290, blue: 0.290) // #B64A4A
    static let appBg   = Color(red: 0.957, green: 0.969, blue: 0.988) // #F4F7FC
    static let ink     = Color(red: 0.102, green: 0.133, blue: 0.200) // #1A2233
    static let muted   = Color(red: 0.400, green: 0.439, blue: 0.522) // #667085
    static let cardLine = Color(red: 0.918, green: 0.933, blue: 0.965)
    static let gradient = LinearGradient(colors: [indigo, teal],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

func euro(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency; f.currencyCode = "EUR"; f.currencySymbol = "€"
    f.locale = Locale(identifier: "en_IE")
    return f.string(from: NSNumber(value: v)) ?? "€\(v)"
}

func avatarColor(_ name: String) -> Color {
    let palette: [Color] = [.init(red: 0.184, green: 0.49, blue: 0.335),
                            .init(red: 0.357, green: 0.42, blue: 0.549),
                            .init(red: 0.549, green: 0.42, blue: 0.247),
                            .init(red: 0.36, green: 0.32, blue: 0.55)]
    return palette[abs(name.hashValue) % palette.count]
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        HomeView()
            .fullScreenCover(item: $state.pending) { p in ApprovalView(pending: p) }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack(alignment: .top) {
            Brand.appBg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) { explainer; activity }.padding(16)
                }
                .refreshable { await BankAPI.refreshAccount(state: state) }
            }
        }
        .task { await BankAPI.refreshAccount(state: state) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Text("€")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                Text("Agentic Bank").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(state.accountHolder)
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }
            Text("AVAILABLE BALANCE")
                .font(.system(size: 12, weight: .semibold)).tracking(0.8)
                .opacity(0.8).padding(.top, 20)
            Text(state.balance.map(euro) ?? "—")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit().padding(.top, 1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.gradient.ignoresSafeArea(edges: .top))
        .clipShape(.rect(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18)).foregroundStyle(Brand.approve)
                .frame(width: 34, height: 34)
                .background(Brand.approve.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Your agent asks. You approve.")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Brand.ink)
                Text("An AI agent can request payments but can never send them. You get a notification and release it with Face ID.")
                    .font(.system(size: 12.5)).foregroundStyle(Brand.muted)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Brand.cardLine))
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold)).tracking(1.1)
                .foregroundStyle(Brand.muted.opacity(0.9)).padding(.leading, 2)
            VStack(spacing: 0) {
                if state.transactions.isEmpty {
                    Text("No activity yet").font(.system(size: 13)).foregroundStyle(Brand.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                }
                ForEach(Array(state.transactions.enumerated()), id: \.element.id) { i, tx in
                    if i > 0 { Divider().overlay(Brand.cardLine) }
                    txRow(tx)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Brand.cardLine))
        }
    }

    private func txRow(_ tx: BankTx) -> some View {
        HStack(spacing: 12) {
            Text(tx.counterparty.prefix(1).uppercased())
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(avatarColor(tx.counterparty), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(tx.direction == "out" ? "To \(tx.to)" : "From \(tx.from)")
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Brand.ink)
                Text(tx.description).font(.system(size: 11.5)).foregroundStyle(Brand.muted)
            }
            Spacer()
            Text((tx.direction == "out" ? "−" : "+") + euro(tx.amount))
                .font(.system(size: 13.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(tx.direction == "out" ? Brand.ink : Brand.approve)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Approval

struct ApprovalView: View {
    let pending: PendingApproval
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var done = false

    var body: some View {
        ZStack(alignment: .top) {
            Brand.appBg.ignoresSafeArea()
            VStack(spacing: 0) {
                hero
                VStack(spacing: 14) {
                    detail
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").foregroundStyle(Brand.teal)
                        Text("Verified through PingGateway · expires in 15 min")
                    }
                    .font(.system(size: 11.5)).foregroundStyle(Brand.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 8)
                    actions
                }
                .padding(18)
            }
            if done { successOverlay }
        }
    }

    private var hero: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color(red: 0.43, green: 0.9, blue: 0.63)).frame(width: 7, height: 7)
                Text("Approval requested by your agent").font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.15), in: Capsule())
            Text("PAYMENT").font(.system(size: 12, weight: .semibold)).tracking(1.0)
                .foregroundStyle(.white.opacity(0.82)).padding(.top, 18)
            Text(pending.amountText)
                .font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 14) {
                partyView(pending.from)
                Image(systemName: "arrow.right").foregroundStyle(.white.opacity(0.7))
                partyView(pending.to)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(Brand.gradient.ignoresSafeArea(edges: .top))
        .clipShape(.rect(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
    }

    private func partyView(_ name: String) -> some View {
        VStack(spacing: 6) {
            Text(name.prefix(1).uppercased())
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.18), in: Circle())
            Text(name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            detailRow("Reference", pending.reference.isEmpty ? "—" : pending.reference)
            Divider().overlay(Brand.cardLine)
            detailRow("Requested", "just now")
            Divider().overlay(Brand.cardLine)
            HStack {
                Text("Authorized scope").foregroundStyle(Brand.muted)
                Spacer()
                Text("transfers:write")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Brand.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Brand.indigo)
            }
            .font(.system(size: 13)).padding(.vertical, 11)
        }
        .padding(.horizontal, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.cardLine))
    }

    private func detailRow(_ l: String, _ r: String) -> some View {
        HStack {
            Text(l).foregroundStyle(Brand.muted)
            Spacer()
            Text(r).fontWeight(.semibold).foregroundStyle(Brand.ink)
        }
        .font(.system(size: 13)).padding(.vertical, 11)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: approve) {
                HStack(spacing: 9) {
                    if working { ProgressView().tint(.white) }
                    else { Image(systemName: "faceid").font(.system(size: 19)) }
                    Text(working ? "Approving…" : "Approve with Face ID")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(15)
                .background(Brand.approve, in: RoundedRectangle(cornerRadius: 15))
                .shadow(color: Brand.approve.opacity(0.5), radius: 12, y: 6)
            }
            .disabled(working)
            Button("Deny", role: .destructive) { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Brand.deny).padding(.vertical, 4)
        }
    }

    private var successOverlay: some View {
        ZStack {
            Brand.gradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72)).foregroundStyle(.white)
                Text("Payment sent").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                Text("\(pending.amountText) to \(pending.to)")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .transition(.opacity)
    }

    private func approve() {
        working = true
        let ctx = LAContext()
        var err: NSError?
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
            ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        let reason = "Approve \(pending.amountText) to \(pending.to)"
        ctx.evaluatePolicy(policy, localizedReason: reason) { ok, _ in
            guard ok else { Task { @MainActor in working = false }; return }
            Task { @MainActor in
                let success = await BankAPI.approve(urlString: pending.approveURL, state: state)
                working = false
                if success {
                    await BankAPI.refreshAccount(state: state)
                    withAnimation { done = true }
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    dismiss()
                }
            }
        }
    }
}
