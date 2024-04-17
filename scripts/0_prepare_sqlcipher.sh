#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"

SQLCIPHER="$PROJECT_ROOT/sqlcipher"
DIST_DIR="$PROJECT_ROOT/Fire/SQLCipher"

cd $SQLCIPHER
./configure --with-crypto-lib=none
make sqlite3.c

echo "构建完成，移动 sqlite3.c 和 sqlite3.h 到 Fire/SQLCipher/ 目录"
mv -f sqlite3.c "$DIST_DIR/sqlite3.c"
mv -f sqlite3.h "$DIST_DIR/sqlite3.h"

echo "清理仓库"
git reset --hard
git clean -fd

echo "SQLCipher 已更新"