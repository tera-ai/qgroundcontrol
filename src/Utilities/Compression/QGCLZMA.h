/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QString>

Q_DECLARE_LOGGING_CATEGORY(QGCLZMALog)

// Minimal .xz / .lzma decompression helper used for the PX4
// COMPONENT_INFORMATION JSON download path. The libarchive-based
// QGCCompression::decompressIfNeeded() was observed to silently fail for
// PX4-generated .xz blobs (e.g. actuators.json.xz), which prevented the
// Vehicle Setup "Actuators" tab from ever being shown.
//
// This helper goes straight to liblzma's stream decoder, matching the
// behavior QGC shipped prior to the libarchive compression refactor.
namespace QGCLZMA
{
    /// Decompress an .xz / .lzma file to disk.
    /// @return true on success, false otherwise.
    bool inflateLZMAFile(const QString &lzmaFilename, const QString &decompressedFilename);
}
