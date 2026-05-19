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

# lib/preflight.bash — Pre-flight check helpers.
#
# Source this file; do not execute it directly.
# Depends on lib/log.bash (sourced automatically if not already loaded).
#
# Public API:
#   require_cmd  NAME   [hint]   — die if NAME is not on PATH
#   require_file PATH   [hint]   — die if PATH is not a regular file
#   require_dir  PATH   [hint]   — die if PATH is not a directory
#   require_env  VAR    [hint]   — die if environment variable VAR is unset/empty
#   preflight_summary            — print a coloured "All checks passed" line

[[ -n "${_PREFLIGHT_BASH_LOADED:-}" ]] && return 0
readonly _PREFLIGHT_BASH_LOADED=1

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.bash
source "${_LIB_DIR}/log.bash"

# ─────────────────────────────────────────────
# require_cmd <name> [install-hint]
# ─────────────────────────────────────────────
require_cmd() {
    local name="${1:?require_cmd: NAME is required}"
    local hint="${2:-}"
    if ! command -v "${name}" >/dev/null 2>&1; then
        local msg="Command '${name}' not found."
        [[ -n "${hint}" ]] && msg+=" ${hint}"
        die "${msg}"
    fi
    log_info "  ✓ ${name}"
}

# ─────────────────────────────────────────────
# require_file <path> [hint]
# ─────────────────────────────────────────────
require_file() {
    local path="${1:?require_file: PATH is required}"
    local hint="${2:-}"
    if [[ ! -f "${path}" ]]; then
        local msg="Required file not found: ${path}"
        [[ -n "${hint}" ]] && msg+=" ${hint}"
        die "${msg}"
    fi
    log_info "  ✓ ${path}"
}

# ─────────────────────────────────────────────
# require_dir <path> [hint]
# ─────────────────────────────────────────────
require_dir() {
    local path="${1:?require_dir: PATH is required}"
    local hint="${2:-}"
    if [[ ! -d "${path}" ]]; then
        local msg="Required directory not found: ${path}"
        [[ -n "${hint}" ]] && msg+=" ${hint}"
        die "${msg}"
    fi
    log_info "  ✓ ${path}"
}

# ─────────────────────────────────────────────
# require_env <VAR> [hint]
# ─────────────────────────────────────────────
require_env() {
    local var="${1:?require_env: VAR is required}"
    local hint="${2:-}"
    if [[ -z "${!var:-}" ]]; then
        local msg="Required environment variable '\$${var}' is not set."
        [[ -n "${hint}" ]] && msg+=" ${hint}"
        die "${msg}"
    fi
    log_info "  ✓ \$${var}=${!var}"
}

# ─────────────────────────────────────────────
# preflight_summary
# ─────────────────────────────────────────────
preflight_summary() {
    log_ok "All pre-flight checks passed."
}
