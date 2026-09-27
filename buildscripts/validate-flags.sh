#!/bin/bash
# 校验 flavor 脚本里的 FFmpeg --enable-*/--disable-* 开关在目标版本里是否合法。
#
# 为什么需要它：
#   FFmpeg 的 configure 对**未知的 --enable-*** 只打印 warning 就放行，
#   但对**未知的 --disable-*** 会直接 "Unknown option" 并退出。
#   FFmpeg 9.0 删除了 libpostproc，--disable-postproc 就成了非法选项，
#   结果 ffmpeg 编译直接失败。这类问题在升级 FFmpeg 时很容易踩到。
#
# 用法：
#   ./validate-flags.sh flavors/default.sh

set -u

FLAVOR="${1:-flavors/default.sh}"
FFMPEG_DIR="deps/ffmpeg"
CONFIGURE="$FFMPEG_DIR/configure"

if [ ! -f "$FLAVOR" ]; then
    echo "!! 找不到 flavor 文件: $FLAVOR"
    exit 1
fi
if [ ! -f "$CONFIGURE" ]; then
    echo "!! 找不到 $CONFIGURE（请先跑 download.sh）"
    exit 1
fi

# 取 configure 的权威选项清单（help 输出里的 --enable-xxx / --disable-xxx）
HELP=$(cd "$FFMPEG_DIR" && ./configure --help 2>/dev/null)
if [ -z "$HELP" ]; then
    echo "!! 无法获取 configure --help 输出"
    exit 1
fi

BAD=""
BAD_N=0
WARN=""
WARN_N=0

for flag in $(grep -oE '\-\-(enable|disable)-[a-z0-9_.-]+' "$FLAVOR" | sort -u); do
    name="${flag#--enable-}"
    name="${name#--disable-}"
    if printf '%s\n' "$HELP" | grep -qE "\-\-(enable|disable)-${name}([ =]|$)"; then
        continue
    fi
    case "$flag" in
        --disable-*)
            # 未知的 disable 会让 configure 直接退出
            echo "!!! [FAIL] 未知开关: $flag  (FFmpeg 不认这个 --disable-，configure 会直接报错退出)"
            BAD="$BAD $flag"
            BAD_N=$((BAD_N + 1))
            ;;
        *)
            echo "--- [warn] 未知开关: $flag  (configure 只会 warning，通常无害)"
            WARN="$WARN $flag"
            WARN_N=$((WARN_N + 1))
            ;;
    esac
done

echo ""
if [ "$BAD_N" -gt 0 ]; then
    echo "======================================================"
    echo "$FLAVOR 中存在 FFmpeg 不认的 --disable-* 开关：$BAD"
    echo "这会让 ffmpeg 的 configure 直接失败。请删除或改名后再构建。"
    echo "======================================================"
    exit 1
fi

echo "$FLAVOR 开关校验通过（未知 --enable-* 警告 $WARN_N 个：$WARN）"
exit 0
