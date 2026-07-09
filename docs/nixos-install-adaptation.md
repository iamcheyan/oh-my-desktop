# NixOS Installation and Adaptation Guide

This document describes how to install, configure, and adapt **oh-my-desktop (OMD)** on NixOS. Since NixOS handles package dependency, environment paths, and system sessions declaratively, running OMD requires specific declarative changes and hardware adjustments.

---

## 1. System Dependencies in `configuration.nix`

For Hyprland and Quickshell to start up correctly without a black screen or missing UI components, ensure that your `/etc/nixos/configuration.nix` contains the required graphical libraries. 

In particular:
- The Quickshell UI relies on the `Qt5Compat.GraphicalEffects` module. Make sure to include `kdePackages.qt5compat` in your `environment.systemPackages` block.
- Precompiled Python wheels (such as `sherpa-onnx` used by the Voice Input daemon) require dynamic library linking. You must enable `nix-ld` so they can resolve system libraries (like `libstdc++.so.6`).

Update your configuration with the following:
```nix
environment.systemPackages = with pkgs; [
  # OMD / Hyprland Core
  hyprland
  hyprlock
  hypridle
  quickshell
  walker
  cliphist
  wl-clipboard
  mako
  swaybg

  # Qt / QML Integration (CRITICAL)
  kdePackages.qtwayland
  kdePackages.qt5compat      # Provides Qt5Compat.GraphicalEffects (needed for OMD UI)
  kdePackages.qt6ct
  kdePackages.qtstyleplugin-kvantum

  # Media & Hardware Utilities
  ffmpeg                     # Required for voice transcription audio processing (gain, resample)
  pamixer
  playerctl
  pavucontrol
  brightnessctl
  grim
  slurp
  
  # Optional TUI / Helpers
  ddcutil                    # For external monitor brightness controls
  libsecret                  # Required for secret-tool API key storage
];

# Enable nix-ld to load dynamic libraries (required for sherpa-onnx / voice input daemon)
programs.nix-ld.enable = true;
```

For non-root users who want to dynamically install it in their active profile, run:
```sh
nix profile add nixpkgs#ffmpeg --extra-experimental-features "nix-command flakes"
```

Remember to apply the system configuration after editing:
```sh
sudo nixos-rebuild switch
```

---

## 2. Adapting Monitor and Resolution (Avoiding Black Screen)

Hyprland will fail to render or boot to a black screen if your display settings in `hypr/monitors.lua` mismatch your actual hardware (e.g., trying to scale an unavailable resolution or choosing the wrong output interface).

### Step 1: Detect your connected monitors
Switch to a TTY or run the following command from another terminal emulator to find your active output name and supported resolutions:
```sh
wlr-randr
# Example output:
# eDP-1 connected primary 1920x1200+0+0
```

### Step 2: Auto-scaling configuration in `hypr/monitors.lua`
Rather than hardcoding monitor configurations, OMD dynamically queries connected screens from `/sys/class/drm`, detects native resolutions, and automatically assigns industry-standard scaling factors.

Here is the logic applied in `hypr/monitors.lua`:

| Resolution Width | Device Category | Default Scale | Intended Layout Density |
| --- | --- | --- | --- |
| **<= 2000 px** | 1080p/1200p Laptop screen | **1.25x** | Comfortable font sizes for small screens |
| **<= 2000 px** | 1080p/1200p External desktop | **1.0x** | High information density on large screens |
| **2000 - 2600 px** | 2K / 1440p External desktop | **1.25x** | Ideal balance of workspace and readability |
| **2600 - 3100 px** | 2.8K / 3K MacBook/Thinkpad retina | **2.0x** | Sharp pixel-doubling (Retina UI) |
| **3100 - 3840 px** | 4K External desktop monitor | **1.5x** | Standard fractional scale for 4K desktop screens |
| **> 3840 px** | 5K / 6K High-DPI Desktop | **2.0x** | Ultra-sharp Retina mode |

Our `hypr/monitors.lua` automatically resolves these rules and arranges multiple connected screens side-by-side:

