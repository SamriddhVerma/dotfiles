pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

RowLayout {
    id: root

    spacing: 4

    readonly property int maxSlots: 20
    readonly property var focusedWs: Hyprland.focusedWorkspace

    // Show every regular workspace up to the highest occupied/focused one, plus
    // one spare empty slot (the "+1"). e.g. 1 busy -> show 1,2 ; 3 busy -> 1..4.
    readonly property int slotCount: {
        let hi = 0;
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            const w = vals[i];
            if (w.id > 0 && w.id > hi)
                hi = w.id;
        }
        const f = Hyprland.focusedWorkspace;
        if (f && f.id > hi)
            hi = f.id;
        return Math.min(root.maxSlots, hi + 1);
    }

    // Existing special workspaces (id < 0).
    readonly property var specialList: {
        const out = [];
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].id < 0)
                out.push(vals[i]);
        }
        return out;
    }

    function wsFor(id: int): var {
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].id === id)
                return vals[i];
        }
        return null;
    }

    // Hyprland runs in Lua dispatch mode here, so dispatchers take a Lua
    // expression. Shell out to hyprctl with the raw Lua form.
    Process {
        id: dispatcher
    }

    function focusWorkspace(id: int): void {
        dispatcher.exec(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"]);
    }

    function toggleSpecial(name: string): void {
        dispatcher.exec(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"" + name + "\")"]);
    }

    // Quickshell's workspace `active`/`focused` don't reflect whether a special
    // is currently shown on a monitor, so we track it ourselves. Map of
    // monitorName -> shown special id (0 = none). A special chip is "active"
    // when its id appears here.
    property var shownSpecials: ({})

    function isSpecialShown(id: int): bool {
        const m = root.shownSpecials;
        for (const k in m) {
            if (m[k] === id)
                return true;
        }
        return false;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "activespecialv2")
                return;
            // data: "<id>,<name>,<monitor>"  (id/name empty when hidden)
            const parts = event.data.split(",");
            const mon = parts[parts.length - 1];
            const id = parts[0] === "" ? 0 : parseInt(parts[0]);
            const next = Object.assign({}, root.shownSpecials);
            next[mon] = id;
            root.shownSpecials = next;
        }
    }

    // Seed the shown-special state at startup (no event has fired yet).
    Process {
        id: seedProc
        running: true
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            id: seedOut
            onStreamFinished: {
                try {
                    const mons = JSON.parse(seedOut.text);
                    const next = ({});
                    for (const m of mons) {
                        const sw = m.specialWorkspace;
                        next[m.name] = sw ? sw.id : 0;
                    }
                    root.shownSpecials = next;
                } catch (e) {
                    // ignore malformed output
                }
            }
        }
    }

    // ---- Regular workspaces ----
    Repeater {
        model: root.slotCount

        delegate: Rectangle {
            id: chip

            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: root.wsFor(wsId)
            readonly property bool active: root.focusedWs ? root.focusedWs.id === wsId : false
            readonly property bool urgent: ws ? ws.urgent : false
            // A non-focused workspace only persists in Hyprland while occupied.
            readonly property bool occupied: ws !== null && !active

            implicitWidth: Math.max(22, txt.implicitWidth + 12)
            implicitHeight: 22
            radius: 11
            color: chip.urgent ? "#f38ba8"
                 : chip.active ? "#89b4fa"
                 : (mouse.containsMouse ? "#313244" : "transparent")

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                id: txt
                anchors.centerIn: parent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.bold: chip.active
                text: chip.wsId
                color: (chip.active || chip.urgent) ? "#11111b"
                     : chip.occupied ? "#cdd6f4"
                     : "#585b70"
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusWorkspace(chip.wsId)
            }
        }
    }

    // ---- Separator (only when specials exist) ----
    Rectangle {
        visible: root.specialList.length > 0
        implicitWidth: 1
        implicitHeight: 14
        color: "#45475a"
        Layout.leftMargin: 2
        Layout.rightMargin: 2
    }

    // ---- Special workspaces ----
    Repeater {
        model: root.specialList

        delegate: Rectangle {
            id: spc

            required property var modelData
            readonly property bool active: root.isSpecialShown(modelData.id)
            readonly property bool urgent: modelData.urgent
            readonly property string shortName: {
                const n = modelData.name || "";
                return n.startsWith("special:") ? n.slice(8) : n;
            }

            implicitWidth: Math.max(22, slabel.implicitWidth + 12)
            implicitHeight: 22
            radius: 11
            color: spc.urgent ? "#f38ba8"
                 : spc.active ? "#cba6f7"
                 : (smouse.containsMouse ? "#313244" : "transparent")

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                id: slabel
                anchors.centerIn: parent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.bold: spc.active
                text: "\u{F04CE}" + (spc.shortName ? " " + spc.shortName : "")
                color: (spc.active || spc.urgent) ? "#11111b" : "#cba6f7"
            }

            MouseArea {
                id: smouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSpecial(spc.shortName)
            }
        }
    }
}
