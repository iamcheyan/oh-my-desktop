# omd-restart cgroup bug fix

## Problem

Running `omd-restart` killed applications that were not part of Quickshell itself.
Reported symptoms:

1. **Workspaces disappeared** — apps launched via the Quickshell applauncher
   (`Quickshell.execDetached`) were killed during reload, leaving workspaces empty.
2. **tmux exited** — tmux sessions running in a foot terminal (in another window)
   were terminated every time Quickshell was reloaded (including when the agent ran
   `omd-restart` during UI verification).

## Root Cause

`omd-restart` uses `systemd-run --user` to start each split Quickshell app as a
transient user service (for example `omd-applauncher.service`).

Apps launched through `Quickshell.execDetached` — foot, kitty, browsers, file
managers, etc. — **inherit the launcher unit's systemd cgroup**. The same applies to
any process started from that cgroup context, including tmux started inside a foot
window that was opened from the applauncher.

Example cgroup layout:

```
/user.slice/user-1000.slice/user@1000.service/app.slice/omd-applauncher.service
├── quickshell -p …/apps/omd-applauncher
├── foot
└── tmux
```

### What `omd-restart` did wrong

The old restart path called `systemctl --user stop` on each `omd-*.service` unit
before starting a new transient unit. **Stopping a transient unit tears down its
cgroup and kills every process still inside it**, not only the Quickshell binary.

This happens even when the unit is started with `KillMode=process`. That setting
only limits which process receives the stop signal on deactivation; it does **not**
keep unrelated processes alive if they remain in the unit cgroup. Foot and tmux were
still members of `omd-applauncher.service`, so they were killed when the unit stopped.

### What was *not* the cause

- **`pkill -f "(quickshell|qs) -p "`** — the broad pattern is risky (it can match
  shell commands or IPC one-shots that mention `qs -p` in their argv), but it did
  **not** kill tmux in reproduction. tmux's cmdline is just `tmux …`; foot is just
  `foot`.
- **Parent-child relationship with quickshell** — foot and tmux often had `systemd`
  (PID 1 user manager) as parent after detaching. The kill came from cgroup teardown
  on `systemctl stop`, not from sending a signal to quickshell's children directly.

### Isolated reproduction (2026-07-11)

```sh
tmux new-session -d -s probe
cat /proc/$(tmux display-message -p '#{pid}')/cgroup
# → …/app.slice/omd-applauncher.service

systemctl --user stop omd-applauncher.service
tmux list-sessions   # → no server running
```

Contrast:

```sh
pkill -f "quickshell -p $HOME/.config/omd/apps/omd-applauncher$"
# tmux survives

systemctl --user kill --kill-who=main omd-applauncher.service
# tmux also survives
```

## Timeline

1. User opens foot (or other apps) via applauncher → processes join
   `omd-applauncher.service` cgroup.
2. User starts tmux inside foot, or opens apps on other workspaces.
3. User or agent runs `omd-restart`.
4. `systemctl --user stop omd-applauncher.service` (and other `omd-*` units) tears
   down each unit cgroup.
5. foot, tmux, and launched apps are killed.
6. Hyprland may destroy now-empty workspaces.

## Fix

Shared stop logic lives in `scripts/omd-quickshell-stop.sh` and is sourced by
`bin/omd-restart` and `scripts/reload-quickshell`.

### 1. Targeted `pkill` (not broad `qs -p`)

Kill only known Quickshell app config paths:

```sh
pkill -f "quickshell -p ${OMD_ROOT}/apps/omd-bar$"
pkill -f "quickshell -p ${OMD_ROOT}/apps/omd-applauncher$"
# … other split apps …
pkill -f "wl-paste --watch.*cliphist"
```

Avoid `(quickshell|qs) -p ` — it matches any argv containing that substring.

### 2. `systemctl kill --kill-who=main` instead of `systemctl stop`

```sh
systemctl --user kill --kill-who=main omd-applauncher.service
```

Signals only the unit's main process. Does **not** tear down the cgroup, so foot,
tmux, and other launched apps that remain in the cgroup stay alive.

### 3. Clean up transient units without `stop`

After the main process exits:

```sh
systemctl --user reset-failed "$app.service"
rm -f "/run/user/$(id -u)/systemd/transient/$app.service"
systemctl --user daemon-reload
```

Stale transient unit files otherwise cause `systemd-run` to fail with "Unit already
loaded or has a fragment file" on consecutive restarts.

### 4. `KillMode=process` on start (unchanged)

```sh
systemd-run --user --property=KillMode=process ...
```

Still required when starting units so a future mistaken `systemctl stop` is less
destructive, but **not sufficient on its own** — the restart path must not call
`systemctl stop`.

## Verification

Tested 2026-07-11:

```sh
setsid tmux new-session -d -s verifyfix
~/.config/omd/bin/omd-restart
tmux list-sessions   # → verifyfix still attached
pgrep -af 'quickshell -p .*/apps/omd-'   # → all split apps running
```

Earlier workspace test (applauncher-launched apps across monitors) also passed after
the cgroup-safe stop path was applied.

## Related

- `scripts/omd-quickshell-stop.sh` — shared safe stop implementation
- `bin/omd-restart` — sources stop script, starts units with `KillMode=process`
- `scripts/reload-quickshell` — same stop script, then calls `omd-restart`
- `systemd.service(5)` — `KillMode`, transient units, cgroup lifecycle
- `Quickshell.execDetached` — forked processes inherit the parent's cgroup