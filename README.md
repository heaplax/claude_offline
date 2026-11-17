# Claude Code 离线安装

适用于 Rocky Linux 9.2 这类使用 glibc 的 Linux x86_64 服务器。

1. 在联网的 Mac 上安装 Node.js/npm，然后运行 `bash download_claude_mac.sh`。默认从 npm 查询 Claude Code 最新正式版本并下载对应的 Linux 包；也可以在命令末尾传入完整版本号。
2. 把 `install_claude_linux.sh`、下载得到的 `anthropic-ai-claude-code-linux-x64-*.tgz` 和 `claude-code-offline.sha256` 拷到服务器的同一个目录。
3. 在服务器运行 `bash install_claude_linux.sh`。脚本按校验文件选择包，校验 SHA-256、测试新版本、备份旧入口并替换 `~/.local/bin/claude`。不需要 sudo、Node.js 或网络。
4. 执行 `export PATH="$HOME/.local/bin:$PATH"; hash -r; claude --version` 确认版本。

仓库只跟踪脚本和说明。已经打包的版本可在 [GitHub Releases](https://github.com/heaplax/claude_offline/releases) 下载。离线安装只更新可执行文件；模型请求仍需要连到已配置的服务。

## 发布新版离线包

GitHub 普通 Git 的单文件上限是 100 MiB；[Release 附件](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases#storage-and-bandwidth-quotas)每个文件须小于 2 GiB。安装包和校验文件通过 Release 上传，不提交到 Git 历史。

在联网的 Mac 上，用 GitHub CLI 登录后运行。把示例版本号换成要发布的版本：

```bash
version=2.1.326
bash download_claude_mac.sh "$version" &&
  shasum -a 256 -c claude-code-offline.sha256 &&
  gh release create "v$version" \
    "anthropic-ai-claude-code-linux-x64-$version.tgz" \
    claude-code-offline.sha256 \
    --repo heaplax/claude_offline --target main \
    --title "Claude Code $version — Linux x86_64 离线包" \
    --notes '下载两个附件，与 install_claude_linux.sh 放在同一目录后运行安装脚本。'
```
