import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
  id: passwordField
  focus: true
  selectByMouse: true
  placeholderText: "Password"
  echoMode: TextInput.Password
  passwordCharacter: "*"
  passwordMaskDelay: config.PasswordShowLastLetter
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
  horizontalAlignment: TextInput.AlignHCenter

  // ── 新增：记录原始 x 位置 ──────────────────────
  property real originX: 0
  Component.onCompleted: originX = x

  // ── 新增：抖动动画 ─────────────────────────────
  SequentialAnimation {
    id: shakeAnimation
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX - 12; duration: 60; easing.type: Easing.OutCubic }
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX + 12; duration: 60; easing.type: Easing.OutCubic }
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX - 8;  duration: 50; easing.type: Easing.OutCubic }
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX + 8;  duration: 50; easing.type: Easing.OutCubic }
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX - 4;  duration: 40; easing.type: Easing.OutCubic }
    PropertyAnimation { target: passwordField; property: "x"; to: passwordField.originX;      duration: 40; easing.type: Easing.OutCubic }
  }

  // ── 新增：对外暴露的调用方法 ───────────────────
  function shake() {
    shakeAnimation.stop()   // 若上次还在播放则先停止
    x = originX             // 复位，防止残留偏移
    shakeAnimation.start()
  }
  // ──────────────────────────────────────────────

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

  transitions: Transition {
    NumberAnimation {
      properties: "radius"
      duration: 250
      easing.type: Easing.OutCubic
    }
  }
}
