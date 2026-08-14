# engineering/ai-workflow

`engineering/ai-workflow` 用于 AI Agent 与模型本身的编排、分工和验收。

适合放入本子类的 skill：

- 多模型分工、交叉复核、方案竞赛。
- 外部模型 CLI 的调用约定与结果验收。
- Agent 工作流的任务契约和边界。

边界：本子类的 skill 会调起外部模型或 CLI，引入前需确认密钥来源、网络出口和工作区隔离规则。

新增 skill 时使用：`skills/engineering/ai-workflow/<skill-name>/SKILL.md`。
