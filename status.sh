#!/usr/bin/env bash
# DeepTutor — status script
# Usage: status.sh [-n COUNT] [-i SECS]   (-n = run N samples then exit)
set -u

SKIP_ROOT_CHECK=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/deeptutor-env.sh"

DEEPTUTOR_API_PORT="${DEEPTUTOR_API_PORT:-8001}"
DEEPTUTOR_WEB_PORT="${DEEPTUTOR_WEB_PORT:-3782}"

SAMPLE_COUNT=0; INTERVAL=5
while getopts "n:i:h" opt; do
  case "${opt}" in
    n) SAMPLE_COUNT="${OPTARG}" ;;
    i) INTERVAL="${OPTARG}" ;;
    h) echo "Usage: $0 [-n COUNT] [-i SECS]"; exit 0 ;;
    *) exit 1 ;;
  esac
done

pid_of() { [[ -f "${PID_DIR}/$1.pid" ]] && cat "${PID_DIR}/$1.pid" || echo "--"; }
alive()  { local p; p="$(pid_of "$1")"; [[ "${p}" != "--" ]] && kill -0 "${p}" 2>/dev/null; }
mark()   { if [[ "$1" == "up" ]]; then echo -e "${FG_GREEN}${CHECK}${RESET}"; else echo -e "${FG_RED}${CROSS}${RESET}"; fi; }
stext()  { if [[ "$1" == "up" ]]; then echo -e "${FG_BRIGHT_GREEN}RUNNING${RESET}"; else echo -e "${FG_BRIGHT_RED}STOPPED${RESET}"; fi; }

while true; do
  printf '\033[2J\033[H'
  echo -e "  ${FG_BRIGHT_BLUE}${BOLD}DeepTutor — Service Status${RESET}"
  echo -e "  ${DIM}   ─────────────────────────────────────────────${RESET}"
  echo ""
  printf "  ${DIM}%-22s %-9s %-8s %s${RESET}\n" "Service" "Status" "PID" "Port"
  echo -e "  ${DIM}  ─────────────────────────────────────────────${RESET}"

  P="$(pid_of deeptutor)"
  printf "  %b %-18s %b %-8s :%s\n" "$(mark "$(alive deeptutor && echo up || echo down)")" "deeptutor" "$(stext "$(alive deeptutor && echo up || echo down)")" "${P}" "${DEEPTUTOR_API_PORT}"

  if port_in_use "${DEEPTUTOR_API_PORT}"; then
    printf "  %b %-18s %-9s %-8s :%s\n" "$(mark up)" "api" "UP" "-" "${DEEPTUTOR_API_PORT}"
  else
    printf "  %b %-18s %-9s %-8s :%s\n" "$(mark down)" "api" "DOWN" "-" "${DEEPTUTOR_API_PORT}"
  fi

  # Web frontend (next-server) negotiates its own port; detect it dynamically.
  WEB_PORT="$(ss -ltnp 2>/dev/null | grep -iE 'next-server|deeptutor_web' | grep -oE ':[0-9]+ ' | tr -d ' :' | head -1)"
  WEB_PORT="${WEB_PORT:-${DEEPTUTOR_WEB_PORT}}"
  if port_in_use "${WEB_PORT}"; then
    printf "  %b %-18s %-9s %-8s :%s\n" "$(mark up)" "web" "UP" "-" "${WEB_PORT}"
  else
    printf "  %b %-18s %-9s %-8s :%s\n" "$(mark down)" "web" "DOWN" "-" "${WEB_PORT}"
  fi

  echo ""
  if port_in_use "${DEEPTUTOR_API_PORT}"; then
    if curl -sf -m 3 "http://127.0.0.1:${DEEPTUTOR_API_PORT}/health" >/dev/null 2>&1; then
      echo -e "  ${FG_GREEN}${CHECK}${RESET} API health: OK"
    else
      echo -e "  ${FG_YELLOW}${WARN}${RESET} API port open (no /health endpoint — expected if not exposed)"
    fi
  fi

  echo ""
  if [[ "${SAMPLE_COUNT}" -gt 0 ]]; then
    SAMPLE_COUNT=$((SAMPLE_COUNT - 1))
    [[ "${SAMPLE_COUNT}" -eq 0 ]] && break
  fi
  sleep "${INTERVAL}"
done
