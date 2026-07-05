pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property var popups: null
    readonly property bool expanded: popups ? popups.current === "clock" : false

    property var now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()

    implicitWidth: label.implicitWidth
    implicitHeight: 30

    function shiftMonth(delta: int): void {
        let m = root.viewMonth + delta;
        let y = root.viewYear;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        root.viewMonth = m;
        root.viewYear = y;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Snap the calendar back to the current month each time it's opened.
    onExpandedChanged: {
        if (expanded) {
            root.viewYear = root.now.getFullYear();
            root.viewMonth = root.now.getMonth();
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: "#cdd6f4"
        text: Qt.formatDateTime(root.now, "hh:mm:ss  dd MMM")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.popups) root.popups.toggle("clock")
    }

    LazyLoader {
        active: root.expanded

        PanelWindow {
            id: win
            anchors.top: true
            anchors.right: true
            margins.top: 6
            margins.right: 8
            implicitWidth: 300
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            color: "#89b4fa"
                            font.pixelSize: 26
                            font.bold: true
                            text: Qt.formatDateTime(root.now, "dddd")
                        }

                        Text {
                            color: "#a6adc8"
                            font.pixelSize: 13
                            text: Qt.formatDateTime(root.now, "dd MMMM yyyy  \u00B7  hh:mm:ss")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#313244"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            color: "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                            text: grid.title
                        }

                        NavBtn {
                            glyph: "\u{F0141}"
                            onClicked: root.shiftMonth(-1)
                        }

                        NavBtn {
                            glyph: "\u{F0142}"
                            onClicked: root.shiftMonth(1)
                        }
                    }

                    DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: grid.locale

                        delegate: Text {
                            required property string shortName

                            horizontalAlignment: Text.AlignHCenter
                            color: "#6c7086"
                            font.pixelSize: 11
                            font.bold: true
                            text: shortName
                        }
                    }

                    MonthGrid {
                        id: grid

                        Layout.fillWidth: true
                        month: root.viewMonth
                        year: root.viewYear
                        spacing: 2

                        delegate: Item {
                            id: cell

                            required property var model

                            readonly property bool isToday: model.today
                            readonly property bool inMonth: model.month === grid.month

                            implicitWidth: 36
                            implicitHeight: 30

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: cell.isToday ? "#89b4fa" : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cell.model.day
                                font.pixelSize: 12
                                color: cell.isToday ? "#11111b" : (cell.inMonth ? "#cdd6f4" : "#585b70")
                            }
                        }
                    }
                }
            }
        }
    }

    component NavBtn: Rectangle {
        id: navBtn

        property string glyph: ""
        signal clicked

        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: navMouse.containsMouse ? "#313244" : "transparent"

        Text {
            anchors.centerIn: parent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: "#cdd6f4"
            text: navBtn.glyph
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }
    }
}
