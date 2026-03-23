import cv2
import mediapipe as mp
import numpy as np
import os
import rclpy

from ament_index_python.packages import get_package_share_directory
from cv_bridge import CvBridge
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from rclpy.node import Node
from sensor_msgs.msg import Image

MARGIN = 10  # pixels
FONT_SIZE = 1
FONT_THICKNESS = 1
HANDEDNESS_TEXT_COLOR = (88, 205, 54)

class HandDetectorNode(Node):
    def __init__(self):
        super().__init__('hand_detector')

        # CV Bridge
        self.bridge = CvBridge()

        # MediaPipe Hands setup
        package_path = get_package_share_directory('hand_detector')
        model_path = os.path.join(package_path, 'models', 'hand_landmarker.task')
        base_options = python.BaseOptions(model_asset_path=model_path)
        options = vision.HandLandmarkerOptions(base_options=base_options,
                                            num_hands=2)
        self.detector = vision.HandLandmarker.create_from_options(options)

        # Subscriber for input images
        self.sub = self.create_subscription(
            Image,
            '/image',
            self.image_callback,
            10
        )

        # Publisher for annotated images
        self.pub = self.create_publisher(Image, '~/image', 10)

        self.get_logger().info('Hand Detector Node started, listening on /image')

    def image_callback(self, msg: Image):
        # Convert ROS Image → OpenCV BGR
        frame = self.bridge.imgmsg_to_cv2(msg, desired_encoding='bgr8')

        # Convert to RGB for MediaPipe
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        results = self.detector.detect(mp_image)
        annotated_image = self.draw_landmarks_on_image(frame, results)
        
        # Publish annotated image
        out_msg = self.bridge.cv2_to_imgmsg(annotated_image, encoding='bgr8')
        out_msg.header = msg.header
        self.pub.publish(out_msg)


    def draw_landmarks_on_image(self, rgb_image, detection_result):
        mp_hands = mp.tasks.vision.HandLandmarksConnections
        mp_drawing = mp.tasks.vision.drawing_utils
        mp_drawing_styles = mp.tasks.vision.drawing_styles

        hand_landmarks_list = detection_result.hand_landmarks
        handedness_list = detection_result.handedness
        annotated_image = np.copy(rgb_image)

        # Loop through the detected hands to visualize.
        for idx in range(len(hand_landmarks_list)):
            hand_landmarks = hand_landmarks_list[idx]
            handedness = handedness_list[idx]

            # Draw the hand landmarks.
            mp_drawing.draw_landmarks(
            annotated_image,
            hand_landmarks,
            mp_hands.HAND_CONNECTIONS,
            mp_drawing_styles.get_default_hand_landmarks_style(),
            mp_drawing_styles.get_default_hand_connections_style())

            # Get the top left corner of the detected hand's bounding box.
            height, width, _ = annotated_image.shape
            x_coordinates = [landmark.x for landmark in hand_landmarks]
            y_coordinates = [landmark.y for landmark in hand_landmarks]
            text_x = int(min(x_coordinates) * width)
            text_y = int(min(y_coordinates) * height) - MARGIN

            # Draw handedness (left or right hand) on the image.
            cv2.putText(annotated_image, f"{handedness[0].category_name}",
                        (text_x, text_y), cv2.FONT_HERSHEY_DUPLEX,
                        FONT_SIZE, HANDEDNESS_TEXT_COLOR, FONT_THICKNESS, cv2.LINE_AA)

        return annotated_image

    def destroy_node(self):
        cv2.destroyAllWindows()
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = HandDetectorNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
'''
MediaPipe — 21 Landmark Map:

            index middle ring pinky
                8    12   16   20
                |    |    |    |
       thumb    7    11   15   19
            4   |    |    |    |
            |   6    10   14   18
            3   |    |    |    |
            |   5----9---13---17
            2   \    \    /    /
             \   \    \  /    /
              1    \   |     /
               \_______0  ← WRIST

'''