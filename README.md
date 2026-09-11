# libmpv-android-video-build-thumbnail

为 Android 平台构建 **libmpv**（基于 mpv 播放器内核）的项目。在默认启用 **gpu-next / vulkan** 渲染的基础上，新增视频进度条缩略图能力。

## 来源与上游

本项目 fork 自 [@Predidit](https://github.com/Predidit) 的 [libmpv-android-video-build](https://github.com/Predidit/libmpv-android-video-build)。该版本在 [media-kit/libmpv-android-video-build](https://github.com/media-kit/libmpv-android-video-build) 基础上开启了 gpu-next / vulkan 渲染。

- **祖父源头**：media-kit/libmpv-android-video-build — media-kit（Flutter 跨平台音视频库）的 Android 后端。
- **直接上游**：[@Predidit](https://github.com/Predidit) 的 libmpv-android-video-build — 在 media-kit 版本基础上开启 gpu-next / vulkan。
- **本项目**：在 [@Predidit](https://github.com/Predidit) 版本基础上新增视频进度条缩略图能力。

## 相对上游的改动

- 新增 mpv 缩略图补丁 `buildscripts/patches/mpv/mk_thumbnail.patch`，为 mpv 加入 `libmpv/thumbnail.c`，支持视频进度条缩略图。
- 修复 CI 产物路径（`.github/workflows/build.yaml`），改为相对路径 `buildscripts/*.jar`。
- 修复 zip 解压后丢失的 `.sh` / `gradlew` 可执行权限。
- `flavors/default.sh` 解码器/解封装器/解析器改为全部打开，修复上游白名单漏项导致的 PGS 字幕不显示与 TrueHD 音频无声问题；协议/编码器/滤镜仍保持上游白名单，同步上游时勿被覆盖。

> 改动原因、自检方法与踩坑记录见 [`DOCS/自有改动说明与踩坑.md`](DOCS/自有改动说明与踩坑.md)。

## 重新生成缩略图补丁

当上游 mpv 版本更新（见 `buildscripts/include/depinfo.sh` 中的 `v_mpv`）时，原有 `mk_thumbnail.patch` 可能不再适用。编辑 `_gen_patch.ps1` 顶部的 `$sha` 为新的 mpv commit 后执行：

```pwsh
pwsh ./_gen_patch.ps1
```

## 许可

见 [LICENSE](LICENSE)。

上游 mpv 及各自依赖遵循其原有许可。
