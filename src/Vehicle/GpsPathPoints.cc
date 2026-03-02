/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GpsPathPoints.h"
#include "Vehicle.h"
#include <QtCore/QDebug>

GpsPathPoints::GpsPathPoints(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{
    qDebug() << "GpsPathPoints created for vehicle" << vehicle->id();
}

void GpsPathPoints::setEnabled(bool enabled)
{
    if (_enabled != enabled) {
        _enabled = enabled;
        qDebug() << "GPS Path enabled:" << _enabled;
        if (!_enabled) {
            clear();
        }
        emit enabledChanged();
    }
}

void GpsPathPoints::addGpsRawIntPoint(QGeoCoordinate coordinate)
{
    if (!coordinate.isValid()) {
        qDebug() << "GPS Path: Invalid coordinate";
        return;
    }

    _lastPoint = coordinate;
    emit lastPointChanged();

    if (!_enabled) {
        return;
    }

    // Accumulate total distance
    if (_prevEnabledPoint.isValid()) {
        double segmentDistance = _prevEnabledPoint.distanceTo(coordinate);
        if (segmentDistance < 1000.0) {
            _totalDistance += segmentDistance;
            emit totalDistanceChanged();
        }
    }

    _prevEnabledPoint = coordinate;
    _points.append(QVariant::fromValue(coordinate));

    if (_points.size() > _maxPointCount) {
        _points.removeFirst();
    }

    // Update distance to home
    QGeoCoordinate home = _vehicle->homePosition();
    if (home.isValid() && coordinate.isValid()) {
        double newDistToHome = coordinate.distanceTo(home);
        if (newDistToHome != _distanceToHome) {
            _distanceToHome = newDistToHome;
            emit distanceToHomeChanged();
        }
    }

    qDebug() << "GPS Path point added:" << coordinate << "Total:" << _points.size() << "Distance:" << _totalDistance;
    emit pointAdded(coordinate);
}

void GpsPathPoints::clear(void)
{
    _points.clear();
    _prevEnabledPoint = QGeoCoordinate();
    _totalDistance = 0.0;
    _distanceToHome = 0.0;
    emit pointsCleared();
    emit totalDistanceChanged();
    emit distanceToHomeChanged();
}

