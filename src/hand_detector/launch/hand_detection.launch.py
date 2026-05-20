
from launch import LaunchDescription
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution


def generate_launch_description():
    return LaunchDescription(
        declare_launch_arguments() +
        declare_nodes_to_launch()
    )

def declare_launch_arguments():
    video_device_arg = DeclareLaunchArgument(
        "video_device",
        default_value="0",
        description="Video device index to use for webcam input.",
    )

    flip_img_arg = DeclareLaunchArgument(
        "flip_img",
        default_value="true",
        description="Flip webcam image before publishing.",
    )

    flip_img_opcode_arg = DeclareLaunchArgument(
        "flip_img_opcode",
        default_value="1",
        description="Flip mode: 0=y-axis, 1=x-axis, -1=both axes.",
    )

    launch_rviz = DeclareLaunchArgument(
        "launch_rviz",
        default_value="true",
        description="Whether to launch RViz for visualization.",
    )

    return [
        video_device_arg,
        flip_img_arg,
        flip_img_opcode_arg,
        launch_rviz
    ]

def declare_nodes_to_launch():
    # Launch configurations define the values of the launch arguments, which can be used in node parameters
    video_device = LaunchConfiguration("video_device")
    flip_img = LaunchConfiguration("flip_img")
    flip_img_opcode = LaunchConfiguration("flip_img_opcode")

    webcam_node = Node(
        package="hand_detector",
        executable="webcam_node",
        name="webcam_node",
        parameters=[{
            "device": video_device,
            "flip_img": flip_img,
            "flip_img_opcode": flip_img_opcode,
        }],
        output="screen",
    )

    hand_detection_node = Node(
        package="hand_detector",
        executable="hand_detector_node",
        name="hand_detector_node",
        remappings=[
            ("/image", "/webcam_node/image"),
        ],
        output="screen",
    )

    rviz2 = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        arguments=["-d", 
                   PathJoinSubstitution(
                    [FindPackageShare("hand_detector"), "config/view_hand_detector.rviz"]
        )],
        condition=IfCondition(LaunchConfiguration("launch_rviz")),
        output="screen",
    )

    return [
        webcam_node,
        hand_detection_node,
        rviz2
    ]