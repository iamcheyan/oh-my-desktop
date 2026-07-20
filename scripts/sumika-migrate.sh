#!/bin/sh
# Sumika Shell configuration migration utility.
#
# Idempotent: safe to run multiple times.  Copies user data from old OMD
# locations to the new Sumika Shell config and state directories.  Does NOT
# delete or unlink source data — that happens in Phase 7 after verification.
#
# Usage:
#   scripts/sumika-migrate.sh           # perform migration
#   scripts/sumika-migrate.sh --dry-run # print planned operations only
#
# Invoked by Init.sh during setup.  Can also be run standalone.

set -eu

# ── Path contract ────────────────────────────────────────────────────────
_script_dir=$(cd -P "$(dirname "$0")/.." && pwd)
. "$_script_dir/lib/paths.sh"
unset _script_dir

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

# Old locations
# Old user data: always read from the real ~/.config/omd path, not OMD_ROOT
# (which is the repo root). On first run Init.sh runs migration before creating
# the symlink, so ~/.config/omd is the real config directory. On re-runs the
# symlink points to the repo, which is fine (data is already migrated).
OLD_CONFIG="$HOME/.config/omd"

# Old state directory — still needed for detection and migration of runtime state.
OLD_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/omd"

# New locations (from path contract)
NEW_CONFIG="$SUMIKA_SHELL_CONFIG_HOME"
NEW_STATE="$SUMIKA_SHELL_STATE_HOME"

MIGRATION_VERSION=1
MARKER_FILE="$NEW_STATE/migration-version"
LOG_FILE="$NEW_STATE/migration.log"

# ── Helpers ──────────────────────────────────────────────────────────────
log() { printf '  %s\n' "$*"; }
log_skip() { printf '  [skip] %s (already exists)\n' "$1"; }
log_copy() { printf '  [copy] %s → %s\n' "$1" "$2"; }
log_mkdir() { printf '  [mkdir] %s\n' "$1"; }

# Copy a file only if destination is absent (never overwrite).
# Uses temp file + atomic rename for safety.
copy_file() {
    src="$1"
    dst="$2"
    if [ ! -e "$src" ]; then
        return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        log_skip "$dst"
        return 0
    fi
    log_copy "$src" "$dst"
    if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$(dirname "$dst")"
        tmp="${dst}.tmp.$$"
        cp -a "$src" "$tmp"
        mv "$tmp" "$dst"
    fi
}

# Copy a directory recursively into destination.
# If destination already exists, merge only missing entries. Existing Sumika
# Shell data always wins over stale legacy data on subsequent runs.
copy_dir() {
    src="$1"
    dst="$2"
    if [ ! -d "$src" ]; then
        return 0
    fi
    if [ -d "$dst" ]; then
        log "$dst (already exists — merging contents)"
        if [ "$DRY_RUN" = 0 ]; then
            # Pass dst as arg to avoid unbound in sub-shell with set -u.
            find "$src" -mindepth 1 -maxdepth 1 -exec sh -c '
                dst="$1"; shift
                for item; do
                    cp -an "$item" "$dst/"
                done
            ' sh "$dst" {} +
        fi
        return 0
    fi
    log_copy "$src" "$dst"
    if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$(dirname "$dst")"
        tmp="${dst}.tmp.$$"
        cp -a "$src" "$tmp"
        mv "$tmp" "$dst"
    fi
}

# Copy globbed files into a destination directory.
copy_glob() {
    pattern="$1"
    destdir="$2"
    for f in $pattern; do
        [ -e "$f" ] || continue
        copy_file "$f" "$destdir/$(basename "$f")"
    done
}

# ── Detect old state ─────────────────────────────────────────────────────
detect_old_state() {
    printf '\n=== Detecting old state ===\n'
    if [ -L "$HOME/.config/omd" ]; then
        log "~/.config/omd is a symlink → $(readlink -f "$HOME/.config/omd")"
    elif [ -d "$HOME/.config/omd" ]; then
        log "~/.config/omd is a real directory"
    else
        log "~/.config/omd does not exist"
    fi
    if [ -d "$OLD_STATE_HOME" ]; then
        log "~/.local/state/omd exists ($(find "$OLD_STATE_HOME" -type f | wc -l) files)"
    else
        log "~/.local/state/omd does not exist"
    fi
}

create_directories() {
    printf '\n=== Creating Sumika Shell directories ===\n'
    for d in \
        "$NEW_CONFIG" \
        "$NEW_CONFIG/keyboard-remap" \
        "$NEW_CONFIG/notifications" \
        "$NEW_CONFIG/file-share-backup" \
        "$NEW_CONFIG/launchers" \
        "$NEW_CONFIG/launchers/icons" \
        "$NEW_CONFIG/scripts" \
        "$NEW_CONFIG/quickshell"; do
        if [ -d "$d" ]; then
            log_skip "$d"
        else
            log_mkdir "$d"
        fi
        if [ "$DRY_RUN" = 0 ]; then
            mkdir -p "$d"
            chmod 755 "$d"
        fi
    done

    for d in \
        "$NEW_STATE" \
        "$NEW_STATE/theme" \
        "$NEW_STATE/wallpaper" \
        "$NEW_STATE/keyboard-remap" \
        "$NEW_STATE/migration-backups"; do
        if [ -d "$d" ]; then
            log_skip "$d"
        else
            log_mkdir "$d"
        fi
        if [ "$DRY_RUN" = 0 ]; then
            mkdir -p "$d"
            chmod 700 "$d"
        fi
    done
}

normalize_directory_permissions() {
    [ "$DRY_RUN" = 0 ] || return 0

    # Config is a normal chezmoi-managed tree. State remains private. Preserve
    # file modes (including executable personal scripts); normalize dirs only.
    find "$NEW_CONFIG" -type d -exec chmod 755 {} +
    find "$NEW_STATE" -type d -exec chmod 700 {} +
}

