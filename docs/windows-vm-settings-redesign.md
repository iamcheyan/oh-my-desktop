# Windows VM Settings Redesign

Date: 2026-07-12

## Goal

The Windows VM settings page should own the complete user workflow:

- If no VM exists, the user can install it from Settings.
- Installation should be automatic after one explicit user action.
- The UI should show current progress and useful errors.
- After installation, the user can see VM status, open the web console, start,
  stop, remove, and connect by RDP.
- The user should not need to know the underlying Docker/Dockurr details for
  normal use.

## Current Local State

Observed on this machine before the redesign:

- `~/.config/windows/docker-compose.yml` exists.
- `~/.windows` exists but is empty.
- `~/Windows` exists but is empty.
- Docker CLI exists at `/usr/bin/docker`.
- Docker daemon/socket is not available to the current user.
- `/dev/kvm` was not available in the initial restricted command context; in
  the later unrestricted context it is available.
- `xfreerdp` exists, but `xfreerdp3` does not.
- Docker cannot inspect `omarchy-windows`; the container is effectively
  missing.

Conclusion: current VM state is partial configuration, not a completed Windows
installation.

## Problems In Current Implementation

1. The Settings page and helper script disagree about responsibility.

   `docs/settings-center.md` says the page only exposes status and calls the
   old Omarchy script, but the QML page already implements a partial auto
   installer.

2. Status detection is too shallow.

   It reports `configured=true` if the compose file exists, even when the VM
   storage is empty and no container exists.

3. Docker failure modes are not explicit.

   `dockerRunning=false` does not distinguish:

   - Docker is not installed.
   - Docker daemon is stopped.
   - Docker socket does not exist.
   - User is not in the docker group.
   - Current session has not picked up a newly added docker group.

4. Compose handling is inconsistent.

   The helper uses `docker-compose` directly in many places even though modern
   systems may only have `docker compose`.

5. FreeRDP detection is too strict.

   The helper requires `xfreerdp3`, but this machine has `xfreerdp`.

6. Compose value parsing is broken.

   Current `ram`, `cpu`, `disk`, and `user` values can include trailing quote
   characters.

7. Installation progress is inferred from a few log patterns.

   The Dockurr image has multiple phases: image pull, ISO download, extraction,
   install, boot, RDP ready. The current UI collapses most of these into
   generic booting.

8. Removal is too easy from UI.

   It deletes `~/.windows`, which is destructive. The settings page should add
   a UI confirmation state before invoking removal.

9. Launch/connect is brittle.

   It assumes `xfreerdp3`; it can fail even when `xfreerdp` exists. It also only
   waits for one log phrase.

## Target Model

### Helper Script Contract

`bin/omd-settings-windows-vm` should be the single backend for Settings.

It should expose stable subcommands:

- `status`
- `check-resources`
- `install-defaults`
- `start`
- `connect`
- `start-connect`
- `stop`
- `remove --yes`
- `logs`
- `web`

All status output remains `key=value` so existing QML parsing stays simple.

### Status Fields

The page should receive at least:

- `configured=true|false`
- `storagePresent=true|false`
- `storageUsedBytes=...`
- `kvm=true|false`
- `dockerCli=true|false`
- `dockerDaemon=true|false`
- `dockerAccess=true|false`
- `dockerError=...`
- `dockerSocket=true|false`
- `dockerGroupMember=true|false`
- `compose=true|false`
- `freerdp=true|false`
- `freerdpBin=...`
- `container=missing|created|running|exited|...`
- `ready=true|false`
- `phase=not-installed|pulling|downloading|installing|booting|ready|error`
- `webReachable=true|false`
- `rdpReachable=true|false`
- `diskAvailable=...`
- `ramTotal=...`
- `cpuTotal=...`
- `ram=...`
- `cpu=...`
- `disk=...`
- `user=...`

### UI States

The Settings page should present these states:

- **Needs setup:** No usable VM. Show one primary install button.
- **System blocked:** Missing KVM/Docker/access. Show the blocking reason and
  the exact next action.
