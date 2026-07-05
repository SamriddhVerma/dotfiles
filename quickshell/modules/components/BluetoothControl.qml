pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

Item {
    id: root

    property var popups: null
    readonly property bool expanded: popups ? popups.current === "bluetooth" : false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false

    // Reactive: reading each device's `connected` inside the binding makes it
    // re-evaluate whenever any device connects/disconnects.
    readonly property bool anyConnected: {
        const ds = Bluetooth.devices?.values ?? [];
        return ds.some(d => d.connected);
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: 30

    Text {
        id: icon
        anchors.centerIn: parent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
        color: root.enabled ? (root.anyConnected ? "#a6e3a1" : "#89b4fa") : "#6c7086"
        text: !root.enabled ? "\u{F00B2}" : (root.anyConnected ? "\u{F00B1}" : "\u{F00AF}")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.popups) root.popups.toggle("bluetooth")
    }

    LazyLoader {
        active: root.expanded

        PanelWindow {
            id: win
            anchors.top: true
            anchors.right: true
            margins.top: 6
            margins.right: 8
            implicitWidth: 340
            implicitHeight: card.implicitHeight
            color: "transparent"
            exclusiveZone: 0

            HyprlandFocusGrab {
                active: true
                windows: [win]
                onCleared: if (root.popups) root.popups.current = ""
            }

            Rectangle {
                id: card
                width: parent.width
                implicitHeight: col.implicitHeight + 24
                radius: 16
                color: "#f21e1e2e"
                border.color: "#45475a"
                border.width: 1

                ColumnLayout {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: "#cdd6f4"
                            text: "\u{F00AF}  Bluetooth"
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            visible: root.enabled
                            active: root.adapter?.discovering ?? false
                            text: (root.adapter?.discovering ?? false) ? "Scanning…" : "Scan"
                            onClicked: {
                                if (root.adapter)
                                    root.adapter.discovering = !root.adapter.discovering;
                            }
                        }

                        Pill {
                            active: root.enabled
                            text: root.enabled ? "On" : "Off"
                            onClicked: {
                                if (root.adapter)
                                    root.adapter.enabled = !root.enabled;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#313244"
                    }

                    Text {
                        visible: !root.enabled
                        Layout.fillWidth: true
                        color: "#6c7086"
                        font.pixelSize: 13
                        text: "Bluetooth is off"
                    }

                    Text {
                        visible: root.enabled && (Bluetooth.devices?.values.length ?? 0) === 0
                        Layout.fillWidth: true
                        color: "#6c7086"
                        font.pixelSize: 13
                        text: "No devices found — tap Scan"
                    }

                    Repeater {
                        model: root.enabled ? (Bluetooth.devices?.values ?? []) : []

                        delegate: RowLayout {
                            id: drow

                            required property var modelData
                            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting

                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: drow.modelData.connected ? "#a6e3a1" : "#cdd6f4"
                                text: "\u{F00AF}"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    text: drow.modelData.name || drow.modelData.address
                                }

                                Text {
                                    visible: drow.modelData.connected
                                    color: "#a6e3a1"
                                    font.pixelSize: 11
                                    text: drow.modelData.batteryAvailable
                                        ? "Connected · " + Math.round(drow.modelData.battery * 100) + "%"
                                        : "Connected"
                                }
                            }

                            Pill {
                                active: drow.modelData.connected
                                text: drow.busy ? "…" : (drow.modelData.connected ? "Disconnect" : "Connect")
                                onClicked: drow.modelData.connected = !drow.modelData.connected
                            }
                        }
                    }
                }
            }
        }
    }

    component Pill: Rectangle {
        id: pill

        property string text: ""
        property bool active: false
        signal clicked

        implicitWidth: pillLabel.implicitWidth + 18
        implicitHeight: pillLabel.implicitHeight + 8
        radius: height / 2
        color: pill.active ? "#89b4fa" : "#313244"

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.text
            color: pill.active ? "#11111b" : "#cdd6f4"
            font.pixelSize: 12
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }
}
