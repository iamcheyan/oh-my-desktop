# Reload Race Condition & SIGSEGV Crashes

> **Status (2026-07-12):** Issue 1 is fixed. Issue 2 is partially resolved — `omd-desktop` has been removed from the codebase, and `omd-polkit` loads successfully but no longer runs as a persistent process. The document below reflects the original investigation.

## 1. Double-Stop Race in `reload-quickshell`

### Problem
`scripts/reload-quickshell` called `omd_stop_quickshell` **twice**:

1. Line 35: `stop_quickshell` → `omd_stop_quickshell()` (first stop)
2. Line 38: `start_quickshell` → `omd-restart` → line 9: `omd_stop_quickshell()` (second stop)

The second stop's `pkill -9` (in `omd-quickshell-stop.sh:27`) could race with freshly started processes from `systemd-run`, killing them before they fully initialize. This caused overview, desktop, polkit, and clipboard-store to all die after reload.

### Fix
- `bin/omd-restart`: Added `OMD_SKIP_STOP` guard (line 11). Skips `omd_stop_quickshell` if already called by the caller.
- `scripts/reload-quickshell`: Passes `OMD_SKIP_STOP=1` when calling `omd-restart` (line 28). Removed redundant `sleep 0.2`.

### Files Changed
- `bin/omd-restart` — added `OMD_SKIP_STOP` guard
- `scripts/reload-quickshell` — passes env var, removed sleep

## 2. SIGSEGV (exit 139) in Desktop & Polkit

### Problem
After reload, `omd-desktop` and `omd-polkit` crash with SIGSEGV (exit code 139). The quickshell log shows "Configuration Loaded" then the process dies immediately with no error message.

### Status
**Partially resolved (2026-07-12):**
- `omd-desktop` has been removed from the codebase (deleted from `bin/`, not started by `omd-restart`).
- `omd-polkit` loads configuration successfully but no longer runs as a persistent process. It is not included in `omd-restart`'s active process list.
- The original SIGSEGV crash is no longer reproducible in current testing.

### Symptoms (historical)
- Process starts, loads config, then exits with code 139
- No error in quickshell log
- Manual launch also crashes with SIGSEGV
- Only affects desktop and polkit; bar and overview survive

### Possible Causes (historical)
- Wayland display socket not fully ready when process starts
- Quickshell internal state corruption from rapid stop/start
- Missing environment variables in `systemd-run` context

### Workaround (historical)
Run `omd-restart` again after reload to restart the crashed processes.
