---
name: agent-vault-shared
description: agent-vault 基座。当 agent 需要从 agent-vault 取任何凭证（SSH 私钥、API token、git 认证）时使用；也用于安装 agent-vault CLI、确认自己有哪些 vault 权限、缺权限时发起申请。其他声明了 x-vault-* 的 skill 都引用本 skill，安装与取用方式只在这里写一份。
compatibility: 需要 agent-vault CLI（外部二进制，不入库；缺失时按正文第 1 步安装，钉版本 v0.39.1 并校验 sha256）。官方仅提供 linux / darwin 构建，Windows 须在 WSL 内运行。另需平台注入 AGENT_VAULT_ADDR、AGENT_VAULT_TOKEN、AGENT_IDENTITY_VAULT 三个环境变量。
---

# Agent Vault 基座

## 目的

让 agent 用统一的、可审计的方式取凭证，并保证**凭证只在需要的那一瞬间存在**——不落盘、不进环境变量、不进日志、不进 commit。

本 skill 不描述任何具体业务。需要凭证的 skill 在自己的 frontmatter 里声明要哪些 vault，然后引用本文。

## 输入

| 变量 | 值 | 来源 |
|---|---|---|
| `AGENT_VAULT_ADDR` | agent-vault 服务地址 | 平台注入（multica 为 `custom_env`） |
| `AGENT_VAULT_TOKEN` | 本 agent 的长期 token | 同上 |
| `AGENT_IDENTITY_VAULT` | 本 agent 专属身份 vault 名 | 同上 |

三个都是平台职责，**agent 不得自行编造或从别处推导**。

## 工作流程

### 0. 前置检查（每次都要做，不许跳过）

```bash
export PATH="$HOME/.local/bin:$PATH"      # 见下方说明，这行不能省

command -v agent-vault >/dev/null || { echo "MISSING: agent-vault CLI"; }
: "${AGENT_VAULT_ADDR:?MISSING: AGENT_VAULT_ADDR}"
: "${AGENT_VAULT_TOKEN:?MISSING: AGENT_VAULT_TOKEN}"
: "${AGENT_IDENTITY_VAULT:?MISSING: AGENT_IDENTITY_VAULT}"
```

**CLI 缺失** → 按第 1 步安装。
**环境变量缺失** → **立即停止**，在任务里回帖说明缺哪个变量，转等待人工配置。

> ⚠️ **第一行 `export PATH` 是必须的，别当成可选的保险。**
> CLI 装在 `~/.local/bin`，但**平台无法把 `PATH` 注入给你**——multica 的 `custom_env` 把 `PATH` 列为屏蔽键（`daemon.go` `isBlockedEnvKey`），HOME / USER / SHELL / TMPDIR 同理。
> 少了这行，会出现「装完了，下一条 `command -v` 还是说缺」的死循环：每次都重装、每次都找不到。
> **每个新 shell 会话都要重新 export**，它不会自己留下来。

> ⛔ **禁止绕路。** 不许把凭证写死在代码或命令里，不许改用别的账号或入口，不许"先跳过这步继续做别的然后当作完成"。缺凭证就是做不了，如实说做不了。

### 1. 安装 CLI（缺失时）

单文件静态二进制，无依赖。**钉死版本并校验，不要用 `latest`**：

```bash
VER=0.39.1
ARCH=$(uname -m); case "$ARCH" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; esac
OS=$(uname -s | tr 'A-Z' 'a-z')          # linux | darwin
TGZ="agent-vault_${VER}_${OS}_${ARCH}.tar.gz"

mkdir -p ~/.local/bin && cd "$(mktemp -d)"
curl -fsSL "https://github.com/Infisical/agent-vault/releases/download/v${VER}/${TGZ}" -o "$TGZ"
curl -fsSL "https://github.com/Infisical/agent-vault/releases/download/v${VER}/checksums.txt" -o checksums.txt
grep " ${TGZ}\$" checksums.txt | sha256sum -c - || { echo "校验失败，终止"; exit 1; }

tar -xzf "$TGZ" agent-vault && install -m 0755 agent-vault ~/.local/bin/agent-vault
export PATH="$HOME/.local/bin:$PATH"
agent-vault version                      # 必须能跑通再往下，否则回到第 0 步看 PATH
```

**装完立刻验证一次**。若 `agent-vault version` 报 `command not found`，问题是 PATH 不是安装——`ls -l ~/.local/bin/agent-vault` 确认文件在，然后回第 0 步。**不要重复下载。**

首次安装会下 ~13 MB。若下载失败或极慢，**不要重试第三次**——直接回帖说明该 runtime 到 `github.com` / `objects.githubusercontent.com` 的连通性有问题，转人工。这类网络问题 agent 解决不了，反复重试只会耗光任务时间。

