# Xan Skills

Xan Skills 是一个可复用的 AI Agent Skills 仓库。它把所有 skill 源文件集中维护在一个 Git 仓库中，再通过软链接或 Windows Junction 安装到 Codex、Claude Code 或用户指定的 CLI skill 目录。

核心原则：**本仓库是唯一真实来源，CLI 的 skill 目录只链接回本仓库**。以后只需要更新这个仓库，已安装的 skill 就会同步获得更新，不需要手工复制。

## 快速入口

- 分类规划：[docs/CATEGORIES.md](docs/CATEGORIES.md)
- Skill 创建与更新规范：[docs/SKILL_GUIDE.md](docs/SKILL_GUIDE.md)
- 新 skill 模板：[templates/new-skill/SKILL.md](templates/new-skill/SKILL.md)
- Agent 协作规则：[AGENTS.md](AGENTS.md)

## 三层结构

```text
skills/<function>/<domain>/<skill>/SKILL.md
```

- `function`：顶层分类，表示一个部门或职能，例如 `engineering`、`marketing`、`legal`。
- `domain`：该职能内的主题领域，例如 `engineering/security`、`marketing/seo`、`legal/contracts`。
- `skill`：具体可复用能力，目录内包含 `SKILL.md`，可按需包含 `scripts/`、`references/`、`assets/`。

## 目录结构

```text
xan-skills/
├── AGENTS.md
├── docs/
│   ├── CATEGORIES.md
│   └── SKILL_GUIDE.md
├── skills/
│   ├── customer-support/
│   ├── content/
│   │   └── reports/
│   ├── data/
│   ├── ecommerce/
│   ├── engineering/
│   ├── finance/
│   ├── legal/
│   ├── marketing/
│   ├── media/
│   ├── operations/
│   │   └── automation/
│   └── productivity/
├── templates/
│   └── new-skill/
└── scripts/
    ├── install.sh
    ├── install.ps1
    ├── uninstall.sh
    ├── update.sh
    └── doctor.sh
```

## 顶层职能分类

| Function | 状态 | 适用场景 |
|---|---|---|
| `engineering` | 规划中 | 软件工程、内部工具、自动化脚本、系统集成 |
| `marketing` | 规划中 | SEO、广告、邮件、社媒、活动和转化优化 |
| `ecommerce` | 规划中 | Amazon/电商 Listing、商品内容、竞品、平台规则 |
| `operations` | 已启用 | SOP、供应商、库存、履约、业务自动化 |
| `content` | 已启用 | 文案、报告、博客、脚本、知识库内容 |
| `media` | 规划中 | 图片、视频、视觉提示词、设计资产 |
| `data` | 规划中 | 数据查询、分析、仪表盘、表格、数据库 |
| `finance` | 规划中 | 定价、利润、预算、对账、现金流 |
| `legal` | 规划中 | 合同、合规、政策、条款和风险检查 |
| `customer-support` | 规划中 | FAQ、工单、回复、退款、评价处理 |
| `productivity` | 规划中 | 计划、复盘、个人流程、知识管理 |

当前已有 skill：

- `skills/operations/automation/clock-in`
- `skills/content/reports/oazon-daily`
- `skills/content/reports/plain-language-daily-reports`
- `skills/engineering/code-review/implementation-impact-brief`

## 安装目标

| 目标 | 默认路径 | 说明 |
|---|---|---|
| Codex 用户目录 | `~/.agents/skills` | 推荐用于个人 Codex 使用 |
| Claude Code 项目目录 | `./.claude/skills` | 推荐用于只在某个项目中生效的 skill |
| Claude Code 用户目录 | `~/.claude/skills` | 推荐用于个人全局 Claude Code skill |
| 自定义目录 | 用户输入 | 用于其他 CLI、服务器或特殊环境 |

## Linux、macOS、WSL 安装

在仓库根目录运行：

```bash
bash scripts/install.sh
```

安装脚本会执行：

1. 从 `skills/<function>/<domain>/<skill-name>` 发现可安装 skill。
2. 让用户选择安装一个、多个或全部 skill。
3. 让用户选择 Codex、Claude Code 或自定义目标目录。
4. 在目标目录创建指向本仓库 skill 源目录的链接。

Windows 用户优先使用 PowerShell。Git Bash 在 Windows 上创建软链接的行为会受系统权限和配置影响。

## Windows PowerShell 安装

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

PowerShell 安装脚本会优先尝试创建 SymbolicLink。如果普通用户权限不允许，会回退为目录 Junction。

## 更新已安装 Skill

如果本仓库是通过 Git 克隆的：

```bash
git pull --ff-only
```

也可以运行：

```bash
bash scripts/update.sh
```

因为安装方式是链接，仓库更新后，安装到各 CLI 目录的 skill 会自动同步到最新内容。

## 检查安装和同步状态

```bash
bash scripts/doctor.sh
```

检查内容包括：

- `skills/` 下有哪些 function、domain 和 skill。
- 每个真实 skill 是否包含 `SKILL.md`。
- 常见目标目录是否存在。
- 已安装条目是链接，还是旧的复制目录。
- Git 工作区是否有未提交修改。
- 当前分支是否有未推送提交或未拉取的 upstream 更新。

如果看到 `WARN: exists but is not a symlink`，说明目标目录里可能存在旧的复制版。建议先备份或移走，再重新安装链接版。

## 修改 Skill 后同步远程仓库

修改任何 skill 后，先检查状态：

```bash
git status --short
bash scripts/doctor.sh
```

如果有未提交修改：

```bash
git add skills docs templates scripts AGENTS.md README.md
git commit -m "update skills"
git push
```

如果 `doctor.sh` 提示本地有未推送提交：

```bash
git push
```

如果 `doctor.sh` 提示本地落后 upstream：

```bash
git pull --ff-only
```

同步原则：服务器上直接修改 skill 后，必须通过 Git commit + push 同步回远程仓库。其他服务器再通过 `git pull --ff-only` 获取更新。

## 卸载链接

```bash
bash scripts/uninstall.sh
```

卸载脚本只删除目标目录里的链接，不会删除 `skills/` 下的源文件。

## 新增或更新 Skill

以 [docs/SKILL_GUIDE.md](docs/SKILL_GUIDE.md) 为准。

简版流程：

1. 从 [docs/CATEGORIES.md](docs/CATEGORIES.md) 选择 function 和 domain。
2. 创建 `skills/<function>/<domain>/<skill-name>/SKILL.md`。
3. `skill-name` 使用小写短横线格式，例如 `cloudflare-tunnel-debug`。
4. 在 frontmatter 的 `description` 写清楚触发场景和主要能力。
5. 保持 `SKILL.md` 简洁，长规范、示例、表格放到 `references/`。
6. 稳定、可重复、容易出错的逻辑放到 `scripts/`。
7. 模板、示例文件、静态资源放到 `assets/`。
8. 运行 `bash scripts/doctor.sh` 并测试安装。
9. 提交并推送到远程仓库。

## 维护原则

- 不提交 API key、密码、私钥、token 或机器特定配置。
- 个人配置放在仓库外，例如 `~/.config` 或工具自己的本地配置目录。
- 安装第三方 skill 前先审查内容，尤其是带脚本或外部副作用的 skill。
- 涉及删除数据、发布变更、发送消息、花费资金、影响生产环境的流程，必须要求用户确认。
