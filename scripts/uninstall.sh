#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

has_skill_entry() {
  [ -f "$1/SKILL.md" ] || [ -f "$1/skill.md" ]
}

list_skills() {
  find "$REPO_ROOT" -mindepth 1 -maxdepth 1 -type d \
    ! -name ".git" ! -name "scripts" \
    | sort \
    | while IFS= read -r dir; do
        if has_skill_entry "$dir"; then
          basename "$dir"
        fi
      done
}

prompt_target_dir() {
  echo >&2
  echo "请选择卸载目标：" >&2
  echo "  1) Codex 用户级: ~/.agents/skills" >&2
  echo "  2) Codex 机器级: /etc/codex/skills" >&2
  echo "  3) Claude Code 项目级: ./.claude/skills" >&2
  echo "  4) Claude Code 用户级: ~/.claude/skills" >&2
  echo "  5) 自定义目录" >&2
  read -r -p "输入编号 [1-5]: " target_choice

  case "${target_choice:-}" in
    1) printf '%s\n' "$HOME/.agents/skills" ;;
    2) printf '%s\n' "/etc/codex/skills" ;;
    3) printf '%s\n' "$(pwd)/.claude/skills" ;;
    4) printf '%s\n' "$HOME/.claude/skills" ;;
    5)
      read -r -p "请输入目标目录绝对路径或相对路径: " custom_dir
      if [ -z "${custom_dir:-}" ]; then
        echo "自定义目录不能为空" >&2
        exit 1
      fi
      case "$custom_dir" in
        ~*) printf '%s\n' "${custom_dir/#\~/$HOME}" ;;
        /*) printf '%s\n' "$custom_dir" ;;
        *) printf '%s\n' "$(pwd)/$custom_dir" ;;
      esac
      ;;
    *)
      echo "无效选择" >&2
      exit 1
      ;;
  esac
}

mapfile -t SKILLS < <(list_skills)
if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "没有发现 skill 目录。" >&2
  exit 1
fi

echo "发现以下 skill："
for i in "${!SKILLS[@]}"; do
  printf "  %d) %s\n" "$((i + 1))" "${SKILLS[$i]}"
done
echo "  a) 全部卸载"

read -r -p "请选择要卸载的 skill（例如 1,3 或 a）: " selection
TARGET_DIR="$(prompt_target_dir)"

declare -a SELECTED=()
if [ "$selection" = "a" ] || [ "$selection" = "A" ]; then
  SELECTED=("${SKILLS[@]}")
else
  IFS=',' read -ra PARTS <<< "$selection"
  for part in "${PARTS[@]}"; do
    part="${part//[[:space:]]/}"
    if ! [[ "$part" =~ ^[0-9]+$ ]]; then
      echo "无效选择：$part" >&2
      exit 1
    fi
    idx=$((part - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#SKILLS[@]}" ]; then
      echo "选择超出范围：$part" >&2
      exit 1
    fi
    SELECTED+=("${SKILLS[$idx]}")
  done
fi

for skill in "${SELECTED[@]}"; do
  link_path="$TARGET_DIR/$skill"
  if [ -L "$link_path" ]; then
    rm "$link_path"
    echo "已删除软链接：$link_path"
  elif [ -e "$link_path" ]; then
    echo "跳过：$link_path 存在但不是软链接"
  else
    echo "未安装：$link_path"
  fi
done

echo "卸载完成。"