已知校验和（v0.39.1，官方 `checksums.txt`）：

| 包 | sha256 |
|---|---|
| `linux_amd64` | `746b18407eec0cadd2c3da918a929c5b071e48536eb12588fa1803896d246991` |
| `linux_arm64` | `9f10237807aee914d87f229e7fc92b36814927b24bb8c2dcb3933f0502024712` |
| `darwin_amd64` | `43f0517b931b079a2c5f3543d5824c30290efc42622a561a3c7894c2cb6ad7fe` |
| `darwin_arm64` | `6cb8c758e915a1575221e04cd1610b06f7218500bd15d30f29565d1930826f44` |

**官方无 Windows 构建。** Windows 机器必须在 WSL 内运行。

**版本要与服务端一致。** 服务端版本用 `agent-vault version` 对照人工确认；不确定就在任务里问，不要自行升级到更高版本。

### 2. 确认自己有什么权限

```bash
agent-vault vault discover --vault "$AGENT_IDENTITY_VAULT"
```

输出形如：

```
Vault:       identity-x-backend

No services configured.

Available Credentials
  SSH_PRIVATE_KEY
  SSH_PUBLIC_KEY
```

三条必须知道的行为：

- **agent 模式下无法枚举自己有哪些 vault。** `vault list` 会报 `not logged in`。要试哪些 vault，由引用方 skill 的 `x-vault-*` 字段给出清单——**那是待试清单，不是权限声明**。
- **`--vault` 是必填的**，不带会报 `vault is required in agent mode`。
- **无权限的报错是明确的**：`Error: Agent does not have access to vault: <name>`。看到这条就是没授权，不要重试、不要换写法。

> ⚠️ **陷阱：人类会话会掩盖 agent 的真实权限。** 如果这台机器上有人执行过 `agent-vault auth login`，落盘的会话可能让 `vault list` 这类管理命令**看起来能用**。那是人的权限，不是你的。判断自己能做什么，**只看 `discover --vault` 的结果**。

**运行时权限的唯一真相是 `discover`，不是 manifest。**

### 3. 取凭证

按用途选姿势。共同原则：**凭证只在需要的那一瞬间存在**。

#### 3.1 普通 token —— 用完即弃的子 shell

```bash
curl -s -H "Authorization: Bearer $(agent-vault vault credential get CLOUDFLARE_API_TOKEN --vault infra)" \
  "https://api.cloudflare.com/client/v4/zones"
```

不要 `TOKEN=$(...)` 存进变量后长期使用——变量会被后续命令、错误回显、调试输出带出来。

#### 3.2 SSH 私钥 —— 走 `ssh-add -`，全程不落盘

```bash
eval "$(ssh-agent -s)"
{ agent-vault vault credential get SSH_PRIVATE_KEY --vault "$AGENT_IDENTITY_VAULT"; echo; } | ssh-add -
ssh-add -l                    # 确认加载成功再往下
# ... 用完 ...
ssh-agent -k
```

> ⚠️ **结尾那个 `echo` 是必须的。** 私钥入库时若漏了结尾换行，`ssh-add` 会报 `error loading key "(stdin)": error in libcrypto`——一个完全不提示格式问题的错误，极难定位。加上 `echo` 可防御这种情况。

**绝不** `agent-vault ... > key.pem`。私钥不落盘。

#### 3.3 git 提交身份

**每次在仓库里工作前先设身份**，否则提交会挂在 daemon 机器的默认身份上，分不清是哪个 agent 干的：

```bash
git config user.name  "$(agent-vault vault credential get GIT_AUTHOR_NAME  --vault "$AGENT_IDENTITY_VAULT")"
git config user.email "$(agent-vault vault credential get GIT_AUTHOR_EMAIL --vault "$AGENT_IDENTITY_VAULT")"
git config user.email     # 确认设上了再干活
```

约定：**name 统一 `RichXan`，email 按 agent 区分**（`x-backend@xan`、`x-devops@xan` …）。

这个 email 与该 agent 的 SSH 公钥注释是同一个字符串，所以**同一个 agent 在服务器的 `auth.log` 和仓库的 `git log` 里长得一样**，两端能对上。

只设 `--local`（不带 `--global`）——托管 workdir 用完即弃，不要污染机器级配置。

#### 3.4 git 推送认证 —— 走 `GIT_ASKPASS`

git 需要密码时才调脚本，脚本现取现给。**token 不进 `.git/config`、不进环境变量、不进进程列表**：

