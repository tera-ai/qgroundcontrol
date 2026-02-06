/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "OdometryPathPoints.h"
#include "Vehicle.h"
#include "QGCGeo.h"

#include <QtCore/QDebug>
#include <cmath>

OdometryPathPoints::OdometryPathPoints(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{
    qDebug() << "OdometryPathPoints created for vehicle" << vehicle->id();
}

void OdometryPathPoints::setEnabled(bool enabled)
{
    if (_enabled != enabled) {
        _enabled = enabled;
        qDebug() << "Odometry Path enabled:" << _enabled;
        if (!_enabled) {
            clear();
            _setReferenceInfo(false, QString());
        } else {
            // Set reference coordinate when enabling
            // Priority: EKF origin (correct) > home position (fallback) > current GPS (last resort)
            _referenceCoordinate = _vehicle->ekfOrigin();
            if (_referenceCoordinate.isValid()) {
                _setReferenceInfo(false, QStringLiteral("EKF Origin"));
            } else {
                qDebug() << "Odometry Path: EKF origin not available, falling back to home position";
                _referenceCoordinate = _vehicle->homePosition();
                if (_referenceCoordinate.isValid()) {
                    _setReferenceInfo(true, QStringLiteral("Home Pos"));
                } else {
                    qDebug() << "Odometry Path: Home position not available, falling back to current GPS";
                    _referenceCoordinate = _vehicle->coordinate();
                    if (_referenceCoordinate.isValid()) {
                        _setReferenceInfo(true, QStringLiteral("GPS"));
                    }
                }
            }
            qDebug() << "Odometry Path reference coordinate:" << _referenceCoordinate << "type:" << _referenceType;
        }
        emit enabledChanged();
    }
}

void OdometryPathPoints::addOdometryPoint(double x, double y, double z, int estimatorType)
{
    if (!_enabled) {
        return;
    }

    // Update reference if we don't have one yet
    // Priority: EKF origin (correct) > home position (fallback) > current GPS (last resort)
    if (!_referenceCoordinate.isValid()) {
        _referenceCoordinate = _vehicle->ekfOrigin();
        if (_referenceCoordinate.isValid()) {
            _setReferenceInfo(false, QStringLiteral("EKF Origin"));
        } else {
            qDebug() << "Odometry Path: EKF origin not available, falling back to home position";
            _referenceCoordinate = _vehicle->homePosition();
            if (_referenceCoordinate.isValid()) {
                _setReferenceInfo(true, QStringLiteral("Home Pos"));
            } else {
                qDebug() << "Odometry Path: Home position not available, falling back to current GPS";
                _referenceCoordinate = _vehicle->coordinate();
                if (_referenceCoordinate.isValid()) {
                    _setReferenceInfo(true, QStringLiteral("GPS"));
                }
            }
        }
        qDebug() << "Odometry Path updated reference:" << _referenceCoordinate << "type:" << _referenceType;
    }

    if (!_referenceCoordinate.isValid()) {
        qDebug() << "Odometry Path: No valid reference coordinate";
        return; // Still no valid reference, can't convert
    }

    // Check for NaN values
    if (std::isnan(x) || std::isnan(y)) {
        qDebug() << "Odometry Path: NaN values in data";
        return;
    }

    // Convert NED (odometry x=north, y=east, z=down) to geodetic coordinate
    // Note: z should be positive down in NED convention
    QGeoCoordinate coordinate;
    QGCGeo::convertNedToGeo(x, y, z, _referenceCoordinate, coordinate);

    if (!coordinate.isValid()) {
        qDebug() << "Odometry Path: Invalid converted coordinate from NED:" << x << y << z;
        return;
    }

    _lastPoint = coordinate;
    _points.append(QVariant::fromValue(coordinate));

    if (_points.size() > _maxPointCount) {
        _points.removeFirst();
    }

    if (_estimatorType != estimatorType) {
        _estimatorType = estimatorType;
        emit estimatorTypeChanged();
    }

    qDebug() << "Odometry Path point added:" << coordinate << "from NED:" << x << y << z << "estimator:" << estimatorType << "Total:" << _points.size();
    emit pointAdded(coordinate);
    emit lastPointChanged();
}

void OdometryPathPoints::clear(void)
{
    _points.clear();
    _lastPoint = QGeoCoordinate();
    _referenceCoordinate = QGeoCoordinate();
    emit pointsCleared();
    emit lastPointChanged();
}

void OdometryPathPoints::_setReferenceInfo(bool usingFallback, const QString& referenceType)
{
    if (_usingFallback != usingFallback) {
        _usingFallback = usingFallback;
        emit usingFallbackChanged();
    }
    if (_referenceType != referenceType) {
        _referenceType = referenceType;
        emit referenceTypeChanged();
    }
}

