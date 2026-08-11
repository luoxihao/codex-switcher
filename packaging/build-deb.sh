#!/bin/sh
set -eu
# 用法: sh packaging/build-deb.sh [版本号]  默认 3.0.0
pkg_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$pkg_dir/.." && pwd)
ver=${1:-3.0.0}
pkg=codex-switcher
out="$pkg_dir/releases"
root="$pkg_dir/build-root"

rm -rf "$root"
mkdir -p "$root/DEBIAN" "$root/usr/local/bin" \
  "$root/usr/share/$pkg/assets" "$root/usr/share/doc/$pkg"

# control：版本号与 packaging/control 同步
sed "s/^Version: .*/Version: $ver/" "$pkg_dir/control" > "$root/DEBIAN/control"
install -m 0755 "$pkg_dir/postinst" "$root/DEBIAN/postinst"

install -m 0755 "$repo_dir/bin/codex-switcher" "$root/usr/local/bin/codex-switcher"
install -m 0644 "$repo_dir/assets/deepseek-models.json" "$root/usr/share/$pkg/assets/deepseek-models.json"
install -m 0644 "$repo_dir/README.md" "$root/usr/share/doc/$pkg/README.md"
install -m 0644 "$repo_dir/docs/model-switching.md" "$root/usr/share/doc/$pkg/model-switching.md"

mkdir -p "$out"
if command -v fakeroot >/dev/null 2>&1; then
  fakeroot dpkg-deb --build "$root" "$out/${pkg}_${ver}_all.deb"
else
  dpkg-deb --build "$root" "$out/${pkg}_${ver}_all.deb"
fi
echo "已生成: $out/${pkg}_${ver}_all.deb"
