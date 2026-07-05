pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    property var popups: null
    readonly property bool expanded: popups ? popups.current === "network" : false
    property bool wifiEnabled: true
    property var networks: []
    property string activeSsid: ""
    property int activeSignal: 0
    property var knownSsids: ({})
    property string statusMsg: ""
    property string pendingSsid: ""

    implicitWidth: icon.implicitWidth
    implicitHeight: 30

    function secured(sec) {
        return !!sec && sec.trim().length > 0;
    }

    function signalGlyph(s) {
        if (s >= 80) return "\u{F0928}";
        if (s >= 55) return "\u{F0925}";
        if (s >= 30) return "\u{F0922}";
        return "\u{F091F}";
    }

    function wifiGlyph() {
        if (!wifiEnabled) return "\u{F05AA}";
        if (activeSsid === "") return "\u{F05A9}";
        return signalGlyph(activeSignal);
    }

    // nmcli -t escapes ':' as '\:' and '\' as '\\'; split on unescaped colons.
    function splitFields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        statusProc.running = true;
        listProc.running = true;
        knownProc.running = true;
    }

    function setWifi(on) {
        radioProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        radioProc.running = true;
        root.wifiEnabled = on;
        Qt.callLater(root.refresh);
    }

    function rescan() {
        root.statusMsg = "Scanning…";
        rescanProc.running = true;
    }

    function doConnect(ssid, password) {
        root.statusMsg = "Connecting to " + ssid + "…";
        const cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (password && password.length > 0)
            cmd.push("password", password);
        connectProc.command = cmd;
        connectProc.running = true;
        root.pendingSsid = "";
    }

    function disconnect(ssid) {
        root.statusMsg = "Disconnecting…";
        actionProc.command = ["nmcli", "connection", "down", "id", ssid];
        actionProc.running = true;
    }

    function onNetworkClicked(net) {
        if (net.active) {
            root.disconnect(net.ssid);
            return;
        }
        if (root.secured(net.security) && !root.knownSsids[net.ssid]) {
            root.pendingSsid = (root.pendingSsid === net.ssid) ? "" : net.ssid;
            return;
        }
        root.doConnect(net.ssid, "");
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            id: statusOut
            onStreamFinished: root.wifiEnabled = statusOut.text.trim() === "enabled"
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            id: knownOut
            onStreamFinished: {
                const map = ({});
                const lines = knownOut.text.split("\n");
                for (const line of lines) {
                    if (!line) continue;
                    const f = root.splitFields(line);
                    if (f[1] && f[1].indexOf("wireless") >= 0)
                        map[f[0]] = true;
                }
                root.knownSsids = map;
            }
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                const seen = ({});
                const list = [];
                let actSsid = "";
                let actSig = 0;
                const lines = listOut.text.split("\n");
                for (const line of lines) {
                    if (!line) continue;
                    const f = root.splitFields(line);
                    const active = f[0] === "yes";
                    const ssid = f[1] || "";
                    const sig = parseInt(f[2] || "0") || 0;
                    const sec = f[3] || "";
                    if (ssid === "") continue;
                    if (active) {
                        actSsid = ssid;
                        actSig = sig;
                    }
                    if (seen[ssid] !== undefined) {
                        const ex = list[seen[ssid]];
                        if (sig > ex.signal) ex.signal = sig;
                        if (active) ex.active = true;
                        continue;
                    }
                    seen[ssid] = list.length;
                    list.push({ ssid: ssid, signal: sig, security: sec, active: active });
                }
                list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = list;
                root.activeSsid = actSsid;
                root.activeSignal = actSig;
            }
        }
    }

    Process { id: radioProc }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            root.statusMsg = "";
            root.refresh();
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {
            id: connectOut
            onStreamFinished: {
                root.statusMsg = "";
                root.refresh();
            }
        }
        stderr: StdioCollector {
            id: connectErr
            onStreamFinished: {
                const t = connectErr.text.trim();
                if (t !== "")
                    root.statusMsg = t.replace(/^Error:\s*/, "");
            }
        }
    }

    Process {
        id: actionProc
        onExited: root.refresh()
    }

    onExpandedChanged: if (expanded) refresh()

    Timer {
        interval: 8000
        running: root.expanded
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    Text {
        id: icon
        anchors.centerIn: parent
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
        color: root.wifiEnabled ? (root.activeSsid !== "" ? "#89b4fa" : "#cdd6f4") : "#6c7086"
        text: root.wifiGlyph()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.popups) root.popups.toggle("network")
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
            implicitWidth: 360
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
                            text: "\u{F05A9}  Wi-Fi"
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            visible: root.wifiEnabled
                            text: "Rescan"
                            onClicked: root.rescan()
                        }

                        Pill {
                            active: root.wifiEnabled
                            text: root.wifiEnabled ? "On" : "Off"
                            onClicked: root.setWifi(!root.wifiEnabled)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#313244"
                    }

                    Text {
                        visible: !root.wifiEnabled
                        color: "#6c7086"
                        font.pixelSize: 13
                        text: "Wi-Fi is off"
                    }

                    Text {
                        visible: root.statusMsg !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: "#f9e2af"
                        font.pixelSize: 11
                        text: root.statusMsg
                    }

                    Repeater {
                        model: root.wifiEnabled ? root.networks : []

                        delegate: ColumnLayout {
                            id: nrow

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    color: nrow.modelData.active ? "#a6e3a1" : "#cdd6f4"
                                    text: root.signalGlyph(nrow.modelData.signal)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: nrow.modelData.active ? "#a6e3a1" : "#cdd6f4"
                                    font.pixelSize: 13
                                    text: nrow.modelData.ssid
                                }

                                Text {
                                    visible: root.secured(nrow.modelData.security)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: "#6c7086"
                                    text: "\u{F033E}"
                                }

                                Pill {
                                    active: nrow.modelData.active
                                    text: nrow.modelData.active ? "Disconnect" : "Connect"
                                    onClicked: root.onNetworkClicked(nrow.modelData)
                                }
                            }

                            RowLayout {
                                id: pwRow
                                visible: root.pendingSsid === nrow.modelData.ssid
                                Layout.fillWidth: true
                                spacing: 6

                                onVisibleChanged: if (visible) pwField.forceActiveFocus()

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: 8
                                    color: "#181825"
                                    border.color: pwField.activeFocus ? "#89b4fa" : "#45475a"
                                    border.width: 1

                                    TextField {
                                        id: pwField
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        placeholderText: "Password"
                                        color: "#cdd6f4"
                                        placeholderTextColor: "#6c7086"
                                        font.pixelSize: 12
                                        background: null
                                        onAccepted: root.doConnect(nrow.modelData.ssid, text)
                                    }
                                }

                                Pill {
                                    active: true
                                    text: "Join"
                                    onClicked: root.doConnect(nrow.modelData.ssid, pwField.text)
                                }
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
