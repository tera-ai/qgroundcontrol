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

// Surfaces ArduPilot EKF "control" parameters (EK2/EK3/EKF2/EKF3 _EV_CTRL and
// _GPS_CTRL) directly on the Fly view. Self-hides if none of these params
// exist on the connected autopilot (e.g. PX4 will simply hide the panel).
//
// Each row renders the bitmask as a row of clickable badges. Clicking a badge
// toggles that bit and writes the new value back through the Fact (i.e. the
// param gets PARAM_SET to the autopilot). The displayed value is bound to
// fact.rawValue so it also updates automatically when the param is changed
// elsewhere (e.g. from the standard parameter editor or a GCS command).
//
// Implementation note: FactPanelController exposes its `vehicle` Q_PROPERTY
// as CONSTANT, fixed to whatever MultiVehicleManager.activeVehicle was when
// the controller was constructed. If we just instantiated a FactPanelController
// directly here, a panel created before any real vehicle connected would
// permanently bind to the offline-editing vehicle (which has none of these
// params) and never re-evaluate. To work around that we wrap the actual panel
// in a Loader and force-reload it whenever the active vehicle changes, so a
// fresh FactPanelController is constructed against the new vehicle.
Item {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    // Surface the loaded panel's intrinsic geometry + visibility so the
    // surrounding FlyViewCustomLayer.qml can lay this out and adjust its
    // tool insets correctly.
    visible: contentLoader.item ? contentLoader.item.visible : false
    width:   contentLoader.item ? contentLoader.item.width   : 0
    height:  contentLoader.item ? contentLoader.item.height  : 0

    Loader {
        id:                 contentLoader
        // Only build the controller-backed content once we have a real,
        // connected vehicle. The offline-editing vehicle never holds the EKF
        // params we care about so loading against it just wastes work.
        active:             root._activeVehicle !== null
                            && !root._activeVehicle.isOfflineEditingVehicle
        sourceComponent:    ekfContent

        // Rebuild on every vehicle change so the embedded FactPanelController
        // (whose `vehicle` is CONSTANT) is reconstructed against the new
        // vehicle's ParameterManager.
        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged() {
                contentLoader.active = false
                var v = QGroundControl.multiVehicleManager.activeVehicle
                contentLoader.active = (v !== null) && !v.isOfflineEditingVehicle
            }
        }
    }

    Component {
        id: ekfContent

        Item {
            id: panelRoot

            // EV_CTRL bit names. ArduPilot's bitmask: bit0 X-Y POS, bit1 Z POS,
            // bit2 X-Y VEL, bit3 Z VEL, bit4 YAW, bit5 ERR_LARGE, bit6 ERR_SMALL.
            readonly property var _evCtrlBits:
                ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW","ERR_LRG","ERR_SML"]
            // GPS_CTRL bit names. Best-effort: bit0 X-Y POS, bit1 Z POS,
            // bit2 X-Y VEL, bit3 Z VEL, bit4 YAW. Bits beyond the array length
            // render as "bitN".
            readonly property var _gpsCtrlBits:
                ["X-Y POS","Z POS","X-Y VEL","Z VEL","YAW"]

            FactPanelController { id: ctrl }

            property var  _paramMgr:     ctrl.vehicle ? ctrl.vehicle.parameterManager : null
            // _paramsReady flips false -> true exactly once when ParameterManager
            // finishes downloading the full param list. _loadProgress changes
            // continuously during download. The existence-check bindings below
            // depend on BOTH of these (referenced directly so QML's binding
            // engine tracks them as dependencies, which it cannot reliably do
            // through a JS function call boundary), so they re-evaluate as
            // params stream in and again when the load completes.
            property bool _paramsReady:  _paramMgr ? _paramMgr.parametersReady : false
            property real _loadProgress: _paramMgr ? _paramMgr.loadProgress : 0

            // One direct property binding per checked param. Each reads
            // _paramsReady and _loadProgress so QML re-runs the binding as
            // params are received and again when the load is fully ready.
            // Placed inside a JS-block binding (the {}) so the dependency
            // tracker sees the property reads even though the result only
            // depends on parameterExists().
            property bool _ek2EvExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EK2_EV_CTRL") : false
            }
            property bool _ek2GpsExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EK2_GPS_CTRL") : false
            }
            property bool _ekf2EvExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EKF2_EV_CTRL") : false
            }
            property bool _ekf2GpsExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EKF2_GPS_CTRL") : false
            }
            property bool _ek3EvExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EK3_EV_CTRL") : false
            }
            property bool _ek3GpsExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EK3_GPS_CTRL") : false
            }
            property bool _ekf3EvExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EKF3_EV_CTRL") : false
            }
            property bool _ekf3GpsExists: {
                var _ = panelRoot._paramsReady; var __ = panelRoot._loadProgress
                return panelRoot._paramMgr ? ctrl.parameterExists(-1, "EKF3_GPS_CTRL") : false
            }

            function _existsByName(name) {
                switch (name) {
                case "EK2_EV_CTRL":   return panelRoot._ek2EvExists
                case "EK2_GPS_CTRL":  return panelRoot._ek2GpsExists
                case "EKF2_EV_CTRL":  return panelRoot._ekf2EvExists
                case "EKF2_GPS_CTRL": return panelRoot._ekf2GpsExists
                case "EK3_EV_CTRL":   return panelRoot._ek3EvExists
                case "EK3_GPS_CTRL":  return panelRoot._ek3GpsExists
                case "EKF3_EV_CTRL":  return panelRoot._ekf3EvExists
                case "EKF3_GPS_CTRL": return panelRoot._ekf3GpsExists
                }
                return false
            }
            function _factOrNull(name) {
                return _existsByName(name) ? ctrl.getParameterFact(-1, name, false) : null
            }
            function _hex(value) {
                var v = (value | 0)
                if (v < 0) v = v >>> 0
                return "0x" + v.toString(16).toUpperCase()
            }

            property bool ek2Available:
                _ek2EvExists || _ek2GpsExists || _ekf2EvExists || _ekf2GpsExists
            property bool ek3Available:
                _ek3EvExists || _ek3GpsExists || _ekf3EvExists || _ekf3GpsExists
            property bool anyAvailable: ek2Available || ek3Available

            // Hide entirely when the connected autopilot doesn't expose any of
            // the tracked EKF params (e.g. PX4). The bindings above re-evaluate
            // as parameters stream in.
            visible: anyAvailable
            width:   panelRect.width
            height:  panelRect.height

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
                            // Both ArduPilot-style ("EK2_*"/"EK3_*") and the
                            // longer "EKF2_*"/"EKF3_*" prefixes are probed.
                            // Rows for params that don't exist on the connected
                            // autopilot self-hide via `visible: _fact !== null`.
                            model: [
                                { name: "EK2_EV_CTRL",   bits: panelRoot._evCtrlBits  },
                                { name: "EK2_GPS_CTRL",  bits: panelRoot._gpsCtrlBits },
                                { name: "EKF2_EV_CTRL",  bits: panelRoot._evCtrlBits  },
                                { name: "EKF2_GPS_CTRL", bits: panelRoot._gpsCtrlBits },
                                { name: "EK3_EV_CTRL",   bits: panelRoot._evCtrlBits  },
                                { name: "EK3_GPS_CTRL",  bits: panelRoot._gpsCtrlBits },
                                { name: "EKF3_EV_CTRL",  bits: panelRoot._evCtrlBits  },
                                { name: "EKF3_GPS_CTRL", bits: panelRoot._gpsCtrlBits }
                            ]

                            // One row per param: [ NAME : 0xVAL ] [bit0][bit1]...
                            delegate: Column {
                                id:         paramRow
                                property var _fact:    panelRoot._factOrNull(modelData.name)
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
                                        text:           panelRoot._hex(paramRow._value)
                                        color:          "white"
                                        font.bold:      true
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                }

                                // Clickable bit badges. We render one badge per
                                // known bit name (length of bits array). If the
                                // param value has bits set beyond the known
                                // names, append extra "bitN" badges so the user
                                // can still toggle them off.
                                Flow {
                                    spacing:    ScreenTools.defaultFontPixelWidth * 0.25
                                    width:      ScreenTools.defaultFontPixelWidth * 26

                                    Repeater {
                                        // Show known-name badges + any extra
                                        // set bits beyond them.
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
                                                    // XOR-toggle the bit and
                                                    // write back. The Fact's
                                                    // rawValueChanged signal
                                                    // re-evaluates _value for
                                                    // everyone bound to it.
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
    }
}
