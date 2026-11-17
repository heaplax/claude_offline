#!/usr/bin/env bash
# Run on a connected Mac; the package targets Linux x86_64 with glibc.
set -euo pipefail

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
[[ $# -le 1 ]] || die '用法：bash download_claude_mac.sh [version]'
requested=${1:-latest}
[[ "$requested" == latest || "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die '请指定 latest 或完整版本号。'
command -v npm >/dev/null || die '请先安装 Node.js/npm。'
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage=$(mktemp -d "$script_dir/.claude-download.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
export npm_config_cache="$stage/npm-cache"
export npm_config_registry=https://registry.npmjs.org
export npm_config_ignore_scripts=true

package=@anthropic-ai/claude-code-linux-x64
if [[ "$requested" == latest ]]; then
  version=$(npm view @anthropic-ai/claude-code@latest version)
else
  version=$requested
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "无法识别版本：$version"
archive="anthropic-ai-claude-code-linux-x64-$version.tgz"
printf '正在下载 Claude Code %s (Linux x86_64)……\n' "$version"
(
  cd "$stage"
  npm pack "$package@$version" --silent
  tar -tzf "$archive" | awk '$0 == "package/claude" { found=1 } END { exit !found }'
  shasum -a 256 "$archive" > claude-code-offline.sha256
)
mv -f -- "$stage/$archive" "$script_dir/$archive"
mv -f -- "$stage/claude-code-offline.sha256" "$script_dir/claude-code-offline.sha256"
printf '请把以下三个文件拷到服务器的同一个目录：\n  %s\n  claude-code-offline.sha256\n  install_claude_linux.sh\n' "$archive"
