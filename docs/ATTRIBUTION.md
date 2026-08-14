# 外部作品来源与署名

本文件记录以「引入」方式 fork 进本仓库的外部 skill：它们不由 `skillctl` 跟踪上游，已按本仓库需要改名和改写，因此必须在此声明原作者、原始许可证和本地改动。

## rayskills

| 项 | 内容 |
|---|---|
| 原作者 | imraywang |
| 上游仓库 | <https://github.com/imraywang/rayskills> |
| 引入版本 | commit `0ea361aab79a9cc9f36d4f875bf06832e0f3f4f8`（2026-08-03） |
| 引入日期 | 2026-08-12 |
| 许可证 | Creative Commons Attribution-NonCommercial 4.0 International（CC BY-NC 4.0），全文见 [licenses/rayskills-CC-BY-NC-4.0.txt](licenses/rayskills-CC-BY-NC-4.0.txt) |
| 使用范围 | **仅限个人非商业使用。** CC BY-NC 4.0 禁止商业性使用，这些 skill 不得用于 OPC 的对外经营、客户交付、商业内容生产或任何以营利为目的的场景。 |

引入的 skill：

| 本仓库 skill | 上游 skill | 路径 |
|---|---|---|
| `xan` | `ray` | `skills/content/pipeline/xan` |
| `xan-writer` | `ray-writer` | `skills/content/blog/xan-writer` |
| `xan-wechat` | `ray-wechat` | `skills/content/publishing/xan-wechat` |
| `xan-x-article` | `ray-x-article` | `skills/content/publishing/xan-x-article` |
| `xan-cover` | `ray-cover` | `skills/media/images/xan-cover` |
| `xan-broll` | `ray-broll` | `skills/media/video/xan-broll` |
| `xan-obsidian` | `ray-obsidian` | `skills/productivity/knowledge-management/xan-obsidian` |
| `xan-consult` | `ray-consult` | `skills/operations/consulting/xan-consult` |
| `xan-multimodel` | `ray-multimodel` | `skills/engineering/ai-workflow/xan-multimodel` |

已做的本地改动（CC BY 要求标明修改）：

- 全部标识符由 `ray` / `ray-*` 改为 `xan` / `xan-*`，包括目录名、frontmatter `name`、`/ray-xxx` 触发词、skill 之间的互相转交。
- 配套标识符同步改名：`.ray-obsidian.json` → `.xan-obsidian.json`、`RAY_WECHAT_DIRECT` → `XAN_WECHAT_DIRECT`、`references/ray-themes.json` → `references/xan-themes.json`、`ray-judgment` / `ray-method` / `ray-deepread` 等主题标签。
- 正文中作为作者人设的「Ray」全部改为「Xan」，含 `references/voice.md`、`references/approved-examples.md` 里的写作范本。
- 目录结构由上游的扁平 `skills/<name>/` 改为本仓库的 `skills/<function>/<domain>/<skill>/`。
- 未改动各 skill 的方法论、流程、脚本逻辑和安全边界。

## 上游内的第三方成分

- `skills/media/video/xan-broll/scripts/generate_video.py` 含来自「狗哥笔记」的 MIT 授权代码，版权声明已随文件保留。
- `skills/engineering/ai-workflow/xan-multimodel/LICENSE.codex-grok-search` 是上游随附的独立授权文件，原样保留。
- `skills/content/publishing/xan-wechat` 在排版环节可调用 `isjiamu/gzh-design-skill`（AGPL-3.0）。它被当作独立外部工具调用，其组件代码不得复制进本仓库。
