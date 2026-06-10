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

    property var editorOptions: {
        var list = Plasmoid.configuration.editorsList
        if (!list || list.length === 0) return [
            { name: "VS Code", cmd: "code --new-window", icon: "code" },
            { name: "Kate",    cmd: "kate",               icon: "kate" },
            { name: "Vim",     cmd: "konsole -e vim",     icon: "utilities-terminal" }
        ]
        return list.map(function(e) {
            var p = e.split("|")
            return { name: p[0] || "", cmd: p[1] || "", icon: p[2] || "document-edit" }
        })
    }

    function openProject(projectPath, editorCmd) {
        executable.exec((editorCmd || "code --new-window") + " '" + projectPath + "'")
    }

    function projectName(path) {
        return path.split("/").filter(s => s.length > 0).pop() || path
    }

    function addProject(path) {
        var list = Plasmoid.configuration.projects.slice()
        if (list.indexOf(path) < 0) {
            list.push(path)
            Plasmoid.configuration.projects = list
            var editors = Plasmoid.configuration.projectEditors.slice()
            editors.push("code --new-window")
            Plasmoid.configuration.projectEditors = editors
        }
    }

    function removeProject(idx) {
        var list = Plasmoid.configuration.projects.slice()
        list.splice(idx, 1)
        Plasmoid.configuration.projects = list
        var editors = Plasmoid.configuration.projectEditors.slice()
        editors.splice(idx, 1)
        Plasmoid.configuration.projectEditors = editors
    }

    function moveProject(from, to) {
        if (from === to) return
        var projects = Plasmoid.configuration.projects.slice()
        var editors  = Plasmoid.configuration.projectEditors.slice()
        var p = projects.splice(from, 1)[0]
        var e = editors.splice(from, 1)[0]
        projects.splice(to, 0, p)
        editors.splice(to, 0, e)
        Plasmoid.configuration.projects      = projects
        Plasmoid.configuration.projectEditors = editors
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
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRep
        spacing: 0

        Layout.minimumWidth:   Kirigami.Units.gridUnit * 22
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight:  Kirigami.Units.gridUnit * 10
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28

        property string searchText: ""
        property bool   searchVisible: false
        property bool   dragEnabled:     false
        property int    draggedIndex:    -1
        property int    dropTargetIndex: -1

        onDragEnabledChanged: {
            if (!dragEnabled) { draggedIndex = -1; dropTargetIndex = -1 }
        }

        property var filteredProjects: {
            var q        = searchText.toLowerCase()
            var projects = Plasmoid.configuration.projects
            var result   = []
            for (var i = 0; i < projects.length; i++) {
                var name = root.projectName(projects[i]).toLowerCase()
                if (q === "" || name.indexOf(q) >= 0)
                    result.push({ path: projects[i], origIndex: i })
            }
            return result
        }

        // ── Header ──────────────────────────────────────────────────────────
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: "code-context"
                        Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    PlasmaExtras.Heading {
                        text: "Proyectos"
                        level: 3
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "search"
                        flat: true
                        checkable: true
                        checked: fullRep.searchVisible
                        onClicked: {
                            fullRep.searchVisible = !fullRep.searchVisible
                            if (!fullRep.searchVisible) fullRep.searchText = ""
                            else searchField.forceActiveFocus()
                        }
                        PlasmaComponents.ToolTip { text: "Buscar proyecto" }
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "transform-move"
                        flat: true
                        checkable: true
                        checked: fullRep.dragEnabled
                        onClicked: fullRep.dragEnabled = !fullRep.dragEnabled
                        PlasmaComponents.ToolTip { text: "Reordenar proyectos" }
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "list-add"
                        flat: true
                        onClicked: folderDialog.open()
                        PlasmaComponents.ToolTip { text: "Añadir proyecto" }
                    }
                }

                PlasmaComponents.TextField {
                    id: searchField
                    visible: fullRep.searchVisible
                    Layout.fillWidth: true
                    placeholderText: "Buscar proyecto..."
                    onTextChanged: fullRep.searchText = text
                    Keys.onEscapePressed: {
                        fullRep.searchVisible = false
                        fullRep.searchText    = ""
                    }
                }
            }
        }

        // ── Empty states ────────────────────────────────────────────────────
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Plasmoid.configuration.projects.length > 0 && fullRep.filteredProjects.length === 0

            PlasmaComponents.Label {
                anchors.centerIn: parent
                text: "Sin resultados."
                opacity: 0.5
            }
        }

        // ── Project list ─────────────────────────────────────────────────────
        PlasmaComponents.ScrollView {
            id: projectsScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: fullRep.filteredProjects.length > 0

            Column {
                id: projectsColumn
                width: projectsScrollView.availableWidth

                Repeater {
                    id: projectsRepeater
                    model: fullRep.filteredProjects

                    delegate: Column {
                        id: projectItem
                        width: parent ? parent.width : 0

                        property string projectPath: modelData.path
                        property int    origIndex:   modelData.origIndex

                        property bool isRunning:  false
                        property bool isLoading:  false
                        property bool isStarting: false
                        property bool isExpanded: false
                        property var  containerList: []

                        property var composeFilePaths:     []
                        property var composeFileNames:     []
                        property int selectedComposeIndex: 0

                        property string currentEditor: {
                            var editors = Plasmoid.configuration.projectEditors
                            return (editors && editors.length > origIndex) ? editors[origIndex] : "code --new-window"
                        }

                        // ── Helpers ──────────────────────────────────────────
                        function setEditor(cmd) {
                            var editors = Plasmoid.configuration.projectEditors.slice()
                            while (editors.length <= origIndex) editors.push("code --new-window")
                            editors[origIndex] = cmd
                            Plasmoid.configuration.projectEditors = editors
                        }

                        function dockerComposeBase() {
                            if (composeFilePaths.length > 0)
                                return "docker compose -f '" + composeFilePaths[selectedComposeIndex] + "'"
                            return "docker compose --project-directory '" + projectPath + "'"
                        }

                        // ── Data sources ─────────────────────────────────────
                        FolderListModel {
                            id: dockerFiles
                            folder: "file://" + projectPath
                            showFiles: true
                            showDirs: false
                            nameFilters: ["docker-compose*.yml", "docker-compose*.yaml", "compose*.yml", "compose*.yaml"]
                            onCountChanged: {
                                if (count === 0) return
                                var names = [], paths = []
                                for (var i = 0; i < count; i++) {
                                    names.push(dockerFiles.get(i, "fileName"))
                                    paths.push(dockerFiles.get(i, "filePath"))
                                }
                                projectItem.composeFileNames     = names
                                projectItem.composeFilePaths     = paths
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
                            id: downSource
                            engine: "executable"
                            connectedSources: []
                            onNewData: (sourceName) => {
                                disconnectSource(sourceName)
                                projectItem.checkStatus()
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
                                            state:   parts[1].trim(),
                                            ports:   parts.length > 2 ? parts[2].trim() : ""
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
                                        projectItem.isRunning = containers.some(function(c) { return c.state === "running" })
                                    }
                                }
                            }
                        }

                        function checkStatus() {
                            statusSource.connectSource(dockerComposeBase() + " ps --status running -q 2>/dev/null")
                        }

                        function fetchContainers() {
                            containersSource.connectSource(dockerComposeBase() + " ps --format '{{.Service}}|{{.State}}|{{.Ports}}' 2>/dev/null")
                        }

                        // ── Timers ────────────────────────────────────────────
                        Timer {
                            id: refreshTimer
                            interval: 3000
                            repeat: true
                            running: root.expanded && dockerFiles.count > 0 && !projectItem.isStarting && !projectItem.isLoading
                            onTriggered: {
                                projectItem.checkStatus()
                                if (projectItem.isExpanded) projectItem.fetchContainers()
                            }
                        }

                        Timer {
                            id: startupPollTimer
                            interval: 1000
                            repeat: true
                            running: projectItem.isStarting
                            onTriggered: projectItem.fetchContainers()
                        }

                        Timer {
                            id: startupTimeoutTimer
                            interval: 60000
                            repeat: false
                            onTriggered: {
                                projectItem.isStarting = false
                                projectItem.isRunning  = projectItem.containerList.some(function(c) { return c.state === "running" })
                            }
                        }

                        Connections {
                            target: root
                            function onExpandedChanged() {
                                if (root.expanded) {
                                    if (dockerFiles.count > 0 && !projectItem.isStarting)
                                        projectItem.checkStatus()
                                } else {
                                    editorMenu.close()
                                    fullRep.draggedIndex    = -1
                                    fullRep.dropTargetIndex = -1
                                }
                            }
                        }

                        // ── Drop indicator (top) ──────────────────────────────
                        Rectangle {
                            visible: fullRep.dragEnabled &&
                                     fullRep.draggedIndex !== -1 &&
                                     fullRep.dropTargetIndex === origIndex &&
                                     fullRep.draggedIndex !== origIndex
                            width: parent.width
                            height: 2
                            color: Kirigami.Theme.highlightColor
                            z: 1
                        }

                        // ── Project row ───────────────────────────────────────
                        RowLayout {
                            width: parent.width
                            spacing: 0
                            opacity: fullRep.draggedIndex === origIndex ? 0.3 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            // Drag handle
                            Item {
                                visible: fullRep.dragEnabled && fullRep.searchText === ""
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                Layout.alignment: Qt.AlignVCenter

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    opacity: dragHandleArea.containsMouse ? 0.7 : 0.3
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 4; height: 4; radius: 2
                                            color: Kirigami.Theme.textColor
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dragHandleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    acceptedButtons: Qt.LeftButton

                                    onPressed: (mouse) => {
                                        fullRep.draggedIndex    = origIndex
                                        fullRep.dropTargetIndex = origIndex
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        var globalY = dragHandleArea.mapToGlobal(mouse.x, mouse.y).y
                                        var count   = projectsRepeater.count
                                        var newTarget = count  // sentinel = drop at end
                                        for (var i = 0; i < count; i++) {
                                            var item = projectsRepeater.itemAt(i)
                                            if (!item) continue
                                            var mid = item.mapToGlobal(0, 0).y + item.height / 2
                                            if (globalY < mid) {
                                                newTarget = item.origIndex
                                                break
                                            }
                                        }
                                        fullRep.dropTargetIndex = newTarget
                                    }

                                    onReleased: {
                                        var from = fullRep.draggedIndex
                                        var drop = fullRep.dropTargetIndex
                                        var n    = Plasmoid.configuration.projects.length
                                        if (from !== -1 && drop !== -1 && from !== drop) {
                                            var to = (from < drop) ? drop - 1 : drop
                                            to = Math.max(0, Math.min(to, n - 1))
                                            root.moveProject(from, to)
                                        }
                                        fullRep.draggedIndex    = -1
                                        fullRep.dropTargetIndex = -1
                                    }
                                }
                            }

                            PlasmaComponents.ItemDelegate {
                                Layout.fillWidth: true
                                icon.name: {
                                    var opt = root.editorOptions.find(e => e.cmd === projectItem.currentEditor)
                                    return opt ? opt.icon : "code-context"
                                }
                                text: root.projectName(projectPath)
                                onClicked: {
                                    root.openProject(projectPath, projectItem.currentEditor)
                                    root.expanded = false
                                }
                            }

                            // Expand/collapse tree
                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0 && projectItem.isRunning && !projectItem.isLoading
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
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
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
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
                                        projectItem.isRunning  = true
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
                                        projectItem.isLoading  = true
                                        projectItem.isExpanded = false
                                        startupTimeoutTimer.stop()
                                        downSource.connectSource("sh -c \"" + projectItem.dockerComposeBase() + " down\"")
                                    }
                                    PlasmaComponents.ToolTip { text: "Detener Docker" }
                                }
                            }

                            // Pull images
                            PlasmaComponents.ToolButton {
                                visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isStarting
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
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
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
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
                                                    projectItem.isRunning  = false
                                                    projectItem.checkStatus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Editor selector
                            PlasmaComponents.ToolButton {
                                id: editorBtn
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                flat: true
                                icon.name: "document-edit"
                                onClicked: editorMenu.popup()
                                PlasmaComponents.ToolTip {
                                    text: {
                                        var opt = root.editorOptions.find(e => e.cmd === projectItem.currentEditor)
                                        return "Editor: " + (opt ? opt.name : projectItem.currentEditor)
                                    }
                                }
                                PlasmaComponents.Menu {
                                    id: editorMenu
                                    Repeater {
                                        model: root.editorOptions
                                        PlasmaComponents.MenuItem {
                                            text: modelData.name
                                            checkable: true
                                            checked: projectItem.currentEditor === modelData.cmd
                                            onTriggered: projectItem.setEditor(modelData.cmd)
                                        }
                                    }
                                }
                            }

                            // Remove project
                            PlasmaComponents.ToolButton {
                                Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.5
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                Layout.alignment: Qt.AlignVCenter
                                icon.name: "list-remove"
                                flat: true
                                onClicked: root.removeProject(origIndex)
                                PlasmaComponents.ToolTip { text: "Eliminar proyecto" }
                            }
                        }

                        // ── Container tree ────────────────────────────────────
                        Column {
                            visible: projectItem.isExpanded && (projectItem.isRunning || projectItem.isStarting)
                            width: parent.width

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

                                    Rectangle {
                                        id: statusDot
                                        width: 7; height: 7; radius: 4
                                        Layout.alignment: Qt.AlignVCenter

                                        property bool isSettled: modelData.state === "running" || modelData.state === "exited" || modelData.state === "dead"
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
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "utilities-terminal"
                                        flat: true
                                        visible: !statusDot.isPending
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " logs -f " + modelData.service + "\"")
                                        PlasmaComponents.ToolTip { text: "Ver logs" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
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
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "run-build"
                                        flat: true
                                        visible: !statusDot.isPending
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " build " + modelData.service + "\"")
                                        PlasmaComponents.ToolTip { text: "Construir imagen" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "application-x-shellscript"
                                        flat: true
                                        visible: !statusDot.isPending && modelData.state === "running"
                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' -e sh -c \"" + projectItem.dockerComposeBase() + " exec " + modelData.service + " sh\"")
                                        PlasmaComponents.ToolTip { text: "Abrir terminal" }
                                    }

                                    PlasmaComponents.ToolButton {
                                        Layout.preferredWidth:  Kirigami.Units.gridUnit * 1.4
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                                        icon.name: "internet-web-browser"
                                        flat: true
                                        visible: !statusDot.isPending && modelData.state === "running" && modelData.ports.length > 0
                                        onClicked: {
                                            var m = /:(\d+)->/.exec(modelData.ports)
                                            if (m) Qt.openUrlExternally("http://localhost:" + m[1])
                                        }
                                        PlasmaComponents.ToolTip { text: "Abrir en navegador" }
                                    }
                                }
                            }

                            Item { width: 1; height: Kirigami.Units.smallSpacing }
                        }

                        Kirigami.Separator { width: parent.width; opacity: 0.3 }

                        // Drop indicator bottom (after last item)
                        Rectangle {
                            visible: fullRep.dragEnabled &&
                                     fullRep.draggedIndex !== -1 &&
                                     fullRep.dropTargetIndex === Plasmoid.configuration.projects.length &&
                                     origIndex === Plasmoid.configuration.projects.length - 1
                            width: parent.width
                            height: 2
                            color: Kirigami.Theme.highlightColor
                        }
                    }
                }
            }
        }
    }
}
