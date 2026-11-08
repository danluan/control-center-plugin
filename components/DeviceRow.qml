import QtQuick
import qs.Commons

// A device in the "Dispositivos" section: icon badge, name, live status and an
// optional power switch. Clicking the row opens the device's full panel.
Item {
  id: row

  required property QtObject cc
  property string icon: ""
  property color iconTint: cc.accent
  property string name: ""
  property string status: ""
  property bool online: false
  property bool lit: false
  property bool hasPower: false
  property bool busy: false
  // Edit mode: the row shows/hides itself from the section instead of acting.
  property bool editing: false
  property bool shownInPanel: true

  signal opened()
  signal powerToggled()
  signal visibilityToggled()

  implicitHeight: Style.space(54)
  opacity: editing && !shownInPanel ? 0.45 : 1
  scale: area.pressed ? 0.985 : 1
  Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: cc.radius
    color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, area.containsMouse && !row.editing ? 0.10 : 0.05)
    border.width: 1
    border.color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, row.editing ? 0.22 : 0.06)
    Behavior on color { ColorAnimation { duration: Style.duration(140) } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.editing ? row.visibilityToggled() : row.opened()
  }

  // Icon badge: tinted when the device is on.
  Rectangle {
    id: badge
    x: Style.space(9)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(36)
    height: width
    radius: width / 2
    color: row.lit ? row.iconTint : Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.10)
    Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    Text {
      anchors.centerIn: parent
      text: row.icon
      color: row.lit ? cc.onAccent : (row.online ? cc.fg : cc.dim)
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading
      textFormat: Text.PlainText
    }
  }

  Column {
    anchors.left: badge.right
    anchors.leftMargin: Style.space(10)
    anchors.right: trailing.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: row.name
      color: cc.fg
      font.family: cc.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
    Text {
      width: parent.width
      text: row.status
      color: cc.dim
      font.family: cc.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
  }

  Item {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    width: row.editing ? Style.space(20) : (row.hasPower ? Style.space(38) : Style.space(14))
    height: Style.space(22)

    // Power switch.
    Rectangle {
      visible: row.hasPower && !row.editing
      anchors.centerIn: parent
      width: Style.space(38)
      height: Style.space(20)
      radius: height / 2
      color: row.lit ? cc.accent : "transparent"
      border.width: row.lit ? 0 : 1
      border.color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.45)
      opacity: row.online ? 1 : 0.4
      Behavior on color { ColorAnimation { duration: Style.duration(160) } }

      Rectangle {
        width: Style.space(12)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: row.lit ? parent.width - width - Style.space(4) : Style.space(4)
        color: row.lit ? cc.onAccent : cc.fg
        Behavior on x { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
      }

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        enabled: row.online && !row.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: row.powerToggled()
      }
    }

    Text {
      visible: !row.hasPower && !row.editing
      anchors.centerIn: parent
      text: "›"
      color: cc.dim
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading
      textFormat: Text.PlainText
    }

    Rectangle {
      visible: row.editing
      anchors.centerIn: parent
      width: Style.space(20)
      height: width
      radius: width / 2
      color: row.shownInPanel ? cc.accent : Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.25)
      Text {
        anchors.centerIn: parent
        text: row.shownInPanel ? "−" : "+"
        color: row.shownInPanel ? cc.onAccent : cc.fg
        font.family: cc.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        textFormat: Text.PlainText
      }
    }
  }
}
