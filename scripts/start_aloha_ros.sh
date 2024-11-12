#! /bin/bash
conda deactivate
source /opt/ros/noetic/setup.sh && source ~/interbotix_ws/devel/setup.sh
roslaunch aloha 4arms_teleop.launch