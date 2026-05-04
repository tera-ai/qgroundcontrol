/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "TeraHybridMapBoundsController.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QByteArray>

#include <cmath>
#include <cstring>

QGC_LOGGING_CATEGORY(TeraHybridMapBoundsLog, "Vehicle.TeraHybridMapBounds")

Q_APPLICATION_STATIC(TeraHybridMapBoundsController, _teraHybridMapBoundsController);

namespace {

constexpr const char* kTeraMapTag = "TERA_MAP";
// `name` is a 10-byte NUL-terminated field; we only require an exact tag match
// on the leading bytes so future variants (e.g. "TERA_MAP2") would not be
// silently misinterpreted.
constexpr int kTeraMapTagLen = 8;

bool _isFiniteLatLon(double lat, double lon)
{
    if (!std::isfinite(lat) || !std::isfinite(lon)) {
        return false;
    }
    if (lat < -90.0 || lat > 90.0) {
        return false;
    }
    if (lon < -180.0 || lon > 180.0) {
        return false;
    }
    return true;
}

} // namespace

TeraHybridMapBoundsController::TeraHybridMapBoundsController(QObject* parent)
    : QObject(parent)
{
}

TeraHybridMapBoundsController* TeraHybridMapBoundsController::instance()
{
    return _teraHybridMapBoundsController();
}

bool TeraHybridMapBoundsController::_isAcceptedSysId(uint8_t sysId)
{
    // Match the ODOMETRY allowlist used in Vehicle.cc: tera-system1 publishes
    // from companion sysids 77 (primary) or 255 (fallback).
    return sysId == 77 || sysId == 255;
}

QVariantList TeraHybridMapBoundsController::coordinates() const
{
    QVariantList out;
    if (!_hasBounds) {
        return out;
    }
    out.reserve(4);
    for (int i = 0; i < 4; ++i) {
        out.append(QVariant::fromValue(_corners[i]));
    }
    return out;
}

void TeraHybridMapBoundsController::mavlinkMessageReceived(const mavlink_message_t& message)
{
    if (message.msgid != MAVLINK_MSG_ID_DEBUG_FLOAT_ARRAY) {
        return;
    }
    if (!_isAcceptedSysId(message.sysid)) {
        return;
    }

    mavlink_debug_float_array_t debugArray{};
    mavlink_msg_debug_float_array_decode(&message, &debugArray);

    if (std::strncmp(debugArray.name, kTeraMapTag, kTeraMapTagLen) != 0) {
        return;
    }

    std::array<double, 8> incoming{};
    for (int i = 0; i < 8; ++i) {
        incoming[i] = static_cast<double>(debugArray.data[i]);
    }

    // Validate before publishing so we don't blank out a previously good
    // overlay because of a single corrupt frame.
    for (int i = 0; i < 4; ++i) {
        if (!_isFiniteLatLon(incoming[i * 2], incoming[i * 2 + 1])) {
            qCDebug(TeraHybridMapBoundsLog) << "Rejecting TERA_MAP frame with invalid corner"
                                            << i << incoming[i * 2] << incoming[i * 2 + 1];
            return;
        }
    }

    // Treat byte-identical floats as the same map (no-op). pymavlink packs the
    // message as float32, so any change in the publishing config will produce
    // a distinct fingerprint while replays of the same map stay quiet.
    if (_hasBounds && incoming == _latLonFlat) {
        return;
    }

    _latLonFlat = incoming;
    for (int i = 0; i < 4; ++i) {
        _corners[i] = QGeoCoordinate(incoming[i * 2], incoming[i * 2 + 1]);
    }
    _hasBounds = true;

    qCDebug(TeraHybridMapBoundsLog) << "Updated TERA_MAP bounds (sysid" << message.sysid << ")"
                                    << "SW" << _corners[0]
                                    << "NW" << _corners[1]
                                    << "NE" << _corners[2]
                                    << "SE" << _corners[3];

    emit boundsChanged();
}
