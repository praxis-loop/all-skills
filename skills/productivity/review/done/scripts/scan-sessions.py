#!/usr/bin/env python3
"""扫描当前项目的历史会话 transcript, 抽取用户意图, 供 done skill 做跨会话聚类。

只输出"用户说了什么/想干什么", 不通读 assistant 输出与工具调用, 以省 token。
路径全部参数化, 不硬编码个人目录。

用法:
  scan-sessions.py [--config-dir DIR] [--cwd PATH] [--exclude SESSION_ID]
                   [--max-intents-per-session N] [--intent-chars N]

  --config-dir  CLAUDE_CONFIG_DIR, 默认取环境变量, 再回退 ~/.claude
  --cwd         项目工作目录, 默认取当前 CWD; 用于推导 projects/<munged> 目录
  --exclude     要排除的当前 session id(它已在 agent 上下文里)
输出: JSON, 结构见文件末尾 print。
"""
import argparse
import json
import os
import re
from datetime import datetime, timezone


def munge_cwd(cwd: str) -> str:
    """把 cwd 编码成 Claude Code projects/ 目录名。

    Claude Code 把路径里所有非字母数字字符('/', '_', '.', '\\' 等)都替换成 '-'。
    例: /home/xan/oazon_sync -> -home-xan-oazon-sync
    """
    return re.sub(r"[^a-zA-Z0-9]", "-", cwd)


def extract_text(content) -> str:
    """从 message.content(字符串或 block 列表)取出纯文本, 跳过 tool_result 等。"""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for blk in content:
            if isinstance(blk, dict) and blk.get("type") == "text":
                t = blk.get("text", "")
                if isinstance(t, str):
                    parts.append(t)
        return " ".join(parts).strip()
    return ""


NOISE_PREFIXES = ("<", "[Request interrupted", "Caveat:")
NOISE_SUBSTRINGS = ("<command-name>", "<local-command", "<system-reminder>")


def is_noise(text: str) -> bool:
    if not text:
        return True
    if text.startswith(NOISE_PREFIXES):
        return True
    if any(s in text for s in NOISE_SUBSTRINGS):
        return True
    # 纯 slash 命令回显 (如 /clear /compact) 视为噪音
    if text.startswith("/") and len(text.split()) <= 2:
        return True
    return False


def scan_file(path: str, max_intents: int, intent_chars: int):
    session_id = os.path.splitext(os.path.basename(path))[0]
    intents = []
    seen = set()
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("type") != "user":
                    continue
                msg = obj.get("message")
                if not isinstance(msg, dict):
                    continue
                text = extract_text(msg.get("content"))
                if is_noise(text):
                    continue
                text = " ".join(text.split())  # 折叠空白/换行
                snippet = text[:intent_chars]
                key = snippet.lower()
                if key in seen:
                    continue
                seen.add(key)
                intents.append(snippet)
                if len(intents) >= max_intents:
                    break
    except OSError as e:
        return None, str(e)

    try:
        mtime = os.path.getmtime(path)
        date = datetime.fromtimestamp(mtime, tz=timezone.utc).astimezone().strftime("%Y-%m-%d")
    except OSError:
        date = ""

    return {
        "session_id": session_id,
        "date": date,
        "opening_intent": intents[0] if intents else "",
        "intents": intents,
    }, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config-dir", default=os.environ.get("CLAUDE_CONFIG_DIR"))
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--exclude", default="")
    ap.add_argument("--max-intents-per-session", type=int, default=12)
    ap.add_argument("--intent-chars", type=int, default=300)
    args = ap.parse_args()

    config_dir = args.config_dir or os.path.expanduser("~/.claude")
    projects_dir = os.path.join(config_dir, "projects", munge_cwd(args.cwd))

    result = {
        "projects_dir": projects_dir,
        "cwd": args.cwd,
        "excluded": args.exclude,
        "sessions": [],
        "warnings": [],
    }

    if not os.path.isdir(projects_dir):
        result["warnings"].append(f"projects dir not found: {projects_dir}")
        result["session_count"] = 0
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    files = sorted(
        (os.path.join(projects_dir, f) for f in os.listdir(projects_dir) if f.endswith(".jsonl")),
        key=lambda p: os.path.getmtime(p),
    )

    for path in files:
        sid = os.path.splitext(os.path.basename(path))[0]
        if args.exclude and sid == args.exclude:
            continue
        data, err = scan_file(path, args.max_intents_per_session, args.intent_chars)
        if err:
            result["warnings"].append(f"{sid}: {err}")
            continue
        if data and data["intents"]:
            result["sessions"].append(data)

    # 按时间倒序, 最近的会话在前
    result["sessions"].reverse()
    result["session_count"] = len(result["sessions"])
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
