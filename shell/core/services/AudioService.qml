pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../features/shared"

// Shared reactive audio service. Pipewire nodes are tracked here once so widgets
// do not spawn subprocesses or poll independently.
Singleton {
    id: service

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property bool outputAvailable: Pipewire.ready && defaultSink !== null && defaultSink !== undefined && defaultSink.ready && defaultSink.audio !== null
    readonly property bool inputAvailable: Pipewire.ready && defaultSource !== null && defaultSource !== undefined && defaultSource.ready && defaultSource.audio !== null

    readonly property int outputVolume: outputAvailable ? Math.max(0, Math.min(volumeLimit("sink"), Math.round(defaultSink.audio.volume * 100))) : 0
    readonly property int inputVolume: inputAvailable ? Math.max(0, Math.min(volumeLimit("source"), Math.round(defaultSource.audio.volume * 100))) : 0
    readonly property bool outputMuted: outputAvailable ? defaultSink.audio.muted : false
    readonly property bool inputMuted: inputAvailable ? defaultSource.audio.muted : false

    property string outputErrorMessage: ""
    property string inputErrorMessage: ""

    function volumeLimit(target) {
        const moduleName = target === "source" ? "Mic" : "Volume"
        const settings = GlobalState.config.modules[moduleName] || ({})
        return Math.max(100, Math.min(150, Number(settings.maxVolume) || 100))
    }

    function setVolume(target, value) {
        const node = target === "source" ? defaultSource : defaultSink
        if (!Pipewire.ready || !node || !node.ready || !node.audio) {
            setError(target, "Аудиоустройство ещё не готово")
            return
        }

        const numericValue = Number(value)
        if (!isFinite(numericValue)) {
            setError(target, "Получено некорректное значение громкости")
            return
        }

        const nextValue = Math.max(0, Math.min(volumeLimit(target), Math.round(numericValue)))
        try {
            node.audio.volume = nextValue / 100.0
            if (nextValue > 0 && node.audio.muted)
                node.audio.muted = false
            setError(target, "")
        } catch (error) {
            setError(target, String(error))
            console.warn("[DFS:audio] Could not set", target, "volume:", error)
        }
    }

    function toggleMute(target) {
        const node = target === "source" ? defaultSource : defaultSink
        if (!Pipewire.ready || !node || !node.ready || !node.audio) {
            setError(target, "Аудиоустройство ещё не готово")
            return
        }

        try {
            node.audio.muted = !node.audio.muted
            setError(target, "")
        } catch (error) {
            setError(target, String(error))
            console.warn("[DFS:audio] Could not toggle", target, "mute:", error)
        }
    }

    function setError(target, message) {
        if (target === "source")
            inputErrorMessage = message
        else
            outputErrorMessage = message
    }

    // The PipeWire service may replace the default sink/source at runtime.
    // Tracking both objects makes their audio properties safe to read and write.
    PwObjectTracker {
        objects: [service.defaultSink, service.defaultSource]
    }
}
