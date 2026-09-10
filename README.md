# libmpv-android-video-build-thumbnail

为 Android 平台构建 **libmpv**(基于 mpv 播放器内核)的项目。CI 产出的是打包成
`.jar`(实际是 zip)的原生库,内含 `libmpv.so` 及其依赖的 `.so`,`lib/*/` 目录按
ABI 组织(`arm64-v8a` / `armeabi-v7a` / `x86` / `x86_64`)。

## 来源与上游

本项目 fork 自 [Predidit/libmpv-android-video-build](https://github.com/Predidit/libmpv-android-video-build),
该仓库默认启用了 **gpu-next / vulkan** 渲染,这正是选用它作为基础的原因。

- **祖父源头**:[media-kit/libmpv-android-video-build](https://github.com/media-kit/libmpv-android-video-build)
  —— media-kit(Flutter 跨平台音视频库)的 Android 后端。
- **直接上游**:[Predidit/libmpv-android-video-build](https://github.com/Predidit/libmpv-android-video-build)
  —— 在 media-kit 版本基础上开启 gpu-next / vulkan。
- **本项目**:在 Predidit 版本基础上新增 **视频进度条缩略图** 能力。

```
media-kit/libmpv-android-video-build
        │ (fork, 开启 gpu-next / vulkan)
        ▼
Predidit/libmpv-android-video-build
        │ (fork, 新增缩略图补丁 + CI 修复)
        ▼
azxcvn/libmpv-android-video-build-thumbnail  (本项目)
```

## 相对上游的改动

- 新增 mpv 缩略图补丁 `buildscripts/patches/mpv/mk_thumbnail.patch`
  —— 为 mpv 加入 `libmpv/thumbnail.c`,支持视频进度条缩略图。
- 修复 CI 产物路径(`.github/workflows/build.yaml`),改为相对路径
  `buildscripts/*.jar`。
- 修复 zip 解压后丢失的 `.sh` / `gradlew` 可执行权限。
- **补齐 `flavors/default.sh` 的解码器白名单**(本项目自有改动,同步上游时勿被覆盖):
  - `--enable-decoder=pgssub` —— **PGS(蓝光位图)字幕**。上游白名单开了
    `dvbsub`/`dvdsub`/`ass`/`subrip` 等,唯独漏了 PGS,导致内嵌 PGS 字幕轨
    **能列出、选中后完全不显示**。
  - `--enable-decoder=truehd` + `--enable-decoder=mlp` —— **Dolby TrueHD(MLP FBA)音频**。
    上游白名单里有 `ac3`/`eac3`/`dca`(DTS),唯独没有 MLP/TrueHD,切到该音轨会**完全无声**
    (mpv 只在错误日志里报 `ad`/`ao` 错误)。
    ⚠️ **两个都必须写**:`mlpdec.c` 里 `ff_mlp_decoder` 与 `ff_truehd_decoder` 是**两个独立的
    解码器**(`AV_CODEC_ID_MLP` / `AV_CODEC_ID_TRUEHD`),各自包在独立的
    `#if CONFIG_MLP_DECODER` / `#if CONFIG_TRUEHD_DECODER` 里,**只写 `mlp` 不会带出 `truehd`**
    (实测过:只开 mlp 时 `ff_truehd_decoder` 符号为 0,TrueHD 轨仍然无声)。
  - 字幕解码器改为**顺手全开**(`*_subtitle` + 逐个列举: `ass`/`ssa`/`dvbsub`/`dvdsub`/
    `pgssub`/`movtext`/`pjs`/`srt`/`stl`/`subrip`/`subviewer`/`subviewer1`/`text`/`vplayer`/
    `webvtt`/`xsub`/`sami`/`microdvd`/`mpl2`/`realtext`/`jacosub`/`dvb_teletext`),
    末尾 `--disable-decoder=libaribcaption --disable-decoder=libzvbi_teletext`
    兜住 `*_subtitle`(这两个需要外部库)。

> ⚠️ **FFmpeg configure 的组件名 ≠ codec 的日志名**,写错会在 configure 阶段直接报
> `Unknown option`。本项目踩过的两个具体坑:
> | codec 日志名 | configure 组件名 | 说明 |
> |---|---|---|
> | `hdmv_pgs_subtitle` | **`pgssub`** | 组件名取自符号 `ff_pgssub_decoder`,不含 `hdmv_` 前缀 |
> | `truehd` | **`mlp`** | `mlpdec.c` 里 `ff_mlp_decoder` 与 `ff_truehd_decoder` 是**同一文件的两个符号**,但组件名只有一个 `mlp`;写 `--enable-decoder=truehd` 会报错 |
>
> 排查方法(改完/换内核后可自检)。**只用符号名**(`ff_<组件名>_decoder`)判断,
> 短名/长名字符串在 `--enable-small` 下会被合并进一个大 blob,互相包含、极易误判:
> ```bash
> # 期望各出现 1 次(0 = 没编进去)
> strings libmpv.so | grep -c 'ff_pgssub_decoder'
> strings libmpv.so | grep -c 'ff_mlp_decoder'
> strings libmpv.so | grep -c 'ff_truehd_decoder'
> # 想一次列出全部已编入的解码器组件名:
> strings libmpv.so | grep -o 'ff_[a-z0-9_]*_decoder' | sort -u
> ```
> 反例(误导过我们):`strings libmpv.so | grep truehd` 会命中
> `--enable-demuxer=truehd` 带来的**解封装器**名字,据此判断"解码器已编入"是错的。

## 产物

CI 构建产出 4 个按 ABI 区分的 jar(zip):`default-arm64-v8a.jar`、
`default-armeabi-v7a.jar`、`default-x86.jar`、`default-x86_64.jar`。
它们内部是 `lib/<abi>/*.so` 原生库,供上层应用(如 media_kit)通过 JNI 加载播放内核。

## 构建

依赖 Debian 环境 + Android NDK r27c。主要流程:

```bash
cd buildscripts
./bundle_default.sh    # 下载依赖 → 打补丁 → 交叉编译 → 打包 jar
```

也可直接查看 `.github/workflows/build.yaml` 了解 CI 的完整步骤。

## 重新生成缩略图补丁

当上游 mpv 版本更新(见 `buildscripts/include/depinfo.sh` 中的 `v_mpv`)时,
原有 `mk_thumbnail.patch` 可能不再适用,可用 `_gen_patch.ps1` 重新生成:

```powershell
# 编辑脚本顶部的 $sha 为新的 mpv commit 后执行
pwsh ./_gen_patch.ps1
```

## 许可

见 [LICENSE](LICENSE)。上游 mpv 及各自依赖遵循其原有许可。