import pygame
import sys
import random
import threading

import rclpy
from rclpy.node import Node

from hand_detector_interfaces.msg import EstimatedPalmCenters, PalmCenter


class PingPongNode(Node):
    def __init__(self):
        super().__init__('ping_pong_node')


        # Initialize pygame
        pygame.init()

        # Screen settings
        self.WIDTH, self.HEIGHT = 1000, 800
        self.detection_min = 75.0
        self.detection_max = 420.0

        # player definitions
        self.left_player_lock = threading.Lock()
        self.left_player_id = "Right_hand"
        self.right_player_lock = threading.Lock()
        self.right_player_id = "Left_hand"

        self.screen = pygame.display.set_mode((self.WIDTH, self.HEIGHT))
        pygame.display.set_caption("ROS2 Ping Pong")

        # Colors
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)

        # Paddle settings
        self.PADDLE_WIDTH, self.PADDLE_HEIGHT = 10, 100
        self.left_paddle = pygame.Rect(30, self.HEIGHT//2 - 50,
                                   self.PADDLE_WIDTH, self.PADDLE_HEIGHT)
        self.right_paddle = pygame.Rect(self.WIDTH - 40, self.HEIGHT//2 - 50,
                                   self.PADDLE_WIDTH, self.PADDLE_HEIGHT)

        self.paddle_speed = 6
        self.ai_speed = 11.0
        self.ball_uncertainty = 30
        self.speed_min_penalty = 0.4
        self.speed_max_penalty = 1.0

        # Ball
        self.ball = pygame.Rect(self.WIDTH//2, self.HEIGHT//2, 10, 10)
        self.ball_speed_x = 10
        self.ball_speed_y = 10

        # Score
        self.score1 = 0
        self.score2 = 0
        self.font = pygame.font.SysFont(None, 50)

        # Clock
        self.clock = pygame.time.Clock()
        self.timer = self.create_timer(1.0 / 60.0, self.update_game)

        # ROS2 dependencies
        # Declare ROS2 parameter for two player mode
        self.declare_parameter('two_player_mode', False)

        # Get parameter value
        self.two_player_mode = (
            self.get_parameter('two_player_mode')
            .get_parameter_value()
            .bool_value
        )

        # Subscriber for detected palm centers
        self.palm_centers = self.create_subscription(
            EstimatedPalmCenters,
            '/hand_detector/estimated_palm_centers',
            self.update_paddle_positions_from_estimate,
            10
        )

    def update_paddle_positions_from_estimate(self, msg: EstimatedPalmCenters):
        for palm_center in msg.centers:
            if palm_center.palm_id.startswith(self.left_player_id):
                left_y_pos = self.calculate_paddle_pos_from_estimate(palm_center.position.y)
                with self.left_player_lock: 
                    self.left_paddle.y  = left_y_pos
            if self.two_player_mode and palm_center.palm_id.startswith(self.right_player_id):
                right_y_pos = self.calculate_paddle_pos_from_estimate(palm_center.position.y)
                with self.right_player_lock: 
                    self.right_paddle.y  = right_y_pos

    def calculate_paddle_pos_from_estimate(self, estimated_pos):
        y_pos_rel = 1.0 - ((self.detection_max - estimated_pos) / (self.detection_max - self.detection_min))
        return y_pos_rel * self.HEIGHT

    def update_left_paddle_from_input(self):
        keys = pygame.key.get_pressed()
        with self.left_player_lock:
            if keys[pygame.K_w]:
                self.left_paddle.y -= self.paddle_speed
            if keys[pygame.K_s]:
                self.left_paddle.y += self.paddle_speed

    def update_right_paddle_from_input(self):
        keys = pygame.key.get_pressed()
        with self.right_player_lock:
            if keys[pygame.K_UP]:
                self.right_paddle.y -= self.paddle_speed
            if keys[pygame.K_DOWN]:
                self.right_paddle.y += self.paddle_speed

    def update_right_paddle_cp(self):
        target = self.ball.centery + random.randint(-self.ball_uncertainty,
                                                    self.ball_uncertainty)
        if self.right_paddle.centery < target:
            self.right_paddle.y += self.ai_speed - random.uniform(
                self.speed_min_penalty, self.speed_max_penalty)
        elif self.right_paddle.centery > target:
            self.right_paddle.y -= self.ai_speed + random.uniform(
                self.speed_min_penalty, self.speed_max_penalty)
        else:
            self.right_paddle.y += self.ai_speed * random.randint(-1, 1)

    def clamp_paddles(self):
        with self.left_player_lock: 
            self.left_paddle.y = max(0, min(self.HEIGHT - self.PADDLE_HEIGHT, self.left_paddle.y))
        with self.right_player_lock:
            self.right_paddle.y = max(0, min(self.HEIGHT - self.PADDLE_HEIGHT, self.right_paddle.y)) 

    def update_game(self):
        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                rclpy.shutdown()
                sys.exit()

        self.update_left_paddle_from_input()
        if self.two_player_mode:
            self.update_right_paddle_from_input()
        else:
            self.update_right_paddle_cp()
        self.clamp_paddles()

        # Ball movement
        self.ball.x += self.ball_speed_x
        self.ball.y += self.ball_speed_y

        # Collisions
        if self.ball.top <= 0 or self.ball.bottom >= self.HEIGHT:
            self.ball_speed_y *= -1

        if self.ball.colliderect(self.left_paddle) or self.ball.colliderect(self.right_paddle):
            self.ball_speed_x *= -1

        # Scoring
        if self.ball.left <= 0:
            self.score2 += 1
            self.reset_ball()

        if self.ball.right >= self.WIDTH:
            self.score1 += 1
            self.reset_ball()

        # Draw
        self.screen.fill(self.BLACK)
        with self.left_player_lock: 
            pygame.draw.rect(self.screen, self.WHITE, self.left_paddle)
        with self.right_player_lock: 
            pygame.draw.rect(self.screen, self.WHITE, self.right_paddle)
        pygame.draw.ellipse(self.screen, self.WHITE, self.ball)

        score_text = self.font.render(f"{self.score1}   {self.score2}", True, self.WHITE)
        self.screen.blit(score_text,
                         (self.WIDTH//2 - score_text.get_width()//2, 20))

        pygame.display.flip()
        self.clock.tick(30)

    def reset_ball(self):
        self.ball.center = (self.WIDTH//2, self.HEIGHT//2)
        self.ball_speed_x *= -1


def main(args=None):
    rclpy.init(args=args)
    node = PingPongNode()
    rclpy.spin(node)

    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()