import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

// To implement a custom overlay copy this code to your own control in your custom code source. Then override the
// FlyViewCustomLayer.qml resource with your own qml. See the custom example and documentation for details.
Item {
    id: _root

    property var parentToolInsets               // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _toolInsets // These are the insets for your custom overlay additions
    property var mapControl

    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle

    // Path overlay toggle controls
    Rectangle {
        id:                     pathControlPanel
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.margins:        ScreenTools.defaultFontPixelWidth
        width:                  pathControlColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 pathControlColumn.height + ScreenTools.defaultFontPixelWidth * 2
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  Qt.rgba(0, 0, 0, 0.7)
        visible:                _activeVehicle

        Column {
            id:                 pathControlColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                text:               qsTr("Path Overlays")
                color:              "white"
                font.pointSize:     ScreenTools.smallFontPointSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            QGCCheckBox {
                text:               qsTr("GPS Path")
                checked:            _activeVehicle ? _activeVehicle.gpsPathPoints.enabled : false
                onClicked:          if (_activeVehicle) _activeVehicle.gpsPathPoints.enabled = checked
                
                Rectangle {
                    width:          ScreenTools.defaultFontPixelWidth * 1.5
                    height:         ScreenTools.defaultFontPixelWidth * 0.5
                    color:          "#00E04B"
                    anchors.left:   parent.right
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            QGCCheckBox {
                property bool _usingFallback: _activeVehicle ? _activeVehicle.odometryPathPoints.usingFallback : false
                property string _refType: _activeVehicle ? _activeVehicle.odometryPathPoints.referenceType : ""
                text:               _usingFallback ? qsTr("Odometry Path (%1 fallback)").arg(_refType) : qsTr("Odometry Path")
                checked:            _activeVehicle ? _activeVehicle.odometryPathPoints.enabled : false
                onClicked:          if (_activeVehicle) _activeVehicle.odometryPathPoints.enabled = checked
                
                Rectangle {
                    width:          ScreenTools.defaultFontPixelWidth * 1.5
                    height:         ScreenTools.defaultFontPixelWidth * 0.5
                    color:          "#536DFF"
                    anchors.left:   parent.right
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Estimator type legend (visible when odometry path is enabled)
            Column {
                visible:    _activeVehicle ? _activeVehicle.odometryPathPoints.enabled : false
                spacing:    ScreenTools.defaultFontPixelWidth * 0.25
                leftPadding: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text:           qsTr("Estimator Type:")
                    color:          "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    Canvas {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2, cy = height / 2, r = width / 2 - 1
                            var inner = r * 0.4
                            ctx.fillStyle = "#FFD700"
                            ctx.strokeStyle = "#536DFF"; ctx.lineWidth = 1.5
                            ctx.beginPath()
                            for (var i = 0; i < 8; i++) {
                                var rad = (i % 2 === 0) ? r : inner
                                var angle = -Math.PI / 2 + (i * Math.PI / 4)
                                var px = cx + Math.cos(angle) * rad
                                var py = cy + Math.sin(angle) * rad
                                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                            }
                            ctx.closePath(); ctx.fill(); ctx.stroke()
                        }
                    }
                    QGCLabel { text: qsTr("Mapping"); color: "white"; font.pointSize: ScreenTools.smallFontPointSize; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    Canvas {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2, cy = height / 2, r = width / 2 - 1
                            ctx.fillStyle = "#B0B0B0"
                            ctx.strokeStyle = "#536DFF"; ctx.lineWidth = 1.5
                            ctx.beginPath()
                            ctx.moveTo(cx, cy - r)
                            ctx.lineTo(cx + r * Math.cos(Math.PI / 6), cy + r * 0.5)
                            ctx.lineTo(cx - r * Math.cos(Math.PI / 6), cy + r * 0.5)
                            ctx.closePath(); ctx.fill(); ctx.stroke()
                        }
                    }
                    QGCLabel { text: qsTr("Tracking"); color: "white"; font.pointSize: ScreenTools.smallFontPointSize; anchors.verticalCenter: parent.verticalCenter }
                }

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    Canvas {
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2, cy = height / 2, r = width / 2 - 1
                            ctx.fillStyle = "#FF5252"
                            ctx.strokeStyle = "#536DFF"; ctx.lineWidth = 1.5
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.closePath(); ctx.fill(); ctx.stroke()
                        }
                    }
                    QGCLabel { text: qsTr("Propagation"); color: "white"; font.pointSize: ScreenTools.smallFontPointSize; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // since this file is a placeholder for the custom layer in a standard build, we will just pass through the parent insets
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset + (pathControlPanel.visible ? pathControlPanel.width + ScreenTools.defaultFontPixelWidth * 2 : 0)
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset + (pathControlPanel.visible ? pathControlPanel.height + ScreenTools.defaultFontPixelWidth * 2 : 0)
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }
}
