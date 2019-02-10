#!/bin/sh
export ROS_HOSTNAME=$(hostname)
export ROS_MASTER_URI=http://$ROS_HOSTNAME:11311
