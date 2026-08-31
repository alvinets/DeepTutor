#!/usr/bin/env bash
# DeepTutor — stop script (application service)
set -u

SKIP_ROOT_CHECK=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/deeptutor-env.sh"

print_banner() {
  echo ""
  echo -e "${FG_BLUE}${BOLD}   Stopping DeepTutor${RESET}"
  echo ""
}

print_banner

# 1) Graceful SIGTERM to the supervised parent; the launcher forwards the
#    signal to its backend + frontend children (see deeptutor runtime launcher).
stop_one "deeptutor" "-"

# 2) Safety sweep for orphaned backend/web processes still bound to our ports.
sweep_port() {
  local p="$1"
  if port_in_use "${p}"; then
    echo -e "  ${FG_YELLOW}${BULLET}${RESET} sweeping orphaned process on :${p}"
    fuser -k "${p}/tcp" 2>/dev/null || true
  }
}
sweep_port "${DEEPTUTOR_API_PORT}"
sweep_port "${DEEPTUTOR_WEB_PORT}"

# 3) Last-resort: kill any supervisor / frontend still bound to this runtime home.
pkill -f "deeptutor start --home" 2>/dev/null || true
pkill -f "next-server" 2>/dev/null || true

echo ""
echo -e "  ${FG_BRIGHT_GREEN}●${RESET} DeepTutor services stopped"
