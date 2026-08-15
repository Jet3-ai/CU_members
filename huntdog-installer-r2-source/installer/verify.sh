#!/bin/bash
set -u

HUNTDOG_ROOT="${HUNTDOG_HOME:-$HOME/.huntdog}"
HUNTDOG_BIN="$HUNTDOG_ROOT/bin/huntdog"
REPORT_DIR="$HUNTDOG_ROOT/reports"
PRIVATE_DIR="$REPORT_DIR/private"
SUMMARY_REPORT="$REPORT_DIR/latest-summary.txt"
DESKTOP_DIR="${HUNTDOG_DESKTOP_DIR:-$HOME/Desktop}"
DESKTOP_REPORT="$DESKTOP_DIR/HuntDog安装验收.txt"

mkdir -p "$PRIVATE_DIR"
chmod 700 "$REPORT_DIR" "$PRIVATE_DIR" 2>/dev/null || true

if [ ! -x "$HUNTDOG_BIN" ]; then
  echo "INSTALL_OK=NO" > "$SUMMARY_REPORT"
  echo "[错误] HuntDog 核心不存在或不可执行。" >> "$SUMMARY_REPORT"
  exit 20
fi

core_version="$("$HUNTDOG_BIN" --version 2>&1)"
if [ "$?" -ne 0 ]; then
  echo "INSTALL_OK=NO" > "$SUMMARY_REPORT"
  echo "[错误] HuntDog 核心启动失败。" >> "$SUMMARY_REPORT"
  exit 21
fi

database_discovery="NOT_CHECKED"
keys_state="NOT_CHECKED"
decryption_context="NOT_CHECKED"
query_state="NOT_CHECKED"
data_state="NOT_CHECKED"
coverage_note="未运行微信数据检查"

if [ "${1:-}" != "--skip-data" ]; then
  doctor_json="$PRIVATE_DIR/doctor-latest.json"
  capabilities_json="$PRIVATE_DIR/capabilities-latest.json"
  query_json="$PRIVATE_DIR/query-latest.json"

  echo "[验收] 发现数据库、读取密钥并检查解密覆盖..."
  if "$HUNTDOG_BIN" doctor --format json > "$doctor_json" 2> "$PRIVATE_DIR/doctor-latest.err"; then
    if grep -q '"auto_detected_db_dir": null' "$doctor_json"; then
      database_discovery="NO"
    elif grep -q '"auto_detected_db_dir":' "$doctor_json"; then
      database_discovery="YES"
    else
      database_discovery="UNKNOWN"
    fi

    if grep -q '"keys_exists": true' "$doctor_json" && ! grep -Eq '"key_count": (0|null)' "$doctor_json"; then
      keys_state="YES"
    else
      keys_state="NO"
    fi

    if grep -q '"app_context_ready": true' "$doctor_json"; then
      decryption_context="YES"
    else
      decryption_context="NO"
    fi
  else
    database_discovery="UNKNOWN"
    keys_state="UNKNOWN"
    decryption_context="NO"
  fi

  echo "[验收] 读取能力矩阵并执行零命中消息查询..."
  if [ "$decryption_context" = "YES" ] && "$HUNTDOG_BIN" capabilities --format json > "$capabilities_json" 2> "$PRIVATE_DIR/capabilities-latest.err"; then
    chat_available="NO"
    full_coverage="NO"
    if grep -q '"chat_history": true' "$capabilities_json"; then
      chat_available="YES"
    fi
    if grep -q '"chat_history_full_coverage": true' "$capabilities_json"; then
      full_coverage="YES"
    fi

    if [ "$chat_available" = "YES" ] && "$HUNTDOG_BIN" search "__HUNTDOG_R2_HEALTHCHECK_8F4B3A__" --limit 1 --format json > "$query_json" 2> "$PRIVATE_DIR/query-latest.err"; then
      query_state="YES"
      if [ "$full_coverage" = "YES" ]; then
        data_state="FULL_READY"
        coverage_note="当前发现的普通消息库均可解密"
      else
        data_state="PARTIAL_READY"
        coverage_note="聊天可查询，但普通消息库并非全覆盖"
      fi
    else
      query_state="NO"
      data_state="DATA_UNAVAILABLE"
      coverage_note="数据库上下文可建立，但消息查询未通过"
    fi
  elif [ "$database_discovery" = "NO" ] || [ "$keys_state" = "NO" ]; then
    query_state="NO"
    data_state="NEEDS_INITIALIZATION"
    coverage_note="核心已安装，尚未完成数据库发现或密钥准备"
  else
    query_state="NO"
    data_state="DATA_UNAVAILABLE"
    coverage_note="已有部分本机状态，但解密上下文不可用"
  fi

  chmod 600 "$PRIVATE_DIR"/* 2>/dev/null || true
fi

cat > "$SUMMARY_REPORT" <<EOF
CyberUnion HuntDog 安装验收
========================================
INSTALL_OK=YES
CORE_VERSION=$core_version
DATABASE_DISCOVERY=$database_discovery
KEYS=$keys_state
DECRYPTION_CONTEXT=$decryption_context
QUERY=$query_state
DATA_STATE=$data_state
COVERAGE_NOTE=$coverage_note

判读：
- INSTALL_OK=YES 代表软件已经正确安装并能启动。
- FULL_READY 才代表当前发现的普通消息库全覆盖。
- PARTIAL_READY 可以分析，但不得声称全量、精确总数或不存在某类反馈。
- NEEDS_INITIALIZATION 代表需要用户确认后再进行微信数据库/密钥初始化，不是安装失败。

隐私：原始 doctor/capabilities 诊断仅保存在本机 ~/.huntdog/reports/private，不要上传聊天、密钥或配置。
EOF
chmod 600 "$SUMMARY_REPORT"

if [ -z "${HUNTDOG_NO_DESKTOP_REPORT:-}" ] && [ -d "$DESKTOP_DIR" ]; then
  cp "$SUMMARY_REPORT" "$DESKTOP_REPORT"
fi

cat "$SUMMARY_REPORT"
