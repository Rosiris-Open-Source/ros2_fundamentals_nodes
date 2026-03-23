import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from cv_bridge import CvBridge
import cv2

class WebcamNode(Node):
    def __init__(self):
        super().__init__('webcam_publisher')
        self.publisher_ = self.create_publisher(Image, '~/image', 10)
        self.bridge = CvBridge()
        self.cap = cv2.VideoCapture(0)

        self.timer = self.create_timer(0.01, self.timer_callback) 

    def timer_callback(self):
        ret, frame = self.cap.read()
        if not ret:
            self.get_logger().warning("Failed to grab frame")
            return
        frame = cv2.flip(frame, 1)
        msg = self.bridge.cv2_to_imgmsg(frame, encoding="bgr8")
        self.publisher_.publish(msg)

def main(args=None):
    rclpy.init(args=args)
    node = WebcamNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()