```lua
-- ~\.config\omd\hypr\monitors.lua
-- Dynamic Monitor Auto-Scaling Configuration for Hyprland

local function get_connected_monitors()
  local monitors = {}
  local p = io.popen("find /sys/class/drm/ -maxdepth 1 -name \"card*-*\" 2>/dev/null")
  if not p then return monitors end

  for path in p:lines() do
    local status_file = io.open(path .. "/status", "r")
    if status_file then
      local status = status_file:read("*l")
      status_file:close()
      if status == "connected" then
        local name = path:match("card%d+%-([^/]+)")
        local modes_file = io.open(path .. "/modes", "r")
        local mode = "preferred"
        local w, h = 0, 0
        if modes_file then
          local first_line = modes_file:read("*l")
          modes_file:close()
          if first_line then
            mode = first_line
            w, h = first_line:match("(%d+)x(%d+)")
            w, h = tonumber(w or 0), tonumber(h or 0)
          end
        end
        table.insert(monitors, { name = name, mode = mode, w = w, h = h })
      end
    end
  end
  p:close()
  return monitors
end

local primary_gdk_scale = 1
local configured_any = false
local x_offset = 0

local connected = get_connected_monitors()

for _, m in ipairs(connected) do
  local is_internal = m.name:sub(1, 3) == "eDP"
  local scale = 1.0
  local gdk_scale = 1

  if is_internal then
    if m.w <= 2000 then
      scale = 1.25
      gdk_scale = 1
    elseif m.w <= 3100 then
      scale = 2.0
      gdk_scale = 2
    else
      scale = 2.0
      gdk_scale = 2
    end
  else
    if m.w <= 2000 then
      scale = 1.0
      gdk_scale = 1
    elseif m.w <= 2600 then
      scale = 1.25
      gdk_scale = 1
    elseif m.w <= 3840 then
      scale = 1.5
      gdk_scale = 1
    else
      scale = 2.0
      gdk_scale = 2
    end
  end

  if is_internal or not configured_any then
    primary_gdk_scale = gdk_scale
  end

  hl.monitor({
    output = m.name,
    mode = "preferred",
    position = x_offset .. "x0",
    scale = scale
  })

  local logical_width = math.floor(m.w / scale)
  x_offset = x_offset + logical_width
  configured_any = true
end

hl.env("GDK_SCALE", tostring(primary_gdk_scale))

-- Wildcard adaptive fallback for safety
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

---

## 3. Dynamic QML Library Pathing (`omd-path.sh`)

NixOS installs packages into isolated Nix store paths (`/nix/store/...`), which means standard Qt search paths might not automatically discover modules like `Qt5Compat`. 

To prevent "Type ReloadPopup unavailable" or "module Qt5Compat.GraphicalEffects is not installed" errors, OMD uses `scripts/omd-path.sh` to dynamically query the Nix store for `qt5compat` and prepend it to `QML_IMPORT_PATH` before starting Quickshell services:

```sh
# scripts/omd-path.sh

# Ensure Qt5Compat.GraphicalEffects QML module is available for Quickshell.
_qt5compat_qml=$(find /nix/store -maxdepth 1 -name "*qt5compat*" -type d 2>/dev/null | head -1)
if [ -n "$_qt5compat_qml" ] && [ -d "$_qt5compat_qml/lib/qt-6/qml" ]; then
    _qt5compat_qml="$_qt5compat_qml/lib/qt-6/qml"
    case ":${QML_IMPORT_PATH:-}:" in
        *:"$_qt5compat_qml":*) ;;
        *) export QML_IMPORT_PATH="$_qt5compat_qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}" ;;
    esac
fi
unset _qt5compat_qml
```

---

## 4. Diagnostics & Troubleshooting

If you encounter a black screen or missing panels after entering from SDDM:

1. **Check if Quickshell processes are running:**
   ```sh
   pgrep -af '(quickshell|qs)'
   ```

2. **Examine the error logs of split services:**
   OMD logs its individual component startups to `/tmp`:
   ```sh
   tail -n 30 /tmp/omd-bar.log
   tail -n 30 /tmp/omd-desktop.log
   ```

3. **Manually trigger reload:**
   If you made changes to `hypr/monitors.lua` or QuickShell QML files:
   ```sh
   hyprctl reload                         # Reload Hyprland
   bash scripts/reload-quickshell          # Restart all QuickShell panels
   ```

---

## 5. Keyboard Remapping (keyd) on NixOS

Since keyboard remapping (`keyd`) intercepts kernel evdev keypresses, it requires root privileges and cannot run as a standalone user process. 

To enable keyboard remapping on NixOS and avoid configurations locking up during system activation, follow these steps:

### Step 1: Declare keyd service and packages in `/etc/nixos/configuration.nix`
In NixOS, you must enable the daemon service **and** explicitly add `keyd` to your system packages list. This ensures the binary is linked into your global `PATH` (`/run/current-system/sw/bin/keyd`), which OMD scripts depend on:

```nix
# 1. Add keyd to your environment.systemPackages block:
environment.systemPackages = with pkgs; [
  keyd
  # ... other packages
];

