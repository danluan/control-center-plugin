#!/bin/bash
# Installs the danluan.control-center integration (idempotent; backs up every
# file it touches).
#
#   ./install.sh                 full install
#   ./install.sh --keep-widgets  add the pill but leave the old widgets on the bar
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS="$(dirname "$DIR")"
BINDINGS="${BINDINGS_FILE:-$HOME/.config/hypr/bindings.lua}"
ID="danluan.control-center"
BEGIN="-- >>> $ID >>>"
END="-- <<< $ID <<<"

command -v python3 >/dev/null || { echo "python3 not found" >&2; exit 1; }
command -v omarchy >/dev/null || { echo "omarchy CLI not found" >&2; exit 1; }

if [[ $DIR != "$HOME/.config/omarchy/plugins/$ID" ]]; then
  echo "This plugin must live in ~/.config/omarchy/plugins/$ID (it is in $DIR)." >&2
  exit 1
fi

# 1. The embedded panels need small host hooks in these plugins.
check_hook() { # plugin pattern
  local file="$PLUGINS/$1/Panel.qml"
  if [[ ! -f $file ]]; then
    echo "  ! $1 not installed: its card will stay empty"
  elif ! grep -q "$2" "$file"; then
    echo "  ! $1 lacks the '$2' hook: see README (Dependências)"
  else
    echo "  ✓ $1"
  fi
}
echo "Checking integrated plugins:"
check_hook local.galaxy-buds "property var anchorItem"
check_hook local.midea-ecomaster "property var anchorItem"
check_hook danluan.netextender "settingsWriter"
check_hook danluan.dohome-strip "stripService"

chmod +x "$DIR/scripts/integrate"

# 2. The DoHome BLE daemon now runs inside this plugin's service; the
#    standalone plugin must be off so there is a single Bluetooth client.
if [[ -d $PLUGINS/danluan.dohome-strip ]]; then
  omarchy plugin disable danluan.dohome-strip >/dev/null 2>&1 || true
fi

# 3. Bar layout.
"$DIR/scripts/integrate" install "$@"

# 4. Panel shortcuts that used to target the removed widgets.
if [[ -f $BINDINGS ]] && ! grep -qF "$BEGIN" "$BINDINGS"; then
  cp "$BINDINGS" "$BINDINGS.bak.control-center-$(date +%s)"
  bindings_before=$(cat "$BINDINGS")
  cat >>"$BINDINGS" <<EOF

$BEGIN
-- The audio/bluetooth/display/network/power widgets live inside the Control
-- Center now, so their panel shortcuts go through it.
local cc = "omarchy-shell $ID "
o.rebind("SUPER + CTRL + A", "Audio", cc .. "flip audio")
o.rebind("SUPER + CTRL + B", "Bluetooth", cc .. "flip bluetooth")
o.rebind("SUPER + CTRL + D", "Display", cc .. "flip display")
o.rebind("SUPER + CTRL + N", "Network", cc .. "flip network")
o.rebind("SUPER + CTRL + P", "Power", cc .. "flip power")
$END
EOF
  if [[ -z ${SKIP_HYPR_RELOAD:-} ]]; then
    hyprctl reload >/dev/null
    errors=$(hyprctl configerrors)
    if [[ -n $errors ]]; then
      echo "Hyprland reported config errors, reverting bindings.lua:" >&2
      echo "$errors" >&2
      printf '%s\n' "$bindings_before" >"$BINDINGS"
      hyprctl reload >/dev/null
      exit 1
    fi
  fi
  echo "Shortcuts Super+Ctrl+A/B/D/N/P now open the Control Center panels"
else
  echo "Shortcuts already installed"
fi

# 5. A restart is needed for IPC handlers to register.
omarchy restart shell >/dev/null 2>&1 || true
echo "Done. Click the status pill on the bar, or: omarchy-shell $ID toggle"
