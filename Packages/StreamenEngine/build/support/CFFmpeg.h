// Umbrella header for the CFFmpeg module (StreamenEngine binary distribution).
#ifndef CFFMPEG_UMBRELLA_H
#define CFFMPEG_UMBRELLA_H

#include <streamen_ffmpeg/libavformat/avformat.h>
#include <streamen_ffmpeg/libavformat/avio.h>
#include <streamen_ffmpeg/libavformat/version.h>

#include <streamen_ffmpeg/libavcodec/avcodec.h>
#include <streamen_ffmpeg/libavcodec/codec.h>
#include <streamen_ffmpeg/libavcodec/codec_desc.h>
#include <streamen_ffmpeg/libavcodec/bsf.h>
#include <streamen_ffmpeg/libavcodec/videotoolbox.h>
#include <streamen_ffmpeg/libavcodec/version.h>

#include <streamen_ffmpeg/libavutil/avutil.h>
#include <streamen_ffmpeg/libavutil/opt.h>
#include <streamen_ffmpeg/libavutil/dict.h>
#include <streamen_ffmpeg/libavutil/error.h>
#include <streamen_ffmpeg/libavutil/frame.h>
#include <streamen_ffmpeg/libavutil/imgutils.h>
#include <streamen_ffmpeg/libavutil/samplefmt.h>
#include <streamen_ffmpeg/libavutil/channel_layout.h>
#include <streamen_ffmpeg/libavutil/pixdesc.h>
#include <streamen_ffmpeg/libavutil/pixfmt.h>
#include <streamen_ffmpeg/libavutil/time.h>
#include <streamen_ffmpeg/libavutil/mathematics.h>
#include <streamen_ffmpeg/libavutil/rational.h>
#include <streamen_ffmpeg/libavutil/display.h>
#include <streamen_ffmpeg/libavutil/log.h>
#include <streamen_ffmpeg/libavutil/hwcontext.h>
#include <streamen_ffmpeg/libavutil/hwcontext_videotoolbox.h>
#include <streamen_ffmpeg/libavutil/mastering_display_metadata.h>
#include <streamen_ffmpeg/libavutil/hdr_dynamic_metadata.h>
#include <streamen_ffmpeg/libavutil/dovi_meta.h>
#include <streamen_ffmpeg/libavutil/stereo3d.h>
#include <streamen_ffmpeg/libavutil/version.h>

#include <streamen_ffmpeg/libswresample/swresample.h>
#include <streamen_ffmpeg/libswscale/swscale.h>

#include <streamen_ffmpeg/libavfilter/avfilter.h>
#include <streamen_ffmpeg/libavfilter/buffersrc.h>
#include <streamen_ffmpeg/libavfilter/buffersink.h>

#include "CFFmpegShim.h"

#endif /* CFFMPEG_UMBRELLA_H */