# 2. Enable the keyd keyboard remapping daemon:
services.keyd = {
  enable = true;
};

# 3. Add systemd service capability overrides (CRITICAL NixOS FIX)
# Without this, keyd fails to demote its user group on startup, crashing with "setgid: Operation not permitted"
systemd.services.keyd.serviceConfig = {
  CapabilityBoundingSet = [ "CAP_SYS_NICE" "CAP_IPC_LOCK" "CAP_SETGID" "CAP_SETUID" ];
};
```

### Step 2: Create directory & placeholder config (CRITICAL AVOID-LOCK STEP)
By default, the NixOS systemd unit for `keyd` will crash with **`status 255/EXCEPTION (opendir: No such file or directory)`** if `/etc/keyd` does not exist or has no configs. If the unit crashes, `nixos-rebuild switch` will hang or return a non-zero exit code, blocking path updates.

Before rebuilding, run the following commands to create the directories and placeholder files:
```sh
# Create keyd folder and dummy configuration file
sudo mkdir -p /etc/keyd
sudo touch /etc/keyd/omd.conf

# Ensure keyd system user group exists
sudo groupadd -r keyd 2>/dev/null || true

# If the service previously crashed, you must clear orphaned socket files
# otherwise keyd fails to start with "failed to create /var/run/keyd.socket (another instance already running?)"
sudo rm -f /var/run/keyd.socket /run/keyd.socket
sudo systemctl reset-failed keyd
```
```

### Step 3: Apply NixOS configuration
Run rebuild to install and register the service:
```sh
sudo nixos-rebuild switch
```

### Step 4: Shebang Portability Patch
Since NixOS does not have a physical `/bin/bash` path, OMD shell scripts (which default to `#!/bin/bash` in other distros) must use a portable shebang:
`#!/usr/bin/env bash`

The scripts under `share/bin/` related to keyboard mapping:
- `share/bin/omarchy-keyboard-render`
- `share/bin/omarchy-keyboard-apply`
- `share/bin/omarchy-keyboard-setup`

Have been patched to `#!/usr/bin/env bash` to run seamlessly on NixOS.

### Step 5: Install Polkit Rules
Run the OMD setup helper to allow the desktop environment to update `/etc/keyd/omd.conf` and reload mappings dynamically without prompting for root password:
```sh
# Set up OMD Polkit rules for keyd
bash ~/.config/omd/share/bin/omarchy-keyboard-setup
```

If you ever run the apply script manually from the terminal under `sudo`, the script will automatically resolve your original non-root home directory (resolving `$SUDO_USER` instead of `$HOME` which defaults to `/root`), preventing path resolution bugs.

Once set up, use **Settings -> Display -> Keyboard Remap** to manage mappings, and click **Apply changes**!

---

## 6. Setting Zsh as Default Shell on NixOS

On NixOS, you cannot use the traditional `chsh -s $(which zsh)` command because `/etc/passwd` is managed declaratively by the NixOS configuration system. 

To set Zsh as the default shell for a user, you must define it in `/etc/nixos/configuration.nix` by doing the following:

### Step 1: Declare Zsh as user shell and enable it globally
Add `shell = pkgs.zsh;` inside your user block, and enable the global zsh program so that PAM modules, system-wide zsh configurations, and `/etc/shells` are correctly populated:

```nix
users.users."tetsuya" = {
  isNormalUser = true;
  shell = pkgs.zsh;              # Set Zsh as default login/interactive shell
  extraGroups = [ "networkmanager" "wheel" ];
};

# Enable global Zsh settings (crucial for NixOS shell initialization)
programs.zsh.enable = true;
```

### Step 2: Apply system configuration
Apply the changes to update the system profiles:
```sh
sudo nixos-rebuild switch
```

