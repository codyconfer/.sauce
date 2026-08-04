#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    ubuntu)
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl jq
        expected=debian
        ;;
    fedora)
        dnf install -y -q ca-certificates curl jq
        expected=fedora
        ;;
    arch|cachyos)
        pacman -Sy --noconfirm --needed --quiet ca-certificates curl jq
        command -v curl >/dev/null 2>&1 || {
            echo "The Arch-family image must provide curl." >&2
            exit 1
        }
        expected=arch
        ;;
    *)
        echo "Usage: $0 {ubuntu|fedora|arch|cachyos}" >&2
        exit 2
        ;;
esac

bash /workspace/tests/bootstrap/test-unix.sh /workspace "$expected"
