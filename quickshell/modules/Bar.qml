import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Hyprland

import "./components"

PanelWindow {
    id: root

    // WlrLayershell.layer: WlrLayer.Bottom

    Component.onCompleted: {
        if (this.WlrLayershell != null) {
            this.WlrLayershell.layer = WlrLayer.Bottom;
        }
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30
    color: '#28000000'

    // Shared popup manager: only one click-popup (network / bluetooth / clock)
    // may be open at a time. Setting `current` to a name opens that popup and
    // implicitly closes any other.
    QtObject {
        id: popups

        property string current: ""

        function toggle(name: string): void {
            current = current === name ? "" : name;
        }
    }

    RowLayout {

        spacing: 12

        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
        }

        Desktop {}

        Rectangle {
            Layout.fillWidth: true
        }

        NetworkControl {
            popups: popups
        }

        BluetoothControl {
            popups: popups
        }

        Battery {}

        Clock {
            popups: popups
        }
    }
}
