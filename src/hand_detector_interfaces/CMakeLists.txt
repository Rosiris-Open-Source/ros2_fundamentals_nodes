cmake_minimum_required(VERSION 3.20)
project(hand_detector_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)

set(THIS_PACKAGE_INCLUDE_DEPENDS
  std_msgs
)
# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)
foreach(Dependency IN ITEMS ${THIS_PACKAGE_INCLUDE_DEPENDS})
  find_package(${Dependency} REQUIRED)
endforeach()

set(msg_files
  msg/Point2d.msg
  msg/PalmCenter.msg
  msg/EstimatedPalmCenters.msg
)

rosidl_generate_interfaces(${PROJECT_NAME}
  ${msg_files}
  DEPENDENCIES builtin_interfaces ${THIS_PACKAGE_INCLUDE_DEPENDS}
  ADD_LINTER_TESTS
)
ament_export_dependencies(rosidl_default_runtime)
ament_package()
