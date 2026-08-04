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

#include <QtCore/QDateTime>
#include <QtCore/QDebug>
#include <QtCore/qmath.h>
#include <cmath>

OdometryPathPoints::OdometryPathPoints(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{
    // The autopilot only broadcasts GPS_GLOBAL_ORIGIN when the origin is set or
    // moved, so it commonly turns up long after we have started plotting
    // against a fallback. Adopt it whenever it does arrive.
    connect(vehicle, &Vehicle::ekfOriginChanged, this, &OdometryPathPoints::_ekfOriginChanged);
    qDebug() << "OdometryPathPoints created for vehicle" << vehicle->id();
}

QVariantList OdometryPathPoints::list(void) const
{
    QVariantList out;
    out.reserve(_entries.size());
    for (const Entry& e : _entries) {
        out.append(QVariant::fromValue(e.coord));
    }
    return out;
}

QVariantList OdometryPathPoints::pointsWithType(void) const
{
    QVariantList out;
    out.reserve(_entries.size());
    for (const Entry& e : _entries) {
        QVariantMap m;
        m.insert(QStringLiteral("coord"), QVariant::fromValue(e.coord));
        m.insert(QStringLiteral("type"),  e.type);
        out.append(m);
    }
    return out;
}

qint64 OdometryPathPoints::droneNowMs(void) const
{
    if (_droneBootBaselineGcsMs == 0) {
        return 0;
    }
    const qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - _droneBootBaselineGcsMs;
    return static_cast<qint64>(_droneBootBaselineMs) + elapsed;
}

void OdometryPathPoints::updateDroneClockBaseline(quint64 droneTimeBootMs)
{
    _droneBootBaselineMs    = droneTimeBootMs;
    _droneBootBaselineGcsMs = QDateTime::currentMSecsSinceEpoch();
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
            _resolveReference();
        }
        emit enabledChanged();
    }
}

void OdometryPathPoints::setPlotPropagation(bool plot)
{
    if (_plotPropagation != plot) {
        _plotPropagation = plot;
        emit plotPropagationChanged();
    }
}

void OdometryPathPoints::_updateOdomAttitude(const float q[4])
{
    if (!q) {
        return;
    }
    // ODOMETRY message uses q = [w, x, y, z]; reject NaN.
    if (std::isnan(q[0]) || std::isnan(q[1]) || std::isnan(q[2]) || std::isnan(q[3])) {
        return;
    }
    const double w = q[0], x = q[1], y = q[2], z = q[3];

    const double roll  = std::atan2(2.0 * (w * x + y * z), 1.0 - 2.0 * (x * x + y * y));
    double sinp        = 2.0 * (w * y - z * x);
    if (sinp >  1.0) sinp =  1.0;
    if (sinp < -1.0) sinp = -1.0;
    const double pitch = std::asin(sinp);
    const double yaw   = std::atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z));

    _odomRollDeg  = qRadiansToDegrees(roll);
    _odomPitchDeg = qRadiansToDegrees(pitch);
    _odomYawDeg   = qRadiansToDegrees(yaw);
    emit odomAttitudeChanged();
}

