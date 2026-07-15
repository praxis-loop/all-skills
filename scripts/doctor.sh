#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_ROOT="$REPO_ROOT/skills"

has_skill_entry() {
  [ -f "$1/SKILL.md" ] || [ -f "$1/skill.md" ]
}

list_skill_records() {
  [ -d "$SKILLS_ROOT" ] || return 0
  find "$SKILLS_ROOT" -mindepth 3 -maxdepth 3 -type d \
    | sort \
    | while IFS= read -r dir; do
        if has_skill_entry "$dir"; then
          domain_dir="$(dirname "$dir")"
          function_dir="$(dirname "$domain_dir")"
          function_name="$(basename "$function_dir")"
          domain_name="$(basename "$domain_dir")"
          skill_name="$(basename "$dir")"
          printf '%s|%s|%s|%s|%s\n' "$function_name/$domain_name/$skill_name" "$dir" "$skill_name" "$function_name" "$domain_name"
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
  while IFS='|' read -r display source_dir skill_name function_name domain_name; do
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

check_supply_chain() {
  echo
  echo "第三方 Skill 供应链状态："

  if [ ! -f "$REPO_ROOT/package.json" ] || [ ! -x "$REPO_ROOT/tools/skillctl" ]; then
    echo "  未启用 skillctl，跳过第三方来源/lockfile 检查"
    return
  fi

  if command -v npm >/dev/null 2>&1; then
    set +e
    (cd "$REPO_ROOT" && npm run skillctl -- check) | sed 's/^/  /'
    local status=${PIPESTATUS[0]}
    set -e
    if [ "$status" -ne 0 ]; then
      echo "  WARN: skillctl check 发现问题，请先处理来源、lockfile 或 integrity 差异"
    fi
  else
    echo "  WARN: 未找到 npm，无法运行 skillctl check"
  fi
}

check_git_sync() {
  echo
  echo "Git 同步状态："

  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  WARN: 当前目录不是 Git 仓库，无法判断远程同步状态"
    return
  fi

  local status_output
  status_output="$(git -C "$REPO_ROOT" status --short)"
  if [ -n "$status_output" ]; then
    echo "  WARN: 工作区存在未提交修改，需要 commit 后再同步远程"
    echo "$status_output" | sed 's/^/    /'
  else
    echo "  OK: 工作区干净"
  fi

  local upstream
  if ! upstream="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    echo "  WARN: 当前分支没有 upstream，无法判断是否需要 push 或 pull"
    echo "  建议：git push -u origin $(git -C "$REPO_ROOT" branch --show-current)"
    return
  fi

  local counts behind ahead
  counts="$(git -C "$REPO_ROOT" rev-list --left-right --count "$upstream...HEAD")"
  behind="${counts%%[[:space:]]*}"
  ahead="${counts##*[[:space:]]}"

  if [ "$ahead" -gt 0 ]; then
    echo "  WARN: 本地领先 $upstream $ahead 个提交，尚未推送"
    echo "  建议：git push"
  else
    echo "  OK: 本地没有未推送提交"
  fi

  if [ "$behind" -gt 0 ]; then
    echo "  WARN: 本地落后 $upstream $behind 个提交，需要同步远程更新"
    echo "  建议：git pull --ff-only"
  else
    echo "  OK: 本地没有落后 upstream"
  fi
}

echo "仓库：$REPO_ROOT"
echo

echo "发现的 skill："
count=0
last_group=""
while IFS='|' read -r display source_dir skill_name function_name domain_name; do
  [ -n "$display" ] || continue
  count=$((count + 1))
  group="$function_name/$domain_name"
  if [ "$group" != "$last_group" ]; then
    echo "  [$group]"
    last_group="$group"
  fi
  entry=""
  [ -f "$source_dir/SKILL.md" ] && entry="SKILL.md"
  [ -z "$entry" ] && [ -f "$source_dir/skill.md" ] && entry="skill.md"
  echo "    OK: $skill_name ($entry)"
done < <(list_skill_records)

if [ "$count" -eq 0 ]; then
  echo "  未发现 skill。请使用 skills/<function>/<domain>/<skill-name>/SKILL.md 结构。"
fi

check_target "$HOME/.agents/skills"
check_target "$HOME/.claude/skills"
check_target "$(pwd)/.claude/skills"
check_git_sync
check_supply_chain

echo
echo "检查完成。"
