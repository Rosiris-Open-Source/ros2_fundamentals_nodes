import pygame
import sys
import random

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
        self.two_player_mode = False

        self.screen = pygame.display.set_mode((self.WIDTH, self.HEIGHT))
        pygame.display.set_caption("ROS2 Ping Pong")

        # Colors
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)

        # Paddle settings
        self.PADDLE_WIDTH, self.PADDLE_HEIGHT = 10, 100
        self.paddle1 = pygame.Rect(30, self.HEIGHT//2 - 50,
                                   self.PADDLE_WIDTH, self.PADDLE_HEIGHT)
        self.paddle2 = pygame.Rect(self.WIDTH - 40, self.HEIGHT//2 - 50,
                                   self.PADDLE_WIDTH, self.PADDLE_HEIGHT)

        self.paddle_speed = 6
        self.ai_speed = 5.0
        self.ball_uncertainty = 30
        self.speed_min_penalty = 0.4
        self.speed_max_penalty = 1.0

        # Ball
        self.ball = pygame.Rect(self.WIDTH//2, self.HEIGHT//2, 10, 10)
        self.ball_speed_x = 5
        self.ball_speed_y = 5

        # Score
        self.score1 = 0
        self.score2 = 0
        self.font = pygame.font.SysFont(None, 50)

        # Clock
        self.clock = pygame.time.Clock()

        # Timer (30 Hz)
        self.timer = self.create_timer(1.0 / 30.0, self.update_game)

    def update_game(self):
        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                rclpy.shutdown()
                sys.exit()

        # Player controls
        keys = pygame.key.get_pressed()
        if keys[pygame.K_w]:
            self.paddle1.y -= self.paddle_speed
        if keys[pygame.K_s]:
            self.paddle1.y += self.paddle_speed

        # AI movement
        target = self.ball.centery + random.randint(-self.ball_uncertainty,
                                                    self.ball_uncertainty)

        if self.paddle2.centery < target:
            self.paddle2.y += self.ai_speed - random.uniform(
                self.speed_min_penalty, self.speed_max_penalty)
        elif self.paddle2.centery > target:
            self.paddle2.y -= self.ai_speed + random.uniform(
                self.speed_min_penalty, self.speed_max_penalty)
        else:
            self.paddle2.y += self.ai_speed * random.randint(-1, 1)

        # Clamp paddles
        self.paddle1.y = max(0, min(self.HEIGHT - self.PADDLE_HEIGHT, self.paddle1.y))
        self.paddle2.y = max(0, min(self.HEIGHT - self.PADDLE_HEIGHT, self.paddle2.y))

        # Ball movement
        self.ball.x += self.ball_speed_x
        self.ball.y += self.ball_speed_y

        # Collisions
        if self.ball.top <= 0 or self.ball.bottom >= self.HEIGHT:
            self.ball_speed_y *= -1

        if self.ball.colliderect(self.paddle1) or self.ball.colliderect(self.paddle2):
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
        pygame.draw.rect(self.screen, self.WHITE, self.paddle1)
        pygame.draw.rect(self.screen, self.WHITE, self.paddle2)
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