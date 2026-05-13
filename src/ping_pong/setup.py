from setuptools import find_packages, setup

package_name = 'ping_pong'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    package_data={'': ['py.typed']},
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Manuel M.',
    maintainer_email='manuel.muth@rosiris.de',
    description='TODO: Package description',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'ping_pong = ping_pong.ping_pong_game_node:main',
            'ping_pong_rviz2 = ping_pong.ping_pong_game_rviz2_node:main'
        ],
    },
)
