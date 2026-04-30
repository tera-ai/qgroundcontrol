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

// Always-visible debug panel for ArduPilot EKF2 "control" parameters
// (EKF2_EV_CTRL and EKF2_GPS_CTRL).
//
// One row per param. If a param doesn't exist on the connected autopilot
// (e.g. PX4, or before the param list has loaded) the row renders
// "Null/NA" in place of the value + bit badges, so the panel is useful
// as a diagnostic even when nothing is wired up yet.
//
// Each row's bitmask is rendered as a row of clickable badges. Clicking a
// badge toggles that bit and writes the new value back through the Fact
// (i.e. PARAM_SET to the autopilot). The displayed value is bound to
// fact.rawValue so it also updates when the param is changed elsewhere.
//
// Implementation note: FactPanelController exposes its `vehicle` Q_PROPERTY
// as CONSTANT, fixed to whatever MultiVehicleManager.activeVehicle was at
// construction. If we just instantiated a FactPanelController directly here
// then on first load (before any real vehicle has connected) it'd
// permanently bind to the offline-editing vehicle and never see real
// params. We wrap the FactPanelController-backed content in a Loader and
// force-reload it on every activeVehicleChanged so a fresh controller is
// constructed against the live ParameterManager.
Item {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    visible:    true
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

            // The actual rows live inside this Loader so we can rebuild
            // them (and the FactPanelController inside) whenever the active
            // vehicle changes. Always active so the box renders even with
            // no vehicle (rows just show "Null/NA").
            Loader {
                id:                 contentLoader
                active:             true
                sourceComponent:    rowsComponent

                function reload() {
                    var sc = sourceComponent
                    sourceComponent = null
                    sourceComponent = sc
                }

                Connections {
                    target: QGroundControl.multiVehicleManager
                    function onActiveVehicleChanged() { contentLoader.reload() }
                }
            }
        }
    }

    Component {
        id: rowsComponent

        Item {
            id: rowsRoot

            // EV_CTRL bit names (ArduPilot bitmask):
            //   bit0 X-Y POS, bit1 Z POS, bit2 X-Y VEL, bit3 Z VEL,
            //   bit4 YAW, bit5 ERR_LARGE, bit6 ERR_SMALL.
            readonly property var _evCtrlBits:
                ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW","ERR_LRG","ERR_SML"]
            // GPS_CTRL bit names (best-effort): bit0 X-Y POS, bit1 Z POS,
            // bit2 X-Y VEL, bit3 Z VEL, bit4 YAW. Bits beyond the known
            // names render as "bitN".
            readonly property var _gpsCtrlBits:
                ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW"]

            FactPanelController { id: ctrl }

            // Reactive triggers so the per-row _fact lookups re-run as the
            // parameter list loads. Both are real Q_PROPERTY-backed
            // notifiers on ParameterManager so QML's binding tracker sees
            // them when read directly inside a binding expression.
            property var  _paramMgr:     ctrl.vehicle ? ctrl.vehicle.parameterManager : null
            property bool _paramsReady:  _paramMgr ? _paramMgr.parametersReady : false
            property real _loadProgress: _paramMgr ? _paramMgr.loadProgress    : 0

            function _hex(value) {
                var v = (value | 0)
                if (v < 0) v = v >>> 0
                return "0x" + v.toString(16).toUpperCase()
            }

            width:  paramsColumn.width
            height: paramsColumn.height

            Column {
                id:         paramsColumn
                spacing:    ScreenTools.defaultFontPixelWidth * 0.5

                Repeater {
                    model: [
                        { name: "EKF2_EV_CTRL",  bits: rowsRoot._evCtrlBits  },
                        { name: "EKF2_GPS_CTRL", bits: rowsRoot._gpsCtrlBits }
                    ]

                    // One row per known param. If the param exists, show
                    // hex value + clickable bit badges. If not, show
                    // "Null/NA" in place of the value + badges.
                    delegate: Column {
                        id: paramRow

                        // Reading _paramsReady AND _loadProgress directly in
                        // this binding expression makes QML re-evaluate it
                        // whenever the parameter manager makes progress
                        // or finishes loading. getParameterFact returns
                        // null when the param doesn't exist (with
                        // reportMissing=false) so this gives us a single
                        // reactive source of truth for the row.
                        property var _fact: {
                            // Force QML dependency tracking on these
                            // properties even though their values are not
                            // used in the result.
                            var _r = rowsRoot._paramsReady
                            var _p = rowsRoot._loadProgress
                            return rowsRoot._paramMgr
                                ? ctrl.getParameterFact(-1, modelData.name, false)
                                : null
                        }
                        property int _value: _fact ? (_fact.rawValue | 0) : 0
                        spacing: ScreenTools.defaultFontPixelWidth * 0.15

                        Row {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel {
                                text:           modelData.name
                                color:          paramRow._fact ? "#AAAAAA" : "#666666"
                                font.pointSize: ScreenTools.smallFontPointSize
                                font.bold:      true
                                width:          ScreenTools.defaultFontPixelWidth * 13
                            }
                            QGCLabel {
                                text:           paramRow._fact
                                                    ? rowsRoot._hex(paramRow._value)
                                                    : qsTr("Null/NA")
                                color:          paramRow._fact ? "white" : "#888888"
                                font.bold:      true
                                font.italic:    !paramRow._fact
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }

                        // Bit badges only render when the fact actually
                        // exists. For missing params there's nothing to
                        // toggle, so the "Null/NA" label above stands alone.
                        Flow {
                            visible:    paramRow._fact !== null
                            spacing:    ScreenTools.defaultFontPixelWidth * 0.25
                            width:      ScreenTools.defaultFontPixelWidth * 26

                            Repeater {
                                // Known-name badges + any extra "bitN"
                                // entries for set bits beyond the named
                                // ones, so unknown bits can still be
                                // toggled off if needed.
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
        }
    }
}
