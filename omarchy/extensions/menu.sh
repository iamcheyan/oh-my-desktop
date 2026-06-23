launch_wifi_controls() {
  rfkill unblock wifi 2>/dev/null || true

  if command -v impala >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui impala
  elif command -v nmtui >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui nmtui
  elif command -v nm-connection-editor >/dev/null 2>&1; then
    uwsm-app -- nm-connection-editor
  elif command -v iwctl >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui iwctl
  else
    notify-send -u critical "Wi-Fi controls unavailable" "Install NetworkManager-tui, impala, or iwd."
  fi
}

launch_bluetooth_controls() {
  rfkill unblock bluetooth 2>/dev/null || true

  if command -v bluetui >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui bluetui
  elif command -v blueman-manager >/dev/null 2>&1; then
    uwsm-app -- blueman-manager
  elif command -v bluetoothctl >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui bluetoothctl
  else
    notify-send -u critical "Bluetooth controls unavailable" "Install bluetui or blueman."
  fi
}

open_monitor_controls() {
  if command -v wdisplays >/dev/null 2>&1; then
    uwsm-app -- wdisplays
  elif command -v systemsettings >/dev/null 2>&1; then
    uwsm-app -- systemsettings kcm_kscreen
  else
    open_active_monitor_config
  fi
}

open_active_monitor_config() {
  if [[ -f ~/.config/hypr/custom/general.lua ]]; then
    open_in_editor ~/.config/hypr/custom/general.lua
  elif [[ -f ~/.config/hypr/monitors.lua ]]; then
    open_in_editor ~/.config/hypr/monitors.lua
  elif [[ -f ~/.config/hypr/monitors.conf ]]; then
    open_in_editor ~/.config/hypr/monitors.conf
  else
    open_in_editor ~/.config/hypr/monitors.lua
  fi
}

show_monitor_menu() {
  local options="󰍹  Display Settings\n  Edit Active Display Config"

  case $(menu "Monitors" "$options") in
  *Settings*) open_monitor_controls ;;
  *Edit*) open_active_monitor_config ;;
  *) show_setup_menu ;;
  esac
}

open_keybindings_config() {
  if [[ -f ~/.config/hypr/custom/keybinds.lua ]]; then
    open_in_editor ~/.config/hypr/custom/keybinds.lua
  else
    open_in_editor "$(hypr_config_file bindings)"
  fi
}

open_input_config() {
  if [[ -f ~/.config/hypr/custom/general.lua ]]; then
    open_in_editor ~/.config/hypr/custom/general.lua
  else
    open_in_editor "$(hypr_config_file input)"
  fi
}

show_setup_config_menu() {
  case $(menu "Setup" "  Hyprland\n  Hypridle\n  Hyprlock\n  Hyprsunset\n  Swayosd\n󰌧  Walker\n󰍜  Waybar\n󰞅  XCompose") in
  *Hyprland*) open_in_editor ~/.config/hypr/hyprland.lua ;;
  *Hypridle*) open_in_editor ~/.config/hypr/hypridle.conf && omarchy-restart-hypridle ;;
  *Hyprlock*) open_in_editor ~/.config/hypr/hyprlock.conf ;;
  *Hyprsunset*) open_in_editor ~/.config/hypr/hyprsunset.conf && omarchy-restart-hyprsunset ;;
  *Swayosd*) open_in_editor ~/.config/swayosd/config.toml && omarchy-restart-swayosd ;;
  *Walker*) open_in_editor ~/.config/walker/config.toml && omarchy-restart-walker ;;
  *Waybar*) open_in_editor ~/.config/waybar/config.jsonc && omarchy-restart-waybar ;;
  *XCompose*) open_in_editor ~/.XCompose && omarchy-restart-xcompose ;;
  *) show_setup_menu ;;
  esac
}

launch_dns_controls() {
  if command -v nm-connection-editor >/dev/null 2>&1; then
    uwsm-app -- nm-connection-editor
  else
    present_terminal omarchy-setup-dns
  fi
}

show_setup_menu() {
  local options="  Audio\n  Wifi\n󰂯  Bluetooth"
  command -v powerprofilesctl >/dev/null 2>&1 && options="$options\n󱐋  Power Profile"
  options="$options\n  System Sleep\n󰍹  Monitors"
  [[ -f ~/.config/hypr/custom/keybinds.lua || -f ~/.config/hypr/bindings.lua ]] && options="$options\n  Keybindings"
  [[ -f ~/.config/hypr/custom/general.lua || -f ~/.config/hypr/input.lua ]] && options="$options\n  Input"
  options="$options\n  Defaults\n󰱔  DNS\n  Security\n  Config"

  case $(menu "Setup" "$options") in
  *Audio*) omarchy-launch-audio ;;
  *Wifi*) launch_wifi_controls ;;
  *Bluetooth*) launch_bluetooth_controls ;;
  *Power*) show_setup_power_menu ;;
  *System*) show_setup_system_menu ;;
  *Monitors*) show_monitor_menu ;;
  *Keybindings*) open_keybindings_config ;;
  *Input*) open_input_config ;;
  *Defaults*) show_setup_default_menu ;;
  *DNS*) launch_dns_controls ;;
  *Security*) show_setup_security_menu ;;
  *Config*) show_setup_config_menu ;;
  *) show_main_menu ;;
  esac
}
