---
title: VPS 部署实践：博客 + todayfood 的两种挂法
published: 2026-07-07
description: 同一台 VPS 上同时部署 Astro 博客和 todayfood 子站，子域名 vs 子路径两种方案的取舍与配置。
tags: [部署, VPS, nginx, HTTPS]
category: 运维
draft: false
---

snowflow 主站（Astro）和 todayfood 要挂同一台 VPS，怎么组织？调研下来有两种主流挂法，这篇记录取舍。

## 架构全景

```
                    ┌─── blog.example.com  →  Astro 博客（静态文件）
VPS (nginx 80/443) ─┤
                    └─── food.example.com  →  todayfood 子站（dist + 反代 /api 到 9081）
                                            （FastAPI 已在 systemd 跑 9081）
```

- **博客**：Astro `pnpm build` 产物丢 VPS，nginx 托管静态文件
- **todayfood**：独立子域名，nginx 反代 `/api` 到 FastAPI（9081）
- 两者完全解耦，互不影响，升级独立

## 方案 A：子域名独立部署

```
blog.example.com  → blog/dist
food.example.com  → todayfood/frontend/dist + 反代 /api
```

todayfood 这边什么都不用改。`vite.config.js` 没设 `base`，默认 `/`，正好适合子域名根路径部署。`/api` 也已约定好由 nginx 反代。

```nginx
# 博客
server {
    listen 80;
    server_name blog.example.com;
    root /var/www/blog;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}

# todayfood
server {
    listen 80;
    server_name food.example.com;
    root /home/ospacer/project/todayfood/frontend/dist;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
    location /api/ {
        proxy_pass http://127.0.0.1:9081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 方案 B：同域子路径

```
example.com/         → blog/dist
example.com/food/    → todayfood/frontend/dist
example.com/food/api/ → 反代到 FastAPI
```

如果想用同一个域名，blog 走 `/`，todayfood 走 `/food/`。**这需要改 todayfood 代码**，因为它现在路由用 `createWebHistory()` 且没设 base。

需要改 3 处：

```js
// 1. vite.config.js 加 base
return {
  base: '/food/',
  // ...
}

// 2. router/index.js 路由 history 传 base
const router = createRouter({
  history: createWebHistory('/food/'),
  // ...
})
```

```nginx
# 3. nginx 同一个 server，按路径分流
server {
    listen 80;
    server_name example.com;

    root /var/www/blog;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }

    location /food/ {
        alias /home/ospacer/project/todayfood/frontend/dist/;
        try_files $uri $uri/ /food/index.html;
    }
    location /food/api/ {
        rewrite ^/food/api/(.*)$ /api/$1 break;
        proxy_pass http://127.0.0.1:9081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

子路径的坑：`index.html` 里资源引用会变成 `/food/assets/...`，必须 `base` 设对；路由 history 的 base 也要对齐，否则刷新 404。

## 怎么选

**就备案号悬挂这件事，选方案 B 更省事。**

ICP 备案号要求备案主体下所有可访问的网站首页底部都要展示备案号：

| 方案 | 站点数 | 备案号要挂几处 |
|------|--------|----------------|
| A 子域名 | 两个独立站 | 两处 |
| B 子路径 | 一个站 | 一处 |

方案 B 下，整个域名对外就是一个站，备案号挂在博客底部就够。代价是 todayfood 要改 3 处代码，但这是一次性的，改完之后维护成本反而更低。

## HTTPS

不管哪种方案，用 certbot 给域名签证书：

```bash
# 方案 A
sudo certbot --nginx -d blog.example.com -d food.example.com

# 方案 B
sudo certbot --nginx -d example.com
```

## 小结

| 维度 | 方案 A 子域名 | 方案 B 子路径 |
|------|---------------|---------------|
| 代码改动 | 零 | todayfood 改 3 处 |
| 备案号 | 挂两处 | 挂一处 |
| 解耦程度 | 完全解耦 | 同域耦合 |
| 灵活性 | 挪服务器改 DNS 即可 | 需调整 nginx |

没有银弹，看重视哪头。我因为要挂备案号，选了方案 B。
