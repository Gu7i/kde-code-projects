import QtQuick
import QtQuick.Layouts
import QtQuick.Controls 2.0 as QQC2
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: configRoot
    implicitHeight: mainLayout.implicitHeight

    property string cfg_theme: "auto"

    Kirigami.FormLayout {
        id: mainLayout
        anchors { left: parent.left; right: parent.right; top: parent.top }

        QQC2.RadioButton {
            Kirigami.FormData.label: "Tema:"
            text: "Automático (sigue a Plasma)"
            checked: configRoot.cfg_theme === "auto"
            onToggled: if (checked) configRoot.cfg_theme = "auto"
        }
        QQC2.RadioButton {
            text: "Claro"
            checked: configRoot.cfg_theme === "light"
            onToggled: if (checked) configRoot.cfg_theme = "light"
        }
        QQC2.RadioButton {
            text: "Oscuro"
            checked: configRoot.cfg_theme === "dark"
            onToggled: if (checked) configRoot.cfg_theme = "dark"
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: "En automático el widget mira la luminosidad del esquema de color " +
                  "de Plasma y cambia de paleta con él."
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }
}
