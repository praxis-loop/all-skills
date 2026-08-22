---
name: server-ops
description: 服务器排查与运维。服务不可达、返回 502/504、请求超时、容器异常退出、端口没人监听、域名解析对但打不开、需要登录机器查状态时使用。凭证从 agent-vault 取，服务清单从工作目录的 README.md 读，排查完把清单里过期的信息改回去。
x-repo: praxis-loop/servers
x-inventory: README.md
x-vault-identity:
  credential: SSH_PRIVATE_KEY
  vault: $AGENT_IDENTITY_VAULT
x-vault-services:
  - infra
---

# Server Ops

## 目的

把「某个服务出问题了」变成一次有据可查的排查：定位到机器和容器、找出原因、给出结论，并把排查过程中发现的清单错漏修回仓库。

**默认只读。** 本 skill 的产出是**诊断结论**，不是修复动作。改动线上状态需要先问（见「边界」）。

## 输入

| 来源 | 内容 |
|---|---|
| 环境变量 | `AGENT_VAULT_ADDR`、`AGENT_VAULT_TOKEN`、`AGENT_IDENTITY_VAULT` |
| 工作目录 | 服务器仓库的 clone，`README.md` 是服务清单，`AGENTS.md` 是仓库约定 |
| 任务描述 | 出问题的域名或服务名；有无授权做写操作 |

三个环境变量缺任何一个都别往下走——直接报告缺什么。

## 工作流程

### 1. 开工检查

```bash
git remote -v          # 必须匹配 frontmatter 的 x-repo（praxis-loop/servers）
git log -1 --date=short --format='%h %ad %s'
```

remote 对不上就停下报告，**不要在陌生仓库里干活**。

> `x-*` 字段是**待试清单，不是权限声明**。没有任何程序会执行它们。运行时权限的唯一真相是
> `agent-vault vault discover --vault <名>`（返回实际授权），不是 frontmatter。

**凭证相关的一切走基座 skill `platforms/agent-vault/agent-vault-shared`**——CLI 安装、权限自查、
取凭证的标准姿势、缺权限怎么申请、收尾清理，都在那里写了一份，本文不重复。开工前先完成它的
第 0 步前置检查。

清单的时效性直接决定排查质量：`README.md` 里通常写着「最后核实：<日期>」。如果距今很久，把「清单可能过期」作为默认假设，别把它当权威。

### 2. 定位

读 `README.md` 的服务清单表，由域名或服务名反查：哪台机器、哪个端口、部署在哪个目录。

**四个已知陷阱，排查时会反复踩：**

| 陷阱 | 表现 | 怎么办 |
|---|---|---|
| **nginx 可能不在链路上** | 机器上装着 nginx、`sites-enabled` 里也有 `server_name` 规则，但 `access.log` 长期是 0 字节 | 先 `ls -l /var/log/nginx/access.log` 看有没有流量。是 0 就说明隧道直连服务端口，那份 nginx 配置是历史残留，**不要拿它当权威** |
| **隧道 ingress 规则不在机器上** | 机器上翻遍了也找不到「域名 → 端口」的映射 | cloudflared 是 token 托管的，规则只存在于 Cloudflare 面板。要查得从 `infra` vault 取 `CLOUDFLARE_API_TOKEN` 调 API（见第 4 步） |
| **`latest` 标签不会自动更新** | 镜像写的是 `latest`，但容器跑的是很旧的版本 | `docker inspect --format '{{.Created}}'` 看镜像实际构建时间。版本落后太多会因缺新端点导致客户端连不上 |
| **域名解析正常不代表服务活着** | DNS 有记录、TLS 握手成功，但返回 502 | 502 是隧道到了但后端没应答，说明问题在机器侧；DNS 层没必要再查 |

### 3. 取凭证

```bash
eval "$(ssh-agent -s)"

# 结尾的 echo 是必须的：若私钥入库时漏了结尾换行，
# ssh-add 会报 "error in libcrypto" 而不是提示格式问题，极难定位
{ agent-vault vault credential get SSH_PRIVATE_KEY --vault "$AGENT_IDENTITY_VAULT"; echo; } | ssh-add -

ssh-add -l    # 确认加载成功再往下
```

私钥**全程不落盘**。不要 `> key.pem`，不要写进临时文件，不要 `echo` 到日志。

登录走仓库里的登录脚本（如 `./<provider>/<host>.sh '<命令>'`），不要手敲 IP 和端口——脚本才是权威。

> **权限不足时不要绕路。** 走 `agent-vault vault proposal create` 申请，在任务里回帖说明卡在哪，然后转等待。人批准后重跑。绕路（换账号、找别的入口）会让授权边界失效。

### 4. 排查顺序

**由便宜到贵**，每一步都可能直接给出答案，不要跳步：

```bash
# 4.1 外部探活 —— 先确认症状，不要只信报告
curl -s -o /dev/null -w 'http=%{http_code} time=%{time_total}\n' --max-time 15 https://<域名>

# 4.2 容器状态
docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'

# 4.3 日志（限量，别把全量日志灌进上下文）
docker logs --tail 100 --timestamps <容器名>

# 4.4 端口监听 —— 容器 Up 不等于端口通
ss -lntp | grep <端口>
curl -s -o /dev/null -w 'http=%{http_code}\n' --max-time 8 http://127.0.0.1:<端口>

# 4.5 最后才查隧道配置（要取凭证、要调外部 API，最贵）
```

