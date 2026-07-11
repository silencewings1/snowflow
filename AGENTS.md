# AGENTS.md

本文件适用于仓库根目录及其所有子目录。处理本工程时，应优先遵循本文件，并保持改动与现有代码风格一致。

## 工程概览

Snowflow 是一个部署于 `https://snowflow.cloud/` 的 Astro 静态内容站点，基于 Fuwari 模板定制，用于博客、项目展示和个人介绍。

- Astro 负责文件路由、内容集合、静态页面生成和图片优化。
- Svelte 仅用于搜索、归档筛选、主题切换等客户端交互岛，不应将站点改造成 SPA。
- Markdown 是文章、项目和 About 页面的主要内容来源。
- Pagefind 在 Astro 构建完成后为 `dist` 生成本地全文搜索索引。
- Swup 负责页面转场，修改全局交互时必须考虑首次加载和 Swup 导航后的重复初始化。
- 本仓库不包含 TodayFood、TripMate 等项目的业务后端；`deploy/nginx.conf` 只负责相关路由和反向代理配置。

## 技术栈

- Node.js 20 或更高版本
- pnpm `9.14.4`
- Astro `5.13.10`
- Svelte `5`
- TypeScript strict
- Tailwind CSS 3、PostCSS nesting 和 Stylus
- Astro Content Collections
- Pagefind、Swup、PhotoSwipe、Expressive Code 和 KaTeX
- Biome `2.2.5`

必须使用 pnpm，不得使用 npm 或 yarn 修改依赖和锁文件。依赖版本及包管理器版本以 `package.json` 和 `pnpm-lock.yaml` 为准。

## 目录结构

- `src/pages/`：Astro 文件路由，包括首页、文章、项目、归档、RSS 和 robots。
- `src/layouts/`：全局页面外壳和主网格布局。
- `src/components/`：Astro 与 Svelte 组件；优先复用现有组件和样式约定。
- `src/content/posts/`：博客文章 Markdown。
- `src/content/projects/`：项目 Markdown 及其封面资源。
- `src/content/spec/`：About 等特殊 Markdown 内容。
- `src/content/config.ts`：内容集合 schema，新增 frontmatter 字段时必须同步修改。
- `src/assets/`：由 Astro 处理、优化和哈希化的资源。
- `public/`：无需构建处理、按原路径发布的静态文件。
- `src/styles/`：全局 CSS、Markdown 和第三方组件样式。
- `src/plugins/`：Remark、Rehype 和 Expressive Code 插件。
- `src/utils/`：内容、URL、日期和设置工具函数。
- `src/config.ts`：站点、导航、个人资料、许可证和代码主题配置。
- `deploy/`：VPS 部署脚本及 Nginx 配置，修改时需考虑同域其他应用。
- `dist/`、`.astro/`：生成产物，不得手工编辑或提交。

## 常用命令

在仓库根目录运行：

```bash
pnpm dev
pnpm check
pnpm type-check
pnpm build
pnpm preview
pnpm new-post
```

- `pnpm build` 执行 `astro build && pagefind --site dist`，是完整生产构建。
- 验证搜索功能时必须使用完整构建；`astro build` 本身不会生成 Pagefind 索引。
- `pnpm format` 和 `pnpm lint` 都带有 `--write`，会修改文件。运行前应检查工作区，运行后必须审阅差异，避免带入无关格式化。
- 不得手工修改 `dist`、`.astro`、`node_modules` 或 Pagefind 生成文件。

## 路由与布局

Astro 使用 `src/pages` 文件系统路由，没有传统的 `main.ts`：

- `/` 和分页：`src/pages/[...page].astro`
- `/posts/:slug/`：`src/pages/posts/[...slug].astro`
- `/projects/`：`src/pages/projects.astro`
- `/archive/`：`src/pages/archive.astro`
- `/about/`：`src/pages/about.astro`
- `/rss.xml`：`src/pages/rss.xml.ts`
- `/robots.txt`：`src/pages/robots.txt.ts`

页面通常通过 `MainGridLayout.astro` 进入 `Layout.astro`。修改 `Layout.astro` 的客户端脚本时，应确保事件监听不会在 Swup 页面切换后重复注册，并正确处理组件初始化和清理。

站点配置启用了 `trailingSlash: "always"`。内部链接应遵循现有 URL 工具和尾斜杠约定，不得硬编码与 `base` 冲突的路径。

## 内容约定

内容集合由 `src/content/config.ts` 定义：

- `posts`：文章标题、发布日期、更新时间、草稿、描述、封面、标签、分类和语言。
- `projects`：项目标题、描述、封面、链接、嵌入状态、状态、标签、排序和草稿。
- `spec`：About 等特殊内容。

修改或新增内容时：

