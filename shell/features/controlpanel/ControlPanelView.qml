import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Networking
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
    onVisibleChanged: {
        if (visible) {
            GlobalState.reloadConfig()
            consumeNetworkMenuRequest()
        } else {
            // Reopen the panel on its root view instead of restoring a stale
            // Wi-Fi, Bluetooth or audio submenu from the previous session.
            isMenuOpen = false
            menuTitle = ""
            currentMenuType = ""
            audioTab = "sink"
            contextModel.clear()
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
            fetchBtProcess.running = false
            fetchAudioProcess.running = false
            if (wifiPasswordDialog.visible) wifiPasswordDialog.close()
            GlobalState.isNetworkPortalOpen = false
            GlobalState.requestNetworkMenu = false
        }
    }

    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Normal
    margins { top: GlobalState.popupTopMargin; right: GlobalState.config.geometry.marginRight }
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: GlobalState.config.geometry.width
    implicitHeight: GlobalState.config.geometry.height
    color: "transparent"

    // Shared state for the network, Bluetooth and audio selection views.
    property bool isMenuOpen: false
    property string menuTitle: ""
    property string currentMenuType: ""
    property string audioTab: "sink"
    property string deviceName: ""
    onIsMenuOpenChanged: {
        if (!isMenuOpen) {
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
        }
    }

    Process { id: execProcess }
    Process {
        id: deviceNameProcess
        command: ["hostname"]
        stdout: StdioCollector { onStreamFinished: root.deviceName = text.trim() }
        Component.onCompleted: running = true
    }
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

    // Scanning is enabled only while the Wi-Fi menu is open. Preserve each
    // device's previous setting and restore it when leaving the menu.
    property var wifiScannerDevices: []
    property var wifiScannerStates: []
    property var selectedWifiNetwork: null
    property string wifiConnectionMessage: ""
    function wifiDevices() {
        const result = []
        const devices = Networking.devices.values
        for (let i = 0; i < devices.length; ++i)
            if (devices[i].type === DeviceType.Wifi) result.push(devices[i])
        return result
    }
    function enableWifiScanning() {
        const devices = wifiDevices()
        for (let i = 0; i < devices.length; ++i) {
            const device = devices[i]
            if (wifiScannerDevices.indexOf(device) < 0) {
                wifiScannerDevices.push(device)
                wifiScannerStates.push(device.scannerEnabled)
            }
            device.scannerEnabled = true
        }
    }
    function restoreWifiScanning() {
        for (let i = 0; i < wifiScannerDevices.length; ++i)
            wifiScannerDevices[i].scannerEnabled = wifiScannerStates[i]
        wifiScannerDevices = []
        wifiScannerStates = []
    }
    function refreshWifiNetworks() {
        if (!root.visible || !root.isMenuOpen || root.currentMenuType !== "wifi") return
        root.enableWifiScanning()
        const found = []
        const devices = root.wifiDevices()
        for (let i = 0; i < devices.length; ++i) {
            const networks = devices[i].networks.values
            for (let j = 0; j < networks.length && found.length < 64; ++j) {
                const network = networks[j]
                const ssid = String(network.name || "").trim()
                if (!ssid || ssid.length > 256) continue
                let duplicate = false
                for (let k = 0; k < found.length; ++k)
                    if (found[k].itemId === ssid) { duplicate = true; break }
                if (duplicate) continue
                found.push({
                    itemId: ssid,
                    itemName: ssid,
                    itemExtra: Math.round(Math.max(0, Math.min(1, Number(network.signalStrength) || 0)) * 100) + "%",
                    itemType: "wifi",
                    secured: network.security !== WifiSecurityType.Open
                })
            }
        }
        let changed = found.length !== contextModel.count
        if (!changed) {
            for (let i = 0; i < found.length; ++i) {
                const current = contextModel.get(i)
                if (current.itemId !== found[i].itemId || current.itemExtra !== found[i].itemExtra || current.secured !== found[i].secured) {
                    changed = true
                    break
                }
            }
        }
        if (changed) {
            contextModel.clear()
            for (let i = 0; i < found.length; ++i) contextModel.append(found[i])
        }
    }
    Timer {
        id: wifiScanRefreshTimer
        interval: 1500
        repeat: true
        onTriggered: root.refreshWifiNetworks()
    }
    Process {
        id: fetchBtProcess
        command: ["bluetoothctl", "devices"]
        stdout: SplitParser {
            onRead: data => {
                if (contextModel.count >= 8 || data.length > 512)
                    return
                const match = data.trim().match(/^Device\s+([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})\s+(.+)$/)
                if (match)
                    contextModel.append({itemId: match[1], itemName: match[2], itemExtra: "", itemType: "bt", secured: false})
            }
        }
    }
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
        if (root.currentMenuType === "wifi" && type !== "wifi") {
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
        }
        contextModel.clear(); root.menuTitle = title; root.currentMenuType = type; root.isMenuOpen = true; refreshMenuData()
    }
    function consumeNetworkMenuRequest() {
        if (!root.visible || !GlobalState.requestNetworkMenu) return
        openCustomMenu("wifi", "СЕТИ · АЛХИМИЧЕСКИЙ КРУГ")
        GlobalState.requestNetworkMenu = false
    }
    function refreshMenuData() {
        contextModel.clear(); fetchBtProcess.running = false; fetchAudioProcess.running = false
        if (root.currentMenuType === "wifi") {
            root.refreshWifiNetworks()
            wifiScanRefreshTimer.start()
        } else if (root.currentMenuType === "bt") {
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
            fetchBtProcess.running = true
        } else if (root.currentMenuType === "audio") {
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
            fetchAudioProcess.running = true
        } else {
            wifiScanRefreshTimer.stop()
            root.restoreWifiScanning()
        }
    }

    Connections {
        target: GlobalState
        function onRequestNetworkMenuChanged() { root.consumeNetworkMenuRequest() }
    }

    property string pendingWifiSsid: ""
    function connectWifi(ssid, secured) {
        const devices = root.wifiDevices()
        let network = null
        for (let i = 0; i < devices.length && network === null; ++i) {
            const networks = devices[i].networks.values
            for (let j = 0; j < networks.length; ++j) {
                if (String(networks[j].name || "") === ssid) {
                    network = networks[j]
                    break
                }
            }
        }
        if (!network) {
            root.wifiConnectionMessage = "Сеть больше не доступна. Обновляю список…"
            root.refreshWifiNetworks()
            return
        }
        root.selectedWifiNetwork = network
        root.wifiConnectionMessage = ""
        if (network.stateChanging) return
        // Let NetworkManager use a saved secret first. If no key is available,
        // the failure signal opens our themed PSK prompt for supported Wi-Fi.
        network.connect()
    }
    Dialog {
        id: wifiPasswordDialog
        title: "Подключение к сети"
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 310)
        standardButtons: Dialog.Cancel
        onRejected: { wifiPasswordField.clear(); root.pendingWifiSsid = "" }
        background: Rectangle { color: root.safeTheme.bg; radius: 9; border.color: root.safeTheme.frame }
        contentItem: ColumnLayout {
            spacing: 9
            Text { text: root.pendingWifiSsid; textFormat: Text.PlainText; color: root.safeTheme.textMain; font.family: root.safeTheme.font; elide: Text.ElideRight; Layout.fillWidth: true }
            TextField {
                id: wifiPasswordField
                Layout.fillWidth: true
                placeholderText: "Пароль сети"
                echoMode: TextInput.Password
                color: root.safeTheme.textMain
                onAccepted: wifiPasswordDialog.connectToNetwork()
            }
            Button {
                id: connectButton
                text: "Подключиться"; Layout.alignment: Qt.AlignRight
                hoverEnabled: true
                onClicked: wifiPasswordDialog.connectToNetwork()
                ThemeToolTip { targetItem: connectButton; visible: connectButton.hovered; text: "Подключиться к выбранной Wi-Fi сети" }
            }
        }
        function connectToNetwork() {
            if (!wifiPasswordField.text) return
            const password = wifiPasswordField.text
            const network = root.selectedWifiNetwork
            wifiPasswordField.clear()
            root.pendingWifiSsid = ""
            close()
            if (network) network.connectWithPsk(password)
        }
    }
    Connections {
        target: root.selectedWifiNetwork
        function onConnectedChanged() {
            if (root.selectedWifiNetwork && root.selectedWifiNetwork.connected)
                root.wifiConnectionMessage = ""
        }
        function onConnectionFailed(reason) {
            const network = root.selectedWifiNetwork
            const usesPsk = network && (
                network.security === WifiSecurityType.WpaPsk ||
                network.security === WifiSecurityType.Wpa2Psk ||
                network.security === WifiSecurityType.Sae)
            if (reason === ConnectionFailReason.NoSecrets && usesPsk) {
                root.pendingWifiSsid = network.name
                wifiPasswordField.clear()
                wifiPasswordDialog.open()
                return
            }
            root.wifiConnectionMessage = "Не удалось подключиться к выбранной сети (" + String(reason) + ")"
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
                                id: panelCloseHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalState.closeControlPanel()
                            }
                            ThemeToolTip { targetItem: panelCloseHit; visible: panelCloseHit.containsMouse; text: "Закрыть системную панель" }
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
                                Layout.preferredHeight: (modelData === "Wifi" || modelData === "Bluetooth") ? 98 :
                                                       ((modelData === "Volume" || modelData === "Mic") ? 108 :
                                                       (modelData === "Appearance" ? 90 : 52))
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
                        MouseArea { id: menuBackHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.isMenuOpen = false; GlobalState.isNetworkPortalOpen = false } }
                        ThemeToolTip { targetItem: menuBackHit; visible: menuBackHit.containsMouse; text: "Вернуться к системным модулям" }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.menuTitle
                        textFormat: Text.PlainText
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
                        MouseArea { id: menuRefreshHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshMenuData() }
                        ThemeToolTip { targetItem: menuRefreshHit; visible: menuRefreshHit.containsMouse; text: "Обновить список устройств поблизости" }
                    }
                }

                Item {
                    visible: root.currentMenuType === "wifi" || root.currentMenuType === "bt"
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 292 : 0
                    HoverHandler { id: orbitHover }
                    Item {
                        id: networkOrbit
                        width: Math.min(parent.width, 286)
                        height: width
                        anchors.centerIn: parent
                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: GlobalState.animationDuration(30000)
                            loops: Animation.Infinite
                            running: GlobalState.idleEffectsEnabled && root.visible && !orbitHover.hovered
                        }
                        Rectangle {
                            id: runeRing
                            width: parent.width - 10; height: width; radius: width / 2
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 1
                            border.color: root.safeTheme.rune
                            opacity: 0.82
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 13; radius: width / 2
                                color: "transparent"; border.color: root.safeTheme.frame; opacity: 0.8
                            }
                            Repeater {
                                model: ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ", "ᚺ", "ᛉ", "ᛟ", "ᛞ"]
                                delegate: Text {
                                    required property int index
                                    required property string modelData
                                    x: runeRing.width / 2 - width / 2 + Math.cos(index * Math.PI / 6) * (runeRing.width / 2 - 11)
                                    y: runeRing.height / 2 - height / 2 + Math.sin(index * Math.PI / 6) * (runeRing.height / 2 - 11)
                                    text: modelData
                                    color: root.safeTheme.rune
                                    font.pixelSize: 12
                                    opacity: 0.96
                                }
                            }
                        }
                        Repeater {
                            model: contextModel
                            delegate: Rectangle {
                                required property int index
                                required property string itemId
                                required property string itemName
                                required property string itemExtra
                                required property string itemType
                                required property bool secured
                                property real angle: (index * 360 / Math.max(1, contextModel.count) - 90) * Math.PI / 180
                                visible: itemType === root.currentMenuType
                                width: 88; height: 31; radius: 7
                                x: networkOrbit.width / 2 - width / 2 + Math.cos(angle) * 91
                                y: networkOrbit.height / 2 - height / 2 + Math.sin(angle) * 91
                                rotation: -networkOrbit.rotation
                                color: networkHit.containsMouse ? root.safeTheme.bgHover : root.safeTheme.bg
                                border.width: 1
                                border.color: networkHit.containsMouse ? root.safeTheme.accentActive : root.safeTheme.frame
                                Behavior on color { ColorAnimation { duration: GlobalState.animationDuration(130) } }
                                Behavior on border.color { ColorAnimation { duration: GlobalState.animationDuration(130) } }
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    text: (itemType === "wifi" ? "ᛞ  " : "ᛒ  ") + (itemName || itemId)
                                    textFormat: Text.PlainText
                                    color: networkHit.containsMouse ? root.safeTheme.textLight : root.safeTheme.textMain
                                    font.family: root.safeTheme.font
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                MouseArea {
                                    id: networkHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (itemType === "wifi") root.connectWifi(itemId, secured)
                                        else if (itemType === "bt") {
                                            root.execProcess.command = ["bluetoothctl", "connect", itemId]
                                            root.execProcess.running = true
                                        }
                                    }
                                }
                                ThemeToolTip {
                                    targetItem: networkHit
                                    visible: networkHit.containsMouse
                                    text: (itemName || itemId) + "\n" + (itemType === "wifi" ? (secured ? "Защищённая Wi-Fi сеть · подключиться" : "Открытая Wi-Fi сеть · подключиться") : (itemType === "bt" ? "Bluetooth · подключить устройство" : "Аудиоустройство · выбрать вывод или ввод"))
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 84; height: 84; radius: 42
                        anchors.centerIn: parent
                        color: root.safeTheme.surfaceBottom
                        border.width: 2; border.color: root.safeTheme.rune
                        Rectangle { anchors.fill: parent; anchors.margins: 5; radius: width / 2; color: "transparent"; border.color: root.safeTheme.accentActive; opacity: 0.58 }
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.currentMenuType === "bt" ? "ᛒ" : "⌂"; color: root.safeTheme.accentGlow; font.pixelSize: 22 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; width: 70; text: root.deviceName || "DFS"; textFormat: Text.PlainText; color: root.safeTheme.rune; font.pixelSize: 8; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter }
                        }
                        SequentialAnimation on scale {
                            running: GlobalState.idleEffectsEnabled && root.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.06; duration: GlobalState.animationDuration(1100); easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: GlobalState.animationDuration(1100); easing.type: Easing.InOutSine }
                        }
                    }
                }

                Text {
                    visible: contextModel.count === 0 || root.wifiConnectionMessage !== ""
                    text: root.wifiConnectionMessage || "Нет доступных устройств или список пуст"
                    color: root.safeTheme.textDark
                    font.family: root.safeTheme.font
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ListView {
                    id: menuList
                    visible: root.currentMenuType !== "wifi"
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
                                textFormat: Text.PlainText
                                color: root.safeTheme.textMain
                                font.family: root.safeTheme.font
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: itemType === "wifi" ? (secured ? "Защищённая сеть · Wi-Fi" : "Открытая сеть · Wi-Fi") : (itemType === "bt" ? itemId : (itemType === "audio" ? (root.audioTab === "sink" ? "Устройство вывода" : "Устройство ввода") : ""))
                                textFormat: Text.PlainText
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
                            textFormat: Text.PlainText
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
                        ThemeToolTip {
                            targetItem: menuMouse
                            visible: menuMouse.containsMouse
                            text: (itemName || itemId) + "\n" + (itemType === "audio" ? "Выбрать аудиоустройство" : "Подключить устройство")
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
