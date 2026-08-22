# platforms/agent-vault

[agent-vault](https://github.com/Infisical/agent-vault) 的绑定：凭证保管、按 vault 授权、缺权限时走人工审批。

它和 `lark` 的性质不同——`lark` 是一个业务平台，`agent-vault` 是**所有其他 skill 的凭证底座**。任何 skill 只要需要密钥、token 或 SSH 私钥，都从这里取。

## 当前 skill

| Skill | 用途 |
|---|---|
| `agent-vault-shared` | 基座：CLI 安装与校验、权限自查、取凭证的标准姿势、缺权限走 proposal、收尾清理 |

## 谁在引用它

任何在 frontmatter 里声明了 `x-vault-*` 的 skill：

- `engineering/devops/server-ops`

引用方只声明**需要哪些 vault**；"怎么装、怎么取、什么不能做"只在基座写一份。

## 外部依赖：agent-vault CLI

**skill 文件不包含二进制**（照 [platforms 维护规则](../README.md#维护规则)）。单文件静态链接，无运行时依赖。

```bash
VER=0.39.1
ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; esac
OS=$(uname -s | tr 'A-Z' 'a-z')
TGZ="agent-vault_${VER}_${OS}_${ARCH}.tar.gz"

cd "$(mktemp -d)" && mkdir -p ~/.local/bin
curl -fsSL "https://github.com/Infisical/agent-vault/releases/download/v${VER}/${TGZ}" -o "$TGZ"
curl -fsSL "https://github.com/Infisical/agent-vault/releases/download/v${VER}/checksums.txt" -o checksums.txt
grep " ${TGZ}\$" checksums.txt | sha256sum -c - || exit 1
tar -xzf "$TGZ" agent-vault && install -m 0755 agent-vault ~/.local/bin/agent-vault
```

三条注意：

- **钉版本，不要 `latest`。** CLI 版本应与服务端一致。
- **官方无 Windows 构建**（只有 linux / darwin，各 amd64 / arm64）。Windows 机器须在 WSL 内运行。
- **校验 sha256。** 官方 release 附 `checksums.txt`，装完自验，失败就终止。

## 人与 agent 是两条独立的认证路径

| | 人 | agent |
|---|---|---|
| 认证方式 | `agent-vault auth login`（邮箱密码，会话落盘） | `AGENT_VAULT_TOKEN` 环境变量 |
| 能否管理 vault | 能（`vault create` / `list` / `service` / `proposal review`） | **不能**，与角色无关 |
| 能否枚举自己的 vault | 能 | **不能**，`vault list` 报 `not logged in` |
| 查自己有什么 | — | `vault discover --vault <名>`（必须指名） |

> ⚠️ **同一台机器上人登录过，会掩盖 agent 的真实权限。** 落盘的人类会话可能让 `vault list` 这类命令看起来能用——那是人的权限。判断 agent 能做什么，只看 `discover --vault` 的结果。

## 环境变量

由平台注入，agent 不得自行编造（multica 通过 `agent.custom_env` 注入）：

```
AGENT_VAULT_ADDR      服务地址
AGENT_VAULT_TOKEN     本 agent 的长期 token
AGENT_IDENTITY_VAULT  本 agent 专属身份 vault 名
```

**per-agent 的东西一律放进它自己的身份 vault，不要增加环境变量。** 这样新增一个 agent 只需建一个 vault，平台侧配置形状永远不变——换平台时要搬的也只有 vault。

## 身份 vault 装什么

`identity-<agent>` 是该 agent 的全部个人身份，约定键名如下：

| 键 | 内容 |
|---|---|
| `SSH_PRIVATE_KEY` / `SSH_PUBLIC_KEY` | 该 agent 专属的 ed25519 密钥对，注释为 `<agent>@xan` |
| `GIT_AUTHOR_NAME` | 统一为 `RichXan` |
| `GIT_AUTHOR_EMAIL` | 按 agent 区分，`<agent>@xan` |

**推送用的 PAT 不在这里，在共享的 `vcs` vault**（`GH_TOKEN` / `AZDO_PAT` / `AZDO_ORG_URL`）——那是"能不能推"，属于平台凭证；身份 vault 装的是"你是谁"。

`GIT_AUTHOR_EMAIL` 与 SSH 公钥注释**是同一个字符串**——所以同一个 agent 在服务器 `auth.log` 与仓库 `git log` 里长得一样，两端可对上。

新增 agent 时照这张表建齐，`custom_env` 那三个变量不变。
