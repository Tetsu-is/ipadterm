# ipadterm

PC に SSH 接続して使う iPadOS 向けターミナル。描画は [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)、SSH は [Citadel](https://github.com/orlandos-nl/Citadel)。

## ビルド

```sh
brew install xcodegen
xcodegen generate
open IPadTerm.xcodeproj
```

Xcode で `IPadTerm` スキームを選び、iPad 実機 (Signing & Capabilities で自分の Team を設定) か「My Mac (Mac Catalyst)」で実行する。初回は Metal Toolchain と iOS プラットフォームのダウンロードを求められることがある。

## 接続先 PC の準備

- macOS: システム設定 > 一般 > 共有 > リモートログイン を有効化
- Linux: `openssh-server` を入れて `sshd` を起動

接続画面でホスト (PC の IP アドレス)、ポート、ユーザー名、パスワードを入れて接続する。パスワードは保存しない。

## SSH 層の検証

```sh
scripts/ssh-smoke.sh
```

Docker で使い捨ての OpenSSH サーバーを立て、アプリと同じ `SSHSession` で接続、コマンド実行、PTY リサイズ、`exit` での終了、ホスト鍵の記録と鍵変更時の拒否までを確認する。

## MVP の既知の制約

- ホスト鍵は初回接続時のものを信頼して記録する (TOFU)。以降に鍵が変わると接続を拒否する。初回接続は信頼できるネットワークで行う。記録のリセット UI はまだ無い。
- パスワード認証のみ。鍵認証は未対応。
- バックグラウンドに回ると接続が切れる。PC 側で `tmux` を使うと作業を保持できる。
- SwiftTerm は 1.18.0 に固定している。1.19 以降はビルドプラグインを含み、Xcode でのプラグイン承認が必要になるため。
