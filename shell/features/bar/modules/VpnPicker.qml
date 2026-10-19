import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import "../../shared"
import "../../../core/services"

PopupWindow {
    id: root

    property Item anchorItem: null
    property bool requestedOpen: false
    property string page: "list"
    property string editingProfileId: ""
    property var selectedProfile: null
    readonly property var theme: GlobalState.effectiveTheme

    visible: requestedOpen
    grabFocus: true
    color: "transparent"
    implicitWidth: 390
    implicitHeight: 510
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    component ActionButton: Rectangle {
        id: actionRoot
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: Math.max(58, actionLabel.implicitWidth + 18)
        implicitHeight: 28
        radius: 5
        color: actionHit.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
        border.width: active ? 1.5 : 1
        border.color: active ? GlobalState.effectiveTheme.rune : GlobalState.effectiveTheme.frame
        gradient: Gradient {
            GradientStop { position: 0; color: actionRoot.active ? (actionHit.containsMouse ? GlobalState.effectiveTheme.accentGlow : GlobalState.effectiveTheme.accent) : GlobalState.effectiveTheme.bgHover }
            GradientStop { position: 1; color: actionRoot.active ? GlobalState.effectiveTheme.surfaceBottom : GlobalState.effectiveTheme.bgAlt }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: GlobalState.effectiveTheme.rune
            opacity: actionRoot.active ? 0.48 : 0.24
        }
        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: actionRoot.label
            color: actionRoot.active ? GlobalState.effectiveTheme.textLight : GlobalState.effectiveTheme.textMain
            font.family: GlobalState.effectiveTheme.font
            font.pixelSize: 9
        }
        MouseArea {
            id: actionHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.clicked()
        }
    }

    component FormField: TextField {
        color: GlobalState.effectiveTheme.textMain
        selectedTextColor: GlobalState.effectiveTheme.textLight
        selectionColor: GlobalState.effectiveTheme.accent
        placeholderTextColor: GlobalState.effectiveTheme.textDark
        font.family: GlobalState.effectiveTheme.font
        font.pixelSize: 9
        selectByMouse: true
        background: Rectangle {
            radius: 5
            color: GlobalState.effectiveTheme.bgAlt
            border.width: 1
            border.color: parent.activeFocus ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.frame
        }
    }

    function showFor(targetItem) {
        if (visible && anchorItem === targetItem) {
            requestedOpen = false
            return
        }
        const wasVisible = visible
        requestedOpen = false
        anchorItem = targetItem
        if (wasVisible)
            Qt.callLater(function() { root.requestedOpen = true })
        else
            requestedOpen = true
    }

    function openEditor(profile) {
        const current = profile || ({})
        editingProfileId = current.id || ""
        profileNameField.text = current.name || ""
        profileUsernameField.text = current.username || ""
        profileConfigPathField.text = current.configPath || ""
        profileConnectionNameField.text = current.connectionName || ""
        profileHostField.text = current.host || ""
        profilePortField.text = current.port || "443"
        profileClientCommandField.text = current.clientCommand || "openfortivpn"
        profileConnectCommandField.text = current.connectCommand || ""
        profileDisconnectCommandField.text = current.disconnectCommand || ""
        backendCombo.currentIndex = current.backend === "networkmanager" ? 1 : (current.backend === "openfortivpn" ? 2 : 0)
        twoFactorCombo.currentIndex = current.twoFactor === "before" ? 1 : (current.twoFactor === "challenge" ? 2 : 0)
        page = "edit"
    }

    function finishEditor() {
        const name = profileNameField.text.trim()
        const backendIndex = backendCombo.currentIndex
        const backend = backendIndex === 1 ? "networkmanager" : (backendIndex === 2 ? "openfortivpn" : "command")
        if (!name) {
            VpnService.lastError = "Введите название профиля."
            return
        }
        if (backend === "networkmanager" && !profileConnectionNameField.text.trim()) {
            VpnService.lastError = "Укажите имя профиля NetworkManager или импортируйте .ovpn."
            return
        }
        if (backend === "openfortivpn" && !profileHostField.text.trim()) {
            VpnService.lastError = "Укажите адрес VPN-сервера."
            return
        }
        if (backend === "command" && !profileConnectCommandField.text.trim()) {
            VpnService.lastError = "Введите команду подключения."
            return
        }
        const profile = {
            id: editingProfileId || ("vpn-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 7)),
            name: name,
            backend: backend,
            username: profileUsernameField.text.trim(),
            configPath: profileConfigPathField.text.trim(),
            connectionName: profileConnectionNameField.text.trim(),
            host: profileHostField.text.trim(),
            port: Number(profilePortField.text) || 443,
            clientCommand: profileClientCommandField.text.trim() || "openfortivpn",
            connectCommand: profileConnectCommandField.text.trim(),
            disconnectCommand: profileDisconnectCommandField.text.trim(),
            twoFactor: backend === "networkmanager" ? "none" : (twoFactorCombo.currentIndex === 1 ? "before" : (twoFactorCombo.currentIndex === 2 ? "challenge" : "none"))
        }
        if (VpnService.upsertProfile(profile)) {
            VpnService.lastError = ""
            page = "list"
        }
    }

    function beginLogin(profile) {
        selectedProfile = profile
        VpnService.lastError = ""
        if (VpnService.lastFailedProfileId === profile.id) {
            VpnService.lastFailedProfileId = ""
            VpnService.connectionStatus = "disconnected"
        }
        if (profile.backend === "networkmanager") {
            VpnService.connect(profile, "", "", "")
            return
        }
        loginUsernameField.text = profile.username || ""
        loginPasswordField.clear()
        loginOtpField.clear()
        rememberPasswordCheck.checked = false
        page = "login"
        VpnService.loadPassword(profile.id)
    }

    function submitLogin() {
        const profile = selectedProfile
        if (!profile)
            return
        const username = loginUsernameField.text.trim()
        const password = loginPasswordField.text
        const needsOtpBefore = profile.twoFactor === "before" || profile.backend === "openfortivpn" && profile.twoFactor === "challenge"
        const otp = needsOtpBefore ? loginOtpField.text.trim() : ""
        if (profile.backend === "openfortivpn" && !username) {
            VpnService.lastError = "Введите имя пользователя."
            return
        }
        if (profile.backend === "openfortivpn" && !password) {
            VpnService.lastError = "Введите пароль или загрузите его из связки ключей."
            return
        }
        if (needsOtpBefore && !otp) {
            VpnService.lastError = "Введите код двухфакторной проверки."
            return
        }
        const updatedProfile = Object.assign({}, profile, { username: username })
        VpnService.upsertProfile(updatedProfile)
        selectedProfile = updatedProfile
        if (rememberPasswordCheck.checked)
            VpnService.savePassword(updatedProfile.id, updatedProfile.name, password)
        VpnService.connect(updatedProfile, username, password, otp)
        loginPasswordField.clear()
        loginOtpField.clear()
        page = "list"
    }

    function profileStatus(profile) {
        if (VpnService.activeProfileId === profile.id) {
            if (VpnService.connectionStatus === "connecting") return "Подключение…"
            if (VpnService.connectionStatus === "awaitingOtp") return "Ожидается код 2FA"
            if (VpnService.connectionStatus === "disconnecting") return "Отключение…"
            return "Подключено"
        }
        if (VpnService.lastFailedProfileId === profile.id)
            return "Ошибка подключения"
        return profile.backend === "networkmanager" ? "NetworkManager" : (profile.backend === "openfortivpn" ? "OpenFortiVPN" : "Внешний клиент")
    }

    function profileStatusColor(profile) {
        if (VpnService.lastFailedProfileId === profile.id)
            return root.theme.accentGlow
        if (VpnService.activeProfileId === profile.id)
            return root.theme.accentGlow
        return root.theme.textDark
    }

    function connectionSummary() {
        if (VpnService.lastError)
            return VpnService.lastError
        if (VpnService.connectionStatus === "connecting")
            return "Подключаемся к " + VpnService.activeProfileName + "…"
        if (VpnService.connectionStatus === "awaitingOtp")
            return "Клиент ожидает код двухфакторной проверки."
        if (VpnService.connectionStatus === "connected")
            return "Подключено: " + VpnService.activeProfileName
        if (VpnService.connectionStatus === "disconnecting")
            return "Отключаем " + VpnService.activeProfileName + "…"
        return ""
    }

    onVisibleChanged: {
        if (!visible) {
            page = "list"
            loginPasswordField.clear()
            loginOtpField.clear()
        }
    }

    Connections {
        target: VpnService
        function onPasswordRetrieved(profileId, password) {
            if (root.page === "login" && root.selectedProfile && root.selectedProfile.id === profileId && loginPasswordField.text === "")
                loginPasswordField.text = password
        }
        function onProfileImported(connectionName, configPath) {
            if (root.page === "edit") {
                backendCombo.currentIndex = 1
                profileConnectionNameField.text = connectionName
                profileConfigPathField.text = configPath
                if (!profileNameField.text.trim())
                    profileNameField.text = connectionName
            }
        }
        function onAwaitingOtpChanged() {
            if (VpnService.awaitingOtp && root.selectedProfile && root.selectedProfile.id === VpnService.awaitingOtpProfileId) {
                root.page = "otp"
                loginOtpField.clear()
            }
        }
    }

    FileDialog {
        id: openVpnFileDialog
        title: "Импорт конфигурации OpenVPN"
        nameFilters: ["OpenVPN (*.ovpn)", "Все файлы (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: VpnService.importOpenVpnConfig(selectedFile.toLocalFile())
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(7, Number(root.theme.radius) || 10)
        color: root.theme.bg
        border.width: 1
        border.color: root.theme.frame
        antialiasing: true

        gradient: Gradient {
            GradientStop { position: 0; color: root.theme.surfaceTop }
            GradientStop { position: 1; color: root.theme.surfaceBottom }
        }

        Rectangle {
            x: 15
            y: 0
            width: 42
            height: 2
            radius: 1
            color: root.theme.accentGlow
            opacity: GlobalState.config.appearance.glow ? 0.88 : 0.4
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: root.theme.rune
            opacity: 0.5
        }

        Rectangle {
            x: 12
            y: 12
            width: parent.width - 24
            height: 36
            radius: 4
            border.width: 1
            border.color: root.theme.rune
            gradient: Gradient {
                GradientStop { position: 0; color: root.theme.accent }
                GradientStop { position: 0.52; color: root.theme.surfaceTop }
                GradientStop { position: 1; color: root.theme.surfaceBottom }
            }
        }

        Repeater {
            model: [0, 1, 2, 3]
            delegate: Rectangle {
                required property int modelData
                x: modelData % 2 === 0 ? 7 : parent.width - width - 7
                y: modelData < 2 ? 7 : parent.height - height - 7
                width: 7
                height: 7
                rotation: 45
                color: root.theme.accent
                border.width: 1
                border.color: root.theme.rune
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.page === "edit" ? "НАСТРОЙКА ПРОФИЛЯ VPN" : (root.page === "login" ? "ВХОД В VPN" : (root.page === "otp" ? "ПОДТВЕРЖДЕНИЕ 2FA" : "VPN · ПРОФИЛИ"))
                        color: root.theme.rune
                        font.family: root.theme.font
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.page === "list" ? (VpnService.profiles.length + " сохранённых профилей") : (root.selectedProfile ? root.selectedProfile.name : "Добавьте способ подключения")
                        color: root.theme.textDark
                        font.family: root.theme.font
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }

                ActionButton {
                    visible: root.page === "list"
                    label: "+ Добавить"
                    active: true
                    onClicked: root.openEditor(null)
                }
                ActionButton {
                    visible: root.page !== "list"
                    label: "‹ Назад"
                    onClicked: {
                        VpnService.lastError = ""
                        if (root.page === "edit" || root.page === "login" || root.page === "otp")
                            root.page = "list"
                    }
                }
                ActionButton {
                    label: "×"
                    onClicked: root.requestedOpen = false
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.frame }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    visible: root.page === "list"
                    spacing: 8

                    ListView {
                        id: profileList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 7
                        model: VpnService.profiles
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: profileCard
                            required property int index
                            required property var modelData
                            width: profileList.width
                            height: 92
                            radius: 6
                            color: VpnService.isConnected(modelData.id) ? root.theme.bgHover : root.theme.bgAlt
                            border.width: VpnService.isConnected(modelData.id) || VpnService.lastFailedProfileId === modelData.id ? 1.5 : 1
                            border.color: VpnService.lastFailedProfileId === modelData.id ? root.theme.accentActive : (VpnService.isConnected(modelData.id) ? root.theme.rune : root.theme.frame)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: profileCard.modelData.name
                                        color: root.theme.textLight
                                        font.family: root.theme.font
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: root.profileStatus(profileCard.modelData)
                                        color: root.profileStatusColor(profileCard.modelData)
                                        font.family: root.theme.font
                                        font.pixelSize: 8
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: profileCard.modelData.backend === "networkmanager" ? (profileCard.modelData.connectionName || "Профиль NetworkManager") : (profileCard.modelData.backend === "openfortivpn" ? (profileCard.modelData.host || "Адрес сервера") : (profileCard.modelData.configPath || profileCard.modelData.connectCommand || "Команда подключения"))
                                    color: root.theme.textDark
                                    font.family: root.theme.font
                                    font.pixelSize: 8
                                    elide: Text.ElideMiddle
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    ActionButton {
                                        label: VpnService.isConnected(profileCard.modelData.id) ? "Отключить" : (VpnService.lastFailedProfileId === profileCard.modelData.id ? "Повторить" : "Подключиться")
                                        active: !VpnService.isConnected(profileCard.modelData.id)
                                        onClicked: VpnService.isConnected(profileCard.modelData.id) ? VpnService.disconnect() : root.beginLogin(profileCard.modelData)
                                    }
                                    ActionButton {
                                        label: "Изменить"
                                        onClicked: root.openEditor(profileCard.modelData)
                                    }
                                    ActionButton {
                                        label: "Удалить"
                                        onClicked: VpnService.removeProfile(profileCard.modelData.id)
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 28
                            visible: VpnService.profiles.length === 0
                            text: "Список пуст. Добавьте профиль NetworkManager, OpenFortiVPN или команду другого клиента."
                            color: root.theme.textDark
                            font.family: root.theme.font
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                }

                ScrollView {
                    anchors.fill: parent
                    visible: root.page === "edit"
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        x: 8
                        width: Math.max(0, parent.width - 16)
                        spacing: 7

                        Text { text: "Название"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        FormField { id: profileNameField; Layout.fillWidth: true; placeholderText: "Например, Рабочий VPN" }

                        Text { text: "Тип подключения"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        ComboBox {
                            id: backendCombo
                            Layout.fillWidth: true
                            implicitHeight: 29
                            model: ["Внешняя команда", "NetworkManager", "OpenFortiVPN"]
                            contentItem: Text { leftPadding: 8; text: backendCombo.displayText; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 5; color: root.theme.bgAlt; border.width: 1; border.color: backendCombo.popup.visible ? root.theme.accentActive : root.theme.frame }
                            delegate: ItemDelegate {
                                required property string modelData
                                width: backendCombo.width
                                height: 28
                                contentItem: Text { text: modelData; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.highlighted ? root.theme.bgHover : root.theme.bg }
                            }
                            popup: Popup {
                                y: backendCombo.height - 1
                                width: backendCombo.width
                                padding: 3
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: backendCombo.popup.visible ? backendCombo.delegateModel : null
                                    interactive: false
                                }
                                background: Rectangle {
                                    radius: 5
                                    color: root.theme.bg
                                    border.width: 1
                                    border.color: root.theme.frame
                                }
                            }
                        }

                        Text { visible: backendCombo.currentIndex === 1; text: "Профиль NetworkManager"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        RowLayout {
                            visible: backendCombo.currentIndex === 1
                            Layout.fillWidth: true
                            FormField { id: profileConnectionNameField; Layout.fillWidth: true; placeholderText: "Имя подключения" }
                            ActionButton { label: "Импорт .ovpn"; onClicked: openVpnFileDialog.open() }
                        }

                        Text { visible: backendCombo.currentIndex !== 1; text: backendCombo.currentIndex === 2 ? "Адрес сервера" : "Конфигурация клиента"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        FormField { id: profileHostField; visible: backendCombo.currentIndex !== 1; Layout.fillWidth: true; placeholderText: "vpn.example.org" }
                        RowLayout {
                            visible: backendCombo.currentIndex === 2
                            Layout.fillWidth: true
                            Text { text: "Порт"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                            FormField { id: profilePortField; Layout.preferredWidth: 70; placeholderText: "443"; validator: IntValidator { bottom: 1; top: 65535 } }
                            Item { Layout.fillWidth: true }
                        }
                        RowLayout {
                            visible: backendCombo.currentIndex !== 1
                            Layout.fillWidth: true
                            Text { text: "Путь к конфигу"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                            FormField { id: profileConfigPathField; Layout.fillWidth: true; placeholderText: "Необязательно" }
                        }
                        RowLayout {
                            visible: backendCombo.currentIndex === 2
                            Layout.fillWidth: true
                            Text { text: "Команда клиента"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                            FormField { id: profileClientCommandField; Layout.fillWidth: true; placeholderText: "openfortivpn или sudo -n openfortivpn" }
                        }
                        Text { visible: backendCombo.currentIndex === 0; text: "Команда подключения"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        FormField { id: profileConnectCommandField; visible: backendCombo.currentIndex === 0; Layout.fillWidth: true; placeholderText: "Команда запуска клиента" }
                        Text { visible: backendCombo.currentIndex === 0; text: "Команда отключения · необязательно"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        FormField { id: profileDisconnectCommandField; visible: backendCombo.currentIndex === 0; Layout.fillWidth: true; placeholderText: "Команда остановки клиента" }

                        Text { text: "Имя пользователя"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        FormField { id: profileUsernameField; Layout.fillWidth: true; placeholderText: "VPN-аккаунт" }

                        Text { visible: backendCombo.currentIndex !== 1; text: "Двухфакторная проверка"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                        ComboBox {
                            id: twoFactorCombo
                            visible: backendCombo.currentIndex !== 1
                            Layout.fillWidth: true
                            implicitHeight: 29
                            model: ["Не используется", "Запросить перед подключением", "Запросить по сообщению клиента"]
                            contentItem: Text { leftPadding: 8; text: twoFactorCombo.displayText; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 5; color: root.theme.bgAlt; border.width: 1; border.color: twoFactorCombo.popup.visible ? root.theme.accentActive : root.theme.frame }
                            delegate: ItemDelegate {
                                required property string modelData
                                width: twoFactorCombo.width
                                height: 28
                                contentItem: Text { text: modelData; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.highlighted ? root.theme.bgHover : root.theme.bg }
                            }
                            popup: Popup {
                                y: twoFactorCombo.height - 1
                                width: twoFactorCombo.width
                                padding: 3
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: twoFactorCombo.popup.visible ? twoFactorCombo.delegateModel : null
                                    interactive: false
                                }
                                background: Rectangle {
                                    radius: 5
                                    color: root.theme.bg
                                    border.width: 1
                                    border.color: root.theme.frame
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: backendCombo.currentIndex !== 1 && (backendCombo.currentIndex === 2 || twoFactorCombo.currentIndex === 2)
                            text: backendCombo.currentIndex === 2 ? "Для OpenFortiVPN код вводится перед запуском клиента." : "Автоматический запрос сработает, если команда покажет сообщение о коде и читает ответ из stdin."
                            color: root.theme.textDark
                            font.family: root.theme.font
                            font.pixelSize: 8
                            wrapMode: Text.Wrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: VpnService.lastError !== ""
                            text: VpnService.lastError
                            color: root.theme.rune
                            font.family: root.theme.font
                            font.pixelSize: 8
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            ActionButton { label: "Отмена"; onClicked: { VpnService.lastError = ""; root.page = "list" } }
                            ActionButton { label: "Сохранить профиль"; active: true; onClicked: root.finishEditor() }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 34
                    visible: root.page === "login"
                    spacing: 8

                    Text { text: "Имя пользователя"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                    FormField { id: loginUsernameField; Layout.fillWidth: true; placeholderText: "VPN-аккаунт" }
                    Text { text: "Пароль"; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8 }
                    FormField { id: loginPasswordField; Layout.fillWidth: true; placeholderText: "Пароль VPN · если требуется"; echoMode: TextInput.Password; onAccepted: root.submitLogin() }
                    ActionButton {
                        label: "Загрузить сохранённый пароль"
                        onClicked: selectedProfile ? VpnService.loadPassword(selectedProfile.id) : undefined
                    }
                    CheckBox {
                        id: rememberPasswordCheck
                        text: "Сохранить пароль в системной связке ключей"
                        checked: false
                        contentItem: Text { leftPadding: rememberPasswordCheck.indicator.width + 7; text: rememberPasswordCheck.text; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 8; verticalAlignment: Text.AlignVCenter; wrapMode: Text.Wrap }
                        indicator: Rectangle { implicitWidth: 15; implicitHeight: 15; x: 0; y: (rememberPasswordCheck.height - height) / 2; radius: 3; color: rememberPasswordCheck.checked ? root.theme.bgHover : root.theme.bgAlt; border.width: 1; border.color: rememberPasswordCheck.checked ? root.theme.accentActive : root.theme.frame; Text { anchors.centerIn: parent; text: rememberPasswordCheck.checked ? "✓" : ""; color: root.theme.accentGlow; font.pixelSize: 10 } }
                    }
                    Text {
                        visible: selectedProfile && (selectedProfile.twoFactor === "before" || selectedProfile.backend === "openfortivpn" && selectedProfile.twoFactor === "challenge")
                        text: "Код двухфакторной проверки"
                        color: root.theme.textDark
                        font.family: root.theme.font
                        font.pixelSize: 8
                    }
                    FormField {
                        id: loginOtpField
                        visible: selectedProfile && (selectedProfile.twoFactor === "before" || selectedProfile.backend === "openfortivpn" && selectedProfile.twoFactor === "challenge")
                        Layout.fillWidth: true
                        placeholderText: "Одноразовый код"
                        onAccepted: root.submitLogin()
                    }
                    Text { Layout.fillWidth: true; visible: VpnService.lastError !== ""; text: VpnService.lastError; color: root.theme.rune; font.family: root.theme.font; font.pixelSize: 8; wrapMode: Text.Wrap }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ActionButton { label: "Подключиться"; active: true; onClicked: root.submitLogin() }
                    }
                    Text { Layout.fillWidth: true; text: "Пароли хранятся через secret-tool в системной связке ключей и не записываются в config.json."; color: root.theme.textDark; font.family: root.theme.font; font.pixelSize: 8; wrapMode: Text.Wrap }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 34
                    visible: root.page === "otp"
                    spacing: 8

                    Text { Layout.fillWidth: true; text: "Клиент запросил одноразовый код. Введите его, чтобы продолжить подключение."; color: root.theme.textMain; font.family: root.theme.font; font.pixelSize: 9; wrapMode: Text.Wrap }
                    FormField { id: challengeOtpField; Layout.fillWidth: true; placeholderText: "Код 2FA"; onAccepted: { if (VpnService.submitOtp(text)) { clear(); root.page = "list" } } }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ActionButton { label: "Отправить код"; active: true; onClicked: { if (VpnService.submitOtp(challengeOtpField.text)) { challengeOtpField.clear(); root.page = "list" } } }
                    }
                    Text { Layout.fillWidth: true; visible: VpnService.lastError !== ""; text: VpnService.lastError; color: root.theme.rune; font.family: root.theme.font; font.pixelSize: 8; wrapMode: Text.Wrap }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.page === "list" && (VpnService.lastError !== "" || VpnService.connectionStatus !== "disconnected")
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 4
                    color: VpnService.connectionStatus === "error" || VpnService.lastError !== "" ? root.theme.accentActive : (VpnService.connectionStatus === "connected" ? "#75d99a" : root.theme.accentGlow)
                }

                Text {
                    Layout.fillWidth: true
                    text: root.connectionSummary()
                    textFormat: Text.PlainText
                    color: VpnService.connectionStatus === "error" || VpnService.lastError !== "" ? root.theme.accentGlow : root.theme.textMain
                    font.family: root.theme.font
                    font.pixelSize: 8
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
