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

# lib/colors.bash — ANSI colour variables.
#
# Source this file; do not execute it directly.
# All variables are exported so sub-shells inherit them.
#
# Degrades gracefully: when stdout is not a TTY (e.g. piped output,
# CI logs), every variable is set to an empty string so callers never
# need to guard against literal escape codes appearing in plain text.
#
# Reference: https://www.shellhacks.com/bash-colors/

# Guard against double-sourcing
[[ -n "${_COLORS_BASH_LOADED:-}" ]] && return 0
readonly _COLORS_BASH_LOADED=1

if [[ -t 1 ]]; then
    # ── Foreground ───────────────────────────────────────────────────────────
    export TERMINAL_COLOR_NC='\033[0m'          # Reset / No Colour

    export TERMINAL_COLOR_BLACK='\033[0;30m'
    export TERMINAL_COLOR_GRAY='\033[1;30m'
    export TERMINAL_COLOR_RED='\033[0;31m'
    export TERMINAL_COLOR_LIGHT_RED='\033[1;31m'
    export TERMINAL_COLOR_GREEN='\033[0;32m'
    export TERMINAL_COLOR_LIGHT_GREEN='\033[1;32m'
    export TERMINAL_COLOR_BROWN='\033[0;33m'    # "orange" on most terminals
    export TERMINAL_COLOR_YELLOW='\033[1;33m'
    export TERMINAL_COLOR_BLUE='\033[0;34m'
    export TERMINAL_COLOR_LIGHT_BLUE='\033[1;34m'
    export TERMINAL_COLOR_PURPLE='\033[0;35m'
    export TERMINAL_COLOR_LIGHT_PURPLE='\033[1;35m'
    export TERMINAL_COLOR_CYAN='\033[0;36m'
    export TERMINAL_COLOR_LIGHT_CYAN='\033[1;36m'
    export TERMINAL_COLOR_LIGHT_GRAY='\033[0;37m'
    export TERMINAL_COLOR_WHITE='\033[1;37m'

    # ── Background ───────────────────────────────────────────────────────────
    export TERMINAL_BG_COLOR_BLACK='\033[40m'
    export TERMINAL_BG_COLOR_GRAY='\033[1;40m'
    export TERMINAL_BG_COLOR_RED='\033[41m'
    export TERMINAL_BG_COLOR_LIGHT_RED='\033[1;41m'
    export TERMINAL_BG_COLOR_GREEN='\033[42m'
    export TERMINAL_BG_COLOR_LIGHT_GREEN='\033[1;42m'
    export TERMINAL_BG_COLOR_BROWN='\033[43m'
    export TERMINAL_BG_COLOR_YELLOW='\033[1;43m'
    export TERMINAL_BG_COLOR_BLUE='\033[44m'
    export TERMINAL_BG_COLOR_LIGHT_BLUE='\033[1;44m'
    export TERMINAL_BG_COLOR_PURPLE='\033[45m'
    export TERMINAL_BG_COLOR_LIGHT_PURPLE='\033[1;45m'
    export TERMINAL_BG_COLOR_CYAN='\033[46m'
    export TERMINAL_BG_COLOR_LIGHT_CYAN='\033[1;46m'
    export TERMINAL_BG_COLOR_LIGHT_GRAY='\033[47m'
    export TERMINAL_BG_COLOR_WHITE='\033[1;47m'
else
    # Non-TTY: blank everything so log output stays clean
    export TERMINAL_COLOR_NC=''
    export TERMINAL_COLOR_BLACK=''    TERMINAL_COLOR_GRAY=''
    export TERMINAL_COLOR_RED=''      TERMINAL_COLOR_LIGHT_RED=''
    export TERMINAL_COLOR_GREEN=''    TERMINAL_COLOR_LIGHT_GREEN=''
    export TERMINAL_COLOR_BROWN=''    TERMINAL_COLOR_YELLOW=''
    export TERMINAL_COLOR_BLUE=''     TERMINAL_COLOR_LIGHT_BLUE=''
    export TERMINAL_COLOR_PURPLE=''   TERMINAL_COLOR_LIGHT_PURPLE=''
    export TERMINAL_COLOR_CYAN=''     TERMINAL_COLOR_LIGHT_CYAN=''
    export TERMINAL_COLOR_LIGHT_GRAY=''  TERMINAL_COLOR_WHITE=''

    export TERMINAL_BG_COLOR_BLACK=''    TERMINAL_BG_COLOR_GRAY=''
    export TERMINAL_BG_COLOR_RED=''      TERMINAL_BG_COLOR_LIGHT_RED=''
    export TERMINAL_BG_COLOR_GREEN=''    TERMINAL_BG_COLOR_LIGHT_GREEN=''
    export TERMINAL_BG_COLOR_BROWN=''    TERMINAL_BG_COLOR_YELLOW=''
    export TERMINAL_BG_COLOR_BLUE=''     TERMINAL_BG_COLOR_LIGHT_BLUE=''
    export TERMINAL_BG_COLOR_PURPLE=''   TERMINAL_BG_COLOR_LIGHT_PURPLE=''
    export TERMINAL_BG_COLOR_CYAN=''     TERMINAL_BG_COLOR_LIGHT_CYAN=''
    export TERMINAL_BG_COLOR_LIGHT_GRAY=''  TERMINAL_BG_COLOR_WHITE=''
fi
