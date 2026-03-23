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

# Visualization constants
FONT_SIZE = 1
FONT_THICKNESS = 1
HANDEDNESS_TEXT_COLOR = (88, 205, 54)
MARGIN = 10  # pixels

class HandDetectorNode(Node):
    def __init__(self):
        super().__init__('hand_detector')

        # CV Bridge
        self.bridge = CvBridge()

        # MediaPipe Hand Landmarker setup
        package_path = get_package_share_directory('hand_detector')
        model_path = os.path.join(package_path, 'models', 'hand_landmarker.task')
        base_options = python.BaseOptions(model_asset_path=model_path)

        options = vision.HandLandmarkerOptions(
            base_options=base_options,
            num_hands=2,
            running_mode=vision.RunningMode.VIDEO
        )

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
        # VIDEO mode requires timestamp in milliseconds
        timestamp_ms = int(msg.header.stamp.sec * 1000 + msg.header.stamp.nanosec / 1e6)
        results = self.detector.detect_for_video(mp_image, timestamp_ms)

        # Draw landmarks and palm center
        img_landmarks = self.draw_landmarks_on_image(frame, results)

        # get centers of palms and draw on img
        palm_centers = self.estimate_palm_centers(img_landmarks, results)
        annotated_image = self.draw_estimated_palm_centers(img_landmarks, palm_centers)

        # Publish annotated image
        out_msg = self.bridge.cv2_to_imgmsg(annotated_image, encoding='bgr8')
        out_msg.header = msg.header
        self.pub.publish(out_msg)

    def draw_landmarks_on_image(self, rgb_image, detection_result):
        mp_hands = mp.tasks.vision.HandLandmarksConnections
        mp_drawing = mp.tasks.vision.drawing_utils
        mp_drawing_styles = mp.tasks.vision.drawing_styles

        hand_landmarks_list = detection_result.hand_landmarks
        annotated_image = np.copy(rgb_image)
        for hand_landmarks in hand_landmarks_list:
           
            # Draw landmarks and connections
            mp_drawing.draw_landmarks(
                annotated_image,
                hand_landmarks,
                mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style()
            )            

        return annotated_image
    
    def estimate_palm_centers(self, rgb_image, detection_result):
        hand_landmarks_list = detection_result.hand_landmarks
        height, width, _ = rgb_image.shape
        handedness_list = detection_result.handedness

        estimated_palm_centers =  {}

        for idx, hand_landmarks in enumerate(hand_landmarks_list):
            handedness = handedness_list[idx][0].category_name
            # Compute rough palm center using wrist + base MCP joints
            palm_indices = [0, 1, 5, 17]  # wrist + palm base
            palm_x = int(np.mean([hand_landmarks[i].x * width for i in palm_indices]))
            palm_y = int(np.mean([hand_landmarks[i].y * height for i in palm_indices]))
            estimated_palm_centers[f"{handedness}_hand_{idx}"] = (palm_x, palm_y)

        return estimated_palm_centers

    def draw_estimated_palm_centers(self, image, estimated_palm_centers : dict[str, tuple[int,int]], color=(0,0,0)):
        annotated_image = np.copy(image)
        for _, center in estimated_palm_centers.items():
            cv2.circle(annotated_image, (center[0], center[1]), 8, color, -1)
        return annotated_image
                
    
    def draw_handeness_on_image(self, rgb_image, detection_result):
        hand_landmarks_list = detection_result.hand_landmarks
        annotated_image = np.copy(rgb_image)
        height, width, _ = annotated_image.shape
        handedness_list = detection_result.handedness

        for idx, hand_landmarks in enumerate(hand_landmarks_list):
            handedness = handedness_list[idx][0].category_name  # "Left" or "Right"
            
            # Compute bounding box around landmarks
            xs = [lm.x * width for lm in hand_landmarks]
            ys = [lm.y * height for lm in hand_landmarks]
            x1, y1 = int(min(xs)), int(min(ys))

            # Draw handedness above the bounding box
            cv2.putText(
                annotated_image,
                f"{handedness}",
                (x1, y1 - MARGIN),
                cv2.FONT_HERSHEY_DUPLEX,
                FONT_SIZE,
                HANDEDNESS_TEXT_COLOR,
                FONT_THICKNESS,
                cv2.LINE_AA
            )

        return annotated_image
    
    def draw_bounding_box_around_hand(self, rgb_image, detection_result):
        hand_landmarks_list = detection_result.hand_landmarks
        annotated_image = np.copy(rgb_image)
        height, width, _ = annotated_image.shape

        for hand_landmarks in hand_landmarks_list:
            # Compute bounding box around landmarks
            xs = [lm.x * width for lm in hand_landmarks]
            ys = [lm.y * height for lm in hand_landmarks]
            x1, y1 = int(min(xs)), int(min(ys))
            x2, y2 = int(max(xs)), int(max(ys))
            cv2.rectangle(annotated_image, (x1, y1), (x2, y2), (0, 255, 0), 2)

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