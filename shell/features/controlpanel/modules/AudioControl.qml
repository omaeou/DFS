import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import "../../shared"
import "../../../core/services"

Item {
    id: root

    property var panel: null
    property var theme: GlobalState.effectiveTheme
    property var modConf: ({})
    property bool microphone: false

    readonly property string nodeType: microphone ? "source" : "sink"
    readonly property string heading: microphone ? "МИКРОФОН" : "ГРОМКОСТЬ"
    readonly property string glyph: microphone ? "󰍬" : "󰕾"
    readonly property int volumeLimit: AudioService.volumeLimit(nodeType)
    readonly property int currentVolume: microphone ? AudioService.inputVolume : AudioService.outputVolume
    readonly property bool isMuted: microphone ? AudioService.inputMuted : AudioService.outputMuted
    readonly property bool nodeAvailable: microphone ? AudioService.inputAvailable : AudioService.outputAvailable
    readonly property string commandError: microphone ? AudioService.inputErrorMessage : AudioService.outputErrorMessage

    implicitWidth: 292
    implicitHeight: 108

    function requestVolumeWrite(value) {
        // QML Slider.moved fires only for direct interaction. Backend changes update
        // the bound value without writing back recursively.
        AudioService.setVolume(nodeType, Math.round(value))
    }

    function toggleMute() {
        AudioService.toggleMute(nodeType)
    }

    Rectangle {
        id: cardBackground
        anchors.fill: parent
        radius: Number(theme.elementRadius) || 8
        border.width: 1
        border.color: theme.frame || theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.surfaceTop || "#26191e" }
            GradientStop { position: 1.0; color: theme.surfaceBottom || theme.bg }
        }
    }

    Rectangle {
        anchors.fill: cardBackground
        anchors.margins: 4
        radius: Math.max(2, (Number(theme.elementRadius) || 8) - 3)
        color: "transparent"
        border.width: GlobalState.ornamentsEnabled ? 1 : 0
        border.color: theme.rune || theme.accent
        opacity: 0.18
    }

    Rectangle {
        x: 13; y: 0; width: 34; height: 2; radius: 1
        visible: GlobalState.ornamentsEnabled
        color: GlobalState.config.appearance.glow ? (theme.accentGlow || theme.accentActive) : (theme.rune || theme.accentActive)
        opacity: 0.62
        SequentialAnimation on opacity {
            running: GlobalState.idleEffectsEnabled && GlobalState.isControlPanelOpen
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: GlobalState.animationDuration(1500); easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.85; duration: GlobalState.animationDuration(1500); easing.type: Easing.InOutSine }
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 9
        anchors.bottomMargin: 7

        Row {
            id: headingRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 33
            spacing: 8

            Rectangle {
                width: 29; height: 29; radius: 6
                color: theme.bgAlt
                border.width: 1
                border.color: theme.frame || theme.border
                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    color: root.isMuted ? theme.textDark : (theme.accentGlow || theme.accentActive)
                    font.family: theme.font
                    font.pixelSize: 16
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(60, parent.width - 171)
                spacing: 2
                Text {
                    text: root.heading
                    color: theme.textLight
                    font.family: theme.font
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.0
                }
                Text {
                    text: !Pipewire.ready ? "PIPEWIRE · ЗАПУСК" :
                          (!root.nodeAvailable ? "УСТРОЙСТВО НЕ НАЙДЕНО" :
                          (root.isMuted ? "ЗВУК ЗАПЕЧАТАН" : "СИСТЕМА АКТИВНА"))
                    color: (!Pipewire.ready || !root.nodeAvailable || root.isMuted) ?
                           (theme.accentGlow || theme.accentActive) : (theme.rune || theme.textDark)
                    font.family: theme.font
                    font.pixelSize: 8
                    font.letterSpacing: 0.35
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                text: root.isMuted ? "MUTE" : (root.modConf.showPercentage !== false ? Math.round(root.currentVolume) + "%" : "ACTIVE")
                color: root.isMuted ? (theme.accentGlow || theme.accentActive) : theme.textLight
                font.family: theme.font
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignRight
            }

            Rectangle {
                width: 25; height: 25; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: root.isMuted ? theme.bgHover : "transparent"
                border.width: 1
                border.color: root.isMuted ? (theme.accentGlow || theme.accentActive) : theme.frame
                opacity: root.nodeAvailable ? 1.0 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: root.isMuted ? "󰝟" : (root.microphone ? "󰍬" : "󰝚")
                    color: root.isMuted ? (theme.accentGlow || theme.accentActive) : theme.textMain
                    font.family: theme.font
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.nodeAvailable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMute()
                }
            }

            Rectangle {
                width: 25; height: 25
                anchors.verticalCenter: parent.verticalCenter
                color: selectorMouse.containsMouse ? theme.bgHover : "transparent"
                border.width: 1
                border.color: selectorMouse.containsMouse ? (theme.accentGlow || theme.accentActive) : theme.frame
                opacity: Pipewire.ready ? 1.0 : 0.45
                Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(100) } }
                Text {
                    anchors.centerIn: parent
                    text: "⇄"
                    color: selectorMouse.containsMouse ? (theme.accentGlow || theme.accentActive) : theme.textMain
                    font.family: theme.font
                    font.pixelSize: 14
                }
                MouseArea {
                    id: selectorMouse
                    anchors.fill: parent
                    enabled: Pipewire.ready && root.panel !== null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.panel.audioTab = root.microphone ? "source" : "sink"
                        root.panel.openCustomMenu("audio", root.microphone ? "Устройства ввода" : "Устройства вывода")
                    }
                }
            }
        }

        Slider {
            id: volumeSlider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headingRow.bottom
            anchors.topMargin: 5
            height: 26
            from: 0
            to: root.volumeLimit
            stepSize: Math.max(1, Number(root.modConf.step) || 1)
            value: root.currentVolume
            live: true
            enabled: root.nodeAvailable
            opacity: enabled ? 1.0 : 0.5
            onMoved: root.requestVolumeWrite(value)

            background: Rectangle {
                x: volumeSlider.leftPadding + 4
                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                width: Math.max(0, volumeSlider.availableWidth - 8)
                height: 7
                radius: 3
                color: theme.bgAlt
                border.width: 1
                border.color: theme.frame || theme.border
                clip: true

                Rectangle {
                    width: volumeSlider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: theme.accent || "#8a1728" }
                        GradientStop { position: 0.8; color: theme.accentActive || "#ff334f" }
                        GradientStop { position: 1.0; color: theme.accentGlow || "#ff6579" }
                    }
                }

                Repeater {
                    model: GlobalState.config.appearance.animations === "off" ? 0 : 5
                    delegate: Rectangle {
                        required property int index
                        x: (index + 1) * parent.width / 6
                        y: 2
                        width: 1
                        height: 3
                        color: theme.rune || "#c5a47d"
                        opacity: 0.55
                    }
                }
            }

            handle: Item {
                width: 19
                height: 19
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                scale: volumeSlider.pressed ? 1.12 : 1.0
                Behavior on scale { NumberAnimation { duration: GlobalState.animationDuration(120); easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 15; height: 15; radius: 2; rotation: 45
                    color: theme.surfaceBottom || "#0c0a0e"
                    border.width: 1.5
                    border.color: volumeSlider.pressed ? (theme.accentGlow || theme.accentActive) : (theme.rune || theme.accent)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 4; rotation: 45; radius: 1
                    color: theme.accentGlow || theme.accentActive
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 11
            spacing: 4
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.microphone ? "ᚱ  INPUT CHANNEL" : "ᚱ  OUTPUT CHANNEL"
                color: theme.textDark
                font.family: theme.font
                font.pixelSize: 7
                font.letterSpacing: 0.5
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                text: root.commandError !== "" ? "!  ERROR" : (root.volumeLimit > 100 ? "BOOST " + root.volumeLimit + "%" : "MAX 100%")
                color: root.commandError !== "" ? (theme.accentGlow || theme.accentActive) : (theme.rune || theme.textDark)
                font.family: theme.font
                font.pixelSize: 7
            }
        }
    }
}
