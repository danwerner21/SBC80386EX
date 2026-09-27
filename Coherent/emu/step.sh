#!/bin/sh
# step.sh 'text' [seconds] -- type text into the VM, wait, screenshot to shot.png
py ../tools/qmp.py type "$1"; sleep ${2:-4}; py ../tools/qmp.py shot shot.png
