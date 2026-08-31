#!/usr/bin/env bash
# Shared environment for the DeepTutor app-service scripts (start/stop/status/perf).
# Source this AFTER setting SKIP_ROOT_CHECK=1 in the calling script.
#
# DeepTutor is an application service that may be launched from the HaoWise menu
# either as root (sudo) or as the user. The shared HaoWise runtime/ tree and the
# /tmp start lock can end up owned by root, which then breaks a later user-run
# (PID file / lock writes fail with Permission denied and lifecycle tracking is
# lost). To stay reliable in both cases we keep all lifecycle files under the
# project itself, which is owned by the user.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAOWISE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${HAOWISE_DIR}/lib/common.sh"

PRODUCT_LABEL="deeptutor"

DEEPTUTOR_BIN="${DEEPTUTOR_BIN:-/usr/local/miniforge3/bin/deeptutor}"
# DEEPTUTOR_HOME is the workspace ROOT. DeepTutor stores all data under
# <home>/data (see deeptutor/runtime/home.py: get_runtime_data_root = home/"data").
# Pointing this at <root>/data would nest a second empty workspace at
# <root>/data/data and lose the real history/models — so it MUST be the project
# root itself. The real store is therefore <root>/data (the existing tree).
DEEPTUTOR_HOME="${DEEPTUTOR_HOME:-${SCRIPT_DIR}}"
DEEPTUTOR_API_PORT="${DEEPTUTOR_API_PORT:-8001}"
DEEPTUTOR_WEB_PORT="${DEEPTUTOR_WEB_PORT:-3782}"
export DEEPTUTOR_HOME
# Self-sufficient PATH: the menu may launch these scripts as root and the
# privilege-drop re-exec (runuser) inherits root's (possibly minimal) PATH,
# which can lack /usr/sbin where fuser/ss/pgrep live. Pin a complete PATH so
# stop/status/perf work no matter how the script is invoked.
export PATH="/usr/local/miniforge3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# Self-contained runtime dir under the project (user-owned). Overrides the shared
# HaoWise runtime/ so PID/log files never collide with root-owned artifacts.
DT_RUNTIME="${SCRIPT_DIR}/runtime"
PID_DIR="${DT_RUNTIME}/pids"
LOG_DIR="${DT_RUNTIME}/logs"
mkdir -p "${PID_DIR}" "${LOG_DIR}" 2>/dev/null || true
export PID_DIR LOG_DIR

# Project-local stale-instance guard (replaces the /tmp root-owned lock).
guard_stale_instance() {
  local product="$1"
  local lock="${DT_RUNTIME}/${product}-start.lock"
  if [[ -f "${lock}" ]]; then
    local old_pid; old_pid="$(cat "${lock}" 2>/dev/null)"
    if [[ -n "${old_pid}" ]] && kill -0 "${old_pid}" 2>/dev/null; then
      if grep -q "my-deeptutor/start.sh" "/proc/${old_pid}/cmdline" 2>/dev/null; then
        printf "  ${FG_BRIGHT_MAGENTA}${ARROW}${RESET} killing stale %s start.sh (PID %d)\n" "${product}" "${old_pid}" >&2
        kill -9 "${old_pid}" 2>/dev/null; sleep 1
      fi
    fi
  fi
  rm -f "${lock}" 2>/dev/null || true
  printf "%s" "$$" > "${lock}" 2>/dev/null || true
}
