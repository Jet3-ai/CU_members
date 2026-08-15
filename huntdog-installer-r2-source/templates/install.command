#!/bin/bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

if /bin/bash "$ROOT_DIR/installer/install.sh"; then
  install_status=0
else
  install_status=$?
fi

if [ -z "${HUNTDOG_AGENT_INSTALL:-}" ] && [ -t 0 ]; then
  echo
  if [ "$install_status" -eq 0 ]; then
    read -r -p "安装流程已结束。按回车键关闭窗口。" _unused
  else
    read -r -p "安装未完成。请保留窗口内容并按回车键关闭。" _unused
  fi
fi

exit "$install_status"
