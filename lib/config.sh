# lib/config.sh — Read values from sumika.json
#
# Source this file: . "$(_omd_root)/lib/config.sh"
# Requires jq to read values.

_sumika_config_read() {
  local key="$1"
  local default="${2:-}"
  [ -f "$SUMIKA_SHELL_CONFIG_HOME/sumika.json" ] || { echo "$default"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "$default"; return 1; }
  # `//` also falls back for boolean false, which makes disabled settings read
  # as enabled when their default is true. Only null/missing values use the
  # supplied default.
  jq -r --arg default "$default" \
    "($key) as \$value | if \$value == null then \$default else \$value end" \
    "$SUMIKA_SHELL_CONFIG_HOME/sumika.json" 2>/dev/null || echo "$default"
}

# Read a string value from sumika.json
# Usage: value=$(sumika_get '.bar.cornerStyle' 0)
sumika_get() {
  _sumika_config_read "$1" "${2:-}"
}

# Read a boolean as "true"/"false"
sumika_get_bool() {
  local val
  val=$(_sumika_config_read "$1" "${2:-false}")
  case "$val" in
    true|True|TRUE|1) echo "true" ;;
    *) echo "false" ;;
  esac
}

# Read a JSON array as newline-separated list
sumika_get_array() {
  local key="$1"
  local fallback="${2:-}"
  [ -f "$SUMIKA_SHELL_CONFIG_HOME/sumika.json" ] || { echo "$fallback"; return 0; }
  command -v jq >/dev/null 2>&1 || { echo "$fallback"; return 0; }
  jq -r "$key // [] | .[]" "$SUMIKA_SHELL_CONFIG_HOME/sumika.json" 2>/dev/null || echo "$fallback"
}
