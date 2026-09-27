#!/bin/bash
# 打补丁。刻意不用 `bash -e`：
# 补丁失败必须被显式捕获并汇报，不能让第一处失败就把整个脚本带走、
# 后续补丁一个都不打，而外层 CI 照样继续构建出包。
# 曾经就是这样丢掉了 mpv 的 mk_thumbnail / mpv_lavc_set_java_vm 补丁，
# 也没人发现。
#
# 用法：
#   ./patch.sh               真正打补丁
#   ./patch.sh --check-only  只干跑校验（git apply --check），不修改任何文件
#
# 行为：
#   * 成功 -> 打印 `--- [OK]`
#   * 失败 -> 打印 `!!! [FAIL]`，收集起来，跑完全部后统一 exit 1
#   * 0 字节的补丁文件 -> 跳过并告警（git apply 对空文件会报 unrecognized input）
#
# 注意：补丁路径会在 `cd deps/$dep` **之前**就展开成绝对路径。
# 早期版本在 cd 之后才展开相对 glob，导致每个补丁都被静默跳过、
# 却仍然报告"全部通过"——那是个会骗人的假绿。

CHECK_ONLY=0
case "$1" in
    --check-only) CHECK_ONLY=1 ;;
    "") ;;
    *) echo "未知参数: $1"; echo "用法: $0 [--check-only]"; exit 2 ;;
esac

if [ "$CHECK_ONLY" = "1" ]; then
    echo "== 补丁预检模式（--check-only，不修改文件） =="
fi

ROOT=$(pwd)
FAILURES=""

for dep_path in patches/*; do
    [ -d "$dep_path" ] || continue
    dep=$(echo "$dep_path" | cut -d/ -f 2)

    # 关键：在进目录之前，把补丁列表展开成绝对路径
    patch_list=("$ROOT/$dep_path"/*)

    if [ ! -d "deps/$dep" ]; then
        echo "!! 依赖目录不存在: deps/$dep"
        FAILURES="$FAILURES
  $dep: deps/$dep 不存在"
        continue
    fi
    cd "deps/$dep" || { echo "!! 无法进入 deps/$dep"; FAILURES="$FAILURES
  $dep: cd 失败"; continue; }
    echo "===== Patching $dep ====="
    for patch in "${patch_list[@]}"; do
        pname=$(basename "$patch")
        if [ ! -f "$patch" ]; then
            echo "--- [skip] $dep/$pname（补丁不存在或不是普通文件）"
            continue
        fi
        size=$(wc -c < "$patch" | tr -d ' ')
        if [ "$size" -eq 0 ]; then
            echo "--- [skip] $dep/$pname（0 字节空补丁，跳过）"
            continue
        fi

        if [ "$CHECK_ONLY" = "1" ]; then
            if git apply --check "$patch"; then
                echo "--- [OK]   $dep/$pname（$size 字节，可应用）"
            else
                echo "!!! [FAIL] $dep/$pname（$size 字节，无法应用）"
                FAILURES="$FAILURES
  $dep/$pname: git apply --check 失败"
            fi
        else
            if git apply "$patch"; then
                echo "--- [OK]   $dep/$pname（$size 字节）"
            else
                echo "!!! [FAIL] $dep/$pname（$size 字节）"
                FAILURES="$FAILURES
  $dep/$pname: git apply 失败"
            fi
        fi
    done
    cd "$ROOT" || exit 1
done

if [ -n "$FAILURES" ]; then
    echo ""
    echo "======================================================"
    echo "补丁存在失败项：$FAILURES"
    echo "======================================================"
    exit 1
fi

if [ "$CHECK_ONLY" = "1" ]; then
    echo ""
    echo "补丁预检通过：全部补丁均可干净应用。"
else
    echo ""
    echo "所有补丁均已成功应用。"
fi
exit 0
