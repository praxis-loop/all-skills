#!/usr/bin/env bash
# 安装 / 卸载 macOS launchd 定时任务
# 用法：
#   ./install-schedule.sh                # 安装
#   ./install-schedule.sh --uninstall    # 卸载

set -euo pipefail

CONFIG_PATH="${HOME}/.clock-in/config.local.json"
LABEL="com.user.clock-in"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SH="${SCRIPT_DIR}/open-dingtalk-and-notify.sh"

uninstall() {
    if [[ ! -f "${PLIST_PATH}" ]]; then
        echo "Plist not found: ${PLIST_PATH}. Nothing to do."
        return
    fi
    launchctl unload "${PLIST_PATH}" 2>/dev/null || true
    rm -f "${PLIST_PATH}"
    echo "Uninstalled."
}

install() {
    if [[ ! -f "${CONFIG_PATH}" ]]; then
        echo "Config not found: ${CONFIG_PATH}. Run /clock-in 初始化 first." >&2
        exit 1
    fi

    if [[ ! -x "${SKILL_SH}" ]]; then
        chmod +x "${SKILL_SH}"
    fi

    # 从 config 读 schedule 字段（用 python3 解析，macOS 自带）
    read_schedule() {
        python3 -c "
import json, sys
c = json.load(open('${CONFIG_PATH}'))
s = c.get('schedule', {})
print(s.get('taskName', 'ClockInDaily'))
print(s.get('startTime', '08:50'))
print(s.get('randomDelayMinutes', 5))
print(','.join(s.get('daysOfWeek', ['Monday','Tuesday','Wednesday','Thursday','Friday'])))
"
    }
    mapfile -t SCHED < <(read_schedule)
    TASK_NAME="${SCHED[0]}"
    START_TIME="${SCHED[1]}"
    RANDOM_DELAY="${SCHED[2]}"
    DAYS_CSV="${SCHED[3]}"

    # launchd Weekday: 0/7=Sun, 1=Mon, 2=Tue, ..., 6=Sat
    declare -A DAY_NUM=([Sunday]=0 [Monday]=1 [Tuesday]=2 [Wednesday]=3 [Thursday]=4 [Friday]=5 [Saturday]=6)
    WEEKDAY_XML=""
    IFS=',' read -ra DAYS <<< "${DAYS_CSV}"
    for d in "${DAYS[@]}"; do
        trimmed="$(echo "${d}" | xargs)"  # trim whitespace
        n="${DAY_NUM[${trimmed}]}"
        [[ -z "${n}" ]] && continue
        WEEKDAY_XML+="        <key>Weekday</key><integer>${n}</integer>"$'\n'
    done

    # 解析 HH:MM
    HOUR="${START_TIME%%:*}"
    MIN="${START_TIME##*:}"

    mkdir -p "${HOME}/Library/LaunchAgents"

    cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SKILL_SH}</string>
        <string>${CONFIG_PATH}</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key><integer>${HOUR}</integer>
            <key>Minute</key><integer>${MIN}</integer>
${WEEKDAY_XML}    </dict>
    </array>
    <key>StandardOutPath</key>
    <string>${HOME}/.clock-in/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.clock-in/launchd.err.log</string>
</dict>
</plist>
EOF

    launchctl unload "${PLIST_PATH}" 2>/dev/null || true
    launchctl load "${PLIST_PATH}"

    echo "Installed: ${PLIST_PATH}"
    echo "Verify: launchctl list | grep ${LABEL}"
}

case "${1:-}" in
    --uninstall|-u) uninstall ;;
    "") install ;;
    *) echo "Usage: $0 [--uninstall]" >&2; exit 1 ;;
esac
