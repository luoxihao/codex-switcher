#!/bin/sh
set -eu
# 用法: sh packaging/publish-gh-pages.sh [版本号]
# 前置: 先运行 build-deb.sh 和 build-repo.sh，生成 packaging/releases/apt
# 作用: 把签名 apt 仓库推到 gh-pages 分支（GitHub Pages 免费托管），
#       之后 apt-get 就能从 https://<user>.github.io/codex-switcher/apt 安装
pkg_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$pkg_dir/.." && pwd)
ver=${1:-3.0.0}
apt="$pkg_dir/releases/apt"
[ -d "$apt" ] || { echo "缺少 $apt，请先运行 build-deb.sh 和 build-repo.sh" >&2; exit 1; }
remote=${REMOTE:-origin}
branch=gh-pages

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

git clone -q "$repo_dir" "$tmp"
cd "$tmp"
if git ls-remote --exit-code "$remote" "$branch" >/dev/null 2>&1; then
  git fetch -q "$remote" "$branch"
  git checkout -q -B "$branch" "FETCH_HEAD"
else
  git checkout -q --orphan "$branch"
fi

# 只保留 apt 仓库 + 公钥
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
mkdir -p apt
cp -a "$apt/." apt/
cp "$pkg_dir/releases/codex-switcher.asc" .

git add -A
if git diff --cached --quiet; then
  echo "gh-pages 无变化，无需推送（已是最新）。"
  exit 0
fi
git commit -q -m "apt repo v$ver"
git push -f "$remote" "$branch"
echo "已推送 $remote/$branch"
echo "接下来：GitHub 仓库 Settings → Pages → Source: Deploy from a branch → $branch / (root)"
