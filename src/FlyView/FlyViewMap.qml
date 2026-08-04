import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

FlightMap {
    id:                         _root
    allowGCSLocationCenter:     true
    allowVehicleLocationCenter: !_keepVehicleCentered
    planView:                   false
    zoomLevel:                  QGroundControl.flightMapZoom
    center:                     QGroundControl.flightMapPosition

    property Item   pipView
    property Item   pipState:                   _pipState
    property var    rightPanelWidth
    property var    planMasterController
    property bool   pipMode:                    false   // true: map is shown in a small pip mode
    property var    toolInsets                          // Insets for the center viewport area

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:      planMasterController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _activeVehicleCoordinate:   _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
    property real   _toolButtonTopMargin:       parent.height - mainWindow.height + (ScreenTools.defaultFontPixelHeight / 2)
    property real   _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property bool   _keepMapCenteredOnVehicle:  _flyViewSettings.keepMapCenteredOnVehicle.rawValue

    property bool   _disableVehicleTracking:    false
    property bool   _keepVehicleCentered:       pipMode ? true : false
    property bool   _saveZoomLevelSetting:      true

    // Toggleable map overlays controlled from FlyViewCustomLayer.qml
    property bool   velocityArrowEnabled:       false

    // Per-estimator-type cap for the odometry estimator-dots overlay (separate
    // from the C++-side per-type cap so we can keep dot rendering performant).
    readonly property int _odomDotsMaxPerType:  1500

    function _adjustMapZoomForPipMode() {
        _saveZoomLevelSetting = false
        if (pipMode) {
            if (QGroundControl.flightMapZoom > 3) {
                zoomLevel = QGroundControl.flightMapZoom - 3
            }
        } else {
            zoomLevel = QGroundControl.flightMapZoom
        }
        _saveZoomLevelSetting = true
    }

    onPipModeChanged: _adjustMapZoomForPipMode()

    onVisibleChanged: {
        if (visible) {
            // Synchronize center position with Plan View
            center = QGroundControl.flightMapPosition
        }
    }

    onZoomLevelChanged: {
        if (_saveZoomLevelSetting) {
            QGroundControl.flightMapZoom = _root.zoomLevel
        }
    }
    onCenterChanged: {
        QGroundControl.flightMapPosition = _root.center
    }

    // We track whether the user has panned or not to correctly handle automatic map positioning
    onMapPanStart:  _disableVehicleTracking = true
    onMapPanStop:   panRecenterTimer.restart()

    function pointInRect(point, rect) {
        return point.x > rect.x &&
                point.x < rect.x + rect.width &&
                point.y > rect.y &&
                point.y < rect.y + rect.height;
    }

    property real _animatedLatitudeStart
    property real _animatedLatitudeStop
    property real _animatedLongitudeStart
    property real _animatedLongitudeStop
    property real animatedLatitude
    property real animatedLongitude

    onAnimatedLatitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)
    onAnimatedLongitudeChanged: _root.center = QtPositioning.coordinate(animatedLatitude, animatedLongitude)

    NumberAnimation on animatedLatitude { id: animateLat; from: _animatedLatitudeStart; to: _animatedLatitudeStop; duration: 1000 }
    NumberAnimation on animatedLongitude { id: animateLong; from: _animatedLongitudeStart; to: _animatedLongitudeStop; duration: 1000 }

    function animatedMapRecenter(fromCoord, toCoord) {
        _animatedLatitudeStart = fromCoord.latitude
        _animatedLongitudeStart = fromCoord.longitude
        _animatedLatitudeStop = toCoord.latitude
        _animatedLongitudeStop = toCoord.longitude
        animateLat.start()
        animateLong.start()
    }

    // returns the rectangle formed by the four center insets
    // used for checking if vehicle is under ui, and as a target for recentering the view
    function _insetCenterRect() {
        return Qt.rect(toolInsets.leftEdgeCenterInset,
                       toolInsets.topEdgeCenterInset,
                       _root.width - toolInsets.leftEdgeCenterInset - toolInsets.rightEdgeCenterInset,
                       _root.height - toolInsets.topEdgeCenterInset - toolInsets.bottomEdgeCenterInset)
    }

    // returns the four rectangles formed by the 8 corner insets
    // used for detecting if the vehicle has flown under the instrument panel, virtual joystick etc
    function _insetCornerRects() {
        var rects = {
        "topleft":      Qt.rect(0,0,
                               toolInsets.leftEdgeTopInset,
                               toolInsets.topEdgeLeftInset),
        "topright":     Qt.rect(_root.width-toolInsets.rightEdgeTopInset,0,
                               toolInsets.rightEdgeTopInset,
                               toolInsets.topEdgeRightInset),
        "bottomleft":   Qt.rect(0,_root.height-toolInsets.bottomEdgeLeftInset,
                               toolInsets.leftEdgeBottomInset,
                               toolInsets.bottomEdgeLeftInset),
        "bottomright":  Qt.rect(_root.width-toolInsets.rightEdgeBottomInset,_root.height-toolInsets.bottomEdgeRightInset,
                               toolInsets.rightEdgeBottomInset,
                               toolInsets.bottomEdgeRightInset)}
        return rects
    }

    function recenterNeeded() {
        var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
        var centerRect = _insetCenterRect()
        //return !pointInRect(vehiclePoint,insetRect)

        // If we are outside the center inset rectangle, recenter
        if(!pointInRect(vehiclePoint, centerRect)){
            return true
        }

        // if we are inside the center inset rectangle
        // then additionally check if we are underneath one of the corner inset rectangles
        var cornerRects = _insetCornerRects()
        if(pointInRect(vehiclePoint, cornerRects["topleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["topright"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomleft"])){
            return true
        } else if(pointInRect(vehiclePoint, cornerRects["bottomright"])){
            return true
        }

        // if we are inside the center inset rectangle, and not under any corner elements
        return false
    }

    function updateMapToVehiclePosition() {
        if (animateLat.running || animateLong.running) {
            return
        }
        // We let FlightMap handle first vehicle position
        if (!_keepMapCenteredOnVehicle && firstVehiclePositionReceived && _activeVehicleCoordinate.isValid && !_disableVehicleTracking) {
            if (_keepVehicleCentered) {
                _root.center = _activeVehicleCoordinate
            } else {
                if (firstVehiclePositionReceived && recenterNeeded()) {
                    // Move the map such that the vehicle is centered within the inset area
                    var vehiclePoint = _root.fromCoordinate(_activeVehicleCoordinate, false /* clipToViewport */)
                    var centerInsetRect = _insetCenterRect()
                    var centerInsetPoint = Qt.point(centerInsetRect.x + centerInsetRect.width / 2, centerInsetRect.y + centerInsetRect.height / 2)
                    var centerOffset = Qt.point((_root.width / 2) - centerInsetPoint.x, (_root.height / 2) - centerInsetPoint.y)
                    var vehicleOffsetPoint = Qt.point(vehiclePoint.x + centerOffset.x, vehiclePoint.y + centerOffset.y)
                    var vehicleOffsetCoord = _root.toCoordinate(vehicleOffsetPoint, false /* clipToViewport */)
                    animatedMapRecenter(_root.center, vehicleOffsetCoord)
                }
            }
        }
    }

    on_ActiveVehicleCoordinateChanged: {
        if (_keepMapCenteredOnVehicle && _activeVehicleCoordinate.isValid && !_disableVehicleTracking) {
            _root.center = _activeVehicleCoordinate
        }
    }

    PipState {
        id:         _pipState
        pipView:    _root.pipView
        isDark:     _isFullWindowItemDark
    }

    Timer {
        id:         panRecenterTimer
        interval:   10000
        running:    false
        onTriggered: {
            _disableVehicleTracking = false
            updateMapToVehiclePosition()
        }
    }

    Timer {
        interval:       500
        running:        true
        repeat:         true
        onTriggered:    updateMapToVehiclePosition()
    }

    QGCMapPalette { id: mapPal; lightColors: isSatelliteMap }

    Connections {
        target:                 _missionController
        ignoreUnknownSignals:   true
        function onNewItemsFromVehicle() {
            var visualItems = _missionController.visualItems
            if (visualItems && visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
                firstVehiclePositionReceived = true
            }
        }
    }

    MapFitFunctions {
        id:                         mapFitFunctions // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        _root
        usePlannedHomePosition:     false
        planMasterController:       _planMasterController
    }

    ObstacleDistanceOverlayMap {
        id: obstacleDistance
        showText: !pipMode
    }

    // Tera hybrid map footprint (SW, NW, NE, SE) broadcast via DEBUG_FLOAT_ARRAY
    // by tera-system1's flight_controller when a map loads. The polygon stays
    // visible across vehicle disconnects and only updates when a new run sends
    // different corners.
    MapPolygon {
        id:             teraMapBoundsPolygon
        z:              QGroundControl.zOrderMapItems
        visible:        !pipMode && teraHybridMapBounds.hasBounds
        color:          Qt.rgba(1, 0.65, 0, 0.10)
        border.width:   2
        border.color:   "#FFA500"

        function _refresh() {
            teraMapBoundsPolygon.path = teraHybridMapBounds.hasBounds
                ? teraHybridMapBounds.coordinates
                : []
        }

        Component.onCompleted: _refresh()

        Connections {
            target: teraHybridMapBounds
            function onBoundsChanged() { teraMapBoundsPolygon._refresh() }
        }
    }

    // Add trajectory lines to the map
    MapPolyline {
        id:         trajectoryPolyline
        line.width: 3
        line.color: "red"
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    !pipMode

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                trajectoryPolyline.path = _activeVehicle ? _activeVehicle.trajectoryPoints.list() : []
            }
        }

        Connections {
            target:                             _activeVehicle ? _activeVehicle.trajectoryPoints : null
            function onPointAdded(coordinate) { trajectoryPolyline.addCoordinate(coordinate) }
            function onUpdateLastPoint(coordinate) { trajectoryPolyline.replaceCoordinate(trajectoryPolyline.pathLength() - 1, coordinate) }
            function onPointsCleared() { trajectoryPolyline.path = [] }
        }
    }

    // GPS path from GPS_RAW_INT messages
    MapPolyline {
        id:         gpsPathPolyline
        line.width: 2
        line.color: "#00E04B"  // Green color matching MAVLink Inspector
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    !pipMode && _activeVehicle && _activeVehicle.gpsPathPoints.enabled

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                gpsPathPolyline.path = _activeVehicle && _activeVehicle.gpsPathPoints.enabled ? _activeVehicle.gpsPathPoints.list() : []
            }
        }

        Connections {
            target:                             _activeVehicle ? _activeVehicle.gpsPathPoints : null
            function onPointAdded(coordinate) { 
                if (gpsPathPolyline.visible) {
                    gpsPathPolyline.addCoordinate(coordinate) 
                }
            }
            function onPointsCleared() { gpsPathPolyline.path = [] }
            function onEnabledChanged() {
                if (_activeVehicle && _activeVehicle.gpsPathPoints.enabled) {
                    gpsPathPolyline.path = _activeVehicle.gpsPathPoints.list()
                } else {
                    gpsPathPolyline.path = []
                }
            }
        }
    }

    // Odometry path from ODOMETRY messages
    MapPolyline {
        id:         odometryPathPolyline
        line.width: 2
        line.color: "#536DFF"  // Blue color matching MAVLink Inspector
        z:          QGroundControl.zOrderTrajectoryLines
        visible:    !pipMode && _activeVehicle && _activeVehicle.odometryPathPoints.enabled

        // Rebuild polyline + dots model from the OdometryPathPoints C++-side
        // entries, applying the current plotPropagation filter.
        function rebuildFromSource() {
            odomEstimatorDotsModel.clear()
            odomDotsTypeCounts.mapping = 0
            odomDotsTypeCounts.tracking = 0
            odomDotsTypeCounts.propagation = 0

            if (!_activeVehicle || !_activeVehicle.odometryPathPoints.enabled) {
                odometryPathPolyline.path = []
                return
            }

            var entries = _activeVehicle.odometryPathPoints.pointsWithType()
            var plotProp = _activeVehicle.odometryPathPoints.plotPropagation
            var path = []
            for (var i = 0; i < entries.length; ++i) {
                var t = entries[i].type
                if (t === 2 && !plotProp) {
                    continue
                }
                var c = entries[i].coord
                path.push(c)
                odomEstimatorDotsModel.append({ "lat": c.latitude, "lon": c.longitude, "estType": t })
                _bumpDotsTypeCount(t)
                _evictOldestDotForType(t)
            }
            odometryPathPolyline.path = path
        }

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                odometryPathPolyline.rebuildFromSource()
            }
        }

        Connections {
            target:                             _activeVehicle ? _activeVehicle.odometryPathPoints : null
            function onPointAdded(coordinate, estimatorType) {
                var plotProp = _activeVehicle.odometryPathPoints.plotPropagation
                if (estimatorType === 2 && !plotProp) {
                    return
                }
                if (odometryPathPolyline.visible) {
                    odometryPathPolyline.addCoordinate(coordinate)
                }
                odomEstimatorDotsModel.append({ "lat": coordinate.latitude, "lon": coordinate.longitude, "estType": estimatorType })
                _bumpDotsTypeCount(estimatorType)
                _evictOldestDotForType(estimatorType)
            }
            function onPointsCleared() {
                odometryPathPolyline.path = []
                odomEstimatorDotsModel.clear()
                odomDotsTypeCounts.mapping = 0
                odomDotsTypeCounts.tracking = 0
                odomDotsTypeCounts.propagation = 0
            }
            function onEnabledChanged() {
                odometryPathPolyline.rebuildFromSource()
            }
            function onPlotPropagationChanged() {
                odometryPathPolyline.rebuildFromSource()
            }
            // The reference point moved, so every stored coordinate changed.
            function onPathReprojected() {
                odometryPathPolyline.rebuildFromSource()
            }
        }
    }

    // Model for estimator type dots along the odometry path
    ListModel {
        id: odomEstimatorDotsModel
    }

    // Per-estimator-type counters for the dots model so a high-rate stream
    // (e.g. propagation) can never push mapping/tracking dots out.
    QtObject {
        id: odomDotsTypeCounts
        property int mapping:     0
        property int tracking:    0
        property int propagation: 0
    }

    function _bumpDotsTypeCount(estType) {
        if (estType === 0)      odomDotsTypeCounts.mapping++
        else if (estType === 1) odomDotsTypeCounts.tracking++
        else if (estType === 2) odomDotsTypeCounts.propagation++
    }

    function _evictOldestDotForType(estType) {
        var cap = _odomDotsMaxPerType
        var count = (estType === 0) ? odomDotsTypeCounts.mapping :
                    (estType === 1) ? odomDotsTypeCounts.tracking :
                    (estType === 2) ? odomDotsTypeCounts.propagation : 0
        if (count <= cap) {
            return
        }
        for (var i = 0; i < odomEstimatorDotsModel.count; ++i) {
            if (odomEstimatorDotsModel.get(i).estType === estType) {
                odomEstimatorDotsModel.remove(i)
                if (estType === 0)      odomDotsTypeCounts.mapping--
                else if (estType === 1) odomDotsTypeCounts.tracking--
                else if (estType === 2) odomDotsTypeCounts.propagation--
                break
            }
        }
    }

    // Colored dots on the odometry path showing estimator type history
    //   Gold = Mapping (0), Grey = Tracking (1), Red = Propagation (2)
    MapItemView {
        model:   odomEstimatorDotsModel
        visible: odometryPathPolyline.visible

        delegate: MapQuickItem {
            coordinate: QtPositioning.coordinate(model.lat, model.lon)
            anchorPoint.x: 4
            anchorPoint.y: 4
            z: QGroundControl.zOrderTrajectoryLines + 0.5

            sourceItem: Rectangle {
                width:  8
                height: 8
                radius: 4
                color:  model.estType === 0 ? "#FFD700" :   // Mapping = Gold
                        model.estType === 1 ? "#B0B0B0" :   // Tracking = Grey
                        model.estType === 2 ? "#FF5252" :   // Propagation = Red
                                              "#FFFFFF"      // Unknown
                border.width: 0.5
                border.color: "#536DFF"
            }
        }
    }

    // Odometry path head marker - shape changes based on estimator type:
    //   Mapping (0) = Star, Tracking (1) = Triangle, Propagation (2) = Circle
    MapQuickItem {
        id:             odometryHeadMarker
        z:              QGroundControl.zOrderTrajectoryLines + 2
        visible:        odometryPathPolyline.visible && _activeVehicle && _activeVehicle.odometryPathPoints.lastPoint.isValid
        coordinate:     _activeVehicle ? _activeVehicle.odometryPathPoints.lastPoint : QtPositioning.coordinate()
        anchorPoint.x:  odometryHeadShape.width / 2
        anchorPoint.y:  odometryHeadShape.height / 2

        property int _estimatorType: _activeVehicle ? _activeVehicle.odometryPathPoints.estimatorType : -1

        sourceItem: Canvas {
            id:     odometryHeadShape
            width:  18
            height: 18

            property int estType: odometryHeadMarker._estimatorType
            onEstTypeChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var cx = width / 2
                var cy = height / 2
                var r = width / 2 - 1

                ctx.lineWidth = 1.5
                ctx.strokeStyle = "#536DFF"

                if (estType === 0) {
                    // MAPPING - Star (4-pointed)
                    ctx.fillStyle = "#FFD700"  // Gold
                    var innerRadius = r * 0.4
                    var spikes = 4
                    var rotation = -Math.PI / 2
                    ctx.beginPath()
                    for (var i = 0; i < spikes * 2; i++) {
                        var rad = (i % 2 === 0) ? r : innerRadius
                        var angle = rotation + (i * Math.PI / spikes)
                        var px = cx + Math.cos(angle) * rad
                        var py = cy + Math.sin(angle) * rad
                        if (i === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                    }
                    ctx.closePath()
                } else if (estType === 1) {
                    // TRACKING - Triangle (pointing up)
                    ctx.fillStyle = "#B0B0B0"  // Grey
                    ctx.beginPath()
                    ctx.moveTo(cx, cy - r)                                    // Top
                    ctx.lineTo(cx + r * Math.cos(Math.PI / 6), cy + r * 0.5) // Bottom-right
                    ctx.lineTo(cx - r * Math.cos(Math.PI / 6), cy + r * 0.5) // Bottom-left
                    ctx.closePath()
                } else if (estType === 2) {
                    // PROPAGATION - Circle
                    ctx.fillStyle = "#FF5252"  // Red
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.closePath()
                } else {
                    // Unknown - small filled circle
                    ctx.fillStyle = "#FFFFFF"
                    ctx.beginPath()
                    ctx.arc(cx, cy, r * 0.5, 0, 2 * Math.PI)
                    ctx.closePath()
                }

                ctx.fill()
                ctx.stroke()
            }
        }
    }

    // Velocity arrow (LOCAL_POSITION_NED vx/vy) drawn from the vehicle icon.
    // Length is time-projected (where the vehicle would be in LOOKAHEAD_SECONDS),
    // so direction comes from atan2(vy, vx) and magnitude scales the arrow length.
    //
    // The shaft AND the arrowhead are rendered as a single MapPolyline so they
    // can never desync visually (separate MapItems can render in different
    // frames, which previously caused the head to lag behind the shaft tip).
    QtObject {
        id: velocityArrowState

        readonly property real lookaheadSeconds:  1.0
        readonly property real minSpeed:          0.2  // m/s, below this we hide the arrow
        readonly property real wingHalfAngleDeg:  30   // angle of arrowhead wings from shaft
        readonly property real wingFraction:      0.22 // wing length as fraction of shaft length
        readonly property real wingMinMeters:     1.5  // minimum wing length so head is visible at low speed

        property var  _vx:        _activeVehicle && _activeVehicle.localPosition ? _activeVehicle.localPosition.vx : null
        property var  _vy:        _activeVehicle && _activeVehicle.localPosition ? _activeVehicle.localPosition.vy : null
        property real vxValue:    _vx ? _vx.rawValue : NaN
        property real vyValue:    _vy ? _vy.rawValue : NaN

        property real speed:      (isNaN(vxValue) || isNaN(vyValue)) ? 0 : Math.sqrt(vxValue * vxValue + vyValue * vyValue)
        // Azimuth measured clockwise from North, in degrees, in [0, 360).
        property real azimuthDeg: (isNaN(vxValue) || isNaN(vyValue)) ? 0
                                  : ((Math.atan2(vyValue, vxValue) * 180.0 / Math.PI) + 360.0) % 360.0

        property var  startCoord: _activeVehicle ? _activeVehicle.coordinate : QtPositioning.coordinate()
        property real shaftMeters: speed * lookaheadSeconds
        property var  endCoord:   (startCoord && startCoord.isValid && speed >= minSpeed)
                                  ? startCoord.atDistanceAndAzimuth(shaftMeters, azimuthDeg)
                                  : QtPositioning.coordinate()

        property real wingMeters:  Math.max(shaftMeters * wingFraction, wingMinMeters)
        // Wings point back-and-out from the tip, away from start, opening by
        // wingHalfAngleDeg on each side of the reverse shaft direction.
        property real wingLeftAz:  ((azimuthDeg + 180 - wingHalfAngleDeg) + 360) % 360
        property real wingRightAz: ((azimuthDeg + 180 + wingHalfAngleDeg) + 360) % 360
        property var  wingLeft:   (endCoord && endCoord.isValid)
                                  ? endCoord.atDistanceAndAzimuth(wingMeters, wingLeftAz)
                                  : QtPositioning.coordinate()
        property var  wingRight:  (endCoord && endCoord.isValid)
                                  ? endCoord.atDistanceAndAzimuth(wingMeters, wingRightAz)
                                  : QtPositioning.coordinate()

        // Single polyline path: shaft -> tip -> left wing -> tip -> right wing.
        // Backtracking through the tip keeps it one connected stroke.
        property var arrowPath: active
                                ? [startCoord, endCoord, wingLeft, endCoord, wingRight]
                                : []

        property bool active:     !pipMode && velocityArrowEnabled && _activeVehicle
                                  && startCoord && startCoord.isValid && speed >= minSpeed
                                  && endCoord && endCoord.isValid
    }

    MapPolyline {
        id:         velocityArrowLine
        line.width: 3
        line.color: "#FF00C8" // Magenta: distinct from red vehicle, blue/green/red paths and any GT line
        z:          QGroundControl.zOrderTrajectoryLines + 1
        visible:    velocityArrowState.active
        path:       velocityArrowState.arrowPath
    }

    // Speed label anchored at the tip. Drawn as a separate MapQuickItem because
    // text isn't part of the polyline geometry; minor sub-frame label lag is
    // not visually misleading the way a detached arrowhead would be.
    MapQuickItem {
        id:             velocityArrowLabel
        z:              QGroundControl.zOrderTrajectoryLines + 1.5
        visible:        velocityArrowState.active
        coordinate:     velocityArrowState.endCoord
        anchorPoint.x:  -6 // small offset to the right of the tip
        anchorPoint.y:  velocityArrowLabelText.height / 2

        sourceItem: Text {
            id:             velocityArrowLabelText
            text:           velocityArrowState.speed.toFixed(1) + " m/s"
            color:          "#FF00C8"
            font.bold:      true
            font.pointSize: ScreenTools.smallFontPointSize
            style:          Text.Outline
            styleColor:     "black"
        }
    }

    // Add the vehicles to the map
    MapItemView {
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: VehicleMapItem {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 3
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add distance sensor view
    MapItemView{
        model: QGroundControl.multiVehicleManager.vehicles
        delegate: ProximityRadarMapView {
            vehicle:        object
            coordinate:     object.coordinate
            map:            _root
            z:              QGroundControl.zOrderVehicles
        }
    }
    // Add ADSB vehicles to the map
    MapItemView {
        model: QGroundControl.adsbVehicleManager.adsbVehicles
        delegate: VehicleMapItem {
            coordinate:     object.coordinate
            altitude:       object.altitude
            callsign:       object.callsign
            heading:        object.heading
            alert:          object.alert
            map:            _root
            size:           pipMode ? ScreenTools.defaultFontPixelHeight : ScreenTools.defaultFontPixelHeight * 2.5
            z:              QGroundControl.zOrderVehicles
        }
    }

    // Add the items associated with each vehicles flight plan to the map
    Repeater {
        model: QGroundControl.multiVehicleManager.vehicles

        PlanMapItems {
            map:                    _root
            largeMapView:           !pipMode
            planMasterController:   masterController
            vehicle:                _vehicle

            property var _vehicle: object

            PlanMasterController {
                id: masterController
                Component.onCompleted: startStaticActiveVehicle(object)
            }
        }
    }

    // Allow custom builds to add map items
    CustomMapItems {
        map:            _root
        largeMapView:   !pipMode
    }

    GeoFenceMapVisuals {
        map:                    _root
        myGeoFenceController:   _geoFenceController
        interactive:            false
        planView:               false
        homePosition:           _activeVehicle && _activeVehicle.homePosition.isValid ? _activeVehicle.homePosition :  QtPositioning.coordinate()
    }

    // Rally points on map
    MapItemView {
        model: _rallyPointController.points

        delegate: MapQuickItem {
            id:             itemIndicator
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderMapItems

            sourceItem: MissionItemIndexLabel {
                id:         itemIndexLabel
                label:      qsTr("R", "rally point map item label")
            }
        }
    }

    // Camera trigger points
    MapItemView {
        model: _activeVehicle ? _activeVehicle.cameraTriggerPoints : 0

        delegate: CameraTriggerIndicator {
            coordinate:     object.coordinate
            z:              QGroundControl.zOrderTopMost
        }
    }

    // GoTo Location forward flight circle visuals
    QGCMapCircleVisuals {
        id:                 fwdFlightGotoMapCircle
        mapControl:         parent
        mapCircle:          _fwdFlightGotoMapCircle
        radiusLabelVisible: true
        visible:            gotoLocationItem.visible && _activeVehicle &&
                            _activeVehicle.inFwdFlight &&
                            !_activeVehicle.orbitActive

        property alias coordinate: _fwdFlightGotoMapCircle.center
        property alias radius: _fwdFlightGotoMapCircle.radius
        property alias clockwiseRotation: _fwdFlightGotoMapCircle.clockwiseRotation

        Component.onCompleted: {
            // Only allow editing the radius, not the position
            centerDragHandleVisible = false

            globals.guidedControllerFlyView.fwdFlightGotoMapCircle = this
        }

        Binding {
            target: _fwdFlightGotoMapCircle
            property: "center"
            value: gotoLocationItem.coordinate
        }

        function startLoiterRadiusEdit() {
            _fwdFlightGotoMapCircle.interactive = true
        }

        // Called when loiter edit is confirmed
        function actionConfirmed() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._commitRadius()
        }

        // Called when loiter edit is cancelled
        function actionCancelled() {
            _fwdFlightGotoMapCircle.interactive = false
            _fwdFlightGotoMapCircle._restoreRadius()
        }

        QGCMapCircle {
            id:                 _fwdFlightGotoMapCircle
            interactive:        false
            showRotation:       true
            clockwiseRotation:  true

            property real _defaultLoiterRadius: _flyViewSettings.forwardFlightGoToLocationLoiterRad.value
            property real _committedRadius;

            onCenterChanged: {
                radius.rawValue = _defaultLoiterRadius
                // Don't commit the radius in case this operation is undone
            }

            Component.onCompleted: {
                radius.rawValue = _defaultLoiterRadius
                _commitRadius()
            }

            function _commitRadius() {
                _committedRadius = radius.rawValue
            }

            function _restoreRadius() {
                radius.rawValue = _committedRadius
            }
        }
    }

    // GoTo Location visuals
    MapQuickItem {
        id:             gotoLocationItem
        visible:        false
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Go here", "Go to location waypoint")
        }

        property bool inGotoFlightMode: _activeVehicle ? _activeVehicle.flightMode === _activeVehicle.gotoFlightMode : false

        property var _committedCoordinate: null

        onInGotoFlightModeChanged: {
            if (!inGotoFlightMode && gotoLocationItem.visible) {
                // Hide goto indicator when vehicle falls out of guided mode
                hide()
            }
        }

        function show(coord) {
            gotoLocationItem.coordinate = coord
            gotoLocationItem.visible = true
        }

        function hide() {
            gotoLocationItem.visible = false
        }

        function actionConfirmed() {
            _commitCoordinate()

            // Commit the new radius which possibly changed
            fwdFlightGotoMapCircle.actionConfirmed()

            // We leave the indicator visible. The handling for onInGuidedModeChanged will hide it.
        }

        function actionCancelled() {
            _restoreCoordinate()

            // Also restore the loiter radius
            fwdFlightGotoMapCircle.actionCancelled()
        }

        function _commitCoordinate() {
            // Must deep copy
            _committedCoordinate = QtPositioning.coordinate(
                coordinate.latitude,
                coordinate.longitude
            );
        }

        function _restoreCoordinate() {
            if (_committedCoordinate) {
                coordinate = _committedCoordinate
            } else {
                hide()
            }
        }
    }

    // Orbit editing visuals
    QGCMapCircleVisuals {
        id:             orbitMapCircle
        mapControl:     parent
        mapCircle:      _mapCircle
        visible:        false

        property alias center:              _mapCircle.center
        property alias clockwiseRotation:   _mapCircle.clockwiseRotation
        readonly property real defaultRadius: 30

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (!activeVehicle) {
                    orbitMapCircle.visible = false
                }
            }
        }

        function show(coord) {
            _mapCircle.radius.rawValue = defaultRadius
            orbitMapCircle.center = coord
            orbitMapCircle.visible = true
        }

        function hide() {
            orbitMapCircle.visible = false
        }

        function actionConfirmed() {
            // Live orbit status is handled by telemetry so we hide here and telemetry will show again.
            hide()
        }

        function actionCancelled() {
            hide()
        }

        function radius() {
            return _mapCircle.radius.rawValue
        }

        Component.onCompleted: globals.guidedControllerFlyView.orbitMapCircle = orbitMapCircle

        QGCMapCircle {
            id:                 _mapCircle
            interactive:        true
            radius.rawValue:    30
            showRotation:       true
            clockwiseRotation:  true
        }
    }

    // ROI Location visuals
    MapQuickItem {
        id:             roiLocationItem
        visible:        _activeVehicle && _activeVehicle.isROIEnabled
        z:              QGroundControl.zOrderMapItems
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY

        Connections {
            target: _activeVehicle
            function onRoiCoordChanged(centerCoord) {
                roiLocationItem.show(centerCoord)
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (position) => {
                position = Qt.point(position.x, position.y)
                var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
                // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                position = mapToItem(globals.parent, position)
                var dropPanel = roiEditDropPanelComponent.createObject(mainWindow, { clickRect: Qt.rect(position.x, position.y, 0, 0) })
                dropPanel.open()
            }
        }

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("ROI here", "Make this a Region Of Interest")
        }

        //-- Visibilty controlled by actual state
        function show(coord) {
            roiLocationItem.coordinate = coord
        }
    }

    // Orbit telemetry visuals
    QGCMapCircleVisuals {
        id:             orbitTelemetryCircle
        mapControl:     parent
        mapCircle:      _activeVehicle ? _activeVehicle.orbitMapCircle : null
        visible:        _activeVehicle ? _activeVehicle.orbitActive : false
    }

    MapQuickItem {
        id:             orbitCenterIndicator
        anchorPoint.x:  sourceItem.anchorPointX
        anchorPoint.y:  sourceItem.anchorPointY
        coordinate:     _activeVehicle ? _activeVehicle.orbitMapCircle.center : QtPositioning.coordinate()
        visible:        orbitTelemetryCircle.visible && !gotoLocationItem.visible

        sourceItem: MissionItemIndexLabel {
            checked:    true
            index:      -1
            label:      qsTr("Orbit", "Orbit waypoint")
        }
    }

    Component {
        id: roiEditPositionDialogComponent

        EditPositionDialog {
            title:                  qsTr("Edit ROI Position")
            coordinate:             roiLocationItem.coordinate
            onCoordinateChanged: {
                roiLocationItem.coordinate = coordinate
                _activeVehicle.guidedModeROI(coordinate)
            }
        }
    }

    Component {
        id: roiEditDropPanelComponent

        DropPanel {
            id: roiEditDropPanel

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Cancel ROI")
                        onClicked: {
                            _activeVehicle.stopGuidedModeROI()
                            roiEditDropPanel.close()
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit Position")
                        onClicked: {
                            roiEditPositionDialogComponent.createObject(mainWindow, { showSetPositionFromVehicle: false }).open()
                            roiEditDropPanel.close()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mapClickDropPanelComponent

        DropPanel {
            id: mapClickDropPanel

            property var mapClickCoord

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Go to location")
                        visible:            globals.guidedControllerFlyView.showGotoLocation
                        onClicked: {
                            mapClickDropPanel.close()
                            gotoLocationItem.show(mapClickCoord)

                            if ((_activeVehicle.flightMode == _activeVehicle.gotoFlightMode) && !_flyViewSettings.goToLocationRequiresConfirmInGuided.value) {
                                globals.guidedControllerFlyView.executeAction(globals.guidedControllerFlyView.actionGoto, mapClickCoord, gotoLocationItem)
                                gotoLocationItem.actionConfirmed() // Still need to call this to commit the new coordinate and radius
                            } else {
                                globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionGoto, mapClickCoord, gotoLocationItem)
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Orbit at location")
                        visible:            globals.guidedControllerFlyView.showOrbit
                        onClicked: {
                            mapClickDropPanel.close()
                            orbitMapCircle.show(mapClickCoord)
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionOrbit, mapClickCoord, orbitMapCircle)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("ROI at location")
                        visible:            globals.guidedControllerFlyView.showROI
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.executeAction(globals.guidedControllerFlyView.actionROI, mapClickCoord, 0, false)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set home here")
                        visible:            globals.guidedControllerFlyView.showSetHome
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionSetHome, mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set Estimator Origin")
                        visible:            globals.guidedControllerFlyView.showSetEstimatorOrigin
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionSetEstimatorOrigin, mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Set Heading")
                        visible:            globals.guidedControllerFlyView.showChangeHeading
                        onClicked: {
                            mapClickDropPanel.close()
                            globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionChangeHeading, mapClickCoord)
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        QGCLabel { text: qsTr("Lat: %1").arg(mapClickCoord.latitude.toFixed(6)) }
                        QGCLabel { text: qsTr("Lon: %1").arg(mapClickCoord.longitude.toFixed(6)) }
                    }
                }
            }
        }
    }

    onMapClicked: (position) => {
        if (!globals.guidedControllerFlyView.guidedUIVisible &&
            (globals.guidedControllerFlyView.showGotoLocation || globals.guidedControllerFlyView.showOrbit ||
             globals.guidedControllerFlyView.showROI || globals.guidedControllerFlyView.showSetHome ||
             globals.guidedControllerFlyView.showSetEstimatorOrigin)) {

            position = Qt.point(position.x, position.y)
            var clickCoord = _root.toCoordinate(position, false /* clipToViewPort */)
            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
            position = _root.mapToItem(globals.parent, position)
            var dropPanel = mapClickDropPanelComponent.createObject(mainWindow, { mapClickCoord: clickCoord, clickRect: Qt.rect(position.x, position.y, 0, 0) })
            dropPanel.open()
        }
    }

    MapScale {
        id:                 mapScale
        anchors.margins:    _toolsMargin
        anchors.left:       parent.left
        anchors.top:        parent.top
        mapControl:         _root
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && mapControl.pipState.state === mapControl.pipState.windowState

        property real centerInset: visible ? parent.height - y : 0
    }

}
