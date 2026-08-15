#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: smoke_test.sh /path/to/extracted-package" >&2
  exit 2
fi

package_dir="$(cd "$1" && pwd)"
test_home="$(mktemp -d -t huntdog-r2-smoke-home.XXXXXX)"
mkdir -p "$test_home/Desktop"

env \
  HOME="$test_home" \
  HUNTDOG_AGENT_INSTALL=1 \
  HUNTDOG_SKIP_DATA_CHECK=1 \
  "$package_dir/install.command"

test -x "$test_home/.huntdog/bin/huntdog"
test -L "$test_home/.local/bin/huntdog"
test -f "$test_home/.codex/skills/wechat-huntdog/SKILL.md"
test -x "$test_home/.huntdog/support/verify.sh"
grep -q '^INSTALL_OK=YES$' "$test_home/.huntdog/reports/latest-summary.txt"
grep -q '^DATA_STATE=NOT_CHECKED$' "$test_home/.huntdog/reports/latest-summary.txt"
"$test_home/.huntdog/bin/huntdog" --version
"$test_home/.huntdog/bin/huntdog" --help >/dev/null

# Reinstall to prove backup/update behavior does not break the runnable target.
env \
  HOME="$test_home" \
  HUNTDOG_AGENT_INSTALL=1 \
  HUNTDOG_SKIP_DATA_CHECK=1 \
  "$package_dir/install.command" >/dev/null
"$test_home/.huntdog/bin/huntdog" --version >/dev/null

echo "HUNTDOG_R2_SMOKE_OK"
echo "SMOKE_HOME=$test_home"
