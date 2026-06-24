#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d .git ]; then
  echo "当前目录不是 Git 仓库，无法自动更新：$REPO_ROOT" >&2
  exit 1
fi

git pull --ff-only

echo "更新完成。由于安装方式是软链接，已安装的 skill 会自动指向最新内容。"
