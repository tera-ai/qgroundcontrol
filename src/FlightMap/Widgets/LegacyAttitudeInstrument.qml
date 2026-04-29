/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls

// Legacy-style standalone artificial horizon variant, intended for the
// FlyView selectable instrument-panel (see FlyView.SettingsGroup.json
// instrumentQmlFile2). Bigger than the integrated variants so the AH is
// readable like the old QGroundControl bottom-right indicator.
Rectangle {
    id:     control
    width:  Math.min(_defaultWidth, _maxWidth)
    height: _outerRadius * 2
    radius: _outerRadius
    color:  qgcPal.window

    property real extraInset:       0
    property real extraValuesWidth: _outerRadius

    property real _defaultWidth:    mainWindow.width * 0.18
    property real _maxWidth:        ScreenTools.defaultFontPixelHeight * 12
    property real _innerRadius:     (width - (_topBottomMargin * 2))
    property real _outerRadius:     (_innerRadius / 2) + _topBottomMargin
    property real _topBottomMargin: (width * 0.05) / 2

    DeadMouseArea { anchors.fill: parent }

    QGCPalette { id: qgcPal }

    QGCAttitudeWidget {
        id:                     attitude
        anchors.centerIn:       parent
        size:                   control._innerRadius
        vehicle:                globals.activeVehicle
        showHeading:            true
    }
}