- **Installing:** Show progress text, web console button, log tail.
- **Ready/running:** Show Connect, Open Console, Stop, Logs.
- **Configured but stopped:** Show Start & Connect, Start, Remove.
- **Broken partial install:** Show Resume/Repair and Remove.

### Install Defaults

For a one-click install:

- RAM: half system RAM, minimum 4G when available, cap at 16G by default.
- CPU: half logical CPUs, minimum 2, cap at 8 by default.
- Disk: 128G when available; otherwise largest safe value above 64G; minimum
  64G.
- User: `win11`
- Password: generated or defaulted by helper. If using a default, the UI must
  clearly show it.

The current existing config uses:

- RAM: `8G`
- CPU: `2`
- Disk: `128G`
- User: `win11`
- Password: present in compose file.

## Implementation Plan

Commit 1: document current state and target design. Completed as
`530763d`.

Commit 2: harden `bin/omd-settings-windows-vm`.

- Add compose command wrapper.
- Fix compose value parsing.
- Report Docker access errors explicitly.
- Accept both `xfreerdp3` and `xfreerdp`.
- Add richer status and phase detection.
- Add non-interactive default install/start/connect/remove commands.

Completed as `43289ca`, then extended in the Settings page commit with
`auto-fix` KVM module loading.

Commit 3: redesign the Windows VM Settings page.

- Replace the confusing auto-step state machine with a clearer state model.
- Show blocking system issues first.
- Show install/progress/management sections based on status.
- Add explicit destructive confirmation for removal.
- Poll status/logs during install/start.

Completed as `cc68e67`.

Commit 4: update docs.

- Update `docs/settings-center.md` to match the new backend ownership and UI
  flow.

Commit 5: validation pass.

- Run script syntax checks.
- Run status/resource commands.
- Verify QML references and command names.

## Important Constraint

The assistant command environment cannot perform privileged GUI/system actions
such as starting Docker through PolicyKit, enabling KVM in BIOS, or completing a
Windows install. The code can be made robust, but final install/connect
verification must happen in the real desktop session.

## Implemented Behavior

The Settings page now uses `bin/omd-settings-windows-vm` as the single backend.
It no longer depends on the old interactive `share/bin/omarchy-windows-vm`
script.

The page shows:

- status pills for VM state, KVM, Docker, and RDP
- system requirement rows with a concrete blocker message
- one primary setup button
- progress rows for installing/booting/ready phases
- web console and log access
- connect, keep-alive connect, start, stop, and two-click remove actions

The backend supports:

- richer `status` output
- `install-defaults`
- `auto-fix`
- `start`
- `launch` and `launch-keepalive`
- `remove --yes`
- both `xfreerdp3` and `xfreerdp`
- both `docker compose` and `docker-compose`
- RDP host-port conflict detection. If another local service already listens on
  3389, the backend rewrites the compose mapping to a free 3390-3400 port and
  reports the actual endpoint to the Settings page.
- download progress extraction from Dockurr logs through `progressPercent`, so
  the Settings page can show `downloading 8%` without opening the raw logs.

On the validation machine, `xrdp.service` was already listening on host port
3389, so the first Docker start left `omarchy-windows` in `created` with a port
bind error. The backend now treats that as a recoverable local-port conflict
instead of a failed Windows install.

## Local Validation Notes

The validation host had Docker CLI installed, but the daemon could not start
through the packaged `docker.socket`. The root cause was a host SELinux/systemd
packaging problem rather than the Settings page:

- `docker.socket` failed before Docker could accept requests.
- Docker and containerd binaries had broken SELinux labels.
- `xrdp.service` already owned host port 3389.

The machine was repaired by running Docker directly from `docker.service` with a
Unix socket listener and `--selinux-enabled=false`, disabling `docker.socket`,
and leaving SELinux permissive for the current boot. This is a host repair, not
normal VM setup behavior. After that repair, `bin/omd-settings-windows-vm
status` reported Docker/KVM/Compose/FreeRDP ready, and `start` launched
`omarchy-windows` with:

```text
Web console: http://127.0.0.1:8006
RDP endpoint: 127.0.0.1:3390
```

The Windows image download then proceeded inside the container. Until the logs
show a real ready marker, the backend reports `ready=false` even if the RDP port
is already open.
