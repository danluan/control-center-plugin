import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "components"

// Control Center: one status pill on the bar that opens a Windows 11 style
// quick-settings panel. Detail views reuse the real panels (Omarchy's own and
// the user's plugins) by embedding them anchored to the pill, so the shell
// morphs between them like any two popouts in the same bar section.
Panel {
  id: root

  moduleName: "danluan.control-center"
  ipcTarget: "danluan.control-center"
  // Service.qml owns the IPC target and routes it to the focused monitor.
  manageIpc: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function t(key) { return strings.t(key) }

  // ── Theme ────────────────────────────────────────────────────────────────
  readonly property color fg: Color.popups.text
  readonly property color accent: Color.accent
  readonly property color onAccent: Color.background
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property real radius: Math.max(Style.space(12), Style.cornerRadius)
  readonly property real gap: Style.space(10)

  // ── Service / monitor routing ────────────────────────────────────────────
  readonly property var service: {
    var host = root.bar && root.bar.shell ? root.bar.shell : null
    return host && typeof host.serviceFor === "function" ? host.serviceFor("danluan.control-center") : null
  }
  // The bar window's screen: the popup's own screen is not settled yet when
  // the panel starts opening, which made brightness read another monitor.
  readonly property var barWindow: pill.QsWindow ? pill.QsWindow.window : null
  readonly property string screenName: barWindow && barWindow.screen ? String(barWindow.screen.name)
    : (popup.screen ? String(popup.screen.name) : "")
  property var registeredService: null

  function syncRegistration() {
    if (registeredService === service) return
    if (registeredService) registeredService.unregisterPanel(root)
    registeredService = service
    if (registeredService) registeredService.registerPanel(root)
  }
  onServiceChanged: syncRegistration()
  Component.onCompleted: syncRegistration()
  Component.onDestruction: if (registeredService) registeredService.unregisterPanel(root)

  function targetLoader(target) {
    switch (String(target)) {
    case "network": return networkPanel
    case "bluetooth": return bluetoothPanel
    case "audio": return audioPanel
    case "display": return displayPanel
    case "power": return powerPanel
    case "weather": return weatherPanel
    case "vpn": return vpnPanel
    case "buds": return budsPanel
    case "midea": return mideaPanel
    case "strip": return stripPanel
    }
    return null
  }

  function openTarget(target) {
    var loader = targetLoader(target)
    if (loader) openEmbedded(loader)
    else root.open()
  }

  // Keybinding entry point: opens the target, or closes it when it is the
  // panel already showing.
  function flipTarget(target) {
    var loader = targetLoader(target)
    if (!loader) { root.toggle(); return }
    if (loader.item && loader.item.opened) loader.item.close()
    else openEmbedded(loader)
  }

  function anyTargetOpen() {
    var names = ["network", "bluetooth", "audio", "display", "power", "weather", "vpn", "buds", "midea", "strip"]
    for (var i = 0; i < names.length; i++) {
      var l = targetLoader(names[i])
      if (l && l.item && l.item.opened) return true
    }
    return false
  }

  // ── Settings (persisted in this widget's shell.json entry) ───────────────
  readonly property var allTiles: ["network", "bluetooth", "vpn", "nightlight", "dnd", "awake", "keyboard"]
  readonly property var allDevices: ["buds", "midea", "strip"]

  function ordered(saved, all) {
    var out = []
    var list = Array.isArray(saved) ? saved : []
    for (var i = 0; i < list.length; i++)
      if (all.indexOf(list[i]) !== -1 && out.indexOf(list[i]) === -1) out.push(list[i])
    for (var j = 0; j < all.length; j++)
      if (out.indexOf(all[j]) === -1) out.push(all[j])
    return out
  }

  readonly property var tileOrder: ordered(setting("tiles", null), allTiles)
  readonly property var hiddenTiles: Array.isArray(setting("hiddenTiles", null)) ? setting("hiddenTiles", []) : ["keyboard"]
  readonly property var hiddenDevices: Array.isArray(setting("hiddenDevices", null)) ? setting("hiddenDevices", []) : []

  function saveSettings(patch) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: moduleName }
    for (var k in settings) if (k !== "id") entry[k] = settings[k]
    for (var p in patch) entry[p] = patch[p]
    root.bar.shell.updateEntryInline(moduleName, entry)
  }

  function toggleListed(key, list, id) {
    var next = list.filter(function(x) { return x !== id })
    if (next.length === list.length) next.push(id)
    var patch = {}
    patch[key] = next
    saveSettings(patch)
  }

  function moveTile(id, direction) {
    var order = tileOrder.slice()
    var from = order.indexOf(id)
    var to = from + direction
    if (from < 0 || to < 0 || to >= order.length) return
    order.splice(from, 1)
    order.splice(to, 0, id)
    saveSettings({ tiles: order })
  }

  property bool editing: false
  onOpenedChanged: {
    if (!opened) editing = false
    else {
      brightnessRead.restart()
      if (!statsProc.running) statsProc.running = true
    }
  }

  // ── Embedded panels ──────────────────────────────────────────────────────
  readonly property string omarchyShell: "file://" + (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/shell/plugins/panels/"

  // A real panel, kept invisible inside the widget and laid over the pill so
  // its popup anchors exactly where ours does.
  component Embedded: Loader {
    property bool wanted: false
    property var configure: null
    anchors.fill: parent
    visible: false
    active: wanted
    onLoaded: {
      if (!item) return
      if ("bar" in item) item.bar = Qt.binding(function() { return root.bar })
      if ("anchorItem" in item) item.anchorItem = pill
      if (typeof configure === "function") configure(item)
    }
  }

  function openEmbedded(loader) {
    loader.wanted = true
    var show = function() {
      var target = loader.item
      if (!target) return
      if (typeof target.openFromHotkey === "function") target.openFromHotkey()
      else target.open()
      if (root.opened) root.closeForPopoutSwitch()
    }
    if (loader.item) show()
    else Qt.callLater(show)
  }

  Embedded { id: networkPanel; source: root.omarchyShell + "network/Panel.qml" }
  Embedded { id: bluetoothPanel; source: root.omarchyShell + "bluetooth/Panel.qml" }
  Embedded { id: audioPanel; source: root.omarchyShell + "audio/Panel.qml" }
  Embedded { id: displayPanel; source: root.omarchyShell + "monitor/Panel.qml" }
  Embedded { id: powerPanel; source: root.omarchyShell + "power/Panel.qml" }
  Embedded { id: weatherPanel; wanted: true; source: root.omarchyShell + "weather/Panel.qml" }
  Embedded { id: budsPanel; wanted: true; source: Qt.resolvedUrl("../local.galaxy-buds/Panel.qml") }
  Embedded { id: mideaPanel; wanted: true; source: Qt.resolvedUrl("../local.midea-ecomaster/Panel.qml") }
  Embedded {
    id: stripPanel
    wanted: root.service !== null
    source: Qt.resolvedUrl("../danluan.dohome-strip/Panel.qml")
    configure: function(item) {
      item.stripService = Qt.binding(function() { return root.service ? root.service.strip : null })
    }
  }
  Embedded {
    id: vpnPanel
    wanted: true
    source: Qt.resolvedUrl("../danluan.netextender/Panel.qml")
    configure: function(item) {
      item.moduleName = "danluan.netextender"
      item.settings = Qt.binding(function() { return root.setting("vpn", ({})) })
      item.settingsWriter = function(entry) {
        var copy = {}
        for (var k in entry) if (k !== "id") copy[k] = entry[k]
        root.saveSettings({ vpn: copy })
      }
    }
  }

  // The VPN asks for a one-time code mid-connect: bring its panel up for it.
  Connections {
    target: vpnPanel.item
    ignoreUnknownSignals: true
    function onOtpRequiredChanged() {
      if (vpnPanel.item && vpnPanel.item.otpRequired && !vpnPanel.item.opened) root.openEmbedded(vpnPanel)
    }
  }

  // ── Network ──────────────────────────────────────────────────────────────
  readonly property var netDevices: Networking.devices ? Networking.devices.values : []
  function findDevice(type) {
    var fallback = null
    for (var i = 0; i < netDevices.length; i++) {
      var d = netDevices[i]
      if (!d || d.type !== type) continue
      if (d.connected) return d
      if (!fallback) fallback = d
    }
    return fallback
  }
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiNetwork: {
    var nets = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].connected) return nets[i]
    return null
  }
  readonly property bool wiredUp: !!wiredDevice && wiredDevice.connected
  readonly property bool wifiUp: !!wifiDevice && wifiDevice.connected
  readonly property int wifiSignal: wifiNetwork ? Math.round((wifiNetwork.signalStrength || 0) * 100) : 0
  readonly property string netIcon: {
    if (wiredUp) return "󰈀"
    if (wifiUp) {
      if (wifiSignal >= 75) return "󰤨"
      if (wifiSignal >= 50) return "󰤥"
      if (wifiSignal >= 25) return "󰤢"
      return "󰤟"
    }
    if (wifiDevice && !Networking.wifiEnabled) return "󰤭"
    return "󰤮"
  }

  // ── Bluetooth ────────────────────────────────────────────────────────────
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property var btConnected: {
    var list = Bluetooth.devices ? Bluetooth.devices.values : []
    return list.filter(function(d) { return d && d.connected })
  }
  readonly property bool btOn: !!btAdapter && btAdapter.enabled
  readonly property string btIcon: !btAdapter ? "" : (!btOn ? "󰂲" : (btConnected.length > 0 ? "󰂱" : "󰂯"))

  // ── Audio ────────────────────────────────────────────────────────────────
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property bool sinkReady: !!sink && !!sink.audio
  readonly property real volume: sinkReady ? Math.min(1, sink.audio.volume) : 0
  readonly property bool muted: sinkReady && sink.audio.muted
  readonly property string volumeIcon: !sinkReady ? "󰖁" : (muted || volume <= 0.001 ? "󰝟" : (volume < 0.34 ? "󰕿" : (volume < 0.67 ? "󰖀" : "󰕾")))

  // ── System toggles (read and driven by Service.qml over IPC) ─────────────
  readonly property bool systemReady: !!service && service.statusLoaded
  readonly property bool nightlightOn: !!service && service.nightlightOn
  readonly property bool dndOn: !!service && service.dndOn
  readonly property bool stayAwake: !!service && service.stayAwake

  // ── Battery (laptops only) ───────────────────────────────────────────────
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isPresent
  readonly property int batteryPercent: hasBattery ? Math.round(Math.max(0, Math.min(1, battery.percentage)) * 100) : 0
  readonly property string batteryIcon: {
    if (!hasBattery) return ""
    if (!UPower.onBattery) return "󰂄"
    var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return icons[Math.max(0, Math.min(9, Math.floor(batteryPercent / 10)))]
  }

  // ── Keyboard / input method ──────────────────────────────────────────────
  readonly property var inputState: InputMethodState.state
  readonly property string inputLabel: {
    var label = String(inputState.label || inputState.language || "")
    return label !== "" ? label.toUpperCase().substring(0, 3) : "—"
  }

  // ── Weather (from the embedded weather panel) ───────────────────────────
  readonly property string weatherText: {
    var w = weatherPanel.item
    if (!w) return ""
    var label = String(w.label || "").trim()
    var temp = String(w.reportTempNum || "")
    if (temp !== "" && label.indexOf("°") === -1) label = (label + "  " + temp + String(w.tempUnit || "°")).trim()
    return label
  }

  // ── Media ────────────────────────────────────────────────────────────────
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var activePlayer: {
    var withTrack = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p || !(p.trackTitle || p.trackArtist)) continue
      if (p.isPlaying) return p
      if (!withTrack) withTrack = p
    }
    return withTrack
  }

  // ── Brightness (per monitor, via DDC/backlight) ──────────────────────────
  property real brightness: 0
  property bool brightnessAvailable: false
  property real pendingBrightness: -1

  Timer {
    id: brightnessRead
    interval: 10
    onTriggered: {
      if (!root.screenName || brightnessProc.running) return
      brightnessProc.command = ["omarchy-brightness-display", "--monitor", root.screenName]
      brightnessProc.running = true
    }
  }
  Process {
    id: brightnessProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(String(text || "").trim(), 10)
        root.brightnessAvailable = !isNaN(n)
        if (!isNaN(n)) root.brightness = Math.max(0, Math.min(100, n)) / 100
      }
    }
  }
  Timer {
    id: brightnessWrite
    interval: 160
    onTriggered: {
      if (root.pendingBrightness < 0 || !root.screenName) return
      if (setBrightnessProc.running) { restart(); return }
      setBrightnessProc.command = ["omarchy-brightness-display", "--no-osd", "--monitor", root.screenName,
        Math.max(1, Math.round(root.pendingBrightness * 100)) + "%"]
      root.pendingBrightness = -1
      setBrightnessProc.running = true
    }
  }
  Process { id: setBrightnessProc }

  // ── System stats (footer) ────────────────────────────────────────────────
  property string cpuText: ""
  property string memText: ""
  Process {
    id: statsProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts[0] === "cpu") root.cpuText = String(parts[1] || "")
          else if (parts[0] === "memory") root.memText = String(parts[1] || "").replace(/GB/g, "").replace(/\s+/g, "") + " GB"
        }
      }
    }
  }
  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: if (!statsProc.running) statsProc.running = true
  }

  // ── Devices ──────────────────────────────────────────────────────────────
  readonly property var buds: budsPanel.item
  readonly property var midea: mideaPanel.item
  readonly property var strip: root.service ? root.service.strip : null
  readonly property var vpn: vpnPanel.item

  readonly property bool vpnConnected: !!vpn && vpn.connected === true
  readonly property bool vpnBusy: !!vpn && vpn.connecting === true

  function toggleVpn() {
    if (!vpn) return
    if (vpnConnected || vpnBusy) { vpn.disconnect(); return }
    // Connects with the last profile; without a stored password (or any
    // profile) the full panel opens so the user can finish there.
    if (vpn.credentialKnown && typeof vpn.validConfiguration === "function" && vpn.validConfiguration()) vpn.startConnection()
    else openEmbedded(vpnPanel)
  }

  function vpnProfileName() {
    var s = root.setting("vpn", ({}))
    return String(s.server || "").replace(/:\d+$/, "")
  }

  // ── Tiles ────────────────────────────────────────────────────────────────
  function tileInfo(id) {
    switch (id) {
    case "network":
      if (!wifiDevice || wiredUp)
        return { icon: netIcon, label: wiredUp ? t("tile.ethernet") : t("tile.network"),
                 detail: wiredUp ? t("state.connected") : t("state.disconnected"),
                 active: wiredUp || wifiUp, details: true, available: true }
      return { icon: netIcon, label: t("tile.wifi"),
               detail: wifiUp ? String(wifiNetwork ? (wifiNetwork.name || "") : "") : (Networking.wifiEnabled ? t("state.disconnected") : t("state.off")),
               active: Networking.wifiEnabled, details: true, available: true }
    case "bluetooth":
      return { icon: btIcon || "󰂲", label: t("tile.bluetooth"),
               detail: !btAdapter ? t("state.unavailable") : (!btOn ? t("state.off")
                 : (btConnected.length === 1 ? String(btConnected[0].name || btConnected[0].deviceName || "")
                 : (btConnected.length > 1 ? strings.tn("state.devices", btConnected.length).arg(btConnected.length) : t("state.on")))),
               active: btOn, details: true, available: !!btAdapter }
    case "vpn":
      return { icon: vpnConnected ? "󰦝" : "󱦚", label: t("tile.vpn"),
               detail: vpnBusy ? t("state.connecting") : (vpnConnected ? vpnProfileName() : t("state.disconnected")),
               active: vpnConnected, busy: vpnBusy, details: true, available: !!vpn }
    case "nightlight":
      return { icon: "󰖔", label: t("tile.nightlight"), detail: nightlightOn ? t("state.on") : t("state.off"),
               active: nightlightOn, details: false, available: systemReady }
    case "dnd":
      return { icon: dndOn ? "󰂛" : "󰂚", label: t("tile.dnd"), detail: dndOn ? t("state.on") : t("state.off"),
               active: dndOn, details: false, available: systemReady }
    case "awake":
      return { icon: "󰅶", label: t("tile.awake"), detail: stayAwake ? t("state.on") : t("state.off"),
               active: stayAwake, details: false, available: systemReady }
    case "keyboard":
      return { icon: "󰌌", label: t("tile.keyboard"), detail: inputLabel,
               active: false, details: false, available: true }
    }
    return { icon: "", label: id, detail: "", active: false, details: false, available: false }
  }

  function tileToggled(id) {
    switch (id) {
    case "network":
      if (!wifiDevice || wiredUp) openEmbedded(networkPanel)
      else Networking.wifiEnabled = !Networking.wifiEnabled
      break
    case "bluetooth":
      if (btAdapter) Quickshell.execDetached(["omarchy-bluetooth-power", btOn ? "off" : "on"])
      break
    case "vpn": toggleVpn(); break
    case "nightlight":
    case "dnd":
    case "awake":
      if (service) service.toggleSystem(id)
      break
    case "keyboard": InputMethodState.cycle(); break
    }
  }

  function tileDetails(id) {
    switch (id) {
    case "network": openEmbedded(networkPanel); break
    case "bluetooth": openEmbedded(bluetoothPanel); break
    case "vpn": openEmbedded(vpnPanel); break
    }
  }

  readonly property var shownTiles: editing ? tileOrder : tileOrder.filter(function(id) { return hiddenTiles.indexOf(id) === -1 })
  readonly property var shownDevices: editing ? allDevices : allDevices.filter(function(id) { return hiddenDevices.indexOf(id) === -1 })

  // ── Pill on the bar ──────────────────────────────────────────────────────
  readonly property bool vertical: root.bar ? root.bar.vertical : false
  readonly property var pillIcons: {
    var icons = [netIcon]
    if (vpnConnected) icons.push("󰦝")
    if (btIcon !== "") icons.push(btIcon)
    icons.push(volumeIcon)
    if (dndOn) icons.push("󰂛")
    if (hasBattery) icons.push(batteryIcon)
    return icons
  }

  readonly property string pillTooltip: {
    var lines = []
    if (wiredUp) lines.push(t("tile.ethernet") + ": " + t("state.connected"))
    else if (wifiUp) lines.push(t("tile.wifi") + ": " + String(wifiNetwork ? (wifiNetwork.name || "") : ""))
    else lines.push(t("tile.network") + ": " + t("state.disconnected"))
    if (vpnConnected) lines.push(t("tile.vpn") + ": " + vpnProfileName())
    if (sinkReady) lines.push(t("slider.volume") + ": " + (muted ? t("state.muted") : Math.round(volume * 100) + "%"))
    if (hasBattery) lines.push(t("battery") + ": " + batteryPercent + "%")
    return lines.join("\n")
  }

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  WidgetButton {
    id: pill
    anchors.fill: parent
    bar: root.bar
    text: root.pillIcons.join(root.vertical ? "\n" : "  ")
    fontSize: Style.font.title
    centerFigures: false
    tooltipText: root.opened ? "" : root.pillTooltip
    onPressed: function(button) {
      if (button === Qt.RightButton) root.openEmbedded(audioPanel)
      else if (button === Qt.MiddleButton) { if (root.sinkReady) root.sink.audio.muted = !root.sink.audio.muted }
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      if (!root.sinkReady) return
      root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (delta > 0 ? 0.05 : -0.05)))
    }
  }

  // ── The panel ────────────────────────────────────────────────────────────
  KeyboardPanel {
    id: popup
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: popup.fittedContentWidth(Style.space(424))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: {
        if (root.editing) root.editing = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(16)

        // Header: discreet weather on the left, battery on the right.
        Item {
          width: parent.width
          height: Style.space(22)

          Row {
            id: weatherRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            opacity: weatherArea.containsMouse ? 1 : 0.8
            visible: !root.editing && root.weatherText !== ""

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.weatherText
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              textFormat: Text.PlainText
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: weatherPanel.item ? String(weatherPanel.item.reportLocation || "") : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
          }
          MouseArea {
            id: weatherArea
            width: weatherRow.width
            height: parent.height
            visible: weatherRow.visible
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openEmbedded(weatherPanel)
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasBattery && !root.editing
            text: root.batteryIcon + "  " + root.batteryPercent + "%"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.editing
            text: root.t("edit.hint")
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }
        }

        // Quick-settings tiles.
        Grid {
          id: tileGrid
          width: parent.width
          columns: 3
          spacing: root.gap
          readonly property real cell: (width - spacing * (columns - 1)) / columns

          Repeater {
            model: root.shownTiles
            delegate: Tile {
              required property string modelData
              required property int index
              readonly property var info: root.tileInfo(modelData)
              cc: root
              width: tileGrid.cell
              icon: info.icon
              label: info.label
              detail: info.detail || ""
              active: info.active === true
              busy: info.busy === true
              hasDetails: info.details === true
              available: info.available !== false
              editing: root.editing
              shownInPanel: root.hiddenTiles.indexOf(modelData) === -1
              canMoveBack: index > 0
              canMoveForward: index < root.shownTiles.length - 1
              onToggled: root.tileToggled(modelData)
              onDetailsRequested: root.tileDetails(modelData)
              onVisibilityToggled: root.toggleListed("hiddenTiles", root.hiddenTiles, modelData)
              onMoveRequested: function(direction) { root.moveTile(modelData, direction) }
            }
          }
        }

        // Sliders.
        Column {
          width: parent.width
          spacing: Style.space(2)

          SliderRow {
            cc: root
            width: parent.width
            icon: "󰃠"
            available: root.brightnessAvailable
            value: root.brightness
            hasDetails: true
            onMoved: function(v) { root.brightness = v; root.pendingBrightness = v; brightnessWrite.restart() }
            onReleased: function(v) { root.pendingBrightness = v; brightnessWrite.restart() }
            onDetailsRequested: root.openEmbedded(displayPanel)
          }

          SliderRow {
            cc: root
            width: parent.width
            icon: root.volumeIcon
            available: root.sinkReady
            value: root.muted ? 0 : root.volume
            hasDetails: true
            onMoved: function(v) {
              if (!root.sinkReady) return
              root.sink.audio.volume = v
              if (root.sink.audio.muted && v > 0) root.sink.audio.muted = false
            }
            onIconClicked: if (root.sinkReady) root.sink.audio.muted = !root.sink.audio.muted
            onDetailsRequested: root.openEmbedded(audioPanel)
          }
        }

        NowPlaying {
          cc: root
          width: parent.width
          visible: root.activePlayer !== null
          player: root.activePlayer
          sourceLabel: root.activePlayer ? String(root.activePlayer.identity || "").toUpperCase() : ""
        }

        // Devices.
        Column {
          id: deviceColumn
          width: parent.width
          spacing: Style.space(6)
          visible: root.shownDevices.length > 0

          Text {
            text: root.t("section.devices")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            leftPadding: Style.space(2)
            textFormat: Text.PlainText
          }

          Repeater {
            model: root.shownDevices
            delegate: DeviceRow {
              required property string modelData
              readonly property var info: root.deviceInfo(modelData)
              cc: root
              width: deviceColumn.width
              editing: root.editing
              shownInPanel: root.hiddenDevices.indexOf(modelData) === -1
              icon: info.icon
              iconTint: info.tint !== undefined ? info.tint : root.accent
              name: info.name
              status: info.status
              online: info.online === true
              lit: info.lit === true
              hasPower: info.power === true
              busy: info.busy === true
              onOpened: root.openDevice(modelData)
              onPowerToggled: root.toggleDevicePower(modelData)
              onVisibilityToggled: root.toggleListed("hiddenDevices", root.hiddenDevices, modelData)
            }
          }
        }

        // Footer.
        Item {
          width: parent.width
          height: Style.space(40)

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(2)
            anchors.bottom: parent.bottom
            height: Style.space(30)
            spacing: Style.space(12)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.cpuText !== ""
              text: "󰍛 " + root.cpuText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.memText !== ""
              text: "󰘚 " + root.memText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
          }

          Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Style.space(4)

            RoundButton {
              cc: root
              icon: root.editing ? "󰄬" : "󰏫"
              highlighted: root.editing
              onClicked: root.editing = !root.editing
            }
            RoundButton {
              cc: root
              icon: "󰒓"
              onClicked: { root.close(); Quickshell.execDetached(["omarchy", "menu", "summon", "setup"]) }
            }
            RoundButton {
              cc: root
              icon: "󰐥"
              onClicked: { root.close(); Quickshell.execDetached(["omarchy", "menu", "summon", "system"]) }
            }
          }
        }
      }
    }
  }

  // ── Device helpers ───────────────────────────────────────────────────────
  function batteryText(v) {
    return v !== null && v !== undefined && Number(v) >= 0 && Number(v) <= 100 ? Math.round(Number(v)) + "%" : "—"
  }

  function deviceInfo(id) {
    if (id === "buds") {
      var b = buds
      var on = !!b && b.connected === true
      var bat = b && b.battery ? b.battery : ({})
      return {
        icon: "󰋋",
        name: b ? String(b.displayName || "Galaxy Buds") : "Galaxy Buds",
        status: on ? (t("buds.left") + " " + batteryText(bat.left) + " · " + t("buds.right") + " " + batteryText(bat.right)
                      + " · " + t("buds.case") + " " + batteryText(bat.case))
                   : (b ? t("state.disconnected") : t("state.loading")),
        online: on, lit: on, power: false
      }
    }
    if (id === "midea") {
      var m = midea
      var d = m && m.device ? m.device : ({})
      var online = d.online === true
      var temp = d.target_temperature !== undefined && d.target_temperature !== null ? Math.round(Number(d.target_temperature)) + "°C" : ""
      var status = !m ? t("state.loading")
        : (!d.configured && (m.busy || m.lastUpdated === "") && m.lastError === "") ? t("state.loading")
        : (m.lastError !== "" && !online) ? t("state.offline")
        : !d.configured ? t("midea.setup")
        : !online ? t("state.offline")
        : d.power ? (t("state.on") + " · " + temp + " · " + (typeof m.modeLabel === "function" ? m.modeLabel(d.mode) : String(d.mode || "")))
        : (t("state.off") + " · " + temp)
      return { icon: "󰜗", name: t("midea.name"), status: status, online: online, lit: online && d.power === true,
               power: d.configured === true, busy: m ? m.busy === true : false }
    }
    if (id === "strip") {
      var s = strip
      var link = s ? String(s.link || "") : ""
      var stat = !s ? t("state.loading")
        : (s.lastError !== "" ? t("strip.error")
        : (link === "connecting" ? t("state.connecting")
        : (s.power ? (t("state.on") + " · " + s.brightness + "%") : t("state.off"))))
      return { icon: "󱁑", name: t("strip.name"), status: stat, online: !!s && s.lastError === "",
               lit: !!s && s.power === true, power: !!s,
               tint: s ? Qt.hsva(s.hue, Math.max(0.35, s.saturation), 1, 1) : root.accent }
    }
    return { icon: "", name: id, status: "", online: false, lit: false, power: false }
  }

  function openDevice(id) {
    if (id === "buds") openEmbedded(budsPanel)
    else if (id === "midea") openEmbedded(mideaPanel)
    else if (id === "strip") openEmbedded(stripPanel)
  }

  function toggleDevicePower(id) {
    if (id === "midea" && midea && midea.device) midea.setValue("power", !midea.device.power)
    else if (id === "strip" && strip) strip.togglePower()
  }
}
