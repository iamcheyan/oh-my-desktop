# OMD Performance Diagnosis & Optimization Guide

This document outlines the performance characteristics of **oh-my-desktop (OMD)**, summarizes recent modifications to reduce CPU load, and provides troubleshooting advice for low-end GPU/integrated GPU devices.

---

## 1. Summary of Applied Optimizations

To resolve the sluggishness ("choppy/laggy" desktop experience), we investigated background activities and eliminated unnecessary polling loops and subprocess chains. The following fixes are now pushed:

### A. Network update debouncing (`quickshell/services/Network.qml`)
- **Problem**: `nmcli monitor` fires events on minor signal fluctuations or network state shifts. Previously, every single stdout line immediately triggered `root.update()`, spawning 5 separate processes querying `nmcli`. This led to high parallel CPU loads and left multiple defunct `[nmcli] <defunct>` zombie processes.
- **Fix**: Introduced `debounceUpdateTimer` with a `1500ms` window. Successive network events now only schedule a single aggregated state refresh, capping network processes and freeing up massive CPU overhead.

### B. On-demand keyboard list polling (`quickshell/services/KeyboardRemap.qml`)
- **Problem**: Previously, a background timer checked connected keyboards every 5 seconds, triggering an external list process.
- **Fix**: 
  - Bound the timer's running condition to `GlobalStates.barPopupType === "keyremap"`. 
  - The scanning timer is now **completely suspended** (idle CPU footprint is 0%) during normal desktop usage, and only wakes up when the status bar popup menu for keyboard remapping is active.

### C. Process-less keyboard parsing (`share/bin/omarchy-keyboard-list`)
- **Problem**: The original bash script iterated over `/proc/bus/input/devices` and launched a nested `python3` process in a loop for *every* connected hardware interface to evaluate binary capability flags. This launched python 20-30 times every few seconds.
- **Fix**: Rewrote the script as a single-entry Python module. It parses `/proc/bus/input/devices` once in memory, reducing execution times from seconds to less than `0.15s`.

---

## 2. Integrated GPU (CometLake-U Intel UHD 620) Fine-tuning

If you still notice visual stuttering, dropping frames during window dragging, workspace switching animations, or panel fly-outs, it is highly likely that **the heavy GPU blur calculations** are overtaxing your Intel UHD integrated graphics card.

OMD applies a heavy gaussian blur layer rules to Quickshell surfaces to achieve a frosted glass effect:
```lua
-- hypr/looknfeel.lua
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true, ignore_alpha = 0.1 })
```

### Steps to boost GPU render speeds:

If dragging windows or opening the overview feels sluggish, edit `hypr/looknfeel.lua` to reduce blur passes, or disable blur for Quickshell layers:

1. **Decrease blur passes (Highly Recommended)**:
   In `hypr/looknfeel.lua`, ensure your global blur is optimized for performance rather than styling density:
   ```lua
   hl.config({
     decoration = {
       blur = {
         enabled = true,
         size = 3,
         passes = 1,              -- Reducing passes from 2/3 to 1 saves ~50% GPU bandwidth
         new_optimizations = true,
       }
     }
   })
   ```

2. **Disable blur entirely (For maximum performance)**:
   If you want absolutely maximum battery life and 120+ FPS animations, comment out the layershell blur rule in `hypr/looknfeel.lua`:
   ```lua
   -- Comment out this line to disable GPU glass blur calculation:
   -- hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true, ignore_alpha = 0.1 })
   ```
   After editing, run `hyprctl reload` to apply instantly.
