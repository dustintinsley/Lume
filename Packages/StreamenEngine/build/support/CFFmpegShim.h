// Swift-visible shims for FFmpeg C macros that the Clang importer cannot expose.
#ifndef CFFMPEG_SHIM_H
#define CFFMPEG_SHIM_H
#define STREAMEN_FFMPEG_SHIM 1

#include <errno.h>
#include <streamen_ffmpeg/libavutil/avutil.h>
#include <streamen_ffmpeg/libavutil/error.h>
#include <streamen_ffmpeg/libavutil/rational.h>

static inline int streamen_averror(int posix_errno) { return AVERROR(posix_errno); }
static inline int streamen_averror_eof(void) { return AVERROR_EOF; }
static inline int streamen_averror_eagain(void) { return AVERROR(EAGAIN); }
static inline int streamen_averror_exit(void) { return AVERROR_EXIT; }
static inline int streamen_averror_invaliddata(void) { return AVERROR_INVALIDDATA; }
static inline int streamen_averror_decoder_not_found(void) { return AVERROR_DECODER_NOT_FOUND; }

static inline int streamen_is_eagain(int ret) { return ret == AVERROR(EAGAIN); }
static inline int streamen_is_eof(int ret) { return ret == AVERROR_EOF; }

static inline int64_t streamen_av_nopts_value(void) { return AV_NOPTS_VALUE; }
static inline AVRational streamen_av_time_base_q(void) { return AV_TIME_BASE_Q; }

#endif /* CFFMPEG_SHIM_H */
