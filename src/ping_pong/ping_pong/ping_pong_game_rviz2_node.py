import random
import threading

import rclpy
from rclpy.node import Node
from rclpy.executors import MultiThreadedExecutor

from visualization_msgs.msg import Marker, MarkerArray
from geometry_msgs.msg import Point

from hand_detector_interfaces.msg import EstimatedPalmCenters


class PingPongRVizNode(Node):
    def __init__(self):
        super().__init__('ping_pong_rviz_node')

        # --------------------
        # Board size (meters)
        # --------------------
        self.width = 10.0
        self.height = 6.0

        self.half_w = self.width / 2.0
        self.half_h = self.height / 2.0

        # --------------------
        # Ball state (CENTERED COORDS)
        # --------------------
        self.ball_x = 0.0
        self.ball_y = 0.0

        self.ball_speed_x = 0.2
        self.ball_speed_y = 0.15

        # --------------------
        # Paddles (CENTERED COORDS)
        # --------------------
        self.left_paddle_y = 0.0
        self.right_paddle_y = 0.0

        self.paddle_height = 1.2
        self.paddle_width = 0.2

        self.left_paddle_x = -self.half_w + 0.3
        self.right_paddle_x = self.half_w - 0.3

        # --------------------
        # AI / mode
        # --------------------
        self.declare_parameter('two_player_mode', True)
        self.two_player_mode = self.get_parameter('two_player_mode').value

        self.ball_uncertainty = 0.8
        self.ai_speed = 0.18

        self.left_player_id = "Right_hand"
        self.right_player_id = "Left_hand"

        self.left_lock = threading.Lock()
        self.right_lock = threading.Lock()

        # --------------------
        # ROS
        # --------------------
        self.marker_pub = self.create_publisher(MarkerArray, "/pong_markers", 10)

        self.create_subscription(
            EstimatedPalmCenters,
            "/hand_detector/estimated_palm_centers",
            self.hand_callback,
            10
        )

        self.create_timer(1.0 / 30.0, self.update)

    # --------------------
    # Map sensor → world
    # --------------------
    def map_y(self, y):
        # 0..480 -> -3..+3
        return (y / 480.0) * self.height - self.half_h

    # --------------------
    # Input
    # --------------------
    def hand_callback(self, msg):
        for p in msg.centers:
            if p.palm_id.startswith(self.left_player_id):
                self.left_paddle_y = self.map_y(p.position.y)

            if self.two_player_mode and p.palm_id.startswith(self.right_player_id):
                self.right_paddle_y = self.map_y(p.position.y)

    # --------------------
    # AI
    # --------------------
    def update_ai(self):
        target = self.ball_y + random.uniform(-self.ball_uncertainty, self.ball_uncertainty)

        if self.right_paddle_y < target:
            self.right_paddle_y += self.ai_speed
        else:
            self.right_paddle_y -= self.ai_speed

    # --------------------
    # Physics (CENTERED)
    # --------------------
    def update_ball(self):
        self.ball_x += self.ball_speed_x
        self.ball_y += self.ball_speed_y

        # top/bottom
        if self.ball_y >= self.half_h or self.ball_y <= -self.half_h:
            self.ball_speed_y *= -1

        # paddles
        if self.hit_left_paddle() or self.hit_right_paddle():
            self.ball_speed_x *= -1

        # left/right walls
        if self.ball_x <= -self.half_w:
            self.reset_ball(direction=1)

        if self.ball_x >= self.half_w:
            self.reset_ball(direction=-1)

    def hit_left_paddle(self):
        return (
            abs(self.ball_x - self.left_paddle_x) < 0.3 and
            abs(self.ball_y - self.left_paddle_y) < self.paddle_height / 2
        )

    def hit_right_paddle(self):
        return (
            abs(self.ball_x - self.right_paddle_x) < 0.3 and
            abs(self.ball_y - self.right_paddle_y) < self.paddle_height / 2
        )

    def reset_ball(self, direction=1):
        self.ball_x = 0.0
        self.ball_y = 0.0
        self.ball_speed_x = 0.2 * direction
        self.ball_speed_y = random.uniform(-0.15, 0.15)

    # --------------------
    # Publish markers
    # --------------------
    def publish_markers(self):
        msg = MarkerArray()
        now = self.get_clock().now().to_msg()

        # BALL
        ball = Marker()
        ball.header.frame_id = "pong_world"
        ball.header.stamp = now
        ball.ns = "pong"
        ball.id = 0
        ball.type = Marker.SPHERE
        ball.action = Marker.ADD

        ball.pose.position.x = self.ball_x
        ball.pose.position.y = self.ball_y
        ball.pose.position.z = 0.0

        ball.scale.x = 0.2
        ball.scale.y = 0.2
        ball.scale.z = 0.2

        ball.color.r = 1.0
        ball.color.g = 1.0
        ball.color.b = 1.0
        ball.color.a = 1.0

        msg.markers.append(ball)

        # LEFT PADDLE
        left = Marker()
        left.header.frame_id = "pong_world"
        left.header.stamp = now
        left.ns = "pong"
        left.id = 1
        left.type = Marker.CUBE
        left.action = Marker.ADD

        left.pose.position.x = self.left_paddle_x
        left.pose.position.y = self.left_paddle_y
        left.pose.position.z = 0.0

        left.scale.x = self.paddle_width
        left.scale.y = self.paddle_height
        left.scale.z = 0.2

        left.color.r = 0.2
        left.color.g = 0.8
        left.color.b = 0.2
        left.color.a = 1.0

        msg.markers.append(left)

        # RIGHT PADDLE
        right = Marker()
        right.header.frame_id = "pong_world"
        right.header.stamp = now
        right.ns = "pong"
        right.id = 2
        right.type = Marker.CUBE
        right.action = Marker.ADD

        right.pose.position.x = self.right_paddle_x
        right.pose.position.y = self.right_paddle_y
        right.pose.position.z = 0.0

        right.scale.x = self.paddle_width
        right.scale.y = self.paddle_height
        right.scale.z = 0.2

        right.color.r = 0.8
        right.color.g = 0.2
        right.color.b = 0.2
        right.color.a = 1.0

        msg.markers.append(right)

        self.marker_pub.publish(msg)

    # --------------------
    # Main loop
    # --------------------
    def update(self):
        if not self.two_player_mode:
            self.update_ai()

        self.update_ball()
        self.publish_markers()


