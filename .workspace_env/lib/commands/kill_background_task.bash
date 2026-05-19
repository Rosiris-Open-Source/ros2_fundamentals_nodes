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


[[ -n "${_CMD_KILL_BG_LOADED:-}" ]] && return 0
readonly _CMD_KILL_BG_LOADED=1

# ─────────────────────────────────────────────
# kill_background_task
# ─────────────────────────────────────────────
kill_background_task() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: kill_background_task [job_num]"
            echo ""
            echo "  Kills a shell background job by job number."
            echo "  With no argument, lists running jobs and prompts for a number."
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Examples:"
            echo "  kill_background_task        # interactive selection"
            echo "  kill_background_task 2      # kill job %2 directly"
            return 0
            ;;
    esac

    local job_list
    job_list="$(jobs -p 2>/dev/null)"

    if [[ -z "${job_list}" ]]; then
        log_info "No background jobs running."
        return 0
    fi

    # Direct kill if job number supplied
    if [[ -n "${1:-}" ]]; then
        _kbt_kill_job "${1}"
        return $?
    fi

    # Interactive: show jobs, prompt for number
    echo ""
    jobs
    echo ""
    echo -en "${TERMINAL_COLOR_CYAN}Enter job number to kill (or Enter to cancel): ${TERMINAL_COLOR_NC}"
    local jobnum
    read -r jobnum

    if [[ -z "${jobnum}" ]]; then
        log_info "Cancelled."
        return 0
    fi

    _kbt_kill_job "${jobnum}"
}

# Internal: validate and kill a single job number
_kbt_kill_job() {
    local job_num="${1}"

    # Validate: must be a positive integer
    if ! [[ "${job_num}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid job number: '${job_num}'. Must be a positive integer."
                return 1
    fi

    if ! jobs "%${job_num}" &>/dev/null; then
        log_error "No job with number %${job_num}."
        jobs    # show what's actually running to help the user
        return 1
    fi

    if kill "%${job_num}" 2>/dev/null; then
        log_ok "Killed job %${job_num}."
    else
        log_error "Failed to kill job %${job_num}."
        return 1
    fi
}