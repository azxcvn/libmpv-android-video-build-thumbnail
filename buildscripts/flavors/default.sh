#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

cpu=armv7-a
[[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
[[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
[[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

cpuflags=
[[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

sed -i -e 's/#define FFMPEG_CONFIGURATION.*/#define FFMPEG_CONFIGURATION ""/' ../configure

# 注意:下面是一个反斜杠续行的长命令,续行中间**不能**插 # 注释(bash 会把注释行
# 当成参数接到上一行),所以本文件的说明一律写在这里。
# 本项目在解码器白名单上的自有改动(同步上游时勿被覆盖):
#   * 字幕解码器改为顺手全开(--enable-decoder=*_subtitle + 逐个列举),
#     因为上游白名单漏了 pgssub(PGS 位图字幕)→ 内嵌 PGS 轨选中后完全不显示。
#   * 补 --enable-decoder=truehd + --enable-decoder=mlp:上游白名单里没有 MLP/TrueHD
#     → TrueHD 音轨完全无声。**两个都要写**:mlpdec.c 里 ff_mlp_decoder 与
#     ff_truehd_decoder 各自有独立的 #if CONFIG_MLP_DECODER / #if CONFIG_TRUEHD_DECODER
#     开关(是不同的 AVCodecID),只写 mlp 不会带出 truehd。
#     判断是否真的编进去了,看符号:ff_mlp_decoder 与 ff_truehd_decoder 应各出现 1 次。
#   * 末尾两条 --disable-decoder=libaribcaption/libzvbi_teletext 用来兜住
#     *_subtitle 通配(这两个需要外部库),**必须排在 enable 之后**(后者覆盖前者)。
# 另外:configure 的组件名 ≠ codec 日志名(如 hdmv_pgs_subtitle 的组件名是 pgssub),
# 写错会在 configure 阶段报 Unknown option,详见仓库 README。
../configure \
	--target-os=android --enable-cross-compile --cross-prefix=$ndk_triple- --ar=$AR --cc=$CC --ranlib=$RANLIB \
	--arch=${ndk_triple%%-*} --cpu=$cpu --pkg-config=pkg-config \
	--extra-cflags="-I$prefix_dir/include $cpuflags" --extra-ldflags="-L$prefix_dir/lib" \
	\
	--disable-gpl \
	--disable-nonfree \
	--enable-version3 \
	--enable-static \
	--disable-shared \
	--disable-vulkan \
	--disable-iconv \
	--pkg-config-flags=--static \
	\
	--disable-muxers \
	--disable-decoders \
	--disable-encoders \
	--disable-demuxers \
	--disable-parsers \
	--disable-protocols \
	--disable-devices \
	--disable-filters \
	--disable-doc \
	--disable-avdevice \
	--disable-postproc \
	--disable-programs \
	--disable-gray \
	--disable-swscale-alpha \
	\
	--enable-jni \
	--enable-bsfs \
	--enable-mediacodec \
	\
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	--disable-bzlib \
	--disable-linux-perf \
	--disable-videotoolbox \
	--disable-audiotoolbox \
	\
	--enable-small \
	--enable-hwaccels \
	--enable-optimizations \
	--enable-runtime-cpudetect \
	\
	--enable-mbedtls \
	\
	--enable-libdav1d \
	\
	--enable-libxml2 \
	\
	--enable-avutil \
	--enable-avcodec \
	--enable-avfilter \
	--enable-avformat \
	--enable-swscale \
	--enable-swresample \
	\
	--enable-decoder=flv \
	--enable-decoder=h263 \
	--enable-decoder=h263i \
	--enable-decoder=h263p \
	--enable-decoder=h264* \
	--enable-decoder=mpeg1video \
	--enable-decoder=mpeg2* \
	--enable-decoder=mpeg4* \
	--enable-decoder=vp6 \
	--enable-decoder=vp6a \
	--enable-decoder=vp6f \
	--enable-decoder=vp8* \
	--enable-decoder=vp9* \
	--enable-decoder=hevc* \
	--enable-decoder=av1* \
	--enable-decoder=libdav1d \
	--enable-decoder=theora \
	--enable-decoder=msmpeg* \
	--enable-decoder=mjpeg* \
	--enable-decoder=wmv* \
	\
	--enable-decoder=aac* \
	--enable-decoder=ac3 \
	--enable-decoder=alac \
	--enable-decoder=als \
	--enable-decoder=ape \
	--enable-decoder=atrac* \
	--enable-decoder=eac3 \
	--enable-decoder=flac \
	--enable-decoder=gsm* \
	--enable-decoder=mp1* \
	--enable-decoder=mp2* \
	--enable-decoder=mp3* \
	--enable-decoder=mpc* \
	--enable-decoder=opus \
	--enable-decoder=ra* \
	--enable-decoder=ralf \
	--enable-decoder=shorten \
	--enable-decoder=tak \
	--enable-decoder=tta \
	--enable-decoder=vorbis \
	--enable-decoder=wavpack \
	--enable-decoder=wma* \
	--enable-decoder=pcm* \
	--enable-decoder=dsd* \
	--enable-decoder=dca \
	--enable-decoder=truehd \
	--enable-decoder=mlp \
	\
	--enable-decoder=*_subtitle \
	--enable-decoder=ass \
	--enable-decoder=ssa \
	--enable-decoder=dvbsub \
	--enable-decoder=dvdsub \
	--enable-decoder=pgssub \
	--enable-decoder=movtext \
	--enable-decoder=pjs \
	--enable-decoder=srt \
	--enable-decoder=stl \
	--enable-decoder=subrip \
	--enable-decoder=subviewer \
	--enable-decoder=subviewer1 \
	--enable-decoder=text \
	--enable-decoder=vplayer \
	--enable-decoder=webvtt \
	--enable-decoder=xsub \
	--enable-decoder=sami \
	--enable-decoder=microdvd \
	--enable-decoder=mpl2 \
	--enable-decoder=realtext \
	--enable-decoder=jacosub \
	--enable-decoder=dvb_teletext \
	--disable-decoder=libaribcaption \
	--disable-decoder=libzvbi_teletext \
	\
	--enable-demuxer=concat \
	--enable-demuxer=data \
	--enable-demuxer=flv \
	--enable-demuxer=hls \
	--enable-demuxer=latm \
	--enable-demuxer=live_flv \
	--enable-demuxer=loas \
	--enable-demuxer=m4v \
	--enable-demuxer=mov \
	--enable-demuxer=mpegps \
	--enable-demuxer=mpegts \
	--enable-demuxer=mpegvideo \
	--enable-demuxer=hevc \
	--enable-demuxer=rtsp \
	--enable-demuxer=mpeg4 \
	--enable-demuxer=mjpeg* \
	--enable-demuxer=avi \
	--enable-demuxer=av1 \
	--enable-demuxer=matroska \
	--enable-demuxer=dash \
	--enable-demuxer=webm_dash_manifest \
	\
	--enable-demuxer=aac \
	--enable-demuxer=ac3 \
	--enable-demuxer=aiff \
	--enable-demuxer=ape \
	--enable-demuxer=asf \
	--enable-demuxer=au \
	--enable-demuxer=avi \
	--enable-demuxer=flac \
	--enable-demuxer=flv \
	--enable-demuxer=matroska \
	--enable-demuxer=mov \
	--enable-demuxer=m4v \
	--enable-demuxer=mp3 \
	--enable-demuxer=mpc* \
	--enable-demuxer=ogg \
	--enable-demuxer=pcm* \
	--enable-demuxer=rm \
	--enable-demuxer=shorten \
	--enable-demuxer=tak \
	--enable-demuxer=tta \
	--enable-demuxer=wav \
	--enable-demuxer=wv \
	--enable-demuxer=xwma \
	--enable-demuxer=dsf \
	--enable-demuxer=truehd \
        --enable-demuxer=dts \
        --enable-demuxer=dtshd \
	\
	--enable-demuxer=ass \
	--enable-demuxer=srt \
	--enable-demuxer=stl \
	--enable-demuxer=webvtt \
	--enable-demuxer=subviewer \
	--enable-demuxer=subviewer1 \
	--enable-demuxer=vplayer \
	\
	--enable-parser=h263 \
	--enable-parser=h264 \
	--enable-parser=hevc \
	--enable-parser=mpeg4 \
	--enable-parser=mpeg4video \
	--enable-parser=mpegvideo \
	\
	--enable-parser=aac* \
	--enable-parser=ac3 \
	--enable-parser=cook \
	--enable-parser=dca \
	--enable-parser=flac \
	--enable-parser=gsm \
	--enable-parser=mpegaudio \
	--enable-parser=tak \
	--enable-parser=vorbis \
 	--enable-parser=dca \
	\
	--enable-filter=overlay \
	--enable-filter=equalizer \
	\
	--enable-protocol=async \
	--enable-protocol=cache \
	--enable-protocol=crypto \
	--enable-protocol=data \
	--enable-protocol=ffrtmphttp \
	--enable-protocol=file \
	--enable-protocol=ftp \
	--enable-protocol=hls \
	--enable-protocol=http \
	--enable-protocol=httpproxy \
	--enable-protocol=https \
	--enable-protocol=pipe \
	--enable-protocol=rtmp \
	--enable-protocol=rtmps \
	--enable-protocol=rtmpt \
	--enable-protocol=rtmpts \
	--enable-protocol=rtp \
	--enable-protocol=subfile \
	--enable-protocol=tcp \
	--enable-protocol=tls \
	--enable-protocol=srt \
	\
	--enable-encoder=mjpeg \
	--enable-encoder=ljpeg \
	--enable-encoder=jpegls \
	--enable-encoder=jpeg2000 \
	--enable-encoder=png \
	--enable-encoder=jpegls \
	\
	--enable-network \

make -j$cores
make DESTDIR="$prefix_dir" install

ln -sf "$prefix_dir"/lib/libswresample.so "$native_dir"
ln -sf "$prefix_dir"/lib/libpostproc.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavutil.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavcodec.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavformat.so "$native_dir"
ln -sf "$prefix_dir"/lib/libswscale.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavfilter.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavdevice.so "$native_dir"
