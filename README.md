# Claude Code 离线安装

适用于 Rocky Linux 9.2 这类使用 glibc 的 Linux x86_64 服务器。

1. 在联网的 Mac 上安装 Node.js/npm，然后运行 `bash download_claude_mac.sh`。默认从 npm 查询 Claude Code 最新正式版本并下载对应的 Linux 包；也可以在命令末尾传入完整版本号。
2. 把 `install_claude_linux.sh`、下载得到的 `anthropic-ai-claude-code-linux-x64-*.tgz` 和 `claude-code-offline.sha256` 拷到服务器的同一个目录。
3. 在服务器运行 `bash install_claude_linux.sh`。脚本按校验文件选择包，校验 SHA-256、测试新版本、备份旧入口并替换 `~/.local/bin/claude`。不需要 sudo、Node.js 或网络。
4. 执行 `export PATH="$HOME/.local/bin:$PATH"; hash -r; claude --version` 确认版本。

仓库只跟踪脚本和说明，下载得到的包与校验文件保存在本地。离线安装只更新可执行文件；模型请求仍需要连到已配置的服务。
