# Xan Skills

Xan Skills 是一个可复用的 AI Agent skill 仓库。它的目标是把常用工作流沉淀成可维护的 skill，并通过安装脚本软链接到 Codex、Claude Code 或用户指定的目录。

## 设计目标

- 仓库是唯一源头，避免在多台机器上手动复制 skill。
- 安装时使用软链接，更新仓库后所有已安装目录自动获得最新内容。
- 支持按需选择安装某几个 skill。
- 支持安装到 Codex、Claude Code 或自定义目录。
- 尽量保留现有 skill 目录结构，降低迁移成本。

## 当前目录

```text
xan-skills/
├── clock-in/
│   ├── skill.md
│   └── scripts/
├── oazon-daily/
│   └── skill.md
├── plain-language-daily-reports/
│   └── SKILL.md
├── registry.json
└── scripts/
    ├── install.sh
    ├── install.ps1
    ├── uninstall.sh
    ├── update.sh
    └── doctor.sh
```

> 建议后续逐步把小写 `skill.md` 统一改为 `SKILL.md`，但当前脚本会同时兼容两种文件名。

## 支持的安装目标

| 目标 | 默认目录 | 说明 |
|---|---|---|
| Codex 用户级 | `~/.agents/skills` | 推荐给个人使用 |
| Codex 机器级 | `/etc/codex/skills` | 推荐给服务器或多人共享机器使用，通常需要 sudo |
| Claude Code 项目级 | `./.claude/skills` | 推荐在某个项目内使用 Claude Code 时安装 |
| Claude Code 用户级 | `~/.claude/skills` | 适合个人全局使用；如你的 Claude Code 版本不扫描该目录，可改用项目级目录 |
| 自定义目录 | 用户输入 | 用于兼容其他 CLI 或特殊目录 |

## Linux/macOS/WSL 安装

在仓库根目录执行：

```bash
bash scripts/install.sh
```

脚本会引导你：

1. 选择要安装的 skill。
2. 选择安装目标目录。
3. 创建目标目录。
4. 使用软链接安装 skill。

## Windows PowerShell 安装

在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

PowerShell 脚本会优先创建 Windows 符号链接；如果当前权限不允许创建符号链接，会自动退回到目录 Junction。两种方式都会指向仓库源目录，更新仓库后无需复制文件。

## 更新 skill

如果你是通过 Git clone 这个仓库，只需要在仓库根目录执行：

```bash
git pull --ff-only
```

也可以执行：

```bash
bash scripts/update.sh
```

因为安装方式是软链接，仓库更新后，已安装到 Codex 或 Claude 的 skill 会直接指向最新内容。

## 检查安装状态

```bash
bash scripts/doctor.sh
```

它会检查：

- 仓库里有哪些 skill。
- 每个 skill 是否有 `SKILL.md` 或 `skill.md`。
- 常见目标目录是否存在。
- 常见目标目录里是否有指向当前仓库的软链接。

## 卸载软链接

```bash
bash scripts/uninstall.sh
```

卸载脚本只删除目标目录中的软链接，不删除仓库里的 skill 源文件。

## 推荐维护方式

### 单机

```bash
git clone <your-repo-url> ~/xan-skills
cd ~/xan-skills
bash scripts/install.sh
```

### 多服务器

1. 每台服务器 clone 到固定路径，例如 `/opt/xan-skills`。
2. 执行 `bash scripts/install.sh` 安装到 `~/.agents/skills` 或 `/etc/codex/skills`。
3. 使用 cron、systemd timer 或 Ansible 定期执行 `git pull --ff-only`。

## 新增一个 skill

1. 在仓库根目录新增一个目录，例如 `my-skill/`。
2. 在目录内创建 `SKILL.md`。
3. 在 `registry.json` 中补充说明。
4. 运行 `bash scripts/doctor.sh` 检查。
5. 运行 `bash scripts/install.sh` 重新选择安装。

推荐结构：

```text
my-skill/
├── SKILL.md
├── references/
├── scripts/
└── assets/
```

## 注意事项

- 不要把 API Key、密码、私钥、个人 token 写入 skill 仓库。
- 每台机器独有的配置应放在用户目录，例如 `~/.clock-in/config.local.json`。
- 对会执行命令或访问外部系统的 skill，安装前应人工检查 `SKILL.md` 和 `scripts/`。
