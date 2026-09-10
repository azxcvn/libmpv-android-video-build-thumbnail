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
#
# 本项目自有改动(同步上游时勿被覆盖):
#   * 解码器/解封装器/解析器**全部打开**(--enable-decoders / --enable-demuxers /
#     --enable-parsers),删掉了上游那份手写白名单。
#     原因:白名单漏项是**静默失效**——构建成功、但那种格式永远解不出来,用户侧就是
#     "能列出、选中后没反应"。已实际踩到两次:
#       - 白名单漏 pgssub(PGS 蓝光位图字幕)→ 内嵌 PGS 轨选中后完全不显示
#       - 白名单漏 truehd(注意 mlp 不带出 truehd;mlpdec.c 里 ff_mlp_decoder 与
#         ff_truehd_decoder 是两个独立解码器/独立 CONFIG 开关)→ TrueHD 音轨无声
#     全开后不再有"漏写"这一类问题。协议(protocol)/编码器(encoder)/滤镜(filter)
#     仍保持上游的精确白名单,未改动。
#   * 与仓库自带的 flavors/full.sh 同一套依赖(depinfo.sh 里 default 与 full 的
#     dep_ffmpeg/dep_mpv 完全一致,都不带 libx264/libvpx/libvorbis),故全开是可行的。
#     同步上游时,若上游 default.sh 又新增白名单,直接按本文件的 --enable-decoders
#     等写法覆盖即可(不要退回逐项白名单)。
#
# 另:configure 的组件名 ≠ codec 日志名(如 hdmv_pgs_subtitle 的组件名是 pgssub),
# 写错会在 configure 阶段报 Unknown option;判断解码器是否编入要看**符号名**
# ff_<组件名>_decoder,不要用短名/长名字符串,详见仓库 README。
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
	--enable-decoders \
	--enable-demuxers \
	--enable-parsers \
	--disable-encoders \
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
