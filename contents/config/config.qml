import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Apariencia"
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: "Editores"
        icon: "document-edit"
        source: "configEditors.qml"
    }
}
