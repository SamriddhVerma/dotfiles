pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Backlight device under /sys/class/backlight, auto-detected at startup.
    property string device: ""
    // Current brightness as a 0..1 fraction of max_brightness.
    property real brightness: 0
    // Suppresses the OSD for the very first reading (startup, not a real change).
    property bool initialised: false
    property bool shouldShowOsd: false

    // Nerd Font glyph matching the brightness level (matches config icon style).
    function brightnessGlyph(): string {
        return root.brightness < 0.5 ? "󰃞" : "󰃠";
    }

    // Pick the first backlight device present on the machine.
    Process {
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight/ | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    // max_brightness is static; a single blocking read is fine.
    FileView {
        id: maxBrightness
        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        blockLoading: true
        printErrors: false
        onLoaded: root.updateBrightness()
    }

    // brightness changes whenever brightnessctl (Hyprland keybinds) writes it.
    // inotify fires on sysfs writes, so watchChanges is enough - no polling.
    FileView {
        id: curBrightness
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.updateBrightness()
    }

    function updateBrightness(): void {
        const max = parseInt(maxBrightness.text());
        const cur = parseInt(curBrightness.text());
        if (isNaN(max) || isNaN(cur) || max <= 0)
            return;

        const value = Math.max(0, Math.min(1, cur / max));
        const changed = Math.abs(value - root.brightness) > 0.0001;
        root.brightness = value;

        if (root.initialised && changed) {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
        root.initialised = true;
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            anchors.bottom: true
            margins.bottom: screen.height / 5
            exclusiveZone: 0

            implicitWidth: 400
            implicitHeight: 50
            color: "transparent"

            // An empty click mask prevents the window from blocking mouse events.
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#80000000"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 15
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        color: "white"
                        text: root.brightnessGlyph()
                    }

                    Rectangle {
                        // Stretches to fill all left-over space
                        Layout.fillWidth: true

                        implicitHeight: 10
                        radius: 20
                        color: "#50ffffff"

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }

                            color: "white"
                            implicitWidth: parent.width * root.brightness
                            radius: parent.radius
                        }
                    }
                }
            }
        }
    }
}
