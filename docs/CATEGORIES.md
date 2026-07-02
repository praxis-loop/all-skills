# Skill 分类规划

本仓库采用三层结构：`skills/<function>/<domain>/<skill>/SKILL.md`。

- `function`：顶层分类，表示一个部门或职能，用来自我定位，例如 `engineering`、`marketing`、`legal`。
- `domain`：该职能内的主题领域，例如 `engineering/security`、`marketing/seo`、`legal/contracts`。
- `skill`：具体可复用能力，目录内必须包含 `SKILL.md`。

分类优先按照 OPC 的真实经营职能来组织，而不是按照底层技术、脚本语言或某个具体 CLI 来组织。

## 顶层职能分类

| Function | 状态 | 适用范围 | 常见子类 |
|---|---|---|---|
| `engineering` | 规划中 | 软件工程、内部工具、自动化脚本、系统集成 | `backend`、`frontend`、`devops`、`security`、`testing`、`code-review` |
| `marketing` | 规划中 | 增长、流量、广告、SEO、活动和转化 | `seo`、`ads`、`email`、`social`、`campaigns` |
| `ecommerce` | 规划中 | 电商平台、商品内容、销售转化和平台规则 | `amazon`、`listing`、`product-research`、`reviews`、`marketplace-compliance` |
| `operations` | 已启用 | 业务运营、SOP、供应商、库存、履约、自动化执行 | `sop`、`inventory`、`suppliers`、`fulfillment`、`automation` |
| `content` | 已启用 | 文案、报告、知识库、脚本、内容资产 | `copywriting`、`blog`、`scripts`、`reports`、`knowledge-base` |
| `media` | 规划中 | 图片、视频、视觉提示词、设计资产和创意生产 | `images`、`video`、`prompts`、`design-review` |
| `data` | 规划中 | 数据查询、分析、报表、仪表盘和数据库工作流 | `analytics`、`reporting`、`dashboards`、`spreadsheets`、`databases` |
| `finance` | 规划中 | 定价、利润、预算、对账、现金流 | `pricing`、`profit`、`budgeting`、`reconciliation` |
| `legal` | 规划中 | 合同、合规、政策、条款和风险检查 | `contracts`、`compliance`、`policies` |
| `customer-support` | 规划中 | 售后、工单、评价、退款和客户沟通 | `faq`、`tickets`、`replies`、`refunds` |
| `productivity` | 规划中 | 个人计划、复盘、习惯、知识整理和效率流程 | `planning`、`review`、`personal-routines`、`knowledge-management` |

## 当前 Skill

| Skill | 路径 | 说明 |
|---|---|---|
| `clock-in` | `skills/operations/automation/clock-in` | 日常运营自动化：钉钉打卡和通知 |
| `oazon-daily` | `skills/content/reports/oazon-daily` | 内容报告：Oazon 每日工作日报 |
| `plain-language-daily-reports` | `skills/content/reports/plain-language-daily-reports` | 内容报告：大白话日报、周报和项目进展 |
| `implementation-impact-brief` | `skills/engineering/code-review/implementation-impact-brief` | 工程评审：基于 Git 变更或 AI Agent 实现会话生成技术实现与影响分析简报 |

## 分类规则

- 每个 skill 放在 `skills/<function>/<domain>/<skill-name>/`。
- `function` 表示职能，回答“这件事属于哪个部门？”
- `domain` 表示主题，回答“这个部门里的哪个领域？”
- `skill-name` 表示能力，回答“这个 skill 具体做什么？”
- 三层目录都使用小写英文，必要时使用短横线。
- 不要为了单个零散 skill 随意新增顶层职能。
- 如果一个 skill 能放进多个位置，优先选择它最主要的用户任务场景。
- 每个顶层职能目录保留 `README.md`，说明该职能边界。
- 已启用的子类目录可以保留 `README.md`，说明该子类边界。

## 什么时候新增顶层 Function

满足以下条件之一时，可以新增顶层职能：

- 现有职能会让 skill 很难被找到。
- 这个方向未来大概率会沉淀出多个 domain 和多个 skill。
- 这个方向有独立的安全、权限或维护规则。
- 这个方向对应清晰的 OPC 业务职能。

## 什么时候新增 Domain

满足以下条件之一时，可以新增子类：

- 同一 function 下已有 skill 数量开始变多，需要分组。
- 该主题有稳定工作流，例如 `marketing/seo` 或 `legal/contracts`。
- 该主题有独立模板、脚本、检查项或安全边界。

新增或移动分类时需要同步更新：

1. `docs/CATEGORIES.md`
2. 根目录 `README.md`
3. 相关 `skills/<function>/README.md`
4. 已启用子类的 `skills/<function>/<domain>/README.md`
5. `AGENTS.md` 或脚本规则，如果变更会影响 agent 操作方式
