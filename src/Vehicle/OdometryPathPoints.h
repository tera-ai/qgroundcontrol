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

signals:
    void pointAdded(QGeoCoordinate coordinate, int estimatorType);
    void lastPointChanged();
    void estimatorTypeChanged();
    void pointsCleared(void);
    void enabledChanged();
    void plotPropagationChanged();
    void usingFallbackChanged();
    void referenceTypeChanged();

public slots:
    void clear(void);
    void addOdometryPoint(double x, double y, double z, int estimatorType);

private:
    void _setReferenceInfo(bool usingFallback, const QString& referenceType);

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
};

