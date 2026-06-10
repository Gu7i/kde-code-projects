import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami
import org.kde.iconthemes as KIconThemes

Item {
    id: configRoot
    implicitHeight: mainLayout.implicitHeight

    property var cfg_editorsList: []

    property var parsedEditors: cfg_editorsList.map(function(e) {
        var p = e.split("|")
        return { name: p[0] || "", cmd: p[1] || "", icon: p[2] || "document-edit" }
    })

    function saveEditors(list) {
        cfg_editorsList = list.map(function(e) {
            return e.name + "|" + e.cmd + "|" + e.icon
        })
    }

    // -2 = cerrado, -1 = añadiendo nuevo, >=0 = editando existente
    property int editingIndex: -2
    property string pendingIcon: "document-edit"

    onEditingIndexChanged: {
        if (editingIndex === -1) {
            nameField.text = ""
            cmdField.text = ""
            configRoot.pendingIcon = "document-edit"
        } else if (editingIndex >= 0 && editingIndex < parsedEditors.length) {
            var e = parsedEditors[editingIndex]
            nameField.text = e.name
            cmdField.text = e.cmd
            configRoot.pendingIcon = e.icon
        }
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: iconName => {
            if (iconName) configRoot.pendingIcon = iconName
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: parsedEditors

            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: modelData.icon
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents.Label {
                    text: modelData.name
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                }

                PlasmaComponents.Label {
                    text: modelData.cmd
                    opacity: 0.6
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PlasmaComponents.ToolButton {
                    icon.name: "document-edit"
                    flat: true
                    onClicked: configRoot.editingIndex = index
                    PlasmaComponents.ToolTip { text: "Editar" }
                }

                PlasmaComponents.ToolButton {
                    icon.name: "list-remove"
                    flat: true
                    enabled: parsedEditors.length > 1
                    onClicked: {
                        var list = parsedEditors.slice()
                        list.splice(index, 1)
                        saveEditors(list)
                    }
                    PlasmaComponents.ToolTip { text: "Eliminar" }
                }
            }
        }

        Kirigami.Separator {
            visible: editingIndex >= -1
            Layout.fillWidth: true
        }

        Kirigami.FormLayout {
            visible: editingIndex >= -1
            Layout.fillWidth: true

            PlasmaComponents.TextField {
                id: nameField
                Kirigami.FormData.label: "Nombre:"
                placeholderText: "ej: VS Code"
            }

            PlasmaComponents.TextField {
                id: cmdField
                Kirigami.FormData.label: "Comando:"
                placeholderText: "ej: code --new-window"
            }

            RowLayout {
                Kirigami.FormData.label: "Ícono:"
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    id: iconPickerBtn
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing * 2
                    Layout.preferredHeight: Layout.preferredWidth

                    onClicked: iconDialog.open()

                    PlasmaComponents.ToolTip { text: "Buscar ícono" }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.large
                        height: width
                        source: configRoot.pendingIcon || "document-edit"
                    }
                }

                PlasmaComponents.Label {
                    text: configRoot.pendingIcon
                    opacity: 0.7
                    font.pixelSize: Kirigami.Units.gridUnit * 0.75
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            RowLayout {
                Kirigami.FormData.label: ""
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Button {
                    text: "Cancelar"
                    onClicked: configRoot.editingIndex = -2
                }

                PlasmaComponents.Button {
                    text: configRoot.editingIndex === -1 ? "Añadir" : "Guardar"
                    enabled: nameField.text.trim().length > 0 && cmdField.text.trim().length > 0
                    onClicked: {
                        var list = parsedEditors.slice()
                        var item = {
                            name: nameField.text.trim(),
                            cmd:  cmdField.text.trim(),
                            icon: configRoot.pendingIcon || "document-edit"
                        }
                        if (configRoot.editingIndex >= 0) list[configRoot.editingIndex] = item
                        else list.push(item)
                        saveEditors(list)
                        configRoot.editingIndex = -2
                    }
                }
            }
        }

        PlasmaComponents.Button {
            visible: editingIndex === -2
            text: "Añadir editor"
            icon.name: "list-add"
            onClicked: configRoot.editingIndex = -1
        }
    }
}
