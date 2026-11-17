#!/usr/bin/env bash
# Update Claude Code from Anthropic's official GitHub Release.
set -euo pipefail

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
[[ $# -eq 0 ]] || die '用法：bash update_claude_linux.sh'
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || die '此脚本仅支持 Linux x86_64。'
getconf GNU_LIBC_VERSION >/dev/null 2>&1 || die '此脚本需要 glibc（不支持 Alpine/musl）。'
for tool in curl sha256sum tar; do
  command -v "$tool" >/dev/null || die "缺少命令：$tool"
done

repo=https://github.com/anthropics/claude-code
archive=claude-linux-x64.tar.gz
bin_dir="$HOME/.local/bin"
target="$bin_dir/claude"

latest_url=$(curl -fsSIL --retry 2 --connect-timeout 15 --max-time 45 \
  -o /dev/null -w '%{url_effective}' "$repo/releases/latest") || die '无法查询 GitHub 官方最新 Release。'
[[ "$latest_url" == "$repo/releases/tag/"* ]] || die "无法识别 Release 地址：$latest_url"
tag=${latest_url##*/}
[[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || die "无法识别 Release 版本：$tag"
version=${BASH_REMATCH[1]}

if [[ -e "$target" ]]; then
  [[ -f "$target" ]] || die "无法替换 $target：不是普通文件或指向普通文件的链接。"
  current=$(DISABLE_AUTOUPDATER=1 "$target" --version 2>/dev/null) || current=''
  current=${current%% *}
  if [[ "$current" == "$version" ]]; then
    printf '已经是 GitHub 官方最新版本：%s\n' "$version"
    exit 0
  fi
  if [[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] &&
    [[ "$(printf '%s\n' "$current" "$version" | LC_ALL=C sort -V | tail -n 1)" == "$current" ]]; then
    printf '当前版本 %s 比 GitHub 最新 Release %s 更新，跳过降级。\n' "$current" "$version"
    exit 0
  fi
fi

mkdir -p -- "$bin_dir"
stage=$(mktemp -d "$bin_dir/.claude-update.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
release="$repo/releases/download/$tag"
download() {
  curl -fSL --retry 2 --connect-timeout 15 --max-time 600 -o "$stage/$1" "$release/$1"
}

printf '正在下载官方 Claude Code %s（Linux x86_64）……\n' "$version"
download SHASUMS256.txt || die '无法下载校验文件；请确认放行 release-assets.githubusercontent.com。'
digest=$(awk -v file="$archive" '
  { sub(/\r$/, "", $0) }
  $2 == file || $2 == "*" file { print $1 }
' "$stage/SHASUMS256.txt")
[[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || die "找不到唯一有效的 $archive SHA-256。"
download "$archive" || die '下载失败，旧版本未被替换。'
printf '%s  %s\n' "$digest" "$archive" | (cd "$stage" && sha256sum -c -) ||
  die 'SHA-256 校验失败，旧版本未被替换。'

tar -xOzf "$stage/$archive" -- claude > "$stage/claude" ||
  die '无法提取官方可执行文件，旧版本未被替换。'
chmod 0755 "$stage/claude"
reported=$(DISABLE_AUTOUPDATER=1 "$stage/claude" --version) ||
  die '新版本无法运行，旧版本未被替换。'
[[ "${reported%% *}" == "$version" ]] || die "版本不匹配：预期 $version，实际 $reported"

backup=''
if [[ -e "$target" || -L "$target" ]]; then
  [[ -L "$target" || -f "$target" ]] || die "无法替换 $target：不是普通文件或链接。"
  backup_dir=$(mktemp -d "$bin_dir/.claude-backup.XXXXXXXX")
  backup="$backup_dir/claude"
  cp -Pp -- "$target" "$backup"
fi
mv -fT -- "$stage/claude" "$target"
printf '更新完成：%s\n路径：%s\n' "$reported" "$target"
if [[ -n "$backup" ]]; then
  printf '如需回滚：mv -fT -- %q %q\n' "$backup" "$target"
fi
if [[ "$(command -v claude || true)" != "$target" ]]; then
  printf '若终端没有找到新版，请执行：export PATH="$HOME/.local/bin:$PATH"; hash -r\n'
fi
