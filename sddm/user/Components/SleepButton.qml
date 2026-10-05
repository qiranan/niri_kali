import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
  implicitHeight: sleepButton.height
  implicitWidth: sleepButton.width

  Button {
    id: sleepButton
    height: inputHeight
    width: inputHeight
    hoverEnabled: true
    icon {
      source: Qt.resolvedUrl("../icons/sleep.svg")
      height: height
      width: width
      color: "#F0FFFFFF"
    }

    background: Item {
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: sleepButton.hovered ? "#30FFFFFF" : "#18FFFFFF"
        Behavior on color { ColorAnimation { duration: 300 } }
      }
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: sleepButton.hovered ? "#88FFFFFF" : "#55FFFFFF"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 300 } }
      }
    }

    onClicked: sddm.suspend()
  }
}
