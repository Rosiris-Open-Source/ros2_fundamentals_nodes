#!/bin/bash
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
#
# Usage:
#   ./setup.sh           — full setup (idempotent, safe to re-run)
#   ./setup.sh --clean   — remove build/, install/, log/, .venv/, then full setup

set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────
# Resolve workspace root (directory of this script)
# so the script works regardless of where it is called from
# ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}"

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
REPOS_FILE="${WORKSPACE_DIR}/.repos/html.repos"
VENV_DIR="${WORKSPACE_DIR}/.venv"
HAND_DETECTOR_PKG="${WORKSPACE_DIR}/src/hand_detector"
LOG_DIR="${WORKSPACE_DIR}/log"
LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
CLEAN=false

# ─────────────────────────────────────────────
# Colour helpers (degrade gracefully in non-TTY)
# ─────────────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m'; YELLOW='\033[1;33m'
    GREEN='\033[0;32m'; CYAN='\033[0;36m'
    BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

info()    { echo -e "${CYAN}[INFO]${RESET}  $*" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*" | tee -a "${LOG_FILE}"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*" | tee -a "${LOG_FILE}"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" | tee -a "${LOG_FILE}" >&2; }

die() {
    error "$*"
    error "Setup failed. See full log: ${LOG_FILE}"
    exit 1
}

# ─────────────────────────────────────────────
# Trap — catch unexpected exits
# ─────────────────────────────────────────────
trap 'die "Unexpected error on line ${LINENO}. Command: ${BASH_COMMAND}"' ERR

# ─────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────
for arg in "$@"; do
    case "${arg}" in
        --clean|-c)
            CLEAN=true ;;
        --help|-h)
            grep '^# Usage' "${BASH_SOURCE[0]}" -A 2 | sed 's/^# //'
            exit 0 ;;
        *)
            die "Unknown argument: '${arg}'. Use --clean or --help." ;;
    esac
done

# ─────────────────────────────────────────────
# Ensure log directory exists before first write
# ─────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
echo "─────────────────────────────────────────────" >> "${LOG_FILE}"
echo "Setup started at $(date)" >> "${LOG_FILE}"
echo "Workspace: ${WORKSPACE_DIR}" >> "${LOG_FILE}"
echo "─────────────────────────────────────────────" >> "${LOG_FILE}"

# ─────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────
echo -e "${BOLD}"
echo "============================================="
echo "  ROS 2 Workspace Setup"
echo "  Workspace : ${WORKSPACE_DIR}"
echo "  Log       : ${LOG_FILE}"
if ${CLEAN}; then
    echo "  Mode      : CLEAN + rebuild"
else
    echo "  Mode      : Incremental (safe to re-run)"
fi
echo "============================================="
echo -e "${RESET}"

# ─────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────
info "Running pre-flight checks..."

command -v python3  >/dev/null 2>&1 || die "'python3' not found. Please install Python 3."
command -v pip3     >/dev/null 2>&1 || die "'pip3' not found. Please install pip."
command -v vcs      >/dev/null 2>&1 || die "'vcs' (vcstool) not found. Install with: pip3 install vcstool"
command -v rosdep   >/dev/null 2>&1 || die "'rosdep' not found. Install with: sudo apt install python3-rosdep"
command -v colcon   >/dev/null 2>&1 || die "'colcon' not found. Install with: sudo apt install python3-colcon-common-extensions"

[[ -f "${REPOS_FILE}" ]]           || die "Repos file not found: ${REPOS_FILE}"
[[ -d "${HAND_DETECTOR_PKG}" ]]    || die "Hand detector package not found: ${HAND_DETECTOR_PKG}"

success "Pre-flight checks passed."

# ─────────────────────────────────────────────
# Clean (optional)
# ─────────────────────────────────────────────
if ${CLEAN}; then
    info "Clean flag set — removing build/, install/, .venv/, and log/ ..."

    # Deactivate venv if currently active to avoid removal issues
    if [[ "${VIRTUAL_ENV:-}" == "${VENV_DIR}" ]]; then
        warn "Deactivating active virtual environment before clean."
        deactivate 2>/dev/null || true
    fi

    # Remove non-log dirs first (tee is still live, log writes work normally)
    for dir in build install .venv; do
        target="${WORKSPACE_DIR}/${dir}"
        if [[ -d "${target}" ]]; then
            rm -rf "${target}"
            info "  Removed: ${target}"
        else
            info "  Not present (skipped): ${target}"
        fi
    done

    # Remove log dir last — use plain echo so tee never loses its target,
    # then immediately recreate the dir and reset LOG_FILE to a fresh timestamp.
    if [[ -d "${LOG_DIR}" ]]; then
        echo "  [INFO]  Removing: ${LOG_DIR}"
        rm -rf "${LOG_DIR}"
    fi
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
    echo "─────────────────────────────────────────────" >> "${LOG_FILE}"
    echo "Log recreated after clean at $(date)"          >> "${LOG_FILE}"
    echo "─────────────────────────────────────────────" >> "${LOG_FILE}"
    info "  Recreated: ${LOG_DIR}"

    success "Clean complete."