After rebuilding, verify that the shell has been updated:
```sh
getent passwd tetsuya
# Output should end with: /run/current-system/sw/bin/zsh
```

---

## 7. Declarative Multi-device NixOS Flake Architecture (Unified Config)

For users running NixOS on multiple machines (e.g. laptop, desktop, server) who want to share their setups publicly while maintaining modularity and privacy, migrating to a **Nix Flake** structure located under the home directory (`~/nixos-config`) is the industry standard.

### 📐 Directory Layout
Create a clean directory tree under `~/nixos-config/`:

```
~/nixos-config/
├── flake.nix                    # Entrypoint: declares host definitions (laptop, desktop)
│
├── hosts/                       # Physical machine profiles
│   ├── laptop/                  # Laptop configurations
│   │   ├── configuration.nix    # Laptop entrypoint (imports shared modules + sets hostname)
│   │   └── hardware.nix         # Laptop-specific partition mounts (from hardware-configuration.nix)
│   │
│   └── desktop/                 # Desktop configurations
│       ├── configuration.nix    # Desktop entrypoint (imports shared modules + graphics)
│       └── hardware.nix         # Desktop-specific partition mounts
│
└── modules/                     # Generic, shareable modules
    ├── core.nix                 # Base tools, locales, input method, unfree license
    ├── desktop.nix              # Graphic sessions (Hyprland, portal, audio, fonts, GUI packages)
    ├── keyd.nix                 # keyd daemon (sandbox fixes + auto config generation)
    └── zsh.nix                  # Zsh default shell enablement
```

---

### 📝 Core Configurations

#### ① Entrypoint (`flake.nix`)
Ties all outputs and hosts to nixpkgs channel versions:
```nix
{
  description = "Tetsuya's Multi-device NixOS Flake Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations = {
      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/laptop/configuration.nix ];
      };
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/desktop/configuration.nix ];
      };
    };
  };
}
```

#### ② Shared Modules: Keyd Guard (`modules/keyd.nix`)
To prevent system activation lockups on clean installs where `/etc/keyd` is missing, we use systemd `preStart` hooks to automatically build directories and configuration placeholders:
```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.keyd ];
  services.keyd.enable = true;

  systemd.services.keyd = {
    preStart = ''
      mkdir -p /etc/keyd
      if [ ! -f /etc/keyd/omd.conf ]; then
        echo "# Placeholder config" > /etc/keyd/omd.conf
      fi
    '';
    serviceConfig = {
      CapabilityBoundingSet = [ "CAP_SYS_NICE" "CAP_IPC_LOCK" "CAP_SETGID" "CAP_SETUID" ];
    };
  };
}
```

#### ③ Shared Modules: Zsh (`modules/zsh.nix`)
```nix
{ config, pkgs, ... }:
{
  programs.zsh.enable = true;
}
```

#### ④ Host Profile Entry (`hosts/laptop/configuration.nix`)
Simple and highly descriptive, linking hardware and desired modules together:
```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/desktop.nix
    ../../modules/keyd.nix
    ../../modules/zsh.nix
  ];

  networking.hostName = "laptop";
  time.timeZone = "Asia/Tokyo";

  users.users."tetsuya" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "tetsuya";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  system.stateVersion = "26.05";
}
```

---

### 🚀 Rebuilding and Switching System Profiles

> [!IMPORTANT]
> **Strict Nix Flake Git Constraint:**
> Nix Flake builds are evaluated strictly inside a sandboxed Git tree. **Any new file that is not staged (i.e. `git add`-ed) will be ignored by Nix**, throwing "file not found" errors. Always stage all changes before rebuilding!

1. Initialize git and stage configuration files:
   ```sh
   cd ~/nixos-config
   git init
   git add .
   ```

2. Build and switch the system over to the Flake configuration:
   
   - **For Laptop**:
     ```sh
     sudo nixos-rebuild switch --flake ~/nixos-config#laptop
     ```
   
   - **For Desktop**:
     ```sh
     sudo nixos-rebuild switch --flake ~/nixos-config#desktop
     ```

Once verified, the repository `~/nixos-config` can be safely pushed to any public GitHub repository for shared use. Other users can copy your setup by simply matching their partition details inside a local `hardware.nix` config!
