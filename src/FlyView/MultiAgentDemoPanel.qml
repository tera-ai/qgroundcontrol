import QtQuick
import QtQuick.Layouts

import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Guided flow for the air-ground teaming demo (PAS-Tera-AI demo/gps_denied):
//   1. plan each drone's survey (Plan view, Pattern > Survey, Upload)
//   2. click the map to set each ground vehicle's goal
//   3. start the ground vehicles once the drones' map is published
// Once the map is published its traversability and detected objects are
// drawn on the map (overlay.png from the demo's map server).
// The demo's truck endpoints (terademo.truck_mavlink) publish its state as
// NAMED_VALUE messages (Vehicle.namedValues); the panel shows only when one
// of them is connected.
Rectangle {
    id:         _root
    width:      mainColumn.width + _margin * 2
    height:     mainColumn.height + _margin * 2
    radius:     ScreenTools.defaultFontPixelWidth * 0.5
    color:      Qt.rgba(0, 0, 0, 0.75)
    visible:    _trucks.length > 0

    property var mapControl

    readonly property real _margin:     ScreenTools.defaultFontPixelWidth
    readonly property int  _cmdSetGoal: 31020   // TERA_SET_GOAL: param5 lat, param6 lon (truck_mavlink)
    readonly property string _mapServer: "http://127.0.0.1:8765/"   // demo.yaml map_server
    readonly property var  _phaseNames: [qsTr("Waiting for survey plans"), qsTr("Drones surveying"),
                                         qsTr("Building the map"), qsTr("Map published: set goals, then start"),
                                         qsTr("Ground vehicles driving"), qsTr("Done")]

    property var    _vehicles:      QGroundControl.multiVehicleManager.vehicles
    property var    _drones:        []
    property var    _trucks:        []      // vehicles whose endpoint publishes DEMO_PH
    property var    _pickTruck:     null    // truck waiting for a goal click
    property var    _markers:       ({})    // truck id -> goal marker on the map
    property var    _state:         _trucks.length > 0 ? _trucks[0].namedValues : ({})
    property int    _phase:         _state["DEMO_PH"] !== undefined ? _state["DEMO_PH"] : -1
    property int    _surveyed:      _state["SURVEYED"] !== undefined ? _state["SURVEYED"] : 0
    property bool   _mapReady:      _state["MAP_RDY"] === 1
    property bool   _allGoals:      _trucks.length > 0 && _trucks.every(t => t.namedValues["GOAL_SET"] === 1)
    property bool   _started:       _phase >= 4
    property var    _overlay:       null    // MapQuickItem with the drones' map
    property bool   _showOverlay:   true

    on_MapReadyChanged: _mapReady ? _loadOverlay() : _clearOverlay()

    function _clearOverlay() {
        if (_overlay) {
            mapControl.removeMapItem(_overlay)
            _overlay.destroy()
            _overlay = null
        }
    }

    // overlay.json: image, north_west / south_east [lat, lon], zoom_level at
    // which the image is at its natural size (terademo.mapping.overlay_placement)
    function _loadOverlay() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.warn("MultiAgentDemoPanel: no map overlay", xhr.status)
                return
            }
            var o = JSON.parse(xhr.responseText)
            _clearOverlay()
            _overlay = mapOverlay.createObject(mapControl, {
                coordinate: QtPositioning.coordinate(o.north_west[0], o.north_west[1]),
                zoomLevel:  o.zoom_level,
                // a new map reuses the file name: bust Qt's image cache
                source:     _mapServer + o.image + "?t=" + Date.now()
            })
            mapControl.addMapItem(_overlay)
        }
        xhr.open("GET", _mapServer + "overlay.json")
        xhr.send()
    }

    function _refresh() {
        var drones = [], trucks = []
        for (var i = 0; i < _vehicles.count; i++) {
            var v = _vehicles.get(i)
            // TGC keeps a vehicle whose link went quiet (an earlier run's,
            // or one dropped from the demo's config): leave it out
            if (v.vehicleLinkManager.communicationLost) {
                continue
            }
            if (v.namedValues["DEMO_PH"] !== undefined) {
                trucks.push(v)
            } else if (v.multiRotor) {
                drones.push(v)
            }
        }
        drones.sort((a, b) => a.id - b.id)
        trucks.sort((a, b) => a.id - b.id)
        // reassign only on change: a new array rebuilds the Repeater rows
        var ids = l => l.map(v => v.id).join(",")
        if (ids(drones) !== ids(_drones)) _drones = drones
        if (ids(trucks) !== ids(_trucks)) _trucks = trucks
    }

    // namedValues of a new endpoint arrive after it connects, so poll lightly
    Timer {
        interval:       1000
        repeat:         true
        running:        true
        triggeredOnStart: true
        onTriggered:    _refresh()
    }

    function _droneSurveyed(v) {
        return (_surveyed >> (v.id - 1)) & 1
    }

    function _truckTaskText(t) {
        var task = t.namedValues["TASK"]
        if (task === 1) return qsTr("driving")
        if (task === 2) return qsTr("reached goal")
        if (task === 3) return qsTr("failed")
        return t.namedValues["GOAL_SET"] === 1 ? qsTr("goal set") : qsTr("no goal")
    }

    function _setGoal(truck, coord) {
        truck.sendCommand(1, _cmdSetGoal, true, 0, 0, 0, 0, coord.latitude, coord.longitude, 0)
        var marker = _markers[truck.id]
        if (!marker) {
            marker = goalMarker.createObject(mapControl, { label: _vehicleName(truck) })
            mapControl.addMapItem(marker)
            _markers[truck.id] = marker
        }
        marker.coordinate = coord
    }

    function _vehicleName(v) {
        return (v.multiRotor ? qsTr("Drone ") : qsTr("Truck ")) + (v.multiRotor ? v.id : v.id - 100)
    }

    Component {
        id: goalMarker
        MapQuickItem {
            property string label
            anchorPoint.x:  sourceItem.width / 2
            anchorPoint.y:  sourceItem.height
            z:              QGroundControl.zOrderMapItems + 2
            sourceItem: Column {
                QGCLabel {
                    text:               label + qsTr(" goal")
                    color:              "white"
                    style:              Text.Outline
                    styleColor:         "black"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Rectangle {
                    width:  ScreenTools.defaultFontPixelHeight
                    height: width
                    radius: width / 2
                    color:  "#FF9800"
                    border.color: "white"
                    border.width: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component {
        id: mapOverlay
        MapQuickItem {
            property alias source: overlayImage.source
            anchorPoint.x:  0
            anchorPoint.y:  0
            visible:        _showOverlay
            z:              QGroundControl.zOrderMapItems - 1   // under vehicles and goals
            sourceItem: Image {
                id:     overlayImage
                smooth: false
            }
        }
    }

    component DemoButton: Rectangle {
        property alias text: buttonLabel.text
        property bool  active: true
        property color baseColor: "#388E3C"
        signal clicked()
        width:      buttonLabel.width + ScreenTools.defaultFontPixelWidth * 2
        height:     buttonLabel.height + ScreenTools.defaultFontPixelWidth
        radius:     ScreenTools.defaultFontPixelWidth * 0.3
        opacity:    active ? 1.0 : 0.4
        color:      buttonMouse.pressed ? Qt.darker(baseColor, 1.2)
                                        : (buttonMouse.containsMouse && active ? Qt.lighter(baseColor, 1.15) : baseColor)
        QGCLabel {
            id:                 buttonLabel
            color:              "white"
            font.pointSize:     ScreenTools.smallFontPointSize
            anchors.centerIn:   parent
        }
        MouseArea {
            id:             buttonMouse
            anchors.fill:   parent
            hoverEnabled:   true
            enabled:        parent.active
            onClicked:      parent.clicked()
        }
    }

    component StepTitle: QGCLabel {
        property bool done: false
        color:          done ? "#81C784" : "white"
        font.bold:      true
    }

    Column {
        id:                 mainColumn
        anchors.centerIn:   parent
        spacing:            _margin * 0.5

        QGCLabel {
            text:           qsTr("Multi-agent demo")
            color:          "white"
            font.pointSize: ScreenTools.mediumFontPointSize
        }
        QGCLabel {
            text:           _phase >= 0 && _phase < _phaseNames.length ? _phaseNames[_phase] : qsTr("Connecting")
            color:          "#FFD54F"
            font.pointSize: ScreenTools.smallFontPointSize
        }

        // ---- 1. survey ----
        StepTitle {
            text:   qsTr("1  Plan the drones' survey")
            done:   _drones.length > 0 && _drones.every(d => _droneSurveyed(d))
        }
        QGCLabel {
            text:           qsTr("Plan view: Pattern > Survey, draw the area (altitude 65 m or more), Upload.\nDo not start the mission: the demo flies it.")
            color:          "#BDBDBD"
            font.pointSize: ScreenTools.smallFontPointSize
        }
        Repeater {
            model: _drones
            RowLayout {
                spacing: _margin
                QGCLabel {
                    text:                   _vehicleName(modelData)
                    color:                  "white"
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    text:                   _droneSurveyed(modelData) ? qsTr("survey uploaded") : qsTr("no survey")
                    color:                  _droneSurveyed(modelData) ? "#81C784" : "#BDBDBD"
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                }
                DemoButton {
                    text:       qsTr("Plan survey")
                    baseColor:  "#1976D2"
                    active:     _phase <= 0
                    onClicked: {
                        QGroundControl.multiVehicleManager.activeVehicle = modelData
                        mainWindow.showPlanView()
                    }
                }
            }
        }

        // ---- drones' map on the ground station map ----
        RowLayout {
            spacing: _margin
            visible: _overlay !== null
            QGCLabel {
                text:           qsTr("Drones' map: <font color='#E57373'>blocked</font>  <font color='#81C784'>road</font>  <font color='#FF8C00'>roadblock</font>  <font color='#3CC83C'>canopy</font>  <font color='#E040E0'>obstacle</font>")
                textFormat:     Text.RichText
                color:          "white"
                font.pointSize: ScreenTools.smallFontPointSize
            }
            DemoButton {
                text:       _showOverlay ? qsTr("Hide") : qsTr("Show")
                baseColor:  "#616161"
                onClicked:  _showOverlay = !_showOverlay
            }
        }

        // ---- 2. goals ----
        StepTitle {
            text:   qsTr("2  Set the ground vehicles' goals")
            done:   _allGoals
        }
        QGCLabel {
            text:           _pickTruck ? qsTr("Click the map to place %1's goal (Esc cancels)").arg(_vehicleName(_pickTruck))
                                       : qsTr("Goals must be inside the surveyed area. Routes are planned on the drones' map.")
            color:          _pickTruck ? "#FFD54F" : "#BDBDBD"
            font.pointSize: ScreenTools.smallFontPointSize
        }
        Repeater {
            model: _trucks
            RowLayout {
                spacing: _margin
                QGCLabel {
                    text:                   _vehicleName(modelData)
                    color:                  "white"
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 9
                }
                QGCLabel {
                    text:                   _truckTaskText(modelData)
                    color:                  modelData.namedValues["GOAL_SET"] === 1 ? "#81C784" : "#BDBDBD"
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 14
                }
                DemoButton {
                    text:       _pickTruck === modelData ? qsTr("Cancel") : qsTr("Set goal")
                    baseColor:  "#F57C00"
                    active:     !_started
                    onClicked:  _pickTruck = (_pickTruck === modelData ? null : modelData)
                }
            }
        }

        // ---- 3. start ----
        StepTitle {
            text:   qsTr("3  Start the ground vehicles")
            done:   _started
        }
        DemoButton {
            text:       _started ? qsTr("Ground missions running") : qsTr("Start ground missions")
            active:     _mapReady && _allGoals && !_started
            onClicked: {
                for (var i = 0; i < _trucks.length; i++) {
                    _trucks[i].sendCommand(1, 300 /* MAV_CMD_MISSION_START */, true)
                }
            }
        }
        QGCLabel {
            text:           !_mapReady ? qsTr("Waits for the drones' map") : (!_allGoals ? qsTr("Waits for every goal") : "")
            color:          "#BDBDBD"
            font.pointSize: ScreenTools.smallFontPointSize
            visible:        text !== "" && !_started
        }
    }

    // Goal picking: while a truck waits for its goal, a click anywhere on
    // the map sets it
    MouseArea {
        parent:         _root.parent
        anchors.fill:   parent
        enabled:        _pickTruck !== null
        visible:        enabled
        z:              _root.z - 1
        cursorShape:    Qt.CrossCursor
        focus:          enabled
        Keys.onEscapePressed: _pickTruck = null
        onClicked: (mouse) => {
            var p = mapControl.mapFromItem(this, mouse.x, mouse.y)
            var coord = mapControl.toCoordinate(p, false)
            if (coord.isValid) {
                _setGoal(_pickTruck, coord)
            }
            _pickTruck = null
        }
    }
}
