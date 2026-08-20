import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var tabButtonList: [{"icon": "checklist", "name": Translation.tr("Unfinished")}, {"name": Translation.tr("Done"), "icon": "check_circle"}]
    property bool showAddDialog: false
    property int dialogMargins: 20
    property int fabSize: 48
    property int fabMargins: 14

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
        }
        // Open add dialog on "N" (any modifiers)
        else if (event.key === Qt.Key_N) {
            root.showAddDialog = true
            event.accepted = true;
        }
        // Close dialog on Esc if open
        else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: swipeView.currentIndex

            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            // To Do tab
            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "check_circle"
                emptyPlaceholderText: Translation.tr("Nothing here!")
                taskList: Todo.list
                    .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                    .filter(function(item) { return !item.done; })
            }
            TaskList {
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "checklist"
                emptyPlaceholderText: Translation.tr("Finished tasks will go here")
                taskList: Todo.list
                    .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                    .filter(function(item) { return item.done; })
            }

        }
    }

    // + FAB
    StyledRectangularShadow {
        target: fabButton
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    FloatingActionButton {
        id: fabButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins

        onClicked: root.showAddDialog = true
        iconText: "add"
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { 
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                todoInput.text = ""
                dialog.addFeedbackMsg = ""
                dialog.isAdding = false
                fabButton.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
                onClicked: if (!dialog.isAdding) root.showAddDialog = false
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            property bool isAdding: false
            property string addFeedbackMsg: ""
            property bool addFeedbackSynced: true
            property string pendingDesc: ""

            Process {
                id: addTaskProcess
                command: ["python3", Quickshell.shellPath("scripts/google_sync.py"), "add-task", dialog.pendingDesc]
                stdout: SplitParser {
                    onRead: (data) => {
                        if (data.includes("[RESULT]")) {
                            try {
                                const jsonStr = data.substring(data.indexOf("[RESULT]") + 8).trim();
                                const res = JSON.parse(jsonStr);
                                dialog.addFeedbackSynced = res.synced ?? false;
                                dialog.addFeedbackMsg = res.synced ? Translation.tr("✓ Sincronizado con Google Tasks") : Translation.tr("💾 Guardado localmente");
                            } catch (e) {
                                dialog.addFeedbackMsg = Translation.tr("✓ Tarea agregada");
                            }
                        }
                    }
                }
                onExited: (exitCode) => {
                    dialog.isAdding = false;
                    Todo.refresh();
                    addFinishTimer.restart();
                }
            }

            Timer {
                id: addFinishTimer
                interval: 1000
                onTriggered: {
                    todoInput.text = "";
                    dialog.addFeedbackMsg = "";
                    root.showAddDialog = false;
                    tabBar.setCurrentIndex(0);
                }
            }

            function addTask() {
                const desc = todoInput.text.trim();
                if (desc.length > 0 && !dialog.isAdding) {
                    dialog.isAdding = true;
                    dialog.addFeedbackMsg = "";
                    dialog.pendingDesc = desc;
                    Todo.addItem({ "content": desc, "done": false });
                    addTaskProcess.running = true;
                }
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: Translation.tr("Add task")
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Task description")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: root.showAddDialog
                    enabled: !dialog.isAdding
                    onAccepted: dialog.addTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                StyledIndeterminateProgressBar {
                    visible: dialog.isAdding
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: -8
                    Layout.bottomMargin: -8
                }

                StyledText {
                    visible: dialog.addFeedbackMsg !== ""
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: -4
                    Layout.bottomMargin: -4
                    text: dialog.addFeedbackMsg
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: dialog.addFeedbackSynced ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        enabled: !dialog.isAdding
                        onClicked: root.showAddDialog = false
                    }
                    DialogButton {
                        buttonText: dialog.isAdding ? Translation.tr("Agregando...") : Translation.tr("Add")
                        enabled: !dialog.isAdding && todoInput.text.trim().length > 0
                        onClicked: dialog.addTask()
                    }
                }
            }
        }
    }
}
