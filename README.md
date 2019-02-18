# Raspberry Pi Configuration Files

## Directory structure:  
Within the config directory, configuration files are placed as if the config directory were the system root directory (`/`). For example, `config/etc/ares/env.sh` should be placed in `/etc/ares/env.sh` to take effect. Rather than moving and updating the configuration files each time a change is made, all configuration files on both Raspberry Pi's have symbolic links pointing to the config repository in `/home/ares/config`. More about that below.
```
config/  
└── etc  
    ├── ares  
    │   └── env.sh
    ├── chrony  
    │   └── chrony.conf  
    ├── ppp  
    │   └── peers  
    │       ├── rfd900x  
    │       └── rfd900x-nocomp  
    ├── systemd  
    │   └── system  
    │       ├── ppp@.service  
    │       └── roscore.service  
    └── udev  
        └── rules.d  
            └── 99-rfd900x.rules  
```
### Problem
Some files need to be different on ares1 and ares2. For example, the radio link's IP address needs to be different on each device.
### Solution
The `master` git branch contains configuration files for ares1 (on the rover), and the `ares2` branch contains the configuration files for ares2 (in the hab).
### Problem  
Moving and updating configuration files each time they are updated is time consuming and error-prone.
### Solution  
Create a symlink (symbolic link) to each of the configuration files. For exapmle, instead of placing `config/etc/ares/env.sh` in `/etc/ares/env.sh`, create a symbolic link from `/home/ares/config/etc/ares/env.sh` to `/etc/ares/env.sh`. Then any time the file in the repository is updated, the system file is also updated (since it points to the same file).  

Use `ln` with the `-s` flag to create symbolic links (see `man ln`), and `ls -l` to view where a symbolic link points to.  

## PPP Radio Configuration Files  
This section deals with `config/etc/ppp/peers/rfd900x` and `config/etc/ppp/peers/rfd900x-nocomp`.  
### Problem  
We want to use the radio link as if it were a regular TCP/IP internet connection.  
### Solution  
PPP (Point-to-Point Protocol) provides this functionality. The two files (`rfd900x` and `rfd900x-nocomp`) set up the radio link by telling ppp what device to use, the baud rate, the IP address to create for it, and more. The only difference between `rfd900x` and `rfd900x-nocomp` is that `rfd900x-nocomp` disables all compression (which makes it easier to characterize the link). Both files are thoroughly commented so that the options being used can be easily understood.  

For more information about the configuration arguments used (and all possible configuration arguments), type `man pppd`.

## Systemd PPP Service File
This section deals with `config/etc/systemd/system/ppp@.service.`  
### Problem  
We want PPP to automatically start up when the Raspberry Pi's are plugged in, and we want it to restart if it dies for any reason.
### Solution  
Systemd is the linux solution for managing user processes (among other things). The `ppp@.service` file is a systemd service file that defines a user process. In this case, when it is started it will start ppp with the specified configuration. Additionally, the service file tells it to always restart the process within 2 seconds if it stops for any reason.  

You can start or stop the process with the syntax `systemctl start ppp@<config>` or `systemctl stop ppp@<config>`, where `<config>` is either `rfd900x` or `rfd900x-nocomp` (see the above section on PPP configuration files). Instead of manually starting and stopping the process, you can have systemd start it at boot with `systemctl enable ppp@<config>`. You can stop it from starting at boot with `systemctl disable ppp@<config>`.  

To get general information about the process (is it running? is it enabled to start at boot?) as well as the last few lines of the logs relating to the process, use `systemctl status ppp@<config>`.

## Systemd ROScore Service File
This section deals with `config/etc/systemd/system/roscore.service`.
### Problem
We want the ROS core to start automatically when the Rasberry Pi's are booted up.
### Solution
The `roscore.service` systemd service file defines the roscore process. Enabling the service will make it start at boot. See the secion on the systemd PPP service files for more details.  

## Telemetry Radio Udev Rules
This section deals with `config/etc/udev/rules.d/99-rfd900x.rules`.
### Problem
The PPP radio configuration needs to know how to connect to the radio. Telling it to use `/dev/ttyUSB0` will make it try to use the first USB device connected, but we want to make sure that that is the radio (and not a joystick or other device).  
### Solution  
Udev is the device manager for Linux. The file `99-rfd900x.rules` defines a udev rule. The rule states that when a USB device is connected, it will check its vendor and product IDs. If those IDs match those of the radio, it will create a symbolic link at `/dev/rfd900x` that points to the radio device. Now the ppp configuration file can try to open `/dev/rfd900x`, which will always be the radio (if it is connected) and not some other USB device.  

## Time Synchronization
This section deals with `config/etc/chrony/chrony.conf`.
### Problem  
The Raspberry Pi's do not have RTCs (Real-Time Clocks) installed. That means that whenever they are shut down, they forget what time it is. This is a problem since ROS expects the time between devices to be synchronized.  
### Solution
This is partially solved by installing the `fake-hwclock` package, which writes the system time to a file when the Raspberry Pi shuts down, then reads that time when it starts up again. It will still think that no time has passed while it was shut down, but at least it won't think it's 1970 or 2022.  

Chrony is an implementation of NTP (the Network Time Protocol). The `chrony.conf` file configures how it is used. On the master branch (for ares1 on the rover), the key configuration is to tell it to use ares2 as the time source (it will try to synchronize to whatever time ares2 has), and it can change the system time in discrete jumps to get there (instead of subtly skewing the system clock to get there eventually).  

On the ares2 branch, the configution file allows ares2 to synchronize time with the internet standard (if it is connected to the internet). The configuration also lets ares1 get its time from ares2, even if ares2 knows it isn't synchronized to internet time (it's more important that they agree on what time it is than that they actually have the right time).  

## Device-Specific ROS Configuration
This section deals with `config/etc/ares/env.sh`.
### Problem
Ares1 needs to know how to connect to the ROS master node running on ares2.
### Solution
A system configuration file is placed at `/etc/ares/env.sh`. This file simply sets up the necessary Linux environment variables so that ROS will know where to look to find the master node. The file does nothing on its own, and must be called. By adding the line `source /etc/ares/env.sh` to the bottom of `/home/ares/.bashrc`, the script will automatically be called every time a terminal is opened.
