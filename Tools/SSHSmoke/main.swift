import Foundation

let env = ProcessInfo.processInfo.environment
let config = HostConfig(
    host: env["SMOKE_HOST"] ?? "127.0.0.1",
    port: Int(env["SMOKE_PORT"] ?? "") ?? 22,
    username: env["SMOKE_USER"] ?? ""
)
let password = env["SMOKE_PASSWORD"] ?? ""
let suiteName = "ipadterm.smoke"
let knownHosts = KnownHosts(defaults: UserDefaults(suiteName: suiteName)!)
let storageKey = "knownHost.\(config.host):\(config.port)"

@MainActor
func waitFor(_ label: String, _ condition: () -> Bool) async -> Bool {
    for _ in 0..<200 where !condition() {
        try? await Task.sleep(for: .milliseconds(100))
    }
    print(condition() ? "ok: \(label)" : "FAIL: \(label)")
    return condition()
}

@MainActor
func interactiveSession(_ label: String) async -> Bool {
    let session = SSHSession(config: config, password: password, knownHosts: knownHosts)
    var output = ""
    session.start(cols: 80, rows: 24) { output += String(decoding: $0, as: UTF8.self) }

    guard await waitFor("\(label): connected", { session.phase == .connected }) else {
        print("  phase=\(session.phase)")
        return false
    }
    session.resize(cols: 132, rows: 40)
    session.send(ArraySlice("echo smoke-$((6*7)); stty size\n".utf8))
    guard await waitFor("\(label): command output", { output.contains("smoke-42") }) else { return false }
    guard await waitFor("\(label): resize reached remote pty", { output.contains("40 132") }) else { return false }
    session.send(ArraySlice("exit\n".utf8))
    return await waitFor("\(label): closed cleanly", { session.phase == .closed(reason: nil) })
}

@MainActor
func rejectsChangedHostKey() async -> Bool {
    let defaults = knownHosts.defaults
    let recorded = defaults.string(forKey: storageKey)
    guard await waitFor("host key recorded on first connect", { recorded != nil }) else { return false }
    defaults.set("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl", forKey: storageKey)
    defer { defaults.set(recorded, forKey: storageKey) }

    let session = SSHSession(config: config, password: password, knownHosts: knownHosts)
    session.start(cols: 80, rows: 24) { _ in }
    return await waitFor("changed host key rejected") {
        if case .closed(let reason?) = session.phase { return reason.contains("ホスト鍵") }
        return false
    }
}

@MainActor
func run() async -> Bool {
    knownHosts.defaults.removePersistentDomain(forName: suiteName)
    guard await interactiveSession("first connect") else { return false }
    guard await interactiveSession("reconnect with known key") else { return false }
    return await rejectsChangedHostKey()
}

exit(await run() ? 0 : 1)
