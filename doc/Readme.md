# ROS2 MediaPipe Hand Detection Setup Guide

## 1. System preparation

Update your system, this ensures rosdep can resolve all dependencies correctly.

```bash
sudo apt update && sudo apt upgrade -y
```

## 2. Python environment

A virtual environment is required because MediaPipe is not provided by ROS. It must still access ROS packages.

```bash
python3 -m venv .venv --system-site-packages
source .venv/bin/activate
```

## 3. Python dependencies

Install MediaPipe and your ROS package inside the environment.

```bash
pip install --upgrade pip
pip install -e src/hand_detector/
```

## 4. ROS dependencies

Install missing system dependencies defined by ROS packages.
You can either use vscode build command (ctrl+shift+b) and select `rosdep install`
or run the command yourself:

```bash
rosdep install --from-paths src --ignore-src -r -y
```

## 5. Build workspace

Build everything while the virtual environment is active and **use python**. This is very important so that we
force the correct python version for execution with ros2 run. If you want to know more read this:[Section: Execution model](#execution-model)

```bash
source .venv/bin/activate
python -m colcon build --symlink-install
source install/setup.bash
```

## 6. Run

Start nodes in order.

```bash
ros2 run hand_detector webcam_node
ros2 run hand_detector hand_detector_node --ros-args -r /image:=webcam_node/image
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 world pong_world
ros2 run ping_pong ping_pong_rviz2
```

## 7. RViz setup

Start RViz and set the fixed frame to pong_world or world depending on TF configuration. Add a MarkerArray display for /pong_markers.
```
rviz2 -d $(ros2 pkg prefix ping_pong)/share/ping_pong/rviz2/ping_pong_game.rviz
```

## 8. Common issues

If MediaPipe is missing, the virtual environment is not active. If ROS uses system Python, check which ros2 and which python. If executables are missing, rebuild and source setup.bash again.

## 9. Workflow

Always activate the environment and source ROS before running nodes.

```bash
source .venv/bin/activate
source install/setup.bash
```

---

## Execution model
Addition to [Section: 5. Build workspace](#5-build-workspace)
ROS does not run Python files directly. It runs the installed wrapper script located in:

install/hand_detector/lib/hand_detector/hand_detector_node

This script launches your node.

#### Shebang requirement

The installed script must start with:

```bash
#!/usr/bin/env python3
```

This ensures the correct Python interpreter is used and MediaPipe is found.

#### Verification

Check installed executables:

```bash
ls install/hand_detector/lib/hand_detector/
```

Check Python path:

```bash
which python
```

It must point to the .venv environment.