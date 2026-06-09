import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as Platform
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName) => disconnectSource(sourceName)
        function exec(cmd) { connectSource(cmd) }
    }

    function openInVSCode(projectPath) {
        Qt.openUrlExternally("vscode://file/" + projectPath)
    }

    function projectName(path) {
        return path.split("/").filter(s => s.length > 0).pop() || path
    }

    function addProject(path) {
        var list = Plasmoid.configuration.projects.slice()
        if (list.indexOf(path) < 0) {
            list.push(path)
            Plasmoid.configuration.projects = list
        }
    }

    function removeProject(idx) {
        var list = Plasmoid.configuration.projects.slice()
        list.splice(idx, 1)
        Plasmoid.configuration.projects = list
    }

    function dockerCmd(projectPath, action) {
        executable.exec("sh -c \"cd '" + projectPath + "' && docker compose " + action + "\"")
    }

    Platform.FolderDialog {
        id: folderDialog
        title: "Seleccionar carpeta del proyecto"
        folder: "file:///home/guti/Code"
        onAccepted: addProject(folder.toString().replace("file://", ""))
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.centerIn: parent
            source: "code-context"
            width: Math.min(parent.width, parent.height) * 0.85
            height: width
            opacity: compactRoot.containsMouse ? 0.7 : 1.0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: 0

        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 25

        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent

                Kirigami.Icon {
                    source: "code-context"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaExtras.Heading {
                    text: "Proyectos"
                    level: 3
                    Layout.fillWidth: true
                }

                PlasmaComponents.ToolButton {
                    icon.name: "list-add"
                    flat: true
                    onClicked: folderDialog.open()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Plasmoid.configuration.projects.length === 0

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: "Sin proyectos.\nPresiona + para añadir uno."
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.5
                wrapMode: Text.WordWrap
            }
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: Plasmoid.configuration.projects.length > 0

            Column {
                width: parent.width

                Repeater {
                    model: Plasmoid.configuration.projects

                    delegate: Column {
                        width: parent ? parent.width : 0

                        property string projectPath: modelData
                        property int projectIndex: index

                        // Detecta si existe docker-compose en el proyecto
                        FolderListModel {
                            id: dockerFiles
                            folder: "file://" + projectPath
                            showFiles: true
                            showDirs: false
                            nameFilters: ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 0

                            PlasmaComponents.ItemDelegate {
                                Layout.fillWidth: true
                                icon.name: "code"
                                text: root.projectName(projectPath)
                                onClicked: {
                                    root.openInVSCode(projectPath)
                                    root.expanded = false
                                }
                            }

                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0
                                width: visible ? implicitWidth : 0
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "media-playback-start"
                                flat: true
                                onClicked: root.dockerCmd(projectPath, "up -d")
                            }

                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0
                                width: visible ? implicitWidth : 0
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "media-playback-stop"
                                flat: true
                                onClicked: root.dockerCmd(projectPath, "down")
                            }

                            PlasmaComponents.ToolButton {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "list-remove"
                                flat: true
                                onClicked: root.removeProject(projectIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
