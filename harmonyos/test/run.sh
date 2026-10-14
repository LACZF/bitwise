#!/bin/bash
set -e

TOP_DIR="$(cd "$(dirname "$0")" && pwd)"

# 计算核心的唯一源文件在鸿蒙工程里；每次运行前同步到本测试目录，
# 保证测试的是该 .ets 文件的当前内容。
cp "$TOP_DIR/../entry/src/main/ets/common/BitwiseCore.ets" "$TOP_DIR/src/BitwiseCore.ts"

cd "$TOP_DIR"

if [ ! -d node_modules ]; then
  echo "[run.sh] installing dev deps (typescript)..."
  npm install --no-audit --no-fund
fi

npm test