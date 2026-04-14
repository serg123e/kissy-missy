#!/usr/bin/env bash
set -euo pipefail

stylua --check src/ tests/
selene src/
lune run tests/run.luau
rojo build -o /tmp/test.rbxl
