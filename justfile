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

# clean the build artefact
clean:
    bash -c 'source .venv/bin/activate && python -m colcon clean workspace'

# Print what to source (can't do it for you)
@activate:
    echo "Run in your shell:"
    echo "  source .venv/bin/activate"
    echo "  source install/setup.bash"