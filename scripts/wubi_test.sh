#!/bin/bash
# 大量输入测试脚本 - 使用 osascript 模拟按键
# 用法:
#   bash wubi_test.sh [分钟数] [起始位置]
# 例:
#   bash wubi_test.sh           # 默认 1 分钟，从头开始
#   bash wubi_test.sh 5         # 5 分钟，从头开始
#   bash wubi_test.sh 5 1234    # 5 分钟，从第 1234 个编码开始

MINUTES=${1:-1}
START=${2:-0}
TIMEOUT=$(( MINUTES * 60 ))

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"

DICT="$PROJECT_ROOT/Fire/Resources/wb_table.txt"

CODES=($(grep -v "^#" "$DICT" 2>/dev/null | awk '{print $1}' | grep -E "^[a-z]+$" | sort -u))
COUNT=${#CODES[@]}
if [ $COUNT -eq 0 ]; then
    echo "错误: 无法读取码表 $DICT"
    exit 1
fi
echo "加载了 $COUNT 个编码，从第 $START 个开始"

type_code() {
    local code="$1"
    for (( i=0; i<${#code}; i++ )); do
        local ch="${code:$i:1}"
        osascript -e "tell application \"System Events\" to keystroke \"$ch\""
        sleep 0.015
    done
    sleep 0.02
    osascript -e 'tell application "System Events" to keystroke space'
}

echo "=========================================="
echo "业火五笔 大量输入测试（${MINUTES} 分钟）"
echo "共 $COUNT 个编码，循环输入"
echo "=========================================="
echo ""
echo "5 秒后开始..."
echo "请切换到文本编辑器，确保业火五笔处于中文模式"
sleep 5

t0=$(date +%s)
total=0
loop_idx=$START

while true; do
    now=$(date +%s)
    elapsed=$(( now - t0 ))
    if [ $elapsed -ge $TIMEOUT ]; then
        rate=$(echo "scale=1; $total / $elapsed" | bc 2>/dev/null || echo "$total")
        echo ""
        echo "=========================================="
        echo "测试结束（${MINUTES} 分钟已到）"
        echo "共输入 $total 次，$rate 次/秒"
        echo "当前编码: $(echo "${CODES[$loop_idx]}") 序号: $loop_idx"
        echo "下次续传: bash wubi_test.sh ${MINUTES} $loop_idx"
        echo "=========================================="
        exit 0
    fi

    code="${CODES[$loop_idx]}"
    type_code "$code"
    total=$(( total + 1 ))

    loop_idx=$(( loop_idx + 1 ))
    if [ $loop_idx -ge $COUNT ]; then
        loop_idx=0
    fi

    if [ $(( total % 50 )) -eq 0 ]; then
        rate=$(echo "scale=1; $total / $elapsed" | bc 2>/dev/null || echo "$total")
        progress=$(( loop_idx + 1 ))
        pct=$(echo "scale=0; $progress * 100 / $COUNT" | bc)
        remaining=$(( TIMEOUT - elapsed ))
        echo "  #$total  ${rate}次/秒  编码 ${progress}/${COUNT}(${pct}%)  剩余${remaining}s"
    fi

    sleep 0.05
done

