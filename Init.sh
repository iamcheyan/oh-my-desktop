#!/bin/bash
set -eu

# oh-my-desktop setup script.
# Creates the runtime symlinks from ~ into this repo.
# Run after cloning:  git clone ... ~/development/OMD && cd ~/development/OMD && ./Init.sh

REPO="$(cd "$(dirname "$0")" && pwd)"

# Symlinks to create:  target -> repo path
declare -a LINKS=(
  "$HOME/.config/quickshell|$REPO/quickshell"
  "$HOME/.config/omarchy|$REPO/omarchy"
  "$HOME/.config/walker|$REPO/omarchy/walker"
  "$HOME/.config/foot|$REPO/omarchy/foot"
  "$HOME/.config/kitty|$REPO/omarchy/kitty"
  "$HOME/.config/alacritty|$REPO/omarchy/alacritty"
  "$HOME/.config/ghostty|$REPO/omarchy/ghostty"
  "$HOME/.config/omd|$REPO"
  "$HOME/.local/share/omarchy|$REPO/share"
)

backup_dir=""

make_backup() {
  local target="$1"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  local bak="${target}.bak.${stamp}"

  if [[ -L "$target" ]]; then
    # Already a symlink — remove it (no backup needed, the repo has the data)
    rm "$target"
    echo "  removed existing symlink $target"
  elif [[ -e "$target" ]]; then
    # Real file/dir — back it up
    if [[ -z "$backup_dir" ]]; then
      backup_dir="$HOME/.config/omd-backup-${stamp}"
      mkdir -p "$backup_dir"
      echo "Backups will be stored in $backup_dir"
    fi
    mv "$target" "$backup_dir/$(basename "$target")"
    echo "  backed up $target -> $backup_dir/$(basename "$target")"
  fi
}

echo "Setting up oh-my-desktop symlinks..."
echo "Repo: $REPO"
echo

for entry in "${LINKS[@]}"; do
  target="${entry%%|*}"
  source="${entry##*|}"

  if [[ ! -e "$source" ]]; then
    echo "ERROR: source $source does not exist" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
    echo "  OK  $target (already linked)"
    continue
  fi

  make_backup "$target"
  ln -s "$source" "$target"
  echo "  LINK $target -> $source"
done

echo
echo "Done. Symlinks:"
for entry in "${LINKS[@]}"; do
  target="${entry%%|*}"
  printf "  %-32s -> %s\n" "$target" "$(readlink "$target")"
done

if [[ -n "$backup_dir" ]]; then
  echo
  echo "Pre-existing files backed up to: $backup_dir"
  echo "Review and remove when no longer needed."
fi

echo
echo "Next steps:"
echo "  ~/.config/omd/bin/omd-doctor   # check runtime dependencies"
echo "  hyprctl reload            # reload Hyprland config"
echo "  omd-restart               # (re)start Quickshell apps"
