# `done` Skill — 设计文档

- 日期: 2026-08-11
- 状态: 已与用户确认方向, 待写实现计划
- 仓库: `all-skills` (source of truth)
- 目标路径: `skills/productivity/review/done/`
- Skill 名: `done` (frontmatter `name: done`, 触发 `/done`)

## 1. 目的与定位

一个**会话结束时手动触发**的复盘工具。用户与 AI agent 完成一段工作后运行 `/done`, 让 agent 对本次会话做结构化复盘, 目标:

1. 总结"一开始如果这样提问会更快解决问题", 优化用户的提问方式;
2. 识别**跨会话反复出现的固定流程**, 建议提炼成新 skill;
3. 把真正与项目/用户长期相关的洞察沉淀进 memory, 让 agent 越来越懂这个项目和这个人;
4. 指出用户在本次会话里暴露出的**知识短板**, 建议补强哪一块知识;
5. 主动抛出用户没提到、但有价值的其他发现。

**核心哲学: 先判断"值不值得沉淀", 再决定要不要写。空手而归也是合法结果——不硬凑。** 产出永远是"先书面汇报, 用户逐项拍板, 批准后才落地"。

## 2. 分类与仓库约定

- function: `productivity` (已启用, 覆盖"个人计划、复盘、效率流程")
- domain: `review` (CATEGORIES.md 已列出的合法子类, 目前尚无 skill; `done` 为首个)
- 目录: `skills/productivity/review/done/`
  ```text
  done/
  ├── SKILL.md              # 主文件 (简洁, 目的/输入/工作流程/输出/检查项/边界)
  ├── references/
  │   └── judgement-gates.md   # 各板块"够不够格沉淀"的判断标准 (长内容外置)
  └── scripts/
      └── scan-sessions.py     # 确定性逻辑: 扫描历史 JSONL, 抽取用户意图
  ```
- 新增 domain 需同步维护(见第 8 节): `docs/CATEGORIES.md`、`skills/productivity/README.md`、新建 `skills/productivity/review/README.md`。

## 3. 触发与读取范围 (混合读取)

`/done` 手动触发, 通常在会话末尾运行。数据两个来源:

| 板块 | 数据来源 | 理由 |
|------|----------|------|
| 概述 / 更快提问 / 项目记忆 / 其他发现 | **当前会话上下文**(agent 已在手) | 最准, 无需解析文件, 省 token |
| 固定流程 → skill 候选 | **本项目全部历史会话 transcript** | "重复"必须跨会话才看得出 |

### 路径推导 (通用, 不写死个人路径)

由 `scripts/scan-sessions.py` 负责, 参数化输入:

- 环境配置根: `$CLAUDE_CONFIG_DIR`
- cwd munge: 把 `cwd` 的 `/` 替换成 `-`。例: `/home/xan/oazon_sync` → `-home-xan-oazon-sync`
- 历史会话目录: `$CLAUDE_CONFIG_DIR/projects/<munged-cwd>/`, 每个会话 = 一个 `<session-id>.jsonl`
- 扫描时**排除当前会话文件**(它已在上下文里); 当前 session id 从 scratchpad 路径/上下文取得
- 已有 skills(查重用): 本仓库 `skills/**` + 已安装的 `$CLAUDE_CONFIG_DIR/skills/`
- 记忆目录: `$CLAUDE_CONFIG_DIR/projects/<munged-cwd>/memory/`(含 `MEMORY.md` 索引)

### Transcript 解析 (脚本职责)

- 每行一个 JSON 对象; 取 `type == "user"` 且 `message.content` 为真实用户输入的行。
- `message.content` 可能是字符串或 text block 列表(取 `type=="text"` 的 `text`)。
- **过滤噪音**: 跳过以 `<` 开头的系统注入(`<system-reminder>` 等)、`[Request interrupted by user]`、`/clear` 等命令回显、纯工具结果。
- 为省 token, 脚本**只输出每个会话的用户意图/开场需求摘要**(不通读 assistant 输出与工具调用)。已与用户确认: 够用。
- 输出结构化结果(如 JSON: `[{session_id, date, intents:[...]}]`), 供 agent 聚类。

## 4. Debrief 六个板块 (SKILL.md 工作流程核心)

每个板块末尾附动作标记: `[建议] 写入 memory: …` / `[建议] 新建 skill: …` / `[无需动作]`。

