pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    // Pick a Nerd Font glyph matching the current level / mute state, matching
    // the glyph-based icon style used elsewhere in this config (e.g. Battery).
    function volumeGlyph(): string {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio || sink.audio.muted)
            return "󰝟"; // muted

        const v = sink.audio.volume;
        if (v <= 0.0)
            return "󰝟"; // muted / zero
        if (v < 0.34)
            return "󰕿"; // low
        if (v < 0.67)
            return "󰖀"; // medium
        return "󰕾"; // high
    }

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio

        function onVolumesChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    property bool shouldShowOsd: false

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    // The OSD window will be created and destroyed based on shouldShowOsd.
    // PanelWindow.visible could be set instead of using a loader, but using
    // a loader will reduce the memory overhead when the window isn't open.
    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            // Since the panel's screen is unset, it will be picked by the compositor
            // when the window is created. Most compositors pick the current active monitor.

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
                        text: root.volumeGlyph()
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

                            // Dim the fill while muted as an extra visual cue.
                            color: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "#80ffffff" : "white"
                            implicitWidth: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)
                            radius: parent.radius
                        }
                    }
                }
            }
        }
    }
}
