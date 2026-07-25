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
    // Dos paletas, un sistema. En claro: papel gris, tinta negra. En oscuro no
    // se invierte la tinta —eso deja cada borde estructural en blanco y el
    // widget se lee como una reja— sino que se toma el chasis de
    // kde-devcommands: planos casi negros con tinte verde, muy poco salto entre
    // ellos, y la profundidad puesta en clrEdge (1 px de luz arriba).
    // "auto" mira el esquema de Plasma; light/dark lo fijan (Plasmoid.configuration.theme).
    readonly property bool dark: {
        var mode = Plasmoid.configuration.theme
        if (mode === "dark")  return true
        if (mode === "light") return false
        return Kirigami.Theme.backgroundColor.hslLightness < 0.5
    }

    // Superficies — mismo orden en los dos temas: fondo < barras < panel < tarjeta.
    readonly property color clrBg:     dark ? "#131715" : "#b6b6b2"  // bandeja donde caen las tarjetas
    readonly property color clrCard:   dark ? "#222724" : "#d6d6d1"  // plano elevado: tarjeta y cabecera
    readonly property color clrShell:  dark ? "#181c1a" : "#c5c5c0"  // barras de herramientas y pie
    readonly property color clrPanel:  dark ? "#1b201e" : "#cacac5"  // panel de servicios
    readonly property color clrText:   dark ? "#e3e8e4" : "#131410"  // 12.3:1 sobre clrCard
    readonly property color clrSub:    dark ? "#b0b9b4" : "#3c3d35"  // valores secundarios (ruta, estado)
    readonly property color clrMuted:  dark ? "#8b948e" : "#5c5d53"  // etiquetas — ≥4.5:1 sobre clrCard

    // La luz que da grosor a los planos elevados: cabecera, tarjeta y pie.
    // En claro no hace falta — ahí el salto de valor ya es suficiente.
    readonly property color clrEdge: dark ? "#20ffffff" : "transparent"

    // Filete de cabecera y pie. En claro, 2 px de tinta: el negro sobre gris es
    // el contraste máximo disponible. En oscuro esa banda sería lo más brillante
    // del widget y se llevaría la mirada por delante del nombre del proyecto.
    readonly property color clrBand: dark ? "#414944" : "#131410"
    readonly property int   bandW:   dark ? 1 : 2

    // Regla 1: el verde significa una sola cosa — "esto está vivo".
    // Regla 2: verde de señal, no verde puro; deja de vibrar sobre el gris.
    // En oscuro basta un verde: 8.7:1 sobre clrCard, sirve de relleno y de texto.
    readonly property color clrGreen:   dark ? "#2fe07a" : "#1f9c3e"  // relleno: raíl, badge, punto de servicio
    readonly property color clrGreenTx: dark ? "#2fe07a" : "#0b5220"  // el mismo verde, legible sobre el fondo
    readonly property color clrOnGreen: dark ? "#06210f" : "#05300f"  // texto sobre relleno verde

    // Regla 3: tres rangos de botón. Primaria con cuerpo, filete = secundaria,
    // rojo = destructiva. En oscuro la primaria no es una losa clara sino una
    // tecla: es el único botón con relleno, y sigue siendo el primero que se ve.
    readonly property color clrPriBg:   dark ? "#2f3733" : "#131410"
    readonly property color clrPriBd:   dark ? "#4a534d" : "#131410"
    readonly property color clrPriTx:   dark ? "#e3e8e4" : "#ffffff"
    readonly property color clrPriEdge: dark ? "#24ffffff" : "transparent"

    readonly property color clrRed:   dark ? "#ff6b4a" : "#9c2b15"  // 5.4:1, al brillo del acento
    readonly property color clrOnRed: dark ? "#131715" : "#ffffff"
    readonly property color clrBtn:   "transparent"  // los secundarios se definen por el filete

    readonly property color clrHair:   dark ? "#313732" : "#33131410"  // filete de 1 px
    readonly property color clrHair2:  dark ? "#414944" : "#73131410"  // divisoria estructural
    readonly property color clrLiveBd: dark ? "#4a544d" : "#131410"    // borde de la tarjeta viva
    readonly property color clrField:  dark ? "#0f1211" : "#bfbfba"    // campo de búsqueda: hundido

    // Grafismos y marcas transitorias: código de barras, destino de drop.
    readonly property color clrInk:      dark ? "#e3e8e4" : "#131410"
    readonly property real  barOpacity:  dark ? 0.85 : 1.0

    // Los desplegables no invierten con el tema: son una capa flotante que debe
    // despegarse de la tarjeta, y su borde (clrBorder) ya la recorta.
    readonly property color clrBorder:  dark ? "#414944" : "#131410"
    readonly property color clrMenuBg:  dark ? "#0f1211" : "#111111"
    readonly property color clrMenuHov: dark ? "#1b201e" : "#1e1e1e"
    readonly property color clrMenuTx:  dark ? "#e3e8e4" : "#ffffff"
    readonly property color clrMenuDim: dark ? "#8b948e" : "#999999"

    // Courier New tiene el trazo tan fino que a 9-10 px se deshace sobre gris.
    // Se elige la primera mono de verdad que haya instalada.
    readonly property string mono: {
        var prefs = ["JetBrainsMono Nerd Font", "JetBrains Mono", "Hack",
                     "Fira Code", "Noto Sans Mono", "DejaVu Sans Mono",
                     "Liberation Mono", "Monospace"]
        var avail = Qt.fontFamilies()
        for (var i = 0; i < prefs.length; i++)
            if (avail.indexOf(prefs[i]) >= 0) return prefs[i]
        return "Monospace"
    }

    // font sizes
    readonly property int fzTiny:   8
    readonly property int fzSmall:  9   // Regla 4: etiquetas — peso normal, gris
    readonly property int fzNormal: 10
    readonly property int fzValue:  11  // Regla 4: valores — negrita, tinta
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
        // "</>" dibujado, no escrito: en mono la barra es más alta que los
        // ángulos y el conjunto queda desparejo. Con trazos propios los tres
        // elementos comparten peso y altura, y aguanta cualquier tamaño de panel.
        Canvas {
            id: glyph
            anchors.centerIn: parent
            // 0.8 de la caja: es la proporción que ocupa un icono del tema en el
            // panel. A caja completa la marca sale más grande que sus vecinas.
            width:  Math.round(Math.min(parent.width, parent.height) * 0.8)
            height: width

            // Cantos vivos, como el resto del widget: sin remates redondeados.
            property color stroke: Kirigami.Theme.textColor
            onStrokeChanged: requestPaint()
            onWidthChanged:  requestPaint()

            opacity: parent.containsMouse ? 0.7 : 1.0
            Behavior on opacity { NumberAnimation { duration: 100 } }

            onPaint: {
                var ctx = getContext("2d")
                var s = width
                ctx.reset()
                ctx.strokeStyle = stroke
                // Redondeado a píxel entero y al peso de Breeze (~2 px a 24 px de
                // icono): en decimales el antialias engorda el trazo.
                ctx.lineWidth   = Math.max(1, Math.round(s * 0.075))
                ctx.lineCap     = "butt"
                ctx.lineJoin    = "miter"

                var p  = s * 0.11          // aire alrededor
                var w  = s - 2 * p
                var h  = w * 0.58          // alto: el mismo para los tres trazos
                var mid = s / 2
                var top = mid - h / 2, bot = mid + h / 2

                // Los huecos barra↔ángulo valen ~1.5 veces el grosor del trazo:
                // menos que eso y los tres elementos se leen como una mancha.
                ctx.beginPath()
                ctx.moveTo(p + w * 0.27, top)   // ángulo izquierdo
                ctx.lineTo(p,            mid)
                ctx.lineTo(p + w * 0.27, bot)

                ctx.moveTo(p + w * 0.73, top)   // ángulo derecho
                ctx.lineTo(p + w,        mid)
                ctx.lineTo(p + w * 0.73, bot)

                ctx.moveTo(p + w * 0.555, top)  // barra
                ctx.lineTo(p + w * 0.445, bot)
                ctx.stroke()
            }
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

        // Los desplegables flotan en el overlay de la ventana: la tarjeta no los
        // recorta, pero el borde del diálogo sí. Antes de abrir uno se mide el
        // hueco real bajo el botón; si la lista entera no cabe, se abre hacia
        // arriba, y si tampoco cabe arriba se queda del lado más holgado con la
        // lista desplazándose dentro del menú. Nunca queda un item medio cortado.
        function placeMenu(popup, anchor, count, itemH) {
            var need  = count * itemH + 2          // +2: el filete del fondo
            var top   = anchor.mapToItem(fullRep, 0, 0).y
            var below = fullRep.height - (top + anchor.height) - 8
            var above = top - 8
            var room  = (need <= below || below >= above) ? below : above
            popup.height = Math.max(Math.min(need, room), itemH + 2)
            popup.y = (room === below) ? anchor.height + 2 : -popup.height - 2
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

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── HEADER ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 64
                color: root.clrCard

                // La luz de 1 px: es lo que da grosor al plano en oscuro.
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: 1
                    color: root.clrEdge
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: root.bandW
                    color: root.clrBand
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Barcode — o se ve, o no está: a tinta plena. Su matrícula
                    // se muda al pie, donde se puede leer.
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        property var bars: [2,1,4,2,1,1,3,2,1,1,2,3,4,1,1,2,2,1,3]
                        Repeater {
                            model: parent.bars.length
                            Rectangle {
                                width: parent.bars[index]; height: 30
                                color: index % 2 === 0 ? root.clrInk : "transparent"
                                opacity: root.barOpacity
                            }
                        }
                    }

                    // Title
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 5
                        Text {
                            text: "DEV PROJECTS"
                            font.family: root.mono; font.pixelSize: 16
                            font.bold: true; font.letterSpacing: 2.4
                            color: root.clrText
                        }
                        Text {
                            text: "PROJECT LAUNCHER"
                            font.family: root.mono; font.pixelSize: root.fzSmall
                            font.letterSpacing: 1.8; color: root.clrMuted
                        }
                    }

                    Rectangle {
                        width: 1; Layout.fillHeight: true
                        Layout.topMargin: 12; Layout.bottomMargin: 14
                        color: root.clrHair2
                    }

                    // Un solo readout: activos sobre total, alineado a la derecha.
                    // OFF era aritmética (total − activos), no un dato.
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 0
                            Text {
                                Layout.alignment: Qt.AlignBaseline
                                text: fullRep.runningCount.toString().padStart(2, "0")
                                font.family: root.mono; font.pixelSize: 26; font.bold: true
                                color: fullRep.runningCount > 0 ? root.clrGreenTx : root.clrMuted
                            }
                            Text {
                                Layout.alignment: Qt.AlignBaseline
                                text: "/" + Plasmoid.configuration.projects.length.toString().padStart(2, "0")
                                font.family: root.mono; font.pixelSize: 15
                                color: root.clrMuted
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: "ACTIVOS / TOTAL"
                            font.family: root.mono; font.pixelSize: root.fzTiny
                            font.letterSpacing: 1.6; color: root.clrMuted
                        }
                    }
                }
            }

            // ── TOOLBAR ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: root.clrShell

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.clrHair2 }

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
                            property bool active:      fullRep[modelData.prop]
                            property bool destructive: modelData.label === "✕ DEL"
                            // Activo = relleno (o rojo si es destructivo); inactivo = solo filete.
                            color:        active ? (destructive ? root.clrRed : root.clrPriBg) : root.clrBtn
                            border.color: active ? (destructive ? root.clrRed : root.clrPriBd) : root.clrHair
                            border.width: 1
                            Rectangle {
                                x: 1; y: 1
                                width: parent.width - 2; height: 1
                                visible: parent.active && !parent.destructive
                                color: root.clrPriEdge
                            }
                            Text {
                                anchors.centerIn: parent
                                text:  modelData.label
                                font.family: root.mono; font.pixelSize: 11
                                font.bold: active; font.letterSpacing: 0.6
                                color: active ? (destructive ? root.clrOnRed : root.clrPriTx) : root.clrText
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

                    // Acción primaria de la barra → relleno, no verde (Reglas 1 y 3)
                    Rectangle {
                        Layout.preferredWidth: 72; Layout.preferredHeight: 26
                        color: root.clrPriBg; border.color: root.clrPriBd; border.width: 1
                        Rectangle {
                            x: 1; y: 1; width: parent.width - 2; height: 1
                            color: root.clrPriEdge
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "+ ADD"; font.family: root.mono; font.pixelSize: 11; font.bold: true; color: root.clrPriTx
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
                color: root.clrField
                border.color: root.clrHair2; border.width: 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 6

                    Text { text: "⌕"; font.family: root.mono; font.pixelSize: 13; color: root.clrSub }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        font.family: root.mono; font.pixelSize: root.fzValue; font.letterSpacing: 1
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

                            // "Vivo" es lo único que gana filete verde y borde en tinta (Reglas 1 y 4).
                            readonly property bool live: isRunning || isStarting

                            // Puertos publicados, sin repetir, para la fila de meta.
                            readonly property var portsList: {
                                var seen = {}, out = []
                                for (var i = 0; i < containerList.length; i++) {
                                    var re = /:(\d+)->/g, m, s = containerList[i].ports || ""
                                    while ((m = re.exec(s)) !== null)
                                        if (!seen[m[1]]) { seen[m[1]] = true; out.push(":" + m[1]) }
                                }
                                return out
                            }
                            // Seis puertos en fila son ruido: se enseñan tres y el resto
                            // se cuenta. La lista completa va en el tooltip.
                            readonly property string portsLabel: {
                                if (portsList.length <= 3) return portsList.join("  ")
                                return portsList.slice(0, 3).join("  ") + "  +" + (portsList.length - 3)
                            }

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
                                // También en plegado: la fila de meta necesita cuántos
                                // servicios y qué puertos hay vivos.
                                onTriggered: {
                                    projectItem.checkStatus()
                                    if (projectItem.isExpanded || projectItem.isRunning) projectItem.fetchContainers()
                                }
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
                                        editorPopup.close(); composePopup.close()
                                        fullRep.draggedIndex = -1; fullRep.dropTargetIndex = -1
                                    }
                                }
                            }

                            // Drop indicator top — destino de drop, no estado: tinta (Regla 1)
                            Rectangle {
                                visible: fullRep.dragEnabled && fullRep.draggedIndex !== -1 &&
                                         fullRep.dropTargetIndex === origIndex && fullRep.draggedIndex !== origIndex
                                width: parent.width; height: 3; color: root.clrInk
                            }

                            // ── CARD ──────────────────────────────────────────
                            Rectangle {
                                width: parent.width
                                height: cardCol.implicitHeight
                                color: root.clrCard
                                border.color: projectItem.live ? root.clrLiveBd : root.clrHair
                                border.width: 1
                                opacity: fullRep.draggedIndex === origIndex ? 0.3 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                // La luz de 1 px que separa la tarjeta del fondo
                                // sin recortarla con un contorno claro.
                                Rectangle {
                                    x: 1; y: 1; width: parent.width - 2; height: 1
                                    color: root.clrEdge
                                }

                                // Filete verde: el estado se escanea sin leer, y sin
                                // gastar una barra negra ni una fila entera en decirlo.
                                Rectangle {
                                    visible: projectItem.live
                                    x: 0; y: 0; width: 4; height: parent.height
                                    color: root.clrGreen
                                    z: 1
                                    // Arrancando: el filete late. Es el indeterminado
                                    // que antes fingía la barra de STATUS al 45%.
                                    SequentialAnimation on opacity {
                                        running: projectItem.isStarting; loops: Animation.Infinite
                                        alwaysRunToEnd: true
                                        NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Column {
                                    id: cardCol
                                    width: parent.width
                                    topPadding: 9
                                    // El panel de servicios va a hueso con el borde inferior
                                    bottomPadding: (projectItem.isExpanded && projectItem.live) ? 0 : 9
                                    spacing: 5

                                    // ── Nombre + estado ───────────────────────
                                    Item {
                                        width: parent.width; height: 22

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 8

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
                                                            color: dragArea.containsMouse ? root.clrText : root.clrMuted
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

                                            // El nombre es lo que buscas al abrir el widget:
                                            // se queda solo, sin etiqueta que le compita.
                                            Text {
                                                Layout.fillWidth: true
                                                text: root.projectName(projectPath).toUpperCase()
                                                font.family: root.mono; font.pixelSize: root.fzLarge
                                                font.bold: true; font.letterSpacing: 0.9
                                                color: projectItem.live ? root.clrText : root.clrSub
                                                elide: Text.ElideRight
                                            }

                                            // Status badge — relleno verde solo si vive;
                                            // apagado = filete gris, sin peso (Reglas 1 y 3)
                                            Rectangle {
                                                Layout.preferredWidth: badgeTxt.implicitWidth + 16
                                                Layout.preferredHeight: 19
                                                color:        projectItem.isRunning ? root.clrGreen : "transparent"
                                                border.color: projectItem.isRunning ? root.clrGreen   :
                                                              projectItem.live      ? root.clrLiveBd : root.clrHair2
                                                border.width: 1
                                                Text {
                                                    id: badgeTxt
                                                    anchors.centerIn: parent
                                                    text: projectItem.isStarting ? "STARTING" :
                                                          projectItem.isRunning  ? "RUNNING"  :
                                                          projectItem.isLoading  ? "LOADING"  : "OFFLINE"
                                                    font.family: root.mono; font.pixelSize: root.fzSmall
                                                    font.bold: projectItem.live; font.letterSpacing: 1.6
                                                    color: projectItem.isRunning ? root.clrOnGreen :
                                                           projectItem.live      ? root.clrText    : root.clrMuted
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
                                                    font.family: root.mono; font.pixelSize: 10
                                                    color: root.clrMuted
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
                                        implicitHeight: bodyLayout.implicitHeight

                                        RowLayout {
                                            id: bodyLayout
                                            x: 12
                                            width: parent.width - 22
                                            spacing: 10

                                            // Info column (izquierda) — centrada contra la
                                            // pila de botones, que es más alta que el texto
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 5

                                                // Ruta — se reconoce por empezar en ~/;
                                                // la etiqueta PATH no aportaba nada
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: projectPath.replace(/^\/home\/[^/]+/, "~")
                                                    font.family: root.mono; font.pixelSize: root.fzValue
                                                    color: root.clrSub
                                                    elide: Text.ElideMiddle
                                                }

                                                // EDITOR row
                                                RowLayout {
                                                    visible: fullRep.editorSelectorEnabled
                                                    spacing: 6
                                                    Text {
                                                        text: "EDITOR"; Layout.preferredWidth: 46
                                                        font.family: root.mono; font.pixelSize: root.fzSmall
                                                        font.letterSpacing: 1.6; color: root.clrMuted
                                                    }
                                                    Rectangle {
                                                        id: editorBtn
                                                        implicitWidth: editorTxt.implicitWidth + 32; implicitHeight: 22
                                                        color: root.clrBtn; border.color: root.clrHair; border.width: 1
                                                        RowLayout {
                                                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 4
                                                            Text {
                                                                id: editorTxt; Layout.fillWidth: true
                                                                text: { var o = root.editorOptions.find(e => e.cmd === projectItem.currentEditor); return o ? o.name.toUpperCase() : "CODE" }
                                                                font.family: root.mono; font.pixelSize: root.fzValue; font.bold: true; color: root.clrText
                                                            }
                                                            Text { text: "▾"; font.family: root.mono; font.pixelSize: 9; color: root.clrMuted }
                                                        }
                                                        MouseArea { anchors.fill: parent; onClicked: editorPopup.open() }
                                                        QQC2.Popup {
                                                            id: editorPopup
                                                            y: parent.height + 2
                                                            width: 170; padding: 0
                                                            onAboutToShow: fullRep.placeMenu(editorPopup, editorBtn, root.editorOptions.length, 28)
                                                            background: Rectangle { color: root.clrMenuBg; border.color: root.clrBorder; border.width: 1 }
                                                            contentItem: ListView {
                                                                implicitWidth: 170
                                                                implicitHeight: contentHeight
                                                                clip: true
                                                                boundsBehavior: Flickable.StopAtBounds
                                                                model: root.editorOptions
                                                                delegate: Rectangle {
                                                                    width: 170; height: 28
                                                                    color: eItemHov.containsMouse ? root.clrMenuHov : root.clrMenuBg
                                                                    // "Seleccionado" no es "vivo": sobre negro, la tinta es el blanco
                                                                    Rectangle { width: 3; height: parent.height; color: root.clrMenuTx; visible: projectItem.currentEditor === modelData.cmd }
                                                                    Text {
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        x: 12; width: parent.width - 20
                                                                        text: modelData.name.toUpperCase()
                                                                        elide: Text.ElideRight
                                                                        font.family: root.mono; font.pixelSize: 11
                                                                        font.bold: projectItem.currentEditor === modelData.cmd
                                                                        color: projectItem.currentEditor === modelData.cmd ? root.clrMenuTx : root.clrMenuDim
                                                                    }
                                                                    HoverHandler { id: eItemHov }
                                                                    MouseArea { anchors.fill: parent; onClicked: { projectItem.setEditor(modelData.cmd); editorPopup.close() } }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // META row — el compose se reconoce por acabar
                                                // en .yml; lo que sí hace falta saber es qué hay
                                                // vivo y en qué puerto.
                                                RowLayout {
                                                    visible: dockerFiles.count > 0
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Rectangle {
                                                        id: fileBtn
                                                        implicitWidth: fileTxt.implicitWidth + (dockerFiles.count > 1 ? 26 : 0)
                                                        implicitHeight: 20
                                                        color: "transparent"
                                                        border.color: dockerFiles.count > 1 ? root.clrHair : "transparent"
                                                        border.width: 1
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: dockerFiles.count > 1 ? 7 : 0
                                                            anchors.rightMargin: dockerFiles.count > 1 ? 5 : 0
                                                            spacing: 4
                                                            Text {
                                                                id: fileTxt; Layout.fillWidth: true
                                                                text: projectItem.composeFileNames.length > 0 ? projectItem.composeFileNames[projectItem.selectedComposeIndex] : "—"
                                                                font.family: root.mono; font.pixelSize: root.fzNormal; color: root.clrSub
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
                                                            onAboutToShow: fullRep.placeMenu(composePopup, fileBtn, projectItem.composeFileNames.length, 28)
                                                            background: Rectangle { color: root.clrMenuBg; border.color: root.clrBorder; border.width: 1 }
                                                            contentItem: ListView {
                                                                implicitWidth: 220
                                                                implicitHeight: contentHeight
                                                                clip: true
                                                                boundsBehavior: Flickable.StopAtBounds
                                                                model: projectItem.composeFileNames
                                                                delegate: Rectangle {
                                                                    width: 220; height: 28
                                                                    color: cItemHov.containsMouse ? root.clrMenuHov : root.clrMenuBg
                                                                    Rectangle { width: 3; height: parent.height; color: root.clrMenuTx; visible: index === projectItem.selectedComposeIndex }
                                                                    Text {
                                                                        anchors.verticalCenter: parent.verticalCenter
                                                                        x: 12; width: parent.width - 20
                                                                        text: modelData
                                                                        elide: Text.ElideMiddle
                                                                        font.family: root.mono; font.pixelSize: 11
                                                                        font.bold: index === projectItem.selectedComposeIndex
                                                                        color: index === projectItem.selectedComposeIndex ? root.clrMenuTx : root.clrMenuDim
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

                                                    // Servicios vivos y puertos publicados
                                                    Rectangle {
                                                        visible: projectItem.isRunning && projectItem.containerList.length > 0
                                                        Layout.preferredWidth: 7; Layout.preferredHeight: 7
                                                        color: root.clrGreen
                                                    }
                                                    Text {
                                                        visible: projectItem.isRunning && projectItem.containerList.length > 0
                                                        text: projectItem.containerList.length + " SVC"
                                                        font.family: root.mono; font.pixelSize: root.fzNormal
                                                        font.bold: true; color: root.clrSub
                                                    }
                                                    // fillWidth + minimumWidth 0: si no, el ancho
                                                    // implícito de la lista empuja los botones
                                                    // fuera de la tarjeta.
                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        visible: projectItem.isRunning && projectItem.portsList.length > 0
                                                        text: projectItem.portsLabel
                                                        font.family: root.mono; font.pixelSize: root.fzNormal
                                                        color: root.clrMuted
                                                        elide: Text.ElideRight
                                                        HoverHandler { id: portsHov }
                                                        PlasmaComponents.ToolTip {
                                                            text: projectItem.portsList.join("   ")
                                                            visible: portsHov.hovered && projectItem.portsList.length > 3
                                                        }
                                                    }

                                                    PlasmaComponents.BusyIndicator {
                                                        Layout.preferredWidth: 13; Layout.preferredHeight: 13
                                                        running: projectItem.isLoading; visible: projectItem.isLoading
                                                    }

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        visible: !(projectItem.isRunning && projectItem.portsList.length > 0)
                                                    }
                                                }

                                                // DELETE (abajo de la info)
                                                Rectangle {
                                                    visible: fullRep.deleteEnabled
                                                    Layout.preferredWidth: 58; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrRed; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "✕ DEL"; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: root.clrRed }
                                                    HoverHandler { id: delHov }
                                                    MouseArea { anchors.fill: parent; onClicked: root.removeProject(origIndex) }
                                                    PlasmaComponents.ToolTip { text: "Eliminar proyecto"; visible: delHov.hovered }
                                                }
                                            }

                                            // Botones columna (derecha)
                                            ColumnLayout {
                                                Layout.alignment: Qt.AlignTop
                                                spacing: 3

                                                // OPEN — secundaria: solo filete (Regla 3)
                                                Rectangle {
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrHair; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "OPEN"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 0.6; color: root.clrSub }
                                                    HoverHandler { id: openHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: { root.openProject(projectPath, projectItem.currentEditor); root.expanded = false }
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Abrir en editor"; visible: openHov.hovered }
                                                }

                                                // PULL — secundaria
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isStarting
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrHair; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "↓ PULL"; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 0.6; color: root.clrSub }
                                                    HoverHandler { id: pullHov }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: executable.exec("konsole --workdir '" + projectPath + "' --hold -e sh -c \"" + projectItem.dockerComposeBase() + " pull\"")
                                                    }
                                                    PlasmaComponents.ToolTip { text: "Actualizar imágenes"; visible: pullHov.hovered }
                                                }

                                                // LAUNCH — primaria: la única con cuerpo. Verde es el
                                                // estado que produce, no el botón que lo lanza (Reglas 1 y 3)
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && !projectItem.isRunning && !projectItem.isStarting
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrPriBg; border.color: root.clrPriBd; border.width: 1
                                                    Rectangle {
                                                        x: 1; y: 1; width: parent.width - 2; height: 1
                                                        color: root.clrPriEdge
                                                    }
                                                    Text { anchors.centerIn: parent; text: "▶ LAUNCH"; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: root.clrPriTx }
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

                                                // STOP — destructiva: filete y texto rojo (Regla 3)
                                                Rectangle {
                                                    visible: dockerFiles.count > 0 && !projectItem.isLoading && (projectItem.isRunning || projectItem.isStarting)
                                                    Layout.preferredWidth: 84; Layout.preferredHeight: 22
                                                    color: root.clrBtn; border.color: root.clrRed; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "■ STOP"; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: root.clrRed }
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
                                        color: root.clrPanel
                                        border.color: root.clrHair; border.width: 1

                                        Column {
                                            id: servicesPanelCol
                                            width: parent.width
                                            topPadding: 4

                                            // Panel header — un contador no es un estado:
                                            // deja de ir en verde y pasa a ser solo cifra (Regla 1)
                                            Rectangle {
                                                width: parent.width; height: 28; color: "transparent"
                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width; height: 1; color: root.clrHair
                                                }
                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                                    Text {
                                                        text: "SERVICIOS"
                                                        font.family: root.mono; font.pixelSize: root.fzSmall
                                                        font.letterSpacing: 2.4; color: root.clrMuted
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Text {
                                                        text: projectItem.containerList.length.toString().padStart(2, "0")
                                                        font.family: root.mono; font.pixelSize: root.fzValue
                                                        font.bold: true; color: root.clrSub
                                                    }
                                                }
                                            }

                                            // Starting placeholder
                                            Item {
                                                visible: projectItem.isStarting && projectItem.containerList.length === 0
                                                width: parent.width; height: 40
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "◌  ARRANCANDO SERVICIOS..."
                                                    font.family: root.mono; font.pixelSize: root.fzValue; font.letterSpacing: 1.6; color: root.clrMuted
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

                                                    Rectangle { width: parent.width; height: 1; color: root.clrHair; opacity: 0.5 }

                                                    Item {
                                                        width: parent.width; height: 38

                                                        RowLayout {
                                                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                                                            spacing: 8

                                                            // Status square
                                                            Rectangle {
                                                                Layout.preferredWidth: 10; Layout.preferredHeight: 10
                                                                color: isPending ? root.clrMuted :
                                                                       modelData.state === "running" ? root.clrGreen : root.clrRed
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
                                                                font.family: root.mono; font.pixelSize: root.fzValue; font.bold: true; font.letterSpacing: 0.6
                                                                color: root.clrText; elide: Text.ElideRight
                                                                opacity: isPending ? 0.5 : 1.0
                                                            }

                                                            // State
                                                            Text {
                                                                Layout.preferredWidth: 68
                                                                text: modelData.state.toUpperCase()
                                                                font.family: root.mono; font.pixelSize: root.fzSmall; font.letterSpacing: 1.6
                                                                color: root.clrMuted
                                                            }

                                                            // Port badge — un puerto es un dato, no un estado:
                                                            // pasa a filete (Regla 1)
                                                            Rectangle {
                                                                visible: port.length > 0
                                                                implicitWidth: pTxt.implicitWidth + 14; implicitHeight: 18
                                                                color: "transparent"; border.color: root.clrHair; border.width: 1
                                                                Text { id: pTxt; anchors.centerIn: parent; text: ":" + port; font.family: root.mono; font.pixelSize: 10; font.bold: true; color: root.clrSub }
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
                                                                        color: root.clrBtn; border.color: root.clrHair; border.width: 1
                                                                        Text { anchors.centerIn: parent; text: modelData.t; font.family: root.mono; font.pixelSize: 10; color: root.clrText }
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
                                                                    color: root.clrBtn; border.color: root.clrHair; border.width: 1
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

                                            // El compose ya está en la fila de meta de la
                                            // tarjeta: repetirlo aquí era decorar el hueco.
                                            Item { width: 1; height: 4 }
                                        }
                                    }
                                }
                            }

                            // Drop indicator bottom
                            Rectangle {
                                visible: fullRep.dragEnabled && fullRep.draggedIndex !== -1 &&
                                         fullRep.dropTargetIndex === Plasmoid.configuration.projects.length &&
                                         origIndex === Plasmoid.configuration.projects.length - 1
                                width: parent.width; height: 3; color: root.clrInk
                            }
                        }
                    }
                }
            }

            // ── FOOTER ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 34; color: root.clrShell

                Rectangle { anchors.top: parent.top; width: parent.width; height: root.bandW; color: root.clrBand }
                Rectangle { y: root.bandW; width: parent.width; height: 1; color: root.clrEdge }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10

                    // Un código, no dos: dos adornos idénticos flanqueando el texto
                    // son ruido simétrico. Y a tinta, para que sea un grafismo.
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        property var bars: [1,3,1,2,4,1,2,1,3,2,1,4,1,2]
                        Repeater {
                            model: parent.bars.length
                            Rectangle {
                                width: parent.bars[index]; height: 18
                                color: index % 2 === 0 ? root.clrInk : "transparent"
                                opacity: root.barOpacity
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "KDE::PLASMA PROJECT LAUNCHER"
                        font.family: root.mono; font.pixelSize: root.fzSmall
                        font.letterSpacing: 1.8; color: root.clrMuted
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "094-72-601  ·  v2.0"
                        font.family: root.mono; font.pixelSize: root.fzSmall
                        font.letterSpacing: 1; color: root.clrMuted
                    }
                }
            }
        }

    }
}
