#! /bin/bash
sudo service udev restart
sudo udevadm control --reload && sudo udevadm trigger