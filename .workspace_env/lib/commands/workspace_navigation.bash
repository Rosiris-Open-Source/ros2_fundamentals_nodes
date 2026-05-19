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

# lib/commands/workspace_navigation.bash — Quick-cd shortcuts for the ROS 2 workspace.
#
# All commands use setup_env_workspace_dir (defined in setup_env.bash) so the
# workspace root is always inferred correctly, regardless of $PWD.
#
# Commands:
#   cdws     cd to workspace root
#   cdwss    cd to workspace root /src
#   cdwsb    cd to workspace root /build
#   cdwsi    cd to workspace root /install
#   cdwsl    cd to workspace root /log
#   wsls     list workspace root contents

[[ -n "${_CMD_WS_NAV_LOADED:-}" ]] && return 0
readonly _CMD_WS_NAV_LOADED=1

# ─────────────────────────────────────────────
# Internal: resolve workspace root, with guard
# ─────────────────────────────────────────────
_ws_nav_root() {
    if ! declare -f setup_env_workspace_dir >/dev/null 2>&1; then
        log_error "setup_env_workspace_dir is not defined." \
                  "Source setup_env.bash before using workspace navigation."
        return 1
    fi
    setup_env_workspace_dir
}

# Internal: cd to a sub-path of the workspace root, with clear errors
_ws_cd() {
    local subpath="${1:-}"   # e.g. "src", "build", "" for root
    local label="${2:-workspace root}"

    local root
    root="$(_ws_nav_root)" || return 1
    local target="${root}${subpath:+/${subpath}}"

    if [[ ! -d "${target}" ]]; then
        log_error "Directory does not exist: ${target}"
        log_info  "Run 'ws_setup' to build the workspace first."
        return 1
    fi

    cd "${target}" || { log_error "cd failed: ${target}"; return 1; }
}

# ─────────────────────────────────────────────
# cdws — workspace root
# ─────────────────────────────────────────────
cdws() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: cdws"
        echo "  cd to the workspace root ($(setup_env_workspace_dir 2>/dev/null || echo '<workspace>'))."
        return 0; }
    _ws_cd "" "workspace root"
}

# ─────────────────────────────────────────────
# cdwss — src/
# ─────────────────────────────────────────────
cdwss() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: cdwss"
        echo "  cd to <workspace>/src"
        return 0; }
    _ws_cd "src" "src"
}

# ─────────────────────────────────────────────
# cdwsb — build/
# ─────────────────────────────────────────────
cdwsb() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: cdwsb"
        echo "  cd to <workspace>/build"
        return 0; }
    _ws_cd "build" "build"
}

# ─────────────────────────────────────────────
# cdwsi — install/
# ─────────────────────────────────────────────
cdwsi() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: cdwsi"
        echo "  cd to <workspace>/install"
        return 0; }
    _ws_cd "install" "install"
}

# ─────────────────────────────────────────────
# cdwsl — log/
# ─────────────────────────────────────────────
cdwsl() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: cdwsl"
        echo "  cd to <workspace>/log"
        return 0; }
    _ws_cd "log" "log"
}

# ─────────────────────────────────────────────
# wsls — list workspace root
# ─────────────────────────────────────────────
wsls() {
    [[ "${1:-}" =~ ^(-h|--help)$ ]] && {
        echo "Usage: wsls"
        echo "  List the contents of the workspace root."
        return 0; }

    local root
    root="$(_ws_nav_root)" || return 1
    echo -e "${TERMINAL_COLOR_CYAN}Workspace: ${root}${TERMINAL_COLOR_NC}"
    ls -la "${root}"
}
