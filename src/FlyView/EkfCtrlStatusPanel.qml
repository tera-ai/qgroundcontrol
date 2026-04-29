/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Surfaces ArduPilot EKF "control" parameters (EK2/EK3 _EV_CTRL and _GPS_CTRL)
// directly on the Fly view. Self-hides if none of these params exist on the
// connected autopilot (e.g. PX4 will simply hide the panel).
//
// Includes a "pop out" button that asks the main window to spawn a separate
// native window showing this same panel (see MainWindow.createWindowedQmlPage).
Item {
    id: root

    // Popped-out instances should not have their own pop-out button.
    property bool popped: false

    // EV_CTRL bit names. ArduPilot's bitmask: bit0 X-Y POS, bit1 Z POS,
    // bit2 X-Y VEL, bit3 Z VEL, bit4 YAW, bit5 ERR_LARGE, bit6 ERR_SMALL.
    readonly property var _evCtrlBits:
        ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW","ERR_LRG","ERR_SML"]
    // GPS_CTRL bit names. Best-effort: bit0 X-Y POS, bit1 Z POS, bit2 X-Y VEL,
    // bit3 Z VEL, bit4 YAW. Bits beyond the array length render as "bit N".
    readonly property var _gpsCtrlBits:
        ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW"]

    FactPanelController { id: ctrl }

    function _exists(name) {
        return ctrl.parameterExists(-1, name)
    }
    function _factOrNull(name) {
        return _exists(name) ? ctrl.getParameterFact(-1, name, false) : null
    }
    function _decodeBits(value, names) {
        var v = (value | 0)
        if (v === 0) return qsTr("(none)")
        var parts = []
        for (var i = 0; i < 32; ++i) {
            if (v & (1 << i)) {
                if (i < names.length) parts.push(names[i])
                else                  parts.push("bit" + i)
            }
        }
        return parts.join("|")
    }
    function _hex(value) {
        var v = (value | 0)
        if (v < 0) v = v >>> 0
        return "0x" + v.toString(16).toUpperCase()
    }

    property bool ek2Available:
        _exists("EK2_EV_CTRL") || _exists("EK2_GPS_CTRL")
    property bool ek3Available:
        _exists("EK3_EV_CTRL") || _exists("EK3_GPS_CTRL")
    property bool anyAvailable: ek2Available || ek3Available

    visible:    anyAvailable
    width:      panelRect.width
    height:     panelRect.height

    Rectangle {
        id:     panelRect
        radius: ScreenTools.defaultFontPixelWidth * 0.5
        color:  Qt.rgba(0, 0, 0, 0.75)
        width:  contentColumn.width  + ScreenTools.defaultFontPixelWidth  * 2
        height: contentColumn.height + ScreenTools.defaultFontPixelWidth * 1.5

        Column {
            id:                 contentColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.25

            // Header row: title + pop-out button
            RowLayout {
                width:                  paramsColumn.width
                spacing:                ScreenTools.defaultFontPixelWidth * 0.5

                QGCLabel {
                    text:                   qsTr("EKF Control")
                    color:                  "#80DEEA"
                    font.bold:              true
                    font.pointSize:         ScreenTools.smallFontPointSize
                    Layout.fillWidth:       true
                }

                // Pop-out button (suppressed if we are already a popped window)
                Rectangle {
                    visible:                !root.popped
                    width:                  popLabel.width  + ScreenTools.defaultFontPixelWidth
                    height:                 popLabel.height + ScreenTools.defaultFontPixelWidth * 0.4
                    radius:                 ScreenTools.defaultFontPixelWidth * 0.25
                    color:                  popMouse.pressed ? "#444444"
                                            : (popMouse.containsMouse ? "#333333" : "#222222")
                    border.color:           "#555555"
                    border.width:           1
                    Layout.alignment:       Qt.AlignRight

                    QGCLabel {
                        id:                 popLabel
                        text:               qsTr("Pop Out")
                        color:              "#80DEEA"
                        font.pointSize:     ScreenTools.smallFontPointSize * 0.85
                        anchors.centerIn:   parent
                    }
                    MouseArea {
                        id:                 popMouse
                        anchors.fill:       parent
                        hoverEnabled:       true
                        onClicked: {
                            if (mainWindow && mainWindow.createWindowedQmlPage) {
                                mainWindow.createWindowedQmlPage(
                                    qsTr("EKF Control"),
                                    "qrc:/qml/QGroundControl/FlyView/EkfCtrlStatusPanel.qml")
                            }
                        }
                    }
                }
            }

            Column {
                id:         paramsColumn
                spacing:    ScreenTools.defaultFontPixelWidth * 0.2

                Repeater {
                    model: [
                        { name: "EK2_EV_CTRL",  bits: root._evCtrlBits  },
                        { name: "EK2_GPS_CTRL", bits: root._gpsCtrlBits },
                        { name: "EK3_EV_CTRL",  bits: root._evCtrlBits  },
                        { name: "EK3_GPS_CTRL", bits: root._gpsCtrlBits }
                    ]

                    delegate: Row {
                        property var _fact:    root._factOrNull(modelData.name)
                        property int _value:   _fact ? _fact.rawValue : 0
                        visible: _fact !== null
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5

                        QGCLabel {
                            text:           modelData.name + ":"
                            color:          "#AAAAAA"
                            font.pointSize: ScreenTools.smallFontPointSize
                            width:          ScreenTools.defaultFontPixelWidth * 13
                        }
                        QGCLabel {
                            text:           root._hex(_value)
                            color:          "white"
                            font.bold:      true
                            font.pointSize: ScreenTools.smallFontPointSize
                            width:          ScreenTools.defaultFontPixelWidth * 6
                        }
                        QGCLabel {
                            text:           "(" + root._decodeBits(_value, modelData.bits) + ")"
                            color:          "#80DEEA"
                            font.pointSize: ScreenTools.smallFontPointSize * 0.9
                        }
                    }
                }
            }

            QGCLabel {
                visible:        !root.anyAvailable
                text:           qsTr("(no EK2/EK3 params on this autopilot)")
                color:          "#888888"
                font.pointSize: ScreenTools.smallFontPointSize * 0.85
            }
        }
    }
}

