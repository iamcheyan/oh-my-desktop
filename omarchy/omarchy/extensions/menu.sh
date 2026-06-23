# Overwrite parts of the omarchy-menu with user-specific submenus.
# See $OMARCHY_PATH/bin/omarchy-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Omarchy changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) omarchy-system-lock ;;
#   *Shutdown*) omarchy-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
# show_about() {
#   exec omarchy-launch-or-focus-tui "zsh -c 'fastfetch; read -k 1'"
# }

launch_wifi_controls() {
  rfkill unblock wifi 2>/dev/null || true

  if command -v omarchy-wifi-tui >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui omarchy-wifi-tui
  elif command -v impala >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui impala
  elif command -v nmtui >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui nmtui
  elif command -v iwctl >/dev/null 2>&1; then
    omarchy-launch-or-focus-tui iwctl
  else
    notify-send -u critical "Wi-Fi controls unavailable" "No Wi-Fi tool found."
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
    notify-send -u critical "Bluetooth controls unavailable" "No Bluetooth tool found."
  fi
}

show_setup_menu() {
  local options="  Audio\n  Wifi\n󰂯  Bluetooth\n󱐋  Power Profile\n  System Sleep\n󰍹  Monitors"
  [[ -f ~/.config/hypr/bindings.lua ]] && options="$options\n  Keybindings"
  [[ -f ~/.config/hypr/input.lua ]] && options="$options\n  Input"
  options="$options\n  Defaults\n󰱔  DNS\n  Security\n  Config"

  case $(menu "Setup" "$options") in
  *Audio*) omarchy-launch-audio ;;
  *Wifi*) launch_wifi_controls ;;
  *Bluetooth*) launch_bluetooth_controls ;;
  *Power*) show_setup_power_menu ;;
  *System*) show_setup_system_menu ;;
  *Monitors*) open_in_editor "$(hypr_config_file monitors)" ;;
  *Keybindings*) open_in_editor "$(hypr_config_file bindings)" ;;
  *Input*) open_in_editor "$(hypr_config_file input)" ;;
  *Defaults*) show_setup_default_menu ;;
  *DNS*) present_terminal omarchy-setup-dns ;;
  *Security*) show_setup_security_menu ;;
  *Config*) show_setup_config_menu ;;
  *) show_main_menu ;;
  esac
}
