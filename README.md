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