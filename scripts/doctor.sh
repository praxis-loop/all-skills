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

check_target() {
  local target_dir="$1"
  echo
  echo "目标目录：$target_dir"
  if [ ! -d "$target_dir" ]; then
    echo "  不存在"
    return
  fi

  local found=0
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    local link_path="$target_dir/$skill"
    if [ -L "$link_path" ]; then
      local resolved
      resolved="$(cd "$(dirname "$link_path")" && readlink "$link_path")"
      echo "  OK: $skill -> $resolved"
      found=1
    elif [ -e "$link_path" ]; then
      echo "  WARN: $skill 存在但不是软链接"
      found=1
    fi
  done < <(list_skills)

  if [ "$found" -eq 0 ]; then
    echo "  未发现指向本仓库 skill 的常见安装项"
  fi
}

echo "仓库：$REPO_ROOT"
echo

echo "发现的 skill："
count=0
while IFS= read -r skill; do
  [ -n "$skill" ] || continue
  count=$((count + 1))
  entry=""
  [ -f "$REPO_ROOT/$skill/SKILL.md" ] && entry="SKILL.md"
  [ -z "$entry" ] && [ -f "$REPO_ROOT/$skill/skill.md" ] && entry="skill.md"
  echo "  OK: $skill ($entry)"
done < <(list_skills)

if [ "$count" -eq 0 ]; then
  echo "  未发现 skill。每个 skill 目录需要包含 SKILL.md 或 skill.md。"
fi

check_target "$HOME/.agents/skills"
check_target "$HOME/.claude/skills"
check_target "$(pwd)/.claude/skills"

if [ -d "/etc/codex/skills" ]; then
  check_target "/etc/codex/skills"
fi

echo
echo "检查完成。"
