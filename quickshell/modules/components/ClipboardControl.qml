pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Clipboard history (Klipper-like) backed by `cliphist`.
// Records are kept by the `wl-paste --watch cliphist store` daemons started
// from hyprland.lua; this widget just lists / restores / deletes them.
Item {
    id: root

    property var popups: null
    readonly property bool expanded: popups ? popups.current === "clipboard" : false

    // [{ id: "12", preview: "…" }]
    property var entries: []
    property string filter: ""

    implicitWidth: icon.implicitWidth
    implicitHeight: 30

    function filtered(): var {
        const f = root.filter.trim().toLowerCase();
        if (f === "")
            return root.entries;
        return root.entries.filter(e => e.preview.toLowerCase().indexOf(f) >= 0);
    }

    function refresh(): void {
        listProc.running = true;
    }

    // cliphist decode <id> | wl-copy  — restores the entry as the current
    // selection (wl-clip-persist keeps it alive after the source app dies).
    function restore(id: string): void {
        actionProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
        actionProc.running = true;
        if (root.popups)
            root.popups.current = "";
    }

    // `cliphist delete` reads a list line and removes the entry by its id.
    function remove(id: string): void {
        delProc.command = ["sh", "-c", "printf '" + id + "\\t' | cliphist delete"];
        delProc.running = true;
    }

    function wipe(): void {
        wipeProc.running = true;
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                const list = [];
                const lines = listOut.text.split("\n");
                for (const line of lines) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    list.push({
                        id: line.substring(0, tab),
                        preview: line.substring(tab + 1)
                    });
                }
                root.entries = list;
            }
        }
    }

    Process {
        id: actionProc
    }

    Process {
        id: delProc
        onExited: root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    onExpandedChanged: {
        if (expanded) {
            root.filter = "";
            refresh();
        }
    }

    Text {
        id: icon
        anchors.centerIn: parent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        color: root.expanded ? "#89b4fa" : "#cdd6f4"
        text: "\u{F0192}"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.popups) root.popups.toggle("clipboard")
    }

    LazyLoader {
        active: root.expanded

        PanelWindow {
            id: win
            focusable: true
            anchors.top: true
            anchors.right: true
            margins.top: 6
            margins.right: 8
            implicitWidth: 380
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
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: "#cdd6f4"
                            text: "\u{F0192}  Clipboard"
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            visible: root.entries.length > 0
                            text: "Clear"
                            onClicked: root.wipe()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#313244"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 8
                        color: "#181825"
                        border.color: searchField.activeFocus ? "#89b4fa" : "#45475a"
                        border.width: 1

                        TextField {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "Search history…"
                            color: "#cdd6f4"
                            placeholderTextColor: "#6c7086"
                            font.pixelSize: 12
                            background: null
                            onTextChanged: root.filter = text
                            Component.onCompleted: forceActiveFocus()
                        }
                    }

                    Text {
                        visible: root.filtered().length === 0
                        color: "#6c7086"
                        font.pixelSize: 13
                        text: root.entries.length === 0 ? "History is empty" : "No matches"
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        implicitHeight: Math.min(contentHeight, 320)
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.filtered()

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            id: entry

                            required property var modelData

                            width: listView.width
                            implicitHeight: 34
                            radius: 8
                            color: entryMouse.containsMouse ? "#313244" : "#181825"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                    text: entry.modelData.preview
                                }

                                Rectangle {
                                    id: delBtn
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 11
                                    color: delMouse.containsMouse ? "#f38ba8" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: delMouse.containsMouse ? "#11111b" : "#6c7086"
                                        text: "\u{F0156}"
                                    }

                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.remove(entry.modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                anchors.rightMargin: 34
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.restore(entry.modelData.id)
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
