import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: userField
    selectByMouse: true
    echoMode: TextInput.Normal
    selectionColor: "#44FFFFFF"
    renderType: Text.NativeRendering
    font {
        family: config.Font
        pointSize: config.FontSize
        bold: true
    }
    color: "#F0FFFFFF"
    palette {
        text: "#F0FFFFFF"
        placeholderText: "#88FFFFFF"
    }
    horizontalAlignment: Text.AlignHCenter
    placeholderText: "Username"
    text: userModel.lastUser

    background: Item {
        id: buttonBackground
        Rectangle {
          anchors.fill: parent
          radius: 18
          color: "#18FFFFFF"
        }

        Rectangle {
          anchors.fill: parent
          radius: 18
          color: "transparent"
          border.color: "#55FFFFFF"
          border.width: 1
        }
    }
}
