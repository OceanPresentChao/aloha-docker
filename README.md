# ALOHA-Dokcer

This repository contains the Dockerfile for building image of [aloha](https://github.com/tonyzhaozh/aloha)

## How to use

### Step 1: Build Image

#### Original Version

If you use the original version of aloha hardware made by Stanford or Interbotix. Build the image with file `Dockerfile.original`.You can feel free to delete the mirror setting in the Dockerfile if you want to.

```shell
# clone the repository
git clone https://github.com/OceanPresentChao/aloha-docker.git

cd ./aloha-docker

# build with Dockerfile.original
docker build --network="host" --build-arg HTTPS_PROXY="<your proxy address>" --build-arg HTTP_PROXY="<your proxy address>" -t <your image name> -f ./Dockerfile.original

# if you don't need proxy, run
docker build -t <your image name> -f ./Dockerfile.original
```

#### ZNJ Version

If you use the version of aloha hardware made by BJROBOT/ZNJ(智能佳).[ZNJ/智能佳](http://www.rosrobot.cn/?id=459) is the official Chinese region agent of aloha. Build the image with file `Dockerfile.ZNJ`.You can feel free to delete the mirror setting in the Dockerfile if you want to.

```shell
# clone the repository
git clone https://github.com/OceanPresentChao/aloha-docker.git

cd ./aloha-docker

# build with Dockerfile.original
docker build --network="host" --build-arg HTTPS_PROXY="<your proxy address>" --build-arg HTTP_PROXY="<your proxy address>" -t <your image name> -f ./Dockerfile.ZNJ

# if you don't need proxy, run
docker build -t <your image name> -f ./Dockerfile.ZNJ
```

### Step 2: Hardware installation(In your host machine):

Firstly, you should install hardware in your `host machine`

Step 1: Connect 4 robots to the computer via USB, and power on. *Do not use extension cable or usb hub*.
- To check if the robot is connected, install dynamixel wizard [here](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)
- Dynamixel wizard is a very helpful debugging tool that connects to individual motors of the robot. It allows
things such as rebooting the motor (very useful!), torque on/off, and sending commands.
However, it has no knowledge about the kinematics of the robot, so be careful about collisions.
The robot *will* collapse if motors are torque off i.e. there is no automatically engaged brakes in joints.
- Open Dynamixel wizard, go into ``options`` and select:
  - Protocal 2.0
  - All ports
  - 1000000 bps
  - ID range from 0-10
- Note: repeat above everytime before you scan.
- Then hit ``Scan``. There should be 4 devices showing up, each with 9 motors.


- One issue that arises is the port each robot binds to can change over time, e.g. a robot that
is initially ``ttyUSB0`` might suddenly become ``ttyUSB5``. To resolve this, we bind each robot to a fixed symlink
port with the following mapping:
  - ``ttyDXL_master_right``: right master robot (master: the robot that the operator would be holding)
  - ``ttyDXL_puppet_right``: right puppet robot (puppet: the robot that performs the task)
  - ``ttyDXL_master_left``: left master robot
  - ``ttyDXL_puppet_left``: left puppet robot
- Take ``ttyDXL_master_right``: right master robot as an example:
  1. Find the port that the right master robot is currently binding to, e.g. ``ttyUSB0``
  2. run ``udevadm info --name=/dev/ttyUSB0 --attribute-walk | grep serial`` to obtain the serial number. Use the first one that shows up, the format should look similar to ``FT6S4DSP``.
  3. ``sudo vim /etc/udev/rules.d/99-fixed-interbotix-udev.rules`` and add the following line: 

         SUBSYSTEM=="tty", ATTRS{serial}=="<serial number here>", ENV{ID_MM_DEVICE_IGNORE}="1", ATTR{device/latency_timer}="1", SYMLINK+="ttyDXL_master_right"

  4. This will make sure the right master robot is *always* binding to ``ttyDXL_master_right``
  5. Repeat with the rest of 3 arms.
- To apply the changes, run ``sudo udevadm control --reload && sudo udevadm trigger``
- If successful, you should be able to find ``ttyDXL*`` in your ``/dev``

Step 2: Set max current for gripper motors
- Open Dynamixel Wizard, and select the wrist motor for puppet arms. The name of it should be ```[ID:009] XM430-W350```
- Tip: the LED on the base of robot will flash when it is talking to Dynamixel Wizard. This will help determine which robot is selected. 
- Find ``38 Current Limit``, enter ``200``, then hit ``save`` at the bottom.
- Repeat this for both puppet robots.
- This limits the max current through gripper motors, to prevent overloading errors.


Step 3: Setup 4 cameras
- You may use usb hub here, but *maximum 2 cameras per hub for reasonable latency*.
- To make sure all 4 cameras are binding to a consistent port, similar steps are needed.
- Cameras are by default binding to ``/dev/video{0, 1, 2...}``, while we want to have symlinks ``{CAM_RIGHT_WRIST, CAM_LEFT_WRIST, CAM_LOW, CAM_HIGH}``
- Take ``CAM_RIGHT_WRIST`` as an example, and let's say it is now binding to ``/dev/video0``. run ``udevadm info --name=/dev/video0 --attribute-walk | grep serial`` to obtain it's serial. Use the first one that shows up, the format should look similar to ``0E1A2B2F``.
- Then ``sudo vim /etc/udev/rules.d/99-fixed-interbotix-udev.rules`` and add the following line 

      SUBSYSTEM=="video4linux", ATTRS{serial}=="<serial number here>", ATTR{index}=="0", ATTRS{idProduct}=="085c", ATTR{device/latency_timer}="1", SYMLINK+="CAM_RIGHT_WRIST"

🚧warning: If your camera model is different from the original version, you'd better check the `idProduct` of your USB camera.Use command `lsusb` to check ID of your devices

- Repeat this for ``{CAM_LEFT_WRIST, CAM_LOW, CAM_HIGH}`` in additional to ``CAM_RIGHT_WRIST``
- To apply the changes, run ``sudo udevadm control --reload && sudo udevadm trigger``
- If successful, you should be able to find ``{CAM_RIGHT_WRIST, CAM_LEFT_WRIST, CAM_LOW, CAM_HIGH}`` in your ``/dev``


### Step 3: Create Container & Hardware Installation for Container

The goal of this section is to run `roslaunch aloha 4arms_teleop.launch`, which starts communication with 4 robots and 4 cameras. It should work after finishing the following steps:

Step 1: (In your host machine)

run the commands:

```shell
docker run --name <your container name> -it --privileged --gpus all --network="host" <your image name>
```

- option `--gpus all` makes sure that your container can access your gpu devices of host

- option `--privileged` makes sure that your container can access your USB devices of host, such as USB Cameras or Arms

Create a new terminal, run the commands:

```shell
docker cp /etc/udev/rules.d/99-fixed-interbotix-udev.rules <your container id>:/etc/udev/rules.d/99-fixed-interbotix-udev.rules
```

Step 2: (In your container)

Run the commands below:

```shell
sudo service udev restart
sudo udevadm control --reload && sudo udevadm trigger
```

If successful, you should be able to find ``{CAM_RIGHT_WRIST, CAM_LEFT_WRIST, CAM_LOW, CAM_HIGH}`` in your ``/dev``

At this point, run:

```
conda deactivate # if conda shows up by default
source /opt/ros/noetic/setup.sh && source ~/interbotix_ws/devel/setup.sh
roslaunch aloha 4arms_teleop.launch
```

If no error message is showing up, the computer should be successfully connected to all 4 cameras and all 4 robots.

### Trouble shooting

- Make sure Dynamixel Wizard is disconnected, and no app is using webcam's stream. It will prevent ROS from connecting to these devices.

- If you get error `Failed to send reload request: Connection refused` when running ` sudo udevadm control --reload && sudo udevadm trigger`. Run `sudo service udev restart` and try again

## Testing teleoperation

**Notice**: Before running the commands below, be sure to place all 4 robots in their sleep positions, and open master robot's gripper. 
All robots will rise to a height that is easy for teleoperation.

PS: All terminals are created in your conatiner! You can run `docker exec <container id> /bin/bash` to create new terminal of your container

    # ROS terminal
    conda deactivate
    source /opt/ros/noetic/setup.sh && source ~/interbotix_ws/devel/setup.sh
    roslaunch aloha 4arms_teleop.launch
    
    # Right hand terminal
    conda activate aloha
    cd ~/interbotix_ws/src/aloha/aloha_scripts
    python3 one_side_teleop.py right
    
    # Left hand terminal
    conda activate aloha
    cd ~/interbotix_ws/src/aloha/aloha_scripts
    python3 one_side_teleop.py left

The teleoperation will start when the master side gripper is closed.