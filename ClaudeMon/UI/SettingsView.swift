import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var pastedKey: String = ""
    @State private var status: SaveStatus = .idle
    @AppStorage("refreshIntervalSeconds") private var refreshInterval: Int = 60
    var onSaved: () -> Void = {}

    private let intervalOptions: [Int] = [30, 60, 120, 300, 600]

    enum SaveStatus { case idle, saved, error(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sign in to ClaudeMon")
                .font(.headline)

            Button {
                CookieExtractor.presentInteractiveSignIn(
                    onSuccess: { key in
                        do {
                            try KeychainStore.setSessionKey(key)
                            status = .saved
                            onSaved()
                        } catch {
                            status = .error("Keychain error: \(error)")
                        }
                    },
                    onCancel: { /* no-op; user can retry */ })
            } label: {
                Label("Sign in to Claude", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)

            Picker("Refresh every", selection: $refreshInterval) {
                ForEach(intervalOptions, id: \.self) { seconds in
                    Text(label(forSeconds: seconds)).tag(seconds)
                }
            }
            .pickerStyle(.menu)

            Divider()

            HStack {
                Spacer()
                Button("Quit ClaudeMon") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }

            DisclosureGroup("Advanced: paste cookie manually") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("""
                    1. Open Chrome / Safari and sign in to claude.ai.
                    2. Press ⌥⌘I to open DevTools.
                    3. Application tab → Storage → Cookies → https://claude.ai.
                    4. Find sessionKey, double-click its Value, copy.
                    5. Paste it below. Starts with sk-ant-sid01-.
                    """)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    SecureField("sk-ant-sid01-...", text: $pastedKey)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Save") { save() }
                            .disabled(pastedKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Clear", role: .destructive) {
                            KeychainStore.delete()
                            pastedKey = ""
                            status = .idle
                        }
                        Spacer()
                        statusLabel
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .idle: EmptyView()
        case .saved: Text("Saved").foregroundStyle(.green).font(.caption)
        case .error(let m): Text(m).foregroundStyle(.red).font(.caption)
        }
    }

    private func save() {
        do {
            try KeychainStore.setSessionKey(pastedKey.trimmingCharacters(in: .whitespacesAndNewlines))
            status = .saved
            onSaved()
        } catch {
            status = .error("Keychain error: \(error)")
        }
    }

    private func label(forSeconds s: Int) -> String {
        if s < 60 { return "\(s)s" }
        if s % 60 == 0 { return "\(s / 60) min" }
        return "\(s)s"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue { try SMAppService.mainApp.register() }
                    else        { try SMAppService.mainApp.unregister() }
                } catch {
                    status = .error("Launch-at-login: \(error)")
                }
            }
        )
    }
}
