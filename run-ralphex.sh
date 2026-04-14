#!/bin/bash
# Launch ralphex with the Kissy Missy's Castle dev environment
# (Rokit toolchain: rojo, wally, selene, stylua, lune + Node.js + Claude Code CLI)
#
# Usage:
#   ./run-ralphex.sh                        # run with default plan (docs/IMPLEMENTATION_PLAN.md)
#   ./run-ralphex.sh <plan-file>            # run with a custom plan file
#   ./run-ralphex.sh --build                # force rebuild the image first
#   ./run-ralphex.sh --build <plan-file>    # rebuild and run with custom plan

set -e

IMAGE=kissy-missy-ralphex:latest
DEFAULT_PLAN=docs/IMPLEMENTATION_PLAN.md

if [ "$1" = "--build" ]; then
    shift
    echo "Building ${IMAGE}..."
    docker build -f Dockerfile.ralphex -t "${IMAGE}" .
elif ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "First run — building ${IMAGE}..."
    docker build -f Dockerfile.ralphex -t "${IMAGE}" .
fi

PLAN_FILE="${1:-$DEFAULT_PLAN}"

docker run --rm -it \
  -v "${HOME}/.claude:/mnt/claude:ro" \
  -v "${HOME}/.config/ralphex:/mnt/ralphex-config:ro" \
  -v "${HOME}/.gitconfig:/home/app/.gitconfig:ro" \
  -v "$(pwd):/workspace" \
  -e "APP_UID=$(id -u)" \
  -e CLAUDE_CONFIG_DIR=/home/app/.claude \
  -w /workspace \
  "${IMAGE}" \
  ralphex "${PLAN_FILE}"
