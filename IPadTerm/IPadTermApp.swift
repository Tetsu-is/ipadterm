import SwiftUI

@main
struct IPadTermApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var session: SSHSession?

    var body: some View {
        if let session {
            SessionView(session: session) {
                session.disconnect()
                self.session = nil
            }
        } else {
            ConnectView { config, password in
                session = SSHSession(config: config, password: password)
            }
        }
    }
}

struct ConnectView: View {
    let onConnect: (HostConfig, String) -> Void

    @AppStorage("host") private var host = ""
    @AppStorage("port") private var port = 22
    @AppStorage("username") private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("接続先") {
                    TextField("ホスト (例: 192.168.1.10)", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("ポート", value: $port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                    TextField("ユーザー名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $password)
                }
                Button("接続") {
                    onConnect(HostConfig(host: host, port: port, username: username), password)
                    password = ""
                }
                .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
            }
            .navigationTitle("ipadterm")
        }
    }
}

struct SessionView: View {
    let session: SSHSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(session.config.username)@\(session.config.host)")
                    .font(.caption.monospaced())
                Spacer()
                statusLabel
                Button(isClosed ? "戻る" : "切断", action: onClose)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            TerminalScreen(session: session)
        }
    }

    private var isClosed: Bool {
        if case .closed = session.phase { return true }
        return false
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch session.phase {
        case .connecting:
            ProgressView()
        case .connected:
            EmptyView()
        case .closed(let reason):
            Text(reason.map { "切断: \($0)" } ?? "切断されました")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
