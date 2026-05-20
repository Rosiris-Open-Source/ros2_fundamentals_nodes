from setuptools import find_packages, setup
from glob import glob
import os   

package_name = 'hand_detector'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/' + package_name + '/config', glob('config/*')),
        ('share/' + package_name + '/launch', glob('launch/*')),
        ('share/' + package_name + '/models', ['resource/models/hand_landmarker.task']),
        ('share/' + package_name, ['package.xml']),
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
    ],
    install_requires=['setuptools',
                      'mediapipe',
                      'numpy<1.28.0',
                    ],
    zip_safe=True,
    maintainer='Manuel M.',
    maintainer_email='manuel.muth@rosiris.de',
    description='Hand detector using MediaPipe and OpenCV',
    license='Apache License 2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'webcam_node = hand_detector.webcam_node:main',
            'hand_detector_node = hand_detector.hand_detector_node:main',
        ],
    },
)