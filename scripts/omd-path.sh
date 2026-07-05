#!/bin/sh
# Shared PATH for OMD launchers and systemd-run services.
# Quickshell spawns cliphist/walker/etc. with the parent process PATH, which
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