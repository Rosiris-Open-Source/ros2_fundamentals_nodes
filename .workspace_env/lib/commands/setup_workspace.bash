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

# setup_workspace.bash — ROS 2 workspace build functions.
#
# ── Two modes ────────────────────────────────────────────────────────────────
#
#   Sourced (from bash_commands.bash or interactively):
#       source setup_workspace.bash
#       ws_setup          # full idempotent setup
#       ws_setup --clean  # clean then full setup
#       ws_build          # only the colcon build step
#       ws_source         # only source the install overlay
#
#   Executed directly:
#       ./setup_workspace.bash [--clean] [--help]
#
# ── Configuration (override before sourcing or calling) ──────────────────────
#
#   WS_DIR            workspace root   (default: directory of this file)
#   WS_REPOS_FILE     .repos input     (default: ${WS_DIR}/.repos/html.repos)
#   WS_HAND_DETECTOR  python pkg path  (default: ${WS_DIR}/src/hand_detector)
#   WS_LOG_DIR        log directory    (default: ${WS_DIR}/log)
#   WS_VENV_DIR       venv location    (default: ${WS_DIR}/.venv)
#
# ─────────────────────────────────────────────────────────────────────────────

[[ -n "${_SETUP_WORKSPACE_LOADED:-}" ]] && return 0
readonly _SETUP_WORKSPACE_LOADED=1

# ─────────────────────────────────────────────
# Bootstrap: resolve paths, load libs
# setup_env_dir is provided by setup_env.bash.
# Fallback for standalone/direct execution.
# ─────────────────────────────────────────────
if ! declare -f setup_env_dir >/dev/null 2>&1; then
    function setup_env_dir() {
        # lib/commands/ → lib/ → .workspace_env/
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null && pwd)"
    }
    function setup_env_workspace_dir() {
        echo "$(dirname "$(setup_env_dir)")"
    }
fi

# shellcheck source=lib/log.bash
source "$(setup_env_dir)/lib/log.bash"
# shellcheck source=lib/preflight.bash
source "$(setup_env_dir)/lib/preflight.bash"

# ─────────────────────────────────────────────
# Default configuration (all overridable)
# WS_DIR defaults to the workspace root (parent
# of .workspace_env/), matching setup_env_workspace_dir.
# ─────────────────────────────────────────────
: "${WS_DIR:=$(setup_env_workspace_dir)}"
: "${WS_REPOS_FILE:=${WS_DIR}/.repos/html.repos}"
: "${WS_HAND_DETECTOR:=${WS_DIR}/src/hand_detector}"
: "${WS_LOG_DIR:=${WS_DIR}/log}"
: "${WS_VENV_DIR:=${WS_DIR}/.venv}"

# ─────────────────────────────────────────────
# Internal: print banner
# ─────────────────────────────────────────────
_ws_banner() {
    local mode="${1:-incremental}"
    echo -e "${TERMINAL_COLOR_WHITE}"
    echo "═══════════════════════════════════════════════"
    echo "  ROS 2 Workspace Setup"
    echo "  Workspace : ${WS_DIR}"
    echo "  Log       : ${LOG_FILE:-<console only>}"
    echo "  Mode      : ${mode}"
    echo "═══════════════════════════════════════════════"
    echo -e "${TERMINAL_COLOR_NC}"
}

# ─────────────────────────────────────────────
# ws_preflight — verify all required tools and paths
# ─────────────────────────────────────────────
ws_preflight() {
    log_info "Running pre-flight checks..."

    require_cmd python3  "Install with: sudo apt install python3"
    require_cmd pip3     "Install with: sudo apt install python3-pip"
    require_cmd vcs      "Install with: pip3 install vcstool"
    require_cmd rosdep   "Install with: sudo apt install python3-rosdep"
    require_cmd colcon   "Install with: sudo apt install python3-colcon-common-extensions"

    require_file "${WS_REPOS_FILE}"
    require_dir  "${WS_HAND_DETECTOR}"

    preflight_summary
}

# ─────────────────────────────────────────────
# ws_clean — remove build artefacts and venv
# ─────────────────────────────────────────────
ws_clean() {
    log_info "Cleaning workspace artefacts..."

    # Deactivate venv if it is currently active
    if [[ "${VIRTUAL_ENV:-}" == "${WS_VENV_DIR}" ]]; then
        log_warn "Deactivating active virtual environment before clean."
        # shellcheck disable=SC1090
        deactivate 2>/dev/null || true
    fi

    local dirs=(build install .venv)
    for d in "${dirs[@]}"; do
        local target="${WS_DIR}/${d}"
        if [[ -d "${target}" ]]; then
            rm -rf "${target}"
            log_info "  Removed: ${target}"
        else
            log_info "  Not present (skipped): ${target}"
        fi
    done

    # Rotate the log directory: remove old logs, recreate, re-init
    if [[ -d "${WS_LOG_DIR}" ]]; then
        echo "  [INFO]  Removing: ${WS_LOG_DIR}"
        rm -rf "${WS_LOG_DIR}"
    fi
    log_init "${WS_LOG_DIR}" "setup_workspace"
    log_ok "Clean complete."
}

# ─────────────────────────────────────────────
# ws_system_update — apt update + upgrade
# ─────────────────────────────────────────────
ws_system_update() {
    log_info "Updating and upgrading system packages..."
    sudo apt update   >> "${LOG_FILE:-/dev/null}" 2>&1 || die "apt update failed."
    sudo apt upgrade -y >> "${LOG_FILE:-/dev/null}" 2>&1 || die "apt upgrade failed."
    log_ok "System packages up to date."
}

