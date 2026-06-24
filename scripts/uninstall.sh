#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_ROOT="$REPO_ROOT/skills"

has_skill_entry() {
  [ -f "$1/SKILL.md" ] || [ -f "$1/skill.md" ]
}

list_skill_records() {
  [ -d "$SKILLS_ROOT" ] || return 0
  find "$SKILLS_ROOT" -mindepth 2 -maxdepth 2 -type d \
    | sort \
    | while IFS= read -r dir; do
        if has_skill_entry "$dir"; then
          category="$(basename "$(dirname "$dir")")"
          name="$(basename "$dir")"
          printf '%s|%s|%s|%s\n' "$category/$name" "$dir" "$name" "$category"
        fi
      done
}

prompt_target_dir() {
  echo >&2
  echo "请选择卸载目标：" >&2
  echo "  1) Codex 用户级: ~/.agents/skills" >&2
  echo "  2) Claude Code 项目级: ./.claude/skills" >&2
  echo "  3) Claude Code 用户级: ~/.claude/skills" >&2
  echo "  4) 自定义目录" >&2
  read -r -p "输入编号 [1-4]: " target_choice

  case "${target_choice:-}" in
    1) printf '%s\n' "$HOME/.agents/skills" ;;
    2) printf '%s\n' "$(pwd)/.claude/skills" ;;
    3) printf '%s\n' "$HOME/.claude/skills" ;;
    4)
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

mapfile -t RECORDS < <(list_skill_records)
if [ "${#RECORDS[@]}" -eq 0 ]; then
  echo "没有发现 skill 目录。" >&2
  exit 1
fi

echo "发现以下 skill："
for i in "${!RECORDS[@]}"; do
  IFS='|' read -r display source_dir skill_name category <<< "${RECORDS[$i]}"
  printf "  %d) %s\n" "$((i + 1))" "$display"
done
echo "  a) 全部卸载"

read -r -p "请选择要卸载的 skill（例如 1,3 或 a）: " selection
TARGET_DIR="$(prompt_target_dir)"

declare -a SELECTED=()
if [ "$selection" = "a" ] || [ "$selection" = "A" ]; then
  SELECTED=("${RECORDS[@]}")
else
  IFS=',' read -ra PARTS <<< "$selection"
  for part in "${PARTS[@]}"; do
    part="${part//[[:space:]]/}"
    if ! [[ "$part" =~ ^[0-9]+$ ]]; then
      echo "无效选择：$part" >&2
      exit 1
    fi
    idx=$((part - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#RECORDS[@]}" ]; then
      echo "选择超出范围：$part" >&2
      exit 1
    fi
    SELECTED+=("${RECORDS[$idx]}")
  done
fi

for record in "${SELECTED[@]}"; do
  IFS='|' read -r display source_dir skill_name category <<< "$record"
  link_path="$TARGET_DIR/$skill_name"
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
