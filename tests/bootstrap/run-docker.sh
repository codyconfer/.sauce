#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-all}"

run_one() {
    local name="$1" image="$2"
    shift 2
    echo "==> Testing $name with $image"
    docker run --rm "$@" \
        --volume "$ROOT:/workspace:ro" \
        "$image" \
        bash /workspace/tests/bootstrap/docker-entrypoint.sh "$name"
}

case "$TARGET" in
    ubuntu) run_one ubuntu ubuntu:24.04 ;;
    fedora) run_one fedora fedora:latest ;;
    arch) run_one arch archlinux:latest ;;
    cachyos) run_one cachyos cachyos/cachyos:latest --platform linux/amd64 ;;
    all)
        run_one ubuntu ubuntu:24.04
        run_one fedora fedora:latest
        run_one arch archlinux:latest
        run_one cachyos cachyos/cachyos:latest --platform linux/amd64
        ;;
    *)
        echo "Usage: $0 [all|ubuntu|fedora|arch|cachyos]" >&2
        exit 2
        ;;
esac
