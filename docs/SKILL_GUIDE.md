# Skill 创建与更新规范

本文档定义本仓库中 skill 的创建、更新、审查和分类规则。所有新增或修改的 skill 都应以本文档为准。

本规范参考 OpenAI Skills 文档、Agent Skills 开放规范和 Claude Code Skills 文档。当前共识是：一个 skill 是一个包含必需 `SKILL.md` 的目录，也可以按需包含 `scripts/`、`references/`、`assets/` 等支持文件。

## 参考来源

- OpenAI Skills guide: https://developers.openai.com/api/docs/guides/tools-skills
- Agent Skills specification: https://agentskills.io/specification
- Claude Code skills guide: https://code.claude.com/docs/en/skills

## 标准目录结构

```text
skills/<category>/<skill-name>/
├── SKILL.md
├── references/
├── scripts/
└── assets/
```

只有 `SKILL.md` 是必需文件。`references/`、`scripts/`、`assets/` 只在确实能提升可靠性、可维护性或复用性时添加。

## 命名规则

- `skill-name` 必须使用小写字母、数字和短横线，例如 `cloudflare-tunnel-debug`。
- 避免使用 `_`、空格、大写字母和中文目录名。
- 避免以 `-skill` 结尾，目录本身已经表达这是 skill。
- `SKILL.md` frontmatter 中的 `name` 必须与目录名一致。
- 一个目录只放一个 skill。
- 分类名保持小写且尽量稳定。需要新增分类时，先更新 `docs/CATEGORIES.md`。

## SKILL.md Frontmatter

默认使用最小跨平台 frontmatter：

```markdown
---
name: skill-name
description: 说明这个 skill 做什么，以及什么时候应该使用。把最重要的触发词和任务场景放在前面。
---
```

规则：

- `name` 必填。
- `description` 必填。
- `description` 是触发入口，应同时回答“做什么”和“什么时候用”。
- 关键触发词放在 `description` 前半段，例如产品名、业务名、任务类型、文件类型或常见用户说法。
- 描述要具体，避免过宽导致无关场景误触发。
- 默认不要加入只属于某个产品的私有 frontmatter 字段，除非这个 skill 明确只服务于该产品。
- 如果某个 workflow 只能手动触发或需要确认，在正文的边界部分写清楚。

## SKILL.md 正文结构

正文应短、准、可执行。它的目标是让 agent 正确完成工作，不是写背景文章。

推荐结构：

```markdown
# Skill Title

## 目的
说明这个 skill 要产出的结果。

## 输入
列出用户需要提供的信息、文件、环境变量或前置条件。

## 工作流程
1. 第一步。
2. 第二步。
3. 第三步。

## 输出要求
说明最终输出格式、文件位置或交付标准。

## 检查项
列出最终回复前必须验证的内容。

## 边界
说明哪些事情不能做，哪些动作必须先问用户确认。
```

编写要求：

- `SKILL.md` 控制在 500 行以内。
- 长表格、长示例、平台规则、API 细节、风格指南放入 `references/`。
- 从 `SKILL.md` 使用相对路径引用支持文件，例如 `references/schema.md`。
- 避免多层引用链。重要参考文件应直接从 `SKILL.md` 链接。
- 格式敏感的 workflow 必须提供输入和输出示例。
- 涉及危险操作时，明确写出确认点和拒绝边界。

## references/

`references/` 用于存放 agent 需要时再读取的资料：

- 数据结构或 JSON schema
- API 说明
- 业务规则
- 风格指南
- 详细检查清单
- 大型示例
- 平台政策或限制

维护规则：

- 每个 reference 文件只解决一个主题。
- 长文件顶部放目录或摘要。
- 不把必须立即知道的关键步骤藏在 reference 中；关键步骤应保留在 `SKILL.md`。
- 不放密钥、token、个人账号信息或机器专属配置。

## scripts/

`scripts/` 用于稳定、可重复、容易出错或不适合靠自然语言执行的逻辑：

- 解析文件
- 校验格式
- 转换文件
- 调用 API 的辅助脚本
- 批量本地操作
- 生成固定结构的输出

脚本规则：

