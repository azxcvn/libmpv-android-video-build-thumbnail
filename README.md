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
- **`flavors/default.sh`:解码器/解封装器/解析器改为全部打开**(本项目自有改动,同步上游时勿被覆盖):
  - 把上游的 `--disable-decoders`/`--disable-demuxers`/`--disable-parsers` 改为
    `--enable-decoders`/`--enable-demuxers`/`--enable-parsers`,并删除上游那份**手写白名单**。
  - **为什么**:手写白名单的漏项是**静默失效**——构建成功,但那种格式永远解不出来,
    用户侧表现为「音轨/字幕能列出、选中后没反应,也没有任何提示」。本项目实际踩到两次:
    - 白名单漏 `pgssub`(PGS 蓝光位图字幕)→ 内嵌 PGS 轨选中后完全不显示
    - 白名单漏 `truehd`(注意 `mlp` **不带出** `truehd`)→ TrueHD 音轨完全无声
  - 全开后不再有「漏写」这一类问题;协议/编码器/滤镜仍保持上游的精确白名单,未改动。
  - 与仓库自带的 `flavors/full.sh` 同一套依赖(`depinfo.sh` 里 `default` 与 `full` 的
    `dep_ffmpeg`/`dep_mpv` 完全一致,都不含 `libx264`/`libvpx`/`libvorbis`),
    因此「全开」在 default flavor 下同样可行。

> ⚠️ **FFmpeg configure 的组件名 ≠ codec 的日志名**,写错会在 configure 阶段直接报
> `Unknown option`。本项目踩过的坑:
> | codec 日志名 | configure 组件名 | 说明 |
> |---|---|---|
> | `hdmv_pgs_subtitle` | **`pgssub`** | 组件名取自符号 `ff_pgssub_decoder`,不含 `hdmv_` 前缀 |
> | `truehd` | **`truehd`** | 是独立组件名(`ff_truehd_decoder`),但**和 `mlp` 都要写**——两者是 `mlpdec.c` 里两个独立解码器(`AV_CODEC_ID_MLP` / `AV_CODEC_ID_TRUEHD`),各自有独立的 `#if CONFIG_MLP_DECODER` / `#if CONFIG_TRUEHD_DECODER`,只写 `mlp` **不会**带出 `truehd`(实测:只开 mlp 时 `ff_truehd_decoder` 符号为 0,TrueHD 仍无声) |
>
> 排查方法(改完/换内核后可自检)。**只用符号名**(`ff_<组件名>_decoder`)判断,
> 短名/长名字符串在 `--enable-small` 下会被合并进一个大 blob,互相包含、极易误判:
> ```bash
> # 期望各出现 1 次(0 = 没编进去)
> strings libmpv.so | grep -c 'ff_pgssub_decoder'
> strings libmpv.so | grep -c 'ff_mlp_decoder'
> strings libmpv.so | grep -c 'ff_truehd_decoder'
> # 想一次列出全部已编入的解码器组件名(全开后会有 400+ 个):
> strings libmpv.so | grep -o 'ff_[a-z0-9_]*_decoder' | sort -u | wc -l
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