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

# setup_env.bash — Interactive shell environment bootstrap.
#
# Add to your ~/.bashrc once:
#     source /path/to/.workspace_env/setup_env.bash
# …or just run: source setup_env.bash
# The script will add itself to ~/.bashrc automatically on first run.
#
# ── Public functions exposed after sourcing ──────────────────────────────────
#   setup_env_dir             → absolute path of this .workspace_env/ directory
#   setup_env_workspace_dir   → absolute path of the workspace root (parent of env dir)
#
# ── What setup_env() does ────────────────────────────────────────────────────
#   1. Registers colcon bash completion
#   2. Bootstraps ~/.bashrc (idempotent, guarded)
#   3. Sets global gitignore
#   4. Sources bash_aliases.bash
#   5. Sources bash_commands.bash  (→ lib/* + setup_workspace.bash)
#   6. Sources prompt/git_prompt.bash
#   7. Sources the ROS 2 install overlay if present

[[ -n "${_SETUP_ENV_LOADED:-}" ]] && return 0
readonly _SETUP_ENV_LOADED=1

# ─────────────────────────────────────────────
# Path helpers — defined here so every file
# sourced below can call setup_env_dir.
# BASH_SOURCE[0] is fixed at definition time.
# ─────────────────────────────────────────────
function setup_env_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
}

function setup_env_workspace_dir() {
    echo "$(dirname "$(setup_env_dir)")"
}

# ─────────────────────────────────────────────
# setup_global_gitignore
# ─────────────────────────────────────────────
function setup_global_gitignore() {
    local current desired
    current="$(git config --global --get core.excludesFile 2>/dev/null || echo "")"
    desired="$(setup_env_dir)/.global_gitignore"
    if [[ "${current}" != "${desired}" ]]; then
        git config --global core.excludesFile "${desired}"
    fi
}

# ─────────────────────────────────────────────
# setup_bashrc_bootstrap
# Appends a source line to ~/.bashrc exactly once,
# guarded by a touch-file so re-runs are no-ops.
# ─────────────────────────────────────────────
function setup_bashrc_bootstrap() {
    local guard_file="$HOME/.env_setup_completed"
    local env_dir
    env_dir="$(setup_env_dir)"

    # Write as $HOME/... so the line is portable across homedirs
    local relative_env_dir="${env_dir/#$HOME/\$HOME}"
    local source_line="if [ -f \"${relative_env_dir}/setup_env.bash\" ]; then source \"${relative_env_dir}/setup_env.bash\"; fi"

    if [[ ! -f "${guard_file}" ]]; then
        {
            echo ""
            echo "# Workspace environment bootstrap — added by setup_env.bash"
            echo "${source_line}"
        } >> "$HOME/.bashrc"
        touch "${guard_file}"
    fi
}

# ─────────────────────────────────────────────
# setup_env — main orchestrator
# ─────────────────────────────────────────────
function setup_env() {
    local env_dir
    env_dir="$(setup_env_dir)"

    # Colcon bash completion
    if command -v register-python-argcomplete >/dev/null 2>&1; then
        eval "$(register-python-argcomplete colcon)"
    fi

    setup_bashrc_bootstrap
    setup_global_gitignore

    # ── Core libraries (order matters: colors -> log -> preflight) ────────────────
    source "$(setup_env_dir)/lib/colors.bash"
    source "$(setup_env_dir)/lib/log.bash"
    source "$(setup_env_dir)/lib/preflight.bash"

    # Prompt
    local prompt_script="${env_dir}/prompt/prompt.bash"
    [[ -f "${prompt_script}" ]] && source "${prompt_script}"

    # All custom commands: lib/* + setup_workspace functions
    local commands_script="${env_dir}/bash_commands.bash"
    [[ -f "${commands_script}" ]] && source "${commands_script}"

    # Aliases
    local aliases_script="${env_dir}/bash_aliases.bash"
    [[ -f "${aliases_script}" ]] && source "${aliases_script}"

    # ROS 2 install overlay (optional — may not exist on a fresh machine)
    local ros_setup
    ros_setup="$(setup_env_workspace_dir)/install/setup.bash"
    [[ -f "${ros_setup}" ]] && source "${ros_setup}"
}

setup_env