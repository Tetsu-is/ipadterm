import Foundation

let env = ProcessInfo.processInfo.environment
let config = HostConfig(
    host: env["SMOKE_HOST"] ?? "127.0.0.1",
    port: Int(env["SMOKE_PORT"] ?? "") ?? 22,
    username: env["SMOKE_USER"] ?? ""
)

@MainActor
func run() async -> Bool {
    let session = SSHSession(config: config, password: env["SMOKE_PASSWORD"] ?? "")
    var output = ""
    session.start(cols: 80, rows: 24) { bytes in
        output += String(decoding: bytes, as: UTF8.self)
    }

    func waitFor(_ label: String, _ condition: () -> Bool) async -> Bool {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(100))
        }
        print(condition() ? "ok: \(label)" : "FAIL: \(label) (phase=\(session.phase))")
        return condition()
    }

    guard await waitFor("connected", { session.phase == .connected }) else { return false }
    session.resize(cols: 132, rows: 40)
    session.send(ArraySlice("echo smoke-$((6*7)); stty size\n".utf8))
    guard await waitFor("command output", { output.contains("smoke-42") }) else { return false }
    guard await waitFor("resize reached remote pty", { output.contains("40 132") }) else { return false }
    session.send(ArraySlice("exit\n".utf8))
    return await waitFor("closed cleanly", { session.phase == .closed(reason: nil) })
}

exit(await run() ? 0 : 1)
