---
name: clock-in
description: 执行钉钉自动打卡（通过 ADB 控制手机亮屏、解锁、打开钉钉，并发 Bark 通知）。当用户说"打卡"、"上班打卡"、"下班打卡"、"帮我打卡"、或使用 /clock-in 时调用。
---

# 钉钉自动打卡

使用 ADB 控制手机唤醒解锁、启动钉钉，并通过 Bark 推送通知结果。支持 Windows 和 macOS。

## 内置文件

```
~/.claude/skills/clock-in/scripts/
├── open-dingtalk-and-notify.ps1   # Windows 主脚本（手动触发）
├── open-dingtalk-and-notify.sh    # macOS/Linux 主脚本
├── install-schedule.ps1           # Windows 安装/卸载定时任务
├── uninstall-schedule.ps1         # Windows 卸载（install-schedule.ps1 -Uninstall 的快捷方式）
├── install-schedule.sh            # macOS 安装/卸载 launchd 任务
└── config.example.json            # 配置模板
```

**配置文件**：`~/.clock-in/config.local.json`（每台电脑独立，不随 skill 同步）

---

## 执行流程

### 第一步：判断操作系统

```bash
uname -s 2>/dev/null || echo "Windows"
```

- 输出 `Darwin` → macOS，使用 `.sh` 脚本
- 输出 `MINGW*` / `MSYS*` / `CYGWIN*` / `Windows`，或命令不存在 → Windows，使用 `.ps1` 脚本

---

### 第二步：检查配置文件

**Windows：**
```bash
powershell.exe -NoProfile -Command 'Test-Path -LiteralPath "$env:USERPROFILE\.clock-in\config.local.json"'
```

> 注意：不要在 Git Bash 里使用 `"Test-Path '$env:USERPROFILE\\... '"` 这种写法；外层双引号会让 Bash 先尝试展开 `$env`，导致 PowerShell 检查到错误路径并误判为 `False`。

**macOS：**
```bash
test -f ~/.clock-in/config.local.json && echo "True" || echo "False"
```

- 返回 `True` → 跳到「第三步：检查设备连接」
- 返回 `False` → 进入「首次配置引导（Wizard）」

---

## 如何回答 AskUserQuestion

Wizard 会**一次性弹出 3 个问题**，收集 adb 路径、Bark URL、手机 PIN。

**每个问题的回答方式**：选中一个最接近的预设选项（通常是「我来提供 XX」），然后在弹出的**备注框（notes）**里粘贴实际值。备注框始终可见，比「Other」自由输入更稳定。

如果 Other 入口找不到或不可见，**一律用「我来提供 XX」+ 备注框**这种方式。

---

## 首次配置引导（Wizard）

### 1. 安装 ADB（如尚未安装）

**Windows：** 下载 [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools)，解压后记录 `adb.exe` 完整路径（如 `D:\ProgramFile\platform-tools\adb.exe`）。

**macOS：** `brew install android-platform-tools`，路径通常在 `/opt/homebrew/bin/adb` 或 `/usr/local/bin/adb`。

### 2. 开启手机 USB 调试并连接

1. 手机「设置」→「关于手机」，连续点击「版本号」7 次开启开发者选项
2. 「设置」→「开发者选项」→ 打开「USB 调试」
3. 用 USB 数据线连接电脑，在手机上点击「允许 USB 调试」

### 3. 获取屏幕分辨率（决定 swipe 坐标）

```bash
<adb路径> shell wm size
```

根据分辨率给出滑动坐标建议（从屏幕下方向上滑动解锁）：
- 1080×2400：`startX=540, startY=2100, endX=540, endY=400, durationMs=800`
- 1260×2800：`startX=630, startY=2700, endX=630, endY=150, durationMs=800`
- 其他分辨率：X 取宽度一半，Y 取 `(height-300)` 和 `300` 左右即可

### 4. 一次性调用 AskUserQuestion 收集 3 项配置

**调用一次** `AskUserQuestion`（multiSelect 关闭），3 个 question 一起弹出：

| header | 问题 | 选项 1（推荐）| 选项 2 |
|--------|------|-------------|--------|
| `adb path` | adb 的完整路径是什么？ | 我来提供路径（备注框填） | 使用默认路径 D:\...\adb.exe |
| `Bark URL` | Bark 推送地址是什么？（末尾须带 `/`） | 我已有 Bark（备注框填 URL） | 我还没装 Bark |
| `PIN` | 手机解锁 PIN 是什么？（不是钉钉密码） | 我提供 PIN（备注框填数字） | 默认 123456 |

**用户在每个问题都选「我来提供 XX」**，然后在每个问题的**备注框**里分别填：
- adb.exe 完整路径
- 完整 Bark URL（含末尾 `/`）
- 手机 PIN 数字

如果 Bark URL 末尾忘了 `/`，AI 在写入前会补上。

### 5. 写入配置文件

直接使用 `Write` 工具写入配置 JSON（**不要用 bash 拼 PowerShell 命令**，Git Bash 会吞 `$env:`）：

- Windows：`C:\Users\12143\.clock-in\config.local.json`
- macOS：`~/.clock-in/config.local.json`

`Write` 工具会自动创建父目录，无需先 mkdir。

参考 `scripts/config.example.json` 的字段，必填：
- `adbPath`：adb 完整路径
- `pinDigits`：PIN 数字数组（如 `[9,7,9,9,7,9]`）
- `swipe`：根据屏幕分辨率填写
- `bark.baseUrl`：Bark URL（含末尾 `/`）

