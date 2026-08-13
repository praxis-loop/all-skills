# platforms/lark

飞书 / Lark 的 API 绑定，全部通过官方 [`lark-cli`](https://github.com/larksuite/cli) 执行。

## 当前 skill

| Skill | 用途 |
|---|---|
| `lark-shared` | 基座：应用配置、登录授权、user/bot 身份切换、scope 排障。其余 skill 遇到认证错误时读它 |
| `lark-doc` | 云文档：Docx / Wiki 读取、创建、编辑、历史版本、素材与画板 |
| `lark-im` | 消息：发送回复、群聊管理、消息搜索、图片文件收发 |
| `lark-base` | 多维表格：表、字段、记录、视图、仪表盘、数据聚合 |
| `lark-drive` | 云空间：文件上传下载、文档搜索、副本与权限、文档评论。`lark-doc`/`lark-im` 的文件类操作都转它 |
| `lark-sheets` | 电子表格：读写、追加、查找、导出 |
| `lark-whiteboard` | 画板：图形 DSL 渲染，被 `lark-doc` 的画板链路调用 |

上游 `larksuite/cli` 共有 27 个 skill，这里只收了在用的七个。要加新的，照抄下面的命令换 skill 名即可。

## 外部依赖：lark-cli

**skill 文件不包含 `lark-cli` 二进制**。`skillctl sync` 只搬 Markdown，装 skill 不会顺带装 CLI；没装的话所有命令都是 `command not found`。

```bash
# 安装
npx @larksuite/cli@latest install

# 配置应用凭据（一次性，输出授权 URL，需在浏览器完成）
lark-cli config init

# 登录授权（建议用 --domain 收窄，别无脑 --recommend）
lark-cli auth login --domain docs --domain im --domain bitable

# 验证
lark-cli auth status
```

授权后 agent 是**以你本人身份**在授权 scope 内操作飞书。写操作先 `--dry-run`，配套机器人只当私聊助手用，不要拉进群。

## 维护

五个目录都是 `skillctl` 跟踪的第三方快照，**不要直接编辑**——`skillctl sync` 会整目录覆盖。

```bash
# 新增一个上游 skill
./tools/skillctl add github larksuite/cli \
  --path skills/lark-sheets --target skills/platforms/lark/lark-sheets
./tools/skillctl sync

# 检查上游是否有更新
./tools/skillctl check
```

本地改造走 overlay：`overlays/<skill-name>/overlay.yaml`，声明 `replace: [{file, from, to}]`，每次同步后自动重放。`from` 匹配不到会直接报错——上游改了对应文本你能立刻发现，而不是静默失效。

## 已知悬空引用

上游 skill 之间用 `../<sibling>/SKILL.md` 互相引用。只收了七个，以下引用仍指向未收录的目录（数字为出现次数，含 `references/` 下的文件）：

| 缺失 | 引用数 | 影响 |
|---|---|---|
| `lark-wiki` | 40 | `lark-doc` 遇到 Wiki token / `/wiki/` 链接时的路由目标，缺口最大 |
| `lark-markdown` | 4 | Drive 原生 `.md` 文件的创建与增量修改 |
| `lark-event` | 2 | WebSocket 实时事件订阅，`lark-im` 的卡片回调链路会提到 |
| `lark-okr` / `lark-note` / `lark-apps` | 各 1 | 边缘路径 |

按需补收即可，命令见上一节。优先级最高的是 `lark-wiki`。
