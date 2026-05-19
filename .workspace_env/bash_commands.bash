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
# bash_commands.bash — Master include for all custom shell commands.
#
# Source this file from setup_env.bash (or your ~/.bashrc directly).
# After sourcing, the following commands are available:
#
#   ── Workspace build ───────────────────────────────────────────
#   ws_setup [--clean]        Full ROS 2 workspace setup / rebuild
#   ws_build                  Run only the colcon build step
#   ws_clean                  Remove build artefacts and venv
#   ws_source                 Source the install overlay
#   ws_preflight              Run pre-flight checks only
#
#   ── Workspace navigation ──────────────────────────────────────
#   cdws                      cd to workspace root
#   cdwss                     cd to workspace root/src
#   cdwsb                     cd to workspace root/build
#   cdwsi                     cd to workspace root/install
#   cdwsl                     cd to workspace root/log
#   wsls                      List workspace root contents
#
#   ── ROS 2 helpers ─────────────────────────────────────────────
#   ros2_get_node_pid         Show PID(s) of ROS 2 node(s)
#   ros2_kill_node            Kill a node by name
#   ros2_kill_all_nodes       Kill all ROS 2 nodes
#
#   ── Shell utilities ───────────────────────────────────────────
#   kill_background_task      Interactively kill a background job
#   mkdircd                   mkdir -p + cd in one step
#
#   ── Logging (reusable in scripts) ────────────────────────────
#   log_info / log_ok / log_warn / log_error / die
#   log_init                  Initialise a log file
#   log_enable_trap           Install ERR trap that calls die()
#
#   ── Pre-flight (reusable in scripts) ─────────────────────────
#   require_cmd / require_file / require_dir / require_env
#
# All commands support -h / --help.

[[ -n "${_BASH_COMMANDS_LOADED:-}" ]] && return 0
readonly _BASH_COMMANDS_LOADED=1

# setup_env_dir is defined in setup_env.bash (fixed BASH_SOURCE at definition).
# Fallback: resolve from this file's own location for standalone sourcing.
if ! declare -f setup_env_dir >/dev/null 2>&1; then
    function setup_env_dir() {
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
    }
fi

# ── Workspace build functions ─────────────────────────────────────────────────
source "$(setup_env_dir)/lib/commands/setup_workspace.bash"

# ── Individual command modules ────────────────────────────────────────────────
source "$(setup_env_dir)/lib/commands/workspace_navigation.bash"
source "$(setup_env_dir)/lib/commands/ros2_helpers.bash"
source "$(setup_env_dir)/lib/commands/kill_background_task.bash"
source "$(setup_env_dir)/lib/commands/mkdircd.bash"

# ─────────────────────────────────────────────
# Add new command modules here.
# Create lib/commands/<name>.bash, source it,
# and add its public functions to the table above.
# ─────────────────────────────────────────────
