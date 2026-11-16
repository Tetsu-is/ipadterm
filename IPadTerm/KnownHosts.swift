import Citadel
import Foundation
import NIOCore
import NIOSSH

struct HostKeyMismatch: Error, CustomStringConvertible {
    let host: String
    var description: String {
        "\(host) のホスト鍵が前回と異なります。PC の再インストールでなければ中間者攻撃の可能性があります。"
    }
}

/// 初回接続時の鍵を信頼して記録し (TOFU)、以降は一致を要求する。
struct KnownHosts: @unchecked Sendable {
    var defaults: UserDefaults = .standard

    func validator(for config: HostConfig) -> SSHHostKeyValidator {
        .custom(Validator(storageKey: "knownHost.\(config.host):\(config.port)", host: config.host, defaults: defaults))
    }

    private struct Validator: NIOSSHClientServerAuthenticationDelegate {
        let storageKey: String
        let host: String
        let defaults: UserDefaults

        func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
            let presented = String(openSSHPublicKey: hostKey)
            switch defaults.string(forKey: storageKey) {
            case nil:
                defaults.set(presented, forKey: storageKey)
                validationCompletePromise.succeed(())
            case presented:
                validationCompletePromise.succeed(())
            default:
                validationCompletePromise.fail(HostKeyMismatch(host: host))
            }
        }
    }
}
