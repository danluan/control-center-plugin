import QtQuick
import qs.Commons

// Windows 11 style quick-settings tile. The body toggles; when the tile has
// details, a separate strip on the right (›) opens them.
Item {
  id: tile

  required property QtObject cc
  property string icon: ""
  property string label: ""
  property string detail: ""
  property bool active: false
  property bool busy: false
  property bool hasDetails: false
  property bool available: true
  // Edit mode: the tile no longer acts; it shows whether it is shown.
  property bool editing: false
  property bool shownInPanel: true
  property bool canMoveBack: false
  property bool canMoveForward: false

  signal toggled()
  signal detailsRequested()
  signal visibilityToggled()
  signal moveRequested(int direction)

  implicitHeight: Style.space(84)
  opacity: editing && !shownInPanel ? 0.45 : (available ? 1 : 0.55)

  readonly property bool lit: active && !editing
  readonly property color ink: lit ? cc.onAccent : cc.fg
  readonly property color inkDim: lit ? Qt.rgba(cc.onAccent.r, cc.onAccent.g, cc.onAccent.b, 0.72) : cc.dim
  readonly property real detailsWidth: hasDetails && !editing ? Style.space(28) : 0

  scale: (bodyArea.pressed || detailsArea.pressed) ? 0.97 : 1
  Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: cc.radius
    color: tile.lit
      ? (bodyArea.containsMouse ? Qt.lighter(cc.accent, 1.08) : cc.accent)
      : Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, bodyArea.containsMouse && !tile.editing ? 0.11 : 0.06)
    border.width: tile.lit ? 0 : 1
    border.color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, tile.editing ? 0.22 : 0.07)
    Behavior on color { ColorAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
  }

  // Details strip: its own hover shade and a hairline separating it.
  Rectangle {
    visible: tile.detailsWidth > 0
    x: parent.width - tile.detailsWidth
    width: tile.detailsWidth
    height: parent.height
    topRightRadius: cc.radius
    bottomRightRadius: cc.radius
    color: detailsArea.containsMouse ? Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.12) : "transparent"
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    Rectangle {
      width: 1
      height: parent.height * 0.5
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(tile.ink.r, tile.ink.g, tile.ink.b, 0.18)
    }

    Text {
      anchors.centerIn: parent
      text: "›"
      color: tile.ink
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading
      textFormat: Text.PlainText
    }
  }

  // Icon pinned to the top, text pinned to the bottom, so the tile breathes
  // instead of stacking everything against one edge.
  Text {
      x: Style.space(14)
      y: Style.space(12)
      text: tile.icon
      color: tile.ink
      font.family: cc.fontFamily
      font.pixelSize: Style.font.heading + Style.space(2)
      textFormat: Text.PlainText
      opacity: tile.busy ? 0.5 : 1
      SequentialAnimation on opacity {
        running: tile.busy
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: Style.duration(500) }
        NumberAnimation { to: 1; duration: Style.duration(500) }
      }
  }

  Column {
    x: Style.space(14)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(11)
    width: parent.width - tile.detailsWidth - Style.space(22)
    spacing: Style.space(4)

    Text {
      width: parent.width
      text: tile.label
      color: tile.ink
      font.family: cc.fontFamily
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: tile.detail
      color: tile.inkDim
      font.family: cc.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
  }

  MouseArea {
    id: bodyArea
    x: 0
    width: parent.width - tile.detailsWidth
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (tile.editing) { tile.visibilityToggled(); return }
      if (mouse.button === Qt.RightButton && tile.hasDetails) tile.detailsRequested()
      else tile.toggled()
    }
  }

  MouseArea {
    id: detailsArea
    visible: tile.detailsWidth > 0
    x: parent.width - tile.detailsWidth
    width: tile.detailsWidth
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.detailsRequested()
  }

  // Edit mode chrome: visibility badge and reorder arrows.
  Rectangle {
    visible: tile.editing
    width: Style.space(20)
    height: width
    radius: width / 2
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(6)
    color: tile.shownInPanel ? cc.accent : Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.25)
    Text {
      anchors.centerIn: parent
      text: tile.shownInPanel ? "−" : "+"
      color: tile.shownInPanel ? cc.onAccent : cc.fg
      font.family: cc.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      textFormat: Text.PlainText
    }
  }

  Row {
    visible: tile.editing
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.margins: Style.space(4)
    spacing: Style.space(2)

    Repeater {
      model: [-1, 1]
      delegate: Rectangle {
        required property int modelData
        readonly property bool enabledMove: modelData < 0 ? tile.canMoveBack : tile.canMoveForward
        width: Style.space(20)
        height: width
        radius: width / 2
        opacity: enabledMove ? 1 : 0.25
        color: moveArea.containsMouse && enabledMove ? Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.18) : "transparent"
        Text {
          anchors.centerIn: parent
          text: modelData < 0 ? "‹" : "›"
          color: cc.fg
          font.family: cc.fontFamily
          font.pixelSize: Style.font.title
          textFormat: Text.PlainText
        }
        MouseArea {
          id: moveArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: parent.enabledMove
          onClicked: tile.moveRequested(modelData)
        }
      }
    }
  }
}