# ── Migrate user-authored configuration ──────────────────────────────────
migrate_config() {
    printf '\n=== Migrating user configuration → %s ===\n' "$NEW_CONFIG"

    # keyboard-remap profiles (user-authored; NOT the generated keyd.conf)
    copy_file "$OLD_CONFIG/keyboard-remap/profiles.json" \
              "$NEW_CONFIG/keyboard-remap/profiles.json"

    # notifications
    copy_file "$OLD_CONFIG/notifications/muted_apps.cfg" \
              "$NEW_CONFIG/notifications/muted_apps.cfg"

    # file-share-backup (private)
    copy_file "$OLD_CONFIG/file-share-backup/config.json" \
              "$NEW_CONFIG/file-share-backup/config.json"

    # personal launchers
    copy_glob "$OLD_CONFIG/launchers/*.desktop" \
              "$NEW_CONFIG/launchers"
    copy_glob "$OLD_CONFIG/launchers/icons/*" \
              "$NEW_CONFIG/launchers/icons"

    # personal launch scripts (keepassxc, wechat, wps, remote-desktop, flatpak-launch)
    copy_glob "$OLD_CONFIG/scripts/keepassxc" \
              "$NEW_CONFIG/scripts/"
    copy_glob "$OLD_CONFIG/scripts/wechat" \
              "$NEW_CONFIG/scripts/"
    copy_glob "$OLD_CONFIG/scripts/wps" \
              "$NEW_CONFIG/scripts/"
    copy_glob "$OLD_CONFIG/scripts/remote-desktop" \
              "$NEW_CONFIG/scripts/"
    copy_glob "$OLD_CONFIG/scripts/remote-desktop.conf" \
              "$NEW_CONFIG/scripts/"
    copy_glob "$OLD_CONFIG/scripts/flatpak-launch" \
              "$NEW_CONFIG/scripts/"

    # Quickshell user config (defaults in repo defaults/config/quickshell/, overrides here)
    copy_file "$OLD_CONFIG/quickshell/config.json" \
              "$NEW_CONFIG/quickshell/config.json"
}

# ── Migrate generated and machine-local state ────────────────────────────
migrate_state() {
    printf '\n=== Migrating generated state → %s ===\n' "$NEW_STATE"

    # Theme snapshot (generated by omarchy-theme-set)
    copy_file "$OLD_CONFIG/current/theme.name" \
              "$NEW_STATE/theme/current-name"
    copy_dir  "$OLD_CONFIG/current/theme" \
              "$NEW_STATE/theme/current"

    copy_file "$OLD_CONFIG/current/wallpaper" \
              "$NEW_STATE/wallpaper/wallpaper"
    # Wallpaper revision for cache invalidation
    copy_file "$OLD_CONFIG/current/wallpaper.revision" \
              "$NEW_STATE/wallpaper/revision"

    # Keyboard remap generated config (not user-authored)
    copy_file "$OLD_CONFIG/keyboard-remap/keyd.generated.conf" \
              "$NEW_STATE/keyboard-remap/keyd.generated.conf"

    # Runtime state from ~/.local/state/omd/
    if [ -d "$OLD_STATE_HOME" ]; then
        # Wallpaper rotation state (merge into wallpaper/ directory)
    for wf in source mode interval prev_wallpaper renderer.log; do
        copy_file "$OLD_STATE_HOME/wallpaper/$wf" "$NEW_STATE/wallpaper/$wf"
    done
        copy_dir  "$OLD_STATE_HOME/session"    "$NEW_STATE/session"
        copy_dir  "$OLD_STATE_HOME/applauncher" "$NEW_STATE/applauncher"
        copy_dir  "$OLD_STATE_HOME/toggles"    "$NEW_STATE/toggles"
        copy_dir  "$OLD_STATE_HOME/display"    "$NEW_STATE/display"
        copy_dir  "$OLD_STATE_HOME/voice"      "$NEW_STATE/voice"
        copy_dir  "$OLD_STATE_HOME/file-share-backup" "$NEW_STATE/file-share-backup"
        copy_file "$OLD_STATE_HOME/monitor-watch.log" "$NEW_STATE/monitor-watch.log"
    fi
}

# ── Write migration marker ───────────────────────────────────────────────
write_marker() {
    if [ "$DRY_RUN" = 1 ]; then
        return 0
    fi
    printf '%s\n' "$MIGRATION_VERSION" > "$MARKER_FILE"
    {
        printf 'migration: v%d\n' "$MIGRATION_VERSION"
        printf 'date: %s\n' "$(date -Iseconds)"
        printf 'dry_run: %d\n' "$DRY_RUN"
        printf 'old_config: %s\n' "$OLD_CONFIG"
        printf 'old_state: %s\n' "$OLD_STATE_HOME"
        printf 'new_config: %s\n' "$NEW_CONFIG"
        printf 'new_state: %s\n' "$NEW_STATE"
    } >> "$LOG_FILE"
}

# ── Main ─────────────────────────────────────────────────────────────────
printf 'Sumika Shell migration utility'
[ "$DRY_RUN" = 1 ] && printf ' (DRY RUN)'
printf '\n'

detect_old_state
create_directories
migrate_config
migrate_state
normalize_directory_permissions
write_marker

printf '\n=== Migration complete ===\n'
printf '  Config: %s\n' "$NEW_CONFIG"
printf '  State:  %s\n' "$NEW_STATE"
[ "$DRY_RUN" = 0 ] && printf '  Marker: %s\n' "$MARKER_FILE"
printf '\nSource data left intact.  Removal happens in Phase 7 after verification.\n'