- frontmatter 必须满足对应 Zod schema。
- 日期使用可被 Astro 解析的日期格式。
- 生产环境不得展示 `draft: true` 的内容。
- 项目 `status` 只能是 `ongoing`、`completed` 或 `archived`。
- 项目 `order` 数字越小，展示顺序越靠前。
- 同域子路径项目使用 `embedded: true`；外部链接使用 `embedded: false`。
- 内容关联图片优先放在对应内容目录；全站资源放在 `src/assets/images/`。
- 资源位于 `src` 时使用相对 `src` 的路径；以 `/` 开头的资源路径必须对应 `public`。
- 项目主图必须放在 `src/content/projects/` 对应项目目录，并在 frontmatter 中使用相对路径；不得使用 `/` 开头的 `public` 路径绕过 Astro 图片优化。
- `/projects/` 中所有项目主图必须通过 Astro Image 管线输出响应式 WebP，显式设置 `format="webp"`、适用于项目卡的 `widths` 和 `sizes`。生成 HTML 的 `src` 和全部 `srcset` 候选不得引用原始 PNG、JPG 或 JPEG。

## 编码与设计约定

- 保持 TypeScript strict，不得用 `any`、非空断言或关闭类型检查来掩盖问题，除非有明确且可说明的边界原因。
- 使用 `tsconfig.json` 中已有的 `@components`、`@utils`、`@layouts`、`@assets` 和 `@/*` 等路径别名。
- 遵循 Biome 配置：Tab 缩进、双引号、自动整理 import。
- 保持周边代码的命名、注释密度和组件结构；不要顺手重构无关代码。
- 注释只解释不明显的约束、生命周期或算法，不重复描述代码本身。
- 优先使用 Astro 构建期渲染；只有确实需要浏览器状态或交互时才添加 Svelte 客户端岛。
- Svelte hydration 指令应选择最小需求，避免无理由使用 `client:only`。
- 优先复用现有 Tailwind utility、共享 CSS class 和图标库，不新增重复的样式体系。
- UI 改动必须检查移动端和桌面端，不得造成文本溢出、元素重叠或布局跳动。
- 图片应通过 Astro 资源管线处理，保留合理的 `alt` 文本，并避免提交不必要的大型重复资源。
- 不得引入新的运行时依赖，除非现有依赖或平台能力无法合理完成需求。

## 验证要求

根据改动范围执行最小但充分的验证：

- 文档或纯内容改动：检查 frontmatter、链接和 `git diff --check`。
- TypeScript、Astro 或 Svelte 改动：运行 `pnpm check`。
- 内容集合、路由、构建配置、图片处理或搜索改动：运行 `pnpm build`。
- 项目主图或项目图片组件改动：检查 `dist/projects/index.html` 的 `src`、`srcset` 和 `sizes`，确保所有项目主图候选均为 WebP，且不存在原始 PNG、JPG 或 JPEG URL。
- TypeScript 工具模块或共享类型改动：视情况运行 `pnpm type-check`。
- UI 改动：除构建外，使用实际页面检查桌面端和移动端布局及交互。
- Nginx 改动：运行可用的 Nginx 配置语法检查，并明确说明无法在本机验证的上游服务。

当前仓库的已知检查基线：

- `src/components/Navbar.astro` 中 `LightDarkSwitch` 的 `client:only` 类型错误。
- `src/pages/archive.astro` 中 `PostForList[]` 与 `Post[]` 的 `category` 类型不兼容。
- `src/plugins/expressive-code/language-badge.ts` 有未使用参数提示。

新改动不得增加检查错误。报告结果时，应区分既存问题和本次引入的问题。不得声称失败的检查已经通过。

## Git 与 GitHub 工作流

每个用户需求完成并验证后，自动执行以下流程，无需再次请求确认：

1. 检查 `git status` 和差异，只选择本次需求产生或明确相关的文件。
2. 运行适用于本次改动的验证，并如实记录结果。
3. 创建一个简洁、准确描述本次需求的本地 Git 提交。
4. 将当前分支推送到远程 GitHub 对应分支。
5. 最终回复中提供提交号、推送结果和验证结果。

Git 操作必须遵守以下限制：

- 不得提交用户或其他任务产生的无关改动。
- 不得覆盖、回滚、删除或格式化无关改动。
- 不得使用 `git reset --hard`、强制推送或其他破坏性命令，除非用户明确要求。
- 推送前确认当前分支及其上游；默认推送当前分支，不擅自创建或切换分支。
- 若本地分支已领先远端，推送会同时发布这些既有提交，应在执行前向用户说明。
- 提交或推送失败时，不得声称成功；应说明失败原因、已完成步骤和仍需处理的步骤。
- 若验证因仓库既存错误失败，可在确认本次改动未新增错误后提交，但必须在最终回复中明确列出基线错误。

## 部署与安全边界

- `astro.config.mjs` 中的生产站点地址为 `https://snowflow.cloud/`。
- `deploy/nginx.conf` 同时包含 Snowflow、TodayFood 和 TripMate 路由。修改时必须检查 location 匹配顺序、静态资源路径、SPA fallback 和反向代理前缀。
- 不得将密钥、令牌、服务器密码、私钥或真实敏感环境变量提交到仓库。
- 新增环境变量时，应提供不含秘密值的示例和用途说明，并确保本地环境文件被 Git 忽略。
- 不得直接发布、部署、重载远程服务或修改 GitHub 配置，除非用户需求明确要求；常规 Git 推送按上一节自动执行。
