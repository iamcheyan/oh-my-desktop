#!/bin/sh
# Shared PATH for OMD launchers and systemd-run services.
# Quickshell spawns cliphist etc. with the parent process PATH, which
# systemd user units do not inherit from interactive shells (goenv, cargo, …).

omd_prepend_path() {
    case ":${PATH}:" in
        *:"$1":*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

omd_prepend_path "$HOME/.local/bin"
omd_prepend_path "$HOME/.cargo/bin"
omd_prepend_path "$HOME/go/bin"

if [ -d "$HOME/.goenv/shims" ]; then
    omd_prepend_path "$HOME/.goenv/shims"
fi

if [ -d "$HOME/.goenv/versions" ]; then
    for go_bin in "$HOME"/.goenv/versions/*/bin; do
        [ -d "$go_bin" ] || continue
        omd_prepend_path "$go_bin"
    done
fi

if command -v go >/dev/null 2>&1; then
    _gopath="$(go env GOPATH 2>/dev/null || true)"
    if [ -n "$_gopath" ]; then
        omd_prepend_path "$_gopath/bin"
    fi
fi

export PATH

# Ensure Qt5Compat.GraphicalEffects QML module is available for Quickshell.
# NixOS does not automatically expose all Qt packages to the QML search path,
# so we probe the nix store and prepend the path when found.
_qt5compat_qml=$( { find /nix/store -maxdepth 1 -name "*qt5compat*" -type d 2>/dev/null || true; } | head -1)
if [ -n "$_qt5compat_qml" ] && [ -d "$_qt5compat_qml/lib/qt-6/qml" ]; then
    _qt5compat_qml="$_qt5compat_qml/lib/qt-6/qml"
    case ":${QML_IMPORT_PATH:-}:" in
        *:"$_qt5compat_qml":*) ;;
        *) export QML_IMPORT_PATH="$_qt5compat_qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" ;;
    esac
fi
unset _qt5compat_qml

# Inject LD_LIBRARY_PATH for nix-ld compatibility (fixes pip-installed binary wheels like sherpa-onnx)
if [ -d "/run/current-system/sw/share/nix-ld/lib" ]; then
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# Resolve SUMIKA_MODULES_HOME from config.json, env var, then default.
# Priority: 1) already-set env var, 2) modules.dir in config.json, 3) $HOME/development/sumika-modules
if [ -z "${SUMIKA_MODULES_HOME:-}" ]; then
    _dir=""
    if command -v jq >/dev/null 2>&1; then
        _sumika_config="${SUMIKA_SHELL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/sumika-shell}"
        _config_json_path="$_sumika_config/quickshell/config.json"
        [ -f "$_config_json_path" ] || _config_json_path="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/config.json"
        if [ -f "$_config_json_path" ]; then
            _dir=$(jq -r 'try .modules.dir // ""' "$_config_json_path" 2>/dev/null || true)
            case "$_dir" in
                [~]/*) _dir="$HOME${_dir#\~}" ;;
            esac
        fi
    fi
    : "${_dir:=$HOME/development/sumika-modules}"
    export SUMIKA_MODULES_HOME="$_dir"
fi