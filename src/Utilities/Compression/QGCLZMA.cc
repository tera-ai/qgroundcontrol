/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QGCLZMA.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QFile>

#include <lzma.h>

QGC_LOGGING_CATEGORY(QGCLZMALog, "qgc.utilities.compression.qgclzma")

namespace QGCLZMA
{

bool inflateLZMAFile(const QString &lzmaFilename, const QString &decompressedFilename)
{
    QFile inputFile(lzmaFilename);
    if (!inputFile.open(QIODevice::ReadOnly)) {
        qCWarning(QGCLZMALog) << "open input file failed" << lzmaFilename << inputFile.errorString();
        return false;
    }

    QFile outputFile(decompressedFilename);
    if (!outputFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(QGCLZMALog) << "open output file failed" << outputFile.fileName() << outputFile.errorString();
        return false;
    }

    lzma_stream strm = LZMA_STREAM_INIT;
    // CONCATENATED lets us decode files that contain multiple streams.
    // TELL_UNSUPPORTED_CHECK lets us continue past unknown integrity checks
    // (mirrors the old xz-embedded behavior).
    const uint32_t flags = LZMA_TELL_UNSUPPORTED_CHECK | LZMA_CONCATENATED;
    lzma_ret ret = lzma_auto_decoder(&strm, UINT64_MAX, flags);
    if (ret != LZMA_OK) {
        qCWarning(QGCLZMALog) << "lzma_auto_decoder init failed" << ret;
        return false;
    }

    constexpr int kBufSize = 8 * 1024;
    uint8_t inBuf[kBufSize];
    uint8_t outBuf[kBufSize];

    strm.next_in = nullptr;
    strm.avail_in = 0;
    strm.next_out = outBuf;
    strm.avail_out = sizeof(outBuf);

    lzma_action action = LZMA_RUN;
    bool success = false;

    while (true) {
        if (strm.avail_in == 0 && !inputFile.atEnd()) {
            const qint64 nread = inputFile.read(reinterpret_cast<char*>(inBuf), sizeof(inBuf));
            if (nread < 0) {
                qCWarning(QGCLZMALog) << "input file read failed:" << inputFile.errorString();
                break;
            }
            strm.next_in = inBuf;
            strm.avail_in = static_cast<size_t>(nread);
            if (inputFile.atEnd()) {
                action = LZMA_FINISH;
            }
        }

        ret = lzma_code(&strm, action);

        if (strm.avail_out == 0 || ret == LZMA_STREAM_END) {
            const size_t writeSize = sizeof(outBuf) - strm.avail_out;
            if (writeSize > 0) {
                const qint64 written = outputFile.write(reinterpret_cast<const char*>(outBuf), static_cast<qint64>(writeSize));
                if (written != static_cast<qint64>(writeSize)) {
                    qCWarning(QGCLZMALog) << "output file write failed:" << outputFile.fileName() << outputFile.errorString();
                    break;
                }
            }
            strm.next_out = outBuf;
            strm.avail_out = sizeof(outBuf);
        }

        if (ret == LZMA_STREAM_END) {
            success = true;
            break;
        }

        if (ret == LZMA_UNSUPPORTED_CHECK) {
            qCWarning(QGCLZMALog) << "Unsupported integrity check; not verifying file integrity";
            continue;
        }

        if (ret != LZMA_OK) {
            const char* msg = "unknown error";
            switch (ret) {
            case LZMA_MEM_ERROR:        msg = "memory allocation failed"; break;
            case LZMA_MEMLIMIT_ERROR:   msg = "memory usage limit reached"; break;
            case LZMA_FORMAT_ERROR:     msg = "not an .xz file"; break;
            case LZMA_OPTIONS_ERROR:    msg = "unsupported options in headers"; break;
            case LZMA_DATA_ERROR:       msg = "compressed data is corrupt"; break;
            case LZMA_BUF_ERROR:        msg = "compressed data is truncated or otherwise corrupt"; break;
            default: break;
            }
            qCWarning(QGCLZMALog) << "lzma_code failed:" << msg << "(code" << ret << ")";
            break;
        }
    }

    lzma_end(&strm);
    return success;
}

} // namespace QGCLZMA