1. **本次会话概述** — 一句话: 用户想解决什么、最终怎么解决。定基调, 无落地动作。
2. **更快的开场提问** — 复盘"如果一开始这么说能少走哪些弯路"(缺失上下文、没说清的约束、反复澄清点)。确有可复用改进时 → 产出/更新**提问模板**(轻量资产, 教用户); 否则明说"本次无明显改进空间"。
3. **可沉淀的项目记忆** — 只挑**跨会话仍成立、且代码/git 查不到**的洞察, 写成 memory。类型遵循用户 CLAUDE.md 规范: `user`/`feedback`/`project`/`reference`; 每条说明**为什么值得沉淀**, `feedback`/`project` 补 `**Why:**` 与 `**How to apply:**`。无则明说"本次无。"
4. **知识短板与补强建议** — 指出用户在本次会话里暴露的知识薄弱点, 给出该补哪一块知识的具体方向。约束:
   - **必须有证据**: 只提本次会话确有信号的点(反复问同一概念、对某工具/机制心智模型有偏差、同一处来回澄清), 并**引用是哪一处**;
   - **给方向不说教**: 指出薄弱点 + 建议补强的具体知识块/资料方向, 不写笼统的"要多学习";
   - **默认只汇报**; 若是长期、跨会话的短板, 可提议写成 `user` 类 memory(让 agent 以后主动照顾表达), 仍需用户批准;
   - 无明确信号则明说"本次无。"避免无端评判。
5. **可提炼的固定流程 → skill (跨会话)** — 用 `scan-sessions.py` 结果 + 当前会话, 找反复出现的固定流程, 建议做成 skill。**只提议, 不自动创建。** 够格条件须同时满足:
   1. **跨会话证据**: 在 ≥2 个会话出现, 且**列出是哪几个会话**(session id/日期/简述);
   2. **可复用**: 步骤相对固定、有清晰输入输出;
   3. **无重复**: 现有 skills 里无同类。
   建议给出: 候选 skill 名、解决的重复问题、跨会话证据、"下一步走仓库 `docs/SKILL_GUIDE.md` 新增 skill 流程"。
6. **其他发现** — 主动抛出用户没提到但有价值的模式(反复踩的卡点、常用工具/命令习惯、协作偏好)。够格的归入板块 3 的 memory 建议。

判断闸门细则外置到 `references/judgement-gates.md`, SKILL.md 只留要点。

## 5. 落地流程 (先汇报, 用户拍板)

```
/done
  → 读取当前会话上下文 + (板块4) 运行 scan-sessions.py 扫描历史 transcript
  → 生成五板块 debrief, 每项带 [建议]/[无需动作]
  → 呈现, 等待用户指令 (例: "1、3 做, 其余跳过")
  → 仅对被批准项执行:
       · 写 memory: 复用现成 memory/ 系统, 遵守 MEMORY.md 索引规范 (同主题则更新而非新建)
       · 提问模板: 写入/更新模板文件 (位置见"待定")
       · 建议 skill: 引导进入仓库 SKILL_GUIDE.md 的新增流程 (本 skill 不直接造 skill)
```

**绝不在未批准前写入任何文件。** (与 SKILL_GUIDE"删除/发布/写入前须确认"的安全要求一致。)

## 6. 判断闸门汇总

- 项目记忆: 必须"跨会话成立 + 代码/git 查不到", 与用户 CLAUDE.md memory 规范一致。
- 提问模板: 仅在确有更优提法时更新。
- 知识短板: 必须引用本次会话的具体证据; 给方向不说教; 无信号则跳过, 不无端评判。
- Skill 候选: ≥2 会话证据 + 可复用 + 无重复, 且附证据。
- 通则: **宁可不写, 不硬凑。** 每板块允许"本次无"。

## 7. 非目标 (YAGNI)

- 不做全自动写入(用户明确要"先汇报后拍板")。
- 不解析历史会话的全部 assistant 输出/工具调用(只取用户意图)。
- 不在本 skill 内直接创建 skill(交给仓库 SKILL_GUIDE 流程)。
- 不做定时/自动触发(纯手动 `/done`)。
- 不做 transcript 精确统计报表(那是别的 skill)。

## 8. 仓库维护义务 (改动完成后)

1. 新建 `skills/productivity/review/done/{SKILL.md, references/…, scripts/…}`。
2. 更新 `docs/CATEGORIES.md`: 在"当前 Skill"表加 `done` 行(路径/来源=自有/说明)。
3. 更新 `skills/productivity/README.md`: 纳入 `review` 子类。
4. 新建 `skills/productivity/review/README.md`: 说明 review 子类边界。
5. 运行 `bash scripts/doctor.sh`; 脚本改动做 `python3 -m py_compile`/语法检查。
6. 向用户报告 git 同步状态(未提交/未推送/需拉取/干净); 在 `main` 上须先开分支再提交, 且仅在用户要求时提交推送。

## 9. 待实现计划确定的细节

- 提问模板存放位置与格式(单文件累积? 每项目一个? 放 memory 还是独立文件?)。
- `scan-sessions.py` 聚类启发式(关键词? 按 gitBranch 分组?)、规模上限、语言(Python 已可用)。
- SKILL.md `description` 触发语措辞(确保 `/done` 与"复盘/总结这次会话/这次聊得怎么样"能命中, 且不误触发)。
- `references/judgement-gates.md` 的具体清单粒度。
