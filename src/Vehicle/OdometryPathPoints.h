/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtPositioning/QGeoCoordinate>
#include <QtQmlIntegration/QtQmlIntegration>

#include <limits>

class Vehicle;

class OdometryPathPoints : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool plotPropagation READ plotPropagation WRITE setPlotPropagation NOTIFY plotPropagationChanged)
    Q_PROPERTY(QGeoCoordinate lastPoint READ lastPoint NOTIFY lastPointChanged)
    Q_PROPERTY(int estimatorType READ estimatorType NOTIFY estimatorTypeChanged)
    Q_PROPERTY(bool usingFallback READ usingFallback NOTIFY usingFallbackChanged)
    Q_PROPERTY(QString referenceType READ referenceType NOTIFY referenceTypeChanged)

    // Estimator type constants matching ODOMETRY message estimator_type field
    Q_PROPERTY(int estimatorMapping READ estimatorMapping CONSTANT)
    Q_PROPERTY(int estimatorTracking READ estimatorTracking CONSTANT)
    Q_PROPERTY(int estimatorPropagation READ estimatorPropagation CONSTANT)

    // Latest odom message timing (any estimator type)
    Q_PROPERTY(quint64 lastDroneUsec   READ lastDroneUsec   NOTIFY timingChanged)
    Q_PROPERTY(qint64  lastArrivalMs   READ lastArrivalMs   NOTIFY timingChanged)

    // Per-estimator-type timestamps. droneUsec is whatever the message carried
    // in odom.time_usec; arrivalMs is the GCS wall clock (ms since epoch) at the
    // moment the message was processed.
    Q_PROPERTY(quint64 mappingDroneUsec     READ mappingDroneUsec     NOTIFY timingChanged)
    Q_PROPERTY(qint64  mappingArrivalMs     READ mappingArrivalMs     NOTIFY timingChanged)
    Q_PROPERTY(quint64 trackingDroneUsec    READ trackingDroneUsec    NOTIFY timingChanged)
    Q_PROPERTY(qint64  trackingArrivalMs    READ trackingArrivalMs    NOTIFY timingChanged)
    Q_PROPERTY(quint64 propagationDroneUsec READ propagationDroneUsec NOTIFY timingChanged)
    Q_PROPERTY(qint64  propagationArrivalMs READ propagationArrivalMs NOTIFY timingChanged)

    // Latest odom-derived attitude (Tait-Bryan, ZYX intrinsic), in degrees.
    // NaN until the first valid quaternion has been ingested.
    Q_PROPERTY(double odomRollDeg  READ odomRollDeg  NOTIFY odomAttitudeChanged)
    Q_PROPERTY(double odomPitchDeg READ odomPitchDeg NOTIFY odomAttitudeChanged)
    Q_PROPERTY(double odomYawDeg   READ odomYawDeg   NOTIFY odomAttitudeChanged)

