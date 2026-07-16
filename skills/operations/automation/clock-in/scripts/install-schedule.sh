#!/usr/bin/env bash
# 安装 / 卸载 macOS launchd 定时任务
# 用法：
#   ./install-schedule.sh                # 安装
#   ./install-schedule.sh --uninstall    # 卸载

set -euo pipefail

CONFIG_PATH="${HOME}/.clock-in/config.local.json"
LABEL_PREFIX="com.user.clock-in"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SH="${SCRIPT_DIR}/open-dingtalk-and-notify.sh"

read_schedules() {
    python3 - "${CONFIG_PATH}" <<'PY'
import json
import sys

config_path = sys.argv[1]
with open(config_path, "r", encoding="utf-8") as fh:
    config = json.load(fh)

if "schedules" in config:
    schedules = config["schedules"]
    if not schedules:
        raise SystemExit("Missing required config value: schedules")
elif "schedule" in config:
    schedules = [config["schedule"]]
else:
    schedules = [{
        "taskName": "ClockInDaily",
        "startTime": "08:50",
        "randomDelayMinutes": 5,
        "daysOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
    }]

for schedule in schedules:
    task_name = schedule.get("taskName") or "ClockInDaily"
    start_time = schedule.get("startTime") or "08:50"
    random_delay = schedule.get("randomDelayMinutes", 5)
    days = schedule.get("daysOfWeek") or ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    print("\t".join([str(task_name), str(start_time), str(random_delay), ",".join(days)]))
PY
}

label_for_task() {
    local task_name="$1"
    local suffix
    suffix="$(printf '%s' "${task_name}" | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')"
    if [[ -z "${suffix}" ]]; then
        suffix="daily"
    fi
    printf '%s.%s\n' "${LABEL_PREFIX}" "${suffix}"
}

uninstall_one() {
    local task_name="$1"
    local label plist_path

    label="$(label_for_task "${task_name}")"
    plist_path="${HOME}/Library/LaunchAgents/${label}.plist"

    if [[ ! -f "${plist_path}" ]]; then
        echo "Plist not found: ${plist_path}. Nothing to do."
        return
    fi
    launchctl unload "${plist_path}" 2>/dev/null || true
    rm -f "${plist_path}"
    echo "Uninstalled: ${label}"
}

install_one() {
    local task_name="$1"
    local start_time="$2"
    local random_delay="$3"
    local days_csv="$4"
    local label plist_path hour minute calendar_xml

    label="$(label_for_task "${task_name}")"
    plist_path="${HOME}/Library/LaunchAgents/${label}.plist"

    # launchd Weekday: 0/7=Sun, 1=Mon, 2=Tue, ..., 6=Sat
    calendar_xml=""

    hour="${start_time%%:*}"
    minute="${start_time##*:}"

    IFS=',' read -ra days <<< "${days_csv}"
    for day in "${days[@]}"; do
        trimmed="$(echo "${day}" | xargs)"
        case "${trimmed}" in
            Sunday) n=0 ;;
            Monday) n=1 ;;
            Tuesday) n=2 ;;
            Wednesday) n=3 ;;
            Thursday) n=4 ;;
            Friday) n=5 ;;
            Saturday) n=6 ;;
            *) n="" ;;
        esac
        [[ -z "${n}" ]] && continue
        calendar_xml+="        <dict>"$'\n'
        calendar_xml+="            <key>Hour</key><integer>${hour}</integer>"$'\n'
        calendar_xml+="            <key>Minute</key><integer>${minute}</integer>"$'\n'
        calendar_xml+="            <key>Weekday</key><integer>${n}</integer>"$'\n'
        calendar_xml+="        </dict>"$'\n'
    done

    if [[ -z "${calendar_xml}" ]]; then
        calendar_xml+="        <dict>"$'\n'
        calendar_xml+="            <key>Hour</key><integer>${hour}</integer>"$'\n'
        calendar_xml+="            <key>Minute</key><integer>${minute}</integer>"$'\n'
        calendar_xml+="        </dict>"$'\n'
    fi

    mkdir -p "${HOME}/Library/LaunchAgents"

    cat > "${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SKILL_SH}</string>
        <string>${CONFIG_PATH}</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
${calendar_xml}    </array>
    <key>StandardOutPath</key>
    <string>${HOME}/.clock-in/${label}.out.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.clock-in/${label}.err.log</string>
</dict>
</plist>
EOF

    launchctl unload "${plist_path}" 2>/dev/null || true
    launchctl load "${plist_path}"

    echo "Installed: ${plist_path}"
    echo "  Task:   ${task_name}"
    echo "  Time:   ${start_time}"
    echo "  Days:   ${days_csv}"
    echo "  Jitter: ${random_delay} min (not supported by launchd; kept for config parity)"
    echo "Verify: launchctl list | grep ${LABEL_PREFIX}"
}

run_all() {
    local mode="$1"

    if [[ ! -f "${CONFIG_PATH}" ]]; then
        echo "Config not found: ${CONFIG_PATH}. Run /clock-in 初始化 first." >&2
        exit 1
    fi

    if [[ ! -x "${SKILL_SH}" ]]; then
        chmod +x "${SKILL_SH}"
    fi

    while IFS=$'\t' read -r task_name start_time random_delay days_csv; do
        if [[ "${mode}" == "uninstall" ]]; then
            uninstall_one "${task_name}"
        else
            install_one "${task_name}" "${start_time}" "${random_delay}" "${days_csv}"
        fi
    done < <(read_schedules)
}

case "${1:-}" in
    --uninstall|-u) run_all uninstall ;;
    "") run_all install ;;
    *) echo "Usage: $0 [--uninstall]" >&2; exit 1 ;;
esac