- 参数化输入，不硬编码个人路径。
- 输出清晰错误信息。
- 在文件头或 README 中说明依赖。
- 不在脚本中保存 secrets。
- 改脚本后必须至少做语法检查；高风险脚本需要测试用例或 dry-run 模式。
- 默认不要执行删除、发布、付款、发消息、生产环境变更等动作；确需执行时必须要求用户确认。

## assets/

`assets/` 用于静态资源：

- 模板文件
- 示例图片
- 样板文档
- 小型查找表
- 固定输出骨架

规则：

- 只放 skill 真正需要的资源。
- 避免提交大型二进制文件。
- 对外部授权、版权或来源不明确的素材保持谨慎。

## 新增 Skill 流程

1. 定义重复任务：确认这个任务会被多次使用，且比普通提示词更适合沉淀成 skill。
2. 收集例子：至少准备两个真实或接近真实的输入/输出例子。
3. 选择分类：优先使用 `docs/CATEGORIES.md` 中已有分类。
4. 创建目录：`skills/<category>/<skill-name>/SKILL.md`。
5. 编写 frontmatter：确保 `name` 与目录名一致，`description` 包含触发场景。
6. 编写正文：写清目的、输入、流程、输出、检查项、边界。
7. 按需添加支持文件：长资料进 `references/`，确定性逻辑进 `scripts/`，静态模板进 `assets/`。
8. 更新 `registry.json`。
9. 运行检查。
10. 测试安装到临时目录或真实目标目录。

推荐从模板开始：

```bash
cp -R templates/new-skill skills/<category>/<skill-name>
```

然后修改 `skills/<category>/<skill-name>/SKILL.md`。

## 更新已有 Skill 流程

1. 优先保留原目录位置，除非分类明显错误。
2. 如果移动分类，同时更新 `registry.json`、根 `README.md` 和 `docs/CATEGORIES.md`。
3. 如果 `SKILL.md` 变长，把扩展内容拆到 `references/`。
4. 如果修改了脚本，重新测试脚本。
5. 运行 `bash scripts/doctor.sh`。
6. 确认安装脚本仍能发现该 skill。
7. 如果用户可能已经安装旧的复制版，在 README 或变更说明中写迁移提示。

## 检查命令

```bash
bash scripts/doctor.sh
bash -n scripts/install.sh scripts/uninstall.sh scripts/update.sh scripts/doctor.sh
python -m json.tool registry.json >/dev/null
```

Windows PowerShell 脚本语法检查：

```powershell
$tokens = $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\install.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { $errors | Format-List; exit 1 }
```

临时目录安装测试：

```bash
tmp=$(mktemp -d)
printf 'a\n4\n%s\n' "$tmp" | bash scripts/install.sh
```

## 提交前审查清单

- `SKILL.md` 存在，文件名大写。
- frontmatter 包含有效的 `name` 和 `description`。
- `description` 同时说明能力和触发时机。
- skill 目录名与 frontmatter `name` 一致。
- 正文包含目的、输入、工作流程、输出要求、检查项、边界。
- 大型资料已放入 `references/`。
- 脚本已测试，或明确标记为未测试和原因。
- 没有提交 secrets、token、密码、私钥或个人凭据。
- `registry.json` 是合法 JSON，路径正确。
- `scripts/doctor.sh` 能识别该 skill。
- README 或分类文档已同步更新。

## 安全要求

Skill 会影响 agent 行为，也可能包含可执行脚本，应按代码审查标准处理：

- 安装第三方 skill 前必须审查内容。
- 不在 frontmatter 中默认授予过宽权限。
- 不把破坏性动作隐藏在脚本里。
- 删除数据、发布变更、发送消息、花费资金、影响生产系统前必须要求用户确认。
- 个人配置放到仓库外，例如 `~/.config` 或工具自己的本地配置目录。

## 质量标准

一个合格的 skill 应满足：

- 触发清晰：用户说什么时应该使用它，描述中能看出来。
- 步骤稳定：不同 agent 或不同机器执行时结果尽量一致。
- 边界明确：不能做什么、何时要问用户，写得清楚。
- 支持文件有用：每个 `references/`、`scripts/`、`assets/` 文件都有明确用途。
- 可维护：新增、更新、安装、回滚都能通过仓库和脚本完成。
