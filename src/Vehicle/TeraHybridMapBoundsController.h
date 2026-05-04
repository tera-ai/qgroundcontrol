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

#include <array>

#include "MAVLinkLib.h"

/// @brief Tracks the most recent terrain footprint advertised by the
/// tera-system1 hybrid pipeline (DEBUG_FLOAT_ARRAY with the "TERA_MAP" tag).
///
/// The controller is a process-wide singleton so the Fly View can bind to it
/// without a live `Vehicle`. Bounds persist until a different map fingerprint
/// is broadcast, matching the behaviour of `run_hybrid_utility.py`: load a
/// map, fly it, and the outline stays on QGC until the next run sends new
/// corners.
class TeraHybridMapBoundsController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Reference via the global terraHybridMapBounds context property.")

    Q_PROPERTY(bool             hasBounds   READ hasBounds   NOTIFY boundsChanged)
    Q_PROPERTY(QVariantList     coordinates READ coordinates NOTIFY boundsChanged)

public:
    /// Constructed exclusively via Q_APPLICATION_STATIC; clients must use
    /// instance() instead of instantiating directly. Public-but-discouraged
    /// because Qt's Q_APPLICATION_STATIC macro requires constructor access.
    explicit TeraHybridMapBoundsController(QObject* parent = nullptr);

    static TeraHybridMapBoundsController* instance();

    /// Examine an inbound MAVLink message and, if it carries the TERA_MAP
    /// payload from a recognised companion sysid, update the cached bounds.
    /// Safe to call from any vehicle's message handler.
    void mavlinkMessageReceived(const mavlink_message_t& message);

    bool hasBounds() const { return _hasBounds; }
    QVariantList coordinates() const;

signals:
    void boundsChanged();

private:
    static bool _isAcceptedSysId(uint8_t sysId);

    bool                            _hasBounds = false;
    std::array<double, 8>           _latLonFlat{};   // SW lat, SW lon, NW lat, NW lon, NE lat, NE lon, SE lat, SE lon
    QGeoCoordinate                  _corners[4];
};
