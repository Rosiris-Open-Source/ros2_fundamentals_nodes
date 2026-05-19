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
# lib/commands/ros2_helpers.bash — ROS 2 process inspection and management.
#
# Commands:
#   ros2_get_node_pid [--all | <node_name>]          Show PID(s) of ROS 2 node(s)
#   ros2_kill_node    <node_name> [<signal>]          Kill a node by name
#   ros2_kill_all_nodes [<signal>]                    Kill all ROS 2 nodes

[[ -n "${_CMD_ROS2_HELPERS_LOADED:-}" ]] && return 0
readonly _CMD_ROS2_HELPERS_LOADED=1

# ─────────────────────────────────────────────
# Internal: find ROS 2 processes
# Returns raw `ps aux` lines matching --ros-args,
# optionally filtered by node_name substring.
# ─────────────────────────────────────────────
_ros2_find_procs() {
    local filter="${1:-}"
    local results
    results="$(ps aux | grep -- '--ros-args' | grep -v grep)"
    if [[ -n "${filter}" ]]; then
        results="$(echo "${results}" | grep "${filter}")"
    fi
    echo "${results}"
}

# ─────────────────────────────────────────────
# ros2_get_node_pid
# ─────────────────────────────────────────────
ros2_get_node_pid() {
    local node_name=""
    local all=false

    for arg in "$@"; do
        case "${arg}" in
            -h|--help)
                echo "Usage: ros2_get_node_pid <node_name>"
                echo "       ros2_get_node_pid --all"
                echo ""
                echo "  Finds running ROS 2 processes and prints their PIDs."
                echo ""
                echo "Options:"
                echo "  --all         Show all ROS 2 processes"
                echo "  -h, --help    Show this help"
                echo ""
                echo "Examples:"
                echo "  ros2_get_node_pid my_node"
                echo "  ros2_get_node_pid --all"
                return 0
                ;;
            --all) all=true ;;
            -*)
                log_error "ros2_get_node_pid: unknown option '${arg}'."
                echo "  Run 'ros2_get_node_pid --help' for usage."
                return 1
                ;;
            *)  node_name="${arg}" ;;
        esac
    done

    if [[ "${all}" == false && -z "${node_name}" ]]; then
        log_error "ros2_get_node_pid: a node name is required (or use --all)."
        echo "  Run 'ros2_get_node_pid --help' for usage."
        return 1
    fi

    local filter=""
    [[ "${all}" == false ]] && filter="${node_name}"

    local results
    results="$(_ros2_find_procs "${filter}")"

    if [[ -z "${results}" ]]; then
        if [[ "${all}" == true ]]; then
            log_warn "No ROS 2 processes found."
        else
            log_warn "No ROS 2 process found matching: '${node_name}'"
        fi
        return 1
    fi

    # Print formatted table
    echo -e "${TERMINAL_COLOR_CYAN}  PID      Executable${TERMINAL_COLOR_NC}"
    echo    "  ─────────────────────────────────────────────"
    echo "${results}" | awk '{
        pid = $2
        exe = $11
        printf "  %-8s [ %s ]\n", pid, exe
    }'
}

# ─────────────────────────────────────────────
# ros2_kill_node
# ─────────────────────────────────────────────
ros2_kill_node() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: ros2_kill_node <node_name> [signal]"
            echo ""
            echo "  Kills all ROS 2 processes whose name matches <node_name>."
            echo "  Signal defaults to SIGINT (graceful shutdown)."
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Signals:"
            echo "  SIGINT   (default) — graceful ROS 2 shutdown"
            echo "  SIGTERM            — terminate"
            echo "  SIGKILL            — force kill (last resort)"
            echo ""
            echo "Examples:"
            echo "  ros2_kill_node my_node"
            echo "  ros2_kill_node my_node SIGTERM"
            return 0
            ;;
        "")
            log_error "ros2_kill_node: a node name is required."
            echo "  Run 'ros2_kill_node --help' for usage."
            return 1
            ;;
    esac

    local node_name="${1}"
    local signal="${2:-SIGINT}"

    local results
    results="$(_ros2_find_procs "${node_name}")"

    if [[ -z "${results}" ]]; then
        log_warn "No ROS 2 process found matching: '${node_name}'"
        return 1
    fi

    local pids
    pids="$(echo "${results}" | awk '{print $2}')"
    local pid_list
    pid_list="$(echo "${pids}" | tr '\n' ' ' | sed 's/ $//')"

    log_info "Sending ${signal} to '${node_name}' (PID(s): ${pid_list})"

    if echo "${pids}" | xargs kill -s "${signal}" 2>/dev/null; then
        log_ok "Signal sent successfully."
    else
        log_error "Failed to send ${signal} to one or more PIDs."
        return 1
    fi
}

# ─────────────────────────────────────────────
# ros2_kill_all_nodes
# ─────────────────────────────────────────────
ros2_kill_all_nodes() {
    case "${1:-}" in
        -h|--help)
            echo "Usage: ros2_kill_all_nodes [signal]"
            echo ""
            echo "  Kills all running ROS 2 nodes."
            echo "  Signal defaults to SIGINT (graceful shutdown)."
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help"
            echo ""
            echo "Signals:"
            echo "  SIGINT   (default) — graceful ROS 2 shutdown"
            echo "  SIGTERM            — terminate"
            echo "  SIGKILL            — force kill (last resort)"
            echo ""
            echo "Examples:"
            echo "  ros2_kill_all_nodes"
            echo "  ros2_kill_all_nodes SIGKILL"
            return 0
            ;;
    esac

    local signal="${1:-SIGINT}"

    local results
    results="$(_ros2_find_procs)"

    if [[ -z "${results}" ]]; then
        log_warn "No ROS 2 processes found."
        return 1
    fi

    local pids
    pids="$(echo "${results}" | awk '{print $2}')"
    local pid_list
    pid_list="$(echo "${pids}" | tr '\n' ' ' | sed 's/ $//')"
    local count
    count="$(echo "${pids}" | wc -l | tr -d ' ')"

    log_info "Sending ${signal} to ${count} ROS 2 node(s) (PID(s): ${pid_list})"

    if echo "${pids}" | xargs kill -s "${signal}" 2>/dev/null; then
        log_ok "All ROS 2 nodes signalled."
    else
        log_error "Failed to send ${signal} to one or more PIDs."
        return 1
    fi
}