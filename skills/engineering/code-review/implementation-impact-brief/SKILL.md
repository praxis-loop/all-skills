---
name: implementation-impact-brief
description: Create a technical implementation and impact assessment brief from Git changes, PRs, branches, local diffs, or an AI agent implementation session/transcript. Use when the user asks to summarize what was implemented, explain technical impact, prepare reviewer/tester/release notes, or turn an agent coding session into a structured engineering brief.
---

# Git Change / Agent Session Impact Brief

## 目的

基于 Git 变更、PR/分支、本地 diff，或 AI Agent 实现会话/转录，生成一份面向 Reviewer、测试和发布人员的技术实现与影响分析简报，并按用户要求保存到项目中。

核心原则：**先判断证据来源，再生成简报**。Git 和代码是实现事实的强证据；AI Agent 会话是目标、决策过程、验证过程和未完成事项的重要证据，但不能把会话陈述直接当作已落地事实。

## 输入来源

优先从用户请求中提取：

- 项目路径或已打开 workspace。
- 输入来源类型：Git / PR / branch / local diff / AI Agent session / transcript / manual summary / 多来源组合。
- Git 来源：起始 commit / base ref、目标 ref（默认 `HEAD`）、PR 或分支名。
- 会话来源：agent 实现会话、聊天转录、工具调用记录、任务总结、测试输出、用户粘贴的过程说明。
- 重点模块，可选。
- 输出目录，默认 `doc/` 或 `docs/` 中更符合项目习惯的目录。
- 是否需要逐 commit 或逐阶段展开；默认不逐条流水账，只按功能模块和影响范围总结。
- 是否需要运行测试；默认运行明显相关、低风险、轻量的本地测试。

缺少必要信息时只问关键问题：

- Git 来源缺少项目路径或 base commit/ref 时先询问用户。
- 会话来源缺少会话内容时，请用户粘贴 transcript、agent summary、执行日志或说明会话文件路径。
- 缺少输出文件名时，用 `技术实现与影响分析简报-<模块或功能名>.md`。

## 来源判断

1. 用户提供 commit range、commit hash、branch、PR、`base..target` 或仓库路径时，走 Git 分析流程。
2. 用户提供 AI agent 会话、聊天记录、转录、执行摘要、工具调用记录或“根据这次 agent 实现过程写简报”时，走会话分析流程。
3. 用户同时提供 Git 和会话材料时，使用 Git/代码校验实现事实，使用会话补充需求背景、技术决策、验证过程、风险和未完成事项。
4. 如果会话内容与当前代码或 Git 状态冲突，以可观察的代码/Git 为准，并在简报中说明冲突。

## Git 分析流程

1. 打开项目工作区，读取适用的 `AGENTS.md` / 项目说明。
2. 检查 Git 状态：运行 `git status --short --branch`。记录未提交改动，但不要把它们混入 commit range 分析，也不要回滚用户改动。
3. 确认提交范围：运行 `git log --oneline <base>..<target>`，只用于理解范围。除非用户要求，不要在最终文档逐个 commit 说明。
4. 获取改动概览：运行 `git diff --stat <base>..<target>` 和 `git diff --name-status <base>..<target>`，识别主要模块、增删文件、配置和部署文件。
5. 阅读关键代码，不要只看 diff 统计。优先阅读变更中的入口、路由、controller、service、model/schema、config/env、Docker/nginx/deployment、tests、docs。
6. 按功能模块归纳整体变化：新增能力、逻辑调整、删除/替换、数据结构变化、配置部署变化、测试覆盖。

## 会话分析流程

1. 明确会话来源：粘贴文本、文件路径、agent summary、执行日志或聊天转录。
2. 提取用户原始目标：这次实现要解决什么问题、交付什么能力、面向谁使用。
3. 提取实际实现项：新增/修改/删除的模块、文件、配置、命令、测试和文档。
4. 提取关键决策：为什么选择某个方案、放弃了哪些方案、哪些约束影响实现。
5. 提取验证记录：运行过的测试/检查命令、通过/失败结果、未运行原因。
6. 提取风险和遗留项：会话中提到但未解决的 TODO、错误、阻塞、人工确认项。
7. 如果可访问项目代码，读取关键文件或 Git 状态进行复核；如果无法复核，必须在简报中标记“未基于代码复核”。
8. 区分三类内容：
   - **明确事实**：会话、代码或命令输出直接支持。
   - **合理推断**：根据上下文推断，但没有直接证据。
   - **待补充**：缺少证据或需要用户/团队确认。

## 影响分析

无论来源是 Git 还是会话，都从以下维度检查：

- API 兼容性、端侧/下游服务、数据库/缓存、存量数据。
- 配置、环境变量、密钥注入、CI/CD、Docker/nginx/deployment。
- 安全合规、鉴权、公开接口、隐私数据、日志暴露。
- 部署顺序、灰度/回滚、数据迁移或反向迁移风险。
- 测试覆盖、未验证路径、Reviewer 必看点。

## 输出要求

- 文档用中文，技术名词、接口路径、命令和文件路径保留原文。
- 默认按模块和影响范围总结，不按 commit 或会话消息列流水账。
- 需要模板时读取 `references/brief-template.md`。
- Jira/工单/PRD 链接缺失时写“待补充”，不要编造。
- 不粘贴大段代码，用自然语言解释实现逻辑。
- 不输出具体密钥、密码、token、私钥；只说明存在敏感配置或凭据管理风险。
- 影响范围表要给出可执行的测试重点。
- 发布与回滚计划要区分数据、配置、服务、前端/网关。
- 如果只基于会话生成，必须说明可信度限制和未复核项。
- 如果保存文档，保存到项目中；不要修改业务代码。如果必须更新已有文档，先确认用户意图。

## 推荐检查命令

```bash
git status --short --branch
git log --oneline <base>..<target>
git diff --stat <base>..<target>
git diff --name-status <base>..<target>
```

按项目技术栈补充：

```bash
# JavaScript/Node 示例
node path/to/test.js
npm test -- --runInBand

# Go 示例
go test ./...

# Python 示例
pytest
```

只运行与本次改动直接相关、耗时可控、不会访问生产环境的测试。不能运行时说明原因，并给出建议验证项。

## 检查项

- 是否明确说明输入来源和可信度限制。
- 是否明确区分已提交变更、未提交工作区改动和会话陈述。
- 是否读过关键实现文件，而不是只复述 commit message 或 agent summary。
- 是否覆盖数据库、配置、部署、安全、兼容性和测试影响。
- 是否没有泄露密钥值。
- 是否没有编造 Jira/PRD 链接、文件、接口或测试结果。
- 是否保存了文档，并在最终回复给出路径。
- 是否说明已运行测试和未运行测试的原因。
- 是否说明当前仓库是否还有未提交、未推送或待拉取状态。

## 边界

- 不执行破坏性 Git 命令，例如 `git reset --hard`、`git checkout --`，除非用户明确要求。
- 不把未提交文件当作 commit range 的实现内容；如未提交文件影响判断，只作为“工作区现状”单独说明。
- 不把 AI Agent 会话中的说法自动当作代码事实；能读代码就复核，不能复核就标记限制。
- 不修改业务代码。
- 不提交、不推送、不发布、不执行生产迁移，除非用户明确要求并确认。
- 如果发现疑似密钥、生产配置或隐私数据，只描述风险，不复述原值。
