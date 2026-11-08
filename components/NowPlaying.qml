import QtQuick
import qs.Commons

// "Now playing" card driven by an MPRIS player.
Item {
  id: card

  required property QtObject cc
  property var player: null
  property string sourceLabel: ""

  readonly property string title: player ? String(player.trackTitle || "") : ""
  readonly property string artist: player ? String(player.trackArtist || player.identity || "") : ""
  readonly property string art: player ? String(player.trackArtUrl || "") : ""
  readonly property bool playing: !!player && !!player.isPlaying
  readonly property real length: player && player.lengthSupported ? Number(player.length || 0) : 0
  property real position: 0

  implicitHeight: Style.space(78)

  // MPRIS does not signal position while playing; poll it while visible.
  Timer {
    interval: 1000
    repeat: true
    running: card.visible && card.playing && card.player && card.player.positionSupported
    triggeredOnStart: true
    onTriggered: if (card.player) card.position = Number(card.player.position || 0)
  }
  onPlayerChanged: position = player && player.positionSupported ? Number(player.position || 0) : 0

  Rectangle {
    anchors.fill: parent
    radius: cc.radius
    color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.05)
    border.width: 1
    border.color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.06)
    clip: true

    // Progress hairline along the bottom edge.
    Rectangle {
      visible: card.length > 0
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.leftMargin: cc.radius / 2
      height: Style.space(2)
      width: (parent.width - cc.radius) * Math.max(0, Math.min(1, card.position / Math.max(1, card.length)))
      radius: height / 2
      color: cc.accent
    }
  }

  Rectangle {
    id: cover
    x: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(56)
    height: width
    radius: cc.radius * 0.75
    color: Qt.rgba(cc.fg.r, cc.fg.g, cc.fg.b, 0.10)
    clip: true

    Image {
      id: coverImage
      anchors.fill: parent
      source: card.art
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 128
      sourceSize.height: 128
      visible: status === Image.Ready
    }
    Text {
      visible: !coverImage.visible
      anchors.centerIn: parent
      text: "󰎆"
      color: cc.dim
      font.family: cc.fontFamily
      font.pixelSize: Style.font.display
      textFormat: Text.PlainText
    }
  }

  Column {
    anchors.left: cover.right
    anchors.leftMargin: Style.space(12)
    anchors.right: controls.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: card.sourceLabel
      visible: text !== ""
      color: cc.accent
      font.family: cc.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 0.8
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
    Text {
      width: parent.width
      text: card.title
      color: cc.fg
      font.family: cc.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
    Text {
      width: parent.width
      text: card.artist
      color: cc.dim
      font.family: cc.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }
  }

  Row {
    id: controls
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    RoundButton {
      cc: card.cc
      icon: "󰒮"
      opacity: card.player && card.player.canGoPrevious ? 1 : 0.35
      onClicked: if (card.player && card.player.canGoPrevious) card.player.previous()
    }
    RoundButton {
      cc: card.cc
      icon: card.playing ? "󰏤" : "󰐊"
      highlighted: true
      size: Style.space(34)
      onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying()
    }
    RoundButton {
      cc: card.cc
      icon: "󰒭"
      opacity: card.player && card.player.canGoNext ? 1 : 0.35
      onClicked: if (card.player && card.player.canGoNext) card.player.next()
    }
  }
}