class BoardNode(Node):
    def __init__(self):
        super().__init__('pong_board_node')

        self.pub = self.create_publisher(Marker, "/pong_board", 10)

        self.timer = self.create_timer(1.0, self.publish_board)

        self.width = 10.0
        self.height = 6.0

    def publish_board(self):
        m = Marker()

        m.header.frame_id = "pong_world"
        m.header.stamp = self.get_clock().now().to_msg()

        m.ns = "pong_board"
        m.id = 0
        m.type = Marker.LINE_STRIP
        m.action = Marker.ADD

        half_w = self.width / 2.0
        half_h = self.height / 2.0

        # rectangle loop
        points = [
            (-half_w, -half_h, 0.0),
            ( half_w, -half_h, 0.0),
            ( half_w,  half_h, 0.0),
            (-half_w,  half_h, 0.0),
            (-half_w, -half_h, 0.0),
        ]

        for p in points:
            pt = m.points.__class__()

        for x, y, z in points:
            pt = Point()
            pt.x = x
            pt.y = y
            pt.z = z
            m.points.append(pt)

        m.scale.x = 0.05  # line width

        m.color.r = 1.0
        m.color.g = 1.0
        m.color.b = 1.0
        m.color.a = 1.0

        self.pub.publish(m)

def main(args=None):
    rclpy.init(args=args)
    ping_pong_game_node = PingPongRVizNode()
    board_node = BoardNode()

    executor = MultiThreadedExecutor()
    executor.add_node(ping_pong_game_node)
    executor.add_node(board_node)

    try:
        executor.spin()
    except KeyboardInterrupt:
        pass

    ping_pong_game_node.destroy_node()
    board_node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()