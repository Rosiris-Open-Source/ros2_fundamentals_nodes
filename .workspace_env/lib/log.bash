#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Authors: Manuel Muth

# lib/log.bash — Structured logging helpers.
#
# Source this file; do not execute it directly.
#
# Public API:
#   log_info  "message"   — cyan  [INFO]
#   log_ok    "message"   — green [OK]
#   log_warn  "message"   — yellow [WARN]
#   log_error "message"   — red   [ERROR]  (writes to stderr)
#   die       "message"   — log_error, then exit 1
#
# File logging:
#   Set LOG_FILE=/path/to/file before sourcing (or at any point before
#   calling a log function).  When set, a plain-text copy of every
#   message is appended to that file with a timestamp prefix.
#   Example:
#       LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
#       source lib/log.bash
#
# Trap helper:
#   log_enable_trap   — install an ERR trap that calls die() with file/line info
#   log_disable_trap  — remove the ERR trap

[[ -n "${_LOG_BASH_LOADED:-}" ]] && return 0
readonly _LOG_BASH_LOADED=1

# Ensure colours are available
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/colors.bash
source "${_LIB_DIR}/colors.bash"

# ─────────────────────────────────────────────
# Internal write helper
# ─────────────────────────────────────────────
_log_write() {
    local level="$1"
    local color="$2"
    local is_stderr="$3"
    shift 3
    local msg="$*"
    local timestamp
    timestamp="$(date '+%H:%M:%S')"
    local formatted="${color}[${level}]${TERMINAL_COLOR_NC}  ${msg}"

    if [[ "${is_stderr}" == "1" ]]; then
        echo -e "${formatted}" >&2
    else
        echo -e "${formatted}"
    fi

    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}][${level}] ${msg}" >> "${LOG_FILE}"
    fi
}

# ─────────────────────────────────────────────
# Public logging functions
# ─────────────────────────────────────────────
log_info()  { _log_write "INFO " "${TERMINAL_COLOR_CYAN}"   "0" "$@"; }
log_ok()    { _log_write "OK   " "${TERMINAL_COLOR_GREEN}"  "0" "$@"; }
log_warn()  { _log_write "WARN " "${TERMINAL_COLOR_YELLOW}" "0" "$@"; }
log_error() { _log_write "ERROR" "${TERMINAL_COLOR_RED}"    "1" "$@"; }

die() {
    log_error "$@"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_error "See full log: ${LOG_FILE}"
    fi
    exit 1
}

# ─────────────────────────────────────────────
# Trap helpers
# ─────────────────────────────────────────────
_log_err_trap() {
    # Disable ourselves immediately — prevents the trap firing again in the
    # caller's shell if we were sourced into an interactive session.
    log_disable_trap
    die "Unexpected error on line ${BASH_LINENO[0]} in ${BASH_SOURCE[1]:-unknown}." \
        "Failed command: ${BASH_COMMAND}"
}

log_enable_trap()  { trap '_log_err_trap' ERR; }
log_disable_trap() { trap - ERR; }

# ─────────────────────────────────────────────
# Log file initialisation helper
# ─────────────────────────────────────────────
# Usage: log_init "/path/to/logdir" "my_session"
# Sets LOG_FILE and writes an opening banner.
log_init() {
    local log_dir="${1:?log_init requires a directory argument}"
    local session_name="${2:-session}"
    mkdir -p "${log_dir}"
    LOG_FILE="${log_dir}/${session_name}_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "════════════════════════════════════════════"
        echo "  Log started : $(date)"
        echo "  Session     : ${session_name}"
        echo "  Host        : $(hostname)"
        echo "════════════════════════════════════════════"
    } >> "${LOG_FILE}"
    log_info "Logging to: ${LOG_FILE}"
}