public:
    OdometryPathPoints(Vehicle* vehicle, QObject* parent = nullptr);

    enum EstimatorType {
        Mapping     = 0,
        Tracking    = 1,
        Propagation = 2
    };
    Q_ENUM(EstimatorType)

    Q_INVOKABLE QVariantList list(void) const;
    // Returns a list of QVariantMap entries: { "coord": QGeoCoordinate, "type": int }
    // preserving original insertion order across all estimator types.
    Q_INVOKABLE QVariantList pointsWithType(void) const;

    // Returns the estimated current drone-side time_boot_ms based on the last
    // captured baseline (e.g. ATTITUDE.time_boot_ms) plus elapsed wall time
    // since that baseline was captured. Returns 0 if no baseline has been seen.
    Q_INVOKABLE qint64 droneNowMs(void) const;

    // Called by Vehicle when a high-rate timestamped MAVLink message arrives,
    // so we can estimate current drone-side time even between odom messages.
    void updateDroneClockBaseline(quint64 droneTimeBootMs);

    bool enabled(void) const { return _enabled; }
    bool plotPropagation(void) const { return _plotPropagation; }
    QGeoCoordinate lastPoint(void) const { return _lastPoint; }
    int estimatorType(void) const { return _estimatorType; }
    bool usingFallback(void) const { return _usingFallback; }
    QString referenceType(void) const { return _referenceType; }
    void setEnabled(bool enabled);
    void setPlotPropagation(bool plot);

    int estimatorMapping(void) const { return Mapping; }
    int estimatorTracking(void) const { return Tracking; }
    int estimatorPropagation(void) const { return Propagation; }

    quint64 lastDroneUsec(void) const           { return _lastAnyDroneUsec; }
    qint64  lastArrivalMs(void) const           { return _lastAnyArrivalMs; }
    quint64 mappingDroneUsec(void) const        { return _lastDroneUsec[Mapping]; }
    qint64  mappingArrivalMs(void) const        { return _lastArrivalMs[Mapping]; }
    quint64 trackingDroneUsec(void) const       { return _lastDroneUsec[Tracking]; }
    qint64  trackingArrivalMs(void) const       { return _lastArrivalMs[Tracking]; }
    quint64 propagationDroneUsec(void) const    { return _lastDroneUsec[Propagation]; }
    qint64  propagationArrivalMs(void) const    { return _lastArrivalMs[Propagation]; }

    double odomRollDeg(void) const  { return _odomRollDeg; }
    double odomPitchDeg(void) const { return _odomPitchDeg; }
    double odomYawDeg(void) const   { return _odomYawDeg; }

signals:
    void pointAdded(QGeoCoordinate coordinate, int estimatorType);
    void lastPointChanged();
    void estimatorTypeChanged();
    void pointsCleared(void);
    void enabledChanged();
    void plotPropagationChanged();
    void usingFallbackChanged();
    void referenceTypeChanged();
    void timingChanged();
    void odomAttitudeChanged();

public slots:
    void clear(void);
    // Receives odom.time_usec, the attitude quaternion (w,x,y,z) and position
    // in NED. Pass nullptr for q if the message had no valid attitude.
    void addOdometryPoint(quint64 timeUsec, const float q[4],
                          double x, double y, double z, int estimatorType);

private:
    void _setReferenceInfo(bool usingFallback, const QString& referenceType);
    void _updateOdomAttitude(const float q[4]);

    struct Entry {
        QGeoCoordinate coord;
        int            type;
    };

    Vehicle*        _vehicle;
    QList<Entry>    _entries;            // All points, in insertion order, tagged by type
    int             _typeCounts[3] = {0, 0, 0}; // Counts per EstimatorType for fast eviction decisions
    QGeoCoordinate  _lastPoint;
    int             _estimatorType = -1;
    bool            _enabled = false;
    bool            _plotPropagation = true;
    bool            _usingFallback = false;
    QString         _referenceType;
    QGeoCoordinate  _referenceCoordinate; // Reference point for NED to geodetic conversion

    // Per-estimator-type cap so a high-rate stream (e.g. propagation) can never
    // evict mapping/tracking history during long flights.
    static constexpr int _maxPointsPerType = 3000;

    // Timing
    quint64 _lastDroneUsec[3]     = {0, 0, 0};
    qint64  _lastArrivalMs[3]     = {0, 0, 0};
    quint64 _lastAnyDroneUsec     = 0;
    qint64  _lastAnyArrivalMs     = 0;

    // Drone clock baseline (captured from another timestamped MAVLink message
    // such as ATTITUDE) so we can estimate current drone-side time between
    // odom messages.
    qint64  _droneBootBaselineGcsMs = 0;
    quint64 _droneBootBaselineMs    = 0;

    // Latest odom-derived attitude in degrees (NaN until first valid quaternion).
    double  _odomRollDeg  = std::numeric_limits<double>::quiet_NaN();
    double  _odomPitchDeg = std::numeric_limits<double>::quiet_NaN();
    double  _odomYawDeg   = std::numeric_limits<double>::quiet_NaN();
};

