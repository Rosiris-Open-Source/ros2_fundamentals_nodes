from rclpy.node import Node
from rcl_interfaces.msg import ParameterDescriptor, IntegerRange, SetParametersResult
from rclpy.parameter import Parameter

from sensor_msgs.msg import Image
from cv_bridge import CvBridge

import rclpy
import cv2

class WebcamNode(Node):
    def __init__(self):
        super().__init__('webcam_node')
        self._declare_and_get_parameters()
        self.add_on_set_parameters_callback(self.param_callback)
        self.publisher_ = self.create_publisher(Image, '~/image', 10)
        self.bridge = CvBridge()
        self.cap = cv2.VideoCapture(self.device)
        self.get_logger().info(f'Publishing image from device: {self.device} on publisher: {self.publisher_.handle.get_topic_name()}')

        self.timer = self.create_timer(0.01, self.timer_callback) 

    def _declare_and_get_parameters(self):
        # device number of the camera
        device_desc = ParameterDescriptor(
            description='Camera device index used by OpenCV',
            type=Parameter.Type.INTEGER,
        )

        # standard camera is usually 0
        self.device: int = self.declare_parameter(
            'device',
            0,
            device_desc,
        ).value

        # flip the image ?
        flip_img_desc = ParameterDescriptor(
            description='If set to true the image if flip as set in flip_img_opcode',
            type=Parameter.Type.BOOL,
            )

        self.flip_img : bool = self.declare_parameter(
            'flip_img',
            True,
            flip_img_desc,
        ).value

        # axis around which to flip
        flip_img_opcode_desc = ParameterDescriptor(
            description='Controls how the image is flipped, 0: y axis, -1 x and y, 1: x axis. Need flip_img to be enabled.',
            type=Parameter.Type.INTEGER,
             integer_range=[
                IntegerRange(
                    from_value=-1,
                    to_value=1,
                    step=1,
                )
                ],
            )

        self.flip_img_opcode : int = self.declare_parameter(
            'flip_img_opcode',
            1,
            flip_img_opcode_desc,
        ).value

    def param_callback(self, params):
        for p in params:
            if p.name == 'flip_img':
                self.flip_img = bool(p.value)

            if p.name == 'flip_img_opcode':
                if p.value not in (-1, 0, 1):
                    return SetParametersResult(
                        successful=False,
                        reason="flip_img_opcode must be -1, 0, or 1"
                    )
                self.flip_img_opcode = p.value

        return SetParametersResult(successful=True)

    def timer_callback(self):
        # capture next frame and convert to msg
        ret, frame = self.cap.read()
        if not ret:
            self.get_logger().warning("Failed to grab frame")
            return
        
        if self.flip_img:
            frame = cv2.flip(frame, self.flip_img_opcode)
        msg = self.bridge.cv2_to_imgmsg(frame, encoding="bgr8")

        # add timestamp to header
        msg.header.stamp = self.get_clock().now().to_msg()

        # publish the image on the created topic
        self.publisher_.publish(msg)

def main(args=None):
    rclpy.init(args=args)
    node = WebcamNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()