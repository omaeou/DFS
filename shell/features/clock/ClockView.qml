import QtQuick
import "../shared"

Text {
    id: clockText

    color: GlobalState.effectiveTheme.textLight
    font.family: GlobalState.effectiveTheme.font
    font.bold: true
    font.pixelSize: Number(settings.fontSize) || 13
    text: "--"

    readonly property var settings: GlobalState.config.modules.Clock || ({})

    function twoDigits(value) { return ("0" + value).slice(-2) }

    function updateText() {
        const d = new Date()
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        const format = settings.format || "ddd DD MMM HH:mm"
        const values = {
            ddd: days[d.getDay()],
            DD: twoDigits(d.getDate()),
            MMM: months[d.getMonth()],
            HH: twoDigits(d.getHours()),
            mm: twoDigits(d.getMinutes()),
            ss: twoDigits(d.getSeconds())
        }
        let result = format
        const tokens = ["ddd", "DD", "MMM", "HH", "mm", "ss"]
        tokens.forEach(function (token) {
            result = result.split(token).join(values[token])
        })
        clockText.text = result
    }

    Timer {
        // Seconds are refreshed every second; minute-only clocks do less work.
        interval: (settings.format || "").indexOf("ss") >= 0 ? 1000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clockText.updateText()
    }
}
