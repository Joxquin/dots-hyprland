import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    readonly property bool isRecording: ScreenRecord.recording
    readonly property bool shown: isRecording
    readonly property bool vertical: Config.options.bar?.vertical ?? false
    property bool controlsPinned: false

    implicitWidth: shown ? (vertical ? Appearance.sizes.verticalBarWidth : pill.implicitWidth + Appearance.spacing.space100) : 0
    implicitHeight: shown ? (vertical ? pill.implicitHeight + Appearance.spacing.space100 : Appearance.sizes.barHeight) : 0
    visible: implicitWidth > 0 && implicitHeight > 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        radius: Appearance.rounding.full
        color: Appearance.colors.colErrorContainer
        border.width: 1
        border.color: Appearance.colors.colError

        implicitWidth: contentRow.implicitWidth + (mouseArea.containsMouse ? Appearance.spacing.space150 : Appearance.spacing.space100) * 2
        implicitHeight: 30

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.controlsPinned = !root.controlsPinned
            }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Appearance.spacing.space50

            // Pulsing record dot
            Rectangle {
                id: dot
                width: 8
                height: 8
                radius: 4
                color: Appearance.colors.colError
                Layout.alignment: Qt.AlignVCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.shown
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "screen_record"
                iconSize: 16
                color: Appearance.colors.colOnErrorContainer
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: mouseArea.containsMouse ? Translation.tr("Stop") : Translation.tr("REC")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: Appearance.colors.colOnErrorContainer
            }
        }
    }

    onShownChanged: if (!shown) root.controlsPinned = false

    RecordIndicatorPopup {
        id: recordPopup
        hoverTarget: mouseArea
        pinnedOpen: root.controlsPinned
        onDismissRequested: root.controlsPinned = false
    }
}
