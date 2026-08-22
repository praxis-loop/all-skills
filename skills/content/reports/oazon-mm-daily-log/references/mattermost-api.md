# mm.oazon.com 取数细节

`scripts/fetch_mm_day.py` 已经把下面所有内容封装好了。**正常流程直接用脚本**，本文件是脚本失效、需要手工排查或改造时的依据。

## 目录

- [为什么走浏览器桥接](#为什么走浏览器桥接)
- [鉴权与登录态](#鉴权与登录态)
- [两个必踩的坑](#两个必踩的坑)
- [用到的端点](#用到的端点)
- [频道类型与显示名](#频道类型与显示名)
- [消息字段](#消息字段)
- [故障排查](#故障排查)

## 为什么走浏览器桥接

opencli 有 163 个站点适配器，**没有 mattermost**，也没有可用的外部 Mattermost CLI。可选路径里：

| 路径 | 结论 |
|---|---|
| `opencli web read` | 不可用。Mattermost 是 SPA，抓不到消息正文 |
| `opencli browser` 抓 DOM | 可用但差。要滚动加载、结构易变、拿不到精确时间戳 |
| `opencli browser eval` + REST API | **推荐**。结构化数据、有精确 `create_at`、一次能翻完整天 |
| 申请 Personal Access Token | 可行但多一道申请，且浏览器登录态本来就在 |

结论可推广：**任何 opencli 没有适配、但你浏览器已登录的内网系统，都优先试 `browser eval` + 该系统自己的 REST API**，而不是抓 DOM。

## 鉴权与登录态

`opencli browser <session> eval` 在页面上下文里执行 JS，`fetch('/api/v4/...')` 自动带上 Mattermost 的会话 cookie，因此**不需要任何 token**。

请求统一带 `X-Requested-With: XMLHttpRequest`（Mattermost 对部分端点会据此放行 CSRF 检查）：

```js
const H = { headers: { "X-Requested-With": "XMLHttpRequest" } };
const g = async u => (await fetch(u, H)).json();
```

开工前先验登录态，拿到的 `username` 就是"我"：

```js
await g("/api/v4/users/me")   // → {id, username, email, ...}
```

如果返回 401，说明浏览器里 mm.oazon.com 没登录或会话过期，需要人工登录后重试。

## 两个必踩的坑

这两个坑各导致过一次"抓到的不是当天内容"，务必确认脚本或手写 JS 里都处理了。

### 坑 1：时区

`date -d "2026-08-12 00:00:00" +%s` 用的是**宿主机系统 TZ**，而开发机的系统 TZ 未必是 Asia/Shanghai。曾经因此把日界线算偏 8 小时，直接丢掉 09:00–15:00 的全部消息，而且从结果上看不出来——只会觉得"今天大家上午没说话"。

正确做法是显式带时区：

```python
tz = timezone(timedelta(hours=8))
start = datetime.strptime("2026-08-12", "%Y-%m-%d").replace(tzinfo=tz)
since_ms = int(start.timestamp() * 1000)
until_ms = int((start + timedelta(days=1)).timestamp() * 1000)
```

Mattermost 的 `create_at` / `last_post_at` 都是**毫秒级 epoch**，绝对时间，与服务器时区无关。

### 坑 2：翻页终止条件

两件事叠在一起：

1. `/posts?since=X&per_page=200` 里 `per_page` **会截断 since 的结果**。所以不要用 `since` 拉全天，改用 `page` 翻页 + 客户端按 `create_at` 过滤。
2. 返回体里 `posts` 是个 map，**除本页内容外还会带上本页回复所属的旧 thread 根帖**。用 `Object.values(d.posts)` 算本页最老时间，会被几天前的根帖拉到很早，第 0 页就误判"已经翻到底"，于是只拿到最近一两百条。

终止条件必须只看 `d.order`（本页真实内容的有序 id 列表）：

```js
const order = d.order || [], bag = d.posts || {};
for (const k in bag) all[k] = bag[k];              // 落全部，反正后面按时间过滤
const pageTimes = order.map(id => bag[id]).filter(Boolean).map(p => p.create_at);
if (!pageTimes.length || Math.min(...pageTimes) < SINCE || order.length < 200) done = true;
```

判据：修正前 `产品研发群` 抓到 117 条，修正后 439 条，同一天同一账号。

## 用到的端点

| 端点 | 用途 |
|---|---|
| `GET /api/v4/users/me` | 验登录、拿"我"的 id 和 username |
| `GET /api/v4/users/me/teams` | 我加入的 team |
| `GET /api/v4/users/{user_id}/teams/{team_id}/channels` | 我在该 team 里的频道，含 `last_post_at` |
| `GET /api/v4/channels/{channel_id}/posts?page=N&per_page=200` | 翻页取消息 |
| `GET /api/v4/users/{user_id}` | user_id → username（务必做缓存，否则请求量爆炸） |

`per_page` 上限是 200。

**先用 `last_post_at >= since` 筛频道**再去拉消息：账号下通常有 70–80 个频道，当天真正有消息的只有 15–25 个，不筛会白跑 3 倍请求。注意 `last_post_at` 会把只含已删除消息的频道也算成活跃，**按实抓结果二次收敛**。

## 频道类型与显示名

| `type` | 含义 | `display_name` |
|---|---|---|
| `O` | 公开频道 | 有 |
| `P` | 私有频道 | 有 |
| `D` | 单人 DM | **空**，需自行解析 |
| `G` | 多人 DM | 通常空 |

DM 的 `name` 形如 `<myUserId>__<otherUserId>`，取出对方 id 再查 `users/{id}` 得到用户名。

同一个频道可能同时属于多个 team（例如"⏰ 定时自动化与系统通知"在 Dev 研发和 OAZON 全员下各有一个同名频道），**按 `channel.id` 去重**，展示时若重名再追加 team 名区分。

## 消息字段

```jsonc
{
  "id": "...",
  "create_at": 1786518000000,   // 毫秒 epoch
  "user_id": "...",
  "message": "正文（Markdown）",
  "root_id": "",                // 非空 = 这是某个 thread 里的回复
  "delete_at": 0,               // 非 0 = 已删除，要过滤
  "type": "",                   // 非空多为 system_* 系统消息（加入/离开频道等）
  "props": { "attachments": [ { "title": "", "text": "", "fallback": "" } ] }
}
```

- `props.attachments` 里常放 bot 的结构化输出（卡片通知、巡检结果），**不能只取 `message`**，否则会丢内容。
- `root_id` 是还原上下文的关键：整理个人日报时，靠它把"我的提问"和"bot 的回答"串成一条线。

## 故障排查

| 现象 | 处理 |
|---|---|
| `opencli doctor` 显示 extension 未连接 | 让用户打开/重启浏览器扩展后重试 |
| `users/me` 返回 401 | 浏览器里 mm.oazon.com 未登录，请用户手工登录 |
| stdout 里混入 `UNDICI-EHPA` 警告导致 JSON 解析失败 | 只取第一行以 `{` 或 `[` 开头的内容作为载荷 |
| 单次 eval 超时 | 减小 `--batch`（默认 6 个频道一批） |
| 抓到的条数明显偏少 | 回到上面两个坑逐一核对，尤其是翻页终止条件 |
