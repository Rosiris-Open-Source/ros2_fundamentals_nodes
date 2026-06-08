# justfile — this is what beginners see and run

# Show available commands
default:
    @just --list

# Full first-time setup
setup:
    bash ./setup_workspace.bash

# Clean everything installed and redo the fist-time setup
setup-clean:
    bash ./setup_workspace.bash --clean

# Build the workspace (needs "setup" to be run first)
build:
    bash -c 'source .venv/bin/activate && python -m colcon build --symlink-install'
    echo "${TERMINAL_COLOR_YELLOW} Do not forget to source: ${TERMINAL_COLOR_CYAN}'source ~/workspace/install/setup.bash' ${TERMINAL_COLOR_YELLOW}or with the alias ${TERMINAL_COLOR_CYAN}'sb'"

# clean the build artefact
clean:
    bash -c 'source .venv/bin/activate && python -m colcon clean workspace'