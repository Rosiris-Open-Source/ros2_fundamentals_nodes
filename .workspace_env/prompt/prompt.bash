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

# prompt/prompt.bash — Interactive shell prompt with git + env awareness.
#
# Source this file from your shell init (e.g. setup_env.bash).
# It sets PROMPT_COMMAND to __update_prompt.
#
# Features:
#   • Username @ hostname (coloured by environment: local / ssh / docker)
#   • Current directory (basename)
#   • Git branch with ahead/behind/diverged symbols
#   • Git working-tree status colour (clean / staged / dirty)
#   • Stash indicator
#   • Active Python venv name
#
# Symbols:
#   +   ahead of remote
#   -   behind remote
#   !   diverged

[[ -n "${_GIT_PROMPT_BASH_LOADED:-}" ]] && return 0
readonly _GIT_PROMPT_BASH_LOADED=1

# setup_env_dir is provided by setup_env.bash (always sourced before this).
# Fallback: walk up from this file's location.
if ! declare -f setup_env_dir >/dev/null 2>&1; then
    function setup_env_dir() {
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
    }
fi

# shellcheck source=lib/colors.bash
source "$(setup_env_dir)/lib/colors.bash"

# ─────────────────────────────────────────────
# Git helpers
# ─────────────────────────────────────────────
_git_branch() {
    git branch --show-current 2>/dev/null
}

_git_remote_symbol() {
    local branch
    branch="$(_git_branch)"
    [[ -z "${branch}" ]] && return

    local status
    status="$(git status --porcelain=2 --branch 2>/dev/null)"

    local ahead behind
    ahead="$(echo "${status}"  | grep "^# branch.ab" | sed -E 's/.*\+([0-9]+).*/\1/')"
    behind="$(echo "${status}" | grep "^# branch.ab" | sed -E 's/.*-([0-9]+).*/\1/')"

    [[ -z "${ahead}" && -z "${behind}" ]] && return

    if   [[ "${ahead}"  -gt 0 && "${behind}" -gt 0 ]]; then echo "!"
    elif [[ "${ahead}"  -gt 0 ]];                       then echo "+"
    elif [[ "${behind}" -gt 0 ]];                       then echo "-"
    fi
}

# Returns the colour for the branch name based on working-tree state.
# Priority: dirty (red) > stash (yellow) > staged (brown/orange) > clean (arg)
_git_branch_color() {
    local default_color="${1:-${TERMINAL_COLOR_GREEN}}"
    [[ -z "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]] \
        && echo "${default_color}" && return

    local porcelain
    porcelain="$(git status --porcelain 2>/dev/null)"

    # Dirty: untracked or unstaged modifications/deletions
    if echo "${porcelain}" | grep -qE "^\?\?|^.[MD]"; then
        echo "${TERMINAL_COLOR_RED}"; return
    fi

    # Stash present
    if git stash list 2>/dev/null | grep -q .; then
        echo "${TERMINAL_COLOR_YELLOW}"; return
    fi

    # Only staged changes
    if echo "${porcelain}" | grep -qE "^[AMD]"; then
        echo "${TERMINAL_COLOR_BROWN}"; return   # orange on most terminals
    fi

    echo "${default_color}"
}

# ─────────────────────────────────────────────
# Environment helpers
# ─────────────────────────────────────────────
_detect_env() {
    if [[ -n "${SSH_CONNECTION:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
        echo "remote"; return
    fi
    if [[ -f "/.dockerenv" ]] || grep -qi docker /proc/1/cgroup 2>/dev/null; then
        echo "docker"; return
    fi
    echo "local"
}

_env_color() {
    case "$(_detect_env)" in
        local)  echo "${TERMINAL_COLOR_GREEN}"  ;;
        remote) echo "${TERMINAL_COLOR_YELLOW}" ;;
        docker) echo "${TERMINAL_COLOR_YELLOW}" ;;
    esac
}

_env_tag() {
    case "$(_detect_env)" in
        docker) echo "cntr" ;;
        remote) echo "ssh"  ;;
        local)  echo ""     ;;
    esac
}

# ─────────────────────────────────────────────
# Prompt assembly
# ─────────────────────────────────────────────
__update_prompt() {
    # Capture early so $? is preserved for any future use
    local ec=$?

    # venv
    local venv_part=""
    [[ -n "${VIRTUAL_ENV:-}" ]] && venv_part="($(basename "${VIRTUAL_ENV}")) "

    # git
    local branch
    branch="$(_git_branch)"
    local git_part=""
    if [[ -n "${branch}" ]]; then
        local symbol
        symbol="$(_git_remote_symbol)"
        [[ -n "${symbol}" ]] && symbol=" ${symbol}"
        local branch_color
        branch_color="$(_git_branch_color "${TERMINAL_COLOR_GREEN}")"
        # <branch_name[_symbol]>
        git_part="\[${TERMINAL_COLOR_GREEN}\]<\[${branch_color}\]${branch}${symbol}"
    fi

    # env tag
    local tag
    tag="$(_env_tag)"
    local env_color
    env_color="$(_env_color)"
    local env_part=""
    [[ -n "${tag}" ]] && env_part="\[${env_color}\][${tag}]"

    # Final prompt: (venv) user@host[tag]:<branch>>dir$
    PS1="${venv_part}"
    PS1+="\[${TERMINAL_COLOR_LIGHT_GREEN}\]\u"
    PS1+="\[${TERMINAL_COLOR_LIGHT_GRAY}\]@"
    PS1+="\[${env_color}\]\h"
    PS1+="${env_part}"
    PS1+="\[${TERMINAL_COLOR_LIGHT_GRAY}\]:"
    PS1+="${git_part}"
    PS1+="\[${TERMINAL_COLOR_GREEN}\]>"
    PS1+="\[${TERMINAL_COLOR_LIGHT_PURPLE}\]\W"
    PS1+="\[${TERMINAL_COLOR_LIGHT_PURPLE}\]\$"
    PS1+="\[${TERMINAL_COLOR_NC}\] "

    return ${ec}
}

PROMPT_COMMAND=__update_prompt