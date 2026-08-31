#!/usr/bin/env bash
# DeepTutor — AI tutoring & knowledge platform (application service)
# CPU-only, no root required (see AGENTS.md). Mirrors the mineru/dify app-service pattern.
set -u

SKIP_ROOT_CHECK=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DeepTutor's Python deps (typer, etc.) live in the runtime-home owner's user
# site-packages, so the service must run as that user — not root. If launched
# as root, drop to the data dir's owner before doing anything else.
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
      echo "WARN: cannot drop privileges to '${_DT_OWNER}' (no runuser/sudo); typer deps are user-only." >&2
    fi
  fi
fi

source "${SCRIPT_DIR}/deeptutor-env.sh"

guard_stale_instance "${PRODUCT_LABEL}"

print_banner() {
  echo ""
  echo -e "${FG_BLUE}${BOLD}   DeepTutor — AI Tutoring & Knowledge Platform${RESET}"
  echo -e "${DIM}   ───────────────────────────────────────────────────${RESET}"
  echo ""
}

prepare_runtime
print_banner

if [[ ! -x "${DEEPTUTOR_BIN}" ]]; then
  fatal "deeptutor binary not found or not executable: ${DEEPTUTOR_BIN}"
fi
if [[ ! -d "${DEEPTUTOR_HOME}" ]]; then
  fatal "DEEPTUTOR_HOME not found: ${DEEPTUTOR_HOME}"
fi

echo -e "  ${FG_CYAN}Runtime home:${RESET} ${DEEPTUTOR_HOME}"
echo -e "  ${FG_CYAN}API port:${RESET}     :${DEEPTUTOR_API_PORT}"
echo -e "  ${FG_CYAN}Web port:${RESET}     :${DEEPTUTOR_WEB_PORT}"
echo ""
echo -e "  ${FG_CYAN}${BULLET}${RESET} launching backend + frontend (supervised process) ..."
echo ""

# If the API port is already bound (e.g. an orphaned prior launch), adopt the
# existing PID instead of spawning a duplicate backend.
port_str="${DEEPTUTOR_API_PORT}"
start_proc deeptutor "${DEEPTUTOR_BIN}" start --home "${DEEPTUTOR_HOME}"

# Readiness: wait for the API port (cold start of uvicorn + Next.js can take a bit).
ready=0
for _ in $(seq 1 45); do
  if port_in_use "${DEEPTUTOR_API_PORT}"; then ready=1; break; fi
  sleep 1
done

echo ""
if [[ "${ready}" == "1" ]]; then
  echo -e "  ${FG_BRIGHT_GREEN}${CHECK}${RESET} DeepTutor API is listening on :${DEEPTUTOR_API_PORT}"
else
  echo -e "  ${FG_YELLOW}${WARN}${RESET} API port :${DEEPTUTOR_API_PORT} not yet up — see ${LOG_DIR}/deeptutor.log"
fi
