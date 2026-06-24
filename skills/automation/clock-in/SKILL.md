---
name: clock-in
description: 执行钉钉自动打卡（通过 ADB 控制手机亮屏、解锁、打开钉钉，并发 Bark 通知）。当用户说"打卡"、"上班打卡"、"下班打卡"、"帮我打卡"、或使用 /clock-in 时调用。
---

# 钉钉自动打卡

使用 ADB 控制手机唤醒解锁、启动钉钉，并通过 Bark 推送通知结果。支持 Windows 和 macOS。

## 内置文件

```
~/.claude/skills/clock-in/scripts/
├── open-dingtalk-and-notify.ps1   # Windows 脚本
├── open-dingtalk-and-notify.sh    # macOS/Linux 脚本
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
- 输出 `Windows` 或命令不存在 → Windows，使用 `.ps1` 脚本

---

### 第二步：检查配置文件

**Windows：**
```bash
powershell.exe -NoProfile -Command "Test-Path '$env:USERPROFILE\.clock-in\config.local.json'"
```

**macOS：**
```bash
test -f ~/.clock-in/config.local.json && echo "True" || echo "False"
```

- 返回 `True` → 跳到第三步
- 返回 `False` → 进入【首次配置引导】

---

### 首次配置引导

依次引导用户完成以下步骤：

#### 1. 安装 ADB

**Windows：**
> 下载 Android Platform Tools（含 adb.exe）：
> https://developer.android.com/tools/releases/platform-tools
> 解压后记录 `adb.exe` 完整路径，例如：`D:\ProgramFile\platform-tools\adb.exe`

**macOS：**
> 可通过 Homebrew 安装：
> ```bash
> brew install android-platform-tools
> ```
> 安装后 adb 路径通常为 `/opt/homebrew/bin/adb`（Apple Silicon）或 `/usr/local/bin/adb`（Intel）。
> 也可手动下载解压，记录 `adb` 完整路径。

用 AskUserQuestion 询问：**"adb 的完整路径是什么？"**

#### 2. 开启手机 USB 调试并连接

> 1. 手机「设置」→「关于手机」，连续点击「版本号」7次，开启开发者选项
> 2. 「设置」→「开发者选项」→ 打开「USB 调试」
> 3. 用 USB 数据线连接电脑，手机上弹出「允许 USB 调试」时点击「允许」

验证连接（输出包含 `device` 即成功）：
```bash
<adb路径> devices
```

若显示 `unauthorized`：提示用户解锁手机并在弹窗中点击「始终允许」后重试。

#### 3. 获取屏幕分辨率（用于配置滑动坐标）

```bash
<adb路径> shell wm size
```

根据分辨率给出滑动坐标建议（从屏幕下方向上滑动解锁）：
- 1080×2400：startX=540, startY=2100, endX=540, endY=400, durationMs=800
- 1260×2800：startX=630, startY=2700, endX=630, endY=150, durationMs=800

告知用户可先用参考值，运行后再微调。

#### 4. 获取 Bark 推送地址

> 在 iPhone 上安装 Bark App，打开后获得推送 URL，格式：
> `https://api.day.app/你的设备key/`

用 AskUserQuestion 询问：**"Bark 的 baseUrl 是什么？"**

#### 5. 创建配置文件

收集完所有信息后创建目录并写入配置：

**Windows：**
```bash
powershell.exe -NoProfile -Command "New-Item -ItemType Directory -Force -Path '$env:USERPROFILE\.clock-in'"
```

**macOS：**
```bash
mkdir -p ~/.clock-in
```

根据用户信息写入 `~/.clock-in/config.local.json`，参考 `scripts/config.example.json` 的字段结构：
- `adbPath`：adb 完整路径（macOS 示例：`/opt/homebrew/bin/adb`）
- `pinDigits`：手机 PIN 数组，如 `[1,2,3,4,5,6]`
- `swipe`：解锁上滑坐标
- `bark.baseUrl`：Bark 推送地址（末尾须有 `/`）
- `timings`：各步骤等待时长（默认值通常够用）

---

### 第三步：检查设备连接

从配置读取 adbPath 并检查设备：

**Windows：**
```bash
powershell.exe -NoProfile -Command "(Get-Content '$env:USERPROFILE\.clock-in\config.local.json' | ConvertFrom-Json).adbPath"
```

**macOS：**
```bash
python3 -c "import json; d=json.load(open(os.path.expanduser('~/.clock-in/config.local.json'))); print(d['adbPath'])" 2>/dev/null || python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.clock-in/config.local.json')))['adbPath'])"
```

然后：
```bash
<adbPath> devices
```

- 包含 `device` → 继续
- 包含 `unauthorized` → 提示用户在手机弹窗点击「始终允许」
- 无设备 → 提示检查 USB 线和连接

---

### 第四步：执行打卡脚本

**Windows：**
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"$env:USERPROFILE\.claude\skills\clock-in\scripts\open-dingtalk-and-notify.ps1\" -ConfigPath \"$env:USERPROFILE\.clock-in\config.local.json\""
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
  - `adb not found` / `adb is not executable`：检查 config 中 adbPath
  - `No authorized Android device`：重插 USB，手机允许调试
  - `DingTalk launch was not confirmed`：增大 `launchDelaySeconds`，或确认钉钉包名（`com.alibaba.android.rimet`）
  - Bark 失败：检查网络和 `bark.baseUrl`

---

## 配置微调

直接编辑 `~/.clock-in/config.local.json`：
- 上滑后没进入密码页 → 增大 `startY`，减小 `endY`
- PIN 后没解锁 → 增大 `unlockDelaySeconds`
- 钉钉未打开 → 增大 `launchDelaySeconds`