fi

# ─────────────────────────────────────────────
#  — System update + upgrade
# ─────────────────────────────────────────────
info " — Updating and upgrading system packages..."
sudo apt update   >> "${LOG_FILE}" 2>&1 || die "apt update failed."
sudo apt upgrade -y >> "${LOG_FILE}" 2>&1 || die "apt upgrade failed."
success "System packages up to date."

# ─────────────────────────────────────────────
#  — Import repositories
# ─────────────────────────────────────────────
info " — Importing repositories from ${REPOS_FILE}..."
# --workers 1 is intentional (avoids race conditions with some vcs back-ends)
vcs import \
    --input "${REPOS_FILE}" \
    --workers 1 \
    "${WORKSPACE_DIR}/" >> "${LOG_FILE}" 2>&1 \
    || die "vcs import failed. Check ${LOG_FILE} for details."
success "Repositories imported."

# ─────────────────────────────────────────────
#  — Create / reuse virtual environment
# ─────────────────────────────────────────────
info " — Setting up Python virtual environment at ${VENV_DIR}..."
if [[ -d "${VENV_DIR}" ]]; then
    info "  Virtual environment already exists — reusing."
else
    python3 -m venv "${VENV_DIR}" --system-site-packages >> "${LOG_FILE}" 2>&1 \
        || die "Failed to create virtual environment."
    info "  Virtual environment created."
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate" \
    || die "Failed to activate virtual environment."
success "Virtual environment active: $(python --version)"

# ─────────────────────────────────────────────
#  — Install Python dependencies
# ─────────────────────────────────────────────
info " — Installing Python dependencies..."
pip install --upgrade pip >> "${LOG_FILE}" 2>&1 \
    || die "pip upgrade failed."

pip install -e "${HAND_DETECTOR_PKG}" >> "${LOG_FILE}" 2>&1 \
    || die "Failed to install hand_detector package. Check ${LOG_FILE}."
success "Python dependencies installed."

# ─────────────────────────────────────────────
#  — rosdep install
# ─────────────────────────────────────────────
info " — Installing ROS dependencies via rosdep..."

# Initialise rosdep only if it has never been initialised
if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    info "  rosdep not yet initialised — running rosdep init..."
    sudo rosdep init >> "${LOG_FILE}" 2>&1 \
        || die "rosdep init failed."
fi

rosdep update >> "${LOG_FILE}" 2>&1 \
    || warn "rosdep update encountered issues — continuing anyway."

rosdep install \
    --from-paths "${WORKSPACE_DIR}/src" \
    --ignore-src \
    -r -y >> "${LOG_FILE}" 2>&1 \
    || die "rosdep install failed. Check ${LOG_FILE}."
success "ROS dependencies installed."

# ─────────────────────────────────────────────
#  — Build with colcon
# ─────────────────────────────────────────────
info " — Building ROS 2 workspace with colcon..."

# Ensure the venv Python is used by colcon so the hand detection model
# is available at runtime
python -m colcon \
    --log-base "${WORKSPACE_DIR}/log/colcon" \
    build \
    --symlink-install \
    --base-paths "${WORKSPACE_DIR}" \
    --build-base  "${WORKSPACE_DIR}/build" \
    --install-base "${WORKSPACE_DIR}/install" \
    >> "${LOG_FILE}" 2>&1 \
    || die "colcon build failed. Check ${LOG_FILE} for details."
success "Workspace built successfully."

# ─────────────────────────────────────────────
# Source the install overlay
# ─────────────────────────────────────────────
INSTALL_SETUP="${WORKSPACE_DIR}/install/setup.bash"
if [[ -f "${INSTALL_SETUP}" ]]; then
    # shellcheck source=/dev/null
    source "${INSTALL_SETUP}"
    success "Sourced install overlay: ${INSTALL_SETUP}"
else
    warn "install/setup.bash not found — workspace may not be fully sourced in this shell."
fi

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}============================================="
echo   "  Setup complete!"
echo   "=============================================${RESET}"
echo ""
info "To activate the workspace in a new shell, run:"
echo -e "    ${BOLD}source ${VENV_DIR}/bin/activate${RESET}"
echo -e "    ${BOLD}source ${INSTALL_SETUP}${RESET}"
echo ""
info "Full log available at: ${LOG_FILE}"