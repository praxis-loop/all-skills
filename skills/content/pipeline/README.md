# content/pipeline

`content/pipeline` 用于跨环节的内容生产入口与路由。

适合放入本子类的 skill：

- 判断当前处境该走哪一步，分发到对应的写作、封面、发布或视频 skill。
- 串联从选题、调研、写作到平台草稿的完整链路。
- 一轮工作结束后决定下一步。

边界：路由类 skill 本身不产出成稿，也不构成公开发布授权。

新增 skill 时使用：`skills/content/pipeline/<skill-name>/SKILL.md`。
