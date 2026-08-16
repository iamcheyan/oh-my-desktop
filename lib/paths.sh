#!/bin/sh
# Sumika Shell path contract — source this from any shell script.
#
# Resolves the repository root and exports XDG-compliant path variables.
# All components (shell, Lua, QML) must use these variables instead of
# hard-coding repository paths.
#
# Usage:
#   . "$REPO/lib/paths.sh"        # from a script that knows the repo root
#   . "$(dirname "$0")/../lib/paths.sh"  # from bin/ scripts
#
# Variables exported:
#   SUMIKA_SHELL_ROOT         — repository root (code + bundled assets)
#   SUMIKA_SHELL_CONFIG_HOME  — durable user-authored configuration
#   SUMIKA_SHELL_STATE_HOME   — generated and machine-local state
#   SUMIKA_SHELL_EXTENSIONS_DIR — user-installed extensions directory
#   SUMIKA_SHELL_DATA_HOME    — installed/shared data
#   SUMIKA_SHELL_RUNTIME_DIR  — sockets, locks, transient files

# ── Resolve repository root ──────────────────────────────────────────────
# Priority: existing SUMIKA_SHELL_ROOT > script location > fail

if [ -z "${SUMIKA_SHELL_ROOT:-}" ] || [ ! -d "$SUMIKA_SHELL_ROOT" ]; then
    # Try resolving from this file's location: lib/ -> repo root
    # BASH_SOURCE (array) is bash-only and aborts under dash/POSIX sh with
    # "Bad substitution". When sourced with '.', POSIX sh keeps the caller's
    # $0 — same repo-root resolution from scripts/, bin/, ... callers.
    if [ -n "${BASH_VERSION:-}" ]; then
        _paths_self="${BASH_SOURCE[0]}"
    else
        _paths_self="$0"
    fi
    if [ -f "$_paths_self" ]; then
        _paths_dir=$(cd -P "$(dirname "$_paths_self")/.." && pwd -P 2>/dev/null) || _paths_dir=""
        if [ -n "$_paths_dir" ] && [ -f "$_paths_dir/Init.sh" ]; then
            SUMIKA_SHELL_ROOT="$_paths_dir"
        fi
    fi
    unset _paths_self _paths_dir
fi

if [ -z "${SUMIKA_SHELL_ROOT:-}" ] || [ ! -d "$SUMIKA_SHELL_ROOT" ]; then
    echo "paths.sh: cannot resolve SUMIKA_SHELL_ROOT" >&2
    return 1 2>/dev/null || exit 1
fi

export SUMIKA_SHELL_ROOT

# ── XDG-compliant path contract ──────────────────────────────────────────
_xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
_xdg_state="${XDG_STATE_HOME:-$HOME/.local/state}"
_xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
_xdg_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SUMIKA_SHELL_CONFIG_HOME="${SUMIKA_SHELL_CONFIG_HOME:-$_xdg_config/sumika-shell}"
SUMIKA_SHELL_STATE_HOME="${SUMIKA_SHELL_STATE_HOME:-$_xdg_state/sumika-shell}"
SUMIKA_SHELL_DATA_HOME="${SUMIKA_SHELL_DATA_HOME:-$_xdg_data/sumika-shell}"
SUMIKA_SHELL_RUNTIME_DIR="${SUMIKA_SHELL_RUNTIME_DIR:-$_xdg_runtime/sumika-shell}"
SUMIKA_SHELL_EXTENSIONS_DIR="${SUMIKA_SHELL_EXTENSIONS_DIR:-$_xdg_data/sumika-shell/extensions}"

export SUMIKA_SHELL_CONFIG_HOME
export SUMIKA_SHELL_STATE_HOME
export SUMIKA_SHELL_DATA_HOME
export SUMIKA_SHELL_RUNTIME_DIR

unset _xdg_config _xdg_state _xdg_data _xdg_runtime
export SUMIKA_SHELL_EXTENSIONS_DIR
