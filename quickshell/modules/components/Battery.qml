pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Services.UPower

Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: !UPower.onBattery

    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    function fmtTime(seconds: real): string {
        if (!seconds || seconds <= 0)
            return "\u2014";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    function batteryGlyph(): string {
        if (!root.battery)
            return "\u{F0091}";
        const percent = Math.round(root.battery.percentage * 100);
        if (root.charging)
            return "\u{F0084}";
        if (percent > 80)
            return "\u{F0079}";
        if (percent > 60)
            return "\u{F0080}";
        if (percent > 40)
            return "\u{F007F}";
        if (percent > 20)
            return "\u{F007E}";
        return "\u{F007A}";
    }

    function stateText(s: int): string {
        switch (s) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.Empty:
            return "Empty";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Pending charge";
        case UPowerDeviceState.PendingDischarge:
            return "Pending discharge";
        default:
            return "Unknown";
        }
    }

    MouseArea {
        id: mousearea
        anchors.fill: parent
        hoverEnabled: true

        Text {
            id: label
            anchors.centerIn: parent
            font.family: "JetBrainsMono Nerd Font"
            color: "#cdd6f4"
            text: {
                if (!root.battery)
                    return "No Battery";
                return root.batteryGlyph() + " " + Math.round(root.battery.percentage * 100) + "%";
            }
        }
    }

    PopupWindow {
        id: popup

        visible: mousearea.containsMouse && root.battery

        anchor {
            item: label
            edges: Edges.Bottom
            rect {
                y: 30
            }
        }

        color: "transparent"
        implicitWidth: 270
        implicitHeight: card.height

        Rectangle {
            id: card

            width: 270
            height: col.implicitHeight + 24
            radius: 16
            color: "#f21e1e2e"
            border.color: "#45475a"
            border.width: 1

            ColumnLayout {
                id: col

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }

                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 30
                        color: root.charging ? "#a6e3a1" : "#89b4fa"
                        text: root.batteryGlyph()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            color: "#cdd6f4"
                            font.pixelSize: 22
                            font.bold: true
                            text: root.battery ? Math.round(root.battery.percentage * 100) + "%" : "\u2014"
                        }

                        Text {
                            color: root.charging ? "#a6e3a1" : "#a6adc8"
                            font.pixelSize: 12
                            text: root.battery ? root.stateText(root.battery.state) : ""
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#313244"
                }

                InfoRow {
                    label: "Power draw"
                    value: root.battery ? Math.abs(root.battery.changeRate).toFixed(1) + " W" : "\u2014"
                }

                InfoRow {
                    visible: root.charging
                    label: "Time to full"
                    value: root.battery ? root.fmtTime(root.battery.timeToFull) : "\u2014"
                }

                InfoRow {
                    visible: !root.charging
                    label: "Time to empty"
                    value: root.battery ? root.fmtTime(root.battery.timeToEmpty) : "\u2014"
                }

                InfoRow {
                    label: "Energy"
                    value: root.battery ? root.battery.energy.toFixed(1) + " / " + root.battery.energyCapacity.toFixed(1) + " Wh" : "\u2014"
                }

                InfoRow {
                    visible: root.battery && root.battery.healthSupported
                    label: "Health"
                    value: root.battery ? Math.round(root.battery.healthPercentage) + "%" : "\u2014"
                }
            }
        }
    }

    component InfoRow: RowLayout {
        id: infoRow

        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        Text {
            color: "#a6adc8"
            font.pixelSize: 12
            text: infoRow.label
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            color: "#cdd6f4"
            font.pixelSize: 12
            text: infoRow.value
        }
    }
}
