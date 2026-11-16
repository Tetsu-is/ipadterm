import Citadel
import Foundation
import NIOCore
import NIOSSH
import Observation

struct HostConfig: Equatable {
    var host: String
    var port: Int
    var username: String
}

enum SessionPhase: Equatable {
    case connecting
    case connected
    case closed(reason: String?)
}

@MainActor
@Observable
final class SSHSession {
    private enum Outbound {
        case bytes([UInt8])
        case resize(cols: Int, rows: Int)
    }

    let config: HostConfig
    private(set) var phase: SessionPhase = .connecting

    private let password: String
    private let outbound: AsyncStream<Outbound>
    private let outboundContinuation: AsyncStream<Outbound>.Continuation
    private var task: Task<Void, Never>?

    init(config: HostConfig, password: String) {
        self.config = config
        self.password = password
        (outbound, outboundContinuation) = AsyncStream.makeStream(of: Outbound.self)
    }

    func start(cols: Int, rows: Int, onOutput: @escaping @MainActor (ArraySlice<UInt8>) -> Void) {
        guard task == nil else { return }
        task = Task { [config, password, outbound] in
            do {
                // TODO: known_hosts 相当の検証。MVP では中間者攻撃を検出できない。
                let client = try await SSHClient.connect(
                    host: config.host,
                    port: config.port,
                    authenticationMethod: .passwordBased(username: config.username, password: password),
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never
                )
                let request = SSHChannelRequestEvent.PseudoTerminalRequest(
                    wantReply: true,
                    term: "xterm-256color",
                    terminalCharacterWidth: cols,
                    terminalRowHeight: rows,
                    terminalPixelWidth: 0,
                    terminalPixelHeight: 0,
                    terminalModes: SSHTerminalModes([:])
                )
                try await client.withPTY(request) { inbound, writer in
                    await MainActor.run { self.phase = .connected }
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for try await chunk in inbound {
                                switch chunk {
                                case .stdout(let buffer), .stderr(let buffer):
                                    let bytes = ArraySlice(buffer.readableBytesView)
                                    await onOutput(bytes)
                                }
                            }
                        }
                        group.addTask {
                            for await message in outbound {
                                switch message {
                                case .bytes(let bytes):
                                    try await writer.write(ByteBuffer(bytes: bytes))
                                case .resize(let cols, let rows):
                                    try await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
                                }
                            }
                        }
                        try await group.next()
                        group.cancelAll()
                    }
                }
                try? await client.close()
                self.phase = .closed(reason: nil)
            } catch ChannelError.alreadyClosed {
                // リモートで `exit` するとチャネルが先に閉じ、Citadel の後始末の close がこれを投げる。
                self.phase = .closed(reason: nil)
            } catch {
                self.phase = .closed(reason: String(describing: error))
            }
        }
    }

    nonisolated func send(_ bytes: ArraySlice<UInt8>) {
        outboundContinuation.yield(.bytes(Array(bytes)))
    }

    nonisolated func resize(cols: Int, rows: Int) {
        outboundContinuation.yield(.resize(cols: cols, rows: rows))
    }

    func disconnect() {
        outboundContinuation.finish()
        task?.cancel()
    }
}
