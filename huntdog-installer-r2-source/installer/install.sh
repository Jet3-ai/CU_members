#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_ENV="$PACKAGE_DIR/manifest.env"
PAYLOAD_BINARY="$PACKAGE_DIR/payload/bin/huntdog"
PAYLOAD_SKILL="$PACKAGE_DIR/payload/codex-skill/wechat-huntdog"
PAYLOAD_VERIFY="$PACKAGE_DIR/installer/verify.sh"

HUNTDOG_ROOT="${HUNTDOG_HOME:-$HOME/.huntdog}"
INSTALL_BIN_DIR="$HUNTDOG_ROOT/bin"
SUPPORT_DIR="$HUNTDOG_ROOT/support"
REPORT_DIR="$HUNTDOG_ROOT/reports"
BACKUP_DIR="$HUNTDOG_ROOT/backups/$(date '+%Y%m%d-%H%M%S')"
LOCAL_BIN_DIR="$HOME/.local/bin"
CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
SKILL_TARGET="$CODEX_SKILLS_DIR/wechat-huntdog"
INSTALL_LOG="$REPORT_DIR/install-latest.log"

mkdir -p "$REPORT_DIR"
chmod 700 "$HUNTDOG_ROOT" "$REPORT_DIR" 2>/dev/null || true
exec > >(tee "$INSTALL_LOG") 2>&1

on_error() {
  error_line="$1"
  error_code="$2"
  echo
  echo "[安装失败] 行号=$error_line，退出码=$error_code"
  echo "诊断日志: $INSTALL_LOG"
}
trap 'on_error "$LINENO" "$?"' ERR

echo "CyberUnion HuntDog 安装器 r2"
echo "========================================"

if [ ! -f "$MANIFEST_ENV" ]; then
  echo "[错误] 安装包缺少 manifest.env"
  exit 10
fi

# shellcheck disable=SC1090
. "$MANIFEST_ENV"

: "${HUNTDOG_PACKAGE_VERSION:?missing HUNTDOG_PACKAGE_VERSION}"
: "${HUNTDOG_CORE_VERSION:?missing HUNTDOG_CORE_VERSION}"
: "${HUNTDOG_PLATFORM:?missing HUNTDOG_PLATFORM}"
: "${HUNTDOG_CORE_SHA256:?missing HUNTDOG_CORE_SHA256}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "[错误] 本安装包只支持 macOS。"
  exit 11
fi

machine_arch="$(uname -m)"
translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || true)"
if [ "$machine_arch" != "arm64" ] && [ "$translated" != "1" ]; then
  echo "[错误] 本安装包只支持 Apple 芯片 Mac（arm64）。当前架构: $machine_arch"
  exit 12
fi

for required_path in "$PAYLOAD_BINARY" "$PAYLOAD_SKILL/SKILL.md" "$PAYLOAD_VERIFY"; do
  if [ ! -e "$required_path" ]; then
    echo "[错误] 安装包不完整，缺少: ${required_path#$PACKAGE_DIR/}"
    exit 13
  fi
done

actual_sha="$(shasum -a 256 "$PAYLOAD_BINARY" | awk '{print $1}')"
if [ "$actual_sha" != "$HUNTDOG_CORE_SHA256" ]; then
  echo "[错误] HuntDog 核心文件校验失败，安装包可能不完整。"
  exit 14
fi

# Agent 安装和 Control-点击打开后，清除本包内文件的浏览器下载隔离属性。
xattr -dr com.apple.quarantine "$PACKAGE_DIR" 2>/dev/null || true

mkdir -p "$INSTALL_BIN_DIR" "$SUPPORT_DIR" "$LOCAL_BIN_DIR" "$CODEX_SKILLS_DIR" "$BACKUP_DIR"
chmod 700 "$INSTALL_BIN_DIR" "$SUPPORT_DIR" "$BACKUP_DIR" 2>/dev/null || true

candidate_binary="$INSTALL_BIN_DIR/huntdog.new.$$"
cp "$PAYLOAD_BINARY" "$candidate_binary"
chmod 755 "$candidate_binary"
xattr -d com.apple.quarantine "$candidate_binary" 2>/dev/null || true

echo "[1/4] 验证 HuntDog 核心依赖..."
candidate_version="$("$candidate_binary" --version)"
if [[ "$candidate_version" != *"$HUNTDOG_CORE_VERSION"* ]]; then
  echo "[错误] 核心版本不匹配: $candidate_version"
  exit 15
fi
echo "[OK] $candidate_version"

if [ -e "$INSTALL_BIN_DIR/huntdog" ]; then
  mv "$INSTALL_BIN_DIR/huntdog" "$BACKUP_DIR/huntdog.previous"
fi
mv "$candidate_binary" "$INSTALL_BIN_DIR/huntdog"

for alias_name in huntdog cyberunion-huntdog wechat-cli cyberunion-wechat-cli; do
  alias_path="$LOCAL_BIN_DIR/$alias_name"
  if [ -e "$alias_path" ] && [ ! -L "$alias_path" ]; then
    mv "$alias_path" "$BACKUP_DIR/$alias_name.previous"
  fi
  ln -sfn "$INSTALL_BIN_DIR/huntdog" "$alias_path"
done

echo "[2/4] 安装 Codex Skill..."
skill_candidate="$CODEX_SKILLS_DIR/.wechat-huntdog.new.$$"
cp -R "$PAYLOAD_SKILL" "$skill_candidate"
if [ -e "$SKILL_TARGET" ]; then
  mv "$SKILL_TARGET" "$BACKUP_DIR/wechat-huntdog.previous"
fi
mv "$skill_candidate" "$SKILL_TARGET"

echo "[3/4] 安装只读验收工具..."
cp "$PAYLOAD_VERIFY" "$SUPPORT_DIR/verify.sh"
chmod 755 "$SUPPORT_DIR/verify.sh"

echo "[4/4] 检查微信数据就绪状态（不会自动初始化）..."
if [ -n "${HUNTDOG_SKIP_DATA_CHECK:-}" ]; then
  "$SUPPORT_DIR/verify.sh" --skip-data
else
  "$SUPPORT_DIR/verify.sh"
fi

echo
echo "安装完成：核心已通过启动校验。"
echo "桌面验收报告: $HOME/Desktop/HuntDog安装验收.txt"
echo "如需初始化，必须先阅读报告并获得用户明确同意。"
