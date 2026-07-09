---
title: 今日宜吃的架构设计
published: 2026-07-08
description: 一个基于黄历的 AI 开运菜单生成器，前端 Vue 3 + 后端 FastAPI + openai-agents，monorepo 组织三个工程。
tags: [todayfood, Vue, FastAPI, AI, 架构]
category: 项目复盘
draft: false
---

[今日宜吃](https://food.example.com)是我做的一个小项目：基于黄历的 AI 开运菜单生成器，每天给你一签、一菜、一份干饭宜忌，搭配幸运三件套（口味/颜色/方位）。小程序竖屏布局，所有内容当日固定，凌晨 0 点按北京时间切换。

这篇复盘它的架构设计。

## 整体架构

```
┌─────────────┐   /api/*   ┌─────────────┐
│  frontend   │ ─────────▶ │  backend    │
│  (Vue 3)    │            │  (FastAPI)  │
└─────────────┘            └──────┬──────┘
       │                          │ 内嵌
       │                          ▼
       │                  ┌─────────────┐
       │                  │ admin 模块  │
       │                  │ (router/db) │
       │                  └─────────────┘
       │                          │
       │                          ▼
       │                  ┌─────────────┐
       └─────────────────▶│   SQLite    │
                          └─────────────┘
```

前端纯静态，后端跑 FastAPI，两者通过 `/api/*` 通信。后端内嵌了 admin 管理模块，共享同一个数据库。

## Monorepo 组织

仓库是 monorepo，包含三个工程：

| 目录 | 技术栈 | 说明 |
|------|--------|------|
| `frontend/` | Vue 3 + Vite | 用户侧 H5 应用（食历 / 择食 / 关于） |
| `backend/` | FastAPI + openai-agents | 业务 API + AI 接入 + 后台管理（内嵌） |
| `admin/` | FastAPI + 单文件 HTML | 后台管理界面（可独立部署） |

之所以放一起而不是拆三个仓库，是因为这三个工程耦合很紧：admin 和 backend 共享数据库 schema，frontend 的 API 契约直接对 backend。拆开反而增加同步成本。

## 前端几个关键决策

### API 前缀统一为 `/api`

```js
// frontend/src/config.js
const API_BASE = import.meta.env.VITE_API_BASE || '/api'
export const API = {
  TODAY: `${API_BASE}/fortune/today`,
  DRAW: `${API_BASE}/fortune/draw`,
}
```

开发环境由 Vite 代理 `/api` 到后端，生产环境由 nginx 反代。前后端前缀一致，切换环境零改动。

### 摇签动画的最小时长

AI 调用耗时不确定，但用户体验上摇签动画不能"一调就停"或"卡死等"。所以设了一个最小时长：

```js
export const DRAW_MIN_DURATION = 2500
```

不管走不走 AI 调用，摇签动画至少持续 2.5 秒；若 AI 调用耗时更长，则摇动状态一直保持到后端返回。这是个很小的细节，但对体验影响很大。

## 后端为什么用 openai-agents

一开始后端就是普通的 FastAPI + 直接调 OpenAI SDK。后来迁到 `openai-agents`，主要图两点：

1. **Agent 抽象**：菜单生成涉及多步推理（看黄历 → 定宜忌 → 选食材 → 组菜谱），用 Agent 比手写 prompt 拼装清晰
2. **工具调用规范**：Agent 框架对 function calling 的生命周期管理更稳

## 部署

后端用 systemd 常驻，监听 9081 端口；前端 `vite build` 出静态文件，nginx 托管并反代 `/api`。这个组合在 VPS 上零成本、足够稳。

## 小结

这个项目体量不大，但把"前端静态 + 后端 API + AI 接入 + 后台管理"这套常见组合走了一遍。monorepo 组织、API 前缀统一、动画最小时长这些细节，都是小决策但经得起复用。