可选字段（用 example 默认值即可）：`timings`、`dingTalkPackage`、`screenOffAfterNotification`、`bark.*` 中的 success/failure 文案。

---

### 第三步：检查设备连接

```bash
<adbPath> devices
```

- 包含 `device` → 继续
- 包含 `unauthorized` → 提示用户在手机弹窗点击「始终允许」
- 无设备 → 提示检查 USB 线和连接

---

### 第四步：执行打卡脚本

**Windows（推荐用 `-File` 避免引号转义问题）：**
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\12143\.claude\skills\clock-in\scripts\open-dingtalk-and-notify.ps1" -ConfigPath "C:\Users\12143\.clock-in\config.local.json"
```

**macOS：**
```bash
bash ~/.claude/skills/clock-in/scripts/open-dingtalk-and-notify.sh ~/.clock-in/config.local.json
```

macOS 首次运行前需确保脚本有执行权限：
```bash
chmod +x ~/.claude/skills/clock-in/scripts/open-dingtalk-and-notify.sh
```

**结果处理：**
- exit code 0 → 告知用户"打卡成功，Bark 通知已发送"
- 失败 → 展示错误并给出建议：
  - `adb not found` / `adb is not executable`：检查 config 中 `adbPath`
  - `No authorized Android device`：重插 USB，手机允许调试
  - `DingTalk launch was not confirmed`：增大 `launchDelaySeconds`，或确认钉钉包名（`com.alibaba.android.rimet`）
  - Bark 失败：检查网络和 `bark.baseUrl`（特别注意末尾 `/`）

---

## 安装每日定时任务（可选）

默认情况下，本 skill 只在手动调用时执行一次。要让它**每天自动打卡**，需要在系统层注册一个调度任务：

- **Windows**：用「任务计划程序」(Task Scheduler)
- **macOS**：用 `launchd`

### 步骤 1：在 config 中添加 schedule 字段

编辑 `~/.clock-in/config.local.json`，添加：

```json
{
  "schedule": {
    "taskName": "ClockInDaily",
    "startTime": "08:50",
    "randomDelayMinutes": 5,
    "daysOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
  }
}
```

字段含义：
- `taskName`：调度任务名（Windows 任务计划程序里显示的名字）
- `startTime`：触发时间，24h 格式 `HH:MM`
- `randomDelayMinutes`：在 `startTime` 基础上随机延迟的分钟数（避免每次都精确同一秒打卡）
- `daysOfWeek`：周几执行，默认周一到周五

不写 `schedule` 段会使用上面的默认值。

### 步骤 2：执行安装脚本

**Windows（PowerShell）：**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\12143\.claude\skills\clock-in\scripts\install-schedule.ps1"
```

**macOS / Linux：**
```bash
bash ~/.claude/skills/clock-in/scripts/install-schedule.sh
chmod +x ~/.claude/skills/clock-in/scripts/install-schedule.sh  # 首次运行
```

安装脚本会读取 `config.schedule.*`，注册对应的调度任务（Windows Task Scheduler / macOS launchd）。

### 步骤 3：验证

**Windows：**
```powershell
Get-ScheduledTask -TaskName ClockInDaily | Format-List *
# 立即触发一次（不等到明天）：
schtasks /run /tn ClockInDaily
```

**macOS：**
```bash
launchctl list | grep clock-in
# 立即触发一次：
launchctl start com.user.clock-in
```

### 卸载定时任务

**Windows：**
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\12143\.claude\skills\clock-in\scripts\uninstall-schedule.ps1"
# 或
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "...\install-schedule.ps1" -Uninstall
```

**macOS：**
```bash
bash ~/.claude/skills/clock-in/scripts/install-schedule.sh --uninstall
```

### ⚠️ 自动调度的前提

- 电脑必须在触发时段**保持开机**（任务计划程序默认 `StartWhenAvailable=true`，电脑休眠时会在唤醒后补跑）
- 手机必须**通过 USB 连接到这台电脑**，且 USB 调试保持授权
- 如果电脑经常关机/合盖，建议用智能插座定时给电脑和手机供电，或改用其他方案（如手机端 Tasker + HTTP 触发）

---

## 配置微调

直接编辑 `~/.clock-in/config.local.json`（用任意文本编辑器，或 `Write` 工具覆盖）：
- 上滑后没进入密码页 → 增大 `startY`，减小 `endY`
- PIN 后没解锁 → 增大 `unlockDelaySeconds`
- 钉钉未打开 → 增大 `launchDelaySeconds`
- 想要钉钉保持前台更久 → 增大 `postLaunchHoldSeconds`

---

## 常见错误速查

| 错误现象 | 原因 | 解决 |
|---------|------|------|
| Git Bash 下 `mkdir` 报"路径格式不支持" | Bash 把 `$env:` 吞掉了 | 改用 `Write` 工具或编辑器 |
| `Test-Path` 在 bash 下输出乱码 | PowerShell 错误流被 utf-8 解析 | 忽略乱码，关注 `True`/`False` |
| Bark 推送 404 | URL 末尾漏了 `/` | 补上 `/` |
| 手机锁屏 PIN 输完仍黑屏 | 等待时间不够 | 调大 `unlockDelaySeconds` |
| 钉钉打开的不是工作台 | 启动后等待不够 | 调大 `postLaunchHoldSeconds` |
