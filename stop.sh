#!/usr/bin/env bash
# DeepTutor — stop 1.6.5 test
set -u

SKIP_ROOT_CHECK=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(id -u)" -eq 0 ]]; then
  _DT_OWNER="$(stat -c '%U' "${SCRIPT_DIR}/data" 2>/dev/null)"
  if [[ -n "${_DT_OWNER}" && "${_DT_OWNER}" != "root" ]]; then
    [[ -d "${SCRIPT_DIR}/runtime" ]] && chown -R "${_DT_OWNER}" "${SCRIPT_DIR}/runtime" 2>/dev/null
    _DT_SELF="${SCRIPT_DIR}/$(basename "$0")"
    if command -v runuser >/dev/null 2>&1; then
      exec runuser -u "${_DT_OWNER}" -- "${_DT_SELF}" "$@"
    elif command -v sudo >/dev/null 2>&1; then
      exec sudo -u "${_DT_OWNER}" -- "${_DT_SELF}" "$@"
    else
      echo "WARN: cannot drop privileges to '${_DT_OWNER}' (no runuser/sudo)." >&2
    fi
  fi
fi

source "${SCRIPT_DIR}/deeptutor-env.sh"

echo -e "  ${FG_CYAN}Stopping DeepTutor...${RESET}"
echo ""

# Stop the deeptutor process
if [[ -f "${PID_DIR}/deeptutor.pid" ]]; then
  local_pid="$(cat "${PID_DIR}/deeptutor.pid" 2>/dev/null)"
  if [[ -n "${local_pid}" ]] && kill -0 "${local_pid}" 2>/dev/null; then
    echo -e "  ${FG_YELLOW}Stopping deeptutor (PID ${local_pid})...${RESET}"
    kill "${local_pid}" 2>/dev/null
    sleep 2
    if kill -0 "${local_pid}" 2>/dev/null; then
      kill -9 "${local_pid}" 2>/dev/null
    fi
  fi
  rm -f "${PID_DIR}/deeptutor.pid" 2>/dev/null || true
fi

# Kill any remaining deeptutor processes
pkill -f "deeptutor start" 2>/dev/null || true

# Free GPU device contexts
pgrep -f "llama-server|vllm|whisper|pyannote" | xargs sudo kill -9 2>/dev/null || true

# Free reserved ports
for port in 9001 4782; do
  if fuser -k "${port}/tcp" 2>/dev/null; then
    echo -e "  ${FG_CYAN}Freed port :${port}${RESET}"
  fi
done

echo -e "  ${FG_BRIGHT_GREEN}DeepTutor stopped${RESET}"
echo -n "Press Enter to return to menu "; read -r