import QtQuick
import qs.Commons

// Icon · rounded slider · value · optional › for details.
Item {
  id: row

  required property QtObject cc
  property string icon: ""
  property string iconTooltip: ""
  property real value: 0          // 0..1
  property bool available: true
  property bool hasDetails: false
  property string valueText: Math.round(value * 100) + "%"
  property real step: 0.05

  // Live value while dragging, so the label and fill follow the pointer
  // without waiting for the system to report back.
  property real liveValue: value
  property bool dragging: false
  onValueChanged: if (!dragging) liveValue = value

  signal moved(real value)
  signal released(real value)
  signal iconClicked()
  signal detailsRequested()

  implicitHeight: Style.space(36)
  opacity: available ? 1 : 0.45

  function clamp(v) { return Math.max(0, Math.min(1, v)) }

  // Icon button (mute, etc.)
  Rectangle {
    id: iconButton
    width: Style.space(32)
    height: width
    radius: width / 2
    anchors.verticalCenter: parent.verticalCenter
    color: iconArea.containsMouse ? Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.12) : "transparent"
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Text {
      anchors.centerIn: parent
      text: row.icon
      color: cc.fg
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading
      textFormat: Text.PlainText
    }
    MouseArea {
      id: iconArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: row.available
      cursorShape: Qt.PointingHandCursor
      onClicked: row.iconClicked()
    }
  }

  Item {
    id: track
    anchors.left: iconButton.right
    anchors.leftMargin: Style.space(8)
    anchors.right: valueLabel.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    height: Style.space(24)

    readonly property real knob: Style.space(18)
    readonly property real usable: width - knob

    Rectangle {
      id: rail
      anchors.verticalCenter: parent.verticalCenter
      x: track.knob / 2
      width: track.usable
      height: Style.space(6)
      radius: height / 2
      color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.16)

      Rectangle {
        width: Math.max(parent.height, parent.width * row.clamp(row.liveValue))
        height: parent.height
        radius: parent.radius
        color: cc.accent
        visible: row.liveValue > 0.001
      }
    }

    // Knob: light ring with an accent core, like Windows 11.
    Rectangle {
      id: knobItem
      width: track.knob
      height: width
      radius: width / 2
      x: track.usable * row.clamp(row.liveValue)
      anchors.verticalCenter: parent.verticalCenter
      color: cc.fg
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.18)

      Rectangle {
        anchors.centerIn: parent
        readonly property real size: (dragArea.containsMouse || row.dragging) ? parent.width * 0.55 : parent.width * 0.42
        width: size
        height: size
        radius: size / 2
        color: cc.accent
        Behavior on width { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: row.available
      cursorShape: Qt.PointingHandCursor
      preventStealing: true

      function valueAt(px) { return row.clamp((px - track.knob / 2) / Math.max(1, track.usable)) }

      onPressed: function(mouse) {
        row.dragging = true
        row.liveValue = valueAt(mouse.x)
        row.moved(row.liveValue)
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        row.liveValue = valueAt(mouse.x)
        row.moved(row.liveValue)
      }
      onReleased: {
        row.dragging = false
        row.released(row.liveValue)
      }
      onCanceled: row.dragging = false
      onWheel: function(wheel) {
        var dir = wheel.angleDelta.y > 0 ? 1 : (wheel.angleDelta.y < 0 ? -1 : 0)
        if (dir === 0) return
        row.liveValue = row.clamp(row.liveValue + dir * row.step)
        row.moved(row.liveValue)
        row.released(row.liveValue)
      }
    }
  }

  Text {
    id: valueLabel
    anchors.right: chevron.visible ? chevron.left : parent.right
    anchors.rightMargin: chevron.visible ? Style.space(4) : 0
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(38)
    horizontalAlignment: Text.AlignRight
    text: row.available ? Math.round(row.clamp(row.liveValue) * 100) + "%" : "—"
    color: cc.dim
    font.family: cc.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Rectangle {
    id: chevron
    visible: row.hasDetails
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(28)
    height: width
    radius: width / 2
    color: chevronArea.containsMouse ? Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.12) : "transparent"
    Text {
      anchors.centerIn: parent
      text: "›"
      color: cc.fg
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading
      textFormat: Text.PlainText
    }
    MouseArea {
      id: chevronArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.detailsRequested()
    }
  }
}
