#!/usr/bin/env bash
# Run the Go unit tests inside a Linux container.
#
# The kubelet-plugin package imports k8s.io/.../deviceattribute, whose symbols
# live only in *_linux.go files. On a non-Linux host (e.g. macOS) the package
# does not compile, so `go test` fails before running. This runs the tests in a
# linux/amd64 golang container where those files build. cgo is required (NVML),
# and the golang image ships gcc, so CGO stays enabled.
#
# Usage:
#   hack/test-in-docker.sh                       # test the kubelet-plugin package
#   hack/test-in-docker.sh ./...                 # test everything
#   hack/test-in-docker.sh ./cmd/gpu-kubelet-plugin/... -run TestGpusUnderLiveMpsDaemons
set -euo pipefail

# Match the toolchain the project builds with (see deployments/devel/Dockerfile).
GO_IMAGE="${GO_IMAGE:-golang:1.26}"

# Default target: the package these changes touch. Override by passing args.
if [[ $# -eq 0 ]]; then
  set -- ./cmd/gpu-kubelet-plugin/...
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cache Go build/module artifacts on the host so repeat runs are fast. The
# container writes them as the invoking user via --user.
CACHE_DIR="${GOCACHE_DIR:-$REPO_ROOT/.cache}"
mkdir -p "$CACHE_DIR/go" "$CACHE_DIR/gomod"

exec docker run --rm \
  --platform linux/amd64 \
  -v "$REPO_ROOT":/work \
  -v "$CACHE_DIR/go":/tmp/.cache/go \
  -v "$CACHE_DIR/gomod":/tmp/.cache/gomod \
  -w /work \
  -e GOFLAGS=-mod=vendor \
  -e GOCACHE=/tmp/.cache/go \
  -e GOMODCACHE=/tmp/.cache/gomod \
  --user "$(id -u):$(id -g)" \
  "$GO_IMAGE" \
  go test "$@"
