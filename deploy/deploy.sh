#!/usr/bin/env bash
# Build and atomically publish Snowflow without exposing a partial dist directory.
set -euo pipefail

umask 022

BLOG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASES_DIR="$BLOG_DIR/.releases"
DIST_LINK="$BLOG_DIR/dist"
LOCK_FILE="/home/ospacer/.local/state/snowflow-site-deploy.lock"
KEEP_RELEASES=5
PNPM_CLI="${PNPM_CLI:-/home/ospacer/.cache/node/corepack/v1/pnpm/9.14.4/bin/pnpm.cjs}"

mkdir -p "$(dirname "$LOCK_FILE")" "$RELEASES_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another snowflow-site deployment is running" >&2; exit 1; }

list_releases() {
  local current
  current="$(readlink -f "$DIST_LINK" 2>/dev/null || true)"
  for release in "$RELEASES_DIR"/*; do
    [ -d "$release" ] || continue
    if [ "$release" = "$current" ]; then
      printf '* %s\n' "$(basename "$release")"
    else
      printf '  %s\n' "$(basename "$release")"
    fi
  done
}

switch_release() {
  local release_dir="$1"
  local next_link="$BLOG_DIR/.dist.next"
  ln -sfn "$release_dir" "$next_link"
  mv -Tf "$next_link" "$DIST_LINK"
}

smoke_test() {
  local response
  response="$(curl --fail --silent --show-error --location --max-time 15 https://snowflow.cloud/)"
  [[ "$response" == *'<html'* ]]
  response="$(curl --fail --silent --show-error --location --max-time 15 https://snowflow.cloud/projects/)"
  [[ "$response" == *'<html'* ]]
}

rollback_release() {
  local requested="${1:-}"
  local target

  if [ -n "$requested" ]; then
    target="$RELEASES_DIR/$requested"
  else
    target="$(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | sed -n '2s/^[^ ]* //p')"
  fi

  [ -n "$target" ] && [ -s "$target/index.html" ] || { echo "Rollback release not found" >&2; exit 1; }
  switch_release "$target"
  smoke_test
  printf 'Rolled back Snowflow to %s\n' "$(basename "$target")"
}

case "${1:-}" in
  --list)
    list_releases
    exit 0
    ;;
  --rollback)
    rollback_release "${2:-}"
    exit 0
    ;;
  "") ;;
  *)
    echo "Usage: $0 [--list|--rollback [release-id]]" >&2
    exit 2
    ;;
esac

cd "$BLOG_DIR"
release_id="$(date -u +%Y%m%dT%H%M%S)-$(date -u +%N)-$(git rev-parse --short HEAD)"
release_dir="$RELEASES_DIR/$release_id"
previous_target="$(readlink -f "$DIST_LINK" 2>/dev/null || true)"
switched=false

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [ "$status" -ne 0 ]; then
    if [ "$switched" = true ] && [ -n "$previous_target" ] && [ -s "$previous_target/index.html" ]; then
      switch_release "$previous_target"
      smoke_test || true
    fi
    if [ "$(readlink -f "$DIST_LINK" 2>/dev/null || true)" != "$release_dir" ]; then
      rm -rf "$release_dir"
    fi
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

node "$PNPM_CLI" install --frozen-lockfile
node "$PNPM_CLI" exec astro build --outDir "$release_dir"
node "$PNPM_CLI" exec pagefind --site "$release_dir"

for artifact in index.html 404.html projects/index.html sitemap-index.xml rss.xml pagefind/pagefind.js; do
  [ -s "$release_dir/$artifact" ] || { echo "Missing build artifact: $artifact" >&2; exit 1; }
done
find "$release_dir/_astro" -type f -print -quit | grep -q . || { echo "Missing Astro assets" >&2; exit 1; }
chmod -R a+rX "$release_dir"

if [ -d "$DIST_LINK" ] && [ ! -L "$DIST_LINK" ]; then
  initial_release="$RELEASES_DIR/$(date -u +%Y%m%dT%H%M%SZ)-initial"
  mv "$DIST_LINK" "$initial_release"
  previous_target="$initial_release"
fi

switch_release "$release_dir"
switched=true
smoke_test
switched=false

current_target="$(readlink -f "$DIST_LINK")"
find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
  | sort -nr \
  | cut -d' ' -f2- \
  | while IFS= read -r old_release; do
      [ "$old_release" = "$current_target" ] && continue
      printf '%s\n' "$old_release"
    done \
  | tail -n "+$KEEP_RELEASES" \
  | xargs -r rm -rf --

trap - EXIT INT TERM
printf 'Snowflow release active: %s\n' "$release_id"
