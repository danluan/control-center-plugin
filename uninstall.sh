#!/bin/bash
# Removes the danluan.control-center integration: puts the original widgets
# back on the bar, restores the shortcuts and re-enables the DoHome plugin.
# The plugin folder itself is left in place.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS="$(dirname "$DIR")"
BINDINGS="${BINDINGS_FILE:-$HOME/.config/hypr/bindings.lua}"
ID="danluan.control-center"
BEGIN="-- >>> $ID >>>"
END="-- <<< $ID <<<"

"$DIR/scripts/integrate" uninstall

if [[ -f $BINDINGS ]] && grep -qF "$BEGIN" "$BINDINGS"; then
  cp "$BINDINGS" "$BINDINGS.bak.control-center-$(date +%s)"
  python3 - "$BINDINGS" "$BEGIN" "$END" <<'PY'
import sys, pathlib, re
path, begin, end = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text()
text = re.sub(r"\n*" + re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "\n", text, flags=re.S)
path.write_text(text)
PY
  hyprctl reload >/dev/null 2>&1 || true
  echo "Shortcuts restored to the Omarchy defaults"
fi

if [[ -d $PLUGINS/danluan.dohome-strip ]]; then
  omarchy plugin enable danluan.dohome-strip >/dev/null 2>&1 || true
fi

omarchy restart shell >/dev/null 2>&1 || true
echo "Control Center removed from the bar."
