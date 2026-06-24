---
name: plain-language-daily-reports
description: Use when writing daily reports, weekly reports, manager updates, status summaries, or leadership-facing progress notes from technical work.
---

# Plain-Language Daily Reports

## Overview

Turn technical work into leadership-readable progress. Emphasize the problem, user/business impact, result, verification, and next step; avoid implementation details unless explicitly requested.

## When to Use

Use for:
- 日报、周报、项目进展、领导汇报
- 用户要求“大白话”“领导听得懂”“不要涉及代码细节”
- 把 bugfix、测试、部署、排查过程总结成工作成果

Do not use for:
- PR descriptions for engineers
- commit messages
- technical RCA documents

## Core Pattern

Convert from technical details to outcome language:

| Technical wording | Report wording |
|---|---|
| modified `getTimeRange` | 优化了日历刷新判断逻辑 |
| fixed `nextRunTimestamp: null` | 避免后续刷新任务中断 |
| added Mocha tests | 补充了自动化验证 |
| changed release source files | 同步更新了发布版本相关内容 |

## Output Rules

- 一行一句话。
- 每句只表达一个工作成果。
- 少写“怎么改”，多写“解决了什么问题”。
- 不写函数名、文件名、参数名、类名，除非用户明确要求。
- 面向领导时优先写：问题、影响、处理结果、验证状态、后续风险。
- 如果有测试失败，清楚写“本次相关验证通过，其他历史问题待单独跟进”。

## Good Example

- 排查并修复了日历事件刷新不及时的问题，避免设备漏掉后续会议提醒。
- 优化了后台刷新机制，即使当天没有会议，系统也会继续关注未来一段时间的会议变化。
- 保持用户原有显示设置不变，避免修复影响现有使用体验。
- 补充了自动化验证，降低类似问题再次出现的风险。
- 本次修复相关验证已通过，其他历史测试问题可后续单独跟进。

## Common Mistakes

| Mistake | Fix |
|---|---|
| 写代码名、参数名 | 改成业务动作或用户影响 |
| 写实现步骤过多 | 压缩成处理结果 |
| 只写“修复 bug” | 补充为什么重要 |
| 报喜不报忧 | 如有未解决项，单独写清边界 |
