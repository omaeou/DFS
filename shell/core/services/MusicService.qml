pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: service
    property var trackInfo: ({
        title: "Загрузка плеера…", artist: "", status: "Stopped", length: 0,
        position: 0, percent: 0, lengthStr: "00:00", positionStr: "00:00",
        playerName: "", source: "Ожидание", artUrl: ""
    })

    readonly property bool available: trackInfo.status === "Playing" || trackInfo.status === "Paused"
    readonly property bool playing: trackInfo.status === "Playing"
    readonly property string title: String(trackInfo.title || "Нет воспроизведения")
    readonly property string artist: String(trackInfo.artist || trackInfo.source || "Ожидание MPRIS")
    readonly property string playerName: String(trackInfo.playerName || "")
    readonly property string artUrl: String(trackInfo.artUrl || "")
    readonly property string positionText: String(trackInfo.positionStr || "00:00")
    readonly property string lengthText: String(trackInfo.lengthStr || "00:00")
    readonly property real position: Number(trackInfo.position || 0)
    readonly property real length: Number(trackInfo.length || 0)
    readonly property real percent: Number(trackInfo.percent || 0)

    function runControl(args) {
        controlProcess.running = false
        const playerArgs = service.playerName ? ["--player", service.playerName] : []
        controlProcess.command = ["playerctl"].concat(playerArgs).concat(args)
        controlProcess.running = true
    }

    function togglePlayback() { runControl(["play-pause"]) }
    function next() { runControl(["next"]) }
    function previous() { runControl(["previous"]) }
    function seekTo(seconds) { runControl(["position", String(Math.max(0, Number(seconds) || 0))]) }

    Process {
        id: infoProcess
        command: ["bash", Quickshell.shellDir + "/features/musicPlayer/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(String(text).trim())
                    if (data && typeof data === "object") service.trackInfo = data
                } catch (error) {
                    console.warn("[DFS:music] Could not parse playerctl metadata:", String(error))
                }
            }
        }
    }
    Process { id: controlProcess }

    Timer {
        interval: 900
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!infoProcess.running) infoProcess.running = true
    }
}
