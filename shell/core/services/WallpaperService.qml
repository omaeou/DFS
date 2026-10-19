pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../features/shared"

Singleton {
    id: service

    property var wallpaperSources: GlobalState.config.wallpapers || []
    property var transitionSettings: GlobalState.config.wallpaperTransition || ({})
    property bool initialized: false
    property var wallpapers: []
    property int selectedIndex: -1
    property string currentPath: ""
    property string lastError: ""
    property bool scanning: false
    property int scanGeneration: 0
    property int pendingScans: 0
    property var scanResults: []
    property var scanErrors: []
    property int pendingIndex: -1
    property string pendingPath: ""
    property string pendingAwwwExecutable: ""

    onWallpaperSourcesChanged: if (initialized) refreshWallpapers()

    Component.onCompleted: {
        initialized = true
        refreshWallpapers()
    }

    Process {
        id: awwwLookupProcess
        stdout: StdioCollector { id: awwwLookupOutput }
        onExited: (exitCode, exitStatus) => {
            const executable = awwwLookupOutput.text.trim()
            if (exitCode !== 0 || executable === "") {
                service.lastError = "Не найдена программа awww. Установите пакет awww и запустите awww-daemon."
                service.pendingIndex = -1
                service.pendingPath = ""
                return
            }
            service.pendingAwwwExecutable = executable
            monitorRefreshProcess.exec(["hyprctl", "monitors", "-j"])
        }
    }

    Process {
        id: monitorRefreshProcess
        stdout: StdioCollector { id: monitorRefreshOutput }
        onExited: (exitCode, exitStatus) => {
            service.applyWallpaperWithRefresh(monitorRefreshOutput.text)
        }
    }

    Process {
        id: wallpaperProcess
        stderr: StdioCollector { id: wallpaperStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                service.selectedIndex = service.pendingIndex
                service.currentPath = service.pendingPath
                service.lastError = ""
            } else {
                service.lastError = wallpaperStderr.text.trim() || "Не удалось применить обои. Проверьте, что запущен awww-daemon и изображение доступно."
                console.warn("[DFS:wallpaper]", service.lastError)
            }
            service.pendingIndex = -1
            service.pendingPath = ""
            service.pendingAwwwExecutable = ""
        }
    }

    function resolvePath(path) {
        let value = String(path || "").trim()
        if (value.startsWith("file://")) {
            try {
                value = decodeURIComponent(value.substring(7))
            } catch (error) {
                return ""
            }
        }
        if (value.startsWith("~/"))
            value = Quickshell.env("HOME") + value.substring(1)
        if (value.startsWith("/"))
            return value
        return Quickshell.shellDir + "/" + value
    }

    function sourcePath(path) {
        let value = String(path || "").trim()
        if (!value)
            return ""
        if (value.endsWith("/.*"))
            value = value.slice(0, -2)
        else if (value.endsWith("/**"))
            value = value.slice(0, -2)
        else if (value.endsWith("/*"))
            value = value.slice(0, -1)
        return resolvePath(value)
    }

    function refreshWallpapers() {
        scanGeneration += 1
        const generation = scanGeneration
        const sources = Array.isArray(wallpaperSources) ? wallpaperSources : []
        scanResults = []
        scanErrors = []
        pendingScans = 0
        scanning = sources.length > 0
        if (sources.length === 0) {
            wallpapers = []
            selectedIndex = -1
            currentPath = ""
            lastError = ""
            scanning = false
            return
        }

        for (let i = 0; i < sources.length; i++) {
            const path = sourcePath(sources[i])
            if (!path)
                continue
            pendingScans += 1
            const job = scanComponent.createObject(service, { rootPath: path, scanId: generation })
            if (!job) {
                pendingScans -= 1
                scanErrors = scanErrors.concat([path])
            }
        }

        if (pendingScans === 0)
            finishScan(generation)
    }

    function completeScan(generation, rootPath, exitCode, output, errorOutput) {
        if (generation !== scanGeneration)
            return
        const paths = String(output || "").split(/\r?\n/).map(path => path.trim()).filter(path => path !== "")
        scanResults = scanResults.concat(paths)
        if (exitCode !== 0) {
            const detail = String(errorOutput || "").trim().split(/\r?\n/)[0].slice(0, 140)
            scanErrors = scanErrors.concat([detail ? rootPath + ": " + detail : rootPath])
        }
        pendingScans = Math.max(0, pendingScans - 1)
        if (pendingScans === 0)
            finishScan(generation)
    }

    function finishScan(generation) {
        if (generation !== scanGeneration)
            return
        const sorted = scanResults.slice().sort((left, right) => left.localeCompare(right))
        const unique = []
        for (let i = 0; i < sorted.length; i++) {
            if (unique.length === 0 || unique[unique.length - 1] !== sorted[i])
                unique.push(sorted[i])
        }
        wallpapers = unique
        selectedIndex = currentPath ? wallpapers.indexOf(currentPath) : -1
        scanning = false
        if (scanErrors.length > 0 && wallpapers.length === 0)
            lastError = "Не удалось прочитать пути к обоям: " + scanErrors.join("; ")
        else if (wallpapers.length === 0)
            lastError = "В указанных каталогах не найдено изображений. Проверьте путь и формат файла."
        else if (scanErrors.length > 0)
            lastError = "Часть путей к обоям недоступна: " + scanErrors.join("; ")
        else
            lastError = ""
    }

    function applyWallpaperWithRefresh(refreshOutput) {
        const settings = transitionSettings || ({})
        let fps = 60
        if (settings.fps === "auto") {
            try {
                const monitors = JSON.parse(String(refreshOutput || ""))
                let maximumRefresh = 0
                for (let i = 0; i < monitors.length; i++) {
                    const refreshRate = Number(monitors[i].refreshRate)
                    if (isFinite(refreshRate) && refreshRate > maximumRefresh)
                        maximumRefresh = refreshRate
                }
                if (maximumRefresh > 0)
                    fps = Math.ceil(maximumRefresh)
            } catch (error) {
                fps = 60
            }
        } else {
            const configuredFps = Number(settings.fps)
            if (isFinite(configuredFps) && configuredFps > 0)
                fps = Math.ceil(configuredFps)
        }
        fps = Math.max(1, Math.min(255, fps))

        const args = [
            "img",
            "--transition-type", settings.type || "grow",
            "--transition-duration", String(settings.duration || 0.65),
            "--transition-fps", String(fps),
            "--transition-pos", settings.position || "center",
            "--transition-bezier", settings.bezier || "0.16,1,0.30,1",
            pendingPath
        ]
        wallpaperProcess.exec([pendingAwwwExecutable].concat(args))
    }

    function applyIndex(index) {
        if (scanning)
            return false
        if (!wallpapers || wallpapers.length === 0) {
            lastError = "Добавьте путь к файлу или каталогу с изображениями в wallpapers в config.json."
            return false
        }
        if (wallpaperProcess.running || awwwLookupProcess.running || monitorRefreshProcess.running) {
            lastError = "Дождитесь завершения текущей смены обоев."
            return false
        }

        const normalized = ((Number(index) % wallpapers.length) + wallpapers.length) % wallpapers.length
        pendingIndex = normalized
        pendingPath = wallpapers[normalized]
        lastError = ""
        awwwLookupProcess.exec(["sh", "-c", "command -v awww"])
        return true
    }

    function next() {
        return applyIndex(selectedIndex < 0 ? 0 : selectedIndex + 1)
    }

    function previous() {
        return applyIndex(selectedIndex < 0 ? wallpapers.length - 1 : selectedIndex - 1)
    }

    Component {
        id: scanComponent
        Process {
            property string rootPath: ""
            property int scanId: 0
            command: ["find", "-L", rootPath, "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.avif", "-o", "-iname", "*.bmp", "-o", "-iname", "*.gif", "-o", "-iname", "*.tif", "-o", "-iname", "*.tiff", "-o", "-iname", "*.pnm", "-o", "-iname", "*.tga", "-o", "-iname", "*.farbfeld", "-o", "-iname", "*.svg", ")", "-print"]
            environment: ({ LC_ALL: "C" })
            stdout: StdioCollector { id: scanOutput }
            stderr: StdioCollector { id: scanError }
            Component.onCompleted: running = true
            onExited: (exitCode, exitStatus) => {
                service.completeScan(scanId, rootPath, exitCode, scanOutput.text, scanError.text)
                destroy()
            }
        }
    }
}
