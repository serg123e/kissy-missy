#!/bin/bash
# Runtime init for the ralphex container.
# - copies claude credentials (so the CLI is authenticated as the host user)
# - adjusts the `app` user UID to match the host user (avoids permission issues on /workspace)
# - copies ralphex config (read-only mount → writable copy)
# - marks /workspace as a safe git directory
# - drops privileges to `app` via gosu

APP_UID="${APP_UID:-1000}"

# Copy claude credentials (mirrors the ralphex official init.sh behaviour)
if [ -d /mnt/claude ]; then
    mkdir -p /home/app/.claude
    for f in .credentials.json settings.json settings.local.json CLAUDE.md; do
        [ -e "/mnt/claude/$f" ] && cp -L "/mnt/claude/$f" "/home/app/.claude/$f" 2>/dev/null || true
    done
    for d in commands skills hooks agents plugins; do
        [ -d "/mnt/claude/$d" ] && cp -rL "/mnt/claude/$d" "/home/app/.claude/" 2>/dev/null || true
    done
    chown -R app:app /home/app/.claude 2>/dev/null || true
fi

# Align the `app` UID with the host user so written files are owned correctly
if [ "$(id -u app)" != "$APP_UID" ]; then
    usermod -u "$APP_UID" app 2>/dev/null || true
fi

# Copy ralphex config (read-only mount → writable copy)
if [ -d /mnt/ralphex-config ]; then
    mkdir -p /home/app/.config/ralphex
    cp -rL /mnt/ralphex-config/* /home/app/.config/ralphex/ 2>/dev/null || true
    chown -R app:app /home/app/.config/ralphex 2>/dev/null || true
fi

# Git safe directory
git config --global --add safe.directory /workspace

# Run as app user
exec gosu app "$@"
