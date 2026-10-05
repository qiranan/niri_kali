import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQml.Models 2.15

Item {
  property var session: sessionList.currentIndex
  implicitHeight: sessionButton.height
  implicitWidth: sessionButton.width

  DelegateModel {
    id: sessionWrapper
    model: sessionModel
    delegate: ItemDelegate {
      id: sessionEntry
      height: inputHeight
      width: parent.width
      highlighted: sessionList.currentIndex == index

      contentItem: Text {
        renderType: Text.NativeRendering
        font {
          family: config.Font
          pointSize: config.FontSize
          bold: true
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "#F0FFFFFF"
        text: name
      }

      // ── 双层半透明背景 ──────────────────────────
      background: Item {
        Rectangle {
          anchors.fill: parent
          radius: 18
          // highlighted 时加深填充，普通时极薄
          color: sessionEntry.highlighted ? "#30FFFFFF" : "#18FFFFFF"

          Behavior on color {
            ColorAnimation { duration: 300 }
          }
        }
        Rectangle {
          anchors.fill: parent
          radius: 18
          color: "transparent"
          border.color: sessionEntry.highlighted ? "#656C6C" : "#55FFFFFF"
          border.width: sessionEntry.highlighted ? 2 : 1

          Behavior on border.color {
            ColorAnimation { duration: 300 }
          }
        }
      }
      // ────────────────────────────────────────────

      MouseArea {
        anchors.fill: parent
        onClicked: {
          sessionList.currentIndex = index
          sessionPopup.close()
        }
      }
    }
  }

  // ── Session 按钮 ─────────────────────────────────
  Button {
    id: sessionButton
    height: inputHeight
    width: inputHeight
    hoverEnabled: true
    icon {
      source: Qt.resolvedUrl("../icons/settings.svg")
      height: height
      width: width
      color: "#F0FFFFFF"
    }

    background: Item {
      Rectangle {
        id: sessionBtnFill
        anchors.fill: parent
        radius: 18
        // hovered / pressed / popup-open 时加深
        color: (sessionButton.down || sessionButton.hovered || sessionPopup.visible)
               ? "#30FFFFFF" : "#18FFFFFF"

        Behavior on color {
          ColorAnimation { duration: 150 }
        }
      }
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: "#55FFFFFF"
        border.width: 1
      }
    }

    onClicked: {
      sessionPopup.visible ? sessionPopup.close() : sessionPopup.open()
    }
  }
  // ────────────────────────────────────────────────

  // ── Popup ────────────────────────────────────────
  Popup {
    id: sessionPopup
    width: inputWidth + padding * 2
    x: (sessionButton.width + sessionList.spacing) * -7.6
    y: -(contentHeight + padding * 2) + sessionButton.height
    padding: inputHeight / 10

    background: Item {
      // 外层：轻微半透明填充
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#18FFFFFF"
      }
      // 内层：边框
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: "#55FFFFFF"
        border.width: 1
      }
    }

    contentItem: ListView {
      id: sessionList
      implicitHeight: contentHeight
      spacing: 8
      model: sessionWrapper
      currentIndex: sessionModel.lastIndex
      clip: true
    }

    enter: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"; from: 0; to: 1
          duration: 400; easing.type: Easing.OutExpo
        }
        NumberAnimation {
          property: "x"
          from: sessionPopup.x + (inputWidth * 0.1)
          to: sessionPopup.x
          duration: 500; easing.type: Easing.OutExpo
        }
      }
    }
    exit: Transition {
      NumberAnimation {
        property: "opacity"; from: 1; to: 0
        duration: 300; easing.type: Easing.OutExpo
      }
    }
  }
  // ────────────────────────────────────────────────
}
