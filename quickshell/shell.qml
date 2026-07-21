import QtQuick
import Quickshell

import "./modules"

ShellRoot {
    id: root

    function toggleAudioMixer() {
        audioMixer.visible = !audioMixer.visible;
    }

    AudioMixer {
        id: audioMixer
        visible: false
    }
    OSD {}
    BrightnessOSD {}

    // One Bar per connected screen. Variants reactively tracks
    // Quickshell.screens, so panels are re-created on monitor
    // hotplug / enable-disable (survives Hyprland monitor cycles).
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
