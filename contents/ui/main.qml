import QtQuick
import QtQuick.Layouts
import QtQuick.Controls 2.0 as QQC2
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

    // ── Theme ──────────────────────────────────────────────────────────────
    readonly property color clrBg:     "#c0c0c0"
    readonly property color clrCard:   "#d4d4d4"
    readonly property color clrHdr:    "#111111"
    readonly property color clrBorder: "#111111"
    readonly property color clrGreen:  "#00ff00"
    readonly property color clrText:   "#111111"
    readonly property color clrSub:    "#333333"
    readonly property color clrMuted:  "#666666"
    readonly property color clrBtn:    "#b8b8b8"
    readonly property string mono:     "Courier New"
    // font sizes
    readonly property int fzTiny:   8
    readonly property int fzSmall:  9
    readonly property int fzNormal: 10
    readonly property int fzLarge:  13

    // ── DataSource ─────────────────────────────────────────────────────────
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
        Plasmoid.configuration.projects       = projects
        Plasmoid.configuration.projectEditors = editors
    }
    function extractFirstPort(portsStr) {
        if (!portsStr || portsStr.length === 0) return ""
        var seen = {}, ports = [], re = /:(\d+)->/g, m
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

    // ── Compact ────────────────────────────────────────────────────────────
    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.centerIn: parent
            source: "code-context"
            width: Math.min(parent.width, parent.height) * 0.85
            height: width
            opacity: parent.containsMouse ? 0.7 : 1.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }

    // ── Full representation ────────────────────────────────────────────────
    fullRepresentation: Rectangle {
        id: fullRep
        color: root.clrBg

        Layout.minimumWidth:   Kirigami.Units.gridUnit * 28
        Layout.preferredWidth: Kirigami.Units.gridUnit * 30
        Layout.minimumHeight:  Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 36

        property string searchText: ""
        property bool   searchVisible:         false
        property bool   dragEnabled:           false
        property bool   deleteEnabled:         false
        property bool   editorSelectorEnabled: false
        property int    draggedIndex:    -1
        property int    dropTargetIndex: -1

        onDragEnabledChanged: {
            if (!dragEnabled) { draggedIndex = -1; dropTargetIndex = -1 }
        }

        property var filteredProjects: {
            var q = searchText.toLowerCase()
            var projects = Plasmoid.configuration.projects
            var result = []
            for (var i = 0; i < projects.length; i++) {
                var name = root.projectName(projects[i]).toLowerCase()
                if (q === "" || name.indexOf(q) >= 0)
                    result.push({ path: projects[i], origIndex: i })
            }
            return result
        }

        // Shared running-state map: origIndex → bool. Each project card writes here.
        property var projectRunningStates: ({})

        function setProjectRunning(idx, val) {
            var s = Object.assign({}, projectRunningStates)  // new object → QML detects change
            s[idx] = val
            projectRunningStates = s
        }

        property int runningCount: {
            var n = 0
            var keys = Object.keys(projectRunningStates)
            for (var i = 0; i < keys.length; i++) if (projectRunningStates[keys[i]]) n++
            return n
        }
        property int offlineCount: {
            return Math.max(0, Plasmoid.configuration.projects.length - runningCount)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── HEADER ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 76
                color: root.clrCard

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 2
                    color: root.clrBorder
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 0

                    // Barcode + title
                    Row {
                        spacing: 6
                        Layout.fillWidth: true

                        // Barcode
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Row {
                                spacing: 0
                                property var bars: [2,1,4,1,2,1,3,1,2,4,1,2,1,3,2,1]
                                Repeater {
                                    model: parent.bars.length
                                    Rectangle {
                                        width: parent.parent.bars[index]; height: 34
                                        color: index % 2 === 0 ? root.clrHdr : "transparent"
                                    }
                                }
                            }
                            Text {
                                text: "1 04-52-900"
                                font.family: root.mono; font.pixelSize: 7
                                color: root.clrSub
                            }
                        }

                        // Title
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text {
                                text: "DEV PROJECTS"
                                font.family: root.mono; font.pixelSize: 15
                                font.bold: true; font.letterSpacing: 2
                                color: root.clrText
                            }
                            Text {
                                text: "PLASMA WIDGET  //  PROJECT LAUNCHER"
                                font.family: root.mono; font.pixelSize: 10
                                font.letterSpacing: 1; color: root.clrSub
                            }
                        }
                    }

                    // Stats dividers
                    Rectangle { width: 1; Layout.fillHeight: true; color: root.clrBorder; opacity: 0.3 }

                    Column {
                        width: 58; Layout.fillHeight: true
                        leftPadding: 8
                        spacing: 2
                        Item { height: 10 }
                        Text { text: "TOTAL"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1; font.bold: true; color: root.clrSub }
                        Text {
                            text: Plasmoid.configuration.projects.length.toString().padStart(2, "0")
                            font.family: root.mono; font.pixelSize: 26; font.bold: true; font.letterSpacing: 2
                            color: root.clrText
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: root.clrBorder; opacity: 0.3 }

                    Column {
                        width: 82; Layout.fillHeight: true
                        leftPadding: 8
                        spacing: 2
                        Item { height: 10 }
                        Text { text: "RUNNING"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1; font.bold: true; color: root.clrSub }
                        Rectangle {
                            width: 52; height: 32; color: root.clrGreen
                            Text {
                                anchors.centerIn: parent
                                text: fullRep.runningCount.toString().padStart(2, "0")
                                font.family: root.mono; font.pixelSize: 22; font.bold: true; color: "#000"
                            }
                        }
                    }

                    Rectangle { width: 1; Layout.fillHeight: true; color: root.clrBorder; opacity: 0.3 }

                    Column {
                        width: 52; Layout.fillHeight: true
                        leftPadding: 8
                        spacing: 2
                        Item { height: 10 }
                        Text { text: "OFF"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1; font.bold: true; color: root.clrSub }
                        Text {
                            text: fullRep.offlineCount.toString().padStart(2, "0")
                            font.family: root.mono; font.pixelSize: 26; font.bold: true; font.letterSpacing: 2
                            color: root.clrMuted
                        }
                    }
                }
            }

            // ── TOOLBAR ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "#cacaca"

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.clrBorder }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "⌕ SRCH",  tip: "Buscar proyecto",    prop: "searchVisible"        },
                            { label: "⇅ MOVE",  tip: "Reordenar",          prop: "dragEnabled"          },
                            { label: "✎ EDIT",  tip: "Selector de editor", prop: "editorSelectorEnabled" },
                            { label: "✕ DEL",   tip: "Eliminar proyectos", prop: "deleteEnabled"        }
                        ]
                        delegate: Rectangle {
                            Layout.preferredWidth: 72; Layout.preferredHeight: 26
                            property bool active: fullRep[modelData.prop]
                            color:        active ? (modelData.label === "✕ DEL" ? "#cc2200" : root.clrGreen) : root.clrBtn
                            border.color: root.clrBorder; border.width: 1.5
                            Text {
                                anchors.centerIn: parent
                                text:  modelData.label
                                font.family: root.mono; font.pixelSize: 11; font.bold: true
                                color: active ? (modelData.label === "✕ DEL" ? "#fff" : "#000") : root.clrText
                            }
                            HoverHandler { id: toolbarHov }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var newVal = !fullRep[modelData.prop]
                                    fullRep[modelData.prop] = newVal
                                    if (modelData.prop === "searchVisible") {
                                        if (!newVal) fullRep.searchText = ""
                                        else searchField.forceActiveFocus()
                                    }
                                }
                            }
                            PlasmaComponents.ToolTip { text: modelData.tip; visible: toolbarHov.hovered }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 72; Layout.preferredHeight: 26
                        color: root.clrGreen; border.color: root.clrBorder; border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: "+ ADD"; font.family: root.mono; font.pixelSize: 11; font.bold: true; color: "#000"
                        }
                        HoverHandler { id: addHov }
                        MouseArea { anchors.fill: parent; onClicked: folderDialog.open() }
                        PlasmaComponents.ToolTip { text: "Añadir proyecto"; visible: addHov.hovered }
                    }
                }
            }

            // ── SEARCH FIELD ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: fullRep.searchVisible ? 30 : 0
                visible: fullRep.searchVisible
                color: "#b8b8b8"
                border.color: root.clrBorder; border.width: 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 6

                    Text { text: "⌕"; font.family: root.mono; font.pixelSize: 13; color: root.clrSub }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 1
                        color: root.clrText
                        onTextChanged: fullRep.searchText = text
                        Keys.onEscapePressed: {
                            fullRep.searchVisible = false
                            fullRep.searchText    = ""
                            text = ""
                        }
                    }

                    Text {
                        text: "ESC"
                        font.family: root.mono; font.pixelSize: 7; font.letterSpacing: 1
                        color: root.clrMuted
                    }
                }
            }

            // ── EMPTY STATES ─────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: Plasmoid.configuration.projects.length === 0
                Column {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "NO PROJECTS"
                        font.family: root.mono; font.pixelSize: 12; font.bold: true; font.letterSpacing: 3
                        color: root.clrMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "PRESS + ADD TO BEGIN"
                        font.family: root.mono; font.pixelSize: 8; font.letterSpacing: 2
                        color: root.clrMuted
                    }
                }
            }

            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: Plasmoid.configuration.projects.length > 0 && fullRep.filteredProjects.length === 0
                Text {
                    anchors.centerIn: parent
                    text: "NO RESULTS"
                    font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3
                    color: root.clrMuted
                }
            }

            // ── PROJECT LIST ─────────────────────────────────────────────────
            PlasmaComponents.ScrollView {
                id: projectsScrollView
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                visible: fullRep.filteredProjects.length > 0

                Column {
                    width: projectsScrollView.availableWidth
                    spacing: 6
                    topPadding: 6; bottomPadding: 6

                    Repeater {
                        id: projectsRepeater
                        model: fullRep.filteredProjects

                        delegate: Column {
                            id: projectItem
                            width: parent ? parent.width - 12 : 0
                            x: 6

                            property string projectPath: modelData.path
                            property int    origIndex:   modelData.origIndex

                            property bool isRunning:  false
                            property bool isLoading:  false
                            property bool isStarting: false
                            property bool isExpanded: false
                            property var  containerList: []

                            onIsRunningChanged:  fullRep.setProjectRunning(origIndex, isRunning || isStarting)
                            onIsStartingChanged: fullRep.setProjectRunning(origIndex, isRunning || isStarting)

                            property var composeFilePaths:     []
                            property var composeFileNames:     []
                            property int selectedComposeIndex: 0

                            property string currentEditor: {
                                var editors = Plasmoid.configuration.projectEditors
                                return (editors && editors.length > origIndex) ? editors[origIndex] : "code --new-window"
                            }

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

                            // ── Data sources ──────────────────────────────────
                            FolderListModel {
                                id: dockerFiles
                                folder: "file://" + projectPath
                                showFiles: true; showDirs: false
                                nameFilters: ["docker-compose*.yml","docker-compose*.yaml","compose*.yml","compose*.yaml"]
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
                                engine: "executable"; connectedSources: []
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
                                engine: "executable"; connectedSources: []
                                onNewData: (sourceName) => {
                                    disconnectSource(sourceName)
                                    projectItem.checkStatus()
                                }
                            }

                            P5Support.DataSource {
                                id: containersSource
                                engine: "executable"; connectedSources: []
                                onNewData: (sourceName, data) => {
                                    var lines = data["stdout"].trim().split("\n").filter(l => l.length > 0)
                                    var containers = []
                                    for (var i = 0; i < lines.length; i++) {
                                        var parts = lines[i].split("|")
                                        if (parts.length >= 2)
                                            containers.push({ service: parts[0].trim(), state: parts[1].trim(), ports: parts.length > 2 ? parts[2].trim() : "" })
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

                            // ── Timers ────────────────────────────────────────
                            Timer {
                                id: refreshTimer; interval: 3000; repeat: true
                                running: root.expanded && dockerFiles.count > 0 && !projectItem.isStarting && !projectItem.isLoading
                                onTriggered: { projectItem.checkStatus(); if (projectItem.isExpanded) projectItem.fetchContainers() }
                            }
                            Timer {
                                id: startupPollTimer; interval: 1000; repeat: true
                                running: projectItem.isStarting
                                onTriggered: projectItem.fetchContainers()
                            }
                            Timer {
                                id: startupTimeoutTimer; interval: 60000; repeat: false
                                onTriggered: {
                                    projectItem.isStarting = false
                                    projectItem.isRunning  = projectItem.containerList.some(function(c) { return c.state === "running" })
                                }
                            }

                            Connections {
                                target: root
                                function onExpandedChanged() {
                                    if (root.expanded) {
                                        if (dockerFiles.count > 0 && !projectItem.isStarting) projectItem.checkStatus()
                                    } else {
                                        editorMenu.close(); composeMenu.close()
                                        fullRep.draggedIndex = -1; fullRep.dropTargetIndex = -1
                                    }
                                }
                            }

                            // Drop indicator top
                            Rectangle {
                                visible: fullRep.dragEnabled && fullRep.draggedIndex !== -1 &&
                                         fullRep.dropTargetIndex === origIndex && fullRep.draggedIndex !== origIndex
                                width: parent.width; height: 3; color: root.clrGreen
                            }

                            // ── CARD ──────────────────────────────────────────
                            Rectangle {
                                width: parent.width
                                height: cardCol.implicitHeight
                                color: root.clrCard
                                border.color: root.clrBorder
                                border.width: projectItem.isRunning || projectItem.isStarting ? 2 : 1
                                opacity: fullRep.draggedIndex === origIndex ? 0.3 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                // Green left accent when running
                                Rectangle {
                                    visible: projectItem.isRunning || projectItem.isStarting
                                    x: 0; y: 0; width: 5; height: parent.height
                                    color: root.clrGreen
                                    z: 1
                                }

                                Column {
                                    id: cardCol
                                    width: parent.width

                                    // ── Card header bar ───────────────────────
                                    Rectangle {
                                        width: parent.width; height: 30
                                        color: root.clrHdr

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            // Drag handle
                                            Item {
                                                visible: fullRep.dragEnabled && fullRep.searchText === ""
                                                Layout.preferredWidth: 18; Layout.fillHeight: true

                                                Column {
                                                    anchors.centerIn: parent; spacing: 3
                                                    Repeater {
                                                        model: 3
                                                        Rectangle {
                                                            width: 14; height: 2
                                                            color: dragArea.containsMouse ? root.clrGreen : "#555"
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    id: dragArea; anchors.fill: parent
                                                    hoverEnabled: true; preventStealing: true
                                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                                    onPressed: { fullRep.draggedIndex = origIndex; fullRep.dropTargetIndex = origIndex }
                                                    onPositionChanged: (mouse) => {
                                                        if (!pressed) return
                                                        var gy = dragArea.mapToGlobal(mouse.x, mouse.y).y
                                                        var n  = projectsRepeater.count
                                                        var newTarget = n
                                                        for (var i = 0; i < n; i++) {
                                                            var itm = projectsRepeater.itemAt(i)
                                                            if (!itm) continue
                                                            if (gy < itm.mapToGlobal(0, 0).y + itm.height / 2) { newTarget = itm.origIndex; break }
                                                        }
                                                        fullRep.dropTargetIndex = newTarget
                                                    }
                                                    onReleased: {
                                                        var from = fullRep.draggedIndex, drop = fullRep.dropTargetIndex
                                                        var n = Plasmoid.configuration.projects.length
                                                        if (from !== -1 && drop !== -1 && from !== drop) {
                                                            var to = Math.max(0, Math.min((from < drop) ? drop - 1 : drop, n - 1))
                                                            root.moveProject(from, to)
                                                        }
                                                        fullRep.draggedIndex = -1; fullRep.dropTargetIndex = -1
                                                    }
                                                }
                                            }

                                            // PROJECT_ID nombre
                                            Text {
                                                Layout.fillWidth: true
                                                text: "PROJECT_ID  " + root.projectName(projectPath).toUpperCase()
                                                font.family: root.mono; font.pixelSize: 10
                                                font.bold: true; font.letterSpacing: 2
                                                color: "#ffffff"
                                                elide: Text.ElideRight
                                            }

                                            // Status badge
                                            Rectangle {
                                                Layout.preferredWidth: badgeTxt.implicitWidth + 20
                                                Layout.preferredHeight: 20
                                                color: projectItem.isRunning || projectItem.isStarting ? root.clrGreen : "#444444"
                                                border.color: projectItem.isRunning || projectItem.isStarting ? root.clrGreen : "#666666"
                                                border.width: 1
                                                Text {
                                                    id: badgeTxt
                                                    anchors.centerIn: parent
                                                    text: projectItem.isStarting ? "◌ STARTING" :
                                                          projectItem.isRunning  ? "■ RUNNING"  :
                                                          projectItem.isLoading  ? "◌ LOADING"  : "● OFFLINE"
                                                    font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                                                    color: projectItem.isRunning || projectItem.isStarting ? "#000000" : "#888888"
                                                }
                                            }

                                            // Expand toggle
                                            Rectangle {
                                                visible: dockerFiles.count > 0 && (projectItem.isRunning || projectItem.isStarting)
                                                Layout.preferredWidth: 22; Layout.preferredHeight: 20
                                                color: "transparent"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: projectItem.isExpanded ? "▲" : "▼"
                                                    font.family: root.mono; font.pixelSize: 11; color: "#aaaaaa"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        projectItem.isExpanded = !projectItem.isExpanded
                                                        if (projectItem.isExpanded) projectItem.fetchContainers()
                                                    }
                                                }
                                            }
                                        }

                                    }

                                    // ── Card body ─────────────────────────────
                                    Item {
                                        width: parent.width
                                        implicitHeight: bodyLayout.implicitHeight + 16

                                        RowLayout {
                                            id: bodyLayout
                                            x: 14; y: 8
                                            width: parent.width - 20
                                            spacing: 8

                                            // Info column (izquierda)
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignTop
                                                spacing: 6

                                                // PATH
                                                RowLayout {
                                                    spacing: 6
                                                    Text {
                                                        text: "PATH"; Layout.preferredWidth: 60
                                                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2
                                                        font.weight: Font.ExtraBold; color: root.clrText
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: projectPath.replace(/^\/home\/[^/]+/, "~")
                                                        font.family: root.mono; font.pixelSize: 11; font.bold: true; color: root.clrText
                                                        elide: Text.ElideMiddle
                                                    }
                                                }

                                                // STATUS BAR
                                                RowLayout {
                                                    spacing: 6
                                                    Text {
                                                        text: "STATUS"; Layout.preferredWidth: 60
                                                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2
                                                        font.weight: Font.ExtraBold; color: root.clrText
                                                    }
                                                    Rectangle {
                                                        Layout.fillWidth: true; Layout.preferredHeight: 12
                                                        color: "#888888"; border.color: "#555555"; border.width: 1
                                                        Rectangle {
                                                            x: 1; y: 1
                                                            height: parent.height - 2
                                                            color: projectItem.isRunning || projectItem.isStarting ? root.clrGreen : "#666666"
                                                            width: projectItem.isRunning  ? parent.width - 2 :
                                                                   projectItem.isStarting ? (parent.width - 2) * 0.45 : 0
                                                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                                                        }
                                                    }
                                                    PlasmaComponents.BusyIndicator {
                                                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                                        running: projectItem.isLoading; visible: projectItem.isLoading
                                                    }
                                                }

                                                // EDITOR row
                                                RowLayout {
                                                    visible: fullRep.editorSelectorEnabled
                                                    spacing: 6
                                                    Text {
                                                        text: "EDITOR"; Layout.preferredWidth: 60
                                                        font.family: root.mono; font.pixelSize: root.fzSmall; font.letterSpacing: 2
                                                        font.bold: true; color: root.clrText
                                                    }
                                                    Rectangle {
                                                        id: editorBtn
                                                        implicitWidth: editorTxt.implicitWidth + 32; implicitHeight: 22
                                                        color: root.clrBtn; border.color: root.clrBorder; border.width: 1
                                                        RowLayout {
                                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 4
                                                            Text {
                                                                id: editorTxt; Layout.fillWidth: true
                                                                text: { var o = root.editorOptions.find(e => e.cmd === projectItem.currentEditor); return o ? o.name.toUpperCase() : "CODE" }
                                                                font.family: root.mono; font.pixelSize: 9; font.bold: true; color: root.clrText
                                                            }
                                                            Text { text: "▾"; font.family: root.mono; font.pixelSize: 9; color: root.clrMuted }
                                                        }
                                                        MouseArea { anchors.fill: parent; onClicked: editorPopup.open() }
                                                        QQC2.Popup {
                                                            id: editorPopup
                                                            y: parent.height + 2
                                                            width: 170; padding: 0
                                                            background: Rectangle { color: "#111111"; border.color: root.clrBorder; border.width: 1 }
                                                            contentItem: Column {
                                                                width: 170
                                                                Repeater {
                                                                    model: root.editorOptions
                                                                    delegate: Rectangle {
                                                                        width: 170; height: 28
                                                                        color: eItemHov.containsMouse ? "#1e1e1e" : "#111111"
                                                                        Rectangle { width: 3; height: parent.height; color: root.clrGreen; visible: projectItem.currentEditor === modelData.cmd }
                                                                        Text {
                                                                            anchors.verticalCenter: parent.verticalCenter; x: 12
                                                                            text: modelData.name.toUpperCase()
                                                                            font.family: root.mono; font.pixelSize: 10; font.bold: true
                                                                            color: projectItem.currentEditor === modelData.cmd ? root.clrGreen : "#cccccc"
                                                                        }
                                                                        HoverHandler { id: eItemHov }
                                                                        MouseArea { anchors.fill: parent; onClicked: { projectItem.setEditor(modelData.cmd); editorPopup.close() } }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // FILE row
                                                RowLayout {
                                                    visible: dockerFiles.count > 0
                                                    spacing: 6
                                                    Text {
                                                        text: "FILE"; Layout.preferredWidth: 60
                                                        font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2
                                                        font.weight: Font.ExtraBold; color: root.clrText
                                                    }
                                                    Rectangle {
                                                        id: fileBtn
                                                        implicitWidth: fileTxt.implicitWidth + 32; implicitHeight: 22
                                                        color: dockerFiles.count > 1 ? root.clrBtn : "transparent"
                                                        border.color: dockerFiles.count > 1 ? root.clrBorder : "transparent"
                                                        border.width: 1
                                                        RowLayout {
                                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 4
                                                            Text {
                                                                id: fileTxt; Layout.fillWidth: true
                                                                text: projectItem.composeFileNames.length > 0 ? projectItem.composeFileNames[projectItem.selectedComposeIndex] : "—"
                                                                font.family: root.mono; font.pixelSize: 11; font.bold: true; color: root.clrText
                                                            }
                                                            Text { visible: dockerFiles.count > 1; text: "▾"; font.family: root.mono; font.pixelSize: 9; color: root.clrMuted }
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            enabled: dockerFiles.count > 1 && !projectItem.isLoading && !projectItem.isStarting
                                                            onClicked: composePopup.open()
                                                        }
                                                        QQC2.Popup {
                                                            id: composePopup
                                                            y: parent.height + 2
                                                            width: 220; padding: 0
                                                            background: Rectangle { color: "#111111"; border.color: root.clrBorder; border.width: 1 }
                                                            contentItem: Column {
                                                                width: 220
                                                                Repeater {
                                                                    model: projectItem.composeFileNames
                                                                    delegate: Rectangle {
                                                                        width: 220; height: 28
                                                                        color: cItemHov.containsMouse ? "#1e1e1e" : "#111111"
                                                                        Rectangle { width: 3; height: parent.height; color: root.clrGreen; visible: index === projectItem.selectedComposeIndex }
                                                                        Text {
                                                                            anchors.verticalCenter: parent.verticalCenter; x: 12
                                                                            text: modelData
                                                                            font.family: root.mono; font.pixelSize: 10; font.bold: true
                                                                            color: index === projectItem.selectedComposeIndex ? root.clrGreen : "#cccccc"
                                                                        }
                                                                        HoverHandler { id: cItemHov }
                                                                        MouseArea {
                                                                            anchors.fill: parent
                                                                            onClicked: {
                                                                                if (projectItem.selectedComposeIndex !== index) {
                                                                                    projectItem.selectedComposeIndex = index
                                                                                    projectItem.isExpanded = false
                                                                                    projectItem.isRunning  = false
                                                                                    projectItem.checkStatus()
                                                                                }
                                                                                composePopup.close()
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // DELETE (abajo de la info)
                                                Rectangle {
                                                    visible: fullRep.deleteEnabled
                                                    Layout.preferredWidth: 58; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: "#cc2200"; border.width: 1.5
                                                    Text { anchors.centerIn: parent; text: "✕ DEL"; font.family: root.mono; font.pixelSize: 9; font.bold: true; color: "#cc2200" }
                                                    HoverHandler { id: delHov }
                                                    MouseArea { anchors.fill: parent; onClicked: root.removeProject(origIndex) }
                                                    PlasmaComponents.ToolTip { text: "Eliminar proyecto"; visible: delHov.hovered }
                                                }
                                            }

                                            // Botones columna (derecha)
                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignTop
                                                spacing: 4

                                                // OPEN
                                                Rectangle {
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrBorder; border.width: 1.5
                                                    Text { anchors.centerIn: parent; text: "OPEN"; font.family: root.mono; font.pixelSize: 9; font.bold: true; color: root.clrText }
                                                    HoverHandler { id: openHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: { root.openProject(projectPath, projectItem.currentEditor); root.expanded = false }
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Abrir en editor"; visible: openHov.hovered }
                                                }

                                                // PULL
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isStarting
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrBorder; border.width: 1.5
                                                    Text { anchors.centerIn: parent; text: "↓ PULL"; font.family: root.mono; font.pixelSize: 9; font.bold: true; color: root.clrText }
                                                    HoverHandler { id: pullHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " pull\"")
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Actualizar imágenes"; visible: pullHov.hovered }
                                                }

                                                // LAUNCH
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isRunning && !projectItem.isStarting
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrGreen; border.color: root.clrBorder; border.width: 2
                                                    Text { anchors.centerIn: parent; text: "▶ LAUNCH"; font.family: root.mono; font.pixelSize: 9; font.bold: true; color: "#000000" }
                                                    HoverHandler { id: launchHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            projectItem.isRunning  = true
                                                            projectItem.isStarting = true
                                                            projectItem.isExpanded = true
                                                            executable.exec("sh -c \"" + projectItem.dockerComposeBase() + " up -d\"")
                                                            startupTimeoutTimer.restart()
                                                            projectItem.fetchContainers()
                                                        }
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Iniciar Docker Compose"; visible: launchHov.hovered }
                                                }

                                                // STOP
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && (projectItem.isRunning || projectItem.isStarting)
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrBorder; border.width: 2
                                                    Text { anchors.centerIn: parent; text: "■ STOP"; font.family: root.mono; font.pixelSize: 9; font.bold: true; color: "#cc2200" }
                                                    HoverHandler { id: stopHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            projectItem.isStarting = false; projectItem.isLoading = true; projectItem.isExpanded = false
                                                            startupTimeoutTimer.stop()
                                                            downSource.connectSource("sh -c \"" + projectItem.dockerComposeBase() + " down\"")
                                                        }
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Detener Docker Compose"; visible: stopHov.hovered }
                                                }
                                            }
                                        }
                                    }

                                    // ── SERVICES PANEL ────────────────────────
                                    Rectangle {
                                        visible: projectItem.isExpanded && (projectItem.isRunning || projectItem.isStarting)
                                        width: parent.width
                                        implicitHeight: visible ? servicesPanelCol.implicitHeight : 0
                                        color: "#c8c8c8"
                                        border.color: root.clrBorder; border.width: 1

                                        Column {
                                            id: servicesPanelCol
                                            width: parent.width

                                            // Panel header
                                            Rectangle {
                                                width: parent.width; height: 30; color: "#222222"
                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                                                    Text {
                                                        text: "SERVICES"
                                                        font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 4; color: "#aaaaaa"
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Rectangle {
                                                        Layout.preferredWidth: 38; Layout.preferredHeight: 20; color: root.clrGreen
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: projectItem.containerList.length.toString().padStart(2, "0")
                                                            font.family: root.mono; font.pixelSize: 11; font.bold: true; color: "#000"
                                                        }
                                                    }
                                                }
                                            }

                                            // Starting placeholder
                                            Item {
                                                visible: projectItem.isStarting && projectItem.containerList.length === 0
                                                width: parent.width; height: 40
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "◌  STARTING SERVICES..."
                                                    font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2; color: root.clrMuted
                                                }
                                            }

                                            // Container rows
                                            Repeater {
                                                model: projectItem.containerList
                                                delegate: Column {
                                                    width: parent ? parent.width : 0

                                                    property var   svc:       modelData
                                                    property bool  isSettled: modelData.state === "running" || modelData.state === "exited" || modelData.state === "dead"
                                                    property bool  isPending: projectItem.isStarting && !isSettled
                                                    property string port:     root.extractFirstPort(modelData.ports)

                                                    Rectangle { width: parent.width; height: 1; color: "#aaaaaa" }

                                                    Item {
                                                        width: parent.width; height: 38

                                                        RowLayout {
                                                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                                                            spacing: 8

                                                            // Status square
                                                            Rectangle {
                                                                Layout.preferredWidth: 10; Layout.preferredHeight: 10
                                                                color: isPending ? root.clrMuted :
                                                                       modelData.state === "running" ? root.clrGreen : "#cc2200"
                                                                border.color: root.clrBorder; border.width: 1
                                                                SequentialAnimation on opacity {
                                                                    running: isPending; loops: Animation.Infinite
                                                                    NumberAnimation { to: 0.2; duration: 500 }
                                                                    NumberAnimation { to: 1.0; duration: 500 }
                                                                }
                                                            }

                                                            // Name
                                                            Text {
                                                                Layout.preferredWidth: 110
                                                                text: modelData.service
                                                                font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1
                                                                color: root.clrText; elide: Text.ElideRight
                                                                opacity: isPending ? 0.5 : 1.0
                                                            }

                                                            // State
                                                            Text {
                                                                Layout.preferredWidth: 68
                                                                text: modelData.state.toUpperCase()
                                                                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                                                                color: modelData.state === "running" ? root.clrText : root.clrMuted
                                                            }

                                                            // Port badge
                                                            Rectangle {
                                                                visible: port.length > 0
                                                                implicitWidth: pTxt.implicitWidth + 14; implicitHeight: 18
                                                                color: root.clrGreen; border.color: root.clrBorder; border.width: 1
                                                                Text { id: pTxt; anchors.centerIn: parent; text: ":" + port; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: "#000" }
                                                            }

                                                            Item { Layout.fillWidth: true }

                                                            // Service action buttons
                                                            Row {
                                                                spacing: 3
                                                                visible: !isPending

                                                                Repeater {
                                                                    model: [
                                                                        { t: "LOG", w: 38, tip: "Ver logs",         show: true },
                                                                        { t: "↺",   w: 26, tip: "Reiniciar",        show: true },
                                                                        { t: "SH",  w: 28, tip: "Abrir terminal",   show: modelData.state === "running" },
                                                                        { t: "BLD", w: 38, tip: "Construir imagen", show: true }
                                                                    ]
                                                                    delegate: Rectangle {
                                                                        visible: modelData.show
                                                                        width: modelData.w; height: 22
                                                                        color: root.clrBtn; border.color: root.clrBorder; border.width: 1
                                                                        Text { anchors.centerIn: parent; text: modelData.t; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: root.clrText }
                                                                        HoverHandler { id: svcBtnHov }
                                                                        MouseArea {
                                                                            anchors.fill: parent
                                                                            onClicked: {
                                                                                var base = projectItem.dockerComposeBase()
                                                                                var name = svc.service
                                                                                if (modelData.t === "LOG") executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + base + " logs -f " + name + "\"")
                                                                                else if (modelData.t === "↺") { projectItem.isLoading = true; executable.exec("sh -c \"" + base + " restart " + name + "\"") }
                                                                                else if (modelData.t === "SH")  executable.exec("konsole --workdir '" + projectPath + "' -e sh -c \"" + base + " exec " + name + " sh\"")
                                                                                else if (modelData.t === "BLD") executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + base + " build " + name + "\"")
                                                                            }
                                                                        }
                                                                        PlasmaComponents.ToolTip { text: modelData.tip; visible: svcBtnHov.hovered }
                                                                    }
                                                                }

                                                                // Browser button
                                                                Rectangle {
                                                                    visible: svc.state === "running" && svc.ports.length > 0
                                                                    width: 26; height: 22
                                                                    color: root.clrGreen; border.color: root.clrBorder; border.width: 1
                                                                    Text { anchors.centerIn: parent; text: "🌐"; font.pixelSize: 11 }
                                                                    HoverHandler { id: webHov }
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        onClicked: {
                                                                            var m = /:(\d+)->/.exec(svc.ports)
                                                                            if (m) Qt.openUrlExternally("http://localhost:" + m[1])
                                                                        }
                                                                    }
                                                                    PlasmaComponents.ToolTip { text: "Abrir en navegador"; visible: webHov.hovered }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Panel footer
                                            Rectangle {
                                                width: parent.width; height: 24; color: "#bbbbbb"
                                                border.color: "#aaaaaa"; border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "COMPOSE: " + (projectItem.composeFileNames.length > 0 ? projectItem.composeFileNames[projectItem.selectedComposeIndex] : "—")
                                                    font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2; color: root.clrSub
                                                }
                                            }
                                        }
                                    }

                                    Item { width: 1; height: 4 }
                                }
                            }

                            // Drop indicator bottom
                            Rectangle {
                                visible: fullRep.dragEnabled && fullRep.draggedIndex !== -1 &&
                                         fullRep.dropTargetIndex === Plasmoid.configuration.projects.length &&
                                         origIndex === Plasmoid.configuration.projects.length - 1
                                width: parent.width; height: 3; color: root.clrGreen
                            }
                        }
                    }
                }
            }

            // ── FOOTER ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 42; color: "#c8c8c8"

                Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: root.clrBorder }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8

                    Row {
                        spacing: 0
                        property var bars: [1,3,1,2,4,1,2,1,3,2,1,4,1,2]
                        Repeater {
                            model: parent.bars.length
                            Rectangle { width: parent.parent.bars[index]; height: 24; color: index % 2 === 0 ? root.clrBorder : "transparent" }
                        }
                    }

                    Column {
                        spacing: 3
                        Text { text: "KDE::PLASMA PROJECT LAUNCHER"; font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2; color: root.clrSub }
                        Text { text: "1 094-72-601  //  v2.0"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1; color: root.clrMuted }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 0
                        property var bars: [2,1,3,1,2,4,1,2,1,3,1,2,1,3]
                        Repeater {
                            model: parent.bars.length
                            Rectangle { width: parent.parent.bars[index]; height: 24; color: index % 2 === 0 ? root.clrBorder : "transparent" }
                        }
                    }
                }
            }
        }

    }
}
