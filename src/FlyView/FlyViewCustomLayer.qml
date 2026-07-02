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
    property bool _showNavError:    QGroundControl.settingsManager.flyViewSettings.showNavErrorPanel.rawValue

    // Toggleable: when true, the Odometry Telemetry panel exposes the
    // odom-derived roll/pitch/yaw rows AND the artificial horizon overlay is
    // driven by the odometry attitude instead of the vehicle facts.
    property bool _showOdomAttitude: false

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

            QGCCheckBox {
                text:               qsTr("Velocity Arrow")
                checked:            mapControl ? mapControl.velocityArrowEnabled : false
                onClicked:          if (mapControl) mapControl.velocityArrowEnabled = checked

                Rectangle {
                    width:          ScreenTools.defaultFontPixelWidth * 1.5
                    height:         ScreenTools.defaultFontPixelWidth * 0.5
                    color:          "#FF00C8"
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

                QGCCheckBox {
                    text:           qsTr("Plot Propagation")
                    checked:        _activeVehicle ? _activeVehicle.odometryPathPoints.plotPropagation : true
                    onClicked:      if (_activeVehicle) _activeVehicle.odometryPathPoints.plotPropagation = checked
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

    // System control buttons (start dragonfly, restart dragonfly)
    Rectangle {
        id:                     systemControlPanel
        anchors.right:          parent.right
        anchors.top:            pathControlPanel.bottom
        anchors.margins:        ScreenTools.defaultFontPixelWidth
        width:                  systemControlColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 systemControlColumn.height + ScreenTools.defaultFontPixelWidth * 2
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  Qt.rgba(0, 0, 0, 0.7)
        visible:                _activeVehicle

        // MCAP publisher liveness: the publisher beacons ODOMETRY from system
        // 77 (same channel Dragonfly uses), so a fresh odom arrival means the
        // recorder is alive. _mcapTick forces the binding to re-evaluate.
        property var  _odomPts:     _activeVehicle ? _activeVehicle.odometryPathPoints : null
        property int  _mcapTick:    0
        property bool _mcapAlive: {
            var _ = _mcapTick
            if (!_odomPts) return false
            var arrivalMs = _odomPts.lastArrivalMs
            if (!arrivalMs || arrivalMs === 0) return false
            return (Date.now() - arrivalMs) < 5000
        }

        Timer {
            interval:           1000
            repeat:             true
            running:            systemControlPanel.visible
            onTriggered:        systemControlPanel._mcapTick++
        }

        Column {
            id:                 systemControlColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                text:               qsTr("System Controls")
                color:              "white"
                font.pointSize:     ScreenTools.smallFontPointSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Start Dragonfly (host launcher service, target system 88)
            Rectangle {
                id:             startDragonflyBtn
                width:          startDragonflyLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         startDragonflyLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          startDragonflyMouse.pressed ? "#2E7D32" : (startDragonflyMouse.containsMouse ? "#43A047" : "#388E3C")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     startDragonflyLabel
                    text:                   qsTr("Start Dragonfly")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             startDragonflyMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(88, 0, 31010, 1, 0, 0, 0, 0, 0, 0)
                        }
                    }
                }
            }

            // Restart Dragonfly (relocalize hybrid nav, target system 77)
            Rectangle {
                id:             restartHybridBtn
                width:          restartHybridLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         restartHybridLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          restartHybridMouse.pressed ? "#1565C0" : (restartHybridMouse.containsMouse ? "#1E88E5" : "#1976D2")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     restartHybridLabel
                    text:                   qsTr("Restart Dragonfly")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             restartHybridMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(77, 0, 246, 1, 0, 0, 0, 0, 0, 0)
                        }
                    }
                }
            }

            // Stop Dragonfly (host launcher service, target system 88, param1 = 2)
            Rectangle {
                id:             stopDragonflyBtn
                width:          stopDragonflyLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         stopDragonflyLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          stopDragonflyMouse.pressed ? "#B71C1C" : (stopDragonflyMouse.containsMouse ? "#E53935" : "#C62828")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     stopDragonflyLabel
                    text:                   qsTr("Stop Dragonfly")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             stopDragonflyMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(88, 0, 31010, 2, 0, 0, 0, 0, 0, 0)
                        }
                    }
                }
            }

            // Start MCAP publisher (host launcher system 88, MAV_CMD_USER_2 / 31011, param1=1)
            Rectangle {
                id:             startMcapBtn
                width:          startMcapLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         startMcapLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          startMcapMouse.pressed ? "#006064" : (startMcapMouse.containsMouse ? "#0097A7" : "#00838F")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     startMcapLabel
                    text:                   qsTr("Start MCAP")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             startMcapMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(88, 0, 31011, 1, 0, 0, 0, 0, 0, 0)
                        }
                    }
                }
            }

            // Stop MCAP publisher (host launcher system 88, MAV_CMD_USER_2 / 31011, param1=2)
            Rectangle {
                id:             stopMcapBtn
                width:          stopMcapLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         stopMcapLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          stopMcapMouse.pressed ? "#BF360C" : (stopMcapMouse.containsMouse ? "#EF6C00" : "#E65100")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     stopMcapLabel
                    text:                   qsTr("Stop MCAP")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             stopMcapMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(88, 0, 31011, 2, 0, 0, 0, 0, 0, 0)
                        }
                    }
                }
            }

            // MCAP publisher status light (green when a sys-77 odom beacon was
            // seen within the last 5 s, red otherwise)
            Row {
                spacing:                  ScreenTools.defaultFontPixelWidth * 0.5
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width:                  ScreenTools.defaultFontPixelWidth * 1.2
                    height:                 width
                    radius:                 width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color:                  systemControlPanel._mcapAlive ? "#00E04B" : "#FF5252"
                    border.color:           "#000000"
                    border.width:           1
                }

                QGCLabel {
                    text:                   qsTr("MCAP Publisher")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // GPS Raw telemetry box (above the existing bottom-right telemetry bar)
    Rectangle {
        id:                     gpsTelemetryPanel
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        anchors.bottomMargin:   parentToolInsets.bottomEdgeRightInset + ScreenTools.defaultFontPixelWidth
        width:                  gpsTelemetryColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 gpsTelemetryColumn.height + ScreenTools.defaultFontPixelWidth * 1.5
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  Qt.rgba(0, 0, 0, 0.75)
        visible:                _activeVehicle

        property var  _gps:         _activeVehicle ? _activeVehicle.gps : null
        property var  _gpsPath:     _activeVehicle ? _activeVehicle.gpsPathPoints : null
        property real _gpsSpeed:    _gps ? _gps.speed.rawValue : NaN
        property real _gpsAlt:      _gps ? _gps.alt.rawValue : NaN
        property real _gpsDist:     _gpsPath ? _gpsPath.totalDistance : 0
        property real _gpsDistHome: _gpsPath ? _gpsPath.distanceToHome : 0
        property int  _gpsLock:     _gps ? _gps.lock.rawValue : 0
        property int  _gpsSats:     _gps ? _gps.count.rawValue : 0

        Column {
            id:                 gpsTelemetryColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.25

            QGCLabel {
                text:               qsTr("GPS Raw Telemetry")
                color:              "#00E04B"
                font.pointSize:     ScreenTools.smallFontPointSize
                font.bold:          true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // GPS Speed
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Speed:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 8
                }
                QGCLabel {
                    text:           isNaN(gpsTelemetryPanel._gpsSpeed) ? "---" : gpsTelemetryPanel._gpsSpeed.toFixed(2) + " m/s"
                    color:          "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // GPS Altitude MSL
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Alt (MSL):")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 8
                }
                QGCLabel {
                    text:           isNaN(gpsTelemetryPanel._gpsAlt) ? "---" : gpsTelemetryPanel._gpsAlt.toFixed(1) + " m"
                    color:          "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // GPS Distance Covered
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Dist Covr:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 8
                }
                QGCLabel {
                    text:           gpsTelemetryPanel._gpsDist < 1000
                                        ? gpsTelemetryPanel._gpsDist.toFixed(1) + " m"
                                        : (gpsTelemetryPanel._gpsDist / 1000.0).toFixed(2) + " km"
                    color:          "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // GPS Distance to Home
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Dist Home:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 8
                }
                QGCLabel {
                    text:           gpsTelemetryPanel._gpsDistHome < 1000
                                        ? gpsTelemetryPanel._gpsDistHome.toFixed(1) + " m"
                                        : (gpsTelemetryPanel._gpsDistHome / 1000.0).toFixed(2) + " km"
                    color:          "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // GPS Fix + Sats
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Fix/Sats:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 8
                }
                QGCLabel {
                    property var _lockNames: ["None", "No Fix", "2D", "3D", "DGPS", "RTK Float", "RTK Fixed", "Static"]
                    text:           (gpsTelemetryPanel._gpsLock >= 0 && gpsTelemetryPanel._gpsLock < _lockNames.length
                                        ? _lockNames[gpsTelemetryPanel._gpsLock] : "?") + " / " + gpsTelemetryPanel._gpsSats
                    color:          gpsTelemetryPanel._gpsLock >= 3 ? "#00E04B" : (gpsTelemetryPanel._gpsLock >= 2 ? "#FFD700" : "#FF5252")
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }
    }

    // Navigation Error Panel (GPS vs Odometry)
    Rectangle {
        id:                     navErrorPanel
        anchors.left:           parent.left
        anchors.bottom:         parent.bottom
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.bottomMargin:   parentToolInsets.bottomEdgeLeftInset + ScreenTools.defaultFontPixelWidth
        width:                  navErrorColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 navErrorColumn.height + ScreenTools.defaultFontPixelWidth * 1.5
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  Qt.rgba(0, 0, 0, 0.75)
        visible:                _activeVehicle && _showNavError

        property var  odomPts:  _activeVehicle ? _activeVehicle.odometryPathPoints : null
        property var  gpsPts:   _activeVehicle ? _activeVehicle.gpsPathPoints : null
        property var  odomLast: odomPts ? odomPts.lastPoint : null
        property var  gpsLast:  gpsPts  ? gpsPts.lastPoint  : null

        property real currentError: NaN
        property real minError:     NaN
        property real maxError:     NaN
        property real avgError:     NaN
        property int  sampleCount:  0
        property real errorSum:     0
        property var  errorHistory: []
        readonly property int maxHistory: 60

        onOdomLastChanged: recomputeError()

        function recomputeError() {
            if (!odomLast || !gpsLast) return
            if (!odomLast.isValid || !gpsLast.isValid) return
            var d = gpsLast.distanceTo(odomLast)
            if (isNaN(d) || d > 50000) return

            currentError = d
            sampleCount++
            errorSum += d
            avgError = errorSum / sampleCount
            if (isNaN(minError) || d < minError) minError = d
            if (isNaN(maxError) || d > maxError) maxError = d

            var h = errorHistory.slice()
            h.push(d)
            if (h.length > maxHistory) h.shift()
            errorHistory = h

            errorSparkline.requestPaint()
        }

        function resetStats() {
            currentError = NaN; minError = NaN; maxError = NaN; avgError = NaN
            sampleCount = 0; errorSum = 0; errorHistory = []
            errorSparkline.requestPaint()
        }

        Column {
            id:                 navErrorColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.25

            QGCLabel {
                text:               qsTr("Nav Error (GPS vs Odom)")
                color:              "#FF9800"
                font.pointSize:     ScreenTools.smallFontPointSize
                font.bold:          true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: ScreenTools.defaultFontPixelWidth * 0.3
                QGCLabel {
                    text:           isNaN(navErrorPanel.currentError) ? "---" : navErrorPanel.currentError.toFixed(3)
                    color:          isNaN(navErrorPanel.currentError) ? "#AAAAAA" : (navErrorPanel.currentError < 1.0 ? "#00E04B" : (navErrorPanel.currentError < 5.0 ? "#FFD700" : "#FF5252"))
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.bold:      true
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCLabel {
                    text:           "m"
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                Column {
                    spacing: 1
                    QGCLabel { text: qsTr("Min"); color: "#777777"; font.pointSize: ScreenTools.smallFontPointSize * 0.85; anchors.horizontalCenter: parent.horizontalCenter }
                    QGCLabel { text: isNaN(navErrorPanel.minError) ? "---" : navErrorPanel.minError.toFixed(2) + " m"; color: "#00E04B"; font.pointSize: ScreenTools.smallFontPointSize; anchors.horizontalCenter: parent.horizontalCenter }
                }
                Column {
                    spacing: 1
                    QGCLabel { text: qsTr("Avg"); color: "#777777"; font.pointSize: ScreenTools.smallFontPointSize * 0.85; anchors.horizontalCenter: parent.horizontalCenter }
                    QGCLabel { text: isNaN(navErrorPanel.avgError) ? "---" : navErrorPanel.avgError.toFixed(2) + " m"; color: "#FFD700"; font.pointSize: ScreenTools.smallFontPointSize; anchors.horizontalCenter: parent.horizontalCenter }
                }
                Column {
                    spacing: 1
                    QGCLabel { text: qsTr("Max"); color: "#777777"; font.pointSize: ScreenTools.smallFontPointSize * 0.85; anchors.horizontalCenter: parent.horizontalCenter }
                    QGCLabel { text: isNaN(navErrorPanel.maxError) ? "---" : navErrorPanel.maxError.toFixed(2) + " m"; color: "#FF5252"; font.pointSize: ScreenTools.smallFontPointSize; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            QGCLabel {
                text:           qsTr("Samples: %1").arg(navErrorPanel.sampleCount)
                color:          "#777777"
                font.pointSize: ScreenTools.smallFontPointSize * 0.85
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Canvas {
                id:     errorSparkline
                width:  ScreenTools.defaultFontPixelWidth * 18
                height: ScreenTools.defaultFontPixelWidth * 5
                anchors.horizontalCenter: parent.horizontalCenter

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var hist = navErrorPanel.errorHistory
                    if (!hist || hist.length < 2) {
                        ctx.fillStyle = "#333333"
                        ctx.fillRect(0, 0, width, height)
                        ctx.fillStyle = "#555555"
                        ctx.font = "10px sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText("waiting for data...", width / 2, height / 2 + 4)
                        return
                    }

                    ctx.fillStyle = "#1A1A1A"
                    ctx.fillRect(0, 0, width, height)

                    var minVal = hist[0], maxVal = hist[0]
                    for (var i = 1; i < hist.length; i++) {
                        if (hist[i] < minVal) minVal = hist[i]
                        if (hist[i] > maxVal) maxVal = hist[i]
                    }
                    var range = maxVal - minVal
                    if (range < 0.01) range = 0.01
                    var pad = 3
                    var plotH = height - pad * 2
                    var plotW = width - pad * 2

                    ctx.beginPath()
                    ctx.moveTo(pad, pad + plotH)
                    for (var j = 0; j < hist.length; j++) {
                        var px = pad + (j / (hist.length - 1)) * plotW
                        var py = pad + plotH - ((hist[j] - minVal) / range) * plotH
                        ctx.lineTo(px, py)
                    }
                    ctx.lineTo(pad + plotW, pad + plotH)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(1, 0.6, 0, 0.15)
                    ctx.fill()

                    ctx.beginPath()
                    for (var k = 0; k < hist.length; k++) {
                        var lx = pad + (k / (hist.length - 1)) * plotW
                        var ly = pad + plotH - ((hist[k] - minVal) / range) * plotH
                        if (k === 0) ctx.moveTo(lx, ly); else ctx.lineTo(lx, ly)
                    }
                    ctx.strokeStyle = "#FF9800"
                    ctx.lineWidth = 1.5
                    ctx.stroke()

                    var lastX = pad + plotW
                    var lastY = pad + plotH - ((hist[hist.length - 1] - minVal) / range) * plotH
                    ctx.beginPath()
                    ctx.arc(lastX, lastY, 3, 0, 2 * Math.PI)
                    ctx.fillStyle = "#FF9800"
                    ctx.fill()

                    ctx.fillStyle = "#666666"
                    ctx.font = "9px sans-serif"
                    ctx.textAlign = "left"
                    ctx.fillText(maxVal.toFixed(1), pad + 1, pad + 8)
                    ctx.fillText(minVal.toFixed(1), pad + 1, height - pad)
                }
            }

            Rectangle {
                width:  resetLabel.width + ScreenTools.defaultFontPixelWidth * 1.5
                height: resetLabel.height + ScreenTools.defaultFontPixelWidth * 0.5
                radius: ScreenTools.defaultFontPixelWidth * 0.2
                color:  resetMouse.pressed ? "#555555" : (resetMouse.containsMouse ? "#444444" : "#333333")
                anchors.horizontalCenter: parent.horizontalCenter
                QGCLabel {
                    id: resetLabel; text: qsTr("Reset Stats"); color: "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize * 0.85; anchors.centerIn: parent
                }
                MouseArea {
                    id: resetMouse; anchors.fill: parent; hoverEnabled: true
                    onClicked: navErrorPanel.resetStats()
                }
            }
        }
    }

    // Odometry Telemetry: timing + per-type ages + optional R/P/Y readout
    Rectangle {
        id:                     odomTelemetryPanel
        anchors.left:           parent.left
        anchors.bottom:         navErrorPanel.visible ? navErrorPanel.top : parent.bottom
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.bottomMargin:   navErrorPanel.visible
                                    ? ScreenTools.defaultFontPixelWidth
                                    : parentToolInsets.bottomEdgeLeftInset + ScreenTools.defaultFontPixelWidth
        width:                  odomTelemetryColumn.width + ScreenTools.defaultFontPixelWidth * 2
        height:                 odomTelemetryColumn.height + ScreenTools.defaultFontPixelWidth * 1.5
        radius:                 ScreenTools.defaultFontPixelWidth * 0.5
        color:                  Qt.rgba(0, 0, 0, 0.75)
        visible:                _activeVehicle && _activeVehicle.odometryPathPoints
                                && _activeVehicle.odometryPathPoints.enabled

        property var  odomPts:  _activeVehicle ? _activeVehicle.odometryPathPoints : null
        // Tick property bumped by the timer so all "ago" labels re-evaluate
        // even when no new C++ signal fires.
        property int  _tick:    0

        Timer {
            interval:           100
            repeat:             true
            running:            odomTelemetryPanel.visible
            onTriggered:        odomTelemetryPanel._tick++
        }

        function _msAgo(arrivalMs) {
            if (!arrivalMs || arrivalMs === 0) return -1
            // Reference _tick so this re-evaluates each timer tick.
            var _ = odomTelemetryPanel._tick
            return Date.now() - arrivalMs
        }

        function _ageColor(ms) {
            if (ms < 0)       return "#AAAAAA"
            if (ms < 1000)    return "#00E04B"
            if (ms < 3000)    return "#FFD700"
            return "#FF5252"
        }

        function _formatAgo(ms) {
            if (ms < 0)       return "---"
            if (ms < 1000)    return ms.toFixed(0) + " ms"
            return (ms / 1000.0).toFixed(2) + " s"
        }

        function _droneLatencyMs() {
            var _ = odomTelemetryPanel._tick
            if (!odomPts) return NaN
            var lastUsec = odomPts.lastDroneUsec
            if (!lastUsec || lastUsec === 0) return NaN
            // Heuristic: > 1e15 us ~= year 2001 -> almost certainly a UNIX
            // epoch microsecond timestamp; else it's time_boot_ms expressed in
            // microseconds (i.e. autopilot uptime).
            if (lastUsec > 1000000000000000) {
                return (Date.now() * 1000 - lastUsec) / 1000.0
            }
            var droneNow = odomPts.droneNowMs()
            if (!droneNow || droneNow === 0) return NaN
            return droneNow - (lastUsec / 1000.0)
        }

        Column {
            id:                 odomTelemetryColumn
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.25

            QGCLabel {
                text:               qsTr("Odometry Telemetry")
                color:              "#536DFF"
                font.pointSize:     ScreenTools.smallFontPointSize
                font.bold:          true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Last odom (GCS arrival staleness)
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Last odom:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    property real _ms: odomTelemetryPanel.odomPts
                                       ? odomTelemetryPanel._msAgo(odomTelemetryPanel.odomPts.lastArrivalMs)
                                       : -1
                    text:           odomTelemetryPanel._formatAgo(_ms)
                    color:          odomTelemetryPanel._ageColor(_ms)
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // Drone-side latency (odom.time_usec vs estimated drone clock)
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Drone lag:")
                    color:          "#AAAAAA"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    property real _ms: odomTelemetryPanel._droneLatencyMs()
                    text:           isNaN(_ms) ? "---"
                                    : (_ms < 1000 ? _ms.toFixed(0) + " ms"
                                                  : (_ms / 1000.0).toFixed(2) + " s")
                    color:          isNaN(_ms) ? "#AAAAAA" : "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#333333" }

            // Per-estimator-type ages
            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Map:")
                    color:          "#FFD700"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    property real _ms: odomTelemetryPanel.odomPts
                                       ? odomTelemetryPanel._msAgo(odomTelemetryPanel.odomPts.mappingArrivalMs)
                                       : -1
                    text:           odomTelemetryPanel._formatAgo(_ms)
                    color:          odomTelemetryPanel._ageColor(_ms)
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Track:")
                    color:          "#B0B0B0"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    property real _ms: odomTelemetryPanel.odomPts
                                       ? odomTelemetryPanel._msAgo(odomTelemetryPanel.odomPts.trackingArrivalMs)
                                       : -1
                    text:           odomTelemetryPanel._formatAgo(_ms)
                    color:          odomTelemetryPanel._ageColor(_ms)
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCLabel {
                    text:           qsTr("Prop:")
                    color:          "#FF5252"
                    font.pointSize: ScreenTools.smallFontPointSize
                    width:          ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    property real _ms: odomTelemetryPanel.odomPts
                                       ? odomTelemetryPanel._msAgo(odomTelemetryPanel.odomPts.propagationArrivalMs)
                                       : -1
                    text:           odomTelemetryPanel._formatAgo(_ms)
                    color:          odomTelemetryPanel._ageColor(_ms)
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#333333" }

            QGCCheckBox {
                text:               qsTr("Show Odom Attitude")
                checked:            _showOdomAttitude
                onClicked:          _showOdomAttitude = checked
            }

            // Roll / Pitch / Yaw from odom quaternion (only when toggled on)
            Column {
                visible: _showOdomAttitude
                spacing: ScreenTools.defaultFontPixelWidth * 0.15

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:           qsTr("Roll:")
                        color:          "#AAAAAA"
                        font.pointSize: ScreenTools.smallFontPointSize
                        width:          ScreenTools.defaultFontPixelWidth * 9
                    }
                    QGCLabel {
                        property real _v: odomTelemetryPanel.odomPts ? odomTelemetryPanel.odomPts.odomRollDeg : NaN
                        text:           isNaN(_v) ? "---" : _v.toFixed(1) + qsTr(" deg")
                        color:          "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:           qsTr("Pitch:")
                        color:          "#AAAAAA"
                        font.pointSize: ScreenTools.smallFontPointSize
                        width:          ScreenTools.defaultFontPixelWidth * 9
                    }
                    QGCLabel {
                        property real _v: odomTelemetryPanel.odomPts ? odomTelemetryPanel.odomPts.odomPitchDeg : NaN
                        text:           isNaN(_v) ? "---" : _v.toFixed(1) + qsTr(" deg")
                        color:          "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    QGCLabel {
                        text:           qsTr("Yaw:")
                        color:          "#AAAAAA"
                        font.pointSize: ScreenTools.smallFontPointSize
                        width:          ScreenTools.defaultFontPixelWidth * 9
                    }
                    QGCLabel {
                        property real _v: odomTelemetryPanel.odomPts ? odomTelemetryPanel.odomPts.odomYawDeg : NaN
                        text:           isNaN(_v) ? "---"
                                        : (((_v % 360) + 360) % 360).toFixed(1) + qsTr(" deg")
                        color:          "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }
        }
    }

    // Standalone artificial horizon overlay (top-left). Always visible when
    // an active vehicle exists, mirroring the legacy QGC look. When
    // _showOdomAttitude is on AND odom attitude is valid, drive it from
    // odometry instead of the vehicle facts.
    Item {
        id:                 attitudeOverlay
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.topMargin:  parentToolInsets.topEdgeLeftInset + ScreenTools.defaultFontPixelWidth
        width:              ScreenTools.defaultFontPixelHeight * 7
        height:             width
        visible:            _activeVehicle

        property var  _odomPts:    _activeVehicle ? _activeVehicle.odometryPathPoints : null
        property bool _useOdomAtt: _showOdomAttitude && _odomPts
                                   && !isNaN(_odomPts.odomRollDeg)
                                   && !isNaN(_odomPts.odomPitchDeg)

        QGCAttitudeWidget {
            anchors.fill:           parent
            size:                   parent.width
            vehicle:                _activeVehicle
            showHeading:            true
            overrideEnabled:        attitudeOverlay._useOdomAtt
            overrideRollDeg:        attitudeOverlay._odomPts ? attitudeOverlay._odomPts.odomRollDeg  : 0
            overridePitchDeg:       attitudeOverlay._odomPts ? attitudeOverlay._odomPts.odomPitchDeg : 0
            overrideHeadingDeg:     attitudeOverlay._odomPts
                                    ? (((attitudeOverlay._odomPts.odomYawDeg % 360) + 360) % 360)
                                    : 0
        }

        // Tiny "AHRS" / "ODOM" source tag overlaid on the bottom-left
        QGCLabel {
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.margins:        ScreenTools.defaultFontPixelWidth * 0.5
            text:                   attitudeOverlay._useOdomAtt ? qsTr("ODOM") : qsTr("AHRS")
            color:                  attitudeOverlay._useOdomAtt ? "#536DFF" : "#FFD700"
            font.bold:              true
            font.pointSize:         ScreenTools.smallFontPointSize * 0.85
            style:                  Text.Outline
            styleColor:             "black"
        }
    }

    // EKF Control parameter status panel (EK2/EK3 EV_CTRL & GPS_CTRL).
    // Self-hides if none of the params exist on the connected autopilot.
    EkfCtrlStatusPanel {
        id:                     ekfCtrlPanel
        anchors.left:           parent.left
        anchors.top:            attitudeOverlay.visible ? attitudeOverlay.bottom : parent.top
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.topMargin:      attitudeOverlay.visible
                                    ? ScreenTools.defaultFontPixelHeight * 1.6
                                    : parentToolInsets.topEdgeLeftInset + ScreenTools.defaultFontPixelWidth
    }

    // since this file is a placeholder for the custom layer in a standard build, we will just pass through the parent insets
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
                                    + (attitudeOverlay.visible ? attitudeOverlay.height + ScreenTools.defaultFontPixelHeight * 1.6 : 0)
                                    + (ekfCtrlPanel.visible ? ekfCtrlPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset + (pathControlPanel.visible ? pathControlPanel.width + ScreenTools.defaultFontPixelWidth * 2 : 0)
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset + (gpsTelemetryPanel.visible ? gpsTelemetryPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
                                    + (attitudeOverlay.visible ? attitudeOverlay.width + ScreenTools.defaultFontPixelWidth : 0)
                                    + (ekfCtrlPanel.visible ? ekfCtrlPanel.width + ScreenTools.defaultFontPixelWidth : 0)
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset + (pathControlPanel.visible ? pathControlPanel.height + ScreenTools.defaultFontPixelWidth * 2 : 0) + (systemControlPanel.visible ? systemControlPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
                                    + (navErrorPanel.visible ? navErrorPanel.height + ScreenTools.defaultFontPixelWidth : 0)
                                    + (odomTelemetryPanel.visible ? odomTelemetryPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset + (gpsTelemetryPanel.visible ? gpsTelemetryPanel.height + ScreenTools.defaultFontPixelWidth : 0)
    }
}
