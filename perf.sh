#!/usr/bin/env bash
# DeepTutor — perf script
# Usage: perf.sh [-n COUNT] [-i SECS]
set -u

SKIP_ROOT_CHECK=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/deeptutor-env.sh"

SAMPLE_COUNT=0; INTERVAL=3
while getopts "n:i:h" opt; do
  case "${opt}" in
    n) SAMPLE_COUNT="${OPTARG}" ;;
    i) INTERVAL="${OPTARG}" ;;
    h) echo "Usage: $0 [-n COUNT] [-i SECS]"; exit 0 ;;
    *) exit 1 ;;
  esac
done

print_banner() {
  echo -e "${FG_BLUE}${BOLD}   DeepTutor — AI Tutoring & Knowledge Platform${RESET}"
}

SERVICE="deeptutor"
sample=0
while true; do
  ((sample++))
  [[ ${sample} -gt 1 ]] && { sleep "${INTERVAL}"; clear 2>/dev/null || true; }

  print_banner
  echo -e "${BOLD}   DeepTutor Performance${RESET} ${DIM}#${sample}${RESET}"
  echo ""

  printf "  %-1s %-18s %-6s %-6s\n" "${BULLET}" "SERVICE" "CPU%" "MEM"
  echo -e "${DIM}  ────────────────────────────────${RESET}"

  pid=""; pidfile="${PID_DIR}/${SERVICE}.pid"
  [[ -f "${pidfile}" ]] && pid=$(cat "${pidfile}")
  [[ -n "${pid}" ]] && ! pid_running "${pid}" && pid=""
  cpu="-"; mem="-"
  [[ -n "${pid}" ]] && cpu=$(get_cpu "${pid}") && mem=$(get_mem "${pid}")
  printf "  %-1s %-18s %-6s %-6s\n" "${BULLET}" "deeptutor" "${cpu:-"-"}" "${mem:-"-"}"

  echo ""
  echo -e "${BOLD}System Resources${RESET}"
  free -h | head -3
  echo ""
  echo -e "Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"

  [[ ${SAMPLE_COUNT} -gt 0 && ${sample} -ge ${SAMPLE_COUNT} ]] && break
done
