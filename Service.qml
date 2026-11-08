import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

// One instance for the whole shell. Omarchy builds a bar (and so a Control
// Center panel) per monitor; this service routes IPC to the panel on the
// focused monitor and owns things that must exist exactly once, such as the
// DoHome strip's Bluetooth LE daemon.
Item {
  id: root

  property var shell: null
  property var panels: []

  function registerPanel(panel) {
    if (panels.indexOf(panel) === -1) panels = panels.concat([panel])
  }

  function unregisterPanel(panel) {
    panels = panels.filter(function(p) { return p !== panel })
  }

  function focusedPanel() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name) : ""
    for (var i = 0; i < panels.length; i++)
      if (panels[i].screenName === name) return panels[i]
    return panels.length > 0 ? panels[0] : null
  }

  function closeAll() {
    for (var i = 0; i < panels.length; i++)
      if (panels[i].opened) panels[i].close()
  }

  function openOnFocused(target) {
    var panel = focusedPanel()
    if (!panel) return
    for (var i = 0; i < panels.length; i++)
      if (panels[i] !== panel && panels[i].opened) panels[i].close()
    if (target) panel.openTarget(target)
    else panel.open()
  }

  // The DoHome strip's service, hosted here because a plugin can only reach
  // its own service. The danluan.dohome-strip plugin itself stays disabled so
  // there is a single BLE client; its Service.qml keeps the
  // `omarchy-shell danluan.dohome-strip …` IPC commands working.
  Loader {
    id: dohomeLoader
    active: true
    source: Qt.resolvedUrl("../danluan.dohome-strip/Service.qml")
  }
  readonly property var strip: dohomeLoader.item

  // ── System toggles ─────────────────────────────────────────────────────
  // Bar widgets are not handed Omarchy's nightlight/notifications/idle
  // services (only full bar replacements are), so they are read and driven
  // through the same IPC targets `omarchy toggle …` uses.
  property bool statusLoaded: false
  property bool nightlightOn: false
  property bool dndOn: false
  property bool stayAwake: false
  readonly property bool anyPanelOpen: panels.some(function(p) { return p.opened })

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggleSystem(kind) {
    var cmd = kind === "nightlight" ? ["omarchy-shell", "nightlight", "toggle"]
      : kind === "dnd" ? ["omarchy-shell", "notifications", "toggleDnd"]
      : kind === "awake" ? ["omarchy-shell", "idle", "toggle"]
      : null
    if (!cmd) return
    // Optimistic: flip now, the next status read confirms.
    if (kind === "nightlight") nightlightOn = !nightlightOn
    else if (kind === "dnd") dndOn = !dndOn
    else if (kind === "awake") stayAwake = !stayAwake
    toggleProc.command = cmd
    toggleProc.running = true
  }

  Process {
    id: statusProc
    command: ["sh", "-c", "omarchy-shell nightlight status; echo; omarchy-shell notifications isDnd; echo; omarchy-shell idle status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n").filter(function(l) { return l.trim() !== "" })
        try { root.nightlightOn = JSON.parse(lines[0] || "{}").enabled === true } catch (e) {}
        root.dndOn = String(lines[1] || "").trim() === "on"
        try { root.stayAwake = JSON.parse(lines[2] || "{}").stayAwake === true } catch (e) {}
        root.statusLoaded = true
      }
    }
  }

  Process {
    id: toggleProc
    onExited: statusDelay.restart()
  }

  Timer {
    id: statusDelay
    interval: 250
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: root.anyPanelOpen ? 2000 : 8000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  onAnyPanelOpenChanged: if (anyPanelOpen) refreshStatus()

  //   omarchy-shell danluan.control-center toggle
  //   omarchy-shell danluan.control-center show network
  ShellIpc {
    target: "danluan.control-center"
    function open(): void { root.openOnFocused("") }
    function close(): void { root.closeAll() }
    function toggle(): void {
      var panel = root.focusedPanel()
      if (panel && panel.opened) panel.close()
      else root.openOnFocused("")
    }
    // network | bluetooth | audio | display | power | weather | vpn | buds | midea | strip
    function show(target: string): void { root.openOnFocused(target) }
    // Like show, but closes the target when it is already open (keybindings).
    function flip(target: string): void {
      var panel = root.focusedPanel()
      if (!panel) return
      for (var i = 0; i < root.panels.length; i++)
        if (root.panels[i] !== panel && root.panels[i].opened) root.panels[i].close()
      panel.flipTarget(target)
    }
  }
}
