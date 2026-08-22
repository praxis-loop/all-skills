# Skill 分类规划

本仓库采用三层结构：`skills/<function>/<domain>/<skill>/SKILL.md`。

- `function`：顶层分类，表示一个部门或职能，用来自我定位，例如 `engineering`、`marketing`、`legal`。
- `domain`：该职能内的主题领域，例如 `engineering/security`、`marketing/seo`、`legal/contracts`。
- `skill`：具体可复用能力，目录内必须包含 `SKILL.md`。

分类优先按照 OPC 的真实经营职能来组织，而不是按照底层技术或脚本语言来组织。

例外是 `platforms`：当一组 skill 的共性不是"哪个部门在用"，而是"绑定同一个外部平台、共用同一套 CLI 与授权体系"时，按平台归类比按职能归类更好找、也更好维护。判断标准见 `platforms` 行的说明。

## 顶层职能分类

| Function | 状态 | 适用范围 | 常见子类 |
|---|---|---|---|
| `engineering` | 已启用 | 软件工程、内部工具、自动化脚本、系统集成 | `backend`、`frontend`、`devops`、`security`、`testing`、`code-review`、`cloudflare` |
| `marketing` | 规划中 | 增长、流量、广告、SEO、活动和转化 | `seo`、`ads`、`email`、`social`、`campaigns` |
| `ecommerce` | 规划中 | 电商平台、商品内容、销售转化和平台规则 | `amazon`、`listing`、`product-research`、`reviews`、`marketplace-compliance` |
| `operations` | 已启用 | 业务运营、SOP、供应商、库存、履约、自动化执行 | `sop`、`inventory`、`suppliers`、`fulfillment`、`automation` |
| `content` | 已启用 | 文案、报告、知识库、脚本、内容资产 | `copywriting`、`blog`、`scripts`、`reports`、`knowledge-base` |
| `media` | 已启用 | 图片、视频、视觉提示词、设计资产和创意生产 | `images`、`video`、`video-summary`、`prompts`、`design-review` |
| `data` | 规划中 | 数据查询、分析、报表、仪表盘和数据库工作流 | `analytics`、`reporting`、`dashboards`、`spreadsheets`、`databases` |
| `finance` | 规划中 | 定价、利润、预算、对账、现金流 | `pricing`、`profit`、`budgeting`、`reconciliation` |
| `legal` | 规划中 | 合同、合规、政策、条款和风险检查 | `contracts`、`compliance`、`policies` |
| `customer-support` | 规划中 | 售后、工单、评价、退款和客户沟通 | `faq`、`tickets`、`replies`、`refunds` |
| `productivity` | 已启用 | 个人计划、复盘、习惯、知识整理和效率流程 | `planning`、`review`、`personal-routines`、`knowledge-management`、`collaboration`、`communication`、`feedback`、`reading` |
| `platforms` | 已启用 | 外部 SaaS / 平台的 API 与 CLI 绑定。同一 domain 下的 skill 共用一套凭据、scope 和安全边界，通常成组 vendored 自厂商仓库 | `lark`、`agent-vault` |

## 当前 Skill

来源为「第三方」的 skill 是快照，通过 `sources/skills.sources.yaml` 声明并由 `skillctl` 同步，不要手工修改其目录。

| Skill | 路径 | 来源 | 说明 |
|---|---|---|---|
| `oazon-mm-daily-log` | `skills/content/reports/oazon-mm-daily-log` | 自有 | 内容报告：从 Mattermost（mm.oazon.com）抓取某天会话，整理成本人的日报，确认后写入 Obsidian 的 `daily.md` |
| `plain-language-daily-reports` | `skills/content/reports/plain-language-daily-reports` | 自有 | 内容报告：大白话日报、周报和项目进展 |
| `wrangler` | `skills/engineering/cloudflare/wrangler` | 第三方 | Cloudflare：Wrangler CLI 部署与管理 Workers、KV、R2、D1 等资源 |
| `implementation-impact-brief` | `skills/engineering/code-review/implementation-impact-brief` | 自有 | 工程评审：基于 Git 变更或 AI Agent 实现会话生成技术实现与影响分析简报 |
| `server-docker-compose-standard` | `skills/engineering/devops/server-docker-compose-standard` | 自有 | 运维标准：`/opt/docker` 下一服务一个 Docker Compose 项目的部署规范 |
| `server-ops` | `skills/engineering/devops/server-ops` | 自有 | 服务器排查：502/超时/容器异常的定位流程，凭证走 agent-vault，收尾回写服务清单 |
| `video-summary-service` | `skills/media/video-summary/video-summary-service` | 自有 | 视频处理：调用已部署的 Video Summary 服务对短视频链接做异步摘要 |
| `clock-in` | `skills/operations/automation/clock-in` | 自有 | 日常运营自动化：钉钉打卡和通知 |
| `agent-vault-shared` | `skills/platforms/agent-vault/agent-vault-shared` | 自有 | 凭证基座：agent-vault CLI 安装与校验、权限自查、取凭证的标准姿势（ssh-add - / GIT_ASKPASS）、缺权限走 proposal、收尾清理。所有声明 x-vault-* 的 skill 都引用它 |
| `lark-shared` | `skills/platforms/lark/lark-shared` | 第三方 | 飞书基座：`lark-cli` 应用配置、登录授权、user/bot 身份切换、scope 排障，其余 lark skill 均引用它 |
| `lark-doc` | `skills/platforms/lark/lark-doc` | 第三方 | 飞书云文档：Docx / Wiki 读取、创建、编辑、历史版本，素材与画板 |
| `lark-im` | `skills/platforms/lark/lark-im` | 第三方 | 飞书消息：发送回复、群聊管理、消息搜索、图片文件收发 |
| `lark-base` | `skills/platforms/lark/lark-base` | 第三方 | 飞书多维表格：表、字段、记录、视图、仪表盘与数据聚合 |
| `lark-drive` | `skills/platforms/lark/lark-drive` | 第三方 | 飞书云空间：文件上传下载、文档搜索、副本与权限、文档评论 |
| `lark-sheets` | `skills/platforms/lark/lark-sheets` | 第三方 | 飞书电子表格：读写、追加、查找、导出 |
| `lark-whiteboard` | `skills/platforms/lark/lark-whiteboard` | 第三方 | 飞书画板：图形 DSL 渲染，被 `lark-doc` 的画板链路调用 |
| `handoff` | `skills/productivity/collaboration/handoff` | 第三方 | 协作交接：把当前会话压缩成交接文档，供下一个 agent 接手 |
| `managing-up` | `skills/productivity/communication/managing-up` | 第三方 | 职场沟通：向上管理，主动沟通、争取资源、用业务视角提出异议 |
| `professional-communication` | `skills/productivity/communication/professional-communication` | 第三方 | 职场沟通：邮件、团队消息、会议表达的结构化写作与受众调校 |
| `grill-me` | `skills/productivity/feedback/grill-me` | 第三方 | 方案打磨：用高强度追问审视一份计划或设计 |
| `cangjie-skill` | `skills/productivity/reading/cangjie-skill` | 第三方 | 知识蒸馏：把书籍、长视频、播客、课程拆解成一组可执行 skill |
| `done` | `skills/productivity/review/done` | 自有 | 复盘沉淀：会话结束时复盘本次+历史会话，产出提问模板、项目记忆、知识短板、跨会话固定流程→建议新 skill，先汇报后拍板 |

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
