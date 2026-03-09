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

    // System control buttons (restart hybrid nav, kill camera publisher)
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

            // Restart Hybrid Navigation System (target system 77)
            Rectangle {
                id:             restartHybridBtn
                width:          restartHybridLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         restartHybridLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          restartHybridMouse.pressed ? "#1565C0" : (restartHybridMouse.containsMouse ? "#1E88E5" : "#1976D2")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     restartHybridLabel
                    text:                   qsTr("Restart Hybrid Nav")
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

            // Kill Camera Publisher (target system 255)
            Rectangle {
                id:             killCameraBtn
                width:          killCameraLabel.width + ScreenTools.defaultFontPixelWidth * 2
                height:         killCameraLabel.height + ScreenTools.defaultFontPixelWidth
                radius:         ScreenTools.defaultFontPixelWidth * 0.3
                color:          killCameraMouse.pressed ? "#C62828" : (killCameraMouse.containsMouse ? "#E53935" : "#D32F2F")
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id:                     killCameraLabel
                    text:                   qsTr("Kill Camera Publisher")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    anchors.centerIn:       parent
                }

                MouseArea {
                    id:             killCameraMouse
                    anchors.fill:   parent
                    hoverEnabled:   true
                    onClicked: {
                        if (_activeVehicle) {
                            _activeVehicle.sendCommandToSystem(255, 0, 246, 3, 0, 0, 0, 0, 0, 0)
                        }
                    }
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

    // since this file is a placeholder for the custom layer in a standard build, we will just pass through the parent insets
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset:    parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset + (pathControlPanel.visible ? pathControlPanel.width + ScreenTools.defaultFontPixelWidth * 2 : 0)
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset + (gpsTelemetryPanel.visible ? gpsTelemetryPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset + (pathControlPanel.visible ? pathControlPanel.height + ScreenTools.defaultFontPixelWidth * 2 : 0) + (systemControlPanel.visible ? systemControlPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset + (navErrorPanel.visible ? navErrorPanel.height + ScreenTools.defaultFontPixelWidth : 0)
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset + (gpsTelemetryPanel.visible ? gpsTelemetryPanel.height + ScreenTools.defaultFontPixelWidth : 0)
    }
}
