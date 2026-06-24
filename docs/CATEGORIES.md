# Skill 分类规划

本仓库按照“用户要完成的工作类型”来给 skill 分组，而不是按照底层技术、脚本语言或某个具体 CLI 来分组。

## 当前与计划分类

| 分类 | 状态 | 适用范围 | 示例 |
|---|---|---|---|
| `automation` | 已启用 | 自动化执行类，会操作工具、设备、本地应用、定时任务或外部服务 | 钉钉打卡、本地应用启动、通知流程 |
| `reports` | 已启用 | 日报、周报、项目进展、领导汇报、工作日志 | Oazon 日报、大白话工作汇报 |
| `ecommerce` | 规划中 | 亚马逊和电商相关工作流 | 主图/副图策划、A+ 模块、Listing 文案、SEO、合规检查 |
| `operations` | 规划中 | 运维、SaaS、基础设施、监控、故障排查 | Cloudflare Tunnel、Zammad、n8n、Docker、服务器健康检查 |
| `data` | 规划中 | 数据查询、导出、日志分析、指标、BI、数据库工作流 | CloudWatch 查询、MongoDB 导出、InfluxDB 分析、Redis 检查 |
| `coding` | 规划中 | 代码仓库、工程流程、测试、CI、发布 | Code review、CI 修复、重构、Release note、PR 总结 |
| `documents` | 规划中 | 文档、表格、PPT、PDF、知识库生产 | 合同草稿、Excel 校验、PDF 提取、文档模板 |
| `research` | 规划中 | 需要检索、引用、比较和判断的信息收集类任务 | 产品调研、竞品分析、技术方案比较、资料汇总 |
| `media` | 规划中 | 图片、视频、视觉提示词、设计资产和创意生产 | 产品精修提示词、亚马逊套图策划、视觉 QA、分镜 |

## 分类规则

- 每个 skill 放在 `skills/<category>/<skill-name>/`。
- 分类名使用小写英文，必要时使用连字符。
- 分类应按照用户会怎么找这个 skill 来决定。
- 不要为了单个零散 skill 随意新增分类。
- 如果一个 skill 能放进多个分类，优先选择它最主要的用户任务场景。
- 每个分类目录都保留一个 `README.md`，用于解释这个分类的边界和适用场景。

## 什么时候新增分类

满足以下条件之一时，可以新增分类：

- 现有分类会让 skill 很难被找到。
- 这个方向未来大概率会沉淀出多个 skill。
- 这个方向有独立的安全、权限或维护规则。
- 这个方向对应清晰的用户工作领域。

新增分类时需要同步更新：

1. `docs/CATEGORIES.md`
2. 根目录 `README.md`
3. 对应 skill 的 `registry.json` 条目
4. `skills/<category>/README.md`
