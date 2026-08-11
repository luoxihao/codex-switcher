# 打包与发布

维护者用。三个脚本按顺序执行即可发一版：

```bash
# 1. 打 .deb 包（输出 packaging/releases/codex-switcher_<版本>_all.deb）
sh packaging/build-deb.sh 3.0.0

# 2. 生成签名 apt 仓库（输出 packaging/releases/apt/）
sh packaging/build-repo.sh 3.0.0

# 3. 推送到 GitHub Pages（gh-pages 分支），供 apt-get 安装
sh packaging/publish-gh-pages.sh 3.0.0
```

## 前置条件（第一次）

- 打包工具：`dpkg-deb`、`dpkg-scanpackages`（dpkg-dev）、`apt-ftparchive`（apt-utils）、`gpg`、`fakeroot`（可选，保证 .deb 内文件属主为 root）。
- GPG 私钥：`build-repo.sh` 会自动生成一个签名用私钥并放在 `~/.gnupg`。**请备份私钥**：
  ```bash
  gpg --export-secret-keys <keyid> > codex-switcher-gpg.key
  ```
  私钥不要提交进仓库；公钥 `packaging/releases/codex-switcher.asc` 会被推送到 gh-pages，用户用它校验仓库。
- 推送凭据：`publish-gh-pages.sh` 使用本机 git 凭据（HTTPS token 或 SSH），需要你本机能 push。
- 启用 Pages：GitHub 仓库 Settings → Pages → Source: Deploy from a branch → `gh-pages` / (root)。启用一次即可，之后每次 `publish-gh-pages.sh` 自动更新。

## 用户侧安装（README 里有完整版）

```bash
curl -fsSL https://<user>.github.io/codex-switcher/codex-switcher.asc \
  | sudo tee /etc/apt/keyrings/codex-switcher.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/codex-switcher.asc] https://<user>.github.io/codex-switcher/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/codex-switcher.list
sudo apt-get update && sudo apt-get install codex-switcher
```

## 可选的正式 GitHub Release

apt 仓库满足 `apt-get install`；如果还想要「GitHub Releases 页面 + .deb 附件」，在网页上
`Releases → Draft a new release → 打标签 v3.0.0 → 上传 packaging/releases/codex-switcher_3.0.0_all.deb`。
（本仓库的 CI 尚未配置自动发布；需要的话可以加 GitHub Actions 工作流。）

## 目录

```text
packaging/
├── control               # deb 元数据（版本号会被 build-deb.sh 替换）
├── postinst              # 安装后脚本（不碰用户目录）
├── build-deb.sh          # 构建 .deb
├── build-repo.sh         # 构建并签名 apt 仓库
├── publish-gh-pages.sh   # 推送 gh-pages 分支
└── releases/             # 产物（已 gitignore）
    ├── codex-switcher_<版本>_all.deb
    ├── codex-switcher.asc            # 公钥
    └── apt/                          # 签名 apt 仓库
```