void OdometryPathPoints::addOdometryPoint(quint64 timeUsec, const float q[4],
                                          double x, double y, double z, int estimatorType)
{
    // Always update timing + attitude even if we end up dropping the point
    // for buffer reasons; the timing/attitude reflect the latest message we
    // saw, regardless of whether it was added to the path.
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    _lastAnyDroneUsec  = timeUsec;
    _lastAnyArrivalMs  = nowMs;
    if (estimatorType >= 0 && estimatorType <= 2) {
        _lastDroneUsec[estimatorType] = timeUsec;
        _lastArrivalMs[estimatorType] = nowMs;
    }
    emit timingChanged();

    _updateOdomAttitude(q);

    _resolveReference();

    if (!_referenceCoordinate.isValid()) {
        qDebug() << "Odometry Path: No valid reference coordinate";
        return;
    }

    if (std::isnan(x) || std::isnan(y)) {
        qDebug() << "Odometry Path: NaN values in data";
        return;
    }

    QGeoCoordinate coordinate;
    QGCGeo::convertNedToGeo(x, y, z, _referenceCoordinate, coordinate);

    if (!coordinate.isValid()) {
        qDebug() << "Odometry Path: Invalid converted coordinate from NED:" << x << y << z;
        return;
    }

    _lastPoint = coordinate;
    emit lastPointChanged();

    if (_estimatorType != estimatorType) {
        _estimatorType = estimatorType;
        emit estimatorTypeChanged();
    }

    if (!_enabled) {
        return;
    }

    // Per-estimator-type eviction: ensure adding this point doesn't push the
    // count for its type above _maxPointsPerType. If it would, find and remove
    // the oldest entry of THIS type only, leaving other types untouched.
    const bool typeIsKnown = (estimatorType >= 0 && estimatorType <= 2);
    if (typeIsKnown && _typeCounts[estimatorType] >= _maxPointsPerType) {
        for (int i = 0; i < _entries.size(); ++i) {
            if (_entries[i].type == estimatorType) {
                _entries.removeAt(i);
                _typeCounts[estimatorType]--;
                break;
            }
        }
    }

    _entries.append({coordinate, estimatorType, x, y, z});
    if (typeIsKnown) {
        _typeCounts[estimatorType]++;
    }

    qDebug() << "Odometry Path point added:" << coordinate << "from NED:" << x << y << z << "estimator:" << estimatorType << "Total:" << _entries.size();
    emit pointAdded(coordinate, estimatorType);
}

void OdometryPathPoints::clear(void)
{
    _entries.clear();
    for (int i = 0; i < 3; ++i) {
        _typeCounts[i] = 0;
    }
    _lastPoint = QGeoCoordinate();
    _referenceCoordinate = QGeoCoordinate();
    emit pointsCleared();
    emit lastPointChanged();
}

void OdometryPathPoints::_resolveReference(void)
{
    if (_referenceCoordinate.isValid()) {
        return;
    }

    // Priority: EKF origin (correct) > home position (fallback) > current GPS (last resort).
    // ODOMETRY positions are measured from the EKF origin, so any fallback puts
    // the whole path out by the distance between that point and the origin --
    // routinely tens of metres, since PX4 sets the origin where EKF2 initializes
    // and only sets home on arming.
    QGeoCoordinate reference = _vehicle->ekfOrigin();
    if (reference.isValid()) {
        _adoptReference(reference, false, QStringLiteral("EKF Origin"));
        return;
    }

    qDebug() << "Odometry Path: EKF origin not available, falling back to home position";
    reference = _vehicle->homePosition();
    if (reference.isValid()) {
        _adoptReference(reference, true, QStringLiteral("Home Pos"));
        return;
    }

    qDebug() << "Odometry Path: Home position not available, falling back to current GPS";
    reference = _vehicle->coordinate();
    if (reference.isValid()) {
        _adoptReference(reference, true, QStringLiteral("GPS"));
    }
}

void OdometryPathPoints::_adoptReference(const QGeoCoordinate& reference, bool usingFallback, const QString& referenceType)
{
    _referenceCoordinate = reference;
    _setReferenceInfo(usingFallback, referenceType);
    qDebug() << "Odometry Path reference coordinate:" << _referenceCoordinate << "type:" << referenceType;

    if (_entries.isEmpty()) {
        return;
    }

    for (Entry& e : _entries) {
        QGCGeo::convertNedToGeo(e.x, e.y, e.z, _referenceCoordinate, e.coord);
    }

    _lastPoint = _entries.last().coord;
    emit lastPointChanged();
    emit pathReprojected();
}

void OdometryPathPoints::_ekfOriginChanged(const QGeoCoordinate& ekfOrigin)
{
    // Always take the origin over a fallback, even if the two happen to
    // coincide, so the UI stops reporting that it is using a fallback.
    if (!ekfOrigin.isValid() || (!_usingFallback && (ekfOrigin == _referenceCoordinate))) {
        return;
    }

    // Either we were on a fallback and can now be correct, or the autopilot
    // moved its origin mid-session and every point we have is now stale.
    _adoptReference(ekfOrigin, false, QStringLiteral("EKF Origin"));
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

