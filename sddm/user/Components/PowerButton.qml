import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
  implicitHeight: powerButton.height
  implicitWidth: powerButton.width

  Button {
    id: powerButton
    height: inputHeight
    width: inputHeight
    hoverEnabled: true
    icon {
      source: Qt.resolvedUrl("../icons/power.svg")
      height: height
      width: width
      color: "#F0FFFFFF"
    }

    background: Item {
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: powerButton.hovered ? "#30FFFFFF" : "#18FFFFFF"
        Behavior on color { ColorAnimation { duration: 300 } }
      }
      Rectangle {
        anchors.fill: parent
        radius: 18
        color: "transparent"
        border.color: powerButton.hovered ? "#88FFFFFF" : "#55FFFFFF"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 300 } }
      }
    }

    onClicked: sddm.powerOff()
  }
}
