/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QVariantList>
#include <QtPositioning/QGeoCoordinate>
#include <QtQmlIntegration/QtQmlIntegration>

class Vehicle;

class OdometryPathPoints : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QGeoCoordinate lastPoint READ lastPoint NOTIFY lastPointChanged)
    Q_PROPERTY(bool usingFallback READ usingFallback NOTIFY usingFallbackChanged)
    Q_PROPERTY(QString referenceType READ referenceType NOTIFY referenceTypeChanged)
    
public:
    OdometryPathPoints(Vehicle* vehicle, QObject* parent = nullptr);

    Q_INVOKABLE QVariantList list(void) const { return _points; }
    bool enabled(void) const { return _enabled; }
    QGeoCoordinate lastPoint(void) const { return _lastPoint; }
    bool usingFallback(void) const { return _usingFallback; }
    QString referenceType(void) const { return _referenceType; }
    void setEnabled(bool enabled);

signals:
    void pointAdded(QGeoCoordinate coordinate);
    void lastPointChanged();
    void pointsCleared(void);
    void enabledChanged();
    void usingFallbackChanged();
    void referenceTypeChanged();

public slots:
    void clear(void);
    void addOdometryPoint(double x, double y, double z);

private:
    void _setReferenceInfo(bool usingFallback, const QString& referenceType);

    Vehicle*        _vehicle;
    QVariantList    _points;
    QGeoCoordinate  _lastPoint;
    bool            _enabled = false;
    bool            _usingFallback = false;
    QString         _referenceType;
    QGeoCoordinate  _referenceCoordinate; // Reference point for NED to geodetic conversion

    static constexpr int _maxPointCount = 600;
};

