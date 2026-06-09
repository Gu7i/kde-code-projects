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
        executable.exec("code --new-window '" + projectPath + "'")
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

    function extractFirstPort(portsStr) {
        if (!portsStr || portsStr.length === 0) return ""
        var seen = {}
        var ports = []
        var re = /:(\d+)->/g
        var m
        while ((m = re.exec(portsStr)) !== null) {
            if (!seen[m[1]]) { seen[m[1]] = true; ports.push(m[1]) }
        }
        return ports.join(" · ")
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

        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28

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
                    PlasmaComponents.ToolTip { text: "Añadir proyecto" }
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
            id: projectsScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: Plasmoid.configuration.projects.length > 0

            Column {
                width: projectsScrollView.availableWidth

                Repeater {
                    model: Plasmoid.configuration.projects

                    delegate: Column {
                        id: projectItem
                        width: parent ? parent.width : 0

                        property string projectPath: modelData
                        property int projectIndex: index
                        property bool isRunning: false
                        property bool isLoading: false   // true only during docker down
                        property bool isStarting: false  // true while compose up is starting
                        property bool isExpanded: false
                        property var containerList: []

                        property var composeFilePaths: []
                        property var composeFileNames: []
                        property int selectedComposeIndex: 0

                        function dockerComposeBase() {
                            if (composeFilePaths.length > 0)
                                return "docker compose -f '" + composeFilePaths[selectedComposeIndex] + "'"
                            return "docker compose --project-directory '" + projectPath + "'"
                        }

                        FolderListModel {
                            id: dockerFiles
                            folder: "file://" + projectPath
                            showFiles: true
                            showDirs: false
                            nameFilters: ["docker-compose*.yml", "docker-compose*.yaml", "compose*.yml", "compose*.yaml"]
                            onCountChanged: {
                                if (count === 0) return
                                var names = []
                                var paths = []
                                for (var i = 0; i < count; i++) {
                                    names.push(dockerFiles.get(i, "fileName"))
                                    paths.push(dockerFiles.get(i, "filePath"))
                                }
                                projectItem.composeFileNames = names
                                projectItem.composeFilePaths = paths
                                projectItem.selectedComposeIndex = 0
                                projectItem.checkStatus()
                            }
                        }

                        P5Support.DataSource {
                            id: statusSource
                            engine: "executable"
                            connectedSources: []
                            onNewData: (sourceName, data) => {
                                if (!projectItem.isStarting) {
                                    var running = data["stdout"].trim().length > 0
                                    projectItem.isRunning = running
                                    projectItem.isLoading = false
                                    if (!running) projectItem.isExpanded = false
                                }
                                disconnectSource(sourceName)
                            }
                        }

                        P5Support.DataSource {
                            id: containersSource
                            engine: "executable"
                            connectedSources: []
                            onNewData: (sourceName, data) => {
                                var lines = data["stdout"].trim().split("\n").filter(l => l.length > 0)
                                var containers = []
                                for (var i = 0; i < lines.length; i++) {
                                    var parts = lines[i].split("|")
                                    if (parts.length >= 2) {
                                        containers.push({
                                            service: parts[0].trim(),
                                            state: parts[1].trim(),
                                            ports: parts.length > 2 ? parts[2].trim() : ""
                                        })
                                    }
                                }
                                projectItem.containerList = containers
                                disconnectSource(sourceName)

                                if (projectItem.isStarting && containers.length > 0) {
                                    var allSettled = containers.every(function(c) {
                                        return c.state === "running" || c.state === "exited" || c.state === "dead"
                                    })
                                    if (allSettled) {
                                        projectItem.isStarting = false
                                        startupTimeoutTimer.stop()
                                        projectItem.isRunning = containers.some(function(c) {
                                            return c.state === "running"
                                        })
                                    }
                                }
                            }
                        }

                        function checkStatus() {
                            var cmd = dockerComposeBase() + " ps --status running -q 2>/dev/null"
                            statusSource.connectSource(cmd)
                        }

                        function fetchContainers() {
                            var cmd = dockerComposeBase() + " ps --format '{{.Service}}|{{.State}}|{{.Ports}}' 2>/dev/null"
                            containersSource.connectSource(cmd)
                        }

                        // Normal refresh poll (pauses during startup or when panel is closed)
                        Timer {
                            id: refreshTimer
                            interval: 3000
                            repeat: true
                            running: root.expanded && dockerFiles.count > 0 && !projectItem.isStarting
                            onTriggered: {
                                projectItem.checkStatus()
                                if (projectItem.isExpanded) projectItem.fetchContainers()
                            }
                        }

                        // Fast poll during compose up (auto-runs while isStarting)
                        Timer {
                            id: startupPollTimer
                            interval: 1000
                            repeat: true
                            running: projectItem.isStarting
                            onTriggered: projectItem.fetchContainers()
                        }

                        // Safety timeout: give up waiting after 60s
                        Timer {
                            id: startupTimeoutTimer
                            interval: 60000
                            repeat: false
                            onTriggered: {
                                projectItem.isStarting = false
                                projectItem.isRunning = projectItem.containerList.some(function(c) {
                                    return c.state === "running"
                                })
                            }
                        }

                        Connections {
                            target: root
                            function onExpandedChanged() {
                                if (root.expanded && dockerFiles.count > 0 && !projectItem.isStarting)
                                    projectItem.checkStatus()
                            }
                        }

                        // Project row
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

                            // Expand/collapse tree
                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0 && projectItem.isRunning && !projectItem.isLoading
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: projectItem.isExpanded ? "arrow-up" : "arrow-down"
                                flat: true
                                onClicked: {
                                    projectItem.isExpanded = !projectItem.isExpanded
                                    if (projectItem.isExpanded) projectItem.fetchContainers()
                                }
                                PlasmaComponents.ToolTip { text: projectItem.isExpanded ? "Colapsar servicios" : "Ver servicios" }
                            }

                            // Docker up/stop/spinner
                            Item {
                                visible: dockerFiles.count > 0
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter

                                PlasmaComponents.BusyIndicator {
                                    anchors.fill: parent
                                    running: projectItem.isLoading
                                    opacity: projectItem.isLoading ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                PlasmaComponents.ToolButton {
                                    anchors.fill: parent
                                    opacity: !projectItem.isLoading && !projectItem.isRunning && !projectItem.isStarting ? 1.0 : 0.0
                                    enabled: !projectItem.isLoading && !projectItem.isRunning && !projectItem.isStarting
                                    icon.name: "media-playback-start"
                                    icon.color: Kirigami.Theme.positiveTextColor
                                    flat: true
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    onClicked: {
                                        projectItem.isRunning = true
                                        projectItem.isStarting = true
                                        projectItem.isExpanded = true
                                        executable.exec("sh -c \"" + projectItem.dockerComposeBase() + " up -d\"")
                                        startupTimeoutTimer.restart()
                                        projectItem.fetchContainers()
                                    }
                                    PlasmaComponents.ToolTip { text: "Iniciar Docker" }
                                }

                                PlasmaComponents.ToolButton {
                                    anchors.fill: parent
                                    opacity: !projectItem.isLoading && (projectItem.isRunning || projectItem.isStarting) ? 1.0 : 0.0
                                    enabled: !projectItem.isLoading && (projectItem.isRunning || projectItem.isStarting)
                                    icon.name: "media-playback-stop"
                                    icon.color: Kirigami.Theme.negativeTextColor
                                    flat: true
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    onClicked: {
                                        projectItem.isStarting = false
                                        projectItem.isLoading = true
                                        projectItem.isExpanded = false
                                        startupTimeoutTimer.stop()
                                        executable.exec("sh -c \"" + projectItem.dockerComposeBase() + " down\"")
                                    }
                                    PlasmaComponents.ToolTip { text: "Detener Docker" }
                                }
                            }

                            // Pull images
                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isStarting
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "edit-download"
                                flat: true
                                onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " pull\"")
                                PlasmaComponents.ToolTip { text: "Actualizar imágenes" }
                            }

                            // Compose file selector
                            PlasmaComponents.ToolButton {
                                id: composeBtn
                                visible: dockerFiles.count > 1 && !projectItem.isLoading && !projectItem.isStarting
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "document-open"
                                flat: true
                                onClicked: composeMenu.popup()
                                PlasmaComponents.ToolTip {
                                    text: projectItem.composeFileNames.length > 0
                                        ? projectItem.composeFileNames[projectItem.selectedComposeIndex]
                                        : "Seleccionar compose"
                                }

                                PlasmaComponents.Menu {
                                    id: composeMenu
                                    Repeater {
                                        model: projectItem.composeFileNames
                                        PlasmaComponents.MenuItem {
                                            text: modelData
                                            checkable: true
                                            checked: index === projectItem.selectedComposeIndex
                                            onTriggered: {
                                                if (projectItem.selectedComposeIndex !== index) {
                                                    projectItem.selectedComposeIndex = index
                                                    projectItem.isExpanded = false
                                                    projectItem.isRunning = false
                                                    projectItem.checkStatus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Remove project
                            PlasmaComponents.ToolButton {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "list-remove"
                                flat: true
                                onClicked: root.removeProject(projectIndex)
                                PlasmaComponents.ToolTip { text: "Eliminar proyecto" }
                            }
                        }

                        // Container tree
                        Column {
                            visible: projectItem.isExpanded && (projectItem.isRunning || projectItem.isStarting)
                            width: parent.width

                            // Placeholder while starting and no containers fetched yet
                            PlasmaComponents.Label {
                                visible: projectItem.isStarting && projectItem.containerList.length === 0
                                width: parent.width
                                leftPadding: Kirigami.Units.gridUnit * 1.5 + Kirigami.Units.smallSpacing
                                topPadding: Kirigami.Units.smallSpacing
                                bottomPadding: Kirigami.Units.smallSpacing
                                text: "Iniciando servicios..."
                                opacity: 0.6
                                font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            }

                            Repeater {
                                model: projectItem.containerList

                                delegate: RowLayout {
                                    width: parent ? parent.width : 0
                                    spacing: Kirigami.Units.smallSpacing

                                    Item { Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2 }

                                    // Status dot: pulsing while starting, solid when settled
                                    Rectangle {
                                        id: statusDot
                                        width: 7
                                        height: 7
                                        radius: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        property bool isSettled: modelData.state === "running" ||
                                                                  modelData.state === "exited"  ||
                                                                  modelData.state === "dead"
                                        property bool isPending: projectItem.isStarting && !isSettled

                                        color: isPending
                                            ? Kirigami.Theme.neutralTextColor
                                            : modelData.state === "running"
                                                ? Kirigami.Theme.positiveTextColor
                                                : modelData.state === "exited" || modelData.state === "dead"
                                                    ? Kirigami.Theme.negativeTextColor
                                                    : Kirigami.Theme.textColor

                                        opacity: isSettled ? 1.0 : isPending ? 1.0 : 0.5

                                        SequentialAnimation on opacity {
                                            running: statusDot.isPending
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    PlasmaComponents.Label {
                                        text: modelData.service
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        opacity: statusDot.isPending ? 0.6 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }

                                    PlasmaComponents.Label {
                                        text: root.extractFirstPort(modelData.ports)
                                        visible: text.length > 0
                                        opacity: 0.6
                                        font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "utilities-terminal"
                                        flat: true
                                        visible: !statusDot.isPending
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " logs -f " + modelData.service + "\"")
                                        PlasmaComponents.ToolTip { text: "Ver logs" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "system-reboot"
                                        flat: true
                                        visible: !statusDot.isPending
                                        onClicked: {
                                            projectItem.isLoading = true
                                            executable.exec("sh -c \"" + projectItem.dockerComposeBase() + " restart " + modelData.service + "\"")
                                        }
                                        PlasmaComponents.ToolTip { text: "Reiniciar" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "run-build"
                                        flat: true
                                        visible: !statusDot.isPending
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " build " + modelData.service + "\"")
                                        PlasmaComponents.ToolTip { text: "Construir imagen" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "application-x-shellscript"
                                        flat: true
                                        visible: !statusDot.isPending && modelData.state === "running"
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' -e sh -c \"" + projectItem.dockerComposeBase() + " exec " + modelData.service + " sh\"")
                                        PlasmaComponents.ToolTip { text: "Abrir terminal" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "internet-web-browser"
                                        flat: true
                                        visible: !statusDot.isPending && modelData.state === "running" && modelData.ports.length > 0
                                        onClicked: {
                                            var re = /:(\d+)->/
                                            var m = re.exec(modelData.ports)
                                            if (m) Qt.openUrlExternally("http://localhost:" + m[1])
                                        }
                                        PlasmaComponents.ToolTip { text: "Abrir en navegador" }
                                    }
                                }
                            }

                            Item { width: 1; height: Kirigami.Units.smallSpacing }
                        }

                        Kirigami.Separator {
                            width: parent.width
                            opacity: 0.3
                        }
                    }
                }
            }
        }
    }
}
