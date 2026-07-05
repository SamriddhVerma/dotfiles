import QtQuick
import Quickshell

Text {

    required property var onClicked

    function click() {
        if (mouseArea.containsMouse) {
            onClicked();
        }
    }

    color: "#fff"
    text: "Sound"

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
