import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

StyledPopup {
    id: root
    contentPadding: Appearance.spacing.space150

    Item {
        id: contentRoot
        implicitWidth: 260
        implicitHeight: mainColumn.implicitHeight

        ColumnLayout {
            id: mainColumn
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: Appearance.spacing.space100

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.space50

                MaterialSymbol {
                    text: "screen_record"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colError
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Screen Recording")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colError
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Appearance.colors.colError
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.space100

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Actively recording")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }

                RippleButton {
                    implicitWidth: stopRow.implicitWidth + Appearance.spacing.space100 * 2
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colErrorContainer
                    colBackgroundHover: Appearance.colors.colErrorContainerHover
                    onClicked: {
                        ScreenRecord.stopRecord()
                        root.dismissRequested()
                    }
                    RowLayout {
                        id: stopRow
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.space50
                        MaterialSymbol {
                            text: "stop"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnErrorContainer
                        }
                        StyledText {
                            text: Translation.tr("Stop")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnErrorContainer
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Stop recording and save video")
                    }
                }
            }
        }
    }
}