```bash
ASKPASS=$(mktemp)
cat > "$ASKPASS" <<'EOF'
#!/bin/sh
case "$1" in
  Username*) echo "$GIT_VAULT_USER" ;;
  Password*) agent-vault vault credential get "$GIT_VAULT_KEY" --vault "$GIT_VAULT_NAME" ;;
esac
EOF
chmod 700 "$ASKPASS"

GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 \
  GIT_VAULT_USER=agent GIT_VAULT_KEY=<凭证键名> GIT_VAULT_NAME="$AGENT_IDENTITY_VAULT" \
  git push origin HEAD

rm -f "$ASKPASS"
```

⛔ **禁止**把 token 拼进 URL（`https://user:TOKEN@host/…`）。那会把 token 写进 `.git/config`，而 `git remote -v` 会直接打印出来。

##### 读走 SSH、写走 HTTPS

daemon 用 **SSH URL** clone（那是机器身份），而 PAT 只能走 **HTTPS**。所以推送要单独指定 push URL：

```bash
git remote set-url --push origin <HTTPS 地址>
```

**SSH → HTTPS 的地址换算因平台而异，不能靠猜：**

| 平台 | clone 用的 SSH URL | 推送用的 HTTPS URL |
|---|---|---|
| GitHub | `git@github.com:<org>/<repo>.git` | `https://github.com/<org>/<repo>.git` |
| Azure DevOps | `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>` | `https://dev.azure.com/<org>/<project>/_git/<repo>` |

> ⚠️ Azure DevOps 两者**结构不同**，不是简单换协议：SSH 是 `v3/org/project/repo`，HTTPS 要插一段 `_git`。照着 SSH 地址直接换协议会得到一个 404。

凭证键名按平台区分，各存在本 agent 的 `$AGENT_IDENTITY_VAULT` 里：

| 平台 | 键名 |
|---|---|
| GitHub | `GITHUB_PAT` |
| Azure DevOps | `AZDO_PAT` |

**推完立即恢复，不要把 pushurl 留在配置里：**

```bash
git remote set-url --delete --push origin <HTTPS 地址> 2>/dev/null || true
```

### 4. 缺权限时

**不要绕路，发起申请：**

```bash
agent-vault vault proposal create --vault <目标 vault> \
  --credential <KEY>="<这个凭证是什么，谁签发>" \
  --message "<为什么需要它，用在哪个任务>"
```

然后在任务里回帖说明卡在哪、已提交申请，转等待。人 `proposal review` 批准后重跑。

这既是安全机制，也是凭证清单的自然增长路径——**每一条凭证的存在都有一条对应的申请记录**。

### 5. 收尾清理

**逐项确认后才结案。任一项没做到，在回帖里明说，不许静默略过。**

| 项目 | 动作 |
|---|---|
| ssh-agent | `ssh-agent -k` —— 必须，否则私钥留在内存 |
| askpass 脚本 | `rm -f "$ASKPASS"` |
| 临时文件 | 本次创建的全部删除 |
| 后台进程 | 本次起的 `ssh -f` / 端口转发 / `nohup` 全部终止 |
| 远端遗留 | 确认目标机器上没留下进程或临时文件 |

## 输出要求

回帖引用凭证时**只写键名，不写值**：写 `CLOUDFLARE_API_TOKEN`，不写它的内容。

命令示例贴进回帖前先检查有没有把值展开进去。

## 检查项

- [ ] 第 0 步前置检查已执行
- [ ] 装 CLI 时校验了 sha256，且钉的是固定版本而非 `latest`
- [ ] 判断权限依据的是 `discover --vault` 的输出，不是 manifest
- [ ] 私钥没有落盘，token 没有进 `.git/config` 或 URL
- [ ] 第 5 步清理清单逐项完成
- [ ] 回帖与日志中不含任何凭证明文

## 边界

**一律禁止：**

- 把任何凭证写进文件、commit、日志或任务回帖
- 把 token 拼进 git remote URL
- 私钥落盘（包括临时文件）
- 缺权限时改用别的账号、别的入口、或硬编码凭证绕过
- 自行升级 CLI 到与服务端不一致的版本
- 依据 manifest 的 `x-vault-*` 判断自己有无权限（那只是待试清单）

**必须先问人：**

- 需要**新增**一条凭证到 vault（走 proposal，不要自己 `credential set`）
- 需要访问 `x-vault-*` 未列出的 vault
- 服务端与本机 CLI 版本不一致

## 引用方约定

需要凭证的 skill 在 frontmatter 里声明，并在正文第一步指向本 skill：

```yaml
x-vault-identity:
  credential: SSH_PRIVATE_KEY
  vault: $AGENT_IDENTITY_VAULT
x-vault-services:      # 待试清单，非权限声明
  - infra
```

当前引用方：

- `engineering/devops/server-ops`
