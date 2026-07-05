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
            refreshTimer.start();
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        onTriggered: kcm.refresh()
    }

    Kirigami.FormLayout {
        id: form

        QQC2.Label {
            Kirigami.FormData.label: i18n("System Performance")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("CPU Performance:")
            
            QQC2.Button {
                text: kcm.cpuPerformanceActive ? i18n("Active") : i18n("Enable")
                icon.name: "cpu"
                enabled: !kcm.cpuPerformanceActive
                onClicked: root.runUjust("cpu-performance")
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Sets CPU to maximum frequency. Recommended for low-latency recording to prevent audio glitches (xruns).")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Bluetooth Quality:")

            QQC2.Button {
                text: kcm.btMicMitigationActive ? i18n("Disable Mitigation") : i18n("Enable Mitigation")
                icon.name: "preferences-system-bluetooth"
                onClicked: root.runUjust("toggle-bt-mic")
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Prevents audio quality drop when using Bluetooth headsets, but disables the headset microphone.")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Audio Routing")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Virtual Channels:")

            QQC2.Button {
                text: i18n("Create")
                icon.name: "list-add"
                visible: !kcm.virtualChannelsActive
                onClicked: root.runUjust("setup-virtual-channels create")
            }

            QQC2.Button {
                text: i18n("Remove")
                icon.name: "list-remove"
                visible: kcm.virtualChannelsActive
                onClicked: root.runUjust("setup-virtual-channels remove")
            }
            
            QQC2.Label {
                text: kcm.virtualChannelsActive ? i18n("Configured") : i18n("Not present")
                color: Kirigami.Theme.disabledTextColor
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Adds dedicated DAW, Monitoring, Recording, and System loopback sinks for complex routing.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("JACK Compatibility:")

            QQC2.Button {
                text: kcm.jackDbusActive ? i18n("Restart") : i18n("Enable")
                icon.name: kcm.jackDbusActive ? "view-refresh" : "media-playback-start"
                onClicked: root.runUjust("use-legacy-audio start")
            }

            QQC2.Button {
                text: i18n("Disable")
                icon.name: "edit-delete-remove"
                visible: kcm.jackDbusActive
                onClicked: root.runUjust("use-legacy-audio remove")
            }

            QQC2.Label {
                text: kcm.jackDbusActive ? i18n("Running") : i18n("Inactive")
                color: Kirigami.Theme.disabledTextColor
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Allows legacy JACK applications (like Carla or Cadence) to communicate with PipeWire via D-Bus.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Legacy MIDI:")

            QQC2.Button {
                text: i18n("ALSA to JACK")
                icon.name: "network-connect"
                onClicked: root.runUjust("add-legacy-channels a2j")
                highlighted: kcm.midiBridgeType === 1
            }

            QQC2.Button {
                text: i18n("Native Bridge")
                icon.name: "network-wired"
                onClicked: root.runUjust("add-legacy-channels native")
                highlighted: kcm.midiBridgeType === 2
            }

            QQC2.Button {
                text: i18n("Disable")
                icon.name: "list-remove"
                onClicked: root.runUjust("add-legacy-channels remove")
                visible: kcm.midiBridgeType !== 0
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Bridges ALSA MIDI hardware to JACK or PipeWire for compatibility with older hardware/software.")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Windows Plugin Compatibility")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Performance Scan:")

            QQC2.Button {
                text: i18n("Scan and Optimize")
                icon.name: "tools-report-bug"
                onClicked: root.runUjust("plugin-diagnose")
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Scans your Windows VSTs for heavy license wrappers and applies Wine registry fixes to prevent deadlocks.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("VST Bridge Mode:")

            QQC2.Button {
                text: kcm.vstIsolationActive ? i18n("Disable") : i18n("Enable")
                icon.name: kcm.vstIsolationActive ? "security-low" : "security-high"
                onClicked: root.runUjust(kcm.vstIsolationActive ? "vst-iso disable" : "vst-iso enable")
            }

            QQC2.Label {
                text: kcm.vstIsolationActive ? i18n("Active") : i18n("Standard")
                color: Kirigami.Theme.disabledTextColor
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Sets REAPER's bridge flag on Windows VST plugins running via yabridge. On Linux, native VST3 plugins (Audio Assault, LSP, DISTRHO, etc.) always run inside REAPER's process regardless of this setting — bridge mode cannot contain their crashes. For native plugin stability, use 'ujust clear-plugin-caches' to remove corrupted cache files that cause convolution plugin crashes.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("JUCE Rendering Fix:")

            QQC2.Button {
                text: i18n("DXVK Clamp")
                icon.name: "preferences-desktop-display"
                highlighted: kcm.juceDxvkActive
                onClicked: root.runUjust("juce-fix dxvk")
            }

            QQC2.Button {
                text: i18n("Wine Desktop")
                icon.name: "window"
                highlighted: kcm.juceDesktopActive
                onClicked: root.runUjust("juce-fix desktop")
            }

            QQC2.Button {
                text: i18n("Reset")
                icon.name: "edit-undo"
                onClicked: root.runUjust("juce-fix reset")
                visible: kcm.juceDxvkActive || kcm.juceDesktopActive
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Fixes graphical glitches in plugins built with the JUCE framework. DXVK Clamp limits feature levels, while Wine Desktop runs them in a virtual window.")
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Maintenance")
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Audio Engine:")

            QQC2.Button {
                text: i18n("Restart PipeWire")
                icon.name: "view-refresh"
                onClicked: root.runUjust("restart-pipewire")
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18n("Restarts the PipeWire audio server. Use this if audio becomes unstable or after applying certain configuration changes.")
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
