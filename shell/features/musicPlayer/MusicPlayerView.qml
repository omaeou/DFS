import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared"
import "../../core/services"

PanelWindow {
    id: root
    visible: GlobalState.isEqualizerOpen
    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Normal
    margins.top: GlobalState.popupTopMargin
    margins.right: GlobalState.config.geometry.marginRight
    implicitWidth: 560
    implicitHeight: 620
    color: "transparent"

    property string currentPreset: "Не подключен"
    property string activeOutput: "Нет активного потока"
    property bool eqAvailable: false
    property var eqData: ({ b1: 0, b2: 0, b3: 0, b4: 0, b5: 0, b6: 0, b7: 0, b8: 0, b9: 0, b10: 0, preset: "Custom", available: false })
    readonly property string scriptPath: Quickshell.shellDir + "/features/musicPlayer/equalizer.sh"

    function runEqualizer(args) {
        eqCommandProcess.running = false
        eqCommandProcess.command = ["bash", root.scriptPath].concat(args)
        eqCommandProcess.running = true
    }
    function formatGain(value) {
        const rounded = Math.round((Number(value) || 0) * 10) / 10
        return rounded.toFixed(1).replace(/\.0$/, "") + " dB"
    }
    function setBand(band, value) {
        if (!root.eqAvailable) return
        const updated = Object.assign({}, root.eqData)
        const gain = Math.round(Number(value) * 10) / 10
        updated["b" + band] = gain
        updated.preset = "Custom"
        root.eqData = updated
        root.runEqualizer(["set_band", String(band), String(gain)])
    }
    function selectPreset(name) {
        if (!root.eqAvailable) return
        const updated = Object.assign({}, root.eqData)
        updated.preset = name
        root.eqData = updated
        root.runEqualizer(["preset", name])
    }
    function openEasyEffects() {
        if (!easyEffectsProcess.running) {
            easyEffectsProcess.command = ["easyeffects"]
            easyEffectsProcess.running = true
        }
    }
    function refreshEqualizer() {
        if (!eqStateProcess.running) eqStateProcess.running = true
        if (!sinkInputsProcess.running) sinkInputsProcess.running = true
    }

    Process {
        id: eqStateProcess
        command: ["bash", root.scriptPath, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.eqData = JSON.parse(String(text).trim())
                    root.eqAvailable = root.eqData.available === true
                }
                catch (error) { console.warn("[DFS:eq] Could not read equalizer state:", String(error)) }
            }
        }
    }
    Process {
        id: presetProcess
        command: ["bash", root.scriptPath, "current_preset"]
        stdout: StdioCollector { onStreamFinished: root.currentPreset = String(text).trim() || "Без пресета" }
    }
    Process {
        id: sinkInputsProcess
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const streams = JSON.parse(text)
                    const labels = []
                    for (let i = 0; i < streams.length; ++i) {
                        const props = streams[i].properties || ({})
                        const app = String(props["application.name"] || props["media.name"] || streams[i].name || "").trim()
                        if (app && labels.indexOf(app) < 0) labels.push(app)
                    }
                    root.activeOutput = labels.length ? labels.join(" · ") : "Нет активного потока"
                } catch (error) { root.activeOutput = "Нет данных о потоках" }
            }
        }
    }
    Process {
        id: eqCommandProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.eqAvailable = false
        }
    }
    Process { id: easyEffectsProcess }
    Timer {
        interval: 1200; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshEqualizer()
    }
    Timer {
        interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!presetProcess.running) presetProcess.running = true
            if (!sinkInputsProcess.running) sinkInputsProcess.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: GlobalState.effectiveTheme.radius
        color: GlobalState.effectiveTheme.bg
        border.color: GlobalState.effectiveTheme.frame
        gradient: Gradient {
            GradientStop { position: 0; color: GlobalState.effectiveTheme.surfaceTop }
            GradientStop { position: 1; color: GlobalState.effectiveTheme.surfaceBottom }
        }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "ЗВУКОВОЙ АЛТАРЬ"; color: GlobalState.effectiveTheme.rune; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: "Музыка и эквалайзер"; color: GlobalState.effectiveTheme.textLight; font.pixelSize: 17; font.bold: true }
                }
                Rectangle {
                    width: 30; height: 30; radius: 6; color: GlobalState.effectiveTheme.bgAlt; border.color: GlobalState.effectiveTheme.frame
                    Text { anchors.centerIn: parent; text: "×"; color: GlobalState.effectiveTheme.textMain; font.pixelSize: 19 }
                    MouseArea { id: closeHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GlobalState.isEqualizerOpen = false }
                    ThemeToolTip { targetItem: closeHit; visible: closeHit.containsMouse; text: "Закрыть музыкальное окно" }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 136; radius: 9
                color: GlobalState.effectiveTheme.bgAlt; border.color: GlobalState.effectiveTheme.frame
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 12
                    Item {
                        Layout.preferredWidth: 86; Layout.preferredHeight: 86
                        Rectangle {
                            anchors.fill: parent; radius: 8
                            color: GlobalState.effectiveTheme.surfaceBottom
                            border.color: GlobalState.effectiveTheme.rune; border.width: 1
                            clip: true
                            Image {
                                id: coverImage
                                anchors.fill: parent; anchors.margins: 3
                                source: MusicService.artUrl ? "file://" + MusicService.artUrl : ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text { anchors.centerIn: parent; text: "♫"; color: GlobalState.effectiveTheme.accentGlow; font.pixelSize: 27; visible: coverImage.status !== Image.Ready }
                        }
                        Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: 2; border.color: GlobalState.effectiveTheme.accentActive; opacity: MusicService.playing ? 0.8 : 0.25 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 4
                        Text { Layout.fillWidth: true; text: MusicService.title; color: GlobalState.effectiveTheme.textLight; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: MusicService.artist; color: GlobalState.effectiveTheme.textMain; font.pixelSize: 10; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: "ИСТОЧНИК · " + (MusicService.playerName || "ожидание Spotify / MPRIS"); color: GlobalState.effectiveTheme.rune; font.pixelSize: 8; elide: Text.ElideRight }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: ["⏮", MusicService.playing ? "⏸" : "▶", "⏭"]
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    Layout.preferredWidth: index === 1 ? 38 : 32
                                    Layout.preferredHeight: 27
                                    radius: 6
                                    color: index === 1 ? GlobalState.effectiveTheme.borderActive : GlobalState.effectiveTheme.surfaceBottom
                                    border.color: index === 1 ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                                    Text { anchors.centerIn: parent; text: modelData; color: GlobalState.effectiveTheme.rune; font.pixelSize: index === 1 ? 14 : 15 }
                                    MouseArea {
                                        id: transportHit
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: index === 0 ? MusicService.previous() : index === 1 ? MusicService.togglePlayback() : MusicService.next()
                                    }
                                    ThemeToolTip {
                                        targetItem: transportHit
                                        visible: transportHit.containsMouse
                                        text: index === 0 ? "Предыдущий трек" : (index === 1 ? (MusicService.playing ? "Пауза" : "Воспроизвести") : "Следующий трек")
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Slider {
                            id: progressSlider
                            Layout.fillWidth: true; Layout.preferredHeight: 14
                            hoverEnabled: true
                            from: 0; to: 100; value: MusicService.percent
                            property bool wasPressed: false
                            onPressedChanged: {
                                if (pressed) {
                                    wasPressed = true
                                } else if (wasPressed) {
                                    wasPressed = false
                                    if (MusicService.length > 0)
                                        MusicService.seekTo(MusicService.length * value / 100)
                                }
                            }
                            Connections {
                                target: MusicService
                                function onTrackInfoChanged() {
                                    if (!progressSlider.pressed)
                                        progressSlider.value = MusicService.percent
                                }
                            }
                            background: Rectangle {
                                x: progressSlider.leftPadding; y: progressSlider.topPadding + (progressSlider.availableHeight - 4) / 2
                                width: progressSlider.availableWidth; height: 4; radius: 2; color: GlobalState.effectiveTheme.border
                                Rectangle { width: progressSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: GlobalState.effectiveTheme.accentActive }
                            }
                            handle: Rectangle {
                                x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                                y: progressSlider.topPadding + (progressSlider.availableHeight - height) / 2
                                width: 9; height: 9; radius: 5; color: GlobalState.effectiveTheme.rune; border.color: GlobalState.effectiveTheme.accentGlow
                            }
                            ThemeToolTip {
                                targetItem: progressSlider
                                visible: progressSlider.hovered
                                text: "Позиция · " + MusicService.positionText + " / " + MusicService.lengthText + " · перетащите шкалу для перемотки"
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: MusicService.positionText; color: GlobalState.effectiveTheme.textDark; font.pixelSize: 8 }
                            Item { Layout.fillWidth: true }
                            Text { text: "ВЫХОД · " + root.activeOutput; color: GlobalState.effectiveTheme.textDark; font.pixelSize: 8; elide: Text.ElideRight; Layout.maximumWidth: 190 }
                            Text { text: MusicService.lengthText; color: GlobalState.effectiveTheme.textDark; font.pixelSize: 8 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "ПРЕСЕТ · " + root.eqData.preset; color: GlobalState.effectiveTheme.rune; font.pixelSize: 9; font.letterSpacing: 0.8 }
                Text { text: "EASYEFFECTS · " + root.currentPreset; color: GlobalState.effectiveTheme.textDark; font.pixelSize: 8; elide: Text.ElideRight; Layout.maximumWidth: 170 }
            }
            GridLayout {
                Layout.fillWidth: true; columns: 4; rowSpacing: 6; columnSpacing: 7
                Repeater {
                    model: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
                    delegate: Rectangle {
                        required property string modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 29
                        radius: 6
                        color: root.eqData.preset === modelData ? GlobalState.effectiveTheme.borderActive : GlobalState.effectiveTheme.bgAlt
                        border.color: root.eqData.preset === modelData ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                        Text { anchors.centerIn: parent; text: modelData; color: root.eqData.preset === modelData ? GlobalState.effectiveTheme.textLight : GlobalState.effectiveTheme.textMain; font.pixelSize: 9 }
                        MouseArea { id: presetHit; anchors.fill: parent; hoverEnabled: true; enabled: root.eqAvailable; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.selectPreset(modelData) }
                        ThemeToolTip {
                            targetItem: presetHit
                            visible: presetHit.containsMouse
                            text: "" + modelData + " · применить кривую, меняя только усиление 10 полос"
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "ПОЛОСЫ ЭКВАЛАЙЗЕРА"; color: GlobalState.effectiveTheme.rune; font.pixelSize: 9; font.letterSpacing: 0.8 }
                Text { text: root.eqAvailable ? "LIVE · ТОЛЬКО УРОВЕНЬ ПОЛОСЫ" : "EASYEFFECTS НЕ ПОДКЛЮЧЁН"; color: root.eqAvailable ? GlobalState.effectiveTheme.accentGlow : GlobalState.effectiveTheme.textDark; font.pixelSize: 8 }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
                Repeater {
                    model: [
                        {idx: 1, label: "31"}, {idx: 2, label: "63"}, {idx: 3, label: "125"}, {idx: 4, label: "250"}, {idx: 5, label: "500"},
                        {idx: 6, label: "1k"}, {idx: 7, label: "2k"}, {idx: 8, label: "4k"}, {idx: 9, label: "8k"}, {idx: 10, label: "16k"}
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
                        Text { Layout.alignment: Qt.AlignHCenter; text: root.formatGain(root.eqData["b" + modelData.idx]); color: GlobalState.effectiveTheme.textMain; font.pixelSize: 8 }
                        Slider {
                            id: bandSlider
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.minimumWidth: 32; Layout.preferredWidth: 38
                            orientation: Qt.Vertical; from: -12; to: 12; stepSize: 0.1
                            enabled: root.eqAvailable
                            hoverEnabled: true
                            value: Number(root.eqData["b" + modelData.idx] || 0)
                            property bool wasPressed: false
                            onPressedChanged: {
                                if (pressed) {
                                    wasPressed = true
                                } else if (wasPressed) {
                                    wasPressed = false
                                    root.setBand(modelData.idx, value)
                                }
                            }
                            Connections {
                                target: root
                                function onEqDataChanged() {
                                    if (!bandSlider.pressed) bandSlider.value = Number(root.eqData["b" + modelData.idx] || 0)
                                }
                            }
                            ThemeToolTip {
                                targetItem: bandSlider
                                visible: bandSlider.hovered
                                text: modelData.label + " Hz · " + root.formatGain(bandSlider.value) + " · меняется только усиление этой полосы"
                            }
                            background: Item {
                                x: (bandSlider.width - width) / 2; y: bandSlider.topPadding
                                width: 8; height: bandSlider.availableHeight
                                Rectangle {
                                    anchors.fill: parent; radius: 4
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: GlobalState.effectiveTheme.frame }
                                        GradientStop { position: 0.48; color: GlobalState.effectiveTheme.rune }
                                        GradientStop { position: 1; color: GlobalState.effectiveTheme.border }
                                    }
                                }
                                Rectangle {
                                    width: parent.width - 2; height: Math.max(2, parent.height * (1 - bandSlider.visualPosition))
                                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
                                    radius: 3; color: GlobalState.effectiveTheme.accentActive; opacity: 0.7
                                }
                            }
                            handle: Rectangle {
                                width: 28; height: 18; radius: 4
                                x: (bandSlider.width - width) / 2
                                y: bandSlider.topPadding + bandSlider.visualPosition * (bandSlider.availableHeight - height)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: GlobalState.effectiveTheme.frame }
                                    GradientStop { position: 0.5; color: GlobalState.effectiveTheme.bgAlt }
                                    GradientStop { position: 1; color: GlobalState.effectiveTheme.surfaceBottom }
                                }
                                border.color: GlobalState.effectiveTheme.rune
                                Rectangle { anchors.centerIn: parent; width: 14; height: 2; radius: 1; color: GlobalState.effectiveTheme.accentGlow }
                                Text { anchors.centerIn: parent; text: "ᚱ"; color: GlobalState.effectiveTheme.rune; font.pixelSize: 7 }
                            }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: GlobalState.effectiveTheme.rune; font.pixelSize: 8 }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: 158; Layout.preferredHeight: 30; radius: 6
                    color: easyEffectsHit.containsMouse ? GlobalState.effectiveTheme.borderActive : GlobalState.effectiveTheme.bgAlt
                    border.color: easyEffectsHit.containsMouse ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
                    Text { anchors.centerIn: parent; text: "EasyEffects · расширенно  ↗"; color: GlobalState.effectiveTheme.textMain; font.pixelSize: 8 }
                    MouseArea { id: easyEffectsHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openEasyEffects() }
                    ThemeToolTip { targetItem: easyEffectsHit; visible: easyEffectsHit.containsMouse; text: "Открыть EasyEffects для остальных аудионастроек. Эта панель изменяет только уровни полос эквалайзера." }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.eqAvailable ? "Изменяются только band0Gain–band9Gain текущего EQ." : "Запустите EasyEffects, затем вернитесь к полосам эквалайзера."
                    color: GlobalState.effectiveTheme.textDark; font.pixelSize: 8; elide: Text.ElideRight
                }
            }
        }
        Rectangle { anchors.fill: parent; anchors.margins: 5; radius: parent.radius - 3; color: "transparent"; border.color: GlobalState.effectiveTheme.rune; opacity: 0.2 }
    }
}