**4.2 之前先探测 docker 怎么调用。** 不同机器上登录账号的组不一样，有的在 `docker` 组、有的只有 `sudo`：

```bash
if docker ps >/dev/null 2>&1; then D="docker"
elif sudo -n docker ps >/dev/null 2>&1; then D="sudo docker"
else echo "docker 不可用"; fi
```

后续统一用 `$D`。**不要看到 `permission denied ... docker.sock` 就判定「Docker 没运行」**——那是账号不在 docker 组，服务好好的。

判断是「内部挂了」还是「隧道错了」，用 4.1 和 4.4 对照：

| 外部 (4.1) | 本地 (4.4) | 结论 |
|---|---|---|
| 502 | 200 | 服务正常，**隧道指向了错误的端口** → 查 Cloudflare 面板 |
| 502 | 连接被拒 | 服务确实没起来 → 回到 4.2 / 4.3 |
| 200 | 200 | 症状已自愈或报告有误 → 回帖说明，别硬找问题 |

需要查隧道配置时：

```bash
TOKEN=$(agent-vault vault credential get CLOUDFLARE_API_TOKEN --vault infra)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/<account_id>/cfd_tunnel"
```

该 token 只有读权限。改隧道规则是人的事。

### 5. 两条会把你带偏的坑

**`cmd || echo FALLBACK` 会把权限错误伪装成业务结论。** 排查脚本里的兜底会吞掉 `permission denied`、`dubious ownership` 这类错误，然后返回一个看起来正常的值，让你得出完全错误的结论。要么不写兜底，要么让兜底带上原始 stderr。

**碰他人属主的目录时先看属主。** `/opt` 下的仓库常常不属于登录账号，git 会直接拒绝：

```bash
ls -ld <目录>                                  # 或 stat -c %U <目录>
sudo -u "$(stat -c %U <目录>)" git -C <目录> status    # 用属主身份跑
```

看到 `detected dubious ownership` 不要当成仓库坏了。

### 6. 收尾

#### 6.1 清单回写

排查中发现 `README.md` 与实际不符（端口变了、服务下线了、路径挪了、备注过期了），**当场改掉并提交**：

```bash
git add README.md
git commit -m "docs: 更新 <服务> 的 <字段>，实地核实于 <日期>"
git push
```

清单是下一次排查的唯一地图，让它带着错误留下去，代价由未来的每一次排查承担。写错了有 git 历史兜底，可以 revert。

同时更新表头附近的「最后核实」日期，并在 commit message 里写清依据是什么（跑了哪条命令看到了什么），不要只写「更新清单」。

#### 6.2 清理检查表

**逐项确认后才结案。任一项没做到，在回帖里明说，不许静默略过。**

| 项目 | 动作 |
|---|---|
| ssh-agent | `ssh-agent -k` —— **必须**，否则私钥留在内存里 |
| SSH 复用连接 | 用过 `ControlMaster` 就 `ssh -O exit <host>` |
| 后台进程 | 本次起的 `ssh -f` / `nohup` / `tail -f` / 端口转发，全部终止 |
| 临时文件 | 本次创建的临时文件全部删除 |
| 远端遗留 | 确认目标机器上没留下后台进程或临时文件 |

## 输出要求

回帖包含五项，缺一不可：

1. **结论** —— 一句话说清是什么问题，或明确说「没复现」
2. **依据** —— 跑了哪些命令、看到了什么。关键输出贴原文，不要复述
3. **影响面** —— 还有哪些服务受同一原因影响
4. **建议动作** —— 具体到命令级，标明哪些需要人来执行
5. **本次改动** —— 改了 `README.md` 的哪几行，commit hash

凭证、token、私钥**一律不得出现在回帖或日志里**。需要引用时写成 `CLOUDFLARE_API_TOKEN`（键名）而不是值。

## 检查项

回帖之前逐条过：

- [ ] `git remote -v` 与预期仓库一致
- [ ] 结论有命令输出支撑，不是推测
- [ ] 外部探活和本地探活都做了，对照过（4.1 vs 4.4）
- [ ] `README.md` 与实际不符之处已修正并 push
- [ ] 6.2 清理检查表逐项完成
- [ ] 回帖中不含任何凭证明文
- [ ] 做过的写操作都有事先授权

## 边界

**默认只读。** 以下动作**必须**先在任务里说明「要做什么、为什么、预期影响」，等人明确回复后才能执行——除非任务描述里已经写明授权：

- `restart` / `stop` / `up` / 任何改变容器状态的操作
- 修改配置文件、`.env`、compose 文件
- 删除任何数据、卷、镜像

**无论是否授权，一律禁止：**

- `docker compose down`（会连带删掉网络和依赖，影响面远超预期）
- 修改 `/opt/docker*` 下任何服务的配置
- 改 DNS 记录、改 Cloudflare 隧道 ingress 规则
- 在机器上留下任何常驻进程
- 把私钥写进文件，或把任何凭证打印到日志、回帖

**判断不了就问。** 排查是只读的，问一句的成本远低于改错线上状态。
