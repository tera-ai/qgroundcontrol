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
// Each row renders the bitmask as a row of clickable badges. Clicking a badge
// toggles that bit and writes the new value back through the Fact (i.e. the
// param gets PARAM_SET to the autopilot). The displayed value is bound to
// fact.rawValue so it also updates automatically when the param is changed
// elsewhere (e.g. from the standard parameter editor or a GCS command).
Item {
    id: root

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
            spacing:            ScreenTools.defaultFontPixelWidth * 0.4

            QGCLabel {
                text:                       qsTr("EKF Control")
                color:                      "#80DEEA"
                font.bold:                  true
                font.pointSize:             ScreenTools.smallFontPointSize
                anchors.horizontalCenter:   parent.horizontalCenter
            }

            QGCLabel {
                text:                       qsTr("Click a badge to toggle")
                color:                      "#666666"
                font.pointSize:             ScreenTools.smallFontPointSize * 0.8
                anchors.horizontalCenter:   parent.horizontalCenter
            }

            Column {
                id:         paramsColumn
                spacing:    ScreenTools.defaultFontPixelWidth * 0.5

                Repeater {
                    model: [
                        { name: "EK2_EV_CTRL",  bits: root._evCtrlBits  },
                        { name: "EK2_GPS_CTRL", bits: root._gpsCtrlBits },
                        { name: "EK3_EV_CTRL",  bits: root._evCtrlBits  },
                        { name: "EK3_GPS_CTRL", bits: root._gpsCtrlBits }
                    ]

                    // One row per param: [ NAME : 0xVAL ] [bit0][bit1]...
                    delegate: Column {
                        id:         paramRow
                        property var _fact:    root._factOrNull(modelData.name)
                        // Bound to fact.rawValue so external changes update us.
                        property int _value:   _fact ? (_fact.rawValue | 0) : 0
                        visible:    _fact !== null
                        spacing:    ScreenTools.defaultFontPixelWidth * 0.15

                        Row {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel {
                                text:           modelData.name
                                color:          "#AAAAAA"
                                font.pointSize: ScreenTools.smallFontPointSize
                                font.bold:      true
                                width:          ScreenTools.defaultFontPixelWidth * 13
                            }
                            QGCLabel {
                                text:           root._hex(paramRow._value)
                                color:          "white"
                                font.bold:      true
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }

                        // Clickable bit badges. We render one badge per known
                        // bit name (length of bits array). If the param value
                        // has bits set beyond the known names, append extra
                        // "bitN" badges so the user can still toggle them off.
                        Flow {
                            spacing:    ScreenTools.defaultFontPixelWidth * 0.25
                            width:      ScreenTools.defaultFontPixelWidth * 26

                            Repeater {
                                // Show known-name badges + any extra set bits beyond them.
                                model: {
                                    var names = modelData.bits.slice()
                                    var v = paramRow._value
                                    for (var i = names.length; i < 32; ++i) {
                                        if (v & (1 << i)) {
                                            names.push("bit" + i)
                                        }
                                    }
                                    return names
                                }

                                delegate: Rectangle {
                                    id:             badge
                                    property int   _bitIndex: index
                                    property int   _bitMask:  (1 << _bitIndex)
                                    property bool  _on:       (paramRow._value & _bitMask) !== 0

                                    width:          badgeText.width  + ScreenTools.defaultFontPixelWidth
                                    height:         badgeText.height + ScreenTools.defaultFontPixelWidth * 0.3
                                    radius:         ScreenTools.defaultFontPixelWidth * 0.25
                                    color:          _on ? "#1976D2" : "#222222"
                                    border.color:   _on ? "#80DEEA"
                                                        : (badgeMouse.containsMouse ? "#666666" : "#444444")
                                    border.width:   1

                                    QGCLabel {
                                        id:                 badgeText
                                        text:               modelData
                                        anchors.centerIn:   parent
                                        color:              badge._on ? "white" : "#888888"
                                        font.pointSize:     ScreenTools.smallFontPointSize * 0.85
                                        font.bold:          badge._on
                                    }

                                    MouseArea {
                                        id:             badgeMouse
                                        anchors.fill:   parent
                                        hoverEnabled:   true
                                        cursorShape:    Qt.PointingHandCursor
                                        onClicked: {
                                            if (!paramRow._fact) return
                                            // XOR-toggle the bit and write back. The Fact's
                                            // rawValueChanged signal will re-evaluate _value
                                            // for everyone bound to it.
                                            var newVal = (paramRow._value ^ badge._bitMask) >>> 0
                                            paramRow._fact.rawValue = newVal
                                        }
                                    }
                                }
                            }
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

