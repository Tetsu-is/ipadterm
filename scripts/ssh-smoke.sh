#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

container=ipadterm-sshd
password=ipadterm-test

if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
  docker run -d --rm --name "$container" -p 127.0.0.1:2222:2222 \
    -e PASSWORD_ACCESS=true -e USER_NAME=tester -e USER_PASSWORD="$password" \
    lscr.io/linuxserver/openssh-server:latest >/dev/null
  until docker logs "$container" 2>&1 | grep -q "ls.io-init] done"; do sleep 1; done
fi

xcodegen generate --quiet
xcodebuild build -quiet -project IPadTerm.xcodeproj -scheme SSHSmoke -destination 'platform=macOS' \
  -derivedDataPath .build/dd CODE_SIGN_IDENTITY=-

SMOKE_PORT=2222 SMOKE_USER=tester SMOKE_PASSWORD="$password" .build/dd/Build/Products/Debug/SSHSmoke
