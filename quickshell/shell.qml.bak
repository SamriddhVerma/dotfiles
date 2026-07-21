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
    Bar {}
}
