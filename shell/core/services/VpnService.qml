pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../features/shared"

Singleton {
    id: service

    readonly property var profiles: GlobalState.config.vpnProfiles || []
    property string activeProfileId: ""
    property string connectionStatus: "disconnected"
    property string lastError: ""
    property string lastFailedProfileId: ""
    property bool awaitingOtp: false
    property string awaitingOtpProfileId: ""
    signal passwordRetrieved(string profileId, string password)
    signal profileImported(string connectionName, string configPath)

    readonly property var activeProfile: {
        for (let i = 0; i < profiles.length; i++) {
            if (profiles[i].id === activeProfileId)
                return profiles[i]
        }
        return null
    }
    readonly property string activeProfileName: activeProfile ? activeProfile.name : ""
    readonly property bool connected: connectionStatus === "connected" || connectionStatus === "connecting" || connectionStatus === "awaitingOtp" || connectionStatus === "disconnecting"
    property string outputWindow: ""

    property bool ignoreConnectExit: false

    function isConnected(profileId) {
        return activeProfileId === profileId && connected
    }

    function saveProfiles(nextProfiles) {
        return GlobalState.updateVpnProfiles(nextProfiles)
    }

    function upsertProfile(profile) {
        const next = GlobalState.clone(profiles)
        const index = next.findIndex(item => item.id === profile.id)
        if (index < 0)
            next.push(profile)
        else
            next[index] = profile
        return saveProfiles(next)
    }

    function removeProfile(profileId) {
        const next = profiles.filter(item => item.id !== profileId)
        clearPassword(profileId)
        if (activeProfileId === profileId)
            disconnect()
        return saveProfiles(next)
    }

    function loadPassword(profileId) {
        secretLookupComponent.createObject(service, { profileId: profileId })
    }

    function savePassword(profileId, profileName, password) {
        if (!password)
            return
        secretStoreComponent.createObject(service, {
            profileId: profileId,
            profileName: profileName,
            secret: password
        })
    }

    function clearPassword(profileId) {
        clearProcess.exec(["secret-tool", "clear", "service", "dfs-vpn", "profileId", profileId])
    }

    function connect(profile, username, password, otp) {
        if (!profile) {
            lastError = "Выберите VPN-профиль."
            return false
        }
        if (activeProfileId) {
            lastError = activeProfileId === profile.id
                ? "Этот профиль уже подключается или подключён."
                : "Сначала отключите текущее VPN-подключение."
            return false
        }

        lastError = ""
        lastFailedProfileId = ""
        outputWindow = ""
        activeProfileId = profile.id
        ignoreConnectExit = false
        awaitingOtp = false
        awaitingOtpProfileId = ""
        connectionStatus = "connecting"

        if (profile.backend === "networkmanager") {
            if (!profile.connectionName) {
                fail("Укажите имя профиля NetworkManager.")
                return false
            }
            connectProcess.exec(["nmcli", "connection", "up", "id", profile.connectionName])
            return true
        }

        const environment = {
            DFS_VPN_PROFILE_ID: profile.id,
            DFS_VPN_USERNAME: username || "",
            DFS_VPN_PASSWORD: password || "",
            DFS_VPN_OTP: otp || "",
            DFS_VPN_CONFIG: profile.configPath || "",
            DFS_VPN_HOST: profile.host || "",
            DFS_VPN_PORT: String(profile.port || "443"),
            DFS_VPN_CLIENT_COMMAND: profile.clientCommand || "openfortivpn"
        }

        if (profile.backend === "openfortivpn") {
            connectProcess.exec({
                command: ["bash", Quickshell.shellDir + "/core/services/openfortivpn-launcher.sh"],
                environment: environment
            })
            return true
        }

        if (!profile.connectCommand || !profile.connectCommand.trim()) {
            fail("Укажите команду подключения для этого профиля.")
            return false
        }
        connectProcess.exec({
            command: ["bash", "-lc", profile.connectCommand],
            environment: environment
        })
        return true
    }

    function submitOtp(code) {
        if (!awaitingOtp || !code || !connectProcess.running)
            return false
        connectProcess.write(code + "\n")
        awaitingOtp = false
        awaitingOtpProfileId = ""
        connectionStatus = "connecting"
        connectionTimeoutTimer.restart()
        return true
    }

    function disconnect() {
        if (!activeProfileId)
            return
        const profile = activeProfile
        awaitingOtp = false
        awaitingOtpProfileId = ""
        if (connectProcess.running) {
            ignoreConnectExit = true
            connectProcess.running = false
        }

        if (profile && profile.backend === "networkmanager") {
            connectionStatus = "disconnecting"
            disconnectProcess.exec(["nmcli", "connection", "down", "id", profile.connectionName])
            return
        }

        if (profile && profile.disconnectCommand && profile.disconnectCommand.trim()) {
            disconnectProcess.exec({
                command: ["bash", "-lc", profile.disconnectCommand],
                environment: ({ DFS_VPN_PROFILE_ID: profile.id, DFS_VPN_CONFIG: profile.configPath || "" })
            })
            connectionStatus = "disconnecting"
            return
        }

        finishDisconnect()
    }

    function finishDisconnect() {
        activeProfileId = ""
        connectionStatus = "disconnected"
        lastError = ""
        lastFailedProfileId = ""
        awaitingOtp = false
        awaitingOtpProfileId = ""
        outputWindow = ""
    }

    function fail(message) {
        if (activeProfileId)
            lastFailedProfileId = activeProfileId
        lastError = message
        connectionStatus = "error"
        awaitingOtp = false
        awaitingOtpProfileId = ""
        activeProfileId = ""
        outputWindow = ""
    }

    function inspectOutput(chunk) {
        if (!activeProfile)
            return
        outputWindow = (outputWindow + String(chunk)).slice(-1200)
        if (activeProfile.twoFactor === "challenge" && activeProfile.backend !== "openfortivpn" && !awaitingOtp && /\b(otp|one[- ]time password|verification code|authentication code|security code|passcode|token(?: code)?|two[- ]factor)\b|одноразов\w*\s+код|код\s+(?:подтверждения|аутентификации|доступа)/i.test(outputWindow)) {
            awaitingOtp = true
            awaitingOtpProfileId = activeProfileId
            connectionStatus = "awaitingOtp"
            outputWindow = ""
            return
        }
        const connectedOutput = /tunnel is up and running|connection successfully activated|connection established|connected successfully|successfully connected|vpn connected/i.test(outputWindow)
        if (connectedOutput && connectionStatus === "connecting") {
            connectionTimeoutTimer.stop()
            connectionStatus = "connected"
            lastError = ""
            lastFailedProfileId = ""
        }
    }

    function failureMessage(exitCode) {
        if (/authentication failed|authentication failure|failed to authenticate|invalid credentials|login failed|permission denied/i.test(outputWindow))
            return "Сервер отклонил учётные данные. Проверьте логин, пароль и код 2FA."
        if (/certificate|tls handshake|ssl handshake/i.test(outputWindow))
            return "Не удалось проверить сертификат VPN-сервера. Проверьте настройки сертификата."
        if (/could not resolve|name or service not known|host not found/i.test(outputWindow))
            return "Не удалось найти VPN-сервер. Проверьте его адрес."
        if (/failed to connect|connection refused|timed out|no route to host|network is unreachable/i.test(outputWindow))
            return "Не удалось связаться с VPN-сервером. Проверьте сеть, адрес и порт."
        if (exitCode === "timeout")
            return "Проверьте сервер, сеть, пароль и код двухфакторной проверки."
        return "VPN-клиент завершился с кодом " + exitCode + ". Проверьте настройки профиля и права запуска."
    }

    function syncNetworkManager(output) {
        if (connectionStatus === "connecting" || connectionStatus === "awaitingOtp" || connectionStatus === "disconnecting")
            return
        const activeNames = String(output || "").split(/\r?\n/).map(name => name.trim()).filter(name => name !== "")
        let found = null
        for (let i = 0; i < profiles.length; i++) {
            const profile = profiles[i]
            if (profile.backend === "networkmanager" && activeNames.indexOf(profile.connectionName) >= 0) {
                found = profile
                break
            }
        }
        if (found) {
            if (!activeProfileId || activeProfile && activeProfile.backend === "networkmanager") {
                activeProfileId = found.id
                connectionStatus = "connected"
                lastError = ""
                lastFailedProfileId = ""
            }
        } else if (activeProfile && activeProfile.backend === "networkmanager" && connectionStatus === "connected") {
            finishDisconnect()
        }
    }

    function importOpenVpnConfig(path) {
        if (!path) {
            lastError = "Выберите файл конфигурации .ovpn."
            return
        }
        lastError = ""
        openVpnImportComponent.createObject(service, { configPath: path })
    }

    Process {
        id: connectProcess
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: chunk => service.inspectOutput(chunk)
        }
        stderr: SplitParser {
            splitMarker: ""
            onRead: chunk => service.inspectOutput(chunk)
        }
        onStarted: connectionTimeoutTimer.start()
        onExited: (exitCode, exitStatus) => {
            connectionTimeoutTimer.stop()
            if (service.ignoreConnectExit) {
                service.ignoreConnectExit = false
                return
            }
            const profile = service.activeProfile
            service.awaitingOtp = false
            service.awaitingOtpProfileId = ""
            if (exitCode === 0) {
                if (profile && profile.backend === "openfortivpn") {
                    service.fail(service.connectionStatus === "connected"
                        ? "VPN-клиент завершился после установки туннеля."
                        : "OpenFortiVPN завершился, не подтвердив подключение.")
                } else {
                    service.connectionStatus = "connected"
                    service.lastError = ""
                    service.lastFailedProfileId = ""
                }
            } else {
                service.fail(service.failureMessage(exitCode))
            }
            service.outputWindow = ""
        }
    }

    Timer {
        id: connectionTimeoutTimer
        interval: 45000
        repeat: false
        onTriggered: {
            if (connectProcess.running && service.connectionStatus === "connecting") {
                service.ignoreConnectExit = true
                connectProcess.running = false
                service.fail("VPN-клиент не подтвердил подключение за 45 секунд. " + service.failureMessage("timeout"))
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: networkStatusComponent.createObject(service)
    }

    Process {
        id: disconnectProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                service.finishDisconnect()
            else
                service.fail("Не удалось отключить VPN. Код завершения: " + exitCode + ".")
        }
    }

    Process { id: clearProcess }

    Component {
        id: networkStatusComponent
        Process {
            command: ["nmcli", "-g", "NAME", "connection", "show", "--active"]
            stdout: StdioCollector { id: nmStatusOutput }
            Component.onCompleted: running = true
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0)
                    service.syncNetworkManager(nmStatusOutput.text)
                destroy()
            }
        }
    }

    Component {
        id: secretLookupComponent
        Process {
            property string profileId: ""
            command: ["secret-tool", "lookup", "service", "dfs-vpn", "profileId", profileId]
            stdout: StdioCollector { id: passwordOutput }
            Component.onCompleted: running = true
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    const password = passwordOutput.text.replace(/\r?\n$/, "")
                    if (password !== "")
                        service.passwordRetrieved(profileId, password)
                }
                destroy()
            }
        }
    }

    Component {
        id: secretStoreComponent
        Process {
            property string profileId: ""
            property string profileName: ""
            property string secret: ""
            stdinEnabled: true
            command: ["secret-tool", "store", "--label=DFS VPN · " + profileName, "service", "dfs-vpn", "profileId", profileId]
            Component.onCompleted: running = true
            onStarted: {
                write(secret)
                stdinEnabled = false
            }
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0)
                    service.lastError = "Не удалось сохранить пароль. Проверьте, что системная связка ключей доступна."
                secret = ""
                destroy()
            }
        }
    }

    Component {
        id: openVpnImportComponent
        Process {
            property string configPath: ""
            command: ["nmcli", "connection", "import", "type", "openvpn", "file", configPath]
            environment: ({ LC_ALL: "C" })
            stdout: StdioCollector { id: importOutput }
            stderr: StdioCollector { id: importError }
            Component.onCompleted: running = true
            onExited: (exitCode, exitStatus) => {
                if (exitCode !== 0) {
                    service.lastError = importError.text.trim() || "NetworkManager не смог импортировать этот файл."
                    destroy()
                    return
                }
                const match = importOutput.text.match(/connection\s+['\"](.+?)['\"]\s+\(/i)
                if (!match) {
                    service.lastError = "Файл импортирован, но имя профиля NetworkManager не удалось определить."
                    destroy()
                    return
                }
                service.lastError = ""
                service.profileImported(match[1], configPath)
                destroy()
            }
        }
    }
}
