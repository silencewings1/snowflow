#!/usr/bin/env bash
# ============================================================
# snowflow.cloud 博客部署脚本（Astro SSG）
#
# 用法：
#   ./deploy/deploy.sh
#
# 功能：本地 build → rsync 到 VPS → 重载 nginx
# 前提：SSH 免密已配、VPS 已装 nginx、/var/www/blog 目录存在
# ============================================================
set -euo pipefail

# —— 配置区（按需修改）——
VPS_USER="root"
VPS_HOST="your-vps-ip"
BLOG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_PATH="/var/www/blog"

echo "================================================"
echo "  snowflow.cloud 博客部署"
echo "================================================"

# —— 1. 构建 ——
echo ""
echo "[1/3] 构建博客（Astro）..."
cd "$BLOG_DIR"
pnpm install --frozen-lockfile
pnpm build
echo "构建完成 → $BLOG_DIR/dist"

# —— 2. 上传 ——
echo ""
echo "[2/3] 上传到 VPS ($VPS_HOST)..."
rsync -avz --delete \
    --exclude='.git' \
    "$BLOG_DIR/dist/" "$VPS_USER@$VPS_HOST:$REMOTE_PATH/"
echo "上传完成"

# —— 3. 重载 nginx ——
echo ""
echo "[3/3] 重载 nginx..."
ssh "$VPS_USER@$VPS_HOST" "nginx -t && nginx -s reload"
echo "nginx 已重载"

echo ""
echo "================================================"
echo "  部署完成！"
echo "  https://snowflow.cloud/"
echo "  https://snowflow.cloud/projects/"
echo "================================================"
