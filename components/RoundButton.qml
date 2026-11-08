import QtQuick
import qs.Commons

// Small circular icon button used in the footer and the media card.
Rectangle {
  id: button

  required property QtObject cc
  property string icon: ""
  property bool highlighted: false
  property real size: Style.space(30)
  property real iconSize: Style.font.title
  property string tooltip: ""

  signal clicked()

  width: size
  height: size
  radius: size / 2
  color: highlighted
    ? cc.accent
    : (area.containsMouse ? Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.13) : "transparent")
  scale: area.pressed ? 0.92 : 1
  Behavior on color { ColorAnimation { duration: Style.duration(120) } }
  Behavior on scale { NumberAnimation { duration: Style.duration(110); easing.type: Easing.OutCubic } }

  Text {
    anchors.centerIn: parent
    text: button.icon
    color: button.highlighted ? cc.onAccent : cc.fg
    font.family: cc.fontFamily
    font.pixelSize: button.iconSize
    textFormat: Text.PlainText
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
