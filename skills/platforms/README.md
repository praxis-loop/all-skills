# platforms

`platforms` 用于外部 SaaS / 平台的 API 与 CLI 绑定。

它和其他顶层职能的划分依据不同：其他 function 回答「这件事属于哪个部门」，`platforms` 回答「这组能力绑定哪个外部平台」。当一组 skill 的真正共性是**共用同一套 CLI、同一套凭据和 scope、同一条授权链路**，而不是共用一个业务场景时，放这里。

## 什么时候放进 platforms

同时满足：

- 能力来自某个具体的外部平台（飞书、GitLab、Nextcloud、n8n 等），离开这个平台就没有意义。
- 该平台的多个 skill 共享一套认证与安全边界，通常还共享一个外部二进制。
- 按职能归类会把它们拆散到多个 function，反而更难找。

只服务单个业务流程、不成组的平台脚本，仍然按职能归类。例如「用飞书发周报」属于 `content/reports`，而「飞书文档 API 操作」属于 `platforms/lark`。

## domain 约定

`domain` 一律是**平台名**（小写、短横线），不是业务主题：

```text
skills/platforms/<platform>/<skill-name>/
```

同一平台的所有 skill 必须是**同级兄弟目录**。厂商仓库里的 skill 常用 `../<sibling>/SKILL.md` 互相引用，打散层级会让这些引用全部失效。

## 维护规则

本目录以 `skillctl` 跟踪的**第三方快照**为主：

- 来源声明在 `sources/skills.sources.yaml`，用 `tools/skillctl add` 登记、`tools/skillctl sync` 落盘。
- **不要手工修改快照目录**，`skillctl sync` 会整目录覆盖。本地改造写成 `overlays/<skill-name>/overlay.yaml`，每次同步后自动重放。
- 平台所需的外部二进制**不入库**。在 skill 的 `compatibility` 字段声明，并在实际执行的脚本里做前置检查，缺失时给出可执行的安装提示。

## 当前已启用 domain

- `lark`：飞书 / Lark，见 [lark/README.md](lark/README.md)
- `agent-vault`：凭证保管与分发。所有需要凭证的 skill 共用它的 CLI、授权链路和安全边界
