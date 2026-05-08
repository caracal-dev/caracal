/*
    SPDX-FileCopyrightText: 2026 Caracal OS

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "black"

    property int stage

    onStageChanged: {
        if (stage >= 1) {
            introAnimation.running = true;
        }
    }

    width: 1280
    height: 800

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            readonly property real size: Kirigami.Units.gridUnit * 8

            anchors.centerIn: parent

            asynchronous: true
            source: "images/caracal-logo.svg"

            sourceSize.width: size
            sourceSize.height: size
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.veryLongDuration * 2
        easing.type: Easing.InOutQuad
    }

    states: [
        State {
            name: "ready"
            when: stage >= 5
            PropertyChanges {
                target: root
                opacity: 0
            }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "ready"
            NumberAnimation {
                property: "opacity"
                duration: Kirigami.Units.veryLongDuration
                easing.type: Easing.InOutQuad
            }
        }
    ]
}
