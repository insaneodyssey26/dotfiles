#!/bin/bash
cpu=0
gpu=0
for hw in /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*; do
    [ -r "$hw/fan1_input" ] && cpu=$(<"$hw/fan1_input")
    [ -r "$hw/fan2_input" ] && gpu=$(<"$hw/fan2_input")
done
echo "$cpu $gpu"
