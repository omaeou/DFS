import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../core/services"
import "../../shared"
import "."

Item {
    id: root
    implicitWidth: 196
    implicitHeight: 34
    width: implicitWidth
    height: implicitHeight

    RowLayout {
        anchors.fill: parent
        spacing: 9
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: MusicService.available ? MusicService.title : "Нет воспроизведения"
                textFormat: Text.PlainText
                color: GlobalState.effectiveTheme.textMain
                font.family: GlobalState.effectiveTheme.font
                font.pixelSize: 9
                elide: Text.ElideRight
                MouseArea { id: titleHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GlobalState.isEqualizerOpen = !GlobalState.isEqualizerOpen }
                ThemeToolTip { targetItem: titleHit; visible: titleHit.containsMouse; text: MusicService.available ? MusicService.title + "\n" + MusicService.artist + "\n" + (GlobalState.isEqualizerOpen ? "Закрыть музыкальное окно" : "Открыть плеер и эквалайзер") : "Ожидание Spotify или другого MPRIS-плеера" }
            }
            Text {
                Layout.fillWidth: true
                text: MusicService.available ? MusicService.artist : "Медиаплеер · открыть"
                textFormat: Text.PlainText
                color: GlobalState.effectiveTheme.textDark
                font.family: GlobalState.effectiveTheme.font
                font.pixelSize: 8
                elide: Text.ElideRight
                MouseArea { id: artistHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: GlobalState.isEqualizerOpen = !GlobalState.isEqualizerOpen }
                ThemeToolTip { targetItem: artistHit; visible: artistHit.containsMouse; text: GlobalState.isEqualizerOpen ? "Закрыть окно музыки и эквалайзера" : "Открыть окно музыки и эквалайзера" }
            }
        }
        RowLayout {
            spacing: 7
            Repeater {
                model: ["⏮", MusicService.playing ? "⏸" : "▶", "⏭"]
                delegate: BarButtonPlate {
                    required property int index
                    required property string modelData
                    Layout.preferredWidth: index === 1 ? 34 : 28
                    Layout.preferredHeight: 27
                    active: index === 1
                    hovered: controlHit.containsMouse
                    cornerRadius: 6
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index === 1 ? GlobalState.effectiveTheme.textLight : GlobalState.effectiveTheme.rune
                        font.pixelSize: index === 1 ? 13 : 18
                    }
                    MouseArea {
                        id: controlHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: index === 0 ? MusicService.previous() : index === 1 ? MusicService.togglePlayback() : MusicService.next()
                    }
                    ThemeToolTip {
                        targetItem: controlHit
                        visible: controlHit.containsMouse
                        text: index === 0 ? "Предыдущий трек" : (index === 1 ? (MusicService.playing ? "Пауза" : "Воспроизвести") : "Следующий трек")
                    }
                }
            }
        }
    }
}
