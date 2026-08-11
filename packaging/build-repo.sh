#!/bin/sh
set -eu
# 用法: sh packaging/build-repo.sh [版本号]
# 依赖: dpkg-scanpackages (dpkg-dev), apt-ftparchive (apt-utils), gpg
# 输出: packaging/releases/apt/  (可直接托管到任意 HTTPS 静态目录，或推 gh-pages)
pkg_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
ver=${1:-3.0.0}
pkg=codex-switcher
deb="$pkg_dir/releases/${pkg}_${ver}_all.deb"
[ -f "$deb" ] || { echo "缺少 $deb，先运行 build-deb.sh" >&2; exit 1; }
command -v dpkg-scanpackages >/dev/null || { echo "需要 dpkg-dev (dpkg-scanpackages)" >&2; exit 1; }
command -v apt-ftparchive >/dev/null || { echo "需要 apt-utils (apt-ftparchive)" >&2; exit 1; }

# 没有 gpg 私钥则自动生成一个（仅用于签名本仓库）
keyid=$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/^sec/{print $2; exit}' | cut -d/ -f2)
if [ -z "$keyid" ]; then
  gpg --batch --passphrase '' --quick-gen-key "codex-switcher <luoxihao2001@outlook.com>" rsa2048 sign 0
  keyid=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2; exit}' | cut -d/ -f2)
fi

apt="$pkg_dir/releases/apt"
rm -rf "$apt"
mkdir -p "$apt/dists/stable/main/binary-all" "$apt/pool/main/c/$pkg"
cp "$deb" "$apt/pool/main/c/$pkg/"

cd "$apt"
dpkg-scanpackages --arch all pool/main > "dists/stable/main/binary-all/Packages"
gzip -9kf "dists/stable/main/binary-all/Packages"
apt-ftparchive release \
  -o APT::FTPArchive::Release::Origin=codex-switcher \
  -o APT::FTPArchive::Release::Label=codex-switcher \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures=all \
  -o APT::FTPArchive::Release::Components=main \
  dists/stable > dists/stable/Release

gpg --default-key "$keyid" --batch --yes --armor --detach-sign \
  -o dists/stable/Release.gpg dists/stable/Release
gpg --default-key "$keyid" --batch --yes --clearsign \
  -o dists/stable/InRelease dists/stable/Release
gpg --armor --export "$keyid" > "$pkg_dir/releases/codex-switcher.asc"

echo "apt 仓库: $apt"
echo "公钥: $pkg_dir/releases/codex-switcher.asc (keyid $keyid)"
echo "私钥在 ~/.gnupg，请自行备份（不要把私钥提交进仓库）"
