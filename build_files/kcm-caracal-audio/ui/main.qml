import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: root

    title: i18n("Caracal Audio")

    property string lastCommand: ""

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function runUjust(args) {
        lastCommand = "ujust " + args;
        executable.connectSource("konsole --hold -e /usr/bin/env bash -lc " + shellQuote(lastCommand + "; # " + Date.now()));
    }

    Plasma5Support.DataSource {
        id: executable

        engine: "executable"

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
        }
    }

    Kirigami.FormLayout {
        id: form

        QQC2.Label {
            Kirigami.FormData.label: i18n("Engine")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("PipeWire:")

            QQC2.Button {
                text: i18n("Restart Engine")
                icon.name: "view-refresh"
                onClicked: root.runUjust("restart-pipewire")
            }

            QQC2.Button {
                text: i18n("CPU Performance")
                icon.name: "cpu"
                onClicked: root.runUjust("cpu-performance")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Bluetooth:")

            QQC2.Button {
                text: i18n("Toggle Headset Mic")
                icon.name: "preferences-system-bluetooth"
                onClicked: root.runUjust("toggle-bt-mic")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Routing")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Virtual channels:")

            QQC2.Button {
                text: i18n("Create")
                icon.name: "list-add"
                onClicked: root.runUjust("setup-virtual-channels create")
            }

            QQC2.Button {
                text: i18n("Remove")
                icon.name: "list-remove"
                onClicked: root.runUjust("setup-virtual-channels remove")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("JACK compatibility:")

            QQC2.Button {
                text: i18n("Enable")
                icon.name: "media-playback-start"
                onClicked: root.runUjust("use-legacy-audio start")
            }

            QQC2.Button {
                text: i18n("Remove")
                icon.name: "edit-delete-remove"
                onClicked: root.runUjust("use-legacy-audio remove")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Legacy MIDI:")

            QQC2.Button {
                text: i18n("ALSA to JACK")
                icon.name: "network-connect"
                onClicked: root.runUjust("add-legacy-channels a2j")
            }

            QQC2.Button {
                text: i18n("Native")
                icon.name: "network-wired"
                onClicked: root.runUjust("add-legacy-channels native")
            }

            QQC2.Button {
                text: i18n("Remove")
                icon.name: "list-remove"
                onClicked: root.runUjust("add-legacy-channels remove")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Plugin Bridge")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("yabridge:")

            QQC2.Button {
                text: i18n("Set Up")
                icon.name: "run-build"
                onClicked: root.runUjust("setup-audio")
            }

            QQC2.Button {
                text: i18n("Sync")
                icon.name: "view-refresh"
                onClicked: root.runUjust("update-audio")
            }

            QQC2.Button {
                text: i18n("Route Plugins")
                icon.name: "folder-sync"
                onClicked: root.runUjust("route-plugins")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Diagnostics:")

            QQC2.Button {
                text: i18n("Scan Plugins")
                icon.name: "tools-report-bug"
                onClicked: root.runUjust("plugin-diagnose")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Windows VST Fixes")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Process isolation:")

            QQC2.Button {
                text: i18n("Enable")
                icon.name: "security-high"
                onClicked: root.runUjust("vst-iso enable")
            }

            QQC2.Button {
                text: i18n("Disable")
                icon.name: "security-low"
                onClicked: root.runUjust("vst-iso disable")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("JUCE rendering:")

            QQC2.Button {
                text: i18n("DXVK Clamp")
                icon.name: "preferences-desktop-display"
                onClicked: root.runUjust("juce-fix dxvk")
            }

            QQC2.Button {
                text: i18n("Wine Desktop")
                icon.name: "window"
                onClicked: root.runUjust("juce-fix desktop")
            }

            QQC2.Button {
                text: i18n("Reset")
                icon.name: "edit-undo"
                onClicked: root.runUjust("juce-fix reset")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            visible: root.lastCommand.length > 0
            type: Kirigami.MessageType.Information
            text: i18n("Opened a terminal for: %1", root.lastCommand)
        }

        QQC2.Label {
            Layout.fillWidth: true
            Kirigami.FormData.isSection: true
            text: i18n("Commands run in Konsole so interactive prompts, sudo requests, and command output stay visible.")
            wrapMode: Text.Wrap
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
