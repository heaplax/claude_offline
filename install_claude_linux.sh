#!/usr/bin/env bash
set -euo pipefail

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
[[ $# -eq 0 ]] || die '用法：bash install_claude_linux.sh'
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || die '此包仅适用于 Linux x86_64。'
getconf GNU_LIBC_VERSION >/dev/null 2>&1 || die '此包需要 glibc，不支持 Alpine/musl。'
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
manifest="$script_dir/claude-code-offline.sha256"
[[ -f "$manifest" ]] || die '同目录缺少 claude-code-offline.sha256。'
[[ "$(awk 'END {print NR}' "$manifest")" == 1 ]] || die '校验文件应只有一条记录。'
read -r digest archive extra < "$manifest" || die '校验文件格式错误。'
[[ "$digest" =~ ^[[:xdigit:]]{64}$ && -z "$extra" ]] || die '校验文件格式错误。'
[[ "$archive" =~ ^anthropic-ai-claude-code-linux-x64-([0-9]+\.[0-9]+\.[0-9]+)\.tgz$ ]] || die '校验文件中的包名格式错误。'
version=${BASH_REMATCH[1]}
(cd "$script_dir" && sha256sum -c -- claude-code-offline.sha256) || die '离线包缺失或校验失败。'

bin_dir="$HOME/.local/bin"
target="$bin_dir/claude"
mkdir -p -- "$bin_dir"
stage=$(mktemp -d "$bin_dir/.claude-offline.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
tar -xzf "$script_dir/$archive" -C "$stage" package/claude
[[ -f "$stage/package/claude" && ! -L "$stage/package/claude" ]] || die '包内缺少普通可执行文件。'
install -m 0755 "$stage/package/claude" "$stage/claude"
reported=$(DISABLE_AUTOUPDATER=1 "$stage/claude" --version) || die '新版本无法运行，未替换旧版本。'
[[ "$reported" == "$version "* || "$reported" == "$version" ]] || die "版本不匹配：预期 $version，实际 $reported"

if [[ -e "$target" || -L "$target" ]]; then
  [[ -L "$target" || -f "$target" ]] || die "无法替换 $target：不是普通文件或链接。"
  backup_dir=$(mktemp -d "$bin_dir/.claude-backup.XXXXXXXX")
  cp -Pp -- "$target" "$backup_dir/claude"
  printf '旧入口已备份。需要回滚时执行：\n  mv -fT -- %q %q\n' "$backup_dir/claude" "$target"
fi
mv -fT -- "$stage/claude" "$target"
printf '安装完成：%s\n路径：%s\n' "$reported" "$target"
printf '在当前终端执行：export PATH="$HOME/.local/bin:$PATH"; hash -r; claude --version\n'
