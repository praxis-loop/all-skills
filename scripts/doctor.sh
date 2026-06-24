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

check_target() {
  local target_dir="$1"
  echo
  echo "目标目录：$target_dir"
  if [ ! -d "$target_dir" ]; then
    echo "  不存在"
    return
  fi

  local found=0
  while IFS='|' read -r display source_dir skill_name category; do
    [ -n "$display" ] || continue
    local link_path="$target_dir/$skill_name"
    if [ -L "$link_path" ]; then
      local resolved
      resolved="$(cd "$(dirname "$link_path")" && readlink "$link_path")"
      echo "  OK: $display installed as $skill_name -> $resolved"
      found=1
    elif [ -e "$link_path" ]; then
      echo "  WARN: $display installed as $skill_name exists but is not a symlink"
      found=1
    fi
  done < <(list_skill_records)

  if [ "$found" -eq 0 ]; then
    echo "  未发现指向本仓库 skill 的常见安装项"
  fi
}

echo "仓库：$REPO_ROOT"
echo

echo "发现的 skill："
count=0
last_category=""
while IFS='|' read -r display source_dir skill_name category; do
  [ -n "$display" ] || continue
  count=$((count + 1))
  if [ "$category" != "$last_category" ]; then
    echo "  [$category]"
    last_category="$category"
  fi
  entry=""
  [ -f "$source_dir/SKILL.md" ] && entry="SKILL.md"
  [ -z "$entry" ] && [ -f "$source_dir/skill.md" ] && entry="skill.md"
  echo "    OK: $skill_name ($entry)"
done < <(list_skill_records)

if [ "$count" -eq 0 ]; then
  echo "  未发现 skill。请使用 skills/<category>/<skill-name>/SKILL.md 结构。"
fi

check_target "$HOME/.agents/skills"
check_target "$HOME/.claude/skills"
check_target "$(pwd)/.claude/skills"

echo
echo "检查完成。"