# ─────────────────────────────────────────────
# ws_import_repos — vcs import
# ─────────────────────────────────────────────
ws_import_repos() {
    log_info "Importing repositories from ${WS_REPOS_FILE}..."
    # --workers 1: avoids race conditions with some vcs back-ends
    vcs import \
        --input "${WS_REPOS_FILE}" \
        --workers 1 \
        "${WS_DIR}/" >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || die "vcs import failed."
    log_ok "Repositories imported."
}

# ─────────────────────────────────────────────
# ws_venv_setup — create / reuse virtual environment
# ─────────────────────────────────────────────
ws_venv_setup() {
    log_info "Setting up Python virtual environment at ${WS_VENV_DIR}..."
    if [[ -d "${WS_VENV_DIR}" ]]; then
        log_info "  Virtual environment already exists — reusing."
    else
        python3 -m venv "${WS_VENV_DIR}" --system-site-packages \
            >> "${LOG_FILE:-/dev/null}" 2>&1 \
            || die "Failed to create virtual environment."
        log_info "  Virtual environment created."
    fi
    # shellcheck source=/dev/null
    source "${WS_VENV_DIR}/bin/activate" \
        || die "Failed to activate virtual environment."
    log_ok "Virtual environment active: $(python --version)"
}

# ─────────────────────────────────────────────
# ws_pip_install — install Python dependencies
# ─────────────────────────────────────────────
ws_pip_install() {
    log_info "Installing Python dependencies..."
    pip install --upgrade pip >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || die "pip upgrade failed."
    pip install -e "${WS_HAND_DETECTOR}" >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || die "Failed to install hand_detector package."
    log_ok "Python dependencies installed."
}

# ─────────────────────────────────────────────
# ws_rosdep_install — rosdep init (if needed) + install
# ─────────────────────────────────────────────
ws_rosdep_install() {
    log_info "Installing ROS dependencies via rosdep..."

    if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
        log_info "  rosdep not yet initialised — running rosdep init..."
        sudo rosdep init >> "${LOG_FILE:-/dev/null}" 2>&1 \
            || die "rosdep init failed."
    fi

    rosdep update >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || log_warn "rosdep update encountered issues — continuing anyway."

    rosdep install \
        --from-paths "${WS_DIR}/src" \
        --ignore-src \
        -r -y >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || die "rosdep install failed."

    log_ok "ROS dependencies installed."
}

# ─────────────────────────────────────────────
# ws_build — colcon build
# ─────────────────────────────────────────────
ws_build() {
    log_info "Building ROS 2 workspace with colcon..."
    python -m colcon \
        --log-base "${WS_LOG_DIR}/colcon" \
        build \
        --symlink-install \
        --base-paths   "${WS_DIR}" \
        --build-base   "${WS_DIR}/build" \
        --install-base "${WS_DIR}/install" \
        >> "${LOG_FILE:-/dev/null}" 2>&1 \
        || die "colcon build failed."
    log_ok "Workspace built successfully."
}

# ─────────────────────────────────────────────
# ws_source — source the install overlay
# ─────────────────────────────────────────────
ws_source() {
    local overlay="${WS_DIR}/install/setup.bash"
    if [[ -f "${overlay}" ]]; then
        # shellcheck source=/dev/null
        source "${overlay}"
        log_ok "Sourced install overlay: ${overlay}"
    else
        log_warn "install/setup.bash not found — workspace may not be fully sourced."
    fi
}

# ─────────────────────────────────────────────
# ws_setup — full orchestration (public entrypoint)
# ─────────────────────────────────────────────
# Usage: ws_setup [--clean]
ws_setup() {
    local do_clean=false
    for arg in "$@"; do
        case "${arg}" in
            --clean|-c) do_clean=true ;;
            --help|-h)
                echo "Usage: ws_setup [--clean|-c] [--help|-h]"
                echo "  --clean   Remove build/, install/, .venv/ then rebuild."
                return 0
                ;;
            *) die "Unknown argument: '${arg}'. Use --clean or --help." ;;
        esac
    done

    # No set -euo pipefail here.
    # When sourced into an interactive shell, set -e applies to the ENTIRE
    # shell session — not just this function. Any non-zero exit after ws_setup
    # returns (even a harmless grep miss) would kill the terminal.
    # All error handling is explicit: every step uses  || die "..."
    # set -euo pipefail is applied only in the direct-execution entrypoint below,
    # where it runs safely in its own subshell.

    log_init "${WS_LOG_DIR}" "setup_workspace"
    log_enable_trap

    if ${do_clean}; then
        _ws_banner "CLEAN + rebuild"
        ws_clean
    else
        _ws_banner "Incremental (safe to re-run)"
    fi

    ws_preflight
    ws_system_update
    ws_import_repos
    ws_venv_setup
    ws_pip_install
    ws_rosdep_install
    ws_build
    ws_source

    log_disable_trap

    echo ""
    echo -e "${TERMINAL_COLOR_WHITE}"
    echo "═══════════════════════════════════════════════"
    echo "  Setup complete!"
    echo "═══════════════════════════════════════════════"
    echo -e "${TERMINAL_COLOR_NC}"
    echo ""
    log_info "To activate the workspace in a new shell:"
    echo -e "    source ${WS_VENV_DIR}/bin/activate"
    echo -e "    source ${WS_DIR}/install/setup.bash"
    echo ""
    log_info "Full log: ${LOG_FILE}"
}

# ─────────────────────────────────────────────
# Direct-execution entrypoint
# When run as a script (not sourced), delegate to ws_setup.
# set -euo pipefail is safe here: the script runs in its own subshell
# so it cannot affect the caller's shell session.
# ─────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    IFS=$'\n\t'
    ws_setup "$@"
fi
