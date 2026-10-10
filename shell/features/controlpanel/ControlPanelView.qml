import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../shared"
import "../../core/modules"

PanelWindow {
    id: root

    // Some bindings can be evaluated before singleton bindings settle during hot reload.
    // The panel therefore keeps a complete local fallback palette for every visual read.
    readonly property var safeTheme: GlobalState.effectiveTheme || ({
        bg: "#09090c", bgAlt: "#19171c", bgHover: "#32131a",
        surfaceTop: "#26191e", surfaceBottom: "#0c0a0e", frame: "#594149",
        rune: "#c5a47d", border: "#3b3037", borderActive: "#741b27",
        accent: "#8a1728", accentActive: "#ff334f", accentGlow: "#ff6579",
        textMain: "#d7cdd0", textLight: "#fff5f4", textDark: "#7d7179",
        font: "JetBrainsMono Nerd Font", radius: 11, elementRadius: 8
    })

    visible: GlobalState.isControlPanelOpen

    // Apply any on-disk config changes when the panel is opened.
    onVisibleChanged: { if (visible) GlobalState.reloadConfig() }

    anchors { top: true; right: true }
    margins { top: GlobalState.config.geometry.marginTop; right: GlobalState.config.geometry.marginRight }
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: GlobalState.config.geometry.width
    implicitHeight: GlobalState.config.geometry.height
    color: "transparent"

    // Shared state for the network, Bluetooth and audio selection views.
    property bool isMenuOpen: false
    property string menuTitle: ""
    property string currentMenuType: ""
    property string audioTab: "sink"

    Process { id: execProcess }
    function runCommand(argv) {
        if (!Array.isArray(argv) || argv.length === 0) {
            console.warn("[ControlPanel] runCommand expects a non-empty argv array")
            return
        }
        execProcess.running = false
        execProcess.command = argv
        execProcess.running = true
    }

    ListModel { id: contextModel }

    // Device-list commands stay in the host so modules do not need shell access.
    Process {
        id: fetchWifiProcess
        // Force a fresh scan; otherwise NetworkManager may return only the one
        // access point left in its cache when this menu was opened.
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        stdout: SplitParser {
            onRead: data => {
                let fields = [], value = "", escaped = false
                for (let i = 0; i < data.length; ++i) {
                    const ch = data[i]
                    if (escaped) { value += ch; escaped = false }
                    else if (ch === "\\") escaped = true
                    else if (ch === ":" && fields.length < 2) { fields.push(value); value = "" }
                    else value += ch
                }
                if (escaped) value += "\\"
                fields.push(value)
                const ssid = fields[0].trim()
                if (!ssid) return
                for (let i = 0; i < contextModel.count; ++i)
                    if (contextModel.get(i).itemType === "wifi" && contextModel.get(i).itemId === ssid) return
                contextModel.append({itemId: ssid, itemName: ssid, itemExtra: fields[1] + "%", itemType: "wifi", secured: fields[2].trim() !== ""})
            }
        }
    }
    Process { id: fetchBtProcess; command: ["sh", "-c", "bluetoothctl devices | head -n 8 | awk '{mac=$2; $1=\"\"; $2=\"\"; sub(/^[ \\t]+/, \"\"); print mac\"|\"$0}'"]; stdout: SplitParser { onRead: data => { let p = data.trim().split("|"); if(p.length >= 2) contextModel.append({itemId: p[0], itemName: p[1], itemExtra: "", itemType: "bt", secured: false}) } } }
    function cleanedAudioLabel(value) {
        const label = String(value || "").trim()
        if (!label || label === "(null)" || label.toLowerCase() === "unknown") return ""
        return label
    }

    function audioDisplayName(device) {
        const properties = device.properties || ({})
        const candidates = [
            properties["node.nick"],
            device.description,
            properties["device.description"],
            properties["alsa.card_name"],
            properties["device.product.name"],
            properties["alsa.name"]
        ]
        for (let i = 0; i < candidates.length; ++i) {
            const label = cleanedAudioLabel(candidates[i])
            if (label) return label
        }

        // Last-resort fallback for virtual or incomplete devices without labels.
        return String(device.name || "Аудиоустройство")
            .replace(/^(alsa_(input|output)|bluez_(input|output))\./, "")
            .replace(/\.(analog-stereo|analog-surround-[^.]+|mono-fallback|iec958-stereo|hdmi-stereo[^.]*)$/, "")
            .replace(/[._-]+/g, " ")
            .replace(/\s+/g, " ")
            .trim()
    }

    Process {
        id: fetchAudioProcess
        command: ["pactl", "-f", "json", "list", root.audioTab === "sink" ? "sinks" : "sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(this.text)
                    for (let i = 0; i < devices.length; ++i) {
                        const device = devices[i]
                        const name = String(device.name || "")
                        const properties = device.properties || ({})
                        const mediaClass = String(properties["media.class"] || "")
                        if (!name || name.endsWith(".monitor") || mediaClass === "Audio/Source/Virtual")
                            continue
                        contextModel.append({
                            itemId: name,
                            itemName: root.audioDisplayName(device),
                            itemExtra: "",
                            itemType: "audio",
                            secured: false
                        })
                    }
                } catch (error) {
                    console.warn("[ControlPanel] Could not parse pactl device list:", String(error))
                }
            }
        }
    }

    function openCustomMenu(type, title) {
        contextModel.clear(); root.menuTitle = title; root.currentMenuType = type; root.isMenuOpen = true; refreshMenuData()
    }
    function refreshMenuData() {
        contextModel.clear(); fetchWifiProcess.running = false; fetchBtProcess.running = false; fetchAudioProcess.running = false
        if (root.currentMenuType === "wifi") fetchWifiProcess.running = true
        else if (root.currentMenuType === "bt") fetchBtProcess.running = true
        else if (root.currentMenuType === "audio") fetchAudioProcess.running = true
    }

    property string pendingWifiSsid: ""
    function connectWifi(ssid, secured) {
        if (!secured) {
            execProcess.command = ["nmcli", "device", "wifi", "connect", ssid]
            execProcess.running = true
            return
        }
        pendingWifiSsid = ssid
        wifiPasswordField.text = ""
        wifiPasswordDialog.open()
    }
    Dialog {
        id: wifiPasswordDialog
        title: "Подключение к сети"
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 310)
        standardButtons: Dialog.Cancel
        background: Rectangle { color: root.safeTheme.bg; radius: 9; border.color: root.safeTheme.frame }
        contentItem: ColumnLayout {
            spacing: 9
            Text { text: root.pendingWifiSsid; color: root.safeTheme.textMain; font.family: root.safeTheme.font; elide: Text.ElideRight; Layout.fillWidth: true }
            TextField {
                id: wifiPasswordField
                Layout.fillWidth: true
                placeholderText: "Пароль сети"
                echoMode: TextInput.Password
                color: root.safeTheme.textMain
                onAccepted: wifiPasswordDialog.connectToNetwork()
            }
            Button { text: "Подключиться"; Layout.alignment: Qt.AlignRight; onClicked: wifiPasswordDialog.connectToNetwork() }
        }
        function connectToNetwork() {
            if (!wifiPasswordField.text) return
            root.execProcess.command = ["nmcli", "device", "wifi", "connect", root.pendingWifiSsid, "password", wifiPasswordField.text]
            root.execProcess.running = true
            close()
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.safeTheme.surfaceTop || "#211318" }
            GradientStop { position: 0.52; color: root.safeTheme.bg || "#0a0a0a" }
            GradientStop { position: 1.0; color: root.safeTheme.surfaceBottom || "#100b0e" }
        }
        border.color: root.safeTheme.frame || root.safeTheme.borderActive
        border.width: 1
        radius: (GlobalState.effectiveTheme && root.safeTheme.radius !== undefined) ? root.safeTheme.radius : 11
        clip: true

        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: GlobalState.animationDuration(250); easing.type: Easing.OutCubic } }

        // --- ГЛАВНЫЙ ЭКРАН ---
        Item {
            id: mainView
            width: parent.width; height: parent.height
            x: root.isMenuOpen ? -width : 0
            opacity: root.isMenuOpen ? 0.0 : 1.0
            visible: opacity > 0
            Behavior on x { NumberAnimation { duration: GlobalState.animationDuration(300); easing.type: Easing.InOutQuart } }

            Item {
                anchors.fill: parent; anchors.margins: 16

                ColumnLayout {
                    anchors.fill: parent; spacing: 12

                    // Dark-fantasy header: an engraved sigil, title and compact close control.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 8
                            color: root.safeTheme.surfaceBottom || root.safeTheme.bg
                            border.color: root.safeTheme.frame || root.safeTheme.border
                            Text {
                                anchors.centerIn: parent
                                text: "ᛉ"
                                color: root.safeTheme.rune || root.safeTheme.accentActive
                                font.family: root.safeTheme.font
                                font.pixelSize: 21
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Управление"
                                color: root.safeTheme.textLight
                                font.family: root.safeTheme.font
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Text {
                                text: "DARK FANTASY  /  SYSTEM RITES"
                                color: root.safeTheme.rune || root.safeTheme.textDark
                                font.family: root.safeTheme.font
                                font.pixelSize: 8
                                font.letterSpacing: 1.1
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 6
                            color: root.safeTheme.bgAlt
                            border.color: root.safeTheme.frame || root.safeTheme.border
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.safeTheme.textMain
                                font.family: root.safeTheme.font
                                font.pixelSize: 18
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalState.isControlPanelOpen = false
                            }
                        }
                    }

                    // --- СЕТКА ДЛЯ РЕНДЕРА МОДУЛЕЙ ---
                    // GridLayout позволяет выводить некоторые модули в ряд (как Wi-Fi и BT)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: GlobalState.config.layout
                            delegate: Loader {
                                // Если модуль называется Wifi или Bluetooth, они занимают половину ширины (1 колонку), иначе всю ширину (2 колонки)
                                Layout.columnSpan: (modelData === "Wifi" || modelData === "Bluetooth" ||
                                    (GlobalState.config.plugins[modelData] && GlobalState.config.plugins[modelData].columnSpan === 1)) ? 1 : 2
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                // Explicit heights keep Loader/GridLayout from collapsing
                                // custom Items whose root Item has no implicit size.
                                Layout.preferredHeight: (modelData === "Volume" || modelData === "Mic") ? 108 :
                                                       (modelData === "Appearance" ? 90 : 52)
                                Layout.minimumHeight: Layout.preferredHeight
                                
                                property string moduleId: modelData
                                source: ModuleRegistry.sourceFor(moduleId, "controlPanel")

                                onStatusChanged: {
                                    if (status === Loader.Error)
                                        console.warn("[ControlPanel] Failed to load module:", moduleId, source)
                                }
                                onLoaded: {
                                    if (ModuleRegistry.isPlugin(moduleId, "controlPanel")) {
                                        item.moduleId = moduleId
                                        item.settings = Qt.binding(() => ModuleRegistry.settingsFor(moduleId))
                                        item.theme = Qt.binding(() => GlobalState.effectiveTheme)
                                        item.panel = root
                                    } else {
                                        item.panel = root
                                        item.theme = Qt.binding(() => GlobalState.effectiveTheme)
                                        item.modConf = Qt.binding(() => GlobalState.config.modules[moduleId] || {})
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true } // Пружина
                }
            }
        }

        // --- ВТОРОЙ ЭКРАН: Wi-Fi networks, Bluetooth devices, audio devices ---
        Item {
            id: customMenuView
            anchors.fill: parent
            x: root.isMenuOpen ? 0 : width
            opacity: root.isMenuOpen ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on x { NumberAnimation { duration: GlobalState.animationDuration(300); easing.type: Easing.InOutQuart } }
            Behavior on opacity { NumberAnimation { duration: GlobalState.animationDuration(180) } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 28; height: 28; radius: 5
                        color: root.safeTheme.bgAlt
                        Text { anchors.centerIn: parent; text: "‹"; color: root.safeTheme.textLight; font.pixelSize: 22 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isMenuOpen = false }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.menuTitle
                        color: root.safeTheme.textLight
                        font.family: root.safeTheme.font
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: root.currentMenuType === "wifi"
                        text: "" + contextModel.count
                        color: root.safeTheme.rune || root.safeTheme.textDark
                        font.family: root.safeTheme.font
                        font.pixelSize: 10
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 5
                        color: root.safeTheme.bgAlt
                        Text { anchors.centerIn: parent; text: "↻"; color: root.safeTheme.textMain; font.pixelSize: 16 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshMenuData() }
                    }
                }

                Text {
                    visible: contextModel.count === 0
                    text: "Нет доступных устройств или список пуст"
                    color: root.safeTheme.textDark
                    font.family: root.safeTheme.font
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ListView {
                    id: menuList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 7
                    model: contextModel
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: if (count > 0) positionViewAtBeginning()
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: GlobalState.animationDuration(160); easing.type: Easing.OutCubic }
                        // ListView owns delegate y positions; animating every new
                        // row to y=0 made the entire network list overlap in one row.
                        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: GlobalState.animationDuration(160); easing.type: Easing.OutCubic }
                    }
                    delegate: Rectangle {
                        required property string itemId
                        required property string itemName
                        required property string itemExtra
                        required property string itemType
                        required property bool secured
                        width: menuList.width
                        height: 50
                        radius: 7
                        color: menuMouse.containsMouse ? root.safeTheme.bgHover : root.safeTheme.bgAlt
                        border.width: 1
                        border.color: menuMouse.containsMouse ? root.safeTheme.accent : root.safeTheme.frame
                        scale: menuMouse.containsMouse ? 1.01 : 1.0
                        Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(120) } }
                        Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(120) } }
                        Behavior on scale { NumberAnimation { duration: GlobalState.animationDuration(120); easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 5
                            color: "transparent"
                            border.width: GlobalState.ornamentsEnabled ? 1 : 0
                            border.color: root.safeTheme.rune
                            opacity: menuMouse.containsMouse ? 0.28 : 0.12
                        }
                        Rectangle {
                            id: deviceGlyphPlate
                            x: 8; width: 29; height: 29
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            color: root.safeTheme.surfaceBottom
                            border.width: 1
                            border.color: root.safeTheme.frame
                            Text {
                                anchors.centerIn: parent
                                text: itemType === "wifi" ? "ᛞ" : (itemType === "bt" ? "ᛒ" : "ᚱ")
                                color: menuMouse.containsMouse ? root.safeTheme.accentGlow : root.safeTheme.rune
                                font.family: root.safeTheme.font
                                font.pixelSize: 13
                            }
                        }

                        Column {
                            anchors.left: deviceGlyphPlate.right
                            anchors.leftMargin: 9
                            anchors.right: extraLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: itemName || itemId
                                color: root.safeTheme.textMain
                                font.family: root.safeTheme.font
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: itemType === "wifi" ? (secured ? "Защищённая сеть · Wi-Fi" : "Открытая сеть · Wi-Fi") : (itemType === "bt" ? itemId : (itemType === "audio" ? (root.audioTab === "sink" ? "Устройство вывода" : "Устройство ввода") : ""))
                                color: root.safeTheme.textDark
                                font.family: root.safeTheme.font
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            id: extraLabel
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: itemExtra
                            color: root.safeTheme.accentActive
                            font.family: root.safeTheme.font
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (itemType === "wifi") {
                                    root.connectWifi(itemId, secured)
                                    return
                                } else if (itemType === "bt") {
                                    execProcess.command = ["bluetoothctl", "connect", itemId]
                                } else if (itemType === "audio") {
                                    execProcess.command = root.audioTab === "sink"
                                        ? ["pactl", "set-default-sink", itemId]
                                        : ["pactl", "set-default-source", itemId]
                                } else {
                                    return
                                }
                                execProcess.running = false
                                execProcess.running = true
                            }
                        }
                    }
                }
            }
        }

        // Etched inner frame and animated blood accents. These decorations do not accept input.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            z: 30
            color: "transparent"
            radius: Math.max(2, (root.safeTheme.radius || 8) - 3)
            border.width: 1
            border.color: root.safeTheme.rune || root.safeTheme.accent
            opacity: GlobalState.config.appearance.glow ? 0.24 : 0.10
        }
        Rectangle {
            id: panelSigilLine
            x: 16
            y: 0
            width: 48
            height: 2
            z: 31
            radius: 1
            color: GlobalState.config.appearance.glow ? (root.safeTheme.accentGlow || root.safeTheme.accentActive) : (root.safeTheme.rune || root.safeTheme.accent)
            opacity: 0.62
            SequentialAnimation on opacity {
                running: GlobalState.idleEffectsEnabled && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: GlobalState.animationDuration(1300); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: GlobalState.animationDuration(1300); easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            x: 16
            y: parent.height - 2
            width: 19
            height: 1
            z: 31
            color: root.safeTheme.rune || root.safeTheme.accent
            opacity: 0.65
        }
        Rectangle {
            x: parent.width - 35
            y: parent.height - 2
            width: 19
            height: 1
            z: 31
            color: root.safeTheme.rune || root.safeTheme.accent
            opacity: 0.65
        }
    }
}
