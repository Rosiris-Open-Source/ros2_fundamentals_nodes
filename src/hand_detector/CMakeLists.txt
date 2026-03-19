cmake_minimum_required(VERSION 3.20)
project(hand_detector)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
# requirement for building python nodes with cmake
find_package(ament_cmake_python REQUIRED)

# Python modules
ament_python_install_package(${PROJECT_NAME})

install(PROGRAMS
  hand_detector/webcam_node.py
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